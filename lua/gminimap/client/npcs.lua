local SQUAD_COLORS = {
    ["none"] = Color( 255, 250, 150 ),
    ["enemy"] = Color( 255, 0, 0 ),
    ["ally"] = Color( 0, 110, 255 )
}

local active = {}
local nearby = {}

local function UpdateNPCBlip( ent, alpha )
    local id = "npc_" .. ent:EntIndex()
    nearby[id] = true

    if active[id] then
        active[id].alpha = alpha
        return
    end

    local color
    local class = ent:GetClass()

    if IsEnemyEntityName( class ) then
        color = SQUAD_COLORS.enemy

    elseif IsFriendEntityName( class ) then
        color = SQUAD_COLORS.ally
    end

    active[id] = GMinimap:AddBlip( {
        id = id,
        position = ent:GetPos(),
        icon = "gminimap/blips/npc_default.png",
        color = color or SQUAD_COLORS.none,
        parent = ent,
        scale = 0.8,
        indicateAlt = true,
        lockIconAng = true,
        alpha = alpha
    } )
end

local IsValid = IsValid
local LocalPlayer = LocalPlayer
local FindByClass = ents.FindByClass

local cvarMaxDist = GetConVar( "gminimap_npc_blips_max_distance" )

timer.Create( "GMinimap.UpdateNPCBlips", 0.5, 0, function()
    local localPly = LocalPlayer()
    if not IsValid( localPly ) then return end

    local maxDist = cvarMaxDist:GetFloat()

    if maxDist <= 0 then
        for id, _ in pairs( active ) do
            active[id] = nil
            GMinimap:RemoveBlipById( id )
        end

        return
    end

    local origin = localPly:GetPos()
    local minDist = maxDist * 0.75

    maxDist = maxDist * maxDist
    minDist = minDist * minDist
    nearby = {}

    local alpha, dist

    for _, ent in ipairs( FindByClass( "npc_*" ) ) do
        -- Make sure this is a NPC (to filter out things like npc_grenade_frag)
        if IsValid( ent ) and ent:IsNPC() and ent:Health() >= 0 then
            dist = origin:DistToSqr( ent:GetPos() )

            if dist < maxDist then
                alpha = 1

                if dist > minDist then
                    alpha = ( maxDist - dist ) / ( maxDist - minDist )
                end

                UpdateNPCBlip( ent, alpha * 255 )
            end
        end
    end

    -- Clear all other blips for invalid / far away NPCs
    for id, _ in pairs( active ) do
        if not nearby[id] then
            active[id] = nil
            GMinimap:RemoveBlipById( id )
        end
    end
end )
