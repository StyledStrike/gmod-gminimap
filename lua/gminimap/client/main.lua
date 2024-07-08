concommand.Add(
    "gminimap",
    function() GMinimap:OpenFrame() end,
    nil,
    "Opens the GMinimap menu."
)

if engine.ActiveGamemode() == "sandbox" then
    list.Set(
        "DesktopWindows",
        "GMinimapDesktopIcon",
        {
            title = GMinimap.GetLanguageText( "title" ),
            icon = "materials/gminimap/gminimap.png",
            init = function() GMinimap:OpenFrame() end
        }
    )
end

hook.Add( "AddToolMenuCategories", "GMinimap.AddConfigCategory", function()
    spawnmenu.AddToolCategory( "Utilities", "GMinimap", "#gminimap.title" )
end )

hook.Add( "PopulateToolMenu", "GMinimap.AddConfigMenu", function()
    spawnmenu.AddToolMenuOption( "Utilities", "GMinimap", "GMinimap_Config", "#gminimap.configure", "", "", function( panel )
        panel:ClearControls()
        panel:Button( "#gminimap.title", "gminimap" )
    end )
end )

net.Receive( "gminimap.force_cvar_changed", function()
    GMinimap:UpdateLayout()
end )

hook.Add( "OnGMinimapConfigChange", "GMinimap.Update", function()
    GMinimap:UpdateLayout()
end )

hook.Add( "InitPostEntity", "GMinimap.Init", function()
    if GMinimap.Config.enable then
        GMinimap:Activate()
    end
end )

function GMinimap:CloseFrame()
    if IsValid( self.frame ) then
        self.frame:Close()
    end
end

function GMinimap:OpenFrame( tabIndex )
    if IsValid( self.frame ) then
        self:CloseFrame()
        return
    end

    local frame = vgui.Create( "GMinimap_TabbedFrame" )
    frame:Center()
    frame:MakePopup()

    frame.OnClose = function()
        self.frame = nil
    end

    self.frame = frame

    local landmarksPanel = frame:AddTab( "icon16/map.png", "landmarks" )
    local settingsPanel = frame:AddTab( "icon16/cog.png", "configure_minimap" )

    self.Landmarks:SetupPanel( landmarksPanel )
    self.Config:SetupPanel( settingsPanel )

    if tabIndex then
        frame:SetActiveTabByIndex( tabIndex )
    end
end

--[[
    All of the code below is for the built-in minimap
]]

-- Enable on autorefresh, used for development.
if IsValid( LocalPlayer() ) and GMinimap.Config.enable then
    timer.Simple( 0, function() GMinimap:Activate() end )
end

function GMinimap:Activate()
    if self.panel then
        self:Deactivate()
    end

    self.panel = vgui.Create( "GMinimap_Radar" )
    self.panel:ParentToHUD()
    self.radar = self.panel.radar

    self.panel.PerformLayout = function() end

    self.panel.Paint = function( _, w, h )
        self:DrawMinimap( w, h )
    end

    self:UpdateLayout()

    hook.Add( "StartChat", "GMinimap.DetectOpenChat", function()
        if self.isExpanded then
            self.isExpanded = false
            self:UpdateLayout()
        end
    end )

    hook.Add( "Think", "GMinimap.AutoSwitchLayers", function()
        self.World:CheckTriggers()
    end )
end

function GMinimap:Deactivate()
    hook.Remove( "StartChat", "GMinimap.DetectOpenChat" )
    hook.Remove( "HUDShouldDraw", "GMinimap.HideHUDItems" )
    hook.Remove( "Think", "GMinimap.AutoSwitchLayers" )

    if IsValid( self.panel ) then
        self.panel:Remove()
    end

    self.panel = nil
    self.bar = nil
end

function GMinimap:UpdateLayout()
    if not self.panel then return end

    local config = self.Config
    local screenW, screenH = ScrW(), ScrH()

    local forceX = GetConVar( "gminimap_force_x" ):GetFloat()
    local forceY = GetConVar( "gminimap_force_y" ):GetFloat()

    local forceW = GetConVar( "gminimap_force_w" ):GetFloat()
    local forceH = GetConVar( "gminimap_force_h" ):GetFloat()

    if forceX < 0 then forceX = config.x end
    if forceY < 0 then forceY = config.y end

    if forceW < 0 then forceW = config.width end
    if forceH < 0 then forceH = config.height end

    local expandedSize = math.max( forceW, forceH ) * 1.5

    local w = self.isExpanded and expandedSize or forceW
    local h = self.isExpanded and expandedSize or forceH

    w = math.Round( screenH * w )
    h = math.Round( screenH * h )

    local x = math.Round( ( screenW * forceX ) - ( w * forceX ) )
    local y = math.Round( ( screenH * forceY ) - ( h * forceY ) )

    if config.showCustomHealth then
        self.bar = {
            w = ( w * 0.5 ) - self.Config.borderThickness,
            h = config.healthHeight,

            hColor = config.healthColor,
            hColorBg = SDrawUtils.ModifyColorBrightness( config.healthColor, 0.2 ),

            hlowColor = config.lowhealthColor,
            hlowColorBg = SDrawUtils.ModifyColorBrightness( config.lowhealthColor, 0.2 ),

            aColor = config.armorColor,
            aColorBg = SDrawUtils.ModifyColorBrightness( config.armorColor, 0.2 ),
        }
    else
        self.bar = nil
    end

    local baseRatio = self.World.baseZoomRatio

    baseRatio = baseRatio + baseRatio * ( 1 - config.zoom )

    self.radar.color = config.terrainColor
    self.radar.ratio = Either( self.isExpanded, baseRatio, baseRatio * 0.8 )
    self.radar.pivotMultY = Either( self.isExpanded, 0.5, config.pivotOffset )

    local margin = self.Config.borderThickness
    local marginBottom = config.showCustomHealth and ( 1 + config.healthHeight + margin * 2 ) or margin * 2

    self.radar:SetHeights( self.World:GetHeights() )
    self.radar:SetDimensions( x + margin, y + margin, w - margin * 2, h - marginBottom )
    self.panel:SetPos( x, y )
    self.panel:SetSize( w, h )

    if config.hideDefaultHealth then
        local dontDraw = {
            ["CHudHealth"] = true,
            ["CHudBattery"] = true
        }

        hook.Add( "HUDShouldDraw", "GMinimap.HideHUDItems", function( name )
            if dontDraw[name] then return false end
        end )
    else
        hook.Remove( "HUDShouldDraw", "GMinimap.HideHUDItems" )
    end
end

function GMinimap:OnButtonPressed( button )
    if button == self.Config.toggleKey then
        self.Config.enable = not self.Config.enable

        if self.Config.enable then
            self:Activate()
        else
            self:Deactivate()
        end

    elseif button == self.Config.expandKey then
        self.isExpanded = not self.isExpanded
        self:UpdateLayout()
    end
end

local LocalPlayer = LocalPlayer

hook.Add( "PlayerButtonDown", "GMinimap.DetectHotkeys", function( ply, button )
    if IsFirstTimePredicted() and ply == LocalPlayer() then
        GMinimap:OnButtonPressed( button )
    end
end )

-- Workaround for key hooks that only run serverside on single-player
if game.SinglePlayer() then
    net.Receive( "gminimap.key", function()
        GMinimap:OnButtonPressed( net.ReadUInt( 8 ) )
    end )
end

local IsValid = IsValid
local Clamp = math.Clamp
local SetColor = surface.SetDrawColor
local DrawRect = surface.DrawRect

function GMinimap:DrawMinimap( w, h )
    SetColor( self.Config.borderColor:Unpack() )
    DrawRect( 0, 0, w, h )

    self.radar.origin = EyePos()
    self.radar.rotation = Angle( 0, self.Config.lockRotation and 0 or EyeAngles().y, 0 )
    self.radar:Draw()
    self:DrawBlips( self.radar )

    local b = self.bar
    if not b then return end

    local user = LocalPlayer()
    if not IsValid( user ) then return end

    local margin = self.Config.borderThickness
    local x, y = margin, h - b.h - margin

    -- Health bar
    local health = Clamp( user:Health() / user:GetMaxHealth(), 0, 1 )
    local lowHealth = health < 0.35

    if lowHealth then
        b.hlowColor.a = 255 * ( 1 - math.fmod( RealTime(), 0.7 ) )
    end

    SetColor( lowHealth and b.hlowColorBg or b.hColorBg )
    DrawRect( x, y, b.w, b.h )

    SetColor( lowHealth and b.hlowColor or b.hColor )
    DrawRect( x, y, b.w * health, b.h )

    -- Armor bar
    local armor = Clamp( user:Armor() / user:GetMaxArmor(), 0, 1 )

    SetColor( b.aColorBg )
    DrawRect( x + b.w + 1, y, b.w, b.h )

    SetColor( b.aColor )
    DrawRect( x + b.w + 1, y, b.w * armor, b.h )
end
