extends SceneTree
# Screenshots of the Economy I UI (needs a display: xvfb-run).
func _initialize() -> void:
	var g = load("res://main.tscn").instantiate()
	root.add_child(g)
	for i in 20: await process_frame
	root.get_viewport().get_texture().get_image().save_png("/tmp/claude-0/shot_title.png")
	seed(7)
	g.start_game(0, "standard", 2)
	while g.turn < 50:
		g._ai_turn(0)
		g._end_turn()
	var city: Dictionary = g.cities.filter(func(c): return c["owner"] == 0)[0]
	g._select(city)
	g._center_on(city["cell"])
	g.hovered = city["cell"] + Vector2i(1, 0)
	for i in 10: await process_frame
	g.hud.refresh(true)
	for i in 5: await process_frame
	root.get_viewport().get_texture().get_image().save_png("/tmp/claude-0/shot_map.png")
	for u in g.units:
		if u["owner"] == 0:
			g._select(u)
			break
	g.hud.refresh(true)
	for i in 5: await process_frame
	root.get_viewport().get_texture().get_image().save_png("/tmp/claude-0/shot_unit.png")
	g._select(city)
	g.hud._toggle(g.hud.tech_win)
	for i in 5: await process_frame
	root.get_viewport().get_texture().get_image().save_png("/tmp/claude-0/shot_tech.png")
	g.hud._toggle(g.hud.tech_win)
	g.hud.open_city_view()
	for i in 10: await process_frame
	root.get_viewport().get_texture().get_image().save_png("/tmp/claude-0/shot_city.png")
	quit()
