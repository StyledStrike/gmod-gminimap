local showAsPlayer = {
    ["npc_lambdaplayer"] = true
}

hook.Add( "OnEntityCreated", "GMinimap.TrackPlayerNPCs", function( ent )
    if not IsValid( ent ) then return end
    if not showAsPlayer[ent:GetClass()] then return end

    GMinimap:AddBlip( {
        id = "npc_" .. ent:EntIndex(),
        icon = "gminimap/blips/default.png",
        parent = ent,
        indicateAng = true,
        scale = 0.8
    } )
end )
