extends RefCounted
# =============================================================
#  Colony Empire — Economy I: real people, staple crops, grain price,
#  standard of living (LS).  Design: 經濟系統設計_v2_人口經濟.md §1–6
#  and 商品系統設計.md §1.1.
#
#  city["pop"]   = number of PEOPLE (e.g. 12480), not an abstract size.
#  city["grain"] = stored food in tonnes of wheat-equivalent (granary buffer).
#  There is no "food bucket" any more: food supply sets the grain price and the
#  coverage, those set the standard of living, and LS drives births, deaths,
#  immigration and emigration.
#
#  All rates below are PER YEAR; one turn = 2 years, so grow() runs the year twice.
#  main.gd calls: Econ.city_econ(game, city) (pure, no side effects)
#                 Econ.grow(game, city, e)   (end of turn: people + granary)
# =============================================================

const LABOR_SHARE := 0.55       # adults who work (the rest are children and the old)
const CAL_NEED := 0.30          # t of wheat-equivalent eaten per person per year
const LOSS := 0.10              # seed, feed and spoilage
const BASE_PRICE := 30.0        # pesos per t of wheat-equivalent
const FOOD_SHARE := 0.55        # food is 55% of a poor household's budget -> subsistence line
const STOCK_DECAY := 0.15       # stored grain lost per year

# Staple crops (per farmer per year at fertility 1.0). "cal" = calories vs. wheat.
const CROPS := {
	"wheat":  { "name": "Wheat",  "t": 1.2, "cal": 1.0 },
	"corn":   { "name": "Corn",   "t": 1.5, "cal": 1.1 },
	"barley": { "name": "Barley", "t": 1.3, "cal": 0.9 },
	"fish":   { "name": "Fish",   "t": 1.2, "cal": 0.8 },
}
# Fertility and how many farmers (or fishers) a hex can hold before it is improved.
const FERT := { "grass": 1.0, "plains": 0.85, "forest": 0.25, "hills": 0.4, "coast": 1.0, "ocean": 0.6 }
const FARM_CAP := { "grass": 40, "plains": 40, "forest": 15, "hills": 25, "coast": 30, "ocean": 15 }
const FARM_CAP_IMPROVED := 130  # a Farm improvement: room for 130 farmers
const FARM_FERT := 0.3          # ...and +0.3 fertility (+0.2 more with Irrigation)
const IRRIGATION_FERT := 0.2

const PROD_CAP := 40            # woodcutters / miners / quarrymen per hex (a Mine doubles it)
const PROD_RATE := 0.015        # production points per worker per turn, per terrain "p"
const SERVICE_SHARE := 0.12     # carters, clergy, servants, traders: jobs per inhabitant
const BLD_JOBS := { "granary": 10, "workshop": 60, "market": 60, "school": 20 }
const PAY := { "prod": 50.0, "job": 60.0, "idle": 10.0 }   # pesos a year (idle = odd jobs)

const HOUSING := [0, 1500, 4000, 9000]    # room for people, by border radius 1..3
const IMMIGRATION := 0.03       # share of free room (jobs AND housing) filled per year at good LS
const TAX_PER_PERSON := 0.0004  # gold per person per turn (at LS 1)
const MIN_POP := 20


static func staple(game, c: Vector2i) -> String:
	var t: String = game.terrain[c]
	if t == "coast" or t == "ocean":
		return "fish"
	var row := float(game.axial_to_offset(c).y) / float(maxi(1, game.MAP_H))
	if row < 0.33: return "barley"      # cold north
	if row > 0.67: return "corn"        # warm south
	return "wheat"


# What one hex offers (used by the city and by the hex tooltip).
static func tile_info(game, c: Vector2i, n: int, center := false) -> Dictionary:
	var t: String = game.terrain[c]
	var tech: Dictionary = game.nations[n]["tech"]
	var imp: String = game.improvements.get(c, "")
	var info := { "crop": "", "fert": 0.0, "cap": 0, "prod_rate": 0.0, "prod_cap": 0 }
	if FERT.has(t):
		var fert: float = FERT[t]
		var cap: int = FARM_CAP[t]
		if imp == "farm":
			fert += FARM_FERT + (IRRIGATION_FERT if tech["irrigation"] else 0.0)
			cap = FARM_CAP_IMPROVED
		if center:                       # town gardens around the market square
			fert = maxf(fert, 0.8)
			cap = maxi(cap, 60)
		info["crop"] = staple(game, c)
		info["fert"] = fert
		info["cap"] = cap
	var p: int = game.TERRAIN[t]["p"]
	if imp == "mine":
		p += 2 if tech["iron_tools"] else 1
	if p > 0 and not center and not game._is_water(t):
		info["prod_rate"] = p * PROD_RATE
		info["prod_cap"] = PROD_CAP * (2 if imp == "mine" else 1)
	return info


# Food (t wheat-eq, after losses) from putting `a` more workers on a hex that already has `k`.
# Diminishing returns: the marginal farmer yields 1.25x at first, 0.80x when the hex is full.
static func _food_gain(per: float, cap: float, k: float, a: float) -> float:
	return per * a * (1.25 - 0.225 * (2.0 * k + a) / cap)


static func city_econ(game, city: Dictionary) -> Dictionary:
	var n: int = city["owner"]
	var center: Vector2i = city["cell"]
	var blds: Array = city["blds"]
	var pop := float(city["pop"])
	var labor := pop * LABOR_SHARE
	var need := pop * CAL_NEED
	var stock := float(city.get("grain", 0.0))
	var stock_cap := pop * 0.05 + (pop * 0.3 + 200.0 if "granary" in blds else 0.0)

	# ---- the city's hexes
	var farms := []
	var mines := []
	for h in game.territory.keys():
		if game.territory[h] != city["id"]:
			continue
		var ti := tile_info(game, h, n, h == center)
		if ti["cap"] > 0:
			var crop: Dictionary = CROPS[ti["crop"]]
			farms.append({ "c": h, "crop": ti["crop"], "cap": float(ti["cap"]), "k": 0.0,
				"per": crop["t"] * crop["cal"] * ti["fert"] * (1.0 - LOSS) })
		if ti["prod_cap"] > 0:
			mines.append({ "c": h, "cap": float(ti["prod_cap"]), "k": 0.0, "rate": ti["prod_rate"] })

	# ---- 1. farmers first: feed the city (+5%) and refill the granary
	var target := need * 1.05 + maxf(0.0, stock_cap - stock) * 0.25
	var left := labor
	var food := 0.0
	var chunk := maxf(5.0, labor / 80.0)
	while food < target and left > 0.01:
		var best := -1
		var best_m := 0.0
		for i in farms.size():
			var f: Dictionary = farms[i]
			if f["k"] < f["cap"]:
				var m: float = f["per"] * (1.25 - 0.45 * f["k"] / f["cap"])
				if m > best_m:
					best_m = m; best = i
		if best < 0:
			break
		var fb: Dictionary = farms[best]
		var a: float = minf(minf(chunk, left), fb["cap"] - fb["k"])
		food += _food_gain(fb["per"], fb["cap"], fb["k"], a)
		fb["k"] += a
		left -= a
	# ---- 2. building jobs and services, 3. woodcutters and miners
	var jobs_cap := pop * SERVICE_SHARE
	for b in blds:
		jobs_cap += BLD_JOBS.get(b, 0)
	var jobs := minf(left, jobs_cap)
	left -= jobs
	mines.sort_custom(func(a, b): return a["rate"] > b["rate"])
	var prod_workers := 0.0
	var hammers := 0.0
	var prod_room := 0.0
	for m in mines:
		var a: float = minf(left, m["cap"])
		m["k"] = a
		left -= a
		prod_workers += a
		hammers += a * m["rate"]
		prod_room += m["cap"] - a
	# ---- 4. anyone still without work farms the land that is left (surplus food, cheaper bread)
	farms.sort_custom(func(a, b): return a["per"] > b["per"])
	for f in farms:
		if left <= 0.01:
			break
		var a: float = minf(left, f["cap"] - f["k"])
		if a > 0.0:
			food += _food_gain(f["per"], f["cap"], f["k"], a)
			f["k"] += a
			left -= a
	var idle := maxf(0.0, left)
	var farm_room := 0.0
	for f in farms:
		farm_room += f["cap"] - f["k"]

	var farmers := 0.0
	var fishers := 0.0
	var crops := {}
	for f in farms:
		if f["k"] <= 0.0:
			continue
		crops[f["crop"]] = crops.get(f["crop"], 0.0) + _food_gain(f["per"], f["cap"], 0.0, f["k"])
		if f["crop"] == "fish": fishers += f["k"]
		else: farmers += f["k"]

	# ---- food market: coverage and price
	var draw := clampf(need - food, 0.0, stock * 0.5)
	var cov := 1.0 if need <= 0.0 else minf(1.0, (food + draw) / need)
	var price := BASE_PRICE * clampf(need / maxf(food + stock * 0.5, 0.01), 0.5, 4.0)

	# ---- standard of living
	var gdp := food * price + prod_workers * PAY["prod"] + jobs * PAY["job"] + idle * PAY["idle"]
	var income := gdp / maxf(pop, 1.0)
	# cost of living: the food part follows the grain price, the rest (clothes, rent, firewood) does not
	var subsist := CAL_NEED * price + CAL_NEED * BASE_PRICE * (1.0 / FOOD_SHARE - 1.0)
	var ls := income / subsist
	if cov < 1.0:
		ls *= 0.5 + 0.5 * cov
	var housing: int = HOUSING[clampi(int(city["radius"]), 1, 3)]
	var crowd := 0.0
	if pop > housing:
		crowd = minf(1.5, 4.0 * (pop - housing) / housing)     # slums: 10% over -> -0.4
		ls -= crowd

	# ---- what the turn gives the nation
	var p := 1 + int(hammers) + (2 if "workshop" in blds else 0)
	var tax := int(pop * TAX_PER_PERSON * clampf(ls, 0.5, 1.5))
	var g := 1 + tax + int(fishers / 150.0) + (3 if "market" in blds else 0) + (1 if game.has_trait(n, "trade") else 0)
	var sci := 1 + int(pop / 1500.0) + (2 if "school" in blds else 0)

	var worked := []
	for f in farms:
		if f["k"] > 0.0: worked.append(f["c"])
	for m in mines:
		if m["k"] > 0.0 and not (m["c"] in worked): worked.append(m["c"])
	# free jobs, counted in people (only if nobody is idle)
	var vacancy := 0.0 if idle > 1.0 else (farm_room + prod_room + maxf(0.0, jobs_cap - jobs)) / LABOR_SHARE
	return {
		"pop": pop, "labor": labor, "farmers": farmers, "fishers": fishers, "jobs": jobs, "jobs_cap": jobs_cap,
		"prod_workers": prod_workers, "idle": idle, "unemp": idle / maxf(labor, 1.0),
		"food": food, "need": need, "crops": crops, "cov": cov, "price": price,
		"stock": stock, "stock_cap": stock_cap,
		"gdp": gdp, "income": income, "subsist": subsist, "ls": ls, "crowd": crowd,
		"housing": housing, "vacancy": vacancy,
		"p": p, "p_land": int(hammers), "g": g, "tax": tax, "sci": sci, "worked": worked,
	}


# End of turn: two years of births, deaths, plague, migration, and the granary.
static func grow(game, city: Dictionary, e: Dictionary) -> Dictionary:
	var n: int = city["owner"]
	var pop := float(city["pop"])
	var ls: float = e["ls"]
	var cov: float = e["cov"]
	var x := clampf(ls - 0.5, 0.0, 1.0)
	var boost := 1.2 if game.has_trait(n, "growth") else 1.0
	var births_r := (0.030 + 0.015 * x) * boost
	var deaths_r := 0.045 - 0.020 * x + 0.06 * (1.0 - cov)
	var plague_p := 0.02 * sqrt(pop / 5000.0) * (0.25 if game.nations[n]["tech"]["vaccines"] else 1.0)
	var r := { "births": 0.0, "deaths": 0.0, "imm": 0.0, "emi": 0.0, "plague": 0.0, "start": pop }
	var stock: float = e["stock"]
	for year in game.YEARS_PER_TURN:
		var b := pop * births_r
		var d := pop * deaths_r
		var room := minf(e["vacancy"], float(e["housing"]) - pop)
		var imm := maxf(0.0, room) * IMMIGRATION * clampf(ls - 0.8, 0.0, 1.0) * boost
		var emi := pop * 0.03 * clampf(0.9 - ls, 0.0, 1.0)
		var pl := 0.0
		if randf() < plague_p:
			pl = pop * randf_range(0.03, 0.08)
		pop = maxf(MIN_POP, pop + b - d + imm - emi - pl)
		r["births"] += b; r["deaths"] += d; r["imm"] += imm; r["emi"] += emi; r["plague"] += pl
		# granary: surplus goes in, shortfalls come out, some rots
		stock += e["food"] - e["need"] if e["food"] >= e["need"] else -minf(stock * 0.5, e["need"] - e["food"])
		stock = clampf(stock * (1.0 - STOCK_DECAY), 0.0, e["stock_cap"])
	city["pop"] = int(round(pop))
	city["grain"] = snappedf(stock, 0.1)
	r["change"] = pop - r["start"]
	r["pct"] = 100.0 * r["change"] / maxf(1.0, r["start"])
	for k in r.keys():
		r[k] = snappedf(r[k], 0.1)
	city["last"] = r
	return r
