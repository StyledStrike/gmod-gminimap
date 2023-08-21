local Radar = {}

Radar.__index = Radar

function GMinimap.CreateRadar()
    local instance = {
        x = 0,
        y = 0,
        w = 32,
        h = 32,

        pivotX = 16, -- terrain and blips rotate around
        pivotY = 16, -- this 2d position on the radar

        origin = Vector(),  -- center of the radar plane, relative to the world
        rotation = Angle(), -- rotation of the radar plane, relative to the world
        ratio = 50,         -- unit-to-pixel ratio (used for zooming)

        terrain = GMinimap.CreateTerrain()
    }

    return setmetatable( instance, Radar )
end

function Radar:Destroy()
    self.terrain:Destroy()
    self.terrain = nil
end

function Radar:UpdateLayout()
    self.pivotX = self.w * 0.5
    self.pivotY = self.h * ( self.pivotMultY or 0.5 )

    self.terrain:SetArea( math.max( self.w, self.h ) * self.ratio )
    self.terrain:SetHeights( GMinimap.GetWorldZDimensions() )
end

function Radar:SetDimensions( x, y, w, h )
    self.x, self.y = x, y
    self.w, self.h = w, h

    self:UpdateLayout()
end

-- converts a 3D, world position to a 2D,
-- pixel position relative to the radar
local Clamp = math.Clamp
local WorldToLocal = WorldToLocal

function Radar:WorldToLocal( pos, ang )
    -- make pos relative to the radar plane
    pos, ang = WorldToLocal( pos, ang, self.origin, self.rotation )

    -- convert source units to pixels
    local x, y = pos.y / self.ratio, pos.x / self.ratio

    -- position stuff relative to the radar center
    x, y = self.x + self.pivotX - x, self.y + self.pivotY - y

    -- keep it inside
    x, y = Clamp( x, self.x, self.x + self.w ), Clamp( y, self.y, self.y + self.h )

    return x, y, -ang.y
end

function Radar:Draw()
    self.terrain:Draw( self.x, self.y, self.w, self.h, self.pivotX, self.pivotY, self.origin, self.rotation.y )
end
