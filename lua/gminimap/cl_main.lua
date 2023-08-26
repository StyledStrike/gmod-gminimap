GMinimap:SetCanSeePlayerBlips( true )

concommand.Add( "gminimap_config", function()
    GMinimap.Config:OpenPanel()
end )

concommand.Add( "gminimap_landmarks", function()
    GMinimap:OpenLandmarks()
end )

hook.Add( "AddToolMenuCategories", "GMinimap.AddConfigCategory", function()
    spawnmenu.AddToolCategory( "Utilities", "GMinimap", "#gminimap.name" )
end )

hook.Add( "PopulateToolMenu", "GMinimap.AddConfigMenu", function()
    spawnmenu.AddToolMenuOption( "Utilities", "GMinimap", "GMinimap_Config", "#gminimap.configure", "", "", function( panel )
        panel:ClearControls()
        panel:Button( "#gminimap.configure_minimap", "gminimap_config" )
        panel:Button( "#gminimap.landmarks", "gminimap_landmarks" )
    end )
end )

net.Receive( "gminimap.force_cvar_changed", function()
    GMinimap.LogF( "Server is forcing cvars" )
    GMinimap:UpdateLayout()
end )

-- enable when all entities are ready
hook.Add( "InitPostEntity", "GMinimap.Init", function()
    if GMinimap.Config.enable then
        GMinimap:Activate()
    end
end )

-- enable on autorefresh, used during development
if IsValid( LocalPlayer() ) and GMinimap.Config.enable then
    timer.Simple( 1, function()
        GMinimap:Activate()
    end )
end

--[[
    All the code below is for the built-in minimap
]]

function GMinimap:Activate()
    if self.radar then
        self:Deactivate()
    end

    self.radar = GMinimap.CreateRadar()
    self:UpdateLayout()

    hook.Add( "Think", "GMinimap.Think", function()
        self:Think()
    end )

    hook.Add( "HUDPaint", "GMinimap.Draw", function()
        self:Draw()
    end )

    hook.Add( "StartChat", "GMinimap.DetectOpenChat", function()
        if self.isExpanded then
            self.isExpanded = false
            self:UpdateLayout()
        end
    end )
end

function GMinimap:Deactivate()
    hook.Remove( "Think", "GMinimap.Think" )
    hook.Remove( "HUDPaint", "GMinimap.Draw" )
    hook.Remove( "StartChat", "GMinimap.DetectOpenChat" )
    hook.Remove( "HUDShouldDraw", "GMinimap.HideHUDItems" )

    self.radar:Destroy()
    self.radar = nil
end

function GMinimap:UpdateLayout()
    if not self.radar then return end

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

    w = screenH * w
    h = screenH * h

    local x = ( screenW * forceX ) - ( w * forceX )
    local y = ( screenH * forceY ) - ( h * forceY )

    if config.showCustomHealth then
        self.bar = {
            x = x,
            y = y + h + 1,

            w = ( w * 0.5 ) - 1,
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

    local baseRatio = GMinimap.GetWorldZoomRatio()

    baseRatio = baseRatio + baseRatio * ( 1 - config.zoom )

    self.radar.terrain.color = config.terrainColor
    self.radar.ratio = Either( self.isExpanded, baseRatio, baseRatio * 0.8 )
    self.radar.pivotMultY = Either( self.isExpanded, nil, 0.7 )
    self.radar:SetDimensions( x, y, w, h )

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

function GMinimap:Think()
    local isPressed = input.IsKeyDown( self.Config.expandKey )

    if isPressed ~= self.isExpandKeyPressed then
        self.isExpandKeyPressed = isPressed

        if isPressed and not vgui.GetKeyboardFocus() and not gui.IsGameUIVisible() then
            self.isExpanded = not self.isExpanded
            self:UpdateLayout()
        end
    end
end

local IsValid = IsValid
local LocalPlayer = LocalPlayer

local m_clamp = math.Clamp
local SetDrawColor = surface.SetDrawColor
local DrawRect = surface.DrawRect

function GMinimap:Draw()
    local thickness = self.Config.borderThickness

    local x, y = self.radar.x, self.radar.y
    local w, h = self.radar.w, self.radar.h

    SetDrawColor( self.Config.borderColor:Unpack() )
    DrawRect( x - thickness, y - thickness, w + thickness * 2, h + thickness * 2 )

    self.radar.origin = EyePos()
    self.radar.rotation = Angle( 0, EyeAngles().y, 0 )
    self.radar:Draw()
    self:DrawBlips( self.radar )

    local b = self.bar
    if not b then return end

    -- health bar
    local user = LocalPlayer()
    if not IsValid( user ) then return end

    x, y = self.bar.x, self.bar.y
    w, h = self.bar.w, self.bar.h

    SetDrawColor( self.Config.borderColor:Unpack() )
    DrawRect( x - thickness, y - 1 - thickness, 2 + ( w * 2 ) + ( thickness * 2 ), h + 2 + ( thickness * 2 ) )

    local health = m_clamp( user:Health() / user:GetMaxHealth(), 0, 1 )
    local lowHealth = health < 0.35

    if lowHealth then
        b.hlowColor.a = 255 * ( 1 - math.fmod( RealTime(), 0.7 ) )
    end

    SetDrawColor( lowHealth and b.hlowColorBg or b.hColorBg )
    DrawRect( x, y, b.w, b.h )

    SetDrawColor( lowHealth and b.hlowColor or b.hColor )
    DrawRect( x, y, b.w * health, b.h )

    -- armor bar
    local armor = m_clamp( user:Armor() / user:GetMaxArmor(), 0, 1 )

    SetDrawColor( b.aColorBg )
    DrawRect( x + b.w + 1, y, b.w, b.h )

    SetDrawColor( b.aColor )
    DrawRect( x + b.w + 1, y, b.w * armor, b.h )
end
