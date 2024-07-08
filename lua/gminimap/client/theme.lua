local colors = {
    black = Color( 0, 0, 0 ),
    panelBackground = Color( 40, 40, 40, 200 ),
    frameBackground = Color( 0, 0, 0, 240 ),

    frameBorder = Color( 80, 80, 80, 255 ),
    frameTitleBar = GMinimap.THEME_COLOR,

    buttonBorder = Color( 150, 150, 150, 255 ),
    buttonBackground = Color( 30, 30, 30, 255 ),
    buttonBackgroundDisabled = Color( 10, 10, 10, 255 ),
    buttonHover = Color( 255, 255, 255, 30 ),
    buttonPress = GMinimap.THEME_COLOR,

    buttonText = Color( 255, 255, 255, 255 ),
    buttonTextDisabled = Color( 180, 180, 180, 255 ),

    entryBorder = Color( 100, 100, 100, 255 ),
    entryBackground = Color( 10, 10, 10, 255 ),
    entryHighlight = GMinimap.THEME_COLOR,
    entryPlaceholder = Color( 150, 150, 150, 255 ),
    entryText = Color( 255, 255, 255, 255 ),

    labelText = Color( 255, 255, 255, 255 ),
    indicatorBackground = Color( 200, 0, 0, 255 )
}

local Theme = GMinimap.Theme or {
    classes = {}
}

Theme.colors = colors
GMinimap.Theme = Theme

function Theme.Apply( panel, forceClass )
    local class = Theme.classes[forceClass or panel.ClassName]
    if not class then return end

    if class.Prepare then
        class.Prepare( panel )
    end

    if class.Paint then
        panel.Paint = class.Paint
    end

    if class.UpdateColours then
        panel.UpdateColours = class.UpdateColours
    end

    if class.Close then
        panel.Close = class.Close
    end
end

----------

local Lerp = Lerp
local FrameTime = FrameTime

local DrawRect = surface.DrawRect
local DrawRoundedBox = draw.RoundedBox
local SetDrawColor = surface.SetDrawColor

Theme.classes["DLabel"] = {
    Prepare = function( self )
        self:SetColor( colors.labelText )
    end
}

Theme.classes["DPanel"] = {
    Paint = function( _, w, h )
        SetDrawColor( colors.panelBackground:Unpack() )
        DrawRect( 0, 0, w, h )
    end
}

Theme.classes["DButton"] = {
    Prepare = function( self )
        self._hoverAnim = 0

        self:SetText( self:GetText():Trim() )
        self:SizeToContentsX( 10 )
    end,

    Paint = function( self, w, h )
        self._hoverAnim = Lerp( FrameTime() * 10, self._hoverAnim, ( self:IsEnabled() and self.Hovered ) and 1 or 0 )

        local bgColor = self._themeHighlight and colors.buttonPress or colors.buttonBackground

        DrawRoundedBox( 4, 0, 0, w, h, colors.buttonBorder )
        DrawRoundedBox( 4, 1, 1, w - 2, h - 2, self:IsEnabled() and bgColor or colors.buttonBackgroundDisabled )

        local r, g, b, a = colors.buttonHover:Unpack()

        SetDrawColor( r, g, b, a * self._hoverAnim )
        DrawRect( 1, 1, w - 2, h - 2 )

        if self:IsDown() or self.m_bSelected then
            DrawRoundedBox( 4, 1, 1, w - 2, h - 2, self._themeHighlight and colors.buttonBackground or colors.buttonPress )
        end
    end,

    UpdateColours = function( self )
        if self:IsEnabled() then
            self:SetTextStyleColor( colors.buttonText )
        else
            self:SetTextStyleColor( colors.buttonTextDisabled )
        end
    end
}

Theme.classes["DBinder"] = Theme.classes["DButton"]

Theme.classes["DTextEntry"] = {
    Prepare = function( self )
        self:SetDrawBorder( false )
        self:SetPaintBackground( false )

        self:SetTextColor( colors.entryText )
        self:SetCursorColor( colors.entryText )
        self:SetHighlightColor( colors.entryHighlight )
        self:SetPlaceholderColor( colors.entryPlaceholder )
    end,

    Paint = function( self, w, h )
        SetDrawColor( colors.entryBorder:Unpack() )
        surface.DrawOutlinedRect( 0, 0, w, h, 1 )

        SetDrawColor( colors.entryBackground:Unpack() )
        DrawRect( 1, 1, w - 2, h - 2 )

        derma.SkinHook( "Paint", "TextEntry", self, w, h )
    end
}

Theme.classes["DComboBox"] = {
    Prepare = function( self )
        self:SetTextColor( colors.entryText )
    end,

    Paint = function( _, w, h )
        SetDrawColor( colors.entryBorder:Unpack() )
        surface.DrawOutlinedRect( 0, 0, w, h, 1 )

        SetDrawColor( colors.entryBackground:Unpack() )
        DrawRect( 1, 1, w - 2, h - 2 )
    end
}

Theme.classes["DNumSlider"] = {
    Prepare = function( self )
        Theme.Apply( self.TextArea )
        Theme.Apply( self.Label )
    end
}

Theme.classes["DScrollPanel"] = {
    Prepare = function( self )
        Theme.Apply( self.VBar )
    end,

    Paint = function( _, w, h )
        SetDrawColor( colors.panelBackground:Unpack() )
        DrawRect( 0, 0, w, h )
    end
}

local function DrawGrip( self, w, h )
    SetDrawColor( colors.buttonBorder:Unpack() )
    DrawRect( 0, 0, w, h )

    SetDrawColor( colors.buttonBackground:Unpack() )
    DrawRect( 1, 1, w - 2, h - 2 )

    if self.Depressed then
        SetDrawColor( colors.buttonPress:Unpack() )
        DrawRect( 1, 1, w - 2, h - 2 )

    elseif self.Hovered then
        SetDrawColor( colors.buttonHover:Unpack() )
        DrawRect( 1, 1, w - 2, h - 2 )
    end
end

Theme.classes["DVScrollBar"] = {
    Prepare = function( self )
        self.btnGrip.Paint = DrawGrip
    end,

    Paint = function( _, w, h )
        SetDrawColor( colors.entryBackground:Unpack() )
        DrawRect( 0, 0, w, h )
    end
}

local function SlideThink( anim, panel, fraction )
    if not anim.StartPos then
        anim.StartPos = Vector( panel.x, panel.y + anim.StartOffset, 0 )
        anim.TargetPos = Vector( panel.x, panel.y + anim.EndOffset, 0 )
    end

    panel._animAlpha = Lerp( fraction, anim.StartAlpha, anim.EndAlpha )

    local pos = LerpVector( fraction, anim.StartPos, anim.TargetPos )
    panel:SetPos( pos.x, pos.y )
    panel:SetAlpha( 255 * panel._animAlpha )
end

Theme.classes["DFrame"] = {
    Prepare = function( self )
        self._animAlpha = 0
        self._OriginalClose = self.Close
        self.lblTitle:SetColor( colors.labelText )

        local anim = self:NewAnimation( 0.4, 0, 0.25 )
        anim.StartOffset = -80
        anim.EndOffset = 0
        anim.StartAlpha = 0
        anim.EndAlpha = 1
        anim.Think = SlideThink
    end,

    Close = function( self )
        self:SetMouseInputEnabled( false )
        self:SetKeyboardInputEnabled( false )

        if self.OnStartClosing then
            self.OnStartClosing()
        end

        local anim = self:NewAnimation( 0.2, 0, 0.5, function()
            self:_OriginalClose()
        end )

        anim.StartOffset = 0
        anim.EndOffset = -80
        anim.StartAlpha = 1
        anim.EndAlpha = 0
        anim.Think = SlideThink
    end,

    Paint = function( self, w, h )
        if self.m_bBackgroundBlur then
            Derma_DrawBackgroundBlur( self, self.m_fCreateTime )
        end

        SetDrawColor( colors.frameBorder:Unpack() )
        surface.DrawOutlinedRect( 0, 0, w, h, 1 )

        SetDrawColor( colors.frameBackground:Unpack() )
        DrawRect( 0, 0, w, h )

        SetDrawColor( colors.frameTitleBar:Unpack() )
        DrawRect( 0, 0, w, 24 )
    end
}
