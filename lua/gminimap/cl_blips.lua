GMinimap.blips = GMinimap.blips or {}

function GMinimap:FindBlipByID( id )
    for _, b in ipairs( self.blips ) do
        if id == b.id then
            return b
        end
    end
end

function GMinimap:RemoveAllBlips()
    table.Empty( self.blips )
end

function GMinimap:RemoveBlipById( id )
    for i, b in ipairs( self.blips ) do
        if b.id == id then
            table.remove( self.blips, i )
            break
        end
    end
end

function GMinimap:RemoveBlipByParent( ent )
    for i, b in ipairs( self.blips ) do
        if b.parent == ent then
            table.remove( self.blips, i )
        end
    end
end

local function CheckOptionalType( v, n, t )
    if v then
        assert( type( v ) == t, "Blip " .. n .. " must be a " .. t .. "!" )
    end
end

function GMinimap:AddBlip( params )
    params = params or {}

    assert( type( params ) == "table", "Blip parameters must be a table!" )

    if params.parent then
        assert( IsValid( params.parent ), "Blip parent is not a valid entity!" )
    end

    CheckOptionalType( params.id, "id", "string" )
    CheckOptionalType( params.position, "position", "Vector" )
    CheckOptionalType( params.angle, "angle", "Angle" )
    CheckOptionalType( params.scale, "scale", "number" )

    CheckOptionalType( params.indicateAlt, "indicateAlt", "boolean" )
    CheckOptionalType( params.indicateAng, "indicateAng", "boolean" )
    CheckOptionalType( params.lockIconAng, "lockIconAng", "boolean" )

    CheckOptionalType( params.icon, "icon", "string" )
    CheckOptionalType( params.alpha, "alpha", "number" )
    CheckOptionalType( params.color, "color", "table" )

    if params.id then
        local b = self:FindBlipByID( params.id )

        -- update existing blip with the same ID
        if b then
            b.parent = params.parent
            b.position = params.position or Vector()
            b.angle = params.angle or Angle()
            b.scale = params.scale or 1

            b.indicateAlt = params.indicateAlt
            b.indicateAng = params.indicateAng
            b.lockIconAng = params.lockIconAng

            b.icon = params.icon
            b.alpha = params.alpha or 255
            b.color = params.color or Color( 255, 255, 255 )

            return b, b.id
        end
    end

    -- create a new blip
    local blip = {
        parent = params.parent,
        position = params.position or Vector(),
        angle = params.angle or Angle(),
        scale = params.scale or 1,

        indicateAlt = params.indicateAlt,
        indicateAng = params.indicateAng,
        lockIconAng = params.lockIconAng,

        icon = params.icon,
        alpha = params.alpha or 255,
        color = params.color or Color( 255, 255, 255 )
    }

    blip.id = params.id or string.format( "%p", blip )

    self.blips[#self.blips + 1] = blip

    return blip, blip.id
end

local Angle = Angle

local function GetHeading( ent )
    if not ent:IsPlayer() then
        return Angle( 0, ent:GetAngles().y, 0 )
    end

    local yaw = 0

    if ent:Alive() then
        if ent:InVehicle() then
            yaw = ent:GetForward():Angle().y
        else
            yaw = ent:EyeAngles().y
        end
    end

    return Angle( 0, yaw, 0 )
end

local ScrH = ScrH
local IsValid = IsValid
local RealTime = RealTime

local SetMaterial = render.SetMaterial
local SetColorMaterial = render.SetColorMaterial

local DrawFilledCircle = SDrawUtils.DrawFilledCircle
local DrawTexturedRectRotated = SDrawUtils.DrawTexturedRectRotated
local URLTexturedRectRotated = SDrawUtils.URLTexturedRectRotated

local m_rad, m_sin, m_cos, m_abs = math.rad, math.sin, math.cos, math.abs
local matArrow = Material( "gminimap/heading.png", "smooth ignorez" )
local colorBlack = Color( 0, 0, 0, 255 )

function GMinimap:DrawBlips( radar )
    local diameter = ScrH() * self.Config.blipBaseSize
    local radius = diameter * 0.5
    local altSize = diameter * 0.8
    local angSize = diameter * 0.7
    local angDist = diameter * 0.55

    local i = #self.blips
    local blink = ( RealTime() % 1 ) > 0.5
    local b, x, y, yaw, zdiff, rad

    while i > 0 do
        b = self.blips[i]

        -- convert the blip world position to pixels relative to the radar
        x, y, yaw = radar:WorldToLocal( b.position, b.angle )

        -- how much higher/lower is this blip relative to the radar origin
        zdiff = radar.origin.z - b.position.z

        colorBlack.a = b.alpha
        b.color.a = b.alpha

        if b.icon then
            URLTexturedRectRotated( b.icon, x, y, diameter * b.scale, diameter * b.scale, b.lockIconAng and 0 or -yaw, b.color )
        else
            local r = radius * b.scale

            SetColorMaterial()
            DrawFilledCircle( r, x, y, colorBlack )
            DrawFilledCircle( r * 0.8, x, y, b.color )
        end

        if blink and b.indicateAlt and m_abs( zdiff ) > 200 then
            SetMaterial( matArrow )
            DrawTexturedRectRotated( x, y, altSize * b.scale, altSize * b.scale, zdiff > 0 and 180 or 0, colorBlack )
        end

        if b.indicateAng then
            rad = m_rad( yaw + 180 )
            x = x - m_sin( rad ) * angDist * b.scale
            y = y + m_cos( rad ) * angDist * b.scale

            SetMaterial( matArrow )
            DrawTexturedRectRotated( x, y, angSize * b.scale, angSize * b.scale, -yaw, colorBlack )
        end

        if b.parent then
            if IsValid( b.parent ) then
                b.position = b.parent:GetPos()
                b.angle = GetHeading( b.parent )
            else
                GMinimap.LogF( "Blip #%d no longer has a valid parent, removing...", i )
                table.remove( self.blips, i )
            end
        end

        i = i - 1
    end
end
