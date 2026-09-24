extends SceneTree
# Headless balance run: every nation (player too) is played by the AI.
#   godot --headless --path godot_starter --script res://sim_test.gd      (SEED=n to vary)
func _initialize() -> void:
	var g = load("res://main.tscn").instantiate()
	root.add_child(g)
	await process_frame
	seed(int(OS.get_environment("SEED")) if OS.get_environment("SEED") != "" else 7)
	g.start_game(0, "standard", 2)
	while not g.game_over:
		g._ai_turn(0)
		g._end_turn()
		if g.turn % 10 == 1 or g.game_over:
			var line := "%d" % g.year()
			for n in g.nations.size():
				var pop := 0; var cc := 0
				for c in g.cities:
					if c["owner"] == n:
						pop += int(c["pop"]); cc += 1
				line += " | N%d c%d %s g%d" % [n, cc, g.fmt_int(pop), g.nations[n]["gold"]]
			print(line)
			for c in g.cities:
				if c["owner"] == 0:
					var e: Dictionary = g.city_yield(c)
					print("     %-12s %6d ls %.2f fed %3d%% price %3d idle %2d%% farm %5d prod %4d jobs %4d  p%2d g%2d  house %d  last %+.1f%%" % [c["name"], c["pop"], e["ls"], int(e["cov"] * 100), int(e["price"]), int(e["unemp"] * 100), e["farmers"] + e["fishers"], e["prod_workers"], e["jobs"], e["p"], e["g"], e["housing"], c.get("last", {}).get("pct", 0.0)])
	# UI smoke test: city panel, city view, hex info on every owned hex
	for c in g.cities:
		if c["owner"] == 0:
			g._select(c)
			g.hud.refresh(true)
			g.hud.open_city_view()
			g.hud.refresh(true)
			for h in g.territory.keys():
				if g.territory[h] == c["id"]:
					g.hovered = h
					g.hud._update_tile_info()
			g.hud.close_city_view()
			break
	g._save_game()
	g._load_game()
	print("ui + save/load ok, player pop after load: %d" % g.cities[0]["pop"])
	var t0 := Time.get_ticks_usec()
	for c in g.cities:
		g._econ_cache.clear()
		g.city_yield(c)
	print("econ calc per city: %d us" % ((Time.get_ticks_usec() - t0) / maxi(1, g.cities.size())))
	quit()
