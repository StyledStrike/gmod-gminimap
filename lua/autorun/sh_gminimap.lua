GMinimap = GMinimap or {}

if CLIENT then
    GMinimap.THEME_COLOR = Color( 34, 142, 66 )
    GMinimap.DATA_DIR = "gminimap/"
end

CreateConVar( "gminimap_player_blips_max_distance", "8000", FCVAR_ARCHIVE + FCVAR_REPLICATED + FCVAR_NOTIFY,
    "Limits how far players can see other players on the map. Set to 0 to disable player blips.", 0, 50000 )

CreateConVar( "gminimap_npc_blips_max_distance", "3000", FCVAR_ARCHIVE + FCVAR_REPLICATED + FCVAR_NOTIFY,
    "Limits how far players can see NPCs on the map. Set to 0 to disable NPC blips.", 0, 50000 )

CreateConVar( "gminimap_force_x", "-1", FCVAR_ARCHIVE + FCVAR_REPLICATED + FCVAR_NOTIFY,
    "Force the X position of the minimap on all players. Set to -1 to disable this.", -1, 1 )

CreateConVar( "gminimap_force_y", "-1", FCVAR_ARCHIVE + FCVAR_REPLICATED + FCVAR_NOTIFY,
    "Force the Y position of the minimap on all players. Set to -1 to disable this.", -1, 1 )

CreateConVar( "gminimap_force_w", "-1", FCVAR_ARCHIVE + FCVAR_REPLICATED + FCVAR_NOTIFY,
    "Force the width of the minimap on all players. Set to -1 to disable this.", -1, 1 )

CreateConVar( "gminimap_force_h", "-1", FCVAR_ARCHIVE + FCVAR_REPLICATED + FCVAR_NOTIFY,
    "Force the height of the minimap on all players. Set to -1 to disable this.", -1, 1 )

function GMinimap.Print( str, ... )
    MsgC( Color( 42, 180, 0 ), "[GMinimap] ", color_white, string.format( str, ... ), "\n" )
end

local UP = Vector( 0, 0, 1 )
local DOWN = Vector( 0, 0, -1 )

function GMinimap.TraceLineWorld( pos, dir, dist )
    return util.TraceLine( {
        start = pos,
        endpos = pos + dir * dist,
        filter = ents.GetAll(),
        mask = MASK_SOLID_BRUSHONLY,
        collisiongroup = COLLISION_GROUP_WORLD,
        ignoreworld = false
    } )
end

function GMinimap.GetHeightsAround( pos, dist )
    -- Try to find the ceiling
    local tr = GMinimap.TraceLineWorld( pos, UP, dist )
    local top = tr.Hit and tr.HitPos[3] or pos[3] + dist

    -- Try to find the floor
    tr = GMinimap.TraceLineWorld( pos, DOWN, dist )
    local bottom = tr.Hit and tr.HitPos[3] or pos[3] - dist

    return top, bottom
end

if SERVER then
    include( "gminimap/server/main.lua" )

    AddCSLuaFile( "includes/modules/styled_draw_utils.lua" )

    AddCSLuaFile( "gminimap/client/theme.lua" )
    AddCSLuaFile( "gminimap/client/utils.lua" )
    AddCSLuaFile( "gminimap/client/blips.lua" )
    AddCSLuaFile( "gminimap/client/config.lua" )
    AddCSLuaFile( "gminimap/client/landmarks.lua" )
    AddCSLuaFile( "gminimap/client/main.lua" )
    AddCSLuaFile( "gminimap/client/npcs.lua" )
    AddCSLuaFile( "gminimap/client/players.lua" )
    AddCSLuaFile( "gminimap/client/radar.lua" )
    AddCSLuaFile( "gminimap/client/world.lua" )

    AddCSLuaFile( "gminimap/client/vgui/tabbed_frame.lua" )
    AddCSLuaFile( "gminimap/client/vgui/radar.lua" )
end

if CLIENT then
    require( "styled_draw_utils" )

    include( "gminimap/client/theme.lua" )
    include( "gminimap/client/utils.lua" )
    include( "gminimap/client/blips.lua" )
    include( "gminimap/client/config.lua" )
    include( "gminimap/client/landmarks.lua" )
    include( "gminimap/client/main.lua" )
    include( "gminimap/client/npcs.lua" )
    include( "gminimap/client/players.lua" )
    include( "gminimap/client/radar.lua" )
    include( "gminimap/client/world.lua" )

    include( "gminimap/client/vgui/tabbed_frame.lua" )
    include( "gminimap/client/vgui/radar.lua" )
end
