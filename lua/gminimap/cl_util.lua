local ratioOverrides = GMinimap.ratioOverrides or {}

ratioOverrides["gm_ame"] = 10
ratioOverrides["gm_aistruct"] = 10
ratioOverrides["gm_amber_metro"] = 10
ratioOverrides["gm_abandoned_ascot_mall"] = 15
ratioOverrides["gm_cinema_v2"] = 10
ratioOverrides["rp_oviscity_gmc5"] = 15
ratioOverrides["rp_nycity_day"] = 60

GMinimap.ratioOverrides = ratioOverrides

local function ValidateNumber( n, min, max )
    return math.Clamp( tonumber( n ) or 0, min, max )
end

function GMinimap.SetNumber( tbl, key, value, min, max )
    if value then
        tbl[key] = ValidateNumber( value, min, max )
    end
end

function GMinimap.SetBool( tbl, key, value )
    tbl[key] = tobool( value )
end

function GMinimap.SetColor( tbl, key, r, g, b )
    if r or g or b then
        tbl[key] = Color(
            ValidateNumber( r or 255, 0, 255 ),
            ValidateNumber( g or 255, 0, 255 ),
            ValidateNumber( b or 255, 0, 255 ),
            255
        )
    end
end

local minZ, maxZ

net.Receive( "gminimap.world_heights", function()
    minZ = net.ReadFloat()
    maxZ = net.ReadFloat()

    GMinimap.LogF( "Received world heights from server: %f, %f", minZ, maxZ )
    GMinimap:UpdateLayout()
end )

function GMinimap.GetWorldZDimensions()
    if minZ then
        return minZ, maxZ
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

function GMinimap.GetWorldZoomRatio()
    local override = ratioOverrides[game.GetMap()]
    if override then return override end

    -- try to figure out the best zoom level for this map
    local world = game.GetWorld()

    if world and world.GetModelBounds then
        local mins, maxs = world:GetModelBounds()

        local sizex = maxs.x + math.abs( mins.x )
        local sizey = maxs.y + math.abs( mins.y )

        local avg = ( sizex + sizey ) * 0.5
        local ratio = ( avg / 25000 ) * 50

        ratioOverrides[game.GetMap()] = ratio

        return ratio
    end

    return 50
end
