local mapDimensions = GMinimap.mapDimensions or {}

GMinimap.mapDimensions = mapDimensions

-- default map dimension overrides
do
    mapDimensions["gm_bigcity_improved"] = { min = -13600, max = 2500 }
    mapDimensions["gm_bigcity_improved_lite"] = { min = -13600, max = 2500 }
end

local function ValidateNumber( n, min, max )
    return math.Clamp( tonumber( n ) or 0, min, max )
end

function GMinimap.SetNumber( tbl, key, value, min, max )
    if value then
        tbl[key] = ValidateNumber( value, min, max )
    end
end

function GMinimap.SetBool( tbl, key, value )
    if value then
        tbl[key] = tobool( value )
    end
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
