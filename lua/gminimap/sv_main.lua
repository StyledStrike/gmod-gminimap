
util.AddNetworkString( "gminimap.world_heights" )

local minHeight, maxHeight = -5000, 5000

local function GetWorldHeights()
    local world = game.GetWorld()

    -- not sure this can ever happen, but better safe than sorry
    if not world or not world.GetModelBounds then
        GMinimap.LogF( "Unable to find the world heights, terrain might not render correctly!" )
        return minHeight, maxHeight
    end

    local mins, maxs = world:GetModelBounds()
    return mins.z, maxs.z, world:OBBCenter().z
end

hook.Add( "InitPostEntity", "GMinimap.CalculateWorldSize", function()
    local minZ, maxZ, centerZ = GetWorldHeights()

    -- try to find the skybox camera, its location
    -- is useful to avoid drawing the skybox in the minimap
    local skyCam = ents.FindByClass( "sky_camera" )[1]

    -- no sky camera, assume we dont have a skybox
    if not IsValid( skyCam ) then
        minHeight, maxHeight = minZ, maxZ

        return
    end

    local camZ = skyCam:GetPos().z

    -- if the skybox is above the map
    if camZ > centerZ then
        -- make the highest point a bit below it
        maxZ = camZ - 1000
    else
        -- the skybox is under the map,
        -- so make the lowest point a bit above it
        minZ = camZ + 1000
    end

    minHeight, maxHeight = minZ, maxZ
end )

-- since PlayerInitialSpawn is called BEFORE the player is ready
-- to receive net events, we have to use ClientSignOnStateChanged instead
hook.Add( "ClientSignOnStateChanged", "GMinimap.SendDataToNewPlayers", function( user, _, new )
    if new == SIGNONSTATE_FULL then
        -- since we can only retrieve the player entity
        -- after this hook runs, lets use a timer
        timer.Simple( 3, function()
            local ply = Player( user )
            if not IsValid( ply ) then return end
            if ply:IsBot() then return end

            net.Start( "gminimap.world_heights", false )
            net.WriteFloat( minHeight )
            net.WriteFloat( maxHeight )
            net.Send( ply )
        end )
    end
end )