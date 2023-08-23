
util.AddNetworkString( "gminimap.world_heights" )

local mapHeights = GMinimap.mapHeights or {}
GMinimap.mapHeights = mapHeights

-- default map dimension overrides
do
    mapHeights["gm_bigcity_improved"] = { min = -13600, max = 2500 }
    mapHeights["gm_bigcity_improved_lite"] = { min = -13600, max = 2500 }
    mapHeights["gm_genesis"] = { min = -9000, max = 1000 }
    mapHeights["gm_excess_construct_13"] = { min = -4000, max = 3000 }
    mapHeights["rp_rudmerge"] = { min = -400, max = 9500 }
end

local minHeight, maxHeight = -5000, 5000

local function GetWorldHeights()
    local world = game.GetWorld()

    -- not sure this can ever happen, but better safe than sorry
    if not world or not world.GetModelBounds then
        GMinimap.LogF( "Unable to find the world heights, terrain might not render correctly!" )
        return minHeight, maxHeight, 0
    end

    local mins, maxs = world:GetModelBounds()
    return mins.z, maxs.z, world:OBBCenter().z
end

local function TraceLineWorld( pos, dir, dist )
    return util.TraceLine( {
        start = pos,
        endpos = pos + dir * dist,
        filter = ents.GetAll(),
        mask = MASK_SOLID_BRUSHONLY,
        collisiongroup = COLLISION_GROUP_WORLD,
        ignoreworld = false
    } )
end

-- given a position that is not in the void,
-- use a line trace to find the lowest point
local function GetFloor( pos )
    local tr = TraceLineWorld( pos, Vector( 0, 0, -1 ), 10000 )

    if tr.Hit then
        return tr.HitPos.z
    end

    return pos.z
end

hook.Add( "InitPostEntity", "GMinimap.CalculateWorldSize", function()
    local map = game.GetMap()
    local heights = mapHeights[map]

    -- prefer the hardcoded heights over what about to be done below
    if heights then
        minHeight, maxHeight = heights.min, heights.max

        return
    end

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
        -- try to find the skybox dimensions
        local skyCamPos = skyCam:GetPos()

        -- find where the skybox floor is
        local skyFloorZ = GetFloor( skyCamPos ) - 50

        -- try to find where the void below the skybox ends going down
        local belowSkybox = Vector( skyCamPos.x, skyCamPos.y, skyFloorZ )
        local tr = TraceLineWorld( belowSkybox, Vector( 0, 0, -1 ), 10000 )

        local endPos = Vector( belowSkybox.x, belowSkybox.y, belowSkybox.z - 10000 * tr.Fraction )
        maxZ = endPos.z - 200
    else
        -- the skybox is under the map,
        -- so make the lowest point a bit above it
        minZ = camZ + 1000
    end

    -- if these are switched, the skybox is likely
    -- level with the map, and so we disregard all we did so far
    if minZ > maxZ then
        minZ, maxZ = GetWorldHeights()
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