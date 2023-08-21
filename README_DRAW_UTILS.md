## Styled's Draw Utilities

After calling `require( "styled_draw_utils" )`, the table `SDrawUtils` becomes available
in global context, and provides the following functions:

---
```lua
color = SDrawUtils.ModifyColorBrightness(color: Color, brightness: number)
```

A shortcut to modify a color's HSV value (brightness). Returns the modified color.

---
```lua
id, rt = SDrawUtils.AllocateRT()
```

As of writing, render targets cannot be destroyed in Garry's Mod. If you ever need to frequently create/remove render targets at random, this function makes sure you're reusing them.

Returns a `id` string you should keep to free this RT later, and the RT's `ITexture`.

---
```lua
SDrawUtils.FreeRT(id: string)
```

Marks a render target as "free" to be reused. The `id` string comes from `SDrawUtils.AllocateRT`.

---
```lua
SDrawUtils.DrawFilledCircle(radius: number, x: number, y: number, color: Color)
```

Draw a filled circle. Works with floating point positions.

---
```lua
SDrawUtils.DrawTexturedRectRotated(x: number, y: number, w: number, h: number, angle: number, color: Color)
```

Draw a textured, rotated rectangle. Drop-in replacement for `surface.DrawTexturedRectRotated`, but works with floating point positions.

---
```lua
SDrawUtils.URLTexturedRectRotated(url: string, x: number, y: number, w: number, h: number, angle: number, color: Color)
```

Draw a textured, rotated rectangle, where the texture comes from the internet.

If the `url` does not start with `http(s)://`, it will attempt to cache and use a local image instead, so this function can also be used as a easier way to draw icons.

```lua
-- this will download, cache and draw a image from the internet
SDrawUtils.URLTexturedRectRotated( "https://cdn3.emoji.gg/emojis/2319-astonished-cat.png", 8, 8, 32, 32, 0, color_white )

-- this will cache and draw a image from the game materials folder
SDrawUtils.URLTexturedRectRotated( "icon16/bomb.png", 8, 8, 32, 32, 0, color_white )
```