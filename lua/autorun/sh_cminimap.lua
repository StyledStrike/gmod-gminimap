GMinimap = { dataFolder = "gminimap/" }

function GMinimap.CreateSharedConvar( name, default, min, max, description )
    local flags = bit.bor( FCVAR_ARCHIVE, FCVAR_REPLICATED, FCVAR_NOTIFY )
    CreateConVar( "gminimap_" .. name, default, flags, "[GMinimap] " .. description, min, max )
end

function GMinimap.LogF( str, ... )
    MsgC( Color( 42, 180, 0 ), "[Custom Minimap] ", color_white, string.format( str, ... ), "\n" )
end

function GMinimap.EnsureDataFolder()
    if not file.Exists( GMinimap.dataFolder, "DATA" ) then
        file.CreateDir( GMinimap.dataFolder )
    end
end

GMinimap.CreateSharedConvar( "player_blips_max_distance", "8000", 0, 50000,
    "Limits how far players can see other players on the map. Set to 0 to disable player blips." )

GMinimap.CreateSharedConvar( "npc_blips_max_distance", "3000", 0, 50000,
    "Limits how far players can see NPCs on the map. Set to 0 to disable NPC blips." )

GMinimap.CreateSharedConvar( "force_x", "-1", -1, 1,
    "Force the X position of the minimap on all players. Set to -1 to disable this." )

GMinimap.CreateSharedConvar( "force_y", "-1", -1, 1,
    "Force the Y position of the minimap on all players. Set to -1 to disable this." )

GMinimap.CreateSharedConvar( "force_w", "-1", -1, 1,
    "Force the width of the minimap on all players. Set to -1 to disable this." )

GMinimap.CreateSharedConvar( "force_h", "-1", -1, 1,
    "Force the height of the minimap on all players. Set to -1 to disable this." )

if SERVER then
    AddCSLuaFile( "includes/modules/styled_draw_utils.lua" )

    AddCSLuaFile( "gminimap/cl_util.lua" )
    AddCSLuaFile( "gminimap/cl_config.lua" )
    AddCSLuaFile( "gminimap/cl_blips.lua" )
    AddCSLuaFile( "gminimap/cl_terrain.lua" )
    AddCSLuaFile( "gminimap/cl_radar.lua" )
    AddCSLuaFile( "gminimap/cl_npcs.lua" )
    AddCSLuaFile( "gminimap/cl_players.lua" )
    AddCSLuaFile( "gminimap/cl_landmarks.lua" )
    AddCSLuaFile( "gminimap/cl_main.lua" )

    include( "gminimap/sv_main.lua" )
end

if CLIENT then
    require( "styled_draw_utils" )

    include( "gminimap/cl_util.lua" )
    include( "gminimap/cl_config.lua" )
    include( "gminimap/cl_blips.lua" )
    include( "gminimap/cl_terrain.lua" )
    include( "gminimap/cl_npcs.lua" )
    include( "gminimap/cl_radar.lua" )
    include( "gminimap/cl_players.lua" )
    include( "gminimap/cl_landmarks.lua" )
    include( "gminimap/cl_main.lua" )
end
