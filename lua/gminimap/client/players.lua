function GMinimap:SetOnlySameTeamBlips( sameTeamOnly )
    self.sameTeamOnly = sameTeamOnly
end

--[[
    Clientside player blip functions
]]

local type = type
local PlayerMeta = FindMetaTable( "Player" )

function PlayerMeta:SetBlipIcon( path )
    if path then
        assert( type( path ) == "string", "Player blip icon path must be a string or nil!" )
    end

    self._GMinimapBlipIcon = path
end

function PlayerMeta:SetBlipScale( scale )
    if scale then
        assert( type( scale ) == "number", "Player blip scale must be a number or nil!" )
    end

    self._GMinimapBlipScale = scale
end

function PlayerMeta:SetBlipColor( color )
    if color and color.r and color.g and color.b then
        self._GMinimapBlipColor = Color( color.r, color.g, color.b )
    else
        self._GMinimapBlipColor = nil
    end
end

--[[
    Player blips handler
]]

local icons = {
    dead = "gminimap/dead.png",
    vehicle = "gminimap/blips/car.png"
}

local colors = {
    default = Color( 255, 255, 255 ),
    dead = Color( 0, 0, 0 )
}

local scales = {
    vehicle = 1.25
}

local function GetState( ply )
    if not ply:Alive() then
        return "dead"
    end

    if ply:InVehicle() then
        return "vehicle"
    end

    return "default"
end

local function GetIcon( ply, state )
    if ply._GMinimapBlipIcon then
        return ply._GMinimapBlipIcon, ply._GMinimapBlipScale, true
    end

    if icons[state] then
        return icons[state], ply._GMinimapBlipScale or scales[state], true
    end

    return nil, ply._GMinimapBlipScale
end

local function GetColor( ply, state )
    if ply._GMinimapBlipColor then
        return ply._GMinimapBlipColor
    end

    if colors[state] then
        return colors[state]
    end

    return colors.default
end

local IsValid = IsValid
local LocalPlayer = LocalPlayer

local localBlip
local cvarMaxDist = GetConVar( "gminimap_player_blips_max_distance" )
local playerBlips = GMinimap.playerBlips or {}

GMinimap.playerBlips = playerBlips

timer.Create( "GMinimap.UpdatePlayerBlips", 0.1, 0, function()
    local localPly = LocalPlayer()
    if not IsValid( localPly ) then return end

    -- Create/update local player blip
    if localBlip then
        local icon, scale = GetIcon( localPly )

        localBlip.icon = icon or "gminimap/player.png"
        localBlip.color = GetColor( localPly )
        localBlip.scale = scale or 1.25
    else
        localBlip = GMinimap:AddBlip( {
            id = "local_player",
            parent = localPly
        } )
    end

    -- Create/update local blips from other players
    local teamId = GMinimap.sameTeamOnly and localPly:Team() or nil
    local defaultMaxDist = cvarMaxDist:GetFloat()
    local origin = localPly:GetPos()

    local id, dist, alpha, b
    local canSee, minDist, maxDist

    for _, ply in ipairs( player.GetAll() ) do
        if ply == localPly then continue end

        id = "player_" .. ply:UserID()
        dist = origin:Distance( ply:GetPos() )

        if ply:IsDormant() then
            canSee, maxDist = false, 0
        else
            canSee, maxDist = hook.Run( "CanSeePlayerBlip", ply )
            maxDist = maxDist or defaultMaxDist
        end

        if canSee == nil and teamId then
            canSee = teamId == ply:Team()
        end

        if maxDist <= 0 then
            canSee = false
        end

        if canSee == false or dist > maxDist then
            if playerBlips[id] then
                playerBlips[id] = nil
                GMinimap:RemoveBlipById( id )
            end

            continue
        end

        alpha = 1
        minDist = maxDist * 0.75

        if dist > minDist then
            alpha = ( maxDist - dist ) / ( maxDist - minDist )
        end

        b = playerBlips[id]

        if b then
            local state = GetState( ply )
            local icon, scale, lockAng = GetIcon( ply, state )

            b.indicateAlt = state ~= "dead"
            b.indicateAng = state == "default"
            b.lockIconAng = lockAng and ( state ~= "localplayer" )

            b.icon = icon
            b.color = GetColor( ply, state )
            b.scale = scale or 0.9
            b.alpha = alpha * 255
        else
            playerBlips[id] = GMinimap:AddBlip( {
                id = id,
                parent = ply,
                alpha = 0
            } )
        end
    end
end )
