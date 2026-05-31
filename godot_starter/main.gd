extends Node2D
# =============================================================
#  Colony Empire — Lesson 8: Workers, pathfinding & roads
#  Walking workers that pathfind (AStarGrid2D) around water and
#  mountains, placeable roads that speed them up, and a less
#  grid-like map (per-tile color variation + detailed tiles).
# =============================================================

const GRID_W := 56
const GRID_H := 56
const TILE_W := 64.0
const TILE_H := 32.0

const START_WOOD := 90
const START_FOOD := 45
const PRODUCE_INTERVAL := 1.5
const FOOD_PER_POP := 1
const WIN_POP := 25

const SEASON_LEN := 8
const SEASONS := ["Spring", "Summer", "Autumn", "Winter"]
const RESEARCH_PER_TICK := 1

const PAN_SPEED := 600.0
const FOREST_WOOD := 6
const FERTILE_FARM_BONUS := 3
const ROAD_COST := 1
const WORKER_SPEED := 3.0            # cells per second
const ROAD_SPEEDUP := 2.0
const MAX_WORKERS := 24

var origin := Vector2(600, 200)
var zoom := 1.0

var terrain := {}
var cleared := {}
var roads := {}
var map_seed := 0

var astar: AStarGrid2D
var workers := []                    # each: { p:Vector2, path:Array, i:int }

var buildings := {}
var hovered := Vector2i(-1, -1)

var wood := START_WOOD
var food := START_FOOD
var population := 0
var ever_populated := false

var research := 0
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
var event_text := ""
var event_timer := 0.0

var won := false
var game_over := false

var selected := "house"
var order := ["house", "farm", "mansion", "road"]

var CATALOG := {
	"house":   { "name": "House",     "cost_wood": 10, "cost_food": 0, "role": "pop",  "pop": 4 },
	"farm":    { "name": "Farm",      "cost_wood": 8,  "cost_food": 0, "role": "food", "amount": 5 },
	"mansion": { "name": "TradePost", "cost_wood": 25, "cost_food": 5, "role": "wood", "amount": 6 },
	"road":    { "name": "Road",      "cost_wood": 1,  "cost_food": 0, "role": "road" },
}

var tex_terrain := {}
var tex_building := {}


func _ready() -> void:
	randomize()
	for t in ["water", "grass", "fertile", "forest", "mountain"]:
		tex_terrain[t] = load("res://assets/%s.png" % t)
	for key in ["house", "farm", "mansion"]:
		tex_building[key] = load("res://assets/%s.png" % key)
	map_seed = randi()
	_generate_terrain()
	_build_astar()
	_center_camera()


# ---------- Terrain ----------
func _generate_terrain() -> void:
	terrain.clear()
	var elev := FastNoiseLite.new()
	elev.seed = map_seed
	elev.frequency = 0.05
	var moist := FastNoiseLite.new()
	moist.seed = map_seed + 1000
	moist.frequency = 0.075
	for y in range(GRID_H):
		for x in range(GRID_W):
			var e := (elev.get_noise_2d(x, y) + 1.0) * 0.5
			var m := (moist.get_noise_2d(x, y) + 1.0) * 0.5
			var t := "grass"
			if e < 0.34: t = "water"
			elif e > 0.74: t = "mountain"
			elif m > 0.62: t = "forest"
			elif m > 0.50: t = "fertile"
			terrain[Vector2i(x, y)] = t
	var c := Vector2i(GRID_W / 2, GRID_H / 2)
	for dy in range(-3, 4):
		for dx in range(-3, 4):
			terrain[Vector2i(c.x + dx, c.y + dy)] = "grass"
	for cell in cleared.keys():
		terrain[cell] = "grass"


func _build_astar() -> void:
	astar = AStarGrid2D.new()
	astar.region = Rect2i(0, 0, GRID_W, GRID_H)
	astar.cell_size = Vector2(1, 1)
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	astar.update()
	for y in range(GRID_H):
		for x in range(GRID_W):
			_refresh_astar_cell(Vector2i(x, y))


func _refresh_astar_cell(cell: Vector2i) -> void:
	var t: String = terrain.get(cell, "grass")
	astar.set_point_solid(cell, t == "water" or t == "mountain")
	astar.set_point_weight_scale(cell, 0.4 if roads.has(cell) else 1.0)


func _center_camera() -> void:
	var c := Vector2i(GRID_W / 2, GRID_H / 2)
	var u := Vector2((c.x - c.y) * TILE_W * 0.5, (c.x + c.y) * TILE_H * 0.5)
	origin = get_viewport_rect().size * 0.5 - u * zoom


# ---------- Transforms ----------
func grid_to_screen(col: int, row: int) -> Vector2:
	return origin + Vector2((col - row) * TILE_W * 0.5, (col + row) * TILE_H * 0.5) * zoom


func grid_to_screen_f(colf: float, rowf: float) -> Vector2:
	return origin + Vector2((colf - rowf) * TILE_W * 0.5, (colf + rowf) * TILE_H * 0.5) * zoom


func screen_to_grid(pos: Vector2) -> Vector2i:
	var p := (pos - origin) / zoom
	var fcol := (p.x / (TILE_W * 0.5) + p.y / (TILE_H * 0.5)) * 0.5
	var frow := (p.y / (TILE_H * 0.5) - p.x / (TILE_W * 0.5)) * 0.5
	return Vector2i(floori(fcol), floori(frow))


func _process(delta: float) -> void:
	var pan := Vector2.ZERO
	if Input.is_key_pressed(KEY_LEFT):  pan.x += 1
	if Input.is_key_pressed(KEY_RIGHT): pan.x -= 1
	if Input.is_key_pressed(KEY_UP):    pan.y += 1
	if Input.is_key_pressed(KEY_DOWN):  pan.y -= 1
	if pan != Vector2.ZERO:
		origin += pan * PAN_SPEED * delta

	hovered = screen_to_grid(get_global_mouse_position())

	if not won and not game_over:
		produce_timer += delta
		if produce_timer >= PRODUCE_INTERVAL:
			produce_timer -= PRODUCE_INTERVAL
			_economy_tick()
			_sync_workers()
		_update_workers(delta)

	if message_timer > 0.0:
		message_timer -= delta
		if message_timer <= 0.0: message = ""
	if event_timer > 0.0:
		event_timer -= delta
		if event_timer <= 0.0: event_text = ""

	queue_redraw()   # redraw every frame so workers animate smoothly


# ---------- Workers ----------
func _sync_workers() -> void:
	var houses := []
	for c in buildings.keys():
		if CATALOG[buildings[c]]["role"] == "pop":
			houses.append(c)
	var desired: int = min(houses.size(), MAX_WORKERS)
	while workers.size() < desired and houses.size() > 0:
		var h: Vector2i = houses[randi() % houses.size()]
		workers.append({ "p": Vector2(h.x, h.y), "path": [], "i": 0 })
	while workers.size() > desired:
		workers.pop_back()


func _update_workers(delta: float) -> void:
	for w in workers:
		var path: Array = w["path"]
		if path.is_empty() or w["i"] >= path.size():
			_assign_dest(w)
			continue
		var pos: Vector2 = w["p"]
		var target: Vector2 = Vector2(path[w["i"]])
		var to: Vector2 = target - pos
		var step: float = WORKER_SPEED * delta
		var here := Vector2i(roundi(pos.x), roundi(pos.y))
		if roads.has(here):
			step *= ROAD_SPEEDUP
		if to.length() <= step:
			w["p"] = target
			w["i"] = int(w["i"]) + 1
		else:
			w["p"] = pos + to.normalized() * step


func _assign_dest(w: Dictionary) -> void:
	var dest: Vector2i
	if buildings.size() > 0 and randf() < 0.85:
		dest = buildings.keys()[randi() % buildings.size()]
	else:
		dest = Vector2i(randi() % GRID_W, randi() % GRID_H)
	var start := Vector2i(roundi(w["p"].x), roundi(w["p"].y))
	if astar.is_in_boundsv(start) and astar.is_in_boundsv(dest) \
			and not astar.is_point_solid(start) and not astar.is_point_solid(dest):
		var path: Array = astar.get_id_path(start, dest)
		if path.size() >= 2:
			w["path"] = path
			w["i"] = 1
			return
	w["path"] = []


# ---------- Economy ----------
func season_index() -> int:
	return int(total_ticks / SEASON_LEN) % 4


func season_multiplier() -> float:
	match season_index():
		1: return 1.25
		3: return 0.65 if tech["granary"] else 0.3
		_: return 1.0


func _economy_tick() -> void:
	total_ticks += 1
	var mult := season_multiplier()
	var capacity := 0
	for c in buildings.keys():
		var d: Dictionary = CATALOG[buildings[c]]
		match d["role"]:
			"food":
				var amt: float = d["amount"] + (2 if tech["irrigation"] else 0)
				if terrain.get(c, "") == "fertile":
					amt += FERTILE_FARM_BONUS
				food += int(round(amt * mult))
			"wood":
				wood += d["amount"]
			"pop":
				capacity += d["pop"]

	food -= population * FOOD_PER_POP
	var starving := food < 0
	if starving:
		food = 0
		population = max(0, population - 1)
	elif population < capacity:
		population += 1
	if population > 0:
		ever_populated = true

	research += RESEARCH_PER_TICK
	if randf() < 0.12:
		_trigger_event()

	if population >= WIN_POP:
		won = true
	elif ever_populated and population == 0:
		game_over = true


func _trigger_event() -> void:
	var pool := ["harvest", "caravan", "fire", "migrants"]
	if not tech["vaccines"]:
		pool.append("disease")
	match pool[randi() % pool.size()]:
		"harvest":  food += 20; _show_event("Bountiful harvest!  +20 food")
		"caravan":  wood += 25; _show_event("Merchant caravan!  +25 wood")
		"migrants": population += 3; ever_populated = true; _show_event("Migrants arrived!  +3 population")
		"disease":  population = max(0, population - 3); _show_event("Disease outbreak!  -3 population")
		"fire":
			if buildings.size() > 0:
				var keys := buildings.keys()
				buildings.erase(keys[randi() % keys.size()])
				_show_event("Fire!  A building burned down")
			else:
				_show_event("Lightning struck an empty field")


func _show_event(text: String) -> void:
	event_text = text; event_timer = 3.0


# ---------- Input ----------
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_1: selected = order[0]
			KEY_2: selected = order[1]
			KEY_3: selected = order[2]
			KEY_4: selected = order[3]
			KEY_Q: _buy_tech("irrigation")
			KEY_W: _buy_tech("granary")
			KEY_E: _buy_tech("vaccines")
			KEY_S: _save_game()
			KEY_L: _load_game()
			KEY_R: _restart()

	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_set_zoom(zoom * 1.1); return
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_set_zoom(zoom / 1.1); return
		if won or game_over:
			return
		var cell := screen_to_grid(get_global_mouse_position())
		if not _in_grid(cell):
			return
		if event.button_index == MOUSE_BUTTON_LEFT:
			_left_click(cell)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			_right_click(cell)


func _set_zoom(nz: float) -> void:
	nz = clampf(nz, 0.5, 2.5)
	var focus := get_global_mouse_position()
	origin = focus - (focus - origin) / zoom * nz
	zoom = nz


func _left_click(cell: Vector2i) -> void:
	var t: String = terrain.get(cell, "grass")

	if selected == "road":
		if t == "water" or t == "mountain":
			_show_message("Roads need solid ground"); return
		if t == "forest":
			_show_message("Clear the forest first"); return
		if buildings.has(cell) or roads.has(cell):
			return
		if wood < ROAD_COST:
			_show_message("Need %d wood" % ROAD_COST); return
		wood -= ROAD_COST
		roads[cell] = true
		_refresh_astar_cell(cell)
		return

	if t == "forest":
		terrain[cell] = "grass"
		cleared[cell] = true
		wood += FOREST_WOOD
		_refresh_astar_cell(cell)
		_show_message("Cleared forest  +%d wood" % FOREST_WOOD)
		return
	if t == "water" or t == "mountain":
		_show_message("Cannot build on %s" % t)
		return
	_try_build(cell)


func _right_click(cell: Vector2i) -> void:
	if buildings.has(cell):
		var data: Dictionary = CATALOG[buildings[cell]]
		wood += int(data["cost_wood"] / 2.0)
		food += int(data["cost_food"] / 2.0)
		buildings.erase(cell)
	elif roads.has(cell):
		roads.erase(cell)
		_refresh_astar_cell(cell)


func _try_build(cell: Vector2i) -> void:
	var data: Dictionary = CATALOG[selected]
	if buildings.has(cell):
		_show_message("Tile already occupied"); return
	if wood < data["cost_wood"] or food < data["cost_food"]:
		_show_message("Not enough! Need wood %d food %d" % [data["cost_wood"], data["cost_food"]]); return
	wood -= data["cost_wood"]
	food -= data["cost_food"]
	buildings[cell] = selected


func _buy_tech(name: String) -> void:
	if tech[name]:
		_show_message("Already researched"); return
	var cost: int = TECHS[name]["cost"]
	if research < cost:
		_show_message("Need %d research for %s" % [cost, name]); return
	research -= cost
	tech[name] = true
	_show_message("Researched: %s" % name)


func _restart() -> void:
	buildings.clear(); cleared.clear(); roads.clear(); workers.clear()
	wood = START_WOOD; food = START_FOOD; population = 0
	research = 0; total_ticks = 0
	tech = { "irrigation": false, "granary": false, "vaccines": false }
	ever_populated = false; produce_timer = 0.0
	won = false; game_over = false; event_text = ""
	map_seed = randi()
	_generate_terrain(); _build_astar(); _center_camera()
	_show_message("New colony — fresh map")


func _save_game() -> void:
	var barr := []
	for c in buildings.keys(): barr.append({ "x": c.x, "y": c.y, "type": buildings[c] })
	var carr := []
	for c in cleared.keys(): carr.append({ "x": c.x, "y": c.y })
	var rarr := []
	for c in roads.keys(): rarr.append({ "x": c.x, "y": c.y })
	var data := {
		"seed": map_seed, "wood": wood, "food": food, "population": population,
		"research": research, "total_ticks": total_ticks, "tech": tech,
		"ever_populated": ever_populated, "buildings": barr, "cleared": carr, "roads": rarr,
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
	map_seed = int(data["seed"])
	wood = int(data["wood"]); food = int(data["food"]); population = int(data["population"])
	research = int(data["research"]); total_ticks = int(data["total_ticks"])
	ever_populated = bool(data["ever_populated"])
	for k in tech.keys():
		tech[k] = bool(data["tech"][k])
	cleared.clear()
	for c in data["cleared"]:
		cleared[Vector2i(int(c["x"]), int(c["y"]))] = true
	roads.clear()
	for c in data["roads"]:
		roads[Vector2i(int(c["x"]), int(c["y"]))] = true
	_generate_terrain()
	buildings.clear()
	for b in data["buildings"]:
		buildings[Vector2i(int(b["x"]), int(b["y"]))] = b["type"]
	workers.clear()
	_build_astar(); _center_camera()
	won = false; game_over = false
	_show_message("Loaded")


func _show_message(text: String) -> void:
	message = text; message_timer = 2.0


func _in_grid(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < GRID_W and cell.y >= 0 and cell.y < GRID_H


# ---------- Drawing ----------
func _draw() -> void:
	var stint := _season_tint()
	var vp := get_viewport_rect().size

	for row in range(GRID_H):
		for col in range(GRID_W):
			var center := grid_to_screen(col, row)
			if center.x < -80 or center.x > vp.x + 80 or center.y < -80 or center.y > vp.y + 120:
				continue
			var cell := Vector2i(col, row)
			var tex: Texture2D = tex_terrain[terrain[cell]]
			# Per-tile brightness variation breaks up the grid look
			var jitter := 0.93 + float(_hash_cell(cell) % 14) / 100.0
			var tint := Color(stint.r * jitter, stint.g * jitter, stint.b * jitter)
			draw_texture_rect(tex, Rect2(center - tex.get_size() * 0.5 * zoom, tex.get_size() * zoom), false, tint)
			if roads.has(cell):
				_draw_road(center)
			if cell == hovered and not won and not game_over:
				_draw_hover(center)

	var cells := buildings.keys()
	cells.sort_custom(func(a, b): return (a.x + a.y) < (b.x + b.y))
	for c in cells:
		var center := grid_to_screen(c.x, c.y)
		if center.x < -120 or center.x > vp.x + 120 or center.y < -200 or center.y > vp.y + 120:
			continue
		var tex: Texture2D = tex_building[buildings[c]]
		var anchor := Vector2(tex.get_width() * 0.5, tex.get_height() - TILE_H * 0.5)
		draw_texture_rect(tex, Rect2(center - anchor * zoom, tex.get_size() * zoom), false)

	_draw_workers(vp)
	_draw_ui()


func _hash_cell(c: Vector2i) -> int:
	return abs((c.x * 73856093) ^ (c.y * 19349663))


func _draw_workers(vp: Vector2) -> void:
	for w in workers:
		var sp := grid_to_screen_f(w["p"].x, w["p"].y)
		if sp.x < -20 or sp.x > vp.x + 20 or sp.y < -20 or sp.y > vp.y + 20:
			continue
		# tiny person: body + head
		draw_circle(sp + Vector2(0, -4 * zoom), 4.0 * zoom, Color(0.2, 0.2, 0.25))
		draw_circle(sp + Vector2(0, -10 * zoom), 2.6 * zoom, Color(0.95, 0.85, 0.65))


func _draw_road(center: Vector2) -> void:
	var hw := TILE_W * 0.34 * zoom
	var hh := TILE_H * 0.34 * zoom
	draw_colored_polygon(PackedVector2Array([
		center + Vector2(0, -hh), center + Vector2(hw, 0),
		center + Vector2(0, hh), center + Vector2(-hw, 0),
	]), Color(0.52, 0.47, 0.40, 0.9))


func _draw_hover(center: Vector2) -> void:
	var hw := TILE_W * 0.5 * zoom
	var hh := TILE_H * 0.5 * zoom
	draw_colored_polygon(PackedVector2Array([
		center + Vector2(0, -hh), center + Vector2(hw, 0),
		center + Vector2(0, hh), center + Vector2(-hw, 0),
	]), Color(1, 1, 1, 0.22))


func _season_tint() -> Color:
	match season_index():
		1: return Color(1.05, 1.05, 0.9)
		2: return Color(1.0, 0.9, 0.75)
		3: return Color(0.8, 0.85, 1.05)
		_: return Color(1, 1, 1)


func _draw_ui() -> void:
	var font := ThemeDB.fallback_font
	var capacity := 0
	for c in buildings.keys():
		var d: Dictionary = CATALOG[buildings[c]]
		if d["role"] == "pop": capacity += d["pop"]

	draw_string(font, Vector2(20, 30), "Wood: %d   Food: %d   Research: %d" % [wood, food, research],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color(1, 1, 1))
	draw_string(font, Vector2(20, 56), "Pop: %d / %d (goal %d)   Season: %s   Workers: %d" % [population, capacity, WIN_POP, SEASONS[season_index()], workers.size()],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.9, 0.95, 1))

	if _in_grid(hovered):
		var ht: String = terrain.get(hovered, "?")
		var note := ""
		if ht == "forest": note = " (clear for wood)"
		elif ht == "water" or ht == "mountain": note = " (cannot build)"
		elif ht == "fertile": note = " (farm bonus)"
		draw_string(font, Vector2(20, 80), "Tile: %s%s" % [ht, note], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.85, 0.9, 0.8))

	var x := 20.0
	for key in order:
		var d2: Dictionary = CATALOG[key]
		var idx := order.find(key) + 1
		var label := "[%d] %s" % [idx, d2["name"]]
		var col := Color(1, 1, 0.5) if key == selected else Color(0.7, 0.7, 0.7)
		if key == selected: label = "> " + label
		draw_string(font, Vector2(x, 104), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, col)
		x += 150

	var tx := 20.0
	for tname in TECHS.keys():
		var t: Dictionary = TECHS[tname]
		var owned: bool = tech[tname]
		var label := "[%s] %s (%d)" % [t["key"], tname, t["cost"]]
		var col := Color(0.5, 1, 0.6) if owned else (Color(0.9, 0.9, 0.6) if research >= t["cost"] else Color(0.6, 0.6, 0.6))
		if owned: label += " OK"
		draw_string(font, Vector2(tx, 126), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, col)
		tx += 175

	draw_string(font, Vector2(20, 148), "Arrows pan / Wheel zoom / Left build-or-clear / Right remove / 1-4 / Q-W-E / S L R",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.78, 0.78, 0.78))

	if event_text != "":
		draw_string(font, Vector2(20, 174), "* " + event_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(1, 0.8, 0.3))
	if message != "":
		draw_string(font, Vector2(20, 198), message, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.9, 0.9, 0.95))

	if won:
		_draw_banner(font, "YOU WIN!  Reached %d population" % WIN_POP, Color(0.4, 1, 0.5))
	elif game_over:
		_draw_banner(font, "GAME OVER  Your colony collapsed", Color(1, 0.4, 0.4))


func _draw_banner(font: Font, text: String, color: Color) -> void:
	var vp := get_viewport_rect().size
	draw_rect(Rect2(0, vp.y * 0.4, vp.x, 90), Color(0, 0, 0, 0.6))
	draw_string(font, Vector2(0, vp.y * 0.4 + 45), text, HORIZONTAL_ALIGNMENT_CENTER, vp.x, 34, color)
	draw_string(font, Vector2(0, vp.y * 0.4 + 78), "Press R for a new map", HORIZONTAL_ALIGNMENT_CENTER, vp.x, 18, Color(0.9, 0.9, 0.9))
