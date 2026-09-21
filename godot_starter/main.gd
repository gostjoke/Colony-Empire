extends Node2D
# =============================================================
#  Colony Empire — Lesson 10: Native villages & rival AI colonies
#  Builds on Lesson 9 (hex map, turns, cities, units). New:
#   - Native tribes: villages, tribal land, attitude (-100..100),
#     first-visit gifts, gold gifts, trade income, raids.
#   - Rival colonial nations run by a simple AI (expand, improve
#     land, garrison, research, court the tribes).
#   - National traits (GDD 6.1), vision (foreign units only show
#     near your own), diplomacy panel [D], final ranking in 1811.
#  Lesson 10b: unit sprites (Colonist / Scout / Guard) tinted with
#  each nation's colour at runtime; new Scout unit; Soldier -> Guard.
# =============================================================

const MAP_W := 70                 # columns (offset layout, odd rows shifted right)
const MAP_H := 44                 # rows
const HEX := 32.0                 # hex radius in px (center -> corner)
const SQ3 := 1.7320508
const NO_CELL := Vector2i(9999, 9999)

const START_YEAR := 1500
const YEARS_PER_TURN := 2
const END_YEAR := 1811
const START_GOLD := 20

const PAN_SPEED := 700.0
const CITY_MIN_DIST := 4          # cities must be at least 4 hexes apart
const FOOD_PER_POP := 2

const PLAYER_NATION := 0          # index into NATIONS — change to 1-3 to play another country
const AI_COUNT := 2               # rival colonial powers (max 3)

# Axial neighbour directions. Index i = the edge between CORNERS[i] and CORNERS[i+1].
const DIRS := [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 1),
		Vector2i(-1, 0), Vector2i(0, -1), Vector2i(1, -1)]
# Pointy-top hex corners (unit radius), starting upper-right, clockwise.
const CORNERS := [Vector2(0.8660254, -0.5), Vector2(0.8660254, 0.5), Vector2(0, 1),
		Vector2(-0.8660254, 0.5), Vector2(-0.8660254, -0.5), Vector2(0, -1)]

# f = food, p = production, g = gold, move = movement cost (0 = impassable)
const TERRAIN := {
	"ocean":    { "name": "Ocean",     "f": 1, "p": 0, "g": 0, "move": 0, "col": Color(0.12, 0.26, 0.47) },
	"coast":    { "name": "Coast",     "f": 1, "p": 0, "g": 1, "move": 0, "col": Color(0.22, 0.44, 0.65) },
	"grass":    { "name": "Grassland", "f": 2, "p": 0, "g": 0, "move": 1, "col": Color(0.40, 0.64, 0.30) },
	"plains":   { "name": "Plains",    "f": 1, "p": 1, "g": 0, "move": 1, "col": Color(0.70, 0.67, 0.38) },
	"forest":   { "name": "Forest",    "f": 1, "p": 2, "g": 0, "move": 2, "col": Color(0.26, 0.48, 0.23) },
	"hills":    { "name": "Hills",     "f": 0, "p": 2, "g": 0, "move": 2, "col": Color(0.58, 0.54, 0.35) },
	"mountain": { "name": "Mountain",  "f": 0, "p": 0, "g": 0, "move": 0, "col": Color(0.50, 0.48, 0.46) },
}
const VILLAGE_LAND := ["grass", "plains", "forest", "hills"]

# Colonial powers and their national traits (GDD 6.1)
const NATIONS := [
	{ "name": "England", "col": Color(0.25, 0.6, 1.0), "trait": "growth", "max_cities": 7,
		"desc": "Cities grow 20% faster",
		"cities": ["New Haven", "Kingsport", "Ashford", "Newbury", "Hartwell", "Dunmore", "Wexham", "Bramley", "Stonebridge", "Eastmarch"] },
	{ "name": "Spain", "col": Color(0.95, 0.75, 0.15), "trait": "military", "max_cities": 8,
		"desc": "Guards cost 40% less",
		"cities": ["San Miguel", "Santa Cruz", "Villa Rica", "San Lorenzo", "Santa Fe", "Valverde", "San Tomas", "Montalba", "Rio Claro", "Alcazar"] },
	{ "name": "France", "col": Color(0.72, 0.45, 0.95), "trait": "diplomacy", "max_cities": 6,
		"desc": "Tribes like you more, land grabs anger them less",
		"cities": ["Port-Royal", "Beaulieu", "Saint-Denis", "Montclair", "Belleville", "Rochefort", "Clairvaux", "Val-d'Or", "Sainte-Anne", "Bonport"] },
	{ "name": "Netherlands", "col": Color(1.0, 0.5, 0.15), "trait": "trade", "max_cities": 6,
		"desc": "Double tribe trade, +1 gold per city",
		"cities": ["Nieuwhaven", "Oranjestad", "Zeeburg", "Hoorndam", "Vlietstad", "Brederode", "Groenwijk", "Amstelkerk", "Waterveld", "Leeuwen"] },
]

# Native tribes (neutral NPCs)
const TRIBES := [
	{ "name": "River People",       "col": Color(0.30, 0.88, 0.78) },
	{ "name": "Hill Clans",         "col": Color(0.95, 0.45, 0.65) },
	{ "name": "Forest Nation",      "col": Color(0.93, 0.93, 0.88) },
	{ "name": "Plains Confederacy", "col": Color(0.85, 0.22, 0.30) },
]
const VILLAGES_PER_TRIBE := 5
const TRIBE_START_ATT := 10
const TRADE_ATT := 20             # attitude needed before a tribe trades with you
const TRADE_RANGE := 6            # ...and one of your cities must be this close to the village
const RAID_ATT := -40             # at or below this, the tribe raids you
const LAND_GRAB := 15             # attitude lost when you settle within 4 hexes of their village
const GIFT_GOLD := 20
const GIFT_ATT := 15

# sight = how many hexes the unit reveals. Units with a sprite in assets/units/ are drawn with it,
# the others fall back to a round token with the icon letter.
const UNITS := {
	"settler": { "name": "Colonist", "mp": 2, "cost": 30, "icon": "C", "sight": 2 },
	"worker":  { "name": "Worker",   "mp": 2, "cost": 20, "icon": "W", "sight": 2 },
	"scout":   { "name": "Scout",    "mp": 3, "cost": 20, "icon": "S", "sight": 3 },
	"guard":   { "name": "Guard",    "mp": 2, "cost": 25, "icon": "G", "sight": 2 },
}
const UNIT_ART := "res://assets/units/unit_%s.png"        # base art (team areas are grey)
const UNIT_TEAM := "res://assets/units/unit_%s_team.png"  # white = where the nation colour goes

const BUILDINGS := {
	"granary":  { "name": "Granary",  "cost": 40, "desc": "+2 food" },
	"workshop": { "name": "Workshop", "cost": 50, "desc": "+2 production" },
	"market":   { "name": "Market",   "cost": 50, "desc": "+3 gold" },
	"school":   { "name": "School",   "cost": 60, "desc": "+2 research" },
}
const BUILD_ORDER := ["settler", "worker", "scout", "guard", "granary", "workshop", "market", "school"]   # keys 1-8

const TECHS := {
	"irrigation": { "key": "Q", "cost": 20, "desc": "Farms +1 food" },
	"iron_tools": { "key": "W", "cost": 35, "desc": "Mines +1 prod, faster workers" },
	"vaccines":   { "key": "E", "cost": 50, "desc": "No disease events" },
}

# Worker jobs: how many turns, and which terrain allows them
const JOBS := {
	"farm": { "turns": 3, "on": ["grass", "plains"] },
	"mine": { "turns": 3, "on": ["hills"] },
	"road": { "turns": 1, "on": ["grass", "plains", "forest", "hills"] },
	"chop": { "turns": 2, "on": ["forest"] },
}
const CHOP_PROD := 12

var origin := Vector2.ZERO
var zoom := 1.0
var map_seed := 0

var terrain := {}        # Vector2i(q, r) axial -> terrain key
var chopped := {}        # forests cut by workers (re-applied when the map is regenerated)
var improvements := {}   # cell -> "farm" / "mine"
var roads := {}          # cell -> true
var seen := {}           # cell -> true  (explored by the player)
var in_sight := {}       # cell -> true  (the player can see it right now)
var territory := {}      # cell -> city id

var nations := []        # [0] = player. Each: { def, gold, research, tech, met, founded }
var cities := []         # Array of Dictionary (every nation)
var city_at := {}        # cell -> city
var city_index := {}     # city id -> city
var units := []          # Array of Dictionary (every nation)
var next_id := 1

var tribes := []         # Each: { att: [attitude toward nation 0, 1, ...], met }
var villages := []       # Each: { id, tribe, cell, visited }
var village_at := {}     # cell -> village
var tribe_land := {}     # cell -> tribe index

var astar := AStar2D.new()
var turn := 1

var selected_unit := {}
var selected_city := {}
var hovered := Vector2i(9999, 9999)
var preview_path := []
var preview_key := []
var show_diplo := false
var unit_tex := {}       # "type:nation" -> tinted ImageTexture (built on first use)

var message := ""
var message_timer := 0.0
var event_text := ""
var event_timer := 0.0
var game_over := false


func _ready() -> void:
	randomize()
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS   # sprites stay smooth when zoomed out
	_restart()


# ---------- Nation helpers ----------
func me() -> Dictionary:
	return nations[0]


func ndef(n: int) -> Dictionary:
	return NATIONS[nations[n]["def"]]


func ncol(n: int) -> Color:
	return ndef(n)["col"]


func has_trait(n: int, t: String) -> bool:
	return ndef(n)["trait"] == t


func _new_nation(def: int) -> Dictionary:
	var tech := {}
	for k in TECHS.keys():
		tech[k] = false
	return { "def": def, "gold": START_GOLD, "research": 0, "tech": tech, "met": false, "founded": 0 }


# ---------- Hex math (axial coordinates) ----------
func offset_to_axial(col: int, row: int) -> Vector2i:
	return Vector2i(col - (row >> 1), row)


func axial_to_offset(c: Vector2i) -> Vector2i:
	return Vector2i(c.x + (c.y >> 1), c.y)


func hex_to_world(c: Vector2i) -> Vector2:
	return Vector2(HEX * SQ3 * (c.x + c.y * 0.5), HEX * 1.5 * c.y)


func world_to_screen(w: Vector2) -> Vector2:
	return origin + w * zoom


func hex_to_screen(c: Vector2i) -> Vector2:
	return origin + hex_to_world(c) * zoom


func screen_to_hex(pos: Vector2) -> Vector2i:
	var p := (pos - origin) / zoom
	return _hex_round((SQ3 / 3.0 * p.x - p.y / 3.0) / HEX, (2.0 / 3.0 * p.y) / HEX)


func _hex_round(qf: float, rf: float) -> Vector2i:
	var sf := -qf - rf
	var q := roundi(qf)
	var r := roundi(rf)
	var s := roundi(sf)
	var dq := absf(q - qf)
	var dr := absf(r - rf)
	var ds := absf(s - sf)
	if dq > dr and dq > ds:
		q = -r - s
	elif dr > ds:
		r = -q - s
	return Vector2i(q, r)


func hex_dist(a: Vector2i, b: Vector2i) -> int:
	var dq := a.x - b.x
	var dr := a.y - b.y
	return (absi(dq) + absi(dr) + absi(dq + dr)) / 2


func hexes_in_range(c: Vector2i, n: int) -> Array:
	var out := []
	for dq in range(-n, n + 1):
		for dr in range(maxi(-n, -dq - n), mini(n, -dq + n) + 1):
			var h := Vector2i(c.x + dq, c.y + dr)
			if terrain.has(h):
				out.append(h)
	return out


func _min_dist(c: Vector2i, cells: Array) -> int:
	var best := 999
	for o in cells:
		best = mini(best, hex_dist(c, o))
	return best


# ---------- Map ----------
func _generate_terrain() -> void:
	terrain.clear()
	var elev := FastNoiseLite.new()
	elev.seed = map_seed
	elev.frequency = 0.06
	var moist := FastNoiseLite.new()
	moist.seed = map_seed + 1000
	moist.frequency = 0.09
	for row in range(MAP_H):
		for col in range(MAP_W):
			var x := col + (row & 1) * 0.5
			var y := row * 0.866
			# Push the map edges down into ocean -> one "New World" continent
			var nx := (x / MAP_W - 0.5) * 2.0
			var ny := (row / float(MAP_H) - 0.5) * 2.0
			var edge := maxf(absf(nx), absf(ny))
			var e := (elev.get_noise_2d(x, y) + 1.0) * 0.5 + 0.12 - edge * edge * 0.55
			var m := (moist.get_noise_2d(x, y) + 1.0) * 0.5
			var t := "grass"
			if e < 0.36: t = "ocean"
			elif e > 0.74: t = "mountain"
			elif e > 0.64: t = "hills"
			elif m > 0.58: t = "forest"
			elif m < 0.42: t = "plains"
			terrain[offset_to_axial(col, row)] = t
	for c in chopped.keys():
		terrain[c] = "plains"
	# Ocean next to land becomes shallow coast
	for c in terrain.keys():
		if terrain[c] != "ocean":
			continue
		for d in DIRS:
			var n: Vector2i = c + d
			if terrain.has(n) and not _is_water(terrain[n]):
				terrain[c] = "coast"
				break


func _is_water(t: String) -> bool:
	return t == "ocean" or t == "coast"


func _coastal(c: Vector2i) -> bool:
	for d in DIRS:
		if _is_water(terrain.get(c + d, "")):
			return true
	return false


func _passable(c: Vector2i) -> bool:
	return terrain.has(c) and TERRAIN[terrain[c]]["move"] > 0 and not village_at.has(c)


func _move_cost(c: Vector2i) -> float:
	if roads.has(c) or city_at.has(c):
		return 0.5
	return float(TERRAIN[terrain[c]]["move"])


func _land_count(c: Vector2i, n: int) -> int:
	var k := 0
	for h in hexes_in_range(c, n):
		if _passable(h):
			k += 1
	return k


func _pick_start(avoid: Array) -> Vector2i:
	# Ships arrive from Europe (east): prefer east-coast grass/plains far from other colonies.
	# Each pass relaxes the rules a bit in case the map is awkward.
	for pass_i in 3:
		var cands := []
		for c in terrain.keys():
			var t: String = terrain[c]
			if t != "grass" and t != "plains":
				continue
			if pass_i < 2 and (axial_to_offset(c).x < MAP_W * 0.5 or not _coastal(c)):
				continue
			if pass_i == 0 and _land_count(c, 2) < 12:
				continue
			if _min_dist(c, avoid) < (12 if pass_i < 2 else 6):
				continue
			cands.append(c)
		if not cands.is_empty():
			return cands[randi() % cands.size()]
	for c in terrain.keys():
		if _passable(c):
			return c
	return offset_to_axial(MAP_W / 2, MAP_H / 2)


func _place_tribes(starts: Array) -> void:
	var land := []
	for c in terrain.keys():
		if terrain[c] in VILLAGE_LAND:
			land.append(c)
	land.shuffle()
	var homes := []
	var vcells := []
	for t in TRIBES.size():
		var att := []
		for n in nations.size():
			att.append(TRIBE_START_ATT + (20 if has_trait(n, "diplomacy") else 0))
		tribes.append({ "att": att, "met": false })
		# 1) a homeland far from the colonists and from other tribes
		var home := NO_CELL
		for c in land:
			if _min_dist(c, starts) >= 7 and _min_dist(c, homes) >= 9 and _land_count(c, 3) >= 20:
				home = c
				break
		if home == NO_CELL:
			continue
		homes.append(home)
		# 2) a few villages around it, each owning the hexes next to it
		var spots := hexes_in_range(home, 5)
		spots.shuffle()
		var placed := 0
		for c in spots:
			if placed >= VILLAGES_PER_TRIBE:
				break
			if not (terrain[c] in VILLAGE_LAND) or tribe_land.has(c):
				continue
			if _min_dist(c, starts) < 5 or _min_dist(c, vcells) < 3:
				continue
			var v := { "id": next_id, "tribe": t, "cell": c, "visited": false }
			next_id += 1
			villages.append(v)
			village_at[c] = v
			vcells.append(c)
			placed += 1
			for h in hexes_in_range(c, 1):
				if not tribe_land.has(h) and not _is_water(terrain[h]):
					tribe_land[h] = t


# ---------- Pathfinding (AStar2D on the hex graph) ----------
func _cid(c: Vector2i) -> int:
	var o := axial_to_offset(c)
	return o.y * MAP_W + o.x


func _cell_from_id(id: int) -> Vector2i:
	return offset_to_axial(id % MAP_W, id / MAP_W)


func _build_astar() -> void:
	astar.clear()
	# Positions are scaled so neighbours are 0.5 apart; weight = cost * 2
	# -> the path cost equals the movement points spent (and the heuristic stays admissible).
	for c in terrain.keys():
		if _passable(c):
			astar.add_point(_cid(c), hex_to_world(c) / (HEX * SQ3) * 0.5, _move_cost(c) * 2.0)
	for c in terrain.keys():
		if not _passable(c):
			continue
		for i in 3:   # E, SE, SW — the other three are covered from the neighbour's side
			var n: Vector2i = c + DIRS[i]
			if _passable(n):
				astar.connect_points(_cid(c), _cid(n))


func _update_astar_cell(c: Vector2i) -> void:
	if astar.has_point(_cid(c)):
		astar.set_point_weight_scale(_cid(c), _move_cost(c) * 2.0)


func _find_path(from: Vector2i, to: Vector2i) -> Array:
	if from == to or not _passable(to) or not _passable(from):
		return []
	var ids := astar.get_id_path(_cid(from), _cid(to))
	var out := []
	for i in range(1, ids.size()):
		out.append(_cell_from_id(ids[i]))
	return out


func _path_turns(u: Dictionary, path: Array) -> int:
	var mp: float = u["mp"]
	var full := float(UNITS[u["type"]]["mp"])
	var turns := 1
	for c in path:
		if mp <= 0.0:
			turns += 1
			mp = full
		mp -= _move_cost(c)
	return turns


# ---------- Units ----------
func _spawn_unit(type: String, cell: Vector2i, n: int) -> Dictionary:
	var u := { "id": next_id, "owner": n, "type": type, "cell": cell, "mp": float(UNITS[type]["mp"]),
		"path": [], "job": "", "job_left": 0, "sleep": false, "goal": NO_CELL, "dp": hex_to_world(cell) }
	next_id += 1
	units.append(u)
	if n == 0:
		_reveal(cell, _sight(u))
	return u


func _sight(u: Dictionary) -> int:
	return UNITS[u["type"]]["sight"]


func _remove_unit(u: Dictionary) -> void:
	for i in units.size():
		if units[i]["id"] == u["id"]:
			units.remove_at(i)
			break
	if _is_same(u, selected_unit):
		selected_unit = {}


func _units_at(cell: Vector2i, n: int) -> Array:
	return units.filter(func(u): return u["cell"] == cell and u["owner"] == n)


func _needs_orders(u: Dictionary) -> bool:
	return u["owner"] == 0 and u["mp"] > 0.0 and u["path"].is_empty() and u["job"] == "" and not u["sleep"]


func _advance_unit(u: Dictionary) -> void:
	var path: Array = u["path"]
	while not path.is_empty() and u["mp"] > 0.0:
		var nxt: Vector2i = path.pop_front()
		if not _passable(nxt):
			path.clear()
			break
		u["mp"] = maxf(0.0, u["mp"] - _move_cost(nxt))   # Civ rule: you can always take one step
		u["cell"] = nxt
		if u["owner"] == 0:
			_reveal(nxt, _sight(u))
			for d in DIRS:   # walking up to a village you haven't visited = meet the chief
				var v: Dictionary = village_at.get(nxt + d, {})
				if not v.is_empty() and not v["visited"]:
					_visit_village(v, u)


func _reveal(c: Vector2i, n: int) -> void:
	for h in hexes_in_range(c, n):
		seen[h] = true


func _start_job(u: Dictionary, job: String) -> bool:
	if u["type"] != "worker":
		return false
	var c: Vector2i = u["cell"]
	var t: String = terrain[c]
	var spec: Dictionary = JOBS[job]
	var why := ""
	if city_at.has(c):
		why = "Not on a city tile"
	elif not (t in spec["on"]):
		why = "Can't %s on %s" % [job, TERRAIN[t]["name"]]
	elif (job == "road" and roads.has(c)) or improvements.get(c, "") == job:
		why = "Already done here"
	elif territory.has(c) and _cell_nation(c) != u["owner"]:
		why = "That is foreign land"
	elif tribe_land.has(c) and job != "road":
		why = "That land belongs to the %s" % TRIBES[tribe_land[c]]["name"]
	if why != "":
		if u["owner"] == 0: _show_message(why)
		return false
	var turns: int = spec["turns"]
	if nations[u["owner"]]["tech"]["iron_tools"]:
		turns = maxi(1, turns - 1)
	u["job"] = job
	u["job_left"] = turns
	u["mp"] = 0.0
	u["path"] = []
	if u["owner"] == 0: _show_message("Worker: %s (%d turns)" % [job, turns])
	return true


func _finish_job(u: Dictionary) -> void:
	var c: Vector2i = u["cell"]
	match u["job"]:
		"farm", "mine":
			improvements[c] = u["job"]
		"road":
			roads[c] = true
		"chop":
			terrain[c] = "plains"
			chopped[c] = true
			var city := _city_by_id(territory.get(c, -1))
			if not city.is_empty() and city["owner"] == u["owner"]:
				city["prod"] += CHOP_PROD
				if u["owner"] == 0:
					_show_event("Forest cut: +%d production for %s" % [CHOP_PROD, city["name"]])
	u["job"] = ""
	_update_astar_cell(c)


# ---------- Cities ----------
func _cell_nation(c: Vector2i) -> int:
	if not territory.has(c):
		return -1
	return city_index[territory[c]]["owner"]


func _found_problem(c: Vector2i, n: int) -> String:
	if not _passable(c):
		return "Can't settle here"
	if tribe_land.has(c):
		return "This land belongs to the %s" % TRIBES[tribe_land[c]]["name"]
	if territory.has(c) and _cell_nation(c) != n:
		return "Inside %s borders" % ndef(_cell_nation(c))["name"]
	for other in cities:
		if hex_dist(other["cell"], c) < CITY_MIN_DIST:
			return "Too close to %s" % other["name"]
	return ""


func _found_city(u: Dictionary) -> bool:
	if u["type"] != "settler":
		return false
	var n: int = u["owner"]
	var c: Vector2i = u["cell"]
	var why := _found_problem(c, n)
	if why != "":
		if n == 0: _show_message(why)
		return false
	var nat: Dictionary = nations[n]
	var names: Array = ndef(n)["cities"]
	var city_name: String = names[nat["founded"] % names.size()]
	if nat["founded"] >= names.size():
		city_name += " II"
	nat["founded"] += 1
	var city := { "id": next_id, "owner": n, "name": city_name, "cell": c, "pop": 1, "food": 0, "prod": 0,
		"build": "worker" if n == 0 else "", "blds": [], "culture": 0, "radius": 1 }
	next_id += 1
	cities.append(city)
	city_at[c] = city
	city_index[city["id"]] = city
	_claim(city)
	_update_astar_cell(c)
	_remove_unit(u)
	# Settling near a village is a land grab: that tribe likes you less
	var upset := {}
	for v in villages:
		if hex_dist(v["cell"], c) <= 4:
			upset[v["tribe"]] = true
	var penalty := LAND_GRAB / 2 if has_trait(n, "diplomacy") else LAND_GRAB
	for t in upset.keys():
		tribes[t]["att"][n] -= penalty
		if n == 0:
			_show_event("The %s resent your new settlement  (-%d attitude)" % [TRIBES[t]["name"], penalty])
	if n == 0:
		_reveal(c, 3)
		_recompute_vision()
		_select(city)
		_show_message("Founded %s!  Pick what to build with 1-8" % city_name)
	return true


func _claim(city: Dictionary) -> void:
	for h in hexes_in_range(city["cell"], city["radius"]):
		if not territory.has(h) and not tribe_land.has(h):
			territory[h] = city["id"]
			if city["owner"] == 0:
				seen[h] = true


func _city_by_id(id: int) -> Dictionary:
	return city_index.get(id, {})


func _nearest_city(c: Vector2i, n: int, max_d: int = 999) -> Dictionary:
	var best := {}
	var bd := max_d + 1
	for city in cities:
		if city["owner"] == n and hex_dist(city["cell"], c) < bd:
			bd = hex_dist(city["cell"], c)
			best = city
	return best


func tile_yield(c: Vector2i, n: int = 0) -> Vector3i:
	var t: Dictionary = TERRAIN[terrain[c]]
	var y := Vector3i(t["f"], t["p"], t["g"])
	var tech: Dictionary = nations[n]["tech"]
	match improvements.get(c, ""):
		"farm": y.x += (2 if tech["irrigation"] else 1)
		"mine": y.y += (2 if tech["iron_tools"] else 1)
	return y


func _tile_score(c: Vector2i, n: int) -> int:
	var y := tile_yield(c, n)
	return y.x * 4 + y.y * 2 + y.z      # citizens favour food so cities grow


func city_yield(city: Dictionary) -> Dictionary:
	var n: int = city["owner"]
	var center: Vector2i = city["cell"]
	var cy := tile_yield(center, n)
	var total := Vector3i(maxi(cy.x, 2), maxi(cy.y, 1), cy.z + 1)   # city centre: at least 2F 1P, +1 gold
	if has_trait(n, "trade"):
		total.z += 1
	var options := []
	for h in territory.keys():
		if territory[h] == city["id"] and h != center:
			options.append(h)
	options.sort_custom(func(a, b): return _tile_score(a, n) > _tile_score(b, n))
	var worked := options.slice(0, city["pop"])    # 1 citizen works 1 tile
	for h in worked:
		total += tile_yield(h, n)
	var blds: Array = city["blds"]
	if "granary" in blds: total.x += 2
	if "workshop" in blds: total.y += 2
	if "market" in blds: total.z += 3
	var sci: int = 1 + int(city["pop"]) / 2 + (2 if "school" in blds else 0)
	return { "f": total.x, "p": total.y, "g": total.z, "sci": sci,
		"eat": int(city["pop"]) * FOOD_PER_POP, "worked": worked }


func growth_need(city: Dictionary) -> int:
	var need := 8 + 5 * int(city["pop"])
	if has_trait(city["owner"], "growth"):
		need = int(need * 0.8)
	return need


func border_need(city: Dictionary) -> int:
	return 10 if city["radius"] == 1 else 40


func build_cost(item: String, n: int = 0) -> int:
	if UNITS.has(item):
		var cost: int = UNITS[item]["cost"]
		if item == "guard" and has_trait(n, "military"):
			cost = int(cost * 0.6)
		return cost
	if BUILDINGS.has(item): return BUILDINGS[item]["cost"]
	return 999999


func _item_name(item: String) -> String:
	if UNITS.has(item): return UNITS[item]["name"]
	if BUILDINGS.has(item): return BUILDINGS[item]["name"]
	return "(nothing)"


func _can_complete(city: Dictionary, item: String) -> bool:
	return not (item == "settler" and city["pop"] < 2)


func _complete(city: Dictionary, item: String) -> void:
	if UNITS.has(item):
		_spawn_unit(item, city["cell"], city["owner"])
		if item == "settler":
			city["pop"] -= 1
	else:
		city["blds"].append(item)
	city["build"] = ""
	if city["owner"] == 0:
		_show_event("%s finished: %s" % [city["name"], _item_name(item)])


func _process_city(city: Dictionary) -> void:
	var nat: Dictionary = nations[city["owner"]]
	var y := city_yield(city)
	nat["gold"] += y["g"]
	nat["research"] += y["sci"]
	# Food -> growth / starvation
	city["food"] += y["f"] - y["eat"]
	if city["food"] >= growth_need(city):
		city["food"] -= growth_need(city)
		city["pop"] += 1
	elif city["food"] < 0:
		city["food"] = 0
		if city["pop"] > 1:
			city["pop"] -= 1
			if city["owner"] == 0:
				_show_event("%s is starving!" % city["name"])
	# Culture -> borders grow (radius 1 -> 2 -> 3)
	city["culture"] += 1 + int(city["pop"]) / 2
	if city["radius"] < 3 and city["culture"] >= border_need(city):
		city["culture"] = 0
		city["radius"] += 1
		_claim(city)
	# Production (wasted if nothing is chosen — pick something!)
	var item: String = city["build"]
	if item != "":
		city["prod"] += y["p"]
		var cost := build_cost(item, city["owner"])
		if city["prod"] >= cost and _can_complete(city, item):
			city["prod"] -= cost
			_complete(city, item)


func _buy(city: Dictionary) -> void:
	var item: String = city["build"]
	if item == "":
		_show_message("Choose something to build first (1-8)"); return
	if not _can_complete(city, item):
		_show_message("A Colonist needs a city of size 2+"); return
	var cost: int = (build_cost(item) - int(city["prod"])) * 2
	if cost <= 0:
		_show_message("Already paid — it finishes at end of turn"); return
	if me()["gold"] < cost:
		_show_message("Need %d gold to buy %s" % [cost, _item_name(item)]); return
	me()["gold"] -= cost
	city["prod"] = 0
	_complete(city, item)


# ---------- Native tribes ----------
func mood(a: int) -> String:
	if a >= 50: return "Allied"
	if a >= TRADE_ATT: return "Friendly"
	if a > -20: return "Wary"
	if a > RAID_ATT: return "Angry"
	return "Hostile"


func _tribe_alive(t: int) -> bool:
	for v in villages:
		if v["tribe"] == t:
			return true
	return false


func _village_near(c: Vector2i) -> Dictionary:
	for h in hexes_in_range(c, 1):
		if village_at.has(h):
			return village_at[h]
	return {}


func _visit_village(v: Dictionary, u: Dictionary) -> void:
	# Scouts are trained to speak with chiefs: better welcome, bigger gifts
	var bonus := 1.5 if u["type"] == "scout" else 1.0
	v["visited"] = true
	var t: int = v["tribe"]
	var tname: String = TRIBES[t]["name"]
	tribes[t]["att"][0] += 15 if u["type"] == "scout" else 10
	var who := "your scout" if u["type"] == "scout" else "you"
	match randi() % 4:
		0:
			var g := int((15 + randi() % 26) * bonus)
			me()["gold"] += g
			_show_event("The %s chief welcomes %s with gifts:  +%d gold" % [tname, who, g])
		1:
			_reveal(v["cell"], 8 if u["type"] == "scout" else 6)
			_show_event("%s hunters share their maps with %s" % [tname, who])
		2:
			var rs := int(15 * bonus)
			me()["research"] += rs
			_show_event("The %s teach %s about this land:  +%d research" % [tname, who, rs])
		3:
			var city := _nearest_city(v["cell"], 0)
			if city.is_empty():
				var g2 := int(20 * bonus)
				me()["gold"] += g2
				_show_event("The %s trade furs with %s:  +%d gold" % [tname, who, g2])
			else:
				var fd := int(12 * bonus)
				city["food"] += fd
				_show_event("The %s share food with %s:  +%d food" % [tname, city["name"], fd])


func _gift(n: int, t: int) -> bool:
	if nations[n]["gold"] < GIFT_GOLD:
		if n == 0: _show_message("A gift costs %d gold" % GIFT_GOLD)
		return false
	nations[n]["gold"] -= GIFT_GOLD
	var gain := GIFT_ATT + (5 if has_trait(n, "diplomacy") else 0)
	tribes[t]["att"][n] = mini(100, tribes[t]["att"][n] + gain)
	if n == 0:
		_show_message("The %s accept your gift  (+%d attitude, now %s)" % [TRIBES[t]["name"], gain, mood(tribes[t]["att"][0])])
	return true


func _trade_income(n: int, only_tribe: int = -1) -> int:
	var total := 0
	for v in villages:
		if only_tribe >= 0 and v["tribe"] != only_tribe:
			continue
		if tribes[v["tribe"]]["att"][n] >= TRADE_ATT and not _nearest_city(v["cell"], n, TRADE_RANGE).is_empty():
			total += 2 if has_trait(n, "trade") else 1
	return total


func _raid(t: int, n: int) -> void:
	var target := {}
	var best := 999
	for v in villages:
		if v["tribe"] != t:
			continue
		var city := _nearest_city(v["cell"], n, 8)
		if not city.is_empty() and hex_dist(city["cell"], v["cell"]) < best:
			best = hex_dist(city["cell"], v["cell"])
			target = city
	if target.is_empty():
		return
	var nat: Dictionary = nations[n]
	var loot: int = mini(nat["gold"], 10 + randi() % 20)
	nat["gold"] -= loot
	var lost := ""
	var imps := []
	for h in improvements.keys():
		if territory.get(h, -1) == target["id"]:
			imps.append(h)
	if not imps.is_empty():
		var h: Vector2i = imps[randi() % imps.size()]
		lost = ", a %s was burned" % improvements[h]
		improvements.erase(h)
	if n == 0:
		_show_event("%s warriors raided %s!  -%d gold%s" % [TRIBES[t]["name"], target["name"], loot, lost])


func _tribes_turn() -> void:
	for t in tribes.size():
		var att: Array = tribes[t]["att"]
		for n in att.size():
			if att[n] <= RAID_ATT and randf() < 0.2:
				_raid(t, n)
			if att[n] < 0 and randf() < 0.25:
				att[n] += 1          # grudges slowly fade
	for n in nations.size():
		nations[n]["gold"] += _trade_income(n)


# ---------- AI colonial nations ----------
func _ai_turn(n: int) -> void:
	var nat: Dictionary = nations[n]
	for key in TECHS.keys():
		if not nat["tech"][key] and nat["research"] >= TECHS[key]["cost"]:
			nat["research"] -= TECHS[key]["cost"]
			nat["tech"][key] = true
	# Keep the natives friendly when there's spare gold
	if nat["gold"] >= 60:
		var worst := -1
		for t in tribes.size():
			if not _tribe_alive(t) or tribes[t]["att"][n] >= TRADE_ATT + 10:
				continue
			if worst < 0 or tribes[t]["att"][n] < tribes[worst]["att"][n]:
				worst = t
		if worst >= 0:
			_gift(n, worst)
	for u in units.duplicate():
		if u["owner"] != n or not u["path"].is_empty() or u["job"] != "" or u["sleep"]:
			continue
		match u["type"]:
			"settler": _ai_settler(u)
			"worker": _ai_worker(u)
			"guard": _ai_guard(u)
			"scout": _ai_scout(u)
	for city in cities:
		if city["owner"] != n:
			continue
		if city["build"] == "":
			city["build"] = _ai_pick_build(n, city)
		# Rich AI rush-buys production (keeps a reserve of 80 gold)
		var item: String = city["build"]
		if item != "" and _can_complete(city, item):
			var cost: int = (build_cost(item, n) - int(city["prod"])) * 2
			if cost > 0 and nat["gold"] >= cost + 80:
				nat["gold"] -= cost
				city["prod"] = 0
				_complete(city, item)


func _ai_pick_build(n: int, city: Dictionary) -> String:
	var count := { "city": 0 }
	for key in UNITS.keys():
		count[key] = 0
	for c in cities:
		if c["owner"] == n:
			count["city"] += 1
			if UNITS.has(c["build"]):
				count[c["build"]] += 1
	for u in units:
		if u["owner"] == n:
			count[u["type"]] += 1
	var max_c: int = ndef(n)["max_cities"]
	if count["city"] + count["settler"] < max_c and count["settler"] == 0:
		return "settler"
	if count["worker"] < count["city"]:
		return "worker"
	if count["guard"] < count["city"]:
		return "guard"
	for b in ["granary", "market", "workshop", "school"]:
		if not (b in city["blds"]):
			return b
	if int(city["pop"]) >= 4 and count["city"] + count["settler"] < max_c:
		return "settler"
	return ""


func _goal_taken(c: Vector2i, n: int, except_id: int) -> bool:
	for u in units:
		if u["owner"] == n and u["id"] != except_id and u["goal"] == c:
			return true
	return false


func _site_score(h: Vector2i, n: int) -> float:
	var s := 0.0
	for c in hexes_in_range(h, 2):
		if tribe_land.has(c) or (territory.has(c) and _cell_nation(c) != n):
			continue
		var y := tile_yield(c, n)
		s += y.x * 3 + y.y * 2 + y.z
	if _coastal(h):
		s += 4
	for v in villages:      # avoid angering tribes that already dislike us
		if hex_dist(v["cell"], h) <= 4:
			s -= 8 if tribes[v["tribe"]]["att"][n] < 0 else 2
	return s


func _ai_find_site(u: Dictionary) -> Vector2i:
	var n: int = u["owner"]
	for radius in [9, 16]:      # look nearby first, then further away
		var cands := []
		for h in hexes_in_range(u["cell"], radius):
			if _found_problem(h, n) != "" or _goal_taken(h, n, u["id"]):
				continue
			cands.append([_site_score(h, n) - hex_dist(u["cell"], h) * 2.0, h])
		cands.sort_custom(func(a, b): return a[0] > b[0])
		for i in mini(4, cands.size()):
			var h: Vector2i = cands[i][1]
			if h == u["cell"] or not _find_path(u["cell"], h).is_empty():
				return h
	return NO_CELL


func _ai_go(u: Dictionary, goal: Vector2i) -> void:
	u["goal"] = goal
	u["path"] = _find_path(u["cell"], goal)
	_advance_unit(u)


func _ai_settler(u: Dictionary) -> void:
	var n: int = u["owner"]
	var first_city := true
	for c in cities:
		if c["owner"] == n:
			first_city = false
			break
	if first_city and _found_problem(u["cell"], n) == "":
		_found_city(u)       # the first colony is founded where the ship lands
		return
	var goal: Vector2i = u["goal"]
	if goal == NO_CELL or _found_problem(goal, n) != "":
		goal = _ai_find_site(u)
		if goal == NO_CELL:
			if _found_problem(u["cell"], n) == "":
				_found_city(u)
			else:
				u["mp"] = 0.0
			return
	if u["cell"] != goal:
		_ai_go(u, goal)
	if u["cell"] == goal:
		_found_city(u)


func _ai_job_for(c: Vector2i, n: int) -> String:
	if _cell_nation(c) != n or city_at.has(c) or improvements.has(c):
		return ""
	match terrain[c]:
		"grass", "plains": return "farm"
		"hills": return "mine"
	return ""


func _worker_busy_at(c: Vector2i, except_id: int) -> bool:
	for u in units:
		if u["id"] != except_id and u["cell"] == c and u["job"] != "":
			return true
	return false


func _ai_worker(u: Dictionary) -> void:
	var n: int = u["owner"]
	var here := _ai_job_for(u["cell"], n)
	if here != "" and not _worker_busy_at(u["cell"], u["id"]):
		_start_job(u, here)
		return
	var best := NO_CELL
	var bd := 999
	for h in hexes_in_range(u["cell"], 8):
		if _ai_job_for(h, n) == "" or _goal_taken(h, n, u["id"]) or _worker_busy_at(h, u["id"]):
			continue
		if hex_dist(u["cell"], h) < bd:
			bd = hex_dist(u["cell"], h)
			best = h
	if best == NO_CELL:
		u["mp"] = 0.0
		return
	_ai_go(u, best)
	if u["cell"] == best and u["mp"] > 0.0:
		_start_job(u, _ai_job_for(best, n))


func _guarded(city: Dictionary, except_id: int) -> bool:
	for u in units:
		if u["owner"] == city["owner"] and u["type"] == "guard" and u["sleep"] \
				and u["cell"] == city["cell"] and u["id"] != except_id:
			return true
	return false


func _ai_scout(u: Dictionary) -> void:
	# Wander to a random far-away land hex (a very simple explorer)
	var opts := hexes_in_range(u["cell"], 10).filter(func(h): return _passable(h) and hex_dist(h, u["cell"]) >= 5)
	if opts.is_empty():
		u["mp"] = 0.0
		return
	_ai_go(u, opts[randi() % opts.size()])


func _ai_guard(u: Dictionary) -> void:
	var n: int = u["owner"]
	var here: Dictionary = city_at.get(u["cell"], {})
	if not here.is_empty() and here["owner"] == n and not _guarded(here, u["id"]):
		u["sleep"] = true      # garrison this city
		return
	var best := NO_CELL
	var bd := 999
	for city in cities:
		if city["owner"] != n or _guarded(city, u["id"]) or _goal_taken(city["cell"], n, u["id"]):
			continue
		if hex_dist(u["cell"], city["cell"]) < bd:
			bd = hex_dist(u["cell"], city["cell"])
			best = city["cell"]
	if best == NO_CELL:
		# Every city is guarded: patrol nearby
		var opts := hexes_in_range(u["cell"], 3).filter(func(h): return _passable(h))
		if opts.is_empty():
			return
		best = opts[randi() % opts.size()]
	_ai_go(u, best)


# ---------- Vision & contact ----------
func _recompute_vision() -> void:
	in_sight.clear()
	for u in units:
		if u["owner"] == 0:
			for h in hexes_in_range(u["cell"], _sight(u)):
				in_sight[h] = true
	for city in cities:
		if city["owner"] == 0:
			for h in hexes_in_range(city["cell"], 3):
				in_sight[h] = true
	for h in in_sight.keys():
		seen[h] = true
	for u in units:
		if u["owner"] != 0 and in_sight.has(u["cell"]):
			_meet(u["owner"])
	for city in cities:
		if city["owner"] != 0 and seen.has(city["cell"]):
			_meet(city["owner"])
	for v in villages:
		var t: int = v["tribe"]
		if seen.has(v["cell"]) and not tribes[t]["met"]:
			tribes[t]["met"] = true
			_show_event("You have met the %s  (walk next to a village to visit)" % TRIBES[t]["name"])


func _meet(n: int) -> void:
	if nations[n]["met"]:
		return
	nations[n]["met"] = true
	_show_event("You have met the colonists of %s!  (press D for diplomacy)" % ndef(n)["name"])


# ---------- Turn ----------
func year() -> int:
	return START_YEAR + (turn - 1) * YEARS_PER_TURN


func _end_turn() -> void:
	if game_over:
		return
	for city in cities.duplicate():
		_process_city(city)
	for u in units:
		if u["job"] != "":
			u["job_left"] -= 1
			if u["job_left"] <= 0:
				_finish_job(u)
	_tribes_turn()
	if randf() < 0.15:
		_trigger_event()
	turn += 1
	# New turn: refill movement and continue multi-turn move orders (everyone)
	for u in units:
		u["mp"] = float(UNITS[u["type"]]["mp"])
		if not u["path"].is_empty():
			_advance_unit(u)
	for n in range(1, nations.size()):
		_ai_turn(n)
	_recompute_vision()
	if year() >= END_YEAR:
		game_over = true
	selected_unit = {}
	_select_next_unit()


func _trigger_event() -> void:
	var mine := cities.filter(func(c): return c["owner"] == 0)
	if mine.is_empty():
		return
	var city: Dictionary = mine[randi() % mine.size()]
	var pool := ["harvest", "ship", "migrants", "fire"]
	if not me()["tech"]["vaccines"]:
		pool.append("disease")
	match pool[randi() % pool.size()]:
		"harvest":  city["food"] += 15; _show_event("Bountiful harvest in %s!  +15 food" % city["name"])
		"ship":     me()["gold"] += 30; _show_event("Merchant ship from Europe!  +30 gold")
		"migrants": city["pop"] += 1; _show_event("Migrants settle in %s!  +1 pop" % city["name"])
		"disease":
			if city["pop"] > 1:
				city["pop"] -= 1
				_show_event("Disease in %s!  -1 pop" % city["name"])
		"fire":
			var blds: Array = city["blds"]
			if not blds.is_empty():
				var lost: String = blds.pop_at(randi() % blds.size())
				_show_event("Fire in %s!  The %s burned down" % [city["name"], _item_name(lost)])


func _buy_tech(key: String) -> void:
	var nat := me()
	if nat["tech"][key]:
		_show_message("Already researched"); return
	var cost: int = TECHS[key]["cost"]
	if nat["research"] < cost:
		_show_message("Need %d research for %s" % [cost, key]); return
	nat["research"] -= cost
	nat["tech"][key] = true
	_show_message("Researched: %s" % key)


func score(n: int) -> int:
	var pop := 0
	var count := 0
	var ids := {}
	for city in cities:
		if city["owner"] == n:
			pop += city["pop"]
			count += 1
			ids[city["id"]] = true
	var land := 0
	for c in territory.keys():
		if ids.has(territory[c]):
			land += 1
	var techs := 0
	for k in TECHS.keys():
		if nations[n]["tech"][k]: techs += 1
	return pop * 4 + count * 10 + land + techs * 10 + int(nations[n]["gold"]) / 20


func ranking() -> Array:
	var order := range(nations.size())
	order.sort_custom(func(a, b): return score(a) > score(b))
	return order


# ---------- Selection ----------
func _is_same(a: Dictionary, b: Dictionary) -> bool:
	return not a.is_empty() and not b.is_empty() and a["id"] == b["id"]


func _select(obj: Dictionary) -> void:
	if obj.has("type"):
		selected_unit = obj
		selected_city = {}
		obj["sleep"] = false
	else:
		selected_city = obj
		selected_unit = {}


func _deselect() -> void:
	selected_unit = {}
	selected_city = {}


func _select_next_unit() -> void:
	var n := units.size()
	var start := 0
	for i in n:
		if _is_same(units[i], selected_unit):
			start = i + 1
	for k in n:
		var u: Dictionary = units[(start + k) % n]
		if _needs_orders(u):
			_select(u)
			_show_if_offscreen(u["cell"])
			return
	selected_unit = {}
	for city in cities:
		if city["owner"] == 0 and city["build"] == "":
			_select(city)
			_show_if_offscreen(city["cell"])
			_show_message("%s needs something to build (1-8)" % city["name"])
			return


func _update_preview() -> void:
	var key := [selected_unit.get("id", -1), selected_unit.get("cell", Vector2i.ZERO), hovered]
	if key == preview_key:
		return
	preview_key = key
	preview_path = []
	if not selected_unit.is_empty() and hovered != selected_unit["cell"]:
		preview_path = _find_path(selected_unit["cell"], hovered)


# ---------- Camera ----------
func _center_on(c: Vector2i) -> void:
	origin = get_viewport_rect().size * 0.5 - hex_to_world(c) * zoom


func _show_if_offscreen(c: Vector2i) -> void:
	var p := hex_to_screen(c)
	var vp := get_viewport_rect().size
	if p.x < 80 or p.y < 120 or p.x > vp.x - 80 or p.y > vp.y - 180:
		_center_on(c)


func _set_zoom(nz: float) -> void:
	nz = clampf(nz, 0.4, 2.0)
	var focus := get_global_mouse_position()
	origin = focus - (focus - origin) / zoom * nz
	zoom = nz


func _process(delta: float) -> void:
	var pan := Vector2.ZERO
	if Input.is_key_pressed(KEY_LEFT):  pan.x += 1
	if Input.is_key_pressed(KEY_RIGHT): pan.x -= 1
	if Input.is_key_pressed(KEY_UP):    pan.y += 1
	if Input.is_key_pressed(KEY_DOWN):  pan.y -= 1
	if pan != Vector2.ZERO:
		origin += pan * PAN_SPEED * delta

	hovered = screen_to_hex(get_global_mouse_position())
	for u in units:   # slide unit tokens smoothly toward their hex
		u["dp"] = (u["dp"] as Vector2).lerp(hex_to_world(u["cell"]), minf(1.0, delta * 10.0))
	_update_preview()

	if message_timer > 0.0:
		message_timer -= delta
		if message_timer <= 0.0: message = ""
	if event_timer > 0.0:
		event_timer -= delta
		if event_timer <= 0.0: event_text = ""
	queue_redraw()


# ---------- Input ----------
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		_on_key(event.keycode)
	elif event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_MIDDLE) != 0:
		origin += event.relative
	elif event is InputEventMouseButton and event.pressed:
		match event.button_index:
			MOUSE_BUTTON_WHEEL_UP: _set_zoom(zoom * 1.1)
			MOUSE_BUTTON_WHEEL_DOWN: _set_zoom(zoom / 1.1)
			MOUSE_BUTTON_LEFT: _left_click(hovered)
			MOUSE_BUTTON_RIGHT: _right_click(hovered)


func _on_key(k: int) -> void:
	match k:
		KEY_F5: _save_game(); return
		KEY_F9: _load_game(); return
		KEY_F2: _restart(); return
		KEY_D: show_diplo = not show_diplo; return
		KEY_ESCAPE: show_diplo = false; _deselect(); return
	if game_over:
		return
	match k:
		KEY_ENTER, KEY_KP_ENTER: _end_turn(); return
		KEY_TAB, KEY_N: _select_next_unit(); return
		KEY_Q: _buy_tech("irrigation"); return
		KEY_W: _buy_tech("iron_tools"); return
		KEY_E: _buy_tech("vaccines"); return
	if not selected_unit.is_empty():
		_unit_key(k)
	elif not selected_city.is_empty():
		_city_key(k)


func _unit_key(k: int) -> void:
	var u := selected_unit
	match k:
		KEY_B: _found_city(u)
		KEY_F: if _start_job(u, "farm"): _select_next_unit()
		KEY_M: if _start_job(u, "mine"): _select_next_unit()
		KEY_R: if _start_job(u, "road"): _select_next_unit()
		KEY_C: if _start_job(u, "chop"): _select_next_unit()
		KEY_T:
			var v := _village_near(u["cell"])
			if v.is_empty():
				_show_message("Move next to a native village first")
			else:
				_gift(0, v["tribe"])
		KEY_SPACE:
			u["mp"] = 0.0
			u["path"] = []
			_select_next_unit()
		KEY_H:
			u["sleep"] = true
			_select_next_unit()


func _city_key(k: int) -> void:
	var city := selected_city
	if k >= KEY_1 and k <= KEY_8:
		var item: String = BUILD_ORDER[k - KEY_1]
		if item in city["blds"]:
			_show_message("%s already has a %s" % [city["name"], _item_name(item)]); return
		city["build"] = item
		_show_message("%s is now building: %s" % [city["name"], _item_name(item)])
	elif k == KEY_G:
		_buy(city)


func _left_click(cell: Vector2i) -> void:
	if not seen.has(cell):
		_deselect(); return
	var choices := _units_at(cell, 0)
	if city_at.has(cell) and city_at[cell]["owner"] == 0:
		choices.append(city_at[cell])
	if choices.is_empty():
		_deselect(); return
	var cur := -1     # clicking the same hex again cycles through what's on it
	for i in choices.size():
		if _is_same(choices[i], selected_unit) or _is_same(choices[i], selected_city):
			cur = i
	_select(choices[(cur + 1) % choices.size()])


func _right_click(cell: Vector2i) -> void:
	if selected_unit.is_empty() or game_over:
		return
	var u := selected_unit
	if cell == u["cell"]:
		return
	var dest := cell
	if village_at.has(cell):
		# Villages can't be entered: walk to the closest hex next to it
		var tname: String = TRIBES[village_at[cell]["tribe"]]["name"]
		if hex_dist(u["cell"], cell) == 1:
			_show_message("%s village — press T to give %d gold as a gift" % [tname, GIFT_GOLD]); return
		dest = NO_CELL
		var best_len := 9999
		for d in DIRS:
			var p := _find_path(u["cell"], cell + d)
			if not p.is_empty() and p.size() < best_len:
				best_len = p.size()
				dest = cell + d
		if dest == NO_CELL:
			_show_message("No land route there"); return
	var path := _find_path(u["cell"], dest)
	if path.is_empty():
		_show_message("No land route there"); return
	u["path"] = path
	u["job"] = ""
	u["sleep"] = false
	_advance_unit(u)
	_recompute_vision()
	if u["mp"] <= 0.0:
		_select_next_unit()


# ---------- New game / save / load ----------
func _restart() -> void:
	map_seed = randi()
	chopped.clear(); roads.clear(); improvements.clear(); seen.clear(); in_sight.clear(); territory.clear()
	cities.clear(); city_at.clear(); city_index.clear(); units.clear(); nations.clear()
	tribes.clear(); villages.clear(); village_at.clear(); tribe_land.clear()
	turn = 1; next_id = 1; game_over = false; show_diplo = false
	var defs := [PLAYER_NATION]
	for i in NATIONS.size():
		if i != PLAYER_NATION and defs.size() < AI_COUNT + 1:
			defs.append(i)
	for d in defs:
		nations.append(_new_nation(d))
	nations[0]["met"] = true
	_generate_terrain()
	var starts := []
	for n in nations.size():
		starts.append(_pick_start(starts))
	_place_tribes(starts)
	_build_astar()
	for n in nations.size():
		_spawn_unit("settler", starts[n], n)
		_spawn_unit("guard", starts[n], n)
		_spawn_unit("scout", starts[n], n)
		_spawn_unit("worker", starts[n], n)
	for n in range(1, nations.size()):
		_ai_turn(n)          # AI colonies found their first city right away
	_center_on(starts[0])
	_deselect()
	_recompute_vision()
	_select_next_unit()
	_show_message("%s's ships reach the New World.  Press B with the Colonist to found a city" % ndef(0)["name"])


func _cells(arr: Array) -> Array:
	var out := []
	for c in arr:
		out.append([c.x, c.y])
	return out


func _v(a) -> Vector2i:
	return Vector2i(int(a[0]), int(a[1]))


func _save_game() -> void:
	var data := {
		"seed": map_seed, "turn": turn, "next_id": next_id, "nations": nations, "tribes": tribes,
		"chopped": _cells(chopped.keys()), "roads": _cells(roads.keys()), "seen": _cells(seen.keys()),
		"improvements": [], "territory": [], "tribe_land": [], "villages": [], "cities": [], "units": [],
	}
	for c in improvements.keys():
		data["improvements"].append([c.x, c.y, improvements[c]])
	for c in territory.keys():
		data["territory"].append([c.x, c.y, territory[c]])
	for c in tribe_land.keys():
		data["tribe_land"].append([c.x, c.y, tribe_land[c]])
	for v in villages:
		var d: Dictionary = v.duplicate()
		d["cell"] = [v["cell"].x, v["cell"].y]
		data["villages"].append(d)
	for city in cities:
		var d: Dictionary = city.duplicate()
		d["cell"] = [city["cell"].x, city["cell"].y]
		data["cities"].append(d)
	for u in units:
		var d: Dictionary = u.duplicate()
		d.erase("dp")
		d["cell"] = [u["cell"].x, u["cell"].y]
		d["goal"] = [u["goal"].x, u["goal"].y]
		d["path"] = _cells(u["path"])
		data["units"].append(d)
	var f := FileAccess.open("user://save_v10.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(data))
	f.close()
	_show_message("Saved (F9 to load)")


func _load_game() -> void:
	if not FileAccess.file_exists("user://save_v10.json"):
		_show_message("No save file"); return
	var f := FileAccess.open("user://save_v10.json", FileAccess.READ)
	var data = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(data) != TYPE_DICTIONARY:
		_show_message("Save file corrupted"); return
	map_seed = int(data["seed"]); turn = int(data["turn"]); next_id = int(data["next_id"])
	nations.clear()
	for d in data["nations"]:
		var nat: Dictionary = d
		for key in ["def", "gold", "research", "founded"]:
			nat[key] = int(d[key])
		nations.append(nat)
	tribes.clear()
	for d in data["tribes"]:
		var att := []
		for a in d["att"]:
			att.append(int(a))
		tribes.append({ "att": att, "met": bool(d["met"]) })
	chopped.clear(); roads.clear(); seen.clear(); improvements.clear(); territory.clear(); tribe_land.clear()
	for a in data["chopped"]: chopped[_v(a)] = true
	for a in data["roads"]: roads[_v(a)] = true
	for a in data["seen"]: seen[_v(a)] = true
	for a in data["improvements"]: improvements[_v(a)] = a[2]
	for a in data["territory"]: territory[_v(a)] = int(a[2])
	for a in data["tribe_land"]: tribe_land[_v(a)] = int(a[2])
	_generate_terrain()
	villages.clear(); village_at.clear()
	for d in data["villages"]:
		var v: Dictionary = d
		v["cell"] = _v(d["cell"]); v["id"] = int(d["id"]); v["tribe"] = int(d["tribe"])
		villages.append(v)
		village_at[v["cell"]] = v
	cities.clear(); city_at.clear(); city_index.clear()
	for d in data["cities"]:
		var city: Dictionary = d
		city["cell"] = _v(d["cell"])
		for key in ["id", "owner", "pop", "food", "prod", "culture", "radius"]:
			city[key] = int(d[key])
		if city["build"] == "soldier": city["build"] = "guard"     # Lesson 10 saves
		cities.append(city)
		city_at[city["cell"]] = city
		city_index[city["id"]] = city
	units.clear()
	for d in data["units"]:
		var u: Dictionary = d
		u["cell"] = _v(d["cell"]); u["goal"] = _v(d["goal"])
		u["id"] = int(d["id"]); u["owner"] = int(d["owner"])
		u["job_left"] = int(d["job_left"]); u["mp"] = float(d["mp"])
		if u["type"] == "soldier": u["type"] = "guard"             # Lesson 10 saves
		var path := []
		for a in d["path"]:
			path.append(_v(a))
		u["path"] = path
		u["dp"] = hex_to_world(u["cell"])
		units.append(u)
	_build_astar()
	game_over = false
	_deselect()
	_recompute_vision()
	var mine := cities.filter(func(c): return c["owner"] == 0)
	if not mine.is_empty(): _center_on(mine[0]["cell"])
	_select_next_unit()
	_show_message("Loaded — year %d" % year())


func _show_message(text: String) -> void:
	message = text; message_timer = 3.0


func _show_event(text: String) -> void:
	event_text = text; event_timer = 4.0


# ---------- Drawing ----------
func _hash_cell(c: Vector2i) -> int:
	return abs((c.x * 73856093) ^ (c.y * 19349663))


func _hex_points(p: Vector2, r: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for k in CORNERS:
		pts.append(p + k * r)
	return pts


func _on_screen(p: Vector2, vp: Vector2, m: float) -> bool:
	return p.x > -m and p.y > -m and p.x < vp.x + m and p.y < vp.y + m


func _draw() -> void:
	var vp := get_viewport_rect().size
	var r := HEX * zoom
	var font := ThemeDB.fallback_font
	draw_rect(Rect2(Vector2.ZERO, vp), Color(0.04, 0.04, 0.06))   # background beyond the map edge

	# 1) Terrain, improvements, roads, grid
	for c in terrain.keys():
		var p := hex_to_screen(c)
		if not _on_screen(p, vp, r * 2):
			continue
		var pts := _hex_points(p, r)
		if not seen.has(c):
			draw_colored_polygon(pts, Color(0.06, 0.06, 0.08))
			continue
		var t: String = terrain[c]
		var col: Color = TERRAIN[t]["col"]
		var j := 0.94 + float(_hash_cell(c) % 12) / 100.0     # small per-hex shade variation
		draw_colored_polygon(pts, Color(col.r * j, col.g * j, col.b * j))
		_draw_decor(t, p, r)
		if improvements.has(c):
			_draw_improvement(improvements[c], p, r)
		if roads.has(c) or city_at.has(c):
			_draw_roads(c, p, r)
		pts.append(pts[0])
		draw_polyline(pts, Color(0, 0, 0, 0.16), 1.0)

	# 2) Borders: colonies (thick, nation colour) and tribal land (thin, tribe colour)
	for c in territory.keys():
		var p := hex_to_screen(c)
		if not seen.has(c) or not _on_screen(p, vp, r * 2):
			continue
		var n := _cell_nation(c)
		for i in 6:
			if _cell_nation(c + DIRS[i]) != n:
				draw_line(p + CORNERS[i] * r * 0.93, p + CORNERS[(i + 1) % 6] * r * 0.93, ncol(n), 3.0 * zoom)
	for c in tribe_land.keys():
		var p := hex_to_screen(c)
		if not seen.has(c) or not _on_screen(p, vp, r * 2):
			continue
		var t: int = tribe_land[c]
		for i in 6:
			if tribe_land.get(c + DIRS[i], -1) != t:
				draw_line(p + CORNERS[i] * r * 0.9, p + CORNERS[(i + 1) % 6] * r * 0.9, TRIBES[t]["col"], 2.0 * zoom)

	# 3) Selected city: its worked tiles
	if not selected_city.is_empty():
		for h in city_yield(selected_city)["worked"]:
			draw_arc(hex_to_screen(h), r * 0.45, 0, TAU, 20, Color(1, 1, 1, 0.8), 2.0 * zoom)
		var cp := _hex_points(hex_to_screen(selected_city["cell"]), r)
		cp.append(cp[0])
		draw_polyline(cp, Color(1, 1, 0.5), 2.5 * zoom)

	# 4) Hover highlight + move preview
	if terrain.has(hovered):
		draw_colored_polygon(_hex_points(hex_to_screen(hovered), r), Color(1, 1, 1, 0.16))
	if not selected_unit.is_empty() and not preview_path.is_empty():
		var prev := hex_to_screen(selected_unit["cell"])
		for c in preview_path:
			var nx := hex_to_screen(c)
			draw_line(prev, nx, Color(1, 1, 1, 0.85), 2.5 * zoom)
			prev = nx
		draw_circle(prev, 5.0 * zoom, Color(1, 1, 1))
		var turns := _path_turns(selected_unit, preview_path)
		draw_string(font, prev + Vector2(8, -8), "%d turn%s" % [turns, "" if turns == 1 else "s"],
			HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(1, 1, 0.6))

	# 5) Villages, cities, units
	for v in villages:
		if seen.has(v["cell"]) and _on_screen(hex_to_screen(v["cell"]), vp, r * 2):
			_draw_village(v, font, r)
	for city in cities:
		if seen.has(city["cell"]) and _on_screen(hex_to_screen(city["cell"]), vp, r * 4):
			_draw_city(city, font, r)
	_draw_units(font, vp, r)
	_draw_ui(font, vp)
	if show_diplo:
		_draw_diplomacy(font, vp)


func _draw_decor(t: String, p: Vector2, r: float) -> void:
	match t:
		"forest":
			for off in [Vector2(-0.35, 0.2), Vector2(0.32, 0.22), Vector2(0.0, -0.2)]:
				var b: Vector2 = p + off * r
				draw_line(b + Vector2(0, 0.1 * r), b + Vector2(0, 0.22 * r), Color(0.35, 0.24, 0.14), 2.0 * zoom)
				draw_colored_polygon(PackedVector2Array([b + Vector2(0, -0.3 * r),
					b + Vector2(0.19 * r, 0.12 * r), b + Vector2(-0.19 * r, 0.12 * r)]), Color(0.12, 0.32, 0.14))
		"hills":
			var hc := Color(0.40, 0.36, 0.22)
			draw_arc(p + Vector2(-0.25 * r, 0.25 * r), 0.3 * r, PI, TAU, 10, hc, 2.5 * zoom)
			draw_arc(p + Vector2(0.22 * r, -0.02 * r), 0.3 * r, PI, TAU, 10, hc, 2.5 * zoom)
		"mountain":
			draw_colored_polygon(PackedVector2Array([p + Vector2(0, -0.62 * r),
				p + Vector2(0.58 * r, 0.42 * r), p + Vector2(-0.58 * r, 0.42 * r)]), Color(0.34, 0.32, 0.31))
			draw_colored_polygon(PackedVector2Array([p + Vector2(0, -0.62 * r),
				p + Vector2(0.18 * r, -0.29 * r), p + Vector2(-0.18 * r, -0.29 * r)]), Color(0.95, 0.95, 0.97))
		"ocean", "coast":
			var w := Color(1, 1, 1, 0.12)
			draw_line(p + Vector2(-0.35 * r, -0.12 * r), p + Vector2(-0.05 * r, -0.12 * r), w, 1.5 * zoom)
			draw_line(p + Vector2(0.02 * r, 0.22 * r), p + Vector2(0.32 * r, 0.22 * r), w, 1.5 * zoom)


func _draw_improvement(kind: String, p: Vector2, r: float) -> void:
	if kind == "farm":
		for i in 3:
			var yy := (-0.3 + i * 0.25) * r
			draw_line(p + Vector2(-0.45 * r, yy), p + Vector2(0.45 * r, yy), Color(0.92, 0.82, 0.32), 2.5 * zoom)
	elif kind == "mine":
		draw_colored_polygon(PackedVector2Array([p + Vector2(-0.2 * r, 0.35 * r),
			p + Vector2(0, 0.05 * r), p + Vector2(0.2 * r, 0.35 * r)]), Color(0.15, 0.12, 0.1))


func _draw_roads(c: Vector2i, p: Vector2, r: float) -> void:
	var col := Color(0.50, 0.37, 0.22)
	var linked := false
	for d in DIRS:
		var n: Vector2i = c + d
		if roads.has(n) or city_at.has(n):
			draw_line(p, p.lerp(hex_to_screen(n), 0.5), col, 3.0 * zoom)
			linked = true
	if not linked:
		draw_circle(p, 3.0 * zoom, col)


func _draw_village(v: Dictionary, font: Font, r: float) -> void:
	var p := hex_to_screen(v["cell"])
	var tcol: Color = TRIBES[v["tribe"]]["col"]
	draw_circle(p, 0.6 * r, Color(tcol, 0.3))
	for off in [Vector2(-0.27, 0.15), Vector2(0.27, 0.15), Vector2(0.0, -0.17)]:
		var b: Vector2 = p + off * r
		var s := 0.17 * r
		draw_line(b + Vector2(0, -s * 1.3), b + Vector2(0, -s * 1.8), Color(0.3, 0.2, 0.1), 1.5 * zoom)
		draw_colored_polygon(PackedVector2Array([b + Vector2(0, -s * 1.3), b + Vector2(s, s * 0.6),
			b + Vector2(-s, s * 0.6)]), Color(0.88, 0.76, 0.55))
		draw_line(b + Vector2(0, -s * 1.3), b + Vector2(0, s * 0.6), Color(0.45, 0.3, 0.18), 1.0 * zoom)
	if not v["visited"]:   # "?" = not visited yet (visiting gives a gift)
		draw_string(font, p + Vector2(0.3 * r, -0.35 * r), "?", HORIZONTAL_ALIGNMENT_LEFT, -1,
			int(clampf(18.0 * zoom, 10, 30)), Color(1, 0.95, 0.4))


func _draw_city(city: Dictionary, font: Font, r: float) -> void:
	var p := hex_to_screen(city["cell"])
	var n: int = city["owner"]
	draw_circle(p, 0.62 * r, Color(0.18, 0.18, 0.2, 0.85))
	for off in [Vector2(-0.28, 0.12), Vector2(0.24, 0.16), Vector2(-0.02, -0.18)]:
		var b: Vector2 = p + off * r
		var s := 0.14 * r
		draw_rect(Rect2(b - Vector2(s, s * 0.4), Vector2(s * 2, s * 1.4)), Color(0.92, 0.88, 0.78))
		draw_colored_polygon(PackedVector2Array([b + Vector2(-s * 1.25, -s * 0.4),
			b + Vector2(0, -s * 1.5), b + Vector2(s * 1.25, -s * 0.4)]), Color(0.72, 0.26, 0.2))
	# Name plate in the owner's colour: "Name  pop"
	var fs := int(clampf(14.0 * zoom, 10, 22))
	var label := "%s  %d" % [city["name"], city["pop"]]
	var tw := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var top := p + Vector2(-tw * 0.5 - 6, -r * 0.85 - fs * 0.5 - 3)
	draw_rect(Rect2(top, Vector2(tw + 12, fs + 6)), Color(ncol(n).darkened(0.35), 0.9))
	draw_string(font, top + Vector2(6, fs + 1), label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 1, 1))
	if n != 0:
		return
	var item: String = city["build"]
	var sub := "choose build!"
	var sub_col := Color(1, 0.5, 0.4)
	if item != "":
		var per_turn: int = maxi(1, city_yield(city)["p"])
		var left := maxi(0, build_cost(item) - int(city["prod"]))
		sub = "%s %dt" % [_item_name(item), ceili(left / float(per_turn))]
		sub_col = Color(0.9, 0.9, 0.9)
	var fs2 := int(clampf(12.0 * zoom, 9, 18))
	draw_string(font, p + Vector2(-r * 3, r * 0.95), sub, HORIZONTAL_ALIGNMENT_CENTER, r * 6, fs2, sub_col)


# Build (once) a copy of a unit sprite painted in a nation's colour.
# unit_X.png has the team areas in grey; unit_X_team.png says where they are (white = 100%).
# new pixel = lerp(pixel, pixel * nation colour, mask)  -> keeps the shading of the grey.
func _unit_texture(type: String, n: int) -> Texture2D:
	var key := "%s:%d" % [type, n]
	if unit_tex.has(key):
		return unit_tex[key]
	var tex: Texture2D = null
	if ResourceLoader.exists(UNIT_ART % type) and ResourceLoader.exists(UNIT_TEAM % type):
		var base: Image = (load(UNIT_ART % type) as Texture2D).get_image()
		var mask: Image = (load(UNIT_TEAM % type) as Texture2D).get_image()
		for img in [base, mask]:
			if img.is_compressed(): img.decompress()
			img.convert(Image.FORMAT_RGBA8)
		var col := ncol(n)
		var data := base.get_data()
		var m := mask.get_data()
		for i in range(0, data.size(), 4):
			var a: float = m[i + 3] / 255.0
			if a > 0.0:
				data[i] = int(data[i] * (1.0 - a + a * col.r))
				data[i + 1] = int(data[i + 1] * (1.0 - a + a * col.g))
				data[i + 2] = int(data[i + 2] * (1.0 - a + a * col.b))
		var img := Image.create_from_data(base.get_width(), base.get_height(), false, Image.FORMAT_RGBA8, data)
		img.generate_mipmaps()
		tex = ImageTexture.create_from_image(img)
	unit_tex[key] = tex      # null = no art yet -> token fallback
	return tex


func _draw_ellipse(center: Vector2, rx: float, ry: float, col: Color, width: float = -1.0) -> void:
	draw_set_transform(center, 0.0, Vector2(1.0, ry / rx))
	if width < 0.0:
		draw_circle(Vector2.ZERO, rx, col)
	else:
		draw_arc(Vector2.ZERO, rx, 0, TAU, 32, col, width * rx / ry)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_units(font: Font, vp: Vector2, r: float) -> void:
	# Group units by hex; draw one figure per hex (the selected one, else your own) + a count badge.
	# Clicking the hex again cycles through the stack.
	var groups := {}
	for u in units:
		var c: Vector2i = u["cell"]
		if u["owner"] != 0 and not in_sight.has(c):
			continue       # foreign units are only visible near your own units/cities
		if not groups.has(c):
			groups[c] = []
		groups[c].append(u)
	var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 150.0)
	for c in groups.keys():
		var group: Array = groups[c]
		var u: Dictionary = group[0]
		for o in group:
			if _is_same(o, selected_unit) or (o["owner"] == 0 and u["owner"] != 0):
				u = o
		for o in group:
			if _is_same(o, selected_unit):
				u = o
		var n: int = u["owner"]
		var sp := world_to_screen(u["dp"])
		if city_at.has(c):
			sp += Vector2(0.4 * r, 0.25 * r)
		if not _on_screen(sp, vp, r * 2):
			continue
		var idle: bool = n == 0 and (u["mp"] <= 0.0 or u["sleep"] or u["job"] != "")
		var feet := sp + Vector2(0, 0.5 * r)
		var tex := _unit_texture(u["type"], n)
		var top_y := sp.y - 0.45 * r
		if tex != null:
			# Nation-coloured base under the figure, then the figure (feet at 91% of the image height)
			_draw_ellipse(feet, 0.5 * r, 0.19 * r, Color(0, 0, 0, 0.35))
			_draw_ellipse(feet, 0.44 * r, 0.16 * r, ncol(n).darkened(0.2))
			_draw_ellipse(feet, 0.44 * r, 0.16 * r, Color(0.1, 0.08, 0.07), 1.5 * zoom)
			if _is_same(u, selected_unit):
				_draw_ellipse(feet, 0.56 * r + pulse * 2.0 * zoom, 0.22 * r + pulse * zoom, Color(1, 1, 0.4), 2.0 * zoom)
			var size := 1.9 * r
			var rect := Rect2(feet.x - size * 0.5, feet.y - size * 0.914, size, size)
			draw_texture_rect(tex, rect, false, Color(0.62, 0.62, 0.66) if idle else Color(1, 1, 1))
			top_y = rect.position.y + size * 0.08
		else:
			# No sprite yet: round token with a letter
			draw_circle(sp, 0.34 * r, Color(0.08, 0.08, 0.1))
			draw_circle(sp, 0.28 * r, ncol(n).darkened(0.45) if idle else ncol(n))
			var fs := int(clampf(15.0 * zoom, 9, 26))
			draw_string(font, sp + Vector2(-0.3 * r, fs * 0.36), UNITS[u["type"]]["icon"],
				HORIZONTAL_ALIGNMENT_CENTER, 0.6 * r, fs, Color(1, 1, 1) if n == 0 else Color(0.1, 0.1, 0.1))
			if _is_same(u, selected_unit):
				draw_arc(sp, 0.4 * r + pulse * 2.5 * zoom, 0, TAU, 24, Color(1, 1, 0.4), 2.0 * zoom)
		if group.size() > 1:
			var bp := feet + Vector2(0.45 * r, -0.2 * r)
			draw_circle(bp, 0.2 * r, Color(0.1, 0.09, 0.08))
			draw_arc(bp, 0.2 * r, 0, TAU, 16, ncol(n), 1.5 * zoom)
			var bfs := int(clampf(12.0 * zoom, 8, 20))
			draw_string(font, bp + Vector2(-0.2 * r, bfs * 0.36), str(group.size()), HORIZONTAL_ALIGNMENT_CENTER, 0.4 * r, bfs, Color(1, 1, 1))
		if n != 0:
			continue
		var fs2 := int(clampf(12.0 * zoom, 9, 18))
		if u["job"] != "":
			draw_string(font, Vector2(sp.x - r, top_y), "%s %d" % [u["job"], u["job_left"]],
				HORIZONTAL_ALIGNMENT_CENTER, r * 2, fs2, Color(1, 0.9, 0.5))
		elif u["sleep"]:
			draw_string(font, Vector2(sp.x + 0.3 * r, top_y), "z z", HORIZONTAL_ALIGNMENT_LEFT, -1, fs2, Color(0.8, 0.9, 1))


func _draw_ui(font: Font, vp: Vector2) -> void:
	var nat := me()
	var inc_g := _trade_income(0)
	var inc_r := 0
	var pop := 0
	var count := 0
	for city in cities:
		if city["owner"] != 0:
			continue
		var y := city_yield(city)
		inc_g += y["g"]
		inc_r += y["sci"]
		pop += city["pop"]
		count += 1

	# Top bar
	draw_rect(Rect2(0, 0, vp.x, 60), Color(0, 0, 0, 0.6))
	draw_rect(Rect2(0, 0, 8, 60), ncol(0))
	draw_string(font, Vector2(16, 26), "%s   Year %d  (turn %d)    Gold %d (+%d)    Research %d (+%d)    Pop %d    Cities %d    Score %d  (#%d of %d)"
		% [ndef(0)["name"], year(), turn, nat["gold"], inc_g, nat["research"], inc_r, pop, count, score(0),
		ranking().find(0) + 1, nations.size()], HORIZONTAL_ALIGNMENT_LEFT, -1, 19, Color(1, 1, 1))
	var tx := 16.0
	for key in TECHS.keys():
		var t: Dictionary = TECHS[key]
		var owned: bool = nat["tech"][key]
		var label := "[%s] %s (%d): %s%s" % [t["key"], key, t["cost"], t["desc"], "  OK" if owned else ""]
		var col := Color(0.5, 1, 0.6) if owned else (Color(0.95, 0.95, 0.6) if nat["research"] >= t["cost"] else Color(0.6, 0.6, 0.6))
		draw_string(font, Vector2(tx, 50), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, col)
		tx += font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x + 30
	draw_string(font, Vector2(vp.x - 216, 50), "[D] Diplomacy", HORIZONTAL_ALIGNMENT_RIGHT, 200, 14, Color(0.7, 0.85, 1))

	if event_text != "":
		draw_string(font, Vector2(16, 88), "* " + event_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(1, 0.8, 0.3))
	if message != "":
		draw_string(font, Vector2(16, 112), message, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.9, 0.95, 1))

	# Bottom-left: selection panel
	var lines := []   # [text, color]
	if not selected_unit.is_empty():
		var u := selected_unit
		var spec: Dictionary = UNITS[u["type"]]
		lines.append(["%s    Moves %s / %d" % [spec["name"], str(snappedf(u["mp"], 0.5)), spec["mp"]], Color(1, 1, 0.6)])
		match u["type"]:
			"settler": lines.append(["[B] Found a city here", Color(1, 1, 1)])
			"worker":
				lines.append(["[F] Farm  [M] Mine  [R] Road  [C] Chop forest", Color(1, 1, 1)])
				if u["job"] != "":
					lines.append(["Working: %s (%d turns left)" % [u["job"], u["job_left"]], Color(1, 0.9, 0.5)])
			"scout": lines.append(["Sees 3 hexes. Chiefs give scouts bigger gifts.", Color(0.8, 0.8, 0.8)])
			"guard": lines.append(["Protects cities. (Combat comes in Lesson 11)", Color(0.8, 0.8, 0.8)])
		var v := _village_near(u["cell"])
		if not v.is_empty():
			lines.append(["[T] Give %d gold to the %s  (+%d attitude)" % [GIFT_GOLD, TRIBES[v["tribe"]]["name"], GIFT_ATT], Color(0.6, 1, 0.9)])
		lines.append(["Right-click: move    [Space] Skip turn    [H] Sleep", Color(0.8, 0.8, 0.8)])
	elif not selected_city.is_empty():
		var city := selected_city
		var y := city_yield(city)
		lines.append(["%s    size %d    borders r%d" % [city["name"], city["pop"], city["radius"]], Color(1, 1, 0.6)])
		lines.append(["Food %d/%d (%+d)    Prod %d (+%d)    Gold +%d    Research +%d" % [city["food"], growth_need(city),
			y["f"] - y["eat"], city["prod"], y["p"], y["g"], y["sci"]], Color(1, 1, 1)])
		var item: String = city["build"]
		var buy := ""
		if item != "":
			buy = "    [G] Buy for %d gold" % maxi(0, (build_cost(item) - int(city["prod"])) * 2)
		lines.append(["Building: %s%s" % [_item_name(item), buy], Color(0.6, 1, 0.7) if item != "" else Color(1, 0.5, 0.4)])
		var row := ""
		for i in BUILD_ORDER.size():
			var key: String = BUILD_ORDER[i]
			var done: bool = key in city["blds"]
			row += "[%d] %s %s   " % [i + 1, _item_name(key), "(built)" if done else str(build_cost(key))]
			if i == 3 or i == BUILD_ORDER.size() - 1:
				lines.append([row, Color(0.85, 0.85, 0.85)])
				row = ""
	if not lines.is_empty():
		var h := 14.0 + lines.size() * 22.0
		draw_rect(Rect2(10, vp.y - h - 40, 560, h), Color(0, 0, 0, 0.62))
		for i in lines.size():
			draw_string(font, Vector2(20, vp.y - h - 40 + 26 + i * 22), lines[i][0], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, lines[i][1])

	# Bottom-right: hovered hex info
	if terrain.has(hovered):
		draw_string(font, Vector2(vp.x - 620, vp.y - 50), _hover_info(), HORIZONTAL_ALIGNMENT_RIGHT, 600, 16, Color(0.9, 0.95, 0.85))

	var waiting := units.filter(func(u): return _needs_orders(u)).size()
	var end_col := Color(1, 1, 0.5) if waiting == 0 else Color(0.75, 0.75, 0.75)
	draw_string(font, Vector2(vp.x - 470, vp.y - 72), "[Enter] End turn   (%d unit%s waiting)" % [waiting, "" if waiting == 1 else "s"],
		HORIZONTAL_ALIGNMENT_RIGHT, 450, 17, end_col)
	draw_string(font, Vector2(16, vp.y - 12), "Left: select   Right: move   Tab: next unit   D: diplomacy   Arrows / middle-drag: pan   Wheel: zoom   F5 save   F9 load   F2 new map",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.75, 0.75, 0.75))

	if game_over:
		var order := ranking()
		var txt := ""
		for i in order.size():
			txt += "%d. %s %d    " % [i + 1, ndef(order[i])["name"], score(order[i])]
		draw_rect(Rect2(0, vp.y * 0.4, vp.x, 110), Color(0, 0, 0, 0.7))
		draw_string(font, Vector2(0, vp.y * 0.4 + 42), "Year %d  —  you finished #%d of %d" % [year(), order.find(0) + 1, order.size()],
			HORIZONTAL_ALIGNMENT_CENTER, vp.x, 32, Color(0.5, 1, 0.6))
		draw_string(font, Vector2(0, vp.y * 0.4 + 72), txt, HORIZONTAL_ALIGNMENT_CENTER, vp.x, 18, Color(1, 1, 1))
		draw_string(font, Vector2(0, vp.y * 0.4 + 98), "Press F2 for a new map", HORIZONTAL_ALIGNMENT_CENTER, vp.x, 16, Color(0.8, 0.8, 0.8))


func _hover_info() -> String:
	if not seen.has(hovered):
		return "Unexplored"
	if village_at.has(hovered):
		var v: Dictionary = village_at[hovered]
		var t: int = v["tribe"]
		var a: int = tribes[t]["att"][0]
		return "%s village   attitude %d (%s)%s" % [TRIBES[t]["name"], a, mood(a), "" if v["visited"] else "   not visited"]
	var ty := tile_yield(hovered)
	var info := "%s   F%d P%d G%d" % [TERRAIN[terrain[hovered]]["name"], ty.x, ty.y, ty.z]
	if improvements.has(hovered): info += "   +" + improvements[hovered]
	if roads.has(hovered): info += "   road"
	if territory.has(hovered):
		var city := _city_by_id(territory[hovered])
		info += "   (%s, %s)" % [city["name"], ndef(city["owner"])["name"]]
	elif tribe_land.has(hovered):
		info += "   (%s land)" % TRIBES[tribe_land[hovered]]["name"]
	if in_sight.has(hovered):
		for u in units:
			if u["cell"] == hovered and u["owner"] != 0:
				info += "   | %s %s" % [ndef(u["owner"])["name"], UNITS[u["type"]]["name"]]
	return info


func _draw_diplomacy(font: Font, vp: Vector2) -> void:
	var lines := []   # [text, color]
	lines.append(["DIPLOMACY   (D to close)", Color(1, 1, 0.6)])
	lines.append(["Colonial powers", Color(0.7, 0.85, 1)])
	for n in nations.size():
		if n != 0 and not nations[n]["met"]:
			lines.append(["   ???  (not met yet)", Color(0.55, 0.55, 0.55)])
			continue
		var count := 0
		var pop := 0
		for city in cities:
			if city["owner"] == n:
				count += 1
				pop += city["pop"]
		lines.append(["   %s%s   cities %d   pop %d   score %d   — %s" % [ndef(n)["name"], " (you)" if n == 0 else "   Peace",
			count, pop, score(n), ndef(n)["desc"]], ncol(n)])
	lines.append(["Native tribes", Color(0.7, 0.85, 1)])
	for t in tribes.size():
		if not _tribe_alive(t):
			continue
		if not tribes[t]["met"]:
			lines.append(["   ???  (not met yet)", Color(0.55, 0.55, 0.55)])
			continue
		var nv := villages.filter(func(v): return v["tribe"] == t).size()
		var a: int = tribes[t]["att"][0]
		lines.append(["   %s   villages %d   attitude %d (%s)   trade +%d gold/turn" % [TRIBES[t]["name"], nv, a, mood(a),
			_trade_income(0, t)], TRIBES[t]["col"]])
	lines.append(["", Color.WHITE])
	lines.append(["Visit a village (walk next to it) for a gift.  [T] next to a village: give %d gold, +%d attitude." % [GIFT_GOLD, GIFT_ATT], Color(0.8, 0.8, 0.8)])
	lines.append(["Friendly (%d+) and one of your cities within %d hexes: +1 gold per village each turn." % [TRADE_ATT, TRADE_RANGE], Color(0.8, 0.8, 0.8)])
	lines.append(["Settling within 4 hexes of a village: -%d.  At %d or below they raid your nearest city." % [LAND_GRAB, RAID_ATT], Color(0.8, 0.8, 0.8)])
	var w := 900.0
	var h := 24.0 + lines.size() * 24.0
	var top := Vector2((vp.x - w) * 0.5, (vp.y - h) * 0.5)
	draw_rect(Rect2(top, Vector2(w, h)), Color(0.05, 0.06, 0.09, 0.93))
	draw_rect(Rect2(top, Vector2(w, h)), Color(0.5, 0.6, 0.8), false, 2.0)
	for i in lines.size():
		draw_string(font, top + Vector2(20, 34 + i * 24), lines[i][0], HORIZONTAL_ALIGNMENT_LEFT, w - 40, 16, lines[i][1])
