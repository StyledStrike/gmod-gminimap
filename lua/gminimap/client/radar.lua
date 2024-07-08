local Radar = {}

Radar.__index = Radar

function GMinimap.CreateRadar()
    local id, rt = SDrawUtils.AllocateRT()

    local instance = {
        -- Radar position/size
        x = 0,
        y = 0,
        w = 128,
        h = 128,

        -- Terrain render target
        rtId = id,
        rt = rt,

        -- Terrain layers and blips rotate around this pivot position.
        -- This is calculated based on the width/height.
        pivotX = 64,
        pivotY = 64,

        -- `pivotY` is set to `h * pivotMultY`
        pivotMultY = 0.5,

        origin = Vector(),  -- Center of the radar plane, relative to the world
        rotation = Angle(), -- Rotation of the radar plane, relative to the world
        ratio = 50,         -- Unit-to-pixel ratio (used for zooming)

        area = 5000,     -- Width/length of the map area (source units)
        bottom = -1000,  -- Min. height of the map area (source units)
        top = 1000,      -- Max. height of the map area (source units)

        -- These are used internally to capture the map area when needed
        lastGridX = -1,
        lastGridY = -1,
        lastCapturePos = Vector(),
        color = Color( 255, 255, 255 ),
        voidColor = Color( 40, 40, 40 )
    }

    return setmetatable( instance, Radar )
end

function Radar:Destroy()
    SDrawUtils.FreeRT( self.rtId )
    self.rtId = nil
    self.rt = nil
end

function Radar:SetDimensions( x, y, w, h )
    self.x, self.y = x, y
    self.w, self.h = w, h
    self:UpdateLayout()
end

function Radar:SetArea( area )
    self.area = area
    self:ResetCapture()
end

function Radar:SetHeights( bottom, top )
    self.bottom = bottom or self.bottom
    self.top = top or self.top
    self:ResetCapture()
end

function Radar:ResetCapture()
    self.lastGridX = -1
    self.lastGridY = -1
end

function Radar:UpdateLayout()
    self.pivotX = self.w * 0.5
    self.pivotY = self.h * self.pivotMultY
    self:SetArea( math.max( self.w, self.h ) * self.ratio )
end

local Clamp = math.Clamp
local WorldToLocal = WorldToLocal

--- Converts a 3D world position to a 2D pixel position,
--- relative to the radar's origin and rotation.
function Radar:WorldToLocal( pos, ang )
    -- Make pos relative to the radar plane
    pos, ang = WorldToLocal( pos, ang, self.origin, self.rotation )

    -- Convert source units to pixels
    local x, y = pos.y / self.ratio, pos.x / self.ratio

    -- Position relative to the radar pivot
    x, y = self.x + self.pivotX - x, self.y + self.pivotY - y

    -- Keep it inside
    x, y = Clamp( x, self.x, self.x + self.w ), Clamp( y, self.y, self.y + self.h )

    return x, y, -ang.y
end

local LocalToWorld = LocalToWorld

--- Converts a 2D pixel position to a 3D world position,
--- taking the radar's origin and rotation into consideration.
function Radar:LocalToWorld( x, y )
    local pos = Vector( self.pivotY - y, self.pivotX - x, 0 ) * self.ratio
    pos = LocalToWorld( pos, Angle(), self.origin, self.rotation )
    pos.z = 0

    return pos
end

local terrainMat = CreateMaterial( "GMinimap_TerrainMaterial", "UnlitGeneric", {
    ["$nolod"] = 1,
    ["$ignorez"] = 1,
    ["$vertexcolor"] = 1
} )

local yawAng = Angle()

local Round, Max = math.Round, math.max
local PushFilterMin, PushFilterMag = render.PushFilterMin, render.PushFilterMag
local PopFilterMin, PopFilterMag = render.PopFilterMin, render.PopFilterMag

local SetMaterial = render.SetMaterial
local SetScissorRect = render.SetScissorRect
local DrawTexturedRectRotated = SDrawUtils.DrawTexturedRectRotated

local function Grid( n, res )
    return Round( n / res ) * res
end

function Radar:Draw()
    if not self.rtId then return end

    local x, y = self.x, self.y
    local w, h = self.w, self.h
    local origin = self.origin
    local yaw = self.rotation[2]
    local size = Max( w, h )

    -- Convert the origin to a position on the grid, based on the area size
    local gridPos = Vector(
        Grid( origin[1], self.area * 0.5 ),
        Grid( origin[2], self.area * 0.5 ),
        0
    )

    -- Capture the terrain if the grid position has changed since last frame
    if self.lastGridX ~= gridPos[1] or self.lastGridY ~= gridPos[2] then
        self.lastGridX = gridPos[1]
        self.lastGridY = gridPos[2]

        self.lastCapturePos = gridPos
        self:Capture( gridPos )
    end

    -- When the origin moves away from out last captured position,
    -- calculate how much we need to move the terrain texture to compensate.
    local offset = Vector(
        ( ( origin[2] - self.lastCapturePos[2] ) / self.area ) * size,
        ( ( origin[1] - self.lastCapturePos[1] ) / self.area ) * size,
        0
    )

    yawAng[2] = yaw
    offset:Rotate( yawAng )

    SetScissorRect( x, y, x + w, y + h, true )

    PushFilterMin( 3 )
    PushFilterMag( 3 )

    terrainMat:SetTexture( "$basetexture", self.rt )
    SetMaterial( terrainMat )
    DrawTexturedRectRotated( x + self.pivotX + offset[1], y + self.pivotY + offset[2], size * 2, size * 2, -yaw, self.color )

    PopFilterMin()
    PopFilterMag()

    SetScissorRect( 0, 0, 0, 0, false )
end

local function NoDrawFunc() return true end

function Radar:Capture( origin )
    if self.capturing then return end

    self.capturing = true
    origin.z = self.top

    local hookId = "GMinimap.Capture_" .. self.rtId
    local Config = GMinimap.Config

    hook.Add( "PreDrawSkyBox", hookId, NoDrawFunc )
    hook.Add( "PrePlayerDraw", hookId, NoDrawFunc )
    hook.Add( "PreDrawViewModel", hookId, NoDrawFunc )

    local haloFunc = hook.GetTable()["PostDrawEffects"]["RenderHalos"]

    if haloFunc then
        hook.Remove( "PostDrawEffects", "RenderHalos" )
    end

    render.PushRenderTarget( self.rt, 0, 0, 1024, 1024 )
    render.SetStencilEnable( false )
    render.SetLightingMode( Config.terrainLighting and 0 or 1 )
    render.OverrideAlphaWriteEnable( false )
    render.SetColorMaterial()

    render.Clear( self.voidColor.r, self.voidColor.g, self.voidColor.b, 255, true, true )

    PushFilterMin( 1 )
    PushFilterMag( 1 )

    local offset = 1000

    render.RenderView( {
        origin = origin + Vector( 0, 0, offset ),
        angles = Angle( 90, 0, 0 ),
        x = 0,
        y = 0,
        w = 1024,
        h = 1024,
        znear = offset,
        zfar = self.top - self.bottom + offset,
        drawhud = false,
        drawmonitors = false,
        drawviewmodel = false,
        viewid = 2, -- VIEW_MONITOR

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

    PopFilterMin()
    PopFilterMag()
    render.PopRenderTarget()

    hook.Remove( "PreDrawSkyBox", hookId )
    hook.Remove( "PrePlayerDraw", hookId )
    hook.Remove( "PreDrawViewModel", hookId )

    if haloFunc then
        hook.Add( "PostDrawEffects", "RenderHalos", haloFunc )
    end

    self.capturing = false
end
