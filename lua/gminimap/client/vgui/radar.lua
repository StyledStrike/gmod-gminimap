--[[
    A wrapper panel for the Radar class.
]]

local Radar = {}

function Radar:Init()
    self:SetCursor( "hand" )

    local baseRatio = GMinimap.World.baseZoomRatio

    self.minRatio = baseRatio * 0.2
    self.maxRatio = baseRatio

    self.radar = GMinimap.CreateRadar()
    self:SetHeights( GMinimap.World:GetHeights() )

    hook.Add( "OnGMinimapConfigChange", self, function()
        self.radar:UpdateLayout()
    end )
end

function Radar:OnRemove()
    hook.Remove( "OnGMinimapConfigChange", self )

    self.radar:Destroy()
    self.radar = nil
end

function Radar:SetOrigin( origin )
    self.radar.origin = origin
end

function Radar:SetRotation( ang )
    self.radar.rotation[2] = ang
end

function Radar:SetRatio( ratio )
    self.radar.ratio = ratio
    self.radar:UpdateLayout()

    if self.slider then
        self.slider:SetValue( ratio )
    end
end

function Radar:SetHeights( bottom, top )
    self.radar:SetHeights( bottom, top )
end

function Radar:AddZoomSlider()
    if self.slider then return end

    self.slider = vgui.Create( "DSlider", self )
    self.slider:SetSize( 100, 16 )
    self.slider:SetLockY( 0.5 )
    self.slider:SetTrapInside( true )

    self.slider.Paint = function( _, w )
        surface.SetDrawColor( 120, 120, 120, 255 )
        surface.DrawRect( 5, 7, w - 10, 1 )

        surface.SetDrawColor( 30, 30, 30, 255 )
        surface.DrawRect( 5, 8, w - 10, 1 )
    end

    self.slider.SetValue = function( s, value )
        s:SetSlideX( math.Remap( value, self.minRatio, self.maxRatio, 1, 0 ) )
    end

    self.slider.TranslateValues = function( _, x, y )
        self.radar.ratio = math.Remap( x, 1, 0, self.minRatio, self.maxRatio )
        self.radar:UpdateLayout()

        return x, y
    end
end

function Radar:PerformLayout( w, h )
    self.radar:SetDimensions( 0, 0, w, h )

    if self.slider then
        self.slider:SetPos( w - self.slider:GetWide() - 4, h - self.slider:GetTall() - 4 )
    end
end

function Radar:Paint()
    local x, y = self:LocalToScreen( 0, 0 )

    self.radar.x = x
    self.radar.y = y
    self.radar:Draw()

    GMinimap:DrawBlips( self.radar )

    if self._originStart then
        x, y = input.GetCursorPos()

        local diffX = ( self._mouseStartX - x ) * self.radar.ratio
        local diffY = ( self._mouseStartY - y ) * self.radar.ratio

        self.radar.origin[2] = self._originStart[2] - diffX
        self.radar.origin[1] = self._originStart[1] - diffY
    end
end

function Radar:OnMousePressed( keyCode )
    self:MouseCapture( true )

    local x, y = input.GetCursorPos()

    if keyCode == MOUSE_LEFT then
        self._originStart = Vector( self.radar.origin[1], self.radar.origin[2], 0 )
        self._mouseStartX = x
        self._mouseStartY = y
    else
        x, y = self:ScreenToLocal( x, y )
        self:OnRightClickPosition( self.radar:LocalToWorld( x, y ) )
    end
end

function Radar:OnMouseReleased()
    self:MouseCapture( false )
    self._originStart = nil
    self._mouseStartX = nil
    self._mouseStartY = nil
end

function Radar:OnMouseWheeled( delta )
    local ratio = math.Clamp( self.radar.ratio - delta * 5, self.minRatio, self.maxRatio )

    self.radar.ratio = ratio
    self.radar:UpdateLayout()

    if self.slider then
        self.slider:SetValue( ratio )
    end
end

function Radar:OnRightClickPosition( _pos ) end

vgui.Register( "GMinimap_Radar", Radar, "DPanel" )
