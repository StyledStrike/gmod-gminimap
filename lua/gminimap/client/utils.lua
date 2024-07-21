function GMinimap.GetLanguageText( id )
    return language.GetPhrase( "gminimap." .. id ):Trim()
end

function GMinimap.ValidateNumber( v, min, max, default )
    return math.Clamp( tonumber( v ) or default or 0, min, max )
end

function GMinimap.SetNumber( t, k, v, min, max, default )
    if v ~= nil then
        t[k] = GMinimap.ValidateNumber( v, min, max, default )
    end
end

function GMinimap.SetBool( t, k, v )
    t[k] = tobool( v )
end

function GMinimap.SetColor( t, k, r, g, b )
    if r or g or b then
        t[k] = Color(
            GMinimap.ValidateNumber( r, 0, 255, 255 ),
            GMinimap.ValidateNumber( g, 0, 255, 255 ),
            GMinimap.ValidateNumber( b, 0, 255, 255 ),
            255
        )
    end
end

function GMinimap.ToJSON( tbl, prettyPrint )
    return util.TableToJSON( tbl, prettyPrint )
end

function GMinimap.FromJSON( str )
    if not str or str == "" then
        return {}
    end

    return util.JSONToTable( str ) or {}
end

function GMinimap.EnsureDataDir()
    if not file.Exists( GMinimap.DATA_DIR, "DATA" ) then
        file.CreateDir( GMinimap.DATA_DIR )
    end
end

function GMinimap.LoadDataFile( path )
    return file.Read( GMinimap.DATA_DIR .. path, "DATA" )
end

function GMinimap.SaveDataFile( path, data )
    GMinimap.Print( "%s: writing %s", path, string.NiceSize( string.len( data ) ) )
    GMinimap.EnsureDataDir()

    file.Write( GMinimap.DATA_DIR .. path, data )
end

local ApplyTheme = GMinimap.ApplyTheme

function GMinimap.CreateToggleButton( parent, label, isChecked, callback )
    local button = vgui.Create( "DButton", parent )
    button:SetTall( 30 )
    button:SetIcon( isChecked and "icon16/accept.png" or "icon16/cancel.png" )
    button:SetText( label )
    button:Dock( TOP )
    button:DockMargin( 0, 0, 0, 4 )
    button._isChecked = isChecked

    ApplyTheme( button )

    button.DoClick = function( s )
        s._isChecked = not s._isChecked
        button:SetIcon( s._isChecked and "icon16/accept.png" or "icon16/cancel.png" )
        callback( s._isChecked )
    end

    return button
end

function GMinimap.CreatePropertyLabel( text, parent )
    local label = vgui.Create( "DLabel", parent )
    label:Dock( TOP )
    label:DockMargin( 0, 0, 0, 2 )
    label:SetText( text )
    label:SetTall( 26 )

    ApplyTheme( label )

    return label
end

function GMinimap.CreateHeader( text, parent, mleft, mtop, mright, mbottom )
    mleft = mleft or 0
    mtop = mtop or 4
    mright = mright or 0
    mbottom = mbottom or 4

    local panel = vgui.Create( "DPanel", parent )
    panel:SetTall( 32 )
    panel:Dock( TOP )
    panel:DockMargin( mleft, mtop, mright, mbottom )
    panel:SetBackgroundColor( color_black )

    local label = vgui.Create( "DLabel", panel )
    label:SetText( text )
    label:SetContentAlignment( 5 )
    label:SizeToContents()
    label:Dock( FILL )

    ApplyTheme( label )

    return panel
end

function GMinimap.CreateSlider( parent, label, default, min, max, decimals, callback )
    local slider = vgui.Create( "DNumSlider", parent )
    slider:SetTall( 36 )
    slider:SetText( label )
    slider:SetMin( min )
    slider:SetMax( max )
    slider:SetValue( default )
    slider:SetDecimals( decimals )
    slider:Dock( TOP )

    ApplyTheme( slider )

    slider.OnValueChanged = function( _, value )
        callback( decimals == 0 and math.floor( value ) or math.Round( value, decimals ) )
    end

    return slider
end

function GMinimap.CreateColorPicker( parent, default, callback )
    local picker = vgui.Create( "DColorMixer", parent )
    picker:SetTall( 150 )
    picker:Dock( TOP )
    picker:SetPalette( true )
    picker:SetAlphaBar( false )
    picker:SetWangs( true )

    if default then
        picker:SetColor( default )
    end

    picker.ValueChanged = function( _, color )
        callback( Color( color.r, color.g, color.b ) )
    end

    return picker
end
