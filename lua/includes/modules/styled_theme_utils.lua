local STheme = _G.STheme or {}
local SThemeClasses = _G.SThemeClasses or {}

_G.STheme = STheme
_G.SThemeClasses = SThemeClasses

function STheme.New( t )
    t = t or {}

    t.panelBackground = t.panelBackground or Color( 20, 20, 20, 200 )
    t.frameBackground = t.frameBackground or Color( 0, 0, 0, 240 )
    t.frameBorder = t.frameBorder or Color( 80, 80, 80, 255 )
    t.frameTitleBar = t.frameTitleBar or Color( 25, 100, 170 )

    t.buttonBorder = t.buttonBorder or Color( 150, 150, 150, 255 )
    t.buttonBackground = t.buttonBackground or Color( 30, 30, 30, 255 )
    t.buttonBackgroundDisabled = t.buttonBackgroundDisabled or Color( 10, 10, 10, 255 )
    t.buttonHover = t.buttonHover or Color( 255, 255, 255, 30 )
    t.buttonPress = t.buttonPress or Color( 25, 100, 170 )

    t.buttonText = t.buttonText or Color( 255, 255, 255, 255 )
    t.buttonTextDisabled = t.buttonTextDisabled or Color( 180, 180, 180, 255 )

    t.entryBorder = t.entryBorder or Color( 100, 100, 100, 255 )
    t.entryBackground = t.entryBackground or Color( 10, 10, 10, 255 )
    t.entryHighlight = t.entryHighlight or Color( 25, 100, 170 )
    t.entryPlaceholder = t.entryPlaceholder or Color( 150, 150, 150, 255 )
    t.entryText = t.entryText or Color( 255, 255, 255, 255 )
    t.labelText = t.labelText or Color( 255, 255, 255, 255 )

    return t
end

function STheme.Apply( theme, panel, forceClass )
    local class = SThemeClasses[forceClass or panel.ClassName]
    if not class then return end

    panel._sTheme = theme

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

local SetDrawColor = surface.SetDrawColor
local MAT_BLUR = Material( "pp/blurscreen" )

function STheme.BlurPanel( panel, density, alpha )
    SetDrawColor( 255, 255, 255, alpha or 255 )
    surface.SetMaterial( MAT_BLUR )

    MAT_BLUR:SetFloat( "$blur", density or 4 )
    MAT_BLUR:Recompute()

    render.UpdateScreenEffectTexture()

    local x, y = panel:LocalToScreen( 0, 0 )
    surface.DrawTexturedRect( -x, -y, ScrW(), ScrH() )
end

---------- Supported panel classes ----------

local Lerp = Lerp
local FrameTime = FrameTime

local DrawRect = surface.DrawRect
local DrawRoundedBox = draw.RoundedBox

SThemeClasses["DLabel"] = {
    Prepare = function( self )
        self:SetColor( self._sTheme.labelText )
    end
}

SThemeClasses["DPanel"] = {
    Paint = function( self, w, h )
        SetDrawColor( self._sTheme.panelBackground:Unpack() )
        DrawRect( 0, 0, w, h )
    end
}

SThemeClasses["DButton"] = {
    Prepare = function( self )
        self._hoverAnim = 0
    end,

    Paint = function( self, w, h )
        self._hoverAnim = Lerp( FrameTime() * 10, self._hoverAnim, ( self:IsEnabled() and self.Hovered ) and 1 or 0 )

        local colors = self._sTheme
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
            self:SetTextStyleColor( self._sTheme.buttonText )
        else
            self:SetTextStyleColor( self._sTheme.buttonTextDisabled )
        end
    end
}

SThemeClasses["DBinder"] = SThemeClasses["DButton"]

SThemeClasses["DTextEntry"] = {
    Prepare = function( self )
        self:SetDrawBorder( false )
        self:SetPaintBackground( false )

        self:SetTextColor( self._sTheme.entryText )
        self:SetCursorColor( self._sTheme.entryText )
        self:SetHighlightColor( self._sTheme.entryHighlight )
        self:SetPlaceholderColor( self._sTheme.entryPlaceholder )
    end,

    Paint = function( self, w, h )
        SetDrawColor( self._sTheme.entryBorder:Unpack() )
        surface.DrawOutlinedRect( 0, 0, w, h, 1 )

        SetDrawColor( self._sTheme.entryBackground:Unpack() )
        DrawRect( 1, 1, w - 2, h - 2 )

        derma.SkinHook( "Paint", "TextEntry", self, w, h )
    end
}

SThemeClasses["DComboBox"] = {
    Prepare = function( self )
        self:SetTextColor( self._sTheme.entryText )
    end,

    Paint = function( self, w, h )
        SetDrawColor( self._sTheme.entryBorder:Unpack() )
        surface.DrawOutlinedRect( 0, 0, w, h, 1 )

        SetDrawColor( self._sTheme.entryBackground:Unpack() )
        DrawRect( 1, 1, w - 2, h - 2 )
    end
}

SThemeClasses["DNumSlider"] = {
    Prepare = function( self )
        STheme.Apply( self._sTheme, self.TextArea )
        STheme.Apply( self._sTheme, self.Label )
    end
}

SThemeClasses["DScrollPanel"] = {
    Prepare = function( self )
        STheme.Apply( self._sTheme, self.VBar )
    end,

    Paint = function( self, w, h )
        SetDrawColor( self._sTheme.panelBackground:Unpack() )
        DrawRect( 0, 0, w, h )
    end
}

local function DrawGrip( self, w, h )
    local colors = self._sTheme

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

SThemeClasses["DVScrollBar"] = {
    Prepare = function( self )
        self.btnGrip._sTheme = self._sTheme
        self.btnGrip.Paint = DrawGrip
    end,

    Paint = function( self, w, h )
        SetDrawColor( self._sTheme.entryBackground:Unpack() )
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

SThemeClasses["DFrame"] = {
    Prepare = function( self )
        self._animAlpha = 0
        self._OriginalClose = self.Close
        self.lblTitle:SetColor( self._sTheme.labelText )

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
        else
            STheme.BlurPanel( self, 2, 255 * self._animAlpha )
        end

        local colors = self._sTheme

        SetDrawColor( colors.frameBorder:Unpack() )
        surface.DrawOutlinedRect( 0, 0, w, h, 1 )

        SetDrawColor( colors.frameBackground:Unpack() )
        DrawRect( 0, 0, w, h )

        SetDrawColor( colors.frameTitleBar:Unpack() )
        DrawRect( 0, 0, w, 24 )
    end
}
