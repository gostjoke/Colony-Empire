# Colony Empire Tutorial — Lesson 5
## Population, food upkeep, win/lose, and save/load

Until now you had a sandbox: build freely, watch numbers go up. This lesson adds the three things that make it a **game**: a goal to reach, a way to fail, and the ability to save your progress.

---

## Step 1: Update the code

Open `main.gd` → select all → delete → paste the new `godot_starter/main.gd` → save → **F5**.

New controls and HUD:
- **Pop: X / Y (goal 20)** — your population vs housing capacity, and the target to win.
- **food/tick: +N / -N** — your net food per tick. Green = surplus, red = you're running a deficit.
- Keys: **1/2/3** select building, **S** save, **L** load, **R** restart.

Try to reach **20 population**. If your people run out of food, they start leaving — and if everyone leaves, it's game over.

---

## Step 2: The core idea — a *balanced loop with tension*

Each building now has a **role**:

| Building | Role | Effect |
|----------|------|--------|
| House | `pop` | +4 housing capacity (room for people) |
| Farm | `food` | +5 food per tick |
| TradePost | `wood` | +6 wood per tick (your income to keep building) |

The tension comes from how these interact, all handled in one function, `_economy_tick()`:

```gdscript
# 1. Income from every building
for c in buildings.keys():
    match role:
        "food": food += amount
        "wood": wood += amount
        "pop":  capacity += pop

# 2. People eat
food -= population * FOOD_PER_POP
var starving := food < 0
if starving: food = 0

# 3. Population grows if fed, shrinks if starving
if starving:
    population -= 1            # someone leaves
elif population < capacity:
    population += 1            # someone moves in
```

This is the whole game in fifteen lines. Houses create *room* for people, but people **eat**. More people need more farms. Farms and houses both cost wood, and wood only comes from trade posts. So you can't just spam one building — you have to balance all three. That balancing act **is** the gameplay.

> I actually simulated this economy before giving it to you: a smart build order (trade posts → farms → houses) wins around tick 27, while building only houses starves out and loses around tick 18. So it's both winnable and losable — which is exactly what a game needs.

---

## Step 3: Win and lose conditions

```gdscript
if population >= WIN_POP:
    won = true
elif ever_populated and population == 0:
    game_over = true
```

`ever_populated` is a flag we flip to `true` the first time anyone moves in. Without it, the game would instantly declare "game over" at the start (when population is 0 and you simply haven't built anything yet). This kind of guard against false triggers is a very common pattern in game logic.

When `won` or `game_over` is true, the economy stops ticking, a banner appears in the middle of the screen, and you can press **R** to restart.

---

## Step 4: Save and load

```gdscript
func _save_game():
    var f := FileAccess.open("user://save.json", FileAccess.WRITE)
    f.store_string(JSON.stringify(data))
    f.close()
```

Two concepts here:

- **`user://`** is a private folder Godot gives every game to store files (saves, settings). On Windows it lives under `%APPDATA%`. You never hard-code a real disk path — `user://` keeps your game portable.
- **JSON** is a simple text format for data. `JSON.stringify()` turns our dictionary into text; `JSON.parse_string()` turns it back. Note that JSON only stores text and numbers, so we convert each building's `Vector2i` cell into plain `{x, y, type}` before saving, and rebuild the `Vector2i` when loading.

Press **S** to save, then build some more, then **L** — you'll snap back to the saved state. (A small gotcha the tutorial code already handles: numbers come back from JSON as floats, so we cast them with `int(...)`.)

---

## Step 5: Tune the difficulty

You're now balancing a real game. Each value lives at the top of the file:

1. `WIN_POP` higher = longer game. Try 30.
2. `START_FOOD` lower = more pressure early. Try 20.
3. `FOOD_PER_POP` = 2 makes every farm support fewer people — much harder.
4. Farm `amount` or house `pop` — shift the whole balance.

Change one number, press F5, and *play your own game*. Notice how a tiny number change can make it trivially easy or brutally hard. Welcome to game balancing — the part that takes the most playtesting and has no "correct" answer.

---

## What you learned

- A self-contained **economy tick**: income → upkeep → population change → win/lose.
- Using a `role` field so one loop handles every building type (data-driven again).
- Guarding against **false win/lose triggers** (`ever_populated`).
- **`user://`** storage and **JSON** save/load, including converting non-text types.

---

## You've built a real vertical slice 🎉

Step back and look at what you have: an isometric colony builder with sprites, three interacting building types, two resources, population dynamics, a genuine win/lose loop, and save/load. This is exactly the "playable core loop" your GDD said to build first. Most people who start a colony sim never get this far.

## Where to go next (pick what excites you)

- **Lesson 6A — Camera & bigger world:** pan with WASD, zoom with the scroll wheel, so a much larger map becomes playable.
- **Lesson 6B — Juice & feedback:** build/destroy animations, sound effects, floating "+5 food" numbers.
- **Lesson 6C — Depth:** seasons (winter cuts farm output), random events, a tech tree.
- **Lesson 6D — Polish to ship:** a main menu, settings, and exporting a real Windows `.exe` you can share.

Tell me which one and we'll keep going. Paste any error and I'll help you fix it.
