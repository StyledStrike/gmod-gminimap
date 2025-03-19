--[[
    This file manages map-specific settings, such as
    terrain layers, base zoom ratio, world size, etc.
]]
local World = GMinimap.World or {}

GMinimap.World = World

function World:Reset()
    self.baseZoomRatio = 50

    -- World heights, set when the data file exists.
    self.bottom = nil
    self.top = nil

    -- List of vertical slices of the map
    self.layers = {}

    -- Places on the world that activate layers
    self.triggers = {}

    -- Trigger check variables
    self.triggerCount = 0
    self.lastTriggerIndex = 0
    self.triggerLayerIndex = 0
    self.activeLayerIndex = 0

    local world = game.GetWorld()
    if not IsValid( world ) then return end
    if not world.GetModelBounds then return end

    local mins, maxs = world:GetModelBounds()

    -- World heights, used when the data file does not exist.
    -- Assume it's the whole map if we haven't received
    -- accurate dimensions from the server yet.
    if not self.serverBottom then
        self.serverBottom = mins.z
        self.serverTop = maxs.z
    end

    -- Try to figure out the best zoom level for this map.
    local sizeX = maxs.x + math.abs( mins.x )
    local sizeY = maxs.y + math.abs( mins.y )
    local avg = ( sizeX + sizeY ) * 0.5

    self.baseZoomRatio = ( avg / 25000 ) * 50
end

World:Reset()

--- Load current map settings from `data_static/` if it exists.
function World:LoadFromFile()
    self:Reset()

    local path = "data_static/gminimap/" .. game.GetMap() .. ".json"
    local data = file.Read( path, "GAME" )

    if not data then
        GMinimap.Print( "Map settings file '%s' does not exist, using defaults.", path )
        return
    end

    data = GMinimap.FromJSON( data )

    local SetNumber = GMinimap.SetNumber

    SetNumber( self, "bottom", data.bottom, -50000, 50000, nil )
    SetNumber( self, "top", data.top, -50000, 50000, nil )
    SetNumber( self, "baseZoomRatio", data.baseZoomRatio, 1, 100, self.baseZoomRatio )

    if type( data.layers ) == "table" and table.IsSequential( data.layers ) then
        for i, l in ipairs( data.layers ) do
            local layer = {}

            SetNumber( layer, "bottom", l.bottom, -50000, 50000, nil )
            SetNumber( layer, "top", l.top, -50000, 50000, nil )

            self.layers[i] = layer
        end
    else
        GMinimap.Print( "Map settings has no layers." )
    end

    local function SortVectors( ax, ay, az, bx, by, bz )
        return
            math.min( ax, bx ),
            math.min( ay, by ),
            math.min( az, bz ),

            math.max( ax, bx ),
            math.max( ay, by ),
            math.max( az, bz )
    end

    if type( data.triggers ) == "table" and table.IsSequential( data.triggers ) then
        for i, trigger in ipairs( data.triggers ) do
            local t = {}

            SetNumber( t, "layerIndex", trigger.layerIndex, 0, 1000, 1 )

            SetNumber( t, "ax", trigger.ax, -50000, 50000, 0 )
            SetNumber( t, "ay", trigger.ay, -50000, 50000, 0 )
            SetNumber( t, "az", trigger.az, -50000, 50000, 0 )

            SetNumber( t, "bx", trigger.bx, -50000, 50000, 0 )
            SetNumber( t, "by", trigger.by, -50000, 50000, 0 )
            SetNumber( t, "bz", trigger.bz, -50000, 50000, 0 )

            t.ax, t.ay, t.az, t.bx, t.by, t.bz = SortVectors(
                t.ax, t.ay, t.az,
                t.bx, t.by, t.bz
            )

            self.triggers[i] = t
        end

        self.triggerCount = #self.triggers
    else
        GMinimap.Print( "Map settings has no layer triggers." )
    end

    GMinimap.Print( "Loaded map settings file: %s", path )
end

function World:GetHeights()
    return
        self.layerBottom or self.bottom or self.serverBottom or -5000,
        self.layerTop or self.top or self.serverTop or 5000
end

function World:GetHeightsNoLayer()
    return
        self.bottom or self.serverBottom or -5000,
        self.top or self.serverTop or 5000
end

local function IsWithinTrigger( v, t )
    if v[1] < t.ax or v[1] > t.bx then return false end
    if v[2] < t.ay or v[2] > t.by then return false end
    if v[3] < t.az or v[3] > t.bz then return false end

    return true
end

function World:SetActiveLayer( index )
    local layer = self.layers[index]

    if layer then
        self.layerTop = layer.top
        self.layerBottom = layer.bottom
    else
        self.layerTop = nil
        self.layerBottom = nil
    end

    GMinimap:UpdateLayout()
end

function World:CheckTriggers()
    if self.triggerCount == 0 then return end

    local index = self.lastTriggerIndex + 1

    -- We've iterated over all triggers, time to check
    if index > self.triggerCount then
        index = 1

        if self.triggerLayerIndex ~= self.activeLayerIndex then
            self.activeLayerIndex = self.triggerLayerIndex
            self:SetActiveLayer( self.activeLayerIndex )
        end

        self.triggerLayerIndex = 0
    end

    self.lastTriggerIndex = index

    -- Do one trigger check per frame
    local checkPos = LocalPlayer():EyePos()

    if IsWithinTrigger( checkPos, self.triggers[index] ) then
        self.triggerLayerIndex = self.triggers[index].layerIndex
    end
end

net.Receive( "gminimap.world_heights", function()
    World.serverBottom = net.ReadFloat()
    World.serverTop = net.ReadFloat()
    World.activeLayerIndex = 0
    World:SetActiveLayer( 0 )

    GMinimap.Print( "Received world heights from server: %f, %f", World.serverBottom, World.serverTop )
end )

hook.Add( "InitPostEntity", "GMinimap.SetupWorld", function()
    World:LoadFromFile()
end )

concommand.Add(
    "gminimap_layers",
    function() World:OpenLayers() end,
    nil,
    "Opens the GMinimap layers editor."
)

function World:OpenLayers()
    local L = GMinimap.GetLanguageText
    local ApplyTheme = StyledTheme.Apply
    local ScaleSize = StyledTheme.ScaleSize

    local frame = vgui.Create( "DFrame" )
    frame:SetTitle( L"layers" )
    frame:SetIcon( "icon16/shape_move_forwards.png" )
    frame:SetSize( ScaleSize( 1200 ), ScaleSize( 700 ) )
    frame:SetSizable( true )
    frame:SetDraggable( true )
    frame:SetDeleteOnClose( true )
    frame:SetMinWidth( ScaleSize( 1000 ) )
    frame:SetMinHeight( ScaleSize( 600 ) )
    frame:Center()
    frame:MakePopup()

    ApplyTheme( frame )

    frame.OnClose = function()
        self.activeLayerIndex = 0
    end

    local menuBar = vgui.Create( "DMenuBar", frame )
    ApplyTheme( menuBar )

    local container = vgui.Create( "DPanel", frame )
    container:SetPaintBackground( false )
    container:Dock( FILL )

    local radar = vgui.Create( "GMinimap_Radar", container )
    radar:SetRatio( GMinimap.World.baseZoomRatio )
    radar:AddZoomSlider()
    radar:Dock( FILL )

    local rightPanel = vgui.Create( "DPanel", frame )
    rightPanel:SetWide( ScaleSize( 340 ) )
    rightPanel:SetPaintBackground( false )
    rightPanel:Dock( RIGHT )
    rightPanel:DockMargin( ScaleSize( 4 ), 0, 0, 0 )

    local layerList = vgui.Create( "DScrollPanel", rightPanel )
    layerList:Dock( FILL )
    ApplyTheme( layerList )

    local selectedItem

    local function GetItems()
        return layerList.pnlCanvas:GetChildren()
    end

    local function SelectItem( item )
        selectedItem = nil

        for _, v in ipairs( GetItems() ) do
            if v == item then
                selectedItem = v
                v._isSelected = true
            else
                v._isSelected = false
            end
        end

        if not selectedItem then return end

        timer.Simple( 0.1, function()
            if IsValid( layerList ) then
                layerList:ScrollToChild( selectedItem )
            end
        end )

        radar:SetHeights( selectedItem._layer.bottom, selectedItem._layer.top )
        self:SetActiveLayer( selectedItem._index )
    end

    local function OnItemChanged( item )
        local layer = item._layer

        if layer.isDefault then
            self.top = layer.top
            self.bottom = layer.bottom
        end

        SelectItem( item )
    end

    -- Item panel functions
    local colors = StyledTheme.colors

    local function PaintItem( s, w, h )
        local bgColor = s._isSelected and colors.buttonPress or colors.panelBackground

        surface.SetDrawColor( bgColor:Unpack() )
        surface.DrawRect( 0, 0, w, h )
    end

    local function SliderPerformLayout( s )
        s.Label:SetWide( ScaleSize( 80 ) )
    end

    -- Item panel creation
    local spacing = ScaleSize( 4 )
    local padding = ScaleSize( 6 )

    local function AddItem( layer, label, index )
        local item = vgui.Create( "DPanel", layerList )
        item:Dock( TOP )
        item:DockMargin( 0, spacing, 0, 0 )
        item:DockPadding( padding, 0, padding, padding )

        layer.top = layer.top or 5000
        layer.bottom = layer.bottom or -5000

        item._index = index
        item._layer = layer
        item.Paint = PaintItem
        item.OnMousePressed = SelectItem

        local header = StyledTheme.CreateFormHeader( item, L( "layer_boundaries" ):format( label ), 0 )
        header:SetMouseInputEnabled( false )

        local sliderTop = StyledTheme.CreateFormSlider( item, L"layer_top", layer.top, -20000, 20000, 0, function( value )
            layer.top = value
            OnItemChanged( item )
        end )

        item._sliderTop = sliderTop
        sliderTop.PerformLayout = SliderPerformLayout

        local sliderBottom = StyledTheme.CreateFormSlider( item, L"layer_bottom", layer.bottom, -20000, 20000, 0, function( value )
            layer.bottom = value
            OnItemChanged( item )
        end )

        item._sliderBottom = sliderBottom
        sliderBottom.PerformLayout = SliderPerformLayout

        item:InvalidateLayout( true )
        item:SizeToChildren( false, true )

        return item
    end

    -- Update the list of items
    local function UpdateList()
        layerList:Clear()

        local bottom, top = World:GetHeightsNoLayer()

        local defaultItem = AddItem( {
            isDefault = true,
            bottom = bottom,
            top = top
        }, L"layer_default", 0 )

        SelectItem( defaultItem )

        for i, layer in ipairs( self.layers ) do
            AddItem( layer, L( "layer_number" ):format( i ), i )
        end
    end

    UpdateList()

    -- Menu functions
    local fileMenu = menuBar:AddMenu( L"file" )

    fileMenu:AddOption( L"import", function()
        local path = "data_static/gminimap/" .. game.GetMap() .. ".json"

        if not file.Exists( path, "GAME" ) then
            Derma_Message( L( "map_settings_not_found" ):format( path ), L"import", L"ok" )
            return
        end

        World:LoadFromFile()
        UpdateList()
        hook.Run( "OnGMinimapConfigChange" )

        Derma_Message( L( "map_settings_found" ):format( path ), L"import", L"ok" )
    end ):SetIcon( "icon16/page_white_get.png" )

    fileMenu:AddOption( L"export", function()
        local bottom, top = World:GetHeightsNoLayer()

        local data = {
            top = top,
            bottom = bottom
        }

        if #self.layers > 0 then
            data.layers = self.layers
        end

        if #self.triggers > 0 then
            data.triggers = self.triggers
        end

        data = util.TableToJSON( data, true )

        local frameExport = vgui.Create( "DFrame" )
        frameExport:SetTitle( L"export" )
        frameExport:SetIcon( "icon16/page_white_go.png" )
        frameExport:SetSize( ScaleSize( 700 ), ScaleSize( 600 ) )
        frameExport:SetSizable( false )
        frameExport:SetDraggable( true )
        frameExport:SetDeleteOnClose( true )
        frameExport:Center()
        frameExport:MakePopup()

        ApplyTheme( frameExport )

        local helpLabel1 = vgui.Create( "DLabel", frameExport )
        helpLabel1:SetText( L"export_tip1" )
        helpLabel1:SetContentAlignment( 5 )
        helpLabel1:Dock( TOP )
        ApplyTheme( helpLabel1 )

        local path = string.format( "%s/data_static/gminimap/%s.json", L"export_tip2", game.GetMap() )
        padding = ScaleSize( 12 )

        local pathEntry = vgui.Create( "DTextEntry", frameExport )
        pathEntry:SetEnabled( false )
        pathEntry:SetValue( path )
        pathEntry:Dock( TOP )
        pathEntry:DockMargin( padding, padding, padding, padding )
        ApplyTheme( pathEntry )

        local helpLabel2 = vgui.Create( "DLabel", frameExport )
        helpLabel2:SetText( L"export_tip3" )
        helpLabel2:SetContentAlignment( 5 )
        helpLabel2:Dock( TOP )
        ApplyTheme( helpLabel2 )

        local codeEntry = vgui.Create( "DTextEntry", frameExport )
        codeEntry:SetEnabled( false )
        codeEntry:SetMultiline( true )
        codeEntry:SetValue( data )
        codeEntry:Dock( FILL )
        codeEntry:DockMargin( padding, padding, padding, padding )

        ApplyTheme( codeEntry )

        local buttonCopy = vgui.Create( "DButton", frameExport )
        buttonCopy:SetText( L"copy_code" )
        buttonCopy:Dock( BOTTOM )

        ApplyTheme( buttonCopy )

        buttonCopy.DoClick = function()
            SetClipboardText( data )
            buttonCopy:SetText( L"code_copied" )
        end
    end ):SetIcon( "icon16/page_white_go.png" )

    local layersMenu = menuBar:AddMenu( L"layers" )

    layersMenu:AddOption( L"add_layer", function()
        local index = #self.layers + 1

        self.layers[index] = {}
        UpdateList()

        local items = GetItems()
        SelectItem( items[#items] )
    end ):SetIcon( "icon16/shape_square_add.png" )

    layersMenu:AddOption( L"remove_layer", function()
        if not selectedItem then return end

        if selectedItem._layer.isDefault then
            Derma_Message( L"remove_layer_blocked", L"remove_layer", L"ok" )
            return
        end

        table.remove( self.layers, selectedItem._index )
        selectedItem:Remove()
        UpdateList()
    end ):SetIcon( "icon16/shape_square_delete.png" )

    layersMenu:AddOption( L"layer_user_position", function()
        if not selectedItem then return end

        local top, bottom = GMinimap.GetHeightsAround( LocalPlayer():EyePos(), 50000 )

        top = top + 1000
        bottom = bottom - 1000

        selectedItem._layer.top = top
        selectedItem._layer.bottom = bottom

        selectedItem._sliderTop:SetValue( top )
        selectedItem._sliderBottom:SetValue( bottom )

        SelectItem( selectedItem )
    end ):SetIcon( "icon16/shape_square_go.png" )
end
