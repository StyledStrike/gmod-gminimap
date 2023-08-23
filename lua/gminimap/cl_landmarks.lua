GMinimap.landmarks = GMinimap.landmarks or {}
GMinimap.landmarkBlips = GMinimap.landmarkBlips or {}

local function RefreshLandmarkBlips()
    for i, _ in ipairs( GMinimap.landmarkBlips ) do
        GMinimap:RemoveBlipById( "gminimap_landmark_" .. i )
    end

    for i, l in ipairs( GMinimap.landmarks ) do
        GMinimap.landmarkBlips[i] = GMinimap:AddBlip( {
            id = "gminimap_landmark_" .. i,
            icon = l.icon,
            color = Color( l.r, l.g, l.b ),
            lockIconAng = true,
            position = Vector( l.x, l.y, 0 ),
            scale = l.scale
        } )
    end
end

local function GetLandmarkFileName()
    return string.format( "%slandmarks_%s.json", GMinimap.dataFolder, game.GetMap() )
end

local function SaveLandmarks()
    GMinimap.EnsureDataFolder()

    file.Write(
        GetLandmarkFileName(),
        util.TableToJSON( GMinimap.landmarks )
    )
end

local function LoadLandmarks()
    GMinimap.EnsureDataFolder()

    local rawData = file.Read( GetLandmarkFileName(), "DATA" )
    if not rawData then return end

    local data = util.JSONToTable( rawData )
    if not data then return end
    if not table.IsSequential( data ) then return end

    table.Empty( GMinimap.landmarks )

    local SetNumber = GMinimap.SetNumber

    for i, v in ipairs( data ) do
        local landmark = {}

        if isstring( v.label ) then
            landmark.label = v.label
        end

        if isstring( v.icon ) then
            landmark.icon = v.icon
        end

        SetNumber( landmark, "x", v.x, -50000, 50000 )
        SetNumber( landmark, "y", v.y, -50000, 50000 )
        SetNumber( landmark, "scale", v.scale, 0.5, 3 )

        SetNumber( landmark, "r", v.r, 0, 255 )
        SetNumber( landmark, "g", v.g, 0, 255 )
        SetNumber( landmark, "b", v.b, 0, 255 )

        GMinimap.landmarks[i] = landmark
    end

    RefreshLandmarkBlips()
end

LoadLandmarks()

function GMinimap:OpenLandmarks()
    if IsValid( self.landmarksFrame ) then
        self.landmarksFrame:Close()
        self.landmarksFrame = nil

        return
    end

    local frame = vgui.Create( "DFrame" )
    frame:SetTitle( "#gminimap.landmarks" )
    frame:SetIcon( "icon16/flag_blue.png" )
    frame:SetSizable( false )
    frame:SetDraggable( true )
    frame:SetSize( 700, 500 )
    frame:SetDeleteOnClose( true )
    frame:Center()
    frame:MakePopup()

    self.landmarksFrame = frame

    local radar = GMinimap.CreateRadar()
    radar.origin = LocalPlayer():GetPos()
    radar.ratio = GMinimap.GetWorldZoomRatio()

    frame.OnClose = function()
        radar:Destroy()
        radar = nil
    end

    function OnLandmarksChanged()
        RefreshLandmarkBlips()

        -- prevent spamming the file system
        timer.Remove( "CMinimap.SaveLandmarksDelay" )
        timer.Create( "CMinimap.SaveLandmarksDelay", 1, 1, SaveLandmarks )
    end

    local function GetLabel( landmark )
        return landmark.label or math.Round( landmark.x, 2 ) .. " / " .. math.Round( landmark.y, 2 )
    end

    local function PaintDarkBackground( _, w, h )
        surface.SetDrawColor( 50, 50, 50, 255 )
        surface.DrawRect( 0, 0, w, h )
    end

    local helpPanel = vgui.Create( "DPanel", frame )
    helpPanel:SetTall( 50 )
    helpPanel:Dock( BOTTOM )
    helpPanel.Paint = PaintDarkBackground

    local helpLabel1 = vgui.Create( "DLabel", helpPanel )
    helpLabel1:SetAutoStretchVertical( true )
    helpLabel1:SetText( "#gminimap.landmarks_help1" )
    helpLabel1:SetFont( "ChatFont" )
    helpLabel1:SetColor( color_white )
    helpLabel1:Dock( TOP )
    helpLabel1:DockMargin( 4, 12, 4, 4 )

    local helpLabel2 = vgui.Create( "DLabel", helpPanel )
    helpLabel2:SetAutoStretchVertical( true )
    helpLabel2:SetText( "#gminimap.landmarks_help2" )
    helpLabel2:SetFont( "ChatFont" )
    helpLabel2:SetColor( color_white )
    helpLabel2:Dock( BOTTOM )
    helpLabel2:DockMargin( 4, 4, 4, 4 )

    ---------- map terrain panel ----------

    local mapPanel = vgui.Create( "DPanel", frame )
    mapPanel:Dock( FILL )

    mapPanel.PerformLayout = function( _, w, h )
        radar:SetDimensions( 0, 0, w, h )
    end

    local landmarksPanel = vgui.Create( "DPanel", frame )
    landmarksPanel:Dock( RIGHT )
    landmarksPanel:SetWide( 200 )

    ---------- landmarks list panel ----------

    local bmkList = vgui.Create( "DListView", landmarksPanel )
    bmkList:Dock( FILL )
    bmkList:SetSortable( false )
    bmkList:SetMultiSelect( false )
    bmkList:AddColumn( game.GetMap() )

    local function PaintIcon( s, w, h )
        local x, y = s:LocalToScreen( 0, 0 )
        SDrawUtils.URLTexturedRectRotated( s._icon, x + w * 0.5, y + h * 0.5, w, h, 0, s._color )
    end

    local function AddLandmarkLine( index, landmark, selected )
        local line = bmkList:AddLine( GetLabel( landmark ) )

        local pIcon = vgui.Create( "DPanel", line )
        pIcon:Dock( RIGHT )
        pIcon:DockMargin( 0, 0, 4, 0 )
        pIcon:SetWide( 16 )

        line._landmarkIndex = index
        line._panelIcon = pIcon

        pIcon._icon = landmark.icon
        pIcon._color = Color( landmark.r, landmark.g, landmark.b )
        pIcon.Paint = PaintIcon

        if selected then
            bmkList._selectedByAdding = true
            bmkList:ClearSelection()
            bmkList:SelectItem( line )
            bmkList._selectedByAdding = nil
        end
    end

    function UpdateLandmarksList()
        bmkList:Clear()

        for i, v in ipairs( self.landmarks ) do
            AddLandmarkLine( i, v )
        end
    end

    local function AddLandmark( pos, icon, color )
        local index = #self.landmarks + 1
        local landmark = {
            x = pos.x,
            y = pos.y,
            icon = icon,
            r = color.r,
            g = color.g,
            b = color.b,
            scale = 1.5
        }

        self.landmarks[index] = landmark

        AddLandmarkLine( index, landmark, true )
        OnLandmarksChanged()
    end

    UpdateLandmarksList()

    ---------- landmark editor panel ----------

    local function CreateMenuPanel( class, w, h )
        local pnl = vgui.Create( class, self )
        pnl:SetSize( w, h )

        local m = DermaMenu()
        m:AddPanel( pnl )
        m:SetPaintBackground( false )
        m:Open( gui.MouseX() + 8, gui.MouseY() + 10 )

        return pnl
    end

    local editing

    local editPanel = vgui.Create( "DDrawer", landmarksPanel )
    editPanel:Dock( BOTTOM )
    editPanel:DockPadding( 4, 12, 4, 4 )
    editPanel:SetOpenSize( 260 )
    editPanel:SetOpenTime( 0.2 )
    editPanel.Paint = PaintDarkBackground

    local editLabelEntry = vgui.Create( "DTextEntry", editPanel )
    editLabelEntry:Dock( TOP )
    editLabelEntry:SetUpdateOnType( true )

    editLabelEntry.OnChange = function( s )
        if not editing then return end

        local label = string.Trim( s:GetValue() )

        editing.landmark.label = Either( label == "", nil, label )
        editing.line:SetColumnText( 1, GetLabel( editing.landmark ) )

        OnLandmarksChanged()
    end

    local editIconPanel = vgui.Create( "DPanel", editPanel )
    editIconPanel:Dock( TOP )
    editIconPanel:DockMargin( 0, 4, 0, 0 )
    editIconPanel:SetPaintBackground( false )

    local function OnSelectIcon( path )
        if not editing then return end

        editing.landmark.icon = path
        editing.line._panelIcon._icon = path

        OnLandmarksChanged()
    end

    local selBuiltinButton = vgui.Create( "DButton", editIconPanel )
    selBuiltinButton:SetText( "#gminimap.builtin_icons" )
    selBuiltinButton:Dock( FILL )
    selBuiltinButton:DockMargin( 0, 2, 0, 2 )

    selBuiltinButton.DoClick = function()
        local iconsPanel = CreateMenuPanel( "DScrollPanel", 256, 128 )
        iconsPanel:SetPaintBackground( true )

        local iconLayout = vgui.Create( "DIconLayout", iconsPanel )
        iconLayout:SetSpaceX( 4 )
        iconLayout:SetSpaceY( 4 )
        iconLayout:SetBorder( 4 )
        iconLayout:Dock( FILL )

        local function OnClickIcon( s )
            OnSelectIcon( s:GetImage() )
            CloseDermaMenus()
        end

        local iconList = file.Find( "materials/gminimap/blips/*.png", "GAME" )

        for _, v in ipairs( iconList ) do
            local btn = iconLayout:Add( "DImageButton" )

            btn:SetOnViewMaterial( "gminimap/blips/" .. v )
            btn:SetTooltip( btn:GetImage() )
            btn:SetSize( 32, 32 )
            btn:SetStretchToFit( true )
            btn.DoClick = OnClickIcon
        end

        iconLayout:Layout()
    end

    local selSilkButton = vgui.Create( "DButton", editIconPanel )
    selSilkButton:SetText( "#gminimap.gmod_icons" )
    selSilkButton:Dock( RIGHT )
    selSilkButton:DockMargin( 2, 2, 0, 2 )

    selSilkButton.DoClick = function()
        local iconBrowser = CreateMenuPanel( "DIconBrowser", 256, 256 )

        iconBrowser.OnChange = function( s )
            OnSelectIcon( s:GetSelectedIcon() )
            CloseDermaMenus()
        end
    end

    local editScaleSlider = vgui.Create( "DNumSlider", editPanel )
    editScaleSlider:SetText( "#gminimap.scale" )
    editScaleSlider:SetMin( 0.5 )
    editScaleSlider:SetDecimals( 3 )
    editScaleSlider:SetMax( 2 )
    editScaleSlider:Dock( TOP )
    editScaleSlider:DockMargin( 0, 4, 0, 0 )

    editScaleSlider.OnValueChanged = function( _, value )
        editing.landmark.scale = value
        OnLandmarksChanged()
    end

    local editColor = vgui.Create( "DColorMixer", editPanel )
    editColor:Dock( TOP )
    editColor:DockMargin( 0, 4, 0, 0 )
    editColor:SetPalette( true )
    editColor:SetAlphaBar( false )
    editColor:SetWangs( false )
    editColor:SetTall( 150 )

    editColor.ValueChanged = function( _, c )
        if not editing then return end

        editing.landmark.r = c.r
        editing.landmark.g = c.g
        editing.landmark.b = c.b
        editing.line._panelIcon._color = Color( c.r, c.g, c.b )

        OnLandmarksChanged()
    end

    local function StopEditing()
        bmkList:ClearSelection()

        editing = nil
        editPanel:Close()

        editLabelEntry:SetDisabled( true )
        editLabelEntry:SetPlaceholderText( "" )
        editLabelEntry:SetValue( "" )

        selBuiltinButton:SetEnabled( false )
        selSilkButton:SetEnabled( false )
        editScaleSlider:SetEnabled( false )
        editColor:SetEnabled( false )
    end

    StopEditing()

    bmkList.OnRowRightClick = function( _, _, row )
        local index = row._landmarkIndex
        local str = language.GetPhrase( "#gminimap.landmark_remove_query" ) .. "\n\n" .. GetLabel( self.landmarks[index] )

        Derma_Query( str, "#gminimap.landmark_remove", "#gminimap.yes", function()
            StopEditing()
            table.remove( self.landmarks, index )

            UpdateLandmarksList()
            OnLandmarksChanged()
        end, "#gminimap.no" )
    end

    bmkList.OnRowSelected = function( _, _, row )
        local index = row._landmarkIndex

        editing = {
            line = row,
            index = index,
            landmark = self.landmarks[index]
        }

        editPanel:Open()

        if not bmkList._selectedByAdding then
            radar.origin = Vector( editing.landmark.x, editing.landmark.y, 0 )
            radar.ratio = GMinimap.GetWorldZoomRatio() * 0.25
            mapPanel:InvalidateLayout()
        end

        editLabelEntry:SetDisabled( false )
        editLabelEntry:SetPlaceholderText( GetLabel( editing.landmark ) )
        editLabelEntry:SetValue( editing.landmark.label or "" )

        selBuiltinButton:SetEnabled( true )
        selSilkButton:SetEnabled( true )

        editScaleSlider:SetEnabled( true )
        editScaleSlider:SetValue( editing.landmark.scale )

        editColor:SetEnabled( true )
        editColor:SetColor( Color( editing.landmark.r, editing.landmark.g, editing.landmark.b ) )
    end

    ---------- map terrain rendering & input ----------

    mapPanel.PaintOver = function( s )
        local x, y = s:LocalToScreen( 0, 0 )

        radar.x = x
        radar.y = y
        radar:Draw()
        self:DrawBlips( radar )

        if s._originStart then
            x, y = input.GetCursorPos()

            local diffX = ( mapPanel._mouseStartX - x ) * radar.ratio
            local diffY = ( mapPanel._mouseStartY - y ) * radar.ratio

            radar.origin.y = s._originStart.y - diffX
            radar.origin.x = s._originStart.x - diffY
        end
    end

    mapPanel.OnMousePressed = function( _, keyCode )
        local x, y = input.GetCursorPos()

        if keyCode == MOUSE_LEFT then
            mapPanel._originStart = Vector( radar.origin.x, radar.origin.y, 0 )
            mapPanel._mouseStartX = x
            mapPanel._mouseStartY = y
        else
            x, y = mapPanel:ScreenToLocal( x, y )
            AddLandmark( radar:LocalToWorld( x, y ), "gminimap/blips/star.png", color_white )
        end
    end

    mapPanel.OnMouseReleased = function()
        mapPanel._originStart = nil
        mapPanel._mouseStartX = nil
        mapPanel._mouseStartY = nil
    end

    mapPanel.OnCursorExited = function()
        mapPanel._originStart = nil
        mapPanel._mouseStartX = nil
        mapPanel._mouseStartY = nil
    end

    mapPanel.OnMouseWheeled = function( _, delta )
        local baseRatio = GMinimap.GetWorldZoomRatio()
        radar.ratio = math.Clamp( radar.ratio - delta * 5, baseRatio * 0.2, baseRatio )
        mapPanel:InvalidateLayout()
    end
end
