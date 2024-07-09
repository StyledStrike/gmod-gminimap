SDrawUtils = {}

local function LogF( str, ... )
    MsgC( Color( 113, 54, 250 ), "[SDrawUtils] ", color_white, string.format( str, ... ), "\n" )
end

function SDrawUtils.ModifyColorBrightness( color, brightness )
    local h, s, _ = ColorToHSV( color )

    -- does not have color metatable
    local c = HSVToColor( h, s, brightness )

    return Color( c.r, c.g, c.b )
end

do
    -- render targets cannot be destroyed,
    -- therefore we should recycle them
    local rtCache = {}

    function SDrawUtils.AllocateRT()
        -- look for free render targets
        for id, rt in ipairs( rtCache ) do
            if rt.isFree then
                rt.isFree = false

                LogF( "RT #%d was recycled", id )
                return id, rt.texture
            end
        end

        --[[
            Texture flags used here, in order:
            - trilinear texture filtering
            - clamp S coordinates
            - clamp T coordinates
            - no mipmaps
            - no LODs (not affected by texture quality settings)
            - is a depth render target (duh)
        ]]
        local flags = bit.bor( 2, 4, 8, 256, 512, 65536 )
        local rt = { isFree = false }
        local id = #rtCache + 1

        rtCache[id] = rt

        rt.texture = GetRenderTargetEx(
            "sdrawutils_rt_" .. id,
            1024, 1024,
            RT_SIZE_LITERAL,
            MATERIAL_RT_DEPTH_SEPARATE,
            flags, 0,
            IMAGE_FORMAT_RGB888
        )

        LogF( "RT #%d was created.", id )

        return id, rt.texture
    end

    function SDrawUtils.FreeRT( id )
        local rt = rtCache[id]

        if rt then
            rt.isFree = true
            LogF( "RT #%d is free for reuse.", id )
        else
            LogF( "Tried to free a inexistent render target #%d", id )
        end
    end
end

do
    -- Original implementation from Starfall can be found at:
    -- https://github.com/thegrb93/StarfallEx/blob/master/lua/starfall/libs_cl/render.lua

    local segments = 32
    local circleMesh = Mesh()
    local meshMatrix = Matrix()
    local meshVector = Vector()

    mesh.Begin( circleMesh, MATERIAL_POLYGON, segments + 2 )

    mesh.Position( meshVector )
    mesh.TexCoord( 0, 0.5, 0.5 )
    mesh.Color( 255, 255, 255, 255 )
    mesh.AdvanceVertex()

    for i = 0, segments do
        local a = math.rad( ( i / segments ) * -360 )
        local s, c = math.sin( a ), math.cos( a )

        meshVector:SetUnpacked( s, c, 0 )

        mesh.Position( meshVector )
        mesh.TexCoord( 0, s / 2 + 0.5, c / 2 + 0.5 )
        mesh.Color( 255, 255, 255, 255 )
        mesh.AdvanceVertex()
    end

    mesh.End()

    local meshMaterial = CreateMaterial( "SDrawUtilsMesh", "UnlitGeneric", {
        ["$basetexture"] = "color/white",
        ["$model"] = 1,
        ["$vertexalpha"] = 1,
        ["$vertexcolor"] = 1
    } )

    local PushModelMatrix = cam.PushModelMatrix
    local PopModelMatrix = cam.PopModelMatrix
    local SetMaterial = render.SetMaterial

    function SDrawUtils.DrawFilledCircle( r, x, y, color )
        meshVector:SetUnpacked( color.r / 255, color.g / 255, color.b / 255 )

        meshMaterial:SetVector( "$color", meshVector )
        meshMaterial:SetFloat( "$alpha", color.a / 255 )

        SetMaterial( meshMaterial )

        meshVector:SetUnpacked( x, y, 0 )
        meshMatrix:SetTranslation( meshVector )

        meshVector:SetUnpacked( r, r, r )
        meshMatrix:SetScale( meshVector )

        PushModelMatrix( meshMatrix, true )
        circleMesh:Draw()
        PopModelMatrix()
    end
end

do
    -- our own implementation of DrawTexturedRectRotated
    -- that allows us to use floating-point coordinates.
    -- Original implementation from Starfall can be found at:
    -- https://github.com/thegrb93/StarfallEx/blob/master/lua/starfall/libs_cl/render.lua

    local v1, v2, v3, v4 = Vector(), Vector(), Vector(), Vector()
    local m_rad, m_sin, m_cos = math.rad, math.sin, math.cos
    local DrawQuad = render.DrawQuad

    local function MakeQuad( x, y, w, h )
        v1.x, v1.y = x, y
        v2.x, v2.y = x + w, y
        v3.x, v3.y = x + w, y + h
        v4.x, v4.y = x, y + h
    end

    local function RotateVector( v, x, y, c, s )
        x = v.x * c - v.y * s + x
        y = v.x * s + v.y * c + y
        v.x = x
        v.y = y
    end

    function SDrawUtils.DrawTexturedRectRotated( x, y, w, h, angle, color )
        MakeQuad( w * -0.5, h * -0.5, w, h )

        local r = m_rad( -angle )
        local c, s = m_cos( r ), m_sin( r )

        RotateVector( v1, x, y, c, s )
        RotateVector( v2, x, y, c, s )
        RotateVector( v3, x, y, c, s )
        RotateVector( v4, x, y, c, s )

        DrawQuad( v1, v2, v3, v4, color )
    end
end

--[[
    Utilities to draw images from the web.

    - Download & cache images
    - Lazy-loading (in a "dont-spam-http-requests" kind of way)
]]
local MAT_BUSY = Material( "icon16/hourglass.png", "smooth" )
local MAT_ERROR = Material( "error" )

local CRC = util.CRC
local CACHE_DIR = "cache/drawutils/"

local loaded = {}
local fetching = 0

if not file.Exists( CACHE_DIR, "DATA" ) then
    file.CreateDir( CACHE_DIR )
end

local function GetMaterialFromURL( url )
    if loaded[url] then
        return loaded[url]
    end

    if string.sub( url, 1, 4 ) ~= "http" then
        loaded[url] = Material( url, "smooth ignorez" )
        loaded[url]:GetTexture( "$basetexture" ):Download()

        return loaded[url]
    end

    local checksum = CRC( url )
    local path = CACHE_DIR .. checksum .. ".png"

    -- if we already have this image downloaded, create a material from the file
    if file.Exists( path, "DATA" ) then
        loaded[url] = Material( "data/" .. path, "smooth ignorez" )
        loaded[url]:GetTexture( "$basetexture" ):Download()

        return loaded[url]
    end

    -- if we are waiting for 3 images to download already, return a placeholder
    if fetching > 3 then return MAT_BUSY end

    -- put a placeholder on the cache for now (to prevent
    -- everything in this function from running every frame)
    loaded[url] = MAT_BUSY

    -- start the download!
    LogF( "Retrieving image: " .. url )
    fetching = fetching + 1

    http.Fetch( url, function( data, _, _, code )
        if tostring( code ):sub( 1, 1 ) ~= "2" then
            -- failed, not a success code!
            loaded[url] = MAT_ERROR
            fetching = fetching - 1
            LogF( string.format( "Failed to retrieve image (%d): %s", code, url ) )

            return
        end

        -- success! save it...
        file.Write( path, data )

        -- and create a material from it
        loaded[url] = Material( "data/" .. path, "smooth ignorez" )
        loaded[url]:GetTexture( "$basetexture" ):Download()
        fetching = fetching - 1

    end, function()
        -- failed!
        loaded[url] = MAT_ERROR
        fetching = fetching - 1
        LogF( "Failed to retrieve image: " .. url )
    end )

    return MAT_BUSY
end

local RealTime = RealTime

--[[
    Draw a rotated rectangle using a image from the web.
    x and y positions represent the center of the rectangle.
]]
local SetMaterial = render.SetMaterial
local DrawTexturedRectRotated = SDrawUtils.DrawTexturedRectRotated

function SDrawUtils.URLTexturedRectRotated( url, x, y, w, h, angle, color )
    local mat = GetMaterialFromURL( url )

    if mat == MAT_BUSY then
        angle = RealTime() * 100
    end

    SetMaterial( mat )
    DrawTexturedRectRotated( x, y, w, h, angle, color )
end
