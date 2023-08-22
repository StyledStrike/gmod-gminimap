CreateConVar(
    "gminimap_player_blips_max_distance",
    "8000",
    bit.bor( FCVAR_ARCHIVE, FCVAR_REPLICATED, FCVAR_NOTIFY ),
    "[GMinimap] Limits how far players can see other players on the map. Set to 0 to disable player blips.",
    0, 50000
)

GMinimap = { dataFolder = "gminimap/" }

function GMinimap.LogF( str, ... )
    MsgC( Color( 42, 180, 0 ), "[Custom Minimap] ", color_white, string.format( str, ... ), "\n" )
end

function GMinimap.EnsureDataFolder()
    if not file.Exists( GMinimap.dataFolder, "DATA" ) then
        file.CreateDir( GMinimap.dataFolder )
    end
end

if SERVER then
    AddCSLuaFile( "includes/modules/styled_draw_utils.lua" )

    AddCSLuaFile( "gminimap/cl_util.lua" )
    AddCSLuaFile( "gminimap/cl_config.lua" )
    AddCSLuaFile( "gminimap/cl_blips.lua" )
    AddCSLuaFile( "gminimap/cl_terrain.lua" )
    AddCSLuaFile( "gminimap/cl_radar.lua" )
    AddCSLuaFile( "gminimap/cl_players.lua" )
    AddCSLuaFile( "gminimap/cl_main.lua" )

    include( "gminimap/sv_main.lua" )
end

if CLIENT then
    require( "styled_draw_utils" )

    include( "gminimap/cl_util.lua" )
    include( "gminimap/cl_config.lua" )
    include( "gminimap/cl_blips.lua" )
    include( "gminimap/cl_terrain.lua" )
    include( "gminimap/cl_radar.lua" )
    include( "gminimap/cl_players.lua" )
    include( "gminimap/cl_main.lua" )
end
