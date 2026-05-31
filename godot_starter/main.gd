extends Node2D
# =============================================================
#  Colony Empire — Lesson 6C: Depth (seasons, events, tech)
#  Adds a season cycle that changes farm output, random events,
#  and a small research/tech system with permanent upgrades.
# =============================================================

const GRID_W := 20
const GRID_H := 20
const TILE_W := 64.0
const TILE_H := 32.0

const START_WOOD := 90
const START_FOOD := 45
const PRODUCE_INTERVAL := 1.5

const FOOD_PER_POP := 1
const WIN_POP := 20

# --- Seasons ---
const SEASON_LEN := 8                       # ticks per season
const SEASONS := ["Spring", "Summer", "Autumn", "Winter"]
const RESEARCH_PER_TICK := 1

var origin := Vector2(512, 130)

var buildings := {}
var hovered := Vector2i(-1, -1)

var wood := START_WOOD
var food := START_FOOD
var population := 0
var ever_populated := false

var research := 0
# Tech flags (permanent upgrades the player buys with research)
var tech := { "irrigation": false, "granary": false, "vaccines": false }
var TECHS := {
	"irrigation": { "key": "Q", "cost": 15, "desc": "Farms +2 food" },
	"granary":    { "key": "W", "cost": 30, "desc": "Halve winter penalty" },
	"vaccines":   { "key": "E", "cost": 50, "desc": "Stop disease events" },
}

var total_ticks := 0
var produce_timer := 0.0
var message := ""
var message_timer := 0.0
var event_text := ""                        # last random event, shown in HUD
var event_timer := 0.0

var won := false
var game_over := false

var selected := "house"
var order := ["house", "farm", "mansion"]

var CATALOG := {
	"house":   { "name": "House",     "cost_wood": 10, "cost_food": 0, "role": "pop",  "pop": 4 },
	"farm":    { "name": "Farm",      "cost_wood": 8,  "cost_food": 0, "role": "food", "amount": 5 },
	"mansion": { "name": "TradePost", "cost_wood": 25, "cost_food": 5, "role": "wood", "amount": 6 },
}

var tex_grass: Texture2D
var tex_building := {}


func _ready() -> void:
	randomize()                              # different random events each run
	tex_grass = load("res://assets/grass.png")
	for key in CATALOG.keys():
		tex_building[key] = load("res://assets/%s.png" % key)


func grid_to_screen(col: int, row: int) -> Vector2:
	return origin + Vector2((col - row) * TILE_W * 0.5, (col + row) * TILE_H * 0.5)


func screen_to_grid(pos: Vector2) -> Vector2i:
	var p := pos - origin
	var fcol := (p.x / (TILE_W * 0.5) + p.y / (TILE_H * 0.5)) * 0.5
	var frow := (p.y / (TILE_H * 0.5) - p.x / (TILE_W * 0.5)) * 0.5
	return Vector2i(floori(fcol), floori(frow))


func season_index() -> int:
	return int(total_ticks / SEASON_LEN) % 4


# How much farm output is multiplied this season
func season_multiplier() -> float:
	match season_index():
		1: return 1.25                       # Summer: bonus
		3:                                   # Winter: penalty
			return 0.65 if tech["granary"] else 0.3
		_: return 1.0                        # Spring / Autumn


func _process(delta: float) -> void:
	var cell := screen_to_grid(get_global_mouse_position())
	if cell != hovered:
		hovered = cell
		queue_redraw()

	if not won and not game_over:
		produce_timer += delta
		if produce_timer >= PRODUCE_INTERVAL:
			produce_timer -= PRODUCE_INTERVAL
			_economy_tick()
			queue_redraw()

	if message_timer > 0.0:
		message_timer -= delta
		if message_timer <= 0.0:
			message = ""; queue_redraw()
	if event_timer > 0.0:
		event_timer -= delta
		if event_timer <= 0.0:
			event_text = ""; queue_redraw()


func _economy_tick() -> void:
	total_ticks += 1
	var mult := season_multiplier()

	# Income
	var capacity := 0
	for c in buildings.keys():
		var d: Dictionary = CATALOG[buildings[c]]
		match d["role"]:
			"food":
				var amt: float = d["amount"] + (2 if tech["irrigation"] else 0)
				food += int(round(amt * mult))
			"wood":
				wood += d["amount"]
			"pop":
				capacity += d["pop"]

	# Food upkeep + population dynamics
	food -= population * FOOD_PER_POP
	var starving := food < 0
	if starving:
		food = 0
		population = max(0, population - 1)
	elif population < capacity:
		population += 1
	if population > 0:
		ever_populated = true

	# Research
	research += RESEARCH_PER_TICK

	# Random event (roughly once every ~8 ticks)
	if randf() < 0.12:
		_trigger_event()

	# Outcomes
	if population >= WIN_POP:
		won = true
	elif ever_populated and population == 0:
		game_over = true


func _trigger_event() -> void:
	var pool := ["harvest", "caravan", "fire", "migrants"]
	if not tech["vaccines"]:
		pool.append("disease")
	var ev: String = pool[randi() % pool.size()]
	match ev:
		"harvest":
			food += 20
			_show_event("Bountiful harvest!  +20 food")
		"caravan":
			wood += 25
			_show_event("Merchant caravan!  +25 wood")
		"migrants":
			population += 3
			ever_populated = true
			_show_event("Migrants arrived!  +3 population")
		"disease":
			population = max(0, population - 3)
			_show_event("Disease outbreak!  -3 population")
		"fire":
			if buildings.size() > 0:
				var keys := buildings.keys()
				var victim = keys[randi() % keys.size()]
				buildings.erase(victim)
				_show_event("Fire!  A building burned down")
			else:
				_show_event("Lightning struck an empty field")


func _show_event(text: String) -> void:
	event_text = text
	event_timer = 3.0
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_1: selected = order[0]; queue_redraw()
			KEY_2: selected = order[1]; queue_redraw()
			KEY_3: selected = order[2]; queue_redraw()
			KEY_Q: _buy_tech("irrigation")
			KEY_W: _buy_tech("granary")
			KEY_E: _buy_tech("vaccines")
			KEY_S: _save_game()
			KEY_L: _load_game()
			KEY_R: _restart()

	if won or game_over:
		return

	if event is InputEventMouseButton and event.pressed:
		var cell := screen_to_grid(get_global_mouse_position())
		if not _in_grid(cell):
			return
		if event.button_index == MOUSE_BUTTON_LEFT:
			_try_build(cell)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			if buildings.has(cell):
				var data: Dictionary = CATALOG[buildings[cell]]
				wood += int(data["cost_wood"] / 2.0)
				food += int(data["cost_food"] / 2.0)
				buildings.erase(cell)
		queue_redraw()


func _buy_tech(name: String) -> void:
	if tech[name]:
		_show_message("Already researched")
		return
	var cost: int = TECHS[name]["cost"]
	if research < cost:
		_show_message("Need %d research for %s" % [cost, name])
		return
	research -= cost
	tech[name] = true
	_show_message("Researched: %s" % name)
	queue_redraw()


func _try_build(cell: Vector2i) -> void:
	var data: Dictionary = CATALOG[selected]
	if buildings.has(cell):
		_show_message("Tile already occupied"); return
	if wood < data["cost_wood"] or food < data["cost_food"]:
		_show_message("Not enough! Need wood %d food %d" % [data["cost_wood"], data["cost_food"]]); return
	wood -= data["cost_wood"]
	food -= data["cost_food"]
	buildings[cell] = selected


func _restart() -> void:
	buildings.clear()
	wood = START_WOOD; food = START_FOOD; population = 0
	research = 0; total_ticks = 0
	tech = { "irrigation": false, "granary": false, "vaccines": false }
	ever_populated = false; produce_timer = 0.0
	won = false; game_over = false
	event_text = ""
	_show_message("New colony started"); queue_redraw()


func _save_game() -> void:
	var arr := []
	for c in buildings.keys():
		arr.append({ "x": c.x, "y": c.y, "type": buildings[c] })
	var data := {
		"wood": wood, "food": food, "population": population,
		"research": research, "total_ticks": total_ticks,
		"tech": tech, "ever_populated": ever_populated, "buildings": arr,
	}
	var f := FileAccess.open("user://save.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(data)); f.close()
	_show_message("Saved")


func _load_game() -> void:
	if not FileAccess.file_exists("user://save.json"):
		_show_message("No save file"); return
	var f := FileAccess.open("user://save.json", FileAccess.READ)
	var text := f.get_as_text(); f.close()
	var data = JSON.parse_string(text)
	if data == null:
		_show_message("Save file corrupted"); return
	wood = int(data["wood"]); food = int(data["food"]); population = int(data["population"])
	research = int(data["research"]); total_ticks = int(data["total_ticks"])
	ever_populated = bool(data["ever_populated"])
	for k in tech.keys():
		tech[k] = bool(data["tech"][k])
	buildings.clear()
	for b in data["buildings"]:
		buildings[Vector2i(int(b["x"]), int(b["y"]))] = b["type"]
	won = false; game_over = false
	_show_message("Loaded"); queue_redraw()


func _show_message(text: String) -> void:
	message = text; message_timer = 2.0; queue_redraw()


func _in_grid(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < GRID_W and cell.y >= 0 and cell.y < GRID_H


func _draw() -> void:
	# Ground tinted slightly by season for atmosphere
	var tint := _season_tint()
	for row in range(GRID_H):
		for col in range(GRID_W):
			var center := grid_to_screen(col, row)
			draw_texture_rect(tex_grass, Rect2(center - tex_grass.get_size() * 0.5, tex_grass.get_size()), false, tint)
			if Vector2i(col, row) == hovered and not won and not game_over:
				_draw_diamond(center, Color(1, 1, 1, 0.25))

	var cells := buildings.keys()
	cells.sort_custom(func(a, b): return (a.x + a.y) < (b.x + b.y))
	for c in cells:
		_draw_building(c.x, c.y, buildings[c])

	_draw_ui()


func _season_tint() -> Color:
	match season_index():
		1: return Color(1.05, 1.05, 0.9)     # Summer: warm
		2: return Color(1.0, 0.9, 0.75)      # Autumn: golden
		3: return Color(0.8, 0.85, 1.05)     # Winter: cold blue
		_: return Color(1, 1, 1)             # Spring: neutral


func _draw_diamond(center: Vector2, color: Color) -> void:
	draw_colored_polygon(PackedVector2Array([
		center + Vector2(0, -TILE_H * 0.5), center + Vector2(TILE_W * 0.5, 0),
		center + Vector2(0, TILE_H * 0.5), center + Vector2(-TILE_W * 0.5, 0),
	]), color)


func _draw_building(col: int, row: int, type: String) -> void:
	var tex: Texture2D = tex_building[type]
	var center := grid_to_screen(col, row)
	var anchor := Vector2(tex.get_width() * 0.5, tex.get_height() - TILE_H * 0.5)
	draw_texture(tex, center - anchor)


func _draw_ui() -> void:
	var font := ThemeDB.fallback_font

	var capacity := 0
	var food_in := 0
	for c in buildings.keys():
		var d: Dictionary = CATALOG[buildings[c]]
		if d["role"] == "pop": capacity += d["pop"]
		elif d["role"] == "food": food_in += d["amount"]
	var net_food := int(round(food_in * season_multiplier())) - population * FOOD_PER_POP

	draw_string(font, Vector2(20, 32), "Wood: %d   Food: %d   Research: %d" % [wood, food, research],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color(1, 1, 1))

	var net_color := Color(0.5, 1, 0.5) if net_food >= 0 else Color(1, 0.5, 0.5)
	draw_string(font, Vector2(20, 58), "Pop: %d / %d (goal %d)   food/tick: %+d" % [population, capacity, WIN_POP, net_food],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 19, net_color)

	# Season line
	var s: String = SEASONS[season_index()]
	var s_col := Color(0.7, 0.85, 1) if season_index() == 3 else Color(1, 0.95, 0.7)
	draw_string(font, Vector2(20, 82), "Season: %s   (winter cuts farm output)" % s,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 18, s_col)

	# Build menu
	var x := 20.0
	for key in order:
		var d2: Dictionary = CATALOG[key]
		var idx := order.find(key) + 1
		var label := "[%d] %s (W%d F%d)" % [idx, d2["name"], d2["cost_wood"], d2["cost_food"]]
		var col := Color(1, 1, 0.5) if key == selected else Color(0.7, 0.7, 0.7)
		if key == selected: label = "> " + label
		draw_string(font, Vector2(x, 106), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, col)
		x += 210

	# Tech menu
	var tx := 20.0
	for tname in TECHS.keys():
		var t: Dictionary = TECHS[tname]
		var owned: bool = tech[tname]
		var label := "[%s] %s (%d) %s" % [t["key"], tname, t["cost"], t["desc"]]
		var col := Color(0.5, 1, 0.6) if owned else (Color(0.9, 0.9, 0.6) if research >= t["cost"] else Color(0.6, 0.6, 0.6))
		if owned: label += " OK"
		draw_string(font, Vector2(tx, 130), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, col)
		tx += 235

	draw_string(font, Vector2(20, 152), "Left build / Right remove / 1-3 select / Q-W-E research / S save / L load / R restart",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.78, 0.78, 0.78))

	if event_text != "":
		draw_string(font, Vector2(20, 178), "* " + event_text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(1, 0.8, 0.3))
	if message != "":
		draw_string(font, Vector2(20, 202), message,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.9, 0.9, 0.95))

	if won:
		_draw_banner(font, "YOU WIN!  Reached %d population" % WIN_POP, Color(0.4, 1, 0.5))
	elif game_over:
		_draw_banner(font, "GAME OVER  Your colony collapsed", Color(1, 0.4, 0.4))


func _draw_banner(font: Font, text: String, color: Color) -> void:
	var vp := get_viewport_rect().size
	draw_rect(Rect2(0, vp.y * 0.4, vp.x, 90), Color(0, 0, 0, 0.6))
	draw_string(font, Vector2(0, vp.y * 0.4 + 45), text, HORIZONTAL_ALIGNMENT_CENTER, vp.x, 34, color)
	draw_string(font, Vector2(0, vp.y * 0.4 + 78), "Press R to play again", HORIZONTAL_ALIGNMENT_CENTER, vp.x, 18, Color(0.9, 0.9, 0.9))
