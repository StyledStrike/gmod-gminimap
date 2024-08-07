## GMinimap

[![GLuaLint](https://github.com/StyledStrike/gmod-gminimap/actions/workflows/glualint.yml/badge.svg)](https://github.com/FPtje/GLuaFixer)
[![Workshop Page](https://img.shields.io/endpoint.svg?url=https%3A%2F%2Fshieldsio-steam-workshop.jross.me%2F3024317004%2Fsubscriptions-text)](https://steamcommunity.com/sharedfiles/filedetails/?id=3024317004)

A customizable minimap for your game HUD.

- Customizable position, size, health/armor, colors and other goodies
- Bookmark your favorite locations with custom blips
- Shows other nearby players
- Map of the terrain, with minimum impact to performance
- Supports custom blips and custom icons (including direct links to images on the internet)

## For Developers

### API Functions

Functions and examples for using GMinimap with Lua are available [here](https://github.com/StyledStrike/gmod-gminimap/wiki/).

### Server console variables

#### `gminimap_player_blips_max_distance <number>`

Limits how far players can see other players on the map. Set to 0 to disable player blips.

#### `gminimap_npc_blips_max_distance <number>`

Limits how far players can see NPCs on the map. Set to 0 to disable NPC blips.

#### `gminimap_force_x <number>`

Force the X position of the minimap on all players (between 0 and 1). Set to -1 to disable this.

#### `gminimap_force_y <number>`

Force the Y position of the minimap on all players (between 0 and 1). Set to -1 to disable this.

#### `gminimap_force_w <number>`

Force the width of the minimap on all players (between 0 and 1). Set to -1 to disable this.

#### `gminimap_force_h <number>`

Force the height of the minimap on all players (between 0 and 1). Set to -1 to disable this.

## Disclaimer

This addon bundles some icons from [flat-icons by Game2rise](https://opengameart.org/content/flat-icons).
