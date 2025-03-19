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
    if v ~= nil then
        t[k] = tobool( v )
    end
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
