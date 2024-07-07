--[[
    This file manages map-specific settings, such as
    terrain layers, base zoom ratio, world size, etc.
]]
local World = GMinimap.World or {}

GMinimap.World = World

function World:Reset()
    -- World heights, set when the data file exists.
    self.bottom = nil
    self.top = nil

    self.baseZoomRatio = 50
    self.layers = {}

    local world = game.GetWorld()
    if not world then return end
    if not world.GetModelBounds then return end

    local mins, maxs = world:GetModelBounds()

    -- World heights, used when the data file does not exist.
    -- Assume it's the whole map if we haven't received
    -- accurate dimensions from the server yet.
    if not self.serverBottom then
        self.serverBottom = mins.z
        self.serverTop = maxs.z
    end

    -- Try to figure out the best zoom level for this map.
    local sizeX = maxs.x + math.abs( mins.x )
    local sizeY = maxs.y + math.abs( mins.y )
    local avg = ( sizeX + sizeY ) * 0.5

    self.baseZoomRatio = ( avg / 25000 ) * 50
end

--- Load current map settings from `data_static/` if it exists.
function World:LoadFromFile()
    self:Reset()

    local path = "data_static/gminimap/" .. game.GetMap() .. ".json"
    local data = file.Read( path, "GAME" )

    if not data then
        GMinimap.Print( "Map settings file '%s' does not exist, using defaults.", path )
        return
    end

    data = GMinimap.FromJSON( data )

    local SetNumber = GMinimap.SetNumber

    SetNumber( self, "bottom", data.bottom, -50000, 50000, nil )
    SetNumber( self, "top", data.top, -50000, 50000, nil )
    SetNumber( self, "baseZoomRatio", data.baseZoomRatio, 1, 100, self.baseZoomRatio )

    -- TODO: load layers

    GMinimap.Print( "Loaded map settings file: %s", path )
end

function World:GetHeights()
    return
        self.bottom or self.serverBottom or -5000,
        self.top or self.serverTop or 5000
end

net.Receive( "gminimap.world_heights", function()
    World.serverBottom = net.ReadFloat()
    World.serverTop = net.ReadFloat()

    GMinimap.Print( "Received world heights from server: %f, %f", World.serverBottom, World.serverTop )
end )

hook.Add( "InitPostEntity", "GMinimap.SetupWorld", function()
    World:LoadFromFile()
end )

function World:SetupPanel( parent )
    local ApplyTheme = GMinimap.Theme.Apply

    -- TODO: check admin
end
