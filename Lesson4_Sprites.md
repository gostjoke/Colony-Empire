# Colony Empire Tutorial — Lesson 4
## From colored blocks to real sprites

So far everything has been drawn by hand with polygons. In this lesson we swap those blocks for real **image assets (sprites)**, and the game finally starts to look like a game.

I've already generated the artwork for you — no downloads needed. Look in `godot_starter/assets/`:

- `grass.png` — the ground tile (a 64×32 isometric diamond)
- `house.png` — wooden cabin with a chimney
- `farm.png` — low field with furrows
- `mansion.png` — tall stone tower with windows

---

## Step 1: Update the code

Open `main.gd` → select all → delete → paste the new `godot_starter/main.gd` → save → **F5**.

You should now see textured grass and proper-looking buildings. Hovering still highlights a tile, and 1/2/3 still switch building types. The game *logic* is identical to Lesson 3 — only the **drawing** changed.

> If Godot shows an error like "Failed to load resource res://assets/house.png", make sure the `assets` folder is really inside `godot_starter/` and that you re-opened the project so Godot imported the PNGs. New image files only get imported when the editor is focused/refocused.

---

## Step 2: The three new concepts

### 1. Loading a resource with `load()`

In `_ready()` (which runs once when the scene starts):

```gdscript
func _ready() -> void:
    tex_grass = load("res://assets/grass.png")
    for key in CATALOG.keys():
        tex_building[key] = load("res://assets/%s.png" % key)
```

- `res://` always means **the project root folder**. So `res://assets/grass.png` is the file you can see in the FileSystem panel.
- `load()` reads that file and hands back a `Texture2D` we can draw.
- We load each texture **once** at startup and reuse it, instead of reloading every frame. Loading from disk is slow; this is an important habit.

### 2. Drawing a texture with `draw_texture()`

```gdscript
draw_texture(tex_grass, center - tex_grass.get_size() * 0.5)
```

The key gotcha: **a texture is drawn from its top-left corner**, not its center. To center a 64×32 grass tile on a point, we shift the draw position left by 32 and up by 16 (half the size). Same idea, just `get_size() * 0.5`.

### 3. The anchor point (lining sprites up with the grid)

Buildings are taller than a tile, so we can't just center them. When I generated the art, I placed each building's **footprint diamond at the bottom of the image**, horizontally centered. The footprint center sits at:

```
(width / 2, height - TILE_H / 2)
```

That point is called the **anchor**. In code:

```gdscript
var anchor := Vector2(tex.get_width() * 0.5, tex.get_height() - TILE_H * 0.5)
draw_texture(tex, center - anchor)
```

This is why the cabin's base lands exactly on its tile while the roof rises above. Getting the anchor right is 90% of the work when wiring up any 2D/2.5D art — remember this concept, you'll use it constantly.

The back-to-front sorting from Lesson 3 is unchanged, so taller buildings still correctly overlap the ones behind them.

---

## Step 3: Make it yours

1. Open any PNG in `assets/` with an image editor (even MS Paint) and recolor it — save, refocus Godot, press F5. Your change shows up instantly. This is the fast art-iteration loop real devs use.
2. Want a fourth building? Add its data to `CATALOG`, add `"mine"` to `order`, drop a `mine.png` into `assets/`, and add a `KEY_4` case in `_unhandled_input`. The drawing code needs **zero** changes — that's the payoff of data-driven design.

---

## What you learned

- `res://` paths and loading images with `load()` (once, in `_ready`).
- `draw_texture()` and why position is measured from the top-left corner.
- **Anchor points** — how to align art of any size to a grid cell.
- Art and logic are separate: we replaced all the visuals without touching a single game rule.

---

## Where you are now

You have a working vertical slice: an isometric map, three building types, two resources, a build/produce economy loop, real sprites, and correct depth sorting. That is genuinely the skeleton of a colony builder.

## Lesson 5 preview — making it a real *game*

The visuals are there; next we add **pressure and goals** (the heart of your GDD):

- A food upkeep: population consumes food each tick; run out and you start losing.
- A simple win/lose condition or score.
- Saving and loading your colony to disk.

Say "Lesson 5" when you're ready. As always, paste any error message and I'll debug it with you.
