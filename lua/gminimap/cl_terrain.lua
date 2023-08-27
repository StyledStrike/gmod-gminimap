local Terrain = {}

Terrain.__index = Terrain

function GMinimap.CreateTerrain()
    local id, rt = SDrawUtils.AllocateRT()

    local instance = {
        rtId = id,
        rt = rt,

        area = 5000,    -- map area captured by the terrain (source units)
        minZ = -1000,   -- min. height of the map terrain (source units)
        maxZ = 1000,    -- max. height of the map terrain (source units)

        lastGridX = -1,
        lastGridY = -1,
        lastCapturePos = Vector(),
        color = Color( 255, 255, 255 ),
        voidColor = Color( 50, 50, 50 )
    }

    return setmetatable( instance, Terrain )
end

function Terrain:Destroy()
    SDrawUtils.FreeRT( self.rtId )
    self.rtId = nil
    self.rt = nil
end

function Terrain:ResetCapture()
    self.lastGridX = -1
    self.lastGridY = -1
end

function Terrain:SetArea( area )
    self.area = area
    self:ResetCapture()
end

function Terrain:SetHeights( minZ, maxZ )
    self.minZ = minZ or self.minZ
    self.maxZ = maxZ or self.maxZ
    self:ResetCapture()
end

local Vector, Angle = Vector, Angle

local quadTL, quadTR = Vector(), Vector()
local quadBR, quadBL = Vector(), Vector()

function Terrain:Capture( origin )
    if self.capturing then return end
    self.capturing = true

    origin.z = self.maxZ

    local noDrawHookId = "GMinimap.CaptureNoDraw_" .. self.rtId

    hook.Add( "PreDrawOpaqueRenderables", noDrawHookId, function( isDrawingDepth, isDrawSkybox, isDraw3DSkybox )
        if isDrawingDepth or isDrawSkybox or isDraw3DSkybox then return end

        quadTL:SetUnpacked( origin.x, origin.y, self.minZ )
        quadTR:SetUnpacked( origin.x + self.area, origin.y, self.minZ )
        quadBR:SetUnpacked( origin.x + self.area, origin.y + self.area, self.minZ )
        quadBL:SetUnpacked( origin.x, origin.y + self.area, self.minZ )

        render.SetColorMaterial()
        render.DrawQuad( quadTL, quadTR, quadBR, quadBL, self.voidColor )
    end )

    hook.Add( "PreDrawSkyBox", noDrawHookId, function()
        return true
    end )

    local haloFunc = hook.GetTable()["PostDrawEffects"]["RenderHalos"]
    if haloFunc then
        hook.Remove( "PostDrawEffects", "RenderHalos" )
    end

    local Config = GMinimap.Config

    render.PushRenderTarget( self.rt, 0, 0, 1024, 1024 )
    render.SetStencilEnable( false )
    render.SetLightingMode( Config.terrainLighting and 0 or 1 )
    render.OverrideAlphaWriteEnable( false )
    render.SetColorMaterial()

    render.RenderView( {
        origin = origin,
        angles = Angle( 90, 0, 0 ),
        x = 0,
        y = 0,
        w = 1024,
        h = 1024,
        znear = 100,
        zfar = self.maxZ - self.minZ,
        drawhud = false,
        drawmonitors = false,
        drawviewmodel = false,

        ortho = {
            top = -self.area,
            left = -self.area,
            right = self.area,
            bottom = self.area
        }
    } )

    render.SetLightingMode( 0 )

    DrawColorModify( {
        ["$pp_colour_addr"] = 0,
        ["$pp_colour_addg"] = 0,
        ["$pp_colour_addb"] = 0,
        ["$pp_colour_mulr"] = 0,
        ["$pp_colour_mulg"] = 0,
        ["$pp_colour_mulb"] = 0,
        ["$pp_colour_brightness"] = Config.terrainBrightness,
        ["$pp_colour_contrast"] = 1,
        ["$pp_colour_colour"] = Config.terrainColorMult,
        ["$pp_colour_inv"] = Config.terrainColorInv
    } )

    render.PopRenderTarget()

    hook.Remove( "PreDrawOpaqueRenderables", noDrawHookId )
    hook.Remove( "PreDrawSkyBox", noDrawHookId )

    if haloFunc then
        hook.Add( "PostDrawEffects", "RenderHalos", haloFunc )
    end

    self.capturing = false
end

local terrainMat = CreateMaterial( "GMinimap_TerrainMaterial", "UnlitGeneric", {
    ["$nolod"] = 1,
    ["$ignorez"] = 1,
    ["$vertexcolor"] = 1
} )

local m_round, m_max = math.Round, math.max

local function Grid( n, res )
    return m_round( n / res ) * res
end

local render = render
local yawAng = Angle()
local DrawTexturedRectRotated = SDrawUtils.DrawTexturedRectRotated

function Terrain:Draw( x, y, w, h, pivotX, pivotY, origin, yaw )
    if not self.rtId then return end

    local size = m_max( w, h )

    -- convert origin to a grid position, based on the area size
    local gridPos = Vector(
        Grid( origin.x, self.area * 0.5 ),
        Grid( origin.y, self.area * 0.5 ),
        0
    )

    -- capture the terrain if the grid position has changed since last time
    if self.lastGridX ~= gridPos.x or self.lastGridY ~= gridPos.y then
        self.lastGridX = gridPos.x
        self.lastGridY = gridPos.y

        self.lastCapturePos = gridPos
        self:Capture( gridPos )
    end

    -- when the origin moves away from out last captured position,
    -- calculate how much we need to move the terrain texture to conpensate
    local offset = Vector(
        ( ( origin.y - self.lastCapturePos.y ) / self.area ) * size,
        ( ( origin.x - self.lastCapturePos.x ) / self.area ) * size,
        0
    )

    yawAng.y = yaw
    offset:Rotate( yawAng )

    render.SetColorMaterial()

    render.SetStencilWriteMask( 0xFF )
    render.SetStencilTestMask( 0xFF )
    render.SetStencilReferenceValue( 0 )
    render.SetStencilCompareFunction( STENCIL_ALWAYS )
    render.SetStencilPassOperation( STENCIL_KEEP )
    render.SetStencilFailOperation( STENCIL_KEEP )
    render.SetStencilZFailOperation( STENCIL_KEEP )
    render.ClearStencil()

    render.SetStencilEnable( true )
    render.SetStencilReferenceValue( 1 )
    render.SetStencilCompareFunction( 1 )
    render.SetStencilFailOperation( STENCIL_REPLACE )

    -- "cut" the screen area where our terrain texture will be
    -- visible according to the x, y, w, h arguments we received
    render.ClearStencilBufferRectangle( x, y, x + w, y + h, 1 )

    render.SetStencilCompareFunction( STENCIL_EQUAL )
    render.SetStencilFailOperation( STENCIL_KEEP )

    -- then draw the terrain texture
    terrainMat:SetTexture( "$basetexture", self.rt )
    render.SetMaterial( terrainMat )
    DrawTexturedRectRotated( x + pivotX + offset.x, y + pivotY + offset.y, size * 2, size * 2, -yaw, self.color )
    render.SetStencilEnable( false )
end
