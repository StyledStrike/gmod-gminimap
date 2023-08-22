local mapDimensions = {}

net.Receive( "gminimap.world_heights", function()
    if mapDimensions[game.GetMap()] then return end

    mapDimensions[game.GetMap()] = {
        min = net.ReadFloat(),
        max = net.ReadFloat()
    }

    GMinimap:UpdateLayout()
end )

function GMinimap.GetWorldZDimensions()
    local map = game.GetMap()
    local d = mapDimensions[map]

    if d then
        return d.min, d.max
    end

    -- assume its the whole map until we get
    -- more accurate dimensions from the server
    local world = game.GetWorld()

    if world and world.GetModelBounds then
        local mins, maxs = world:GetModelBounds()
        return mins.z, maxs.z
    end

    return -5000, 5000
end
