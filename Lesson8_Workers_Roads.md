# Colony Empire Tutorial — Lesson 8
## Walking workers, pathfinding, roads, and a less "grid-like" map

Three things this lesson:
1. **Workers** that actually walk around the map.
2. **Pathfinding** so they route around water and mountains.
3. **Roads** you place to speed them up — plus a map that looks less like a checkerboard.

---

## Step 1: Update everything

The refined terrain art is already in `assets/` (the tiles now have soft edges and speckled detail instead of hard black outlines).
Open `main.gd` → select all → delete → paste the new `godot_starter/main.gd` → save → **F5**.

New stuff you'll see:
- Build a couple of **Houses** and little people appear and wander between your buildings.
- They walk *around* lakes and hills, never through them.
- Press **4** to select **Road**, then left-click to lay roads (1 wood each). Workers move ~2× faster on roads, and prefer to route along them.
- The ground no longer looks like a flat grid — each tile is slightly shaded differently and has texture.

---

## Step 2: Pathfinding with AStarGrid2D

Godot has a built-in grid pathfinder, `AStarGrid2D`. We set it up once:

```gdscript
astar = AStarGrid2D.new()
astar.region = Rect2i(0, 0, GRID_W, GRID_H)
astar.cell_size = Vector2(1, 1)
astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
astar.update()
```

Then we tell it which tiles are blocked and how "expensive" each is:

```gdscript
func _refresh_astar_cell(cell):
    var t = terrain.get(cell, "grass")
    astar.set_point_solid(cell, t == "water" or t == "mountain")   # impassable
    astar.set_point_weight_scale(cell, 0.4 if roads.has(cell) else 1.0)  # roads are cheap
```

Asking for a route is then a single call:

```gdscript
var path = astar.get_id_path(start, dest)   # returns a list of cells to walk
```

**This is the big idea:** A\* (pronounced "A-star") is the standard pathfinding algorithm in games. You don't implement it — you describe the world to it (what's solid, what's cheap) and ask for a path. The **weight** is why roads work: a road tile costs 0.4 instead of 1.0, so A\* naturally prefers routes that follow your roads, exactly like real units in an RTS. Whenever terrain changes (you clear a forest or lay a road), we call `_refresh_astar_cell` so the pathfinder stays in sync.

---

## Step 3: Making workers walk (interpolation)

A path is just a list of cells. To make a worker *glide* instead of teleporting, each worker stores a floating-point position and moves a little each frame toward the next cell:

```gdscript
var target = Vector2(path[w["i"]])      # next cell as a point
var to = target - w["p"]                # direction & distance
var step = WORKER_SPEED * delta         # how far we can move this frame
if roads.has(here): step *= ROAD_SPEEDUP
if to.length() <= step:
    w["p"] = target; w["i"] += 1        # arrived at this cell, aim at the next
else:
    w["p"] += to.normalized() * step    # move part-way
```

When a worker reaches the end of its path, `_assign_dest()` picks a new destination (usually a random building) and asks A\* for a fresh route. This "pick goal → path → walk → repeat" loop is the skeleton of every unit-AI in strategy games. Right now the goals are random; later you'd make them purposeful ("go to the nearest farm, harvest, carry food to storage").

Because workers move continuously, we now call `queue_redraw()` **every frame** so the animation is smooth — and the off-screen **culling** from last lesson is what keeps that cheap on a big map.

> Note: workers are visual/transient, so we don't save them. After loading, `_sync_workers()` simply respawns the right number based on your houses.

---

## Step 4: Why the map looks less grid-like

Two cheap tricks, no extra art pipeline:

1. **Soft tiles** — the regenerated terrain PNGs dropped the hard dark outline and added random speckles, so neighbouring tiles of the same type blend instead of showing a crisp diamond border.
2. **Per-tile color variation** — in code, each tile is tinted by a tiny amount derived from a hash of its coordinates:

```gdscript
var jitter = 0.93 + float(_hash_cell(cell) % 14) / 100.0
var tint = Color(stint.r*jitter, stint.g*jitter, stint.b*jitter)
```

`_hash_cell` turns `(x, y)` into a stable pseudo-random number, so every tile gets a consistent, slightly different brightness. That irregularity is what fools the eye into reading "natural ground" instead of "spreadsheet". This is the cheapest possible step toward better visuals; the real upgrade later is *autotiling* (special edge tiles where grass meets water), which we can do as its own lesson.

---

## Step 5: Play with it

1. `WORKER_SPEED` and `ROAD_SPEEDUP` — make roads feel essential by lowering base speed and raising the road bonus.
2. The road weight `0.4` — set it to `0.1` and workers will go far out of their way to use roads.
3. `MAX_WORKERS` — raise it and build a dense town to watch the little crowd path around obstacles.
4. Lay a road across a lake's narrow point... you can't (roads need solid ground). Bridges would be a fun future feature: a "bridge" that makes a water tile passable.

---

## What you learned

- **A\* pathfinding** with `AStarGrid2D`: describe solidity + weights, request a path.
- **Roads as path weights** — the clean way to make preferred routes.
- **Smooth movement by interpolation** toward path cells, and the universal "pick goal → path → act → repeat" agent loop.
- Keeping the pathfinder **in sync** when the world changes.
- Two cheap **anti-grid** visual tricks: soft tiles + hashed per-tile tint.

---

## Honest status & next threads

You've now got pathfinding agents on a procedural map — that's real strategy-game tech. Toward the Farthest-Frontier feel, the highest-impact next steps are:

- **Purposeful workers**: assign jobs (harvest → carry → deposit) so workers *do* the economy instead of population being abstract.
- **Autotiling / nicer terrain**: proper edge tiles where biomes meet (the biggest visual jump).
- **Multi-tile buildings** and smooth (sub-tile) placement.
- **Audio + juice**: footsteps, placement sounds, floating "+wood" numbers.

Tell me which to tackle next. And if anything throws a parser/runtime error, paste it and I'll fix it fast.
