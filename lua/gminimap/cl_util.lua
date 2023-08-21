function GMinimap.GetWorldZDimensions()
    local mins, maxs = game.GetWorld():GetModelBounds()

    -- TODO: figure out a way to exclude the miniature skybox
    -- TODO: cache result

    return mins.z, maxs.z
end
