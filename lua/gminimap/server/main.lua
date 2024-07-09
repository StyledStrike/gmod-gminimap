resource.AddWorkshop( "3024317004" )

util.AddNetworkString( "gminimap.world_heights" )
util.AddNetworkString( "gminimap.force_cvar_changed" )

local worldTop, worldBottom

hook.Add( "InitPostEntity", "GMinimap.CalculateWorldSize", function()
    worldTop, worldBottom = 0, 0

    local GetHeightsAround = GMinimap.GetHeightsAround

    -- Try to find the world heights by looking at spawnpoints
    local spawnpoints = ents.FindByClass( "info_player_start" )

    for _, ent in ipairs( spawnpoints ) do
        local top, bottom = GetHeightsAround( ent:GetPos(), 50000 )

        if top > worldTop then worldTop = top end
        if bottom < worldBottom then worldBottom = bottom end
    end

    worldTop = worldTop + 1000
    worldBottom = worldBottom - 1000

    -- Try to to exclude the skybox from the world heights.
    local skyCam = ents.FindByClass( "sky_camera" )[1]

    if IsValid( skyCam ) then
        local skyCamPos = skyCam:GetPos()
        local skyTop, skyBottom = GetHeightsAround( skyCamPos, 5000 )
        local skyCenter = ( skyTop + skyBottom ) * 0.5

        -- If the skybox is above the map...
        if skyCenter > worldTop then
            -- Make sure the world top doesn't go into the skybox
            worldTop = math.min( worldTop, skyBottom )
            GMinimap.Print( "Looks like this map's skybox is above the rest of the map." )
        end

        -- If the skybox is below the map...
        if skyCenter < worldBottom then
            -- Make sure the world bottom ends at the top of the skybox
            worldBottom = skyTop + 100
            GMinimap.Print( "Looks like this map's skybox is below the rest of the map." )
        end
    end
end )

-- Since `PlayerInitialSpawn` is called before the player is ready to
-- receive net events, we have to use `ClientSignOnStateChanged` instead.
hook.Add( "ClientSignOnStateChanged", "GMinimap.SendWorldHeights", function( user, _, new )
    if new == SIGNONSTATE_FULL then
        -- Since we can only retrieve the player entity
        -- after this hook runs, lets use a timer.
        timer.Simple( 3, function()
            local ply = Player( user )
            if not IsValid( ply ) then return end
            if ply:IsBot() then return end

            net.Start( "gminimap.world_heights", false )
            net.WriteFloat( worldBottom )
            net.WriteFloat( worldTop )
            net.Send( ply )
        end )
    end
end )

-- Callbacks on FCVAR_REPLICATED cvars dont work clientside so we need them here
local function NotifyForceCvarChanged()
    net.Start( "gminimap.force_cvar_changed", false )
    net.Broadcast()
end

cvars.AddChangeCallback( "gminimap_force_x", NotifyForceCvarChanged, "changed_force_x" )
cvars.AddChangeCallback( "gminimap_force_y", NotifyForceCvarChanged, "changed_force_y" )
cvars.AddChangeCallback( "gminimap_force_w", NotifyForceCvarChanged, "changed_force_w" )
cvars.AddChangeCallback( "gminimap_force_h", NotifyForceCvarChanged, "changed_force_h" )

-- Workaround for key hooks that only run serverside on single-player
if game.SinglePlayer() then
    util.AddNetworkString( "gminimap.key" )

    hook.Add( "PlayerButtonDown", "GMinimap.ButtonDownWorkaround", function( ply, button )
        net.Start( "gminimap.key", true )
        net.WriteUInt( button, 8 )
        net.Send( ply )
    end )
end
