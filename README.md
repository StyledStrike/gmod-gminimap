## GMinimap

A customizable minimap for your game HUD.

- Customizable position, size, health/armor, colors and other goodies
- Bookmark your favorite locations with custom blips
- Shows other players nearby
- Semi-realtime map of the terrain, with minimum impact to performance
- Supports custom blips and custom icons (including direct links to images on the internet)

## For Developers

### Server console variables

#### `gminimap_player_blips_max_distance <number>`

Limits how far players can see other players on the map. Set to 0 to disable player blips.

### Client-side functions

#### `GMinimap:SetCanSeePlayerBlips(canSee: boolean)`

Use this to show/hide the built-in player blips for the local player only

#### `blip, id = GMinimap:AddBlip(params: table)`

Add your own blip to the radar.

The params table is a key-value dictionary that should contain the initial properties
of the blip. You can modify the returned `blip` with these same parameters at any point.

| Key           | Type      | Description                                           |
|---------------|-----------|-------------------------------------------------------|
| id            | string    | A ID that can be used to remove the blip later        |
| parent        | Entity    | A parent entity the blip will follow, if valid        |
| icon          | string    | Icon file path, either as a URL or a file on disk     |
| position      | Vector    | World position (doesnt apply if `parent` was set)     |
| angle         | Angle     | World rotation (doesnt apply if `parent` was set)     |
| scale         | number    | Blip icon scale                                       |
| alpha         | number    | Blip icon opacity                                     |
| color         | Color     | Blip icon color                                       |                     
| indicateAlt   | boolean   | Show a altitude indicator when not in the same level  |
| indicateAng   | boolean   | Show a heading arrow                                  |
| lockIconAng   | boolean   | `angle` will only affect `indicateAng`, icon does not rotate |

#### `blip = GMinimap:FindBlipByID(id: string)`

Find a blip created previously by it's ID.

#### `GMinimap:RemoveBlipById(id: string)`

Remove a blip created previously by it's `id`. You can obtain the `id` either from the second value returned from `GMinimap:AddBlip` or in the blip itself, `blip.id`.

#### `GMinimap:RemoveBlipByParent(ent: Entity)`

Remove all blips created previously that have `ent` as their `parent`.

## Disclaimer

This addon bundles some icons from [flat-icons by Game2rise](https://opengameart.org/content/flat-icons).
