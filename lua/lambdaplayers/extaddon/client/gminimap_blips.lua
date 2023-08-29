hook.Add( "OnEntityCreated", "GMinimap.TrackLambdaPlayers", function( ent )
    if not IsValid( ent ) then return end
    if ent:GetClass() ~= "npc_lambdaplayer" then return end

    GMinimap:AddBlip( {
        id = "lambda_player_" .. ent:EntIndex(),
        icon = "gminimap/blips/default.png",
        parent = ent,
        indicateAng = true,
        scale = 0.8
    } )
end )
