# Colony Empire Tutorial — Lesson 7
## A big procedural map + camera (a step toward Farthest Frontier)

> Reality check first: Farthest Frontier is a 3D commercial game made by a full studio, with real terrain, rivers, soil fertility and resource nodes. We can't match its fidelity in a 2.5D learning project. But this lesson takes a big step in that direction: a **large, varied, procedurally generated map** where **where you build matters**, plus a **camera** to roam it.

---

## Step 1: Update the code

You already have the new terrain art in `assets/` (`water`, `forest`, `mountain`, `fertile`, plus `grass`).
Open `main.gd` → select all → delete → paste the new `godot_starter/main.gd` → save → **F5**.

You'll spawn in the middle of a **56×56** map with lakes, forests, hills and fertile patches.

New controls:
- **Arrow keys** — pan the camera
- **Mouse wheel** — zoom in/out (zooms toward the cursor)
- **Left-click a forest** — chop it for wood and clear the land
- Building only works on grass/fertile; water and mountains are blocked

The HUD now shows the **tile under your cursor** and whether it's buildable.

---

## Step 2: Procedural terrain with noise

The whole map is generated from **noise** — a function that returns smooth, natural-looking random values across a grid. Godot has `FastNoiseLite` built in:

```gdscript
var elev := FastNoiseLite.new()
elev.seed = map_seed
elev.frequency = 0.05            # lower = larger, smoother features
```

We sample **two** noise fields per tile — elevation and moisture — and turn the pair into a biome:

```gdscript
var e := (elev.get_noise_2d(x, y) + 1.0) * 0.5   # noise is -1..1, remap to 0..1
var m := (moist.get_noise_2d(x, y) + 1.0) * 0.5
if   e < 0.34: t = "water"        # low ground floods
elif e > 0.74: t = "mountain"     # high ground is rock
elif m > 0.62: t = "forest"       # wet land grows trees
elif m > 0.50: t = "fertile"      # damp soil is rich
else:          t = "grass"
```

This two-axis idea (elevation × moisture → biome) is exactly how real terrain generators — including big strategy games — decide what goes where. Two cheap noise fields produce a surprisingly believable world.

The **seed** (`map_seed = randi()`) makes each new game a different map, but the *same* seed always rebuilds the *same* map — which is why we can save just the seed instead of all 3,136 tiles. (We also force a clear patch in the center so you always have somewhere to start.)

---

## Step 3: The camera — pan and zoom by math, not magic

Instead of adding a `Camera2D` node (which would also move the HUD), we keep one script and move the world ourselves with two variables:

- `origin` — a pixel offset added to every tile position (panning).
- `zoom` — a scale factor multiplied into every tile size (zooming).

Every coordinate function now multiplies by `zoom`:

```gdscript
func grid_to_screen(col, row):
    return origin + Vector2((col-row)*TILE_W*0.5, (col+row)*TILE_H*0.5) * zoom
```

The neat part is **zoom-toward-cursor**. To keep the point under the mouse fixed while zooming:

```gdscript
func _set_zoom(nz):
    var focus := get_global_mouse_position()
    origin = focus - (focus - origin) / zoom * nz
    zoom = nz
```

That one line is the same trick every map/photo app uses. Worth re-reading until it clicks — it's pure algebra: solve for the new `origin` that leaves `focus` on the same screen pixel.

Because the HUD is drawn at fixed screen coordinates (and only the *map* uses `origin`/`zoom`), the interface stays put while the world pans and scales underneath it.

---

## Step 4: Performance — culling

A 56×56 map is 3,136 tiles, redrawn whenever you pan. To stay smooth we **skip tiles that are off-screen**:

```gdscript
if center.x < -80 or center.x > vp.x + 80 or center.y < -80 or center.y > vp.y + 120:
    continue
```

Only what you can actually see gets drawn. This "culling" is why you could push `GRID_W`/`GRID_H` to 100+ and still run fine. It's one of the most important habits for any game with a large world.

---

## Step 5: Placement that matters (the Farthest Frontier feeling)

Land type now changes your decisions:

- **Forest** → left-click clears it for `+6 wood` and turns it into buildable grass. Forests are your early wood supply *and* the obstacle you expand through.
- **Fertile soil** → a Farm built here gets `+3` food (`FERTILE_FARM_BONUS`). Scout the map for green-rich patches before placing farms.
- **Water / mountain** → can't build; they shape where your town can grow.

This is the core of terrain-driven design: the map isn't a blank grid, it's a puzzle of opportunities and obstacles. Suddenly *exploring* and *choosing a site* are gameplay.

---

## Step 6: Make it yours

1. `elev.frequency` / `moist.frequency` — lower = bigger continents and lakes; higher = noisy, fragmented terrain. Try 0.03 and 0.12 to feel the difference.
2. Shift the thresholds: raise the `water` cutoff to `0.40` for a wetter, lake-heavy world.
3. `GRID_W`/`GRID_H` to 80 — thanks to culling it still runs; pan around your bigger continent.
4. Add a `stone` resource you mine from `mountain` tiles, mirroring how forests give wood.

---

## What you learned

- **Noise-based procedural generation**, and the elevation×moisture → biome pattern.
- **Seeds**: reproducible randomness (and tiny save files).
- A **camera done with math** (`origin` + `zoom`), including zoom-toward-cursor.
- **Culling** off-screen tiles to keep a large map fast.
- **Terrain-driven placement** — turning the map itself into a decision space.

---

## Honest note on going further toward Farthest Frontier

To get closer to that look/feel, the next big jumps would be: smooth (sub-tile) building placement, multi-tile buildings, real pathfinding workers who walk to resources, rivers and roads, and layered terrain art with proper height. Each is a sizable lesson. If that's the dream, the smartest move is to keep this as your "systems prototype" and grow it one system at a time — which is exactly what we've been doing.

Tell me which thread to pull next: workers that actually walk around, multi-tile buildings, nicer art, or polishing toward a shippable demo.
