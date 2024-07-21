local Config = GMinimap.Config or {}

GMinimap.Config = Config

function Config:Reset()
    self.enable = true
    self.toggleKey = KEY_NONE
    self.expandKey = KEY_N

    self.zoom = 1
    self.pivotOffset = 0.75
    self.lockRotation = false
    self.blipBaseSize = 0.015

    -- Sizes are relative to the screen height
    self.width = 0.35
    self.height = 0.12

    -- `x` and `y` are numbers between 0 and 1, and they
    -- take the width/height into consideration. This means that, for example,
    -- when y is 0.0, the top of the radar aligns with the top of the screen, whereas
    -- when y is 1.0, the bottom of the radar aligns with the bottom of the screen.
    self.x = 0.5
    self.y = 0.01

    self.borderColor = Color( 20, 20, 20, 255 )
    self.borderThickness = 2

    -- Terrain
    self.terrainColor = Color( 255, 255, 255 )
    self.terrainBrightness = 0
    self.terrainColorMult = 0.75
    self.terrainColorInv = 0
    self.terrainLighting = true

    -- Health/armor
    self.hideDefaultHealth = false
    self.showCustomHealth = false
    self.healthHeight = 10

    self.healthColor = Color( 78, 160, 76, 255 )
    self.lowhealthColor = Color( 203, 66, 80, 255 )
    self.armorColor = Color( 70, 144, 180 )
end

function Config:Load()
    self:Reset()

    GMinimap.EnsureDataDir()

    local data = GMinimap.FromJSON( GMinimap.LoadDataFile( "config.json" ) )
    local SetNumber, SetBool, SetColor = GMinimap.SetNumber, GMinimap.SetBool, GMinimap.SetColor

    SetBool( self, "enable", data.enable )
    SetNumber( self, "toggleKey", data.toggleKey, KEY_NONE, BUTTON_CODE_LAST, self.toggleKey )
    SetNumber( self, "expandKey", data.expandKey, KEY_NONE, BUTTON_CODE_LAST, self.expandKey )
    SetNumber( self, "zoom", data.zoom, 0.5, 1.5, self.zoom )

    SetNumber( self, "x", data.x, 0, 1, self.x )
    SetNumber( self, "y", data.y, 0, 1, self.y )
    SetNumber( self, "width", data.width, 0, 1, self.width )
    SetNumber( self, "height", data.height, 0, 1, self.height )

    SetColor( self, "borderColor", data.borderR, data.borderG, data.borderB )
    SetNumber( self, "borderThickness", data.borderThickness, 0, 16, self.borderThickness )

    SetColor( self, "terrainColor", data.terrainR, data.terrainG, data.terrainB )
    SetNumber( self, "terrainBrightness", data.terrainBrightness, -1, 1, self.terrainBrightness )
    SetNumber( self, "terrainColorMult", data.terrainColorMult, 0, 2, self.terrainColorMult )
    SetNumber( self, "terrainColorInv", data.terrainColorInv, 0, 1, self.terrainColorInv )
    SetBool( self, "terrainLighting", data.terrainLighting )

    SetBool( self, "hideDefaultHealth", data.hideDefaultHealth )
    SetBool( self, "showCustomHealth", data.showCustomHealth )
    SetNumber( self, "healthHeight", data.healthHeight, 2, 32, self.healthHeight )

    SetColor( self, "healthColor", data.healthR, data.healthG, data.healthB )
    SetColor( self, "lowhealthColor", data.lowhealthR, data.lowhealthG, data.lowhealthB )
    SetColor( self, "armorColor", data.armorR, data.armorG, data.armorB )
end

function Config:Save( immediate )
    if not immediate then
        -- Avoid spamming the file system
        timer.Remove( "GMinimap.SaveConfigDelay" )
        timer.Create( "GMinimap.SaveConfigDelay", 0.5, 1, function()
            self:Save( true )
        end )

        return
    end

    local data = GMinimap.ToJSON( {
        enable = self.enable,
        toggleKey = self.toggleKey,
        expandKey = self.expandKey,

        zoom = self.zoom,

        x = self.x,
        y = self.y,
        width = self.width,
        height = self.height,

        borderR = self.borderColor.r,
        borderG = self.borderColor.g,
        borderB = self.borderColor.b,
        borderThickness = self.borderThickness,

        terrainR = self.terrainColor.r,
        terrainG = self.terrainColor.g,
        terrainB = self.terrainColor.b,

        terrainBrightness = self.terrainBrightness,
        terrainColorMult = self.terrainColorMult,
        terrainColorInv = self.terrainColorInv,
        terrainLighting = self.terrainLighting,

        hideDefaultHealth = self.hideDefaultHealth,
        showCustomHealth = self.showCustomHealth,
        healthHeight = self.healthHeight,

        healthR = self.healthColor.r,
        healthG = self.healthColor.g,
        healthB = self.healthColor.b,

        lowhealthR = self.lowhealthColor.r,
        lowhealthG = self.lowhealthColor.g,
        lowhealthB = self.lowhealthColor.b,

        armorR = self.armorColor.r,
        armorG = self.armorColor.g,
        armorB = self.armorColor.b
    }, true )

    GMinimap.SaveDataFile( "config.json", data )
end

Config:Load()

function Config:SetupPanel( parent )
    parent:Clear()

    local function OnChangeConfig()
        self:Save()
        hook.Run( "OnGMinimapConfigChange" )
    end

    local IGNORE_BIND_KEYS = {
        [MOUSE_LEFT] = true,
        [MOUSE_RIGHT] = true
    }

    local L = GMinimap.GetLanguageText
    local ApplyTheme = GMinimap.ApplyTheme

    local CreateHeader = GMinimap.CreateHeader
    local CreateSlider = GMinimap.CreateSlider
    local CreateColorPicker = GMinimap.CreateColorPicker
    local CreateToggleButton = GMinimap.CreateToggleButton
    local CreatePropertyLabel = GMinimap.CreatePropertyLabel

    local function OnBindChange( binder, keyNum, configKey, title )
        if IGNORE_BIND_KEYS[keyNum] then
            binder:SetValue( self[configKey] )
            Derma_Message( L( "invalid_bind" ):format( input.GetKeyName( keyNum ) ), L( title ), L"ok" )

            return
        end

        self[configKey] = keyNum
        self:Save()
    end

    local scroll = vgui.Create( "DScrollPanel", parent )
    scroll:Dock( FILL )
    scroll.pnlCanvas:DockPadding( 90, 8, 90, 8 )

    ApplyTheme( scroll )

    ----- General settings
    CreateHeader( L"title", scroll, -50, 0, -50, 10 )

    -- Toggle minimap
    CreateToggleButton( scroll, L"enable", self.enable, function( checked )
        self.enable = checked

        if checked then
            GMinimap:Activate()
        else
            GMinimap:Deactivate()
        end

        self:Save()
    end )

    -- Reset settings
    local buttonReset = vgui.Create( "DButton", scroll )
    buttonReset:SetText( L"reset" )
    buttonReset:Dock( TOP )

    ApplyTheme( buttonReset )

    buttonReset.DoClick = function()
        Derma_Query( L"reset_query", L"reset", L"yes", function()
            self:Reset()
            self:Save()

            GMinimap:Activate()

            timer.Simple( 0, function()
                self:SetupPanel( parent )
            end )
        end, L"no" )
    end

    -- Minimap toggle bind
    CreatePropertyLabel( L"toggle_key", scroll ):DockMargin( 0, 4, 0, 0 )

    local binderToggle = vgui.Create( "DBinder", scroll )
    binderToggle:Dock( TOP )
    binderToggle:SetValue( self.toggleKey )

    ApplyTheme( binderToggle, "DButton" )

    binderToggle.OnChange = function( _, num )
        OnBindChange( binderToggle, num, "toggleKey", "toggle_key" )
    end

    -- Expanded toggle bind
    CreatePropertyLabel( L"expand_key", scroll ):DockMargin( 0, 4, 0, 0 )

    local binderExpand = vgui.Create( "DBinder", scroll )
    binderExpand:Dock( TOP )
    binderExpand:SetValue( self.expandKey )

    ApplyTheme( binderExpand, "DButton" )

    binderExpand.OnChange = function( _, num )
        OnBindChange( binderExpand, num, "expandKey", "expand_key" )
    end

    ----- Radar properties
    CreateHeader( L"radar", scroll, -50, 10, -50, 10 )

    -- Lock rotation
    CreateToggleButton( scroll, L"lock_rotation", self.lockRotation, function( checked )
        self.lockRotation = checked
        OnChangeConfig()
    end )

    -- Radar zoom
    CreateSlider( scroll, L"zoom", self.zoom, 0.5, 1.5, 3, function( value )
        self.zoom = value
        OnChangeConfig()
    end )

    -- Radar pivot offset
    CreateSlider( scroll, L"pivot_offset", self.pivotOffset, 0, 1, 2, function( value )
        self.pivotOffset = value
        OnChangeConfig()
    end )

    -- Radar position/size
    local forceX = GetConVar( "gminimap_force_x" ):GetFloat()
    local forceY = GetConVar( "gminimap_force_y" ):GetFloat()
    local forceW = GetConVar( "gminimap_force_w" ):GetFloat()
    local forceH = GetConVar( "gminimap_force_h" ):GetFloat()

    if forceX >= 0 or forceY >= 0 or forceW >= 0 or forceH >= 0 then
        CreateHeader( L"forced_config", scroll ):SetTall( 24 )
    end

    CreateSlider( scroll, "X", self.x, 0, 1, 3, function( value )
        self.x = value
        OnChangeConfig()
    end ):SetEnabled( forceX < 0 )

    CreateSlider( scroll, "Y", self.y, 0, 1, 3, function( value )
        self.y = value
        OnChangeConfig()
    end ):SetEnabled( forceY < 0 )

    CreateSlider( scroll, L"width", self.width, 0.1, 0.5, 2, function( value )
        self.width = value
        OnChangeConfig()
    end ):SetEnabled( forceW < 0 )

    CreateSlider( scroll, L"height", self.height, 0.1, 0.5, 2, function( value )
        self.height = value
        OnChangeConfig()
    end ):SetEnabled( forceH < 0 )

    -- Radar border
    CreateSlider( scroll, L"border_thickness", self.borderThickness, 0, 16, 0, function( value )
        self.borderThickness = value
        OnChangeConfig()
    end )

    CreatePropertyLabel( L"border_color", scroll )

    CreateColorPicker( scroll, self.borderColor, function( color )
        self.borderColor = color
        OnChangeConfig()
    end )

    ----- Terrain properties
    CreateHeader( L"terrain", scroll, -50, 10, -50, 10 )

    -- Terrain lighting
    CreateToggleButton( scroll, L"terrain_lighting", self.terrainLighting, function( checked )
        self.terrainLighting = checked
        OnChangeConfig()
    end )

    -- Terrain brightness
    CreateSlider( scroll, L"terrain_brightness", self.terrainBrightness, -1, 1, 1, function( value )
        self.terrainBrightness = value
        OnChangeConfig()
    end )

    -- Terrain saturation
    CreateSlider( scroll, L"terrain_saturation", self.terrainColorMult, 0, 2, 1, function( value )
        self.terrainColorMult = value
        OnChangeConfig()
    end )

    -- Terrain color inversion
    CreateSlider( scroll, L"terrain_color_inv", self.terrainColorInv, 0, 1, 1, function( value )
        self.terrainColorInv = value
        OnChangeConfig()
    end )

    -- Terrain tint
    CreatePropertyLabel( L"terrain_color", scroll )

    CreateColorPicker( scroll, self.terrainColor, function( color )
        self.terrainColor = color
        OnChangeConfig()
    end )

    ----- Health/armor properties
    CreateHeader( L"health_armor", scroll, -50, 10, -50, 10 )

    -- Toggle custom health/armor
    CreateToggleButton( scroll, L"health_show_custom", self.showCustomHealth, function( checked )
        self.showCustomHealth = checked
        OnChangeConfig()
    end )

    -- Toggle hide default health/armor
    CreateToggleButton( scroll, L"health_hide_default", self.hideDefaultHealth, function( checked )
        self.hideDefaultHealth = checked
        OnChangeConfig()
    end )

    -- Health/armor height
    CreateSlider( scroll, L"health_height", self.healthHeight, 2, 32, 0, function( value )
        self.healthHeight = value
        OnChangeConfig()
    end )

    -- Health color
    CreatePropertyLabel( L"health_color", scroll )

    CreateColorPicker( scroll, self.healthColor, function( color )
        self.healthColor = color
        OnChangeConfig()
    end )

    -- Low health color
    CreatePropertyLabel( L"low_health_color", scroll )

    CreateColorPicker( scroll, self.lowhealthColor, function( color )
        self.lowhealthColor = color
        OnChangeConfig()
    end )

    -- Armor color
    CreatePropertyLabel( L"armor_color", scroll )

    CreateColorPicker( scroll, self.armorColor, function( color )
        self.armorColor = color
        OnChangeConfig()
    end )
end
