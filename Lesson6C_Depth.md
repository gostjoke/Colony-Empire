# Colony Empire Tutorial — Lesson 6C
## Depth: seasons, random events, and a tech tree

You have a complete game loop. Now we add the things that make players want a *second* run: a changing world they must adapt to, surprises they can't fully control, and long-term upgrades to chase.

---

## Step 1: Update the code

Open `main.gd` → select all → delete → paste the new `godot_starter/main.gd` → save → **F5**.

What's new on screen:
- A **Research** counter (top row) and a **Season** line.
- The ground gently changes tint each season (golden autumn, cold-blue winter).
- A **tech menu** — press **Q / W / E** to buy upgrades.
- Occasional **events** flashing in orange ("Bountiful harvest!", "Fire!", etc.).

---

## Step 2: Seasons — a world that changes on you

A `total_ticks` counter drives a 4-season cycle. Each season lasts `SEASON_LEN` ticks:

```gdscript
func season_index() -> int:
    return int(total_ticks / SEASON_LEN) % 4   # 0..3 repeating

func season_multiplier() -> float:
    match season_index():
        1: return 1.25                          # Summer: +25% farm output
        3: return 0.65 if tech["granary"] else 0.3   # Winter: big cut
        _: return 1.0
```

Then farm income is multiplied by it:

```gdscript
food += int(round(amt * mult))
```

The design lesson here: **a single multiplier creates rhythm.** Summer lets you stockpile; winter forces you to have built a buffer. Players now have to think ahead instead of reacting tick-by-tick. Most management games are built on cycles exactly like this.

The `% 4` ("modulo") is the trick that makes the counter loop forever through the four seasons — a pattern you'll reuse for day/night, turns, anything cyclic.

---

## Step 3: Random events — controlled chaos

Each tick has a small chance to fire one event:

```gdscript
if randf() < 0.12:        # ~12% chance per tick
    _trigger_event()
```

`_trigger_event()` picks one from a pool and applies its effect — bonus food/wood, free migrants, a disease that costs population, or a fire that destroys a random building.

Two important details:

- **`randomize()` in `_ready()`** seeds the random number generator, so every playthrough is different. Without it, you'd get the same "random" events every time.
- The event pool is **data, not hard-coded branches** — disease is only added to the pool if you *haven't* researched vaccines:

```gdscript
var pool := ["harvest", "caravan", "fire", "migrants"]
if not tech["vaccines"]:
    pool.append("disease")
```

This is how you make upgrades feel meaningful: a tech literally removes a bad outcome from the game's possibility space.

Good event design = mostly small effects, rare big ones, and the player should usually be able to recover. Tune the `0.12` and the effect sizes to taste.

---

## Step 4: Tech — long-term goals

Research accrues automatically (`research += RESEARCH_PER_TICK`). You spend it on permanent upgrades:

```gdscript
var tech := { "irrigation": false, "granary": false, "vaccines": false }
var TECHS := {
    "irrigation": { "key": "Q", "cost": 15, "desc": "Farms +2 food" },
    "granary":    { "key": "W", "cost": 30, "desc": "Halve winter penalty" },
    "vaccines":   { "key": "E", "cost": 50, "desc": "Stop disease events" },
}
```

Buying one just flips a boolean, and the rest of the code *reads* that boolean:
- `irrigation` → adds +2 to farm output in the income loop.
- `granary` → changes the winter multiplier from 0.3 to 0.65.
- `vaccines` → keeps "disease" out of the event pool.

This is the cleanest way to do a tech tree: **techs are flags; systems check the flags.** To add a new tech you add one entry to `TECHS`, one key in `_unhandled_input`, and one `if tech["..."]` check wherever it should matter. No giant switch statement.

---

## Step 5: Save/load kept in sync

Notice the save file now also stores `research`, `total_ticks`, and the whole `tech` dictionary. Whenever you add new game state, remember to add it to **both** `_save_game()` and `_load_game()`, or a loaded game will silently reset those values. Forgetting this is one of the most common save-system bugs.

---

## Step 6: Play designer

1. `SEASON_LEN` shorter (e.g. 5) = faster, more frantic seasons.
2. Make winter brutal: change the winter multiplier to `0.1`. Now `granary` becomes a must-have tech — feel how one number reshapes the whole strategy.
3. Add a 4th tech, e.g. `"sawmill": { "key": "R", "cost": 40, "desc": "TradePost +3 wood" }`, and make the wood income line check `tech["sawmill"]`.
4. Tweak event chance and effects until a run feels tense but fair.

---

## What you learned

- **Cyclic systems** with a tick counter + modulo (seasons).
- **Randomness done right**: `randomize()`, weighted/conditional pools, recoverable effects.
- **Flag-based upgrades**: techs are booleans that systems read — a scalable tech-tree pattern.
- Keeping **save/load in sync** with new state.
- The meta-lesson: depth comes from *systems interacting* (seasons × farms × tech × events), not from more content.

---

## Where to go next

You now have a surprisingly complete colony sim. Remaining directions:

- **6A — Camera & bigger world** (pan/zoom for a larger map)
- **6B — Juice & feedback** (animations, sound, floating numbers)
- **6D — Polish to ship** (main menu, settings, export a Windows .exe)

Or we could start refactoring the single `main.gd` into separate scenes/scripts — a good step once a project grows. Tell me what you'd like next.
