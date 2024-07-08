local Landmarks = GMinimap.Landmarks or {}

GMinimap.Landmarks = Landmarks

Landmarks.items = Landmarks.items or {}
Landmarks.blips = Landmarks.blips or {}

function Landmarks:GetSaveFileName()
    return string.format( "landmarks_%s.json", game.GetMap() )
end

function Landmarks:Save( immediate )
    if not immediate then
        -- Avoid spamming the file system
        timer.Remove( "GMinimap.SaveLandmarksDelay" )
        timer.Create( "GMinimap.SaveLandmarksDelay", 0.5, 1, function()
            self:Save( true )
        end )

        return
    end

    local data = GMinimap.ToJSON( self.items, true )
    GMinimap.SaveDataFile( self:GetSaveFileName(), data )
end

function Landmarks:Load()
    GMinimap.EnsureDataDir()

    local rawData = GMinimap.LoadDataFile( self:GetSaveFileName() )
    if not rawData then return end

    local data = GMinimap.FromJSON( rawData )
    if not table.IsSequential( data ) then return end

    table.Empty( self.items )

    local SetNumber = GMinimap.SetNumber

    for i, v in ipairs( data ) do
        local landmark = {}

        if isstring( v.label ) then
            landmark.label = v.label
        end

        if isstring( v.icon ) then
            landmark.icon = v.icon
        end

        SetNumber( landmark, "x", v.x, -50000, 50000, 0 )
        SetNumber( landmark, "y", v.y, -50000, 50000, 0 )
        SetNumber( landmark, "scale", v.scale, 0.5, 3, 1 )

        SetNumber( landmark, "r", v.r, 0, 255, 255 )
        SetNumber( landmark, "g", v.g, 0, 255, 255 )
        SetNumber( landmark, "b", v.b, 0, 255, 255 )

        self.items[i] = landmark
    end

    self:Update()
end

function Landmarks:Update()
    for i, _ in ipairs( self.blips ) do
        GMinimap:RemoveBlipById( "gminimap_landmark_" .. i )
    end

    for i, l in ipairs( self.items ) do
        self.blips[i] = GMinimap:AddBlip( {
            id = "gminimap_landmark_" .. i,
            icon = l.icon,
            color = Color( l.r, l.g, l.b ),
            lockIconAng = true,
            position = Vector( l.x, l.y, 0 ),
            scale = l.scale
        } )
    end
end

function Landmarks:SetupPanel( parent )
    local radar = vgui.Create( "GMinimap_Radar", parent )
    radar:SetOrigin( LocalPlayer():GetPos() )
    radar:SetRatio( GMinimap.World.baseZoomRatio )
    radar:AddZoomSlider()
    radar:Dock( FILL )

    local helpLabel1 = vgui.Create( "DLabel", radar )
    helpLabel1:SetTall( 16 )
    helpLabel1:SetText( "#gminimap.landmarks_help2" )
    helpLabel1:SetFont( "ChatFont" )
    helpLabel1:SetColor( color_white )

    local helpLabel2 = vgui.Create( "DLabel", radar )
    helpLabel2:SetTall( 16 )
    helpLabel2:SetText( "#gminimap.landmarks_help1" )
    helpLabel2:SetFont( "ChatFont" )
    helpLabel2:SetColor( color_white )

    local OriginalPerformLayout = radar.PerformLayout

    radar.PerformLayout = function( s, w, h )
        OriginalPerformLayout( s, w, h )

        helpLabel1:SetWide( w )
        helpLabel2:SetWide( w )
        helpLabel1:SetPos( 4, 4 )
        helpLabel2:SetPos( 4, 24 )
    end

    local L = GMinimap.GetLanguageText
    local ApplyTheme = GMinimap.Theme.Apply

    local function OnLandmarksChanged()
        self:Save()
        self:Update()
    end

    local SetEditingLine, StopEditing

    ----- Landmarks list -----

    local landmarksPanel = vgui.Create( "DPanel", parent )
    landmarksPanel:SetWide( 200 )
    landmarksPanel:SetPaintBackground( false )
    landmarksPanel:Dock( LEFT )
    landmarksPanel:DockMargin( 0, 0, 4, 0 )

    -- Landmarks header
    local landmarksHeader = vgui.Create( "DLabel", landmarksPanel )
    landmarksHeader:SetTall( 16 )
    landmarksHeader:SetText( game.GetMap() )
    landmarksHeader:SetContentAlignment( 5 )
    landmarksHeader:Dock( TOP )

    ApplyTheme( landmarksHeader )

    -- Landmarks list
    local landmarkList = vgui.Create( "DScrollPanel", landmarksPanel )
    landmarkList:Dock( FILL )
    landmarkList:DockMargin( 0, 4, 0, 0 )
    landmarkList.pnlCanvas:DockPadding( 4, 4, 4, 4 )

    -- Workaround for `URLTexturedRectRotated` not obeying panel clipping
    landmarkList.Paint = function( s, w, h )
        surface.SetDrawColor( 40, 40, 40, 200 )
        surface.DrawRect( 0, 0, w, h )

        local x, y = s:LocalToScreen( 0, 0 )
        render.SetScissorRect( x, y, x + w, y + h, true )
    end

    landmarkList.PaintOver = function()
        render.SetScissorRect( 0, 0, 0, 0, false )
    end

    local function ClearSelection()
        for _, line in ipairs( landmarkList.pnlCanvas:GetChildren() ) do
            line._themeHighlight = false
        end
    end

    local function SelectLine( index, bringToView )
        ClearSelection()

        for _, line in ipairs( landmarkList.pnlCanvas:GetChildren() ) do
            if line._landmarkIndex == index then
                SetEditingLine( line )

                if bringToView then
                    local landmark = self.items[index]
                    radar:SetOrigin( Vector( landmark.x, landmark.y, 0 ) )
                    radar:SetRatio( radar.minRatio )
                end

                return
            end
        end

        StopEditing()
    end

    local function GetLabel( landmark )
        return landmark.label or math.Round( landmark.x, 2 ) .. " / " .. math.Round( landmark.y, 2 )
    end

    local function PaintLine( s, _, h )
        local x, y = s:LocalToScreen( 0, 0 )
        SDrawUtils.URLTexturedRectRotated( s._landmarkIcon, x + h * 0.5, y + h * 0.5, h * 0.8, h * 0.8, 0, s._landmarkColor )
    end

    local function OnClickLine( s )
        SelectLine( s._landmarkIndex, true )
    end

    local function RemoveLandmarkByLine( s )
        local index = s._landmarkIndex
        local str = L ( "landmark_remove_query" ) .. "\n\n" .. GetLabel( self.items[index] )

        Derma_Query( str, L"landmark_remove", L"yes", function()
            StopEditing()
            table.remove( self.items, index )

            landmarkList.UpdateLandmarks()
            OnLandmarksChanged()
        end, "#gminimap.no" )
    end

    local function AddLine( index, landmark )
        local line = vgui.Create( "DButton", landmarkList )
        line:SetText( GetLabel( landmark ) )
        line:SetTall( 24 )
        line:Dock( TOP )
        line:DockMargin( 0, 0, 0, 2 )

        ApplyTheme( line )

        line._landmarkIndex = index
        line._landmarkIcon = landmark.icon
        line._landmarkColor = Color( landmark.r, landmark.g, landmark.b )
        line.PaintOver = PaintLine
        line.DoClick = OnClickLine
        line.DoRightClick = RemoveLandmarkByLine
    end

    landmarkList.UpdateLandmarks = function()
        StopEditing()
        landmarkList:Clear()

        for i, v in ipairs( self.items ) do
            AddLine( i, v )
        end
    end

    radar.OnRightClickPosition = function( _, pos )
        local index = #self.items + 1

        local landmark = {
            x = pos.x,
            y = pos.y,
            icon = "gminimap/blips/star.png",
            r = 255,
            g = 255,
            b = 255,
            scale = 1.5
        }

        self.items[index] = landmark

        ClearSelection()
        OnLandmarksChanged()

        AddLine( index, landmark )
        SelectLine( index )
    end

    ----- Landmark editor -----

    local editing

    local CreateHeader = GMinimap.CreateHeader
    local CreateSlider = GMinimap.CreateSlider
    local CreateColorPicker = GMinimap.CreateColorPicker

    local function CreateMenuPanel( class, w, h )
        local pnl = vgui.Create( class )
        pnl:SetSize( w, h )

        local m = DermaMenu()
        m:AddPanel( pnl )
        m:SetPaintBackground( false )
        m:Open( gui.MouseX() + 8, gui.MouseY() + 10 )

        return pnl
    end

    local landmarkEditor = vgui.Create( "DScrollPanel", landmarksPanel )
    landmarkEditor:SetTall( 0 )
    landmarkEditor:Dock( BOTTOM )
    landmarkEditor:DockMargin( 0, 4, 0, 0 )
    landmarkEditor.pnlCanvas:DockPadding( 4, 4, 4, 4 )

    ApplyTheme( landmarkEditor )

    -- Landmark label
    CreateHeader( L"landmark_label", landmarkEditor, 0, 0, 0, 4 ):SetTall( 18 )

    local editLabelEntry = vgui.Create( "DTextEntry", landmarkEditor )
    editLabelEntry:Dock( TOP )
    editLabelEntry:SetUpdateOnType( true )

    ApplyTheme( editLabelEntry )

    editLabelEntry.OnChange = function( s )
        if not editing then return end

        local label = string.Trim( s:GetValue() )

        editing.landmark.label = Either( label == "", nil, label )
        editing.line:SetText( GetLabel( editing.landmark ) )

        OnLandmarksChanged()
    end

    -- Landmark icon
    CreateHeader( L"landmark_icon", landmarkEditor, 0, 4, 0, 4 ):SetTall( 18 )

    local editIconPanel = vgui.Create( "DPanel", landmarkEditor )
    editIconPanel:Dock( TOP )
    editIconPanel:DockMargin( 0, 4, 0, 0 )
    editIconPanel:SetPaintBackground( false )

    local function OnSelectIcon( path )
        if not editing then return end

        editing.landmark.icon = path
        editing.line._landmarkIcon = path

        OnLandmarksChanged()
    end

    local selBuiltinButton = vgui.Create( "DButton", editIconPanel )
    selBuiltinButton:SetText( L"builtin_icons" )
    selBuiltinButton:Dock( FILL )
    selBuiltinButton:DockMargin( 0, 2, 0, 2 )

    ApplyTheme( selBuiltinButton )

    selBuiltinButton.DoClick = function()
        local iconsPanel = CreateMenuPanel( "DScrollPanel", 256, 256 )
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
    selSilkButton:SetText( L"gmod_icons" )
    selSilkButton:Dock( RIGHT )
    selSilkButton:DockMargin( 2, 2, 0, 2 )

    ApplyTheme( selSilkButton )

    selSilkButton.DoClick = function()
        local iconBrowser = CreateMenuPanel( "DIconBrowser", 256, 256 )

        iconBrowser.OnChange = function( s )
            OnSelectIcon( s:GetSelectedIcon() )
            CloseDermaMenus()
        end
    end

    local editScaleSlider = CreateSlider( landmarkEditor, L"scale", 1, 0.5, 2, 2, function( value )
        if not editing then return end

        editing.landmark.scale = value
        OnLandmarksChanged()
    end )

    editScaleSlider.PerformLayout = function( s )
        s.Label:SizeToContents()
    end

    editScaleSlider:SetTall( 20 )
    editScaleSlider:DockMargin( 0, 6, 0, 6 )

    -- Landmark icon color
    CreateHeader( L"landmark_icon_color", landmarkEditor, 0, 4, 0, 4 ):SetTall( 18 )

    local editColor = CreateColorPicker( landmarkEditor, nil, function( c )
        if not editing then return end

        editing.landmark.r = c.r
        editing.landmark.g = c.g
        editing.landmark.b = c.b
        editing.line._landmarkColor = Color( c.r, c.g, c.b )

        OnLandmarksChanged()
    end )

    editColor:SetTall( 200 )

    local removeButton = vgui.Create( "DButton", landmarkEditor )
    removeButton:SetTall( 20 )
    removeButton:SetText( L"landmark_remove" )
    removeButton:Dock( TOP )
    removeButton:DockMargin( 0, 6, 0, 0 )

    ApplyTheme( removeButton )

    removeButton.DoClick = function()
        RemoveLandmarkByLine( editing.line )
    end

    ----- Define the editing functions

    StopEditing = function()
        editing = nil
        landmarkEditor:SizeTo( -1, 0, 0.2, 0, 0.5 )
        editLabelEntry:SetPlaceholderText( "" )
        editLabelEntry:SetValue( "" )
    end

    StopEditing()

    SetEditingLine = function( line )
        if not line then
            StopEditing()
            return
        end

        if editing and line == editing.line then
            StopEditing()
            return
        end

        timer.Simple( editing == nil and 0.5 or 0, function()
            if IsValid( landmarkList ) then
                landmarkList:ScrollToChild( line )
            end
        end )

        landmarkEditor:SizeTo( -1, 200, 0.2, 0, 0.3 )
        line._themeHighlight = true

        editing = {
            line = line,
            landmark = self.items[line._landmarkIndex]
        }

        editLabelEntry:SetPlaceholderText( GetLabel( editing.landmark ) )
        editLabelEntry:SetValue( editing.landmark.label or "" )
        editScaleSlider:SetValue( editing.landmark.scale )
        editColor:SetColor( Color( editing.landmark.r, editing.landmark.g, editing.landmark.b ) )
    end

    landmarkList.UpdateLandmarks()
end

Landmarks:Load()
