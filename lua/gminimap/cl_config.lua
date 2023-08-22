local Config = GMinimap.Config or {}

GMinimap.Config = Config

function Config:Reset()
    self.enable = true
    self.expandKey = KEY_N
    self.blipBaseSize = 0.015

    -- x and y are fractions (between 0 and 1), and they
    -- take the width and height into consideration. This means that, for example,
    -- when y is 0, the top of the radar aligns with the top of the screen, whereas
    -- when y is 1, the bottom of the radar aligns with the bottom of the screen.
    self.x = 0.5
    self.y = 0.01

    -- sizes are relative to the screen height
    self.width = 0.35
    self.height = 0.12

    self.borderColor = Color( 0, 0, 0, 255 )
    self.borderThickness = 2

    -- terrain
    self.terrainColor = Color( 255, 255, 255 )
    self.terrainBrightness = 0
    self.terrainColorMult = 0.75
    self.terrainColorInv = 0
    self.terrainLighting = true

    -- health/armor
    self.hideDefaultHealth = false
    self.showCustomHealth = false
    self.healthHeight = 10

    self.healthColor = Color( 78, 160, 76, 255 )
    self.lowhealthColor = Color( 203, 66, 80, 255 )
    self.armorColor = Color( 70, 144, 180 )
end

function Config:Load()
    self:Reset()

    GMinimap.EnsureDataFolder()

    local rawData = file.Read( GMinimap.dataFolder .. "config.json", "DATA" ) or ""
    local data = util.JSONToTable( rawData ) or {}

    local SetNumber, SetBool, SetColor = GMinimap.SetNumber, GMinimap.SetBool, GMinimap.SetColor

    SetBool( self, "enable", data.enable )
    SetNumber( self, "expandKey", data.expandKey, KEY_FIRST, BUTTON_CODE_LAST )

    SetNumber( self, "x", data.x, 0, 1 )
    SetNumber( self, "y", data.y, 0, 1 )
    SetNumber( self, "width", data.width, 0, 1 )
    SetNumber( self, "height", data.height, 0, 1 )

    SetColor( self, "borderColor", data.borderR, data.borderG, data.borderB )
    SetNumber( self, "borderThickness", data.borderThickness, 0, 16 )

    SetColor( self, "terrainColor", data.terrainR, data.terrainG, data.terrainB )
    SetNumber( self, "terrainBrightness", data.terrainBrightness, -1, 1 )
    SetNumber( self, "terrainColorMult", data.terrainColorMult, 0, 2 )
    SetNumber( self, "terrainColorInv", data.terrainColorInv, 0, 1 )
    SetBool( self, "terrainLighting", data.terrainLighting )

    SetBool( self, "hideDefaultHealth", data.hideDefaultHealth )
    SetBool( self, "showCustomHealth", data.showCustomHealth )
    SetNumber( self, "healthHeight", data.healthHeight, 2, 32 )

    SetColor( self, "healthColor", data.healthR, data.healthG, data.healthB )
    SetColor( self, "lowhealthColor", data.lowhealthR, data.lowhealthG, data.lowhealthB )
    SetColor( self, "armorColor", data.armorR, data.armorG, data.armorB )
end

function Config:Save()
    local data = util.TableToJSON( {
        enable = self.enable,
        expandKey = self.expandKey,

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

    file.Write( GMinimap.dataFolder .. "config.json", data )
end

Config:Load()

function Config:OpenPanel()
    if IsValid( self.frame ) then
        self.frame:Close()
        self.frame = nil

        return
    end

    local frame = vgui.Create( "DFrame" )
    frame:SetTitle( "#gminimap.configure_minimap" )
    frame:SetIcon( "icon16/cog.png" )
    frame:SetDraggable( true )
    frame:SetSize( 500, 400 )
    frame:SetDeleteOnClose( true )
    frame:Center()
    frame:MakePopup()

    self.frame = frame

    local props = vgui.Create( "DProperties", frame )
    props:Dock( FILL )

    local function OnConfigChanged()
        GMinimap:UpdateLayout()
        Config:Save()
    end

    local function CreateColorRow( category, name, value, callback )
        local row = props:CreateRow( category, name )
        row:Setup( "VectorColor", {} )
        row:SetValue( Vector( value.r, value.g, value.b ) / 255 )

        row.DataChanged = function( s )
            local v = s.Inner.VectorValue
            row:SetValue( v )
            callback( Color( v[1] * 255, v[2] * 255, v[3] * 255 ) )
        end

        return row
    end

    local rowEnable = props:CreateRow( "#gminimap.name", "#gminimap.enable" )
    rowEnable:Setup( "Boolean" )
    rowEnable:SetValue( self.enable )

    rowEnable.DataChanged = function( _, val )
        self.enable = val > 0

        if self.enable then
            GMinimap:Activate()
        else
            GMinimap:Deactivate()
        end

        Config:Save()
    end

    local rowReset = props:CreateRow( "#gminimap.name", "#gminimap.reset" )
    rowReset:Setup( "Generic" )
    rowReset.Inner:GetChildren()[1]:Remove()
    rowReset.Inner.IsEditing = function() return false end

    local btnReset = vgui.Create( "DButton", rowReset.Inner )
    btnReset:Dock( FILL )
    btnReset:SetText( "#gminimap.reset" )

    btnReset.DoClick = function()
        Derma_Query( "#gminimap.reset_query", "#gminimap.reset", "#gminimap.yes", function()
            Config:Reset()
            Config:Save()
            GMinimap:Activate()

            self.frame:Close()
            self.frame = nil

            timer.Simple( 0, function()
                self:OpenPanel()
            end )
        end, "#gminimap.no" )
    end

    local rowKeybind = props:CreateRow( "#gminimap.name", "#gminimap.expand_key" )
    rowKeybind:Setup( "Generic" )
    rowKeybind.Inner:GetChildren()[1]:Remove()
    rowKeybind.Inner.IsEditing = function() return false end

    local ignoreKeys = {
        [MOUSE_LEFT] = true,
        [MOUSE_RIGHT] = true
    }

    local binder = vgui.Create( "DBinder", rowKeybind.Inner )
    binder:Dock( FILL )
    binder:SetValue( self.expandKey )

    binder.OnChange = function( _, num )
        if ignoreKeys[num] then
            binder:SetValue( self.expandKey )
            Derma_Message( "Cannot use " .. input.GetKeyName( num ) .. "!", "Invalid button", "OK" )

            return
        end

        self.expandKey = num
    end

    ------ radar ------

    local rowX = props:CreateRow( "#gminimap.radar", "X" )
    rowX:Setup( "Float", { min = 0, max = 1 } )
    rowX:SetValue( self.x )

    rowX.DataChanged = function( _, val )
        self.x = math.Round( val, 3 )
        OnConfigChanged()
    end

    local rowY = props:CreateRow( "#gminimap.radar", "Y" )
    rowY:Setup( "Float", { min = 0, max = 1 } )
    rowY:SetValue( self.y )

    rowY.DataChanged = function( _, val )
        self.y = math.Round( val, 3 )
        OnConfigChanged()
    end

    local rowWidth = props:CreateRow( "#gminimap.radar", "#gminimap.width" )
    rowWidth:Setup( "Float", { min = 0.1, max = 0.5 } )
    rowWidth:SetValue( self.width )

    rowWidth.DataChanged = function( _, val )
        self.width = math.Round( val, 3 )
        OnConfigChanged()
    end

    local rowHeight = props:CreateRow( "#gminimap.radar", "#gminimap.height" )
    rowHeight:Setup( "Float", { min = 0.1, max = 0.5 } )
    rowHeight:SetValue( self.height )

    rowHeight.DataChanged = function( _, val )
        self.height = math.Round( val, 3 )
        OnConfigChanged()
    end

    local rowBorderThick = props:CreateRow( "#gminimap.radar", "#gminimap.border_thickness" )
    rowBorderThick:Setup( "Int", { min = 0, max = 16 } )
    rowBorderThick:SetValue( self.borderThickness )

    rowBorderThick.DataChanged = function( _, val )
        self.borderThickness = math.floor( val )
        OnConfigChanged()
    end

    CreateColorRow( "#gminimap.radar", "#gminimap.border_color", self.borderColor, function( v )
        self.borderColor = v
        OnConfigChanged()
    end )

    ------ terrain ------

    CreateColorRow( "#gminimap.terrain", "#gminimap.terrain_color", self.terrainColor, function( v )
        self.terrainColor = v
        OnConfigChanged()
    end )

    local rowBrightness = props:CreateRow( "#gminimap.terrain", "#gminimap.terrain_brightness" )
    rowBrightness:Setup( "Float", { min = -1, max = 1 } )
    rowBrightness:SetValue( self.terrainBrightness )

    rowBrightness.DataChanged = function( _, val )
        self.terrainBrightness = math.Round( val, 3 )
        OnConfigChanged()
    end

    local rowColorMult = props:CreateRow( "#gminimap.terrain", "#gminimap.terrain_saturation" )
    rowColorMult:Setup( "Float", { min = 0, max = 2 } )
    rowColorMult:SetValue( self.terrainColorMult )

    rowColorMult.DataChanged = function( _, val )
        self.terrainColorMult = math.Round( val, 3 )
        OnConfigChanged()
    end

    local rowColorInv = props:CreateRow( "#gminimap.terrain", "#gminimap.terrain_color_inv" )
    rowColorInv:Setup( "Float", { min = 0, max = 1 } )
    rowColorInv:SetValue( self.terrainColorInv )

    rowColorInv.DataChanged = function( _, val )
        self.terrainColorInv = math.Round( val, 3 )
        OnConfigChanged()
    end

    local rowTerrainLighting = props:CreateRow( "#gminimap.terrain", "#gminimap.terrain_lighting" )
    rowTerrainLighting:Setup( "Boolean" )
    rowTerrainLighting:SetValue( self.terrainLighting )

    rowTerrainLighting.DataChanged = function( _, val )
        self.terrainLighting = val > 0
        OnConfigChanged()
    end

    ------ health/armor ------

    local rowShowCustom = props:CreateRow( "#gminimap.health_armor", "#gminimap.health_show_custom" )
    rowShowCustom:Setup( "Boolean" )
    rowShowCustom:SetValue( self.showCustomHealth )

    rowShowCustom.DataChanged = function( _, val )
        self.showCustomHealth = val > 0
        OnConfigChanged()
    end

    local rowHideDefault = props:CreateRow( "#gminimap.health_armor", "#gminimap.health_hide_default" )
    rowHideDefault:Setup( "Boolean" )
    rowHideDefault:SetValue( self.hideDefaultHealth )

    rowHideDefault.DataChanged = function( _, val )
        self.hideDefaultHealth = val > 0
        OnConfigChanged()
    end

    local rowHealthHeight = props:CreateRow( "#gminimap.health_armor", "#gminimap.health_height" )
    rowHealthHeight:Setup( "Int", { min = 2, max = 32 } )
    rowHealthHeight:SetValue( self.healthHeight )

    rowHealthHeight.DataChanged = function( _, val )
        self.healthHeight = math.floor( val )
        OnConfigChanged()
    end

    CreateColorRow( "#gminimap.health_armor", "#gminimap.health_color", self.healthColor, function( v )
        self.healthColor = v
        OnConfigChanged()
    end )

    CreateColorRow( "#gminimap.health_armor", "#gminimap.low_health_color", self.lowhealthColor, function( v )
        self.lowhealthColor = v
        OnConfigChanged()
    end )

    CreateColorRow( "#gminimap.health_armor", "#gminimap.armor_color", self.armorColor, function( v )
        self.armorColor = v
        OnConfigChanged()
    end )
end
