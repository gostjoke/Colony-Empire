extends CanvasLayer
# =============================================================
#  Colony Empire — HUD (Lesson 10d)
#  Every on-screen panel is a real Godot Control node, styled by
#  a Theme built in code.  Lesson 11b: classic 4X strategy skin —
#  slate-blue glass panels with bevelled gold frames, glossy
#  buttons and bars (9-slice images from tools/make_ui_skin.py),
#  white text with drop shadows, Cinzel titles + Alegreya Sans.
#
#  The HUD never changes the game directly: its buttons send the
#  same key codes as the keyboard (game._on_key), so each action
#  still has exactly one implementation in main.gd.
# =============================================================

var game      # main.gd — set by main before add_child()

# ---- palette ----
const C_BG := Color(0.075, 0.105, 0.15, 0.94)
const C_BG2 := Color(0.12, 0.16, 0.22, 0.96)
const C_INSET := Color(0.02, 0.035, 0.06, 0.7)
const C_BRASS := Color(0.8, 0.65, 0.36)
const C_BRASS_HI := Color(1.0, 0.86, 0.5)
const C_TEXT := Color(0.95, 0.96, 0.98)
const C_DIM := Color(0.66, 0.73, 0.82)
const C_GOOD := Color(0.55, 0.9, 0.45)
const C_BAD := Color(1.0, 0.45, 0.38)
const C_FOOD := Color(0.45, 0.74, 0.3)
const C_PROD := Color(0.86, 0.55, 0.22)
const C_SCI := Color(0.38, 0.6, 0.95)
const C_GOLD := Color(0.95, 0.76, 0.3)

# 9-slice skin images (assets/ui/skin_*.png): how many pixels of each edge must not stretch
const SKIN_MARGIN := { "panel": 14, "window": 16, "tooltip": 7, "card": 9, "card_on": 9, "inset": 7,
	"event": 8, "event_bad": 8, "button": 9, "button_hover": 9, "button_pressed": 9, "button_disabled": 9,
	"button_on": 10, "gold": 11, "gold_hover": 11, "gold_pressed": 11, "bar_bg": 6, "bar_fill": 6, "medal": 20 }
var skins := {}

const BUILD_ICONS := { "granary": "food", "workshop": "production", "market": "gold", "school": "research" }

var f_title: Font
var f_body: Font
var f_bold: Font
var icons := {}

var root: Control
var ui: Control          # everything shown while playing
var title_ui: Control    # the title screen (main menu, new game, settings)
# top bar
var badge: PanelContainer
var badge_letter: Label
var nation_label: Label
var chips := {}          # name -> [container, value label, delta label]
# panels
var toast: PanelContainer
var toast_label: Label
var toast_tween: Tween
var notif_box: VBoxContainer
var sel_panel: PanelContainer
var sel_box: VBoxContainer
var tile_panel: PanelContainer
var tile_title: Label
var tile_yields: HBoxContainer
var tile_note: Label
var end_btn: Button
var end_any: Button
var right_col: VBoxContainer
var mini: Control
var mini_tex: ImageTexture
var tech_win: PanelContainer
var tech_body: VBoxContainer
var diplo_win: PanelContainer
var diplo_body: VBoxContainer
var menu_win: PanelContainer
var over_win: PanelContainer
var over_body: VBoxContainer

var sel_sig := []
var top_sig := []
var mini_sig := []
var tile_sig := []
var win_sig := []


func _ready() -> void:
	layer = 10
	f_body = load("res://assets/fonts/AlegreyaSans-Regular.ttf")
	f_bold = load("res://assets/fonts/AlegreyaSans-Bold.ttf")
	var cinzel: FontFile = load("res://assets/fonts/Cinzel.ttf")
	var fv := FontVariation.new()
	fv.base_font = cinzel
	fv.variation_opentype = { "wght": 700 }
	f_title = fv
	for n in ["gold", "research", "food", "production", "population", "score", "year", "city", "culture", "moves", "diplomacy"]:
		icons[n] = load("res://assets/ui/icon_%s.png" % n)
	for n in SKIN_MARGIN.keys():
		skins[n] = load("res://assets/ui/skin_%s.png" % n)
	skins["topbar"] = load("res://assets/ui/skin_topbar.png")
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = _make_theme()
	add_child(root)
	ui = Control.new()
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(ui)
	_build_top_bar()
	_build_toast()
	_build_notifications()
	_build_selection_panel()
	_build_right_column()
	_build_windows()
	_build_city_view()
	_build_title()


# =============================================================
#  Theme
# =============================================================
func _box(bg: Color, border: Color, bw: int, radius: int, margin: float, shadow := 0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(bw)
	sb.set_corner_radius_all(radius)
	sb.set_content_margin_all(margin)
	sb.anti_aliasing = true
	if shadow > 0:
		sb.shadow_size = shadow
		sb.shadow_color = Color(0, 0, 0, 0.45)
		sb.shadow_offset = Vector2(0, 3)
	return sb


# A 9-slice image style. margin = content padding (-1: automatic), tint multiplies the image.
func _skin(name: String, margin := -1.0, tint := Color(1, 1, 1)) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = skins[name]
	var m: int = SKIN_MARGIN.get(name, 8)
	sb.set_texture_margin_all(m)
	sb.set_content_margin_all(margin if margin >= 0.0 else m * 0.75)
	sb.modulate_color = tint
	return sb


func _gold_button(b: Button) -> void:
	b.add_theme_stylebox_override("normal", _skin("gold", 8))
	b.add_theme_stylebox_override("hover", _skin("gold_hover", 8))
	b.add_theme_stylebox_override("pressed", _skin("gold_pressed", 8))
	b.add_theme_stylebox_override("disabled", _skin("button_disabled", 8))
	for k in ["font_color", "font_hover_color", "font_pressed_color"]:
		b.add_theme_color_override(k, Color(0.2, 0.11, 0.02))
	b.add_theme_color_override("font_outline_color", Color(1, 0.93, 0.7, 0.55))
	b.add_theme_constant_override("outline_size", 2)


func _make_theme() -> Theme:
	var th := Theme.new()
	th.default_font = f_body
	th.default_font_size = 16
	th.set_color("font_color", "Label", C_TEXT)
	th.set_color("font_shadow_color", "Label", Color(0, 0, 0, 0.8))
	th.set_constant("shadow_offset_x", "Label", 1)
	th.set_constant("shadow_offset_y", "Label", 2)
	th.set_stylebox("panel", "PanelContainer", _skin("panel", 12))
	# buttons: glossy steel-blue with a gold rim that lights up on hover
	th.set_stylebox("normal", "Button", _skin("button", 7))
	th.set_stylebox("hover", "Button", _skin("button_hover", 7))
	th.set_stylebox("pressed", "Button", _skin("button_pressed", 7))
	th.set_stylebox("hover_pressed", "Button", _skin("button_on", 7))
	th.set_stylebox("disabled", "Button", _skin("button_disabled", 7))
	th.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	th.set_color("font_color", "Button", C_TEXT)
	th.set_color("font_hover_color", "Button", Color(1, 0.97, 0.88))
	th.set_color("font_pressed_color", "Button", C_BRASS_HI)
	th.set_color("font_disabled_color", "Button", Color(0.55, 0.57, 0.6))
	th.set_color("font_outline_color", "Button", Color(0, 0, 0, 0.6))
	th.set_constant("outline_size", "Button", 3)
	th.set_constant("icon_max_width", "Button", 22)
	th.set_constant("h_separation", "Button", 6)
	th.set_font("font", "Button", f_bold)
	th.set_stylebox("background", "ProgressBar", _skin("bar_bg", 0))
	th.set_stylebox("fill", "ProgressBar", _skin("bar_fill", 0, C_GOOD))
	th.set_stylebox("panel", "TooltipPanel", _skin("tooltip", 9))
	th.set_color("font_color", "TooltipLabel", C_TEXT)
	th.set_font("font", "TooltipLabel", f_body)
	th.set_font_size("font_size", "TooltipLabel", 15)
	return th


# =============================================================
#  Small builders
# =============================================================
func _label(text := "", size := 16, col := C_TEXT, font: Font = null) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	if font != null:
		l.add_theme_font_override("font", font)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _icon(icon_name: String, size := 22) -> TextureRect:
	var t := TextureRect.new()
	t.texture = icons.get(icon_name)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.custom_minimum_size = Vector2(size, size)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t


func _hbox(sep := 8) -> HBoxContainer:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", sep)
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return hb


func _vbox(sep := 6) -> VBoxContainer:
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", sep)
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return vb


func _button(text: String, key := 0, icon_name := "", tip := "") -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE      # never let Enter/Space "click" a focused button
	if icon_name != "" and icons.has(icon_name):
		b.icon = icons[icon_name]
	b.tooltip_text = tip
	if key != 0:
		b.pressed.connect(_press.bind(key))
	return b


# Turns needed to fill `left` at `per_turn` a turn — always at least 1 ("next turn")
func _turns(left: float, per_turn: float) -> int:
	return maxi(1, ceili(maxf(0.0, left) / maxf(1.0, per_turn)))


func _press(key: int) -> void:
	game._on_key(key)
	game.queue_redraw()
	refresh(true)


# ---- Economy I helpers: standard of living, food, growth (economy.gd)
func _ls_word(ls: float) -> String:
	if ls < 0.6: return "Destitute"
	if ls < 0.9: return "Poor"
	if ls < 1.1: return "Getting by"
	if ls < 1.5: return "Comfortable"
	return "Prosperous"


func _ls_col(ls: float) -> Color:
	return C_BAD if ls < 0.9 else (C_TEXT if ls < 1.1 else C_GOOD)


func _food_text(y: Dictionary) -> String:
	return "Fed %d%%   ·   grain %d / t   ·   granary %s / %s t" % [int(y["cov"] * 100), int(round(y["price"])),
		game.fmt_int(y["stock"]), game.fmt_int(y["stock_cap"])]


func _growth_text(city: Dictionary) -> String:
	var r: Dictionary = city.get("last", {})
	if r.is_empty():
		return "Newly founded"
	return "%+.1f%% last turn  (%s people)" % [r["pct"], ("+" if r["change"] >= 0 else "") + game.fmt_int(r["change"])]


func _stat(icon_name: String, text: String, col := C_TEXT, size := 16) -> HBoxContainer:
	var hb := _hbox(4)
	hb.add_child(_icon(icon_name, 20))
	hb.add_child(_label(text, size, col, f_bold))
	return hb


func _bar(col: Color, value: float, max_value: float, text: String) -> ProgressBar:
	var pb := ProgressBar.new()
	pb.min_value = 0
	pb.max_value = maxf(1.0, max_value)
	pb.value = clampf(value, 0, pb.max_value)
	pb.show_percentage = false
	pb.custom_minimum_size = Vector2(0, 22)
	pb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pb.add_theme_stylebox_override("fill", _skin("bar_fill", 0, col.lightened(0.1)))
	var l := _label(text, 14, Color(1, 1, 1), f_bold)
	l.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("shadow_offset_x", 1)
	l.add_theme_constant_override("shadow_offset_y", 1)
	pb.add_child(l)
	return pb


func _clear(node: Node) -> void:
	for ch in node.get_children():
		node.remove_child(ch)
		ch.queue_free()


func _divider() -> Control:
	var c := ColorRect.new()
	c.color = Color(C_BRASS, 0.35)
	c.custom_minimum_size = Vector2(0, 1)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


# The upper part of a unit sprite (head to knees) makes a nice portrait
func _portrait(type: String, n: int) -> Texture2D:
	return _portrait_col(type, game.ncol(n))


func _portrait_col(type: String, col: Color) -> Texture2D:
	var tex: Texture2D = game._sprite_tex(type, col)
	if tex == null:
		return null
	var at := AtlasTexture.new()
	at.atlas = tex
	var w := tex.get_width()
	at.region = Rect2(w * 0.2, w * 0.1, w * 0.6, w * 0.6)
	return at


# =============================================================
#  Top bar
# =============================================================
func _build_top_bar() -> void:
	var bar := PanelContainer.new()
	var sb := StyleBoxTexture.new()
	sb.texture = skins["topbar"]
	sb.texture_margin_bottom = 10
	sb.texture_margin_top = 2
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 7
	sb.content_margin_bottom = 13
	bar.add_theme_stylebox_override("panel", sb)
	ui.add_child(bar)
	bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	var hb := _hbox(22)
	bar.add_child(hb)
	# nation badge: a coloured disc with the initial
	badge = PanelContainer.new()
	badge.custom_minimum_size = Vector2(34, 34)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge_letter = _label("", 18, Color(1, 1, 1), f_title)
	badge_letter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge_letter.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.add_child(badge_letter)
	var name_row := _hbox(10)
	name_row.add_child(badge)
	nation_label = _label("", 21, C_BRASS_HI, f_title)
	name_row.add_child(nation_label)
	hb.add_child(name_row)
	for spec in [["year", "year", "The year advances 2 years per turn. The game ends in 1811."],
			["gold", "gold", "Gold: spent on buying production and gifts to tribes."],
			["research", "research", "Research points: spend them on technologies."],
			["population", "population", "Total population of your cities."],
			["city", "city", "Number of cities."],
			["score", "score", "Score and rank among the colonial powers."]]:
		var chip := _hbox(6)
		chip.mouse_filter = Control.MOUSE_FILTER_STOP
		chip.tooltip_text = spec[2]
		chip.add_child(_icon(spec[1], 24))
		var v := _label("", 19, C_TEXT, f_bold)
		var d := _label("", 15, C_GOOD, f_bold)
		chip.add_child(v)
		chip.add_child(d)
		hb.add_child(chip)
		chips[spec[0]] = [chip, v, d]
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(spacer)
	var tech_btn := _button("Technology", 0, "research", "Spend research points  (Q / W / E)")
	tech_btn.pressed.connect(func(): _toggle(tech_win))
	hb.add_child(tech_btn)
	hb.add_child(_button("Diplomacy", KEY_D, "diplomacy", "Nations and native tribes  (D)"))
	var menu_btn := _button("Menu", 0, "", "Save, load, new map, controls")
	menu_btn.pressed.connect(func(): _toggle(menu_win))
	hb.add_child(menu_btn)


func _update_top() -> void:
	var me: Dictionary = game.me()
	var pop := 0
	var count := 0
	var inc_g: int = game._trade_income(0)
	var inc_r := 0
	var sig := [game.turn, me["gold"], me["research"], game.cities.size(), game.nations[0]["def"]]
	for city in game.cities:
		if city["owner"] == 0:
			pop += city["pop"]
			count += 1
			sig.append(city["pop"])
	if sig == top_sig:
		return
	top_sig = sig
	for city in game.cities:
		if city["owner"] == 0:
			var y: Dictionary = game.city_yield(city)
			inc_g += y["g"]
			inc_r += y["sci"]
	var col: Color = game.ncol(0)
	badge.add_theme_stylebox_override("panel", _box(col.darkened(0.15), C_BRASS_HI, 2, 17, 0))
	var nname: String = game.ndef(0)["name"]
	badge_letter.text = nname.substr(0, 1)
	nation_label.text = nname
	_set_chip("year", "%d AD" % game.year(), "turn %d" % game.turn, C_DIM)
	_set_chip("gold", str(me["gold"]), "%+d" % inc_g, C_GOOD if inc_g >= 0 else C_BAD)
	_set_chip("research", str(me["research"]), "%+d" % inc_r, C_SCI.lightened(0.3))
	_set_chip("population", game.fmt_int(pop), "people", C_DIM)
	_set_chip("city", str(count), "", C_DIM)
	var rank: int = game.ranking().find(0) + 1
	_set_chip("score", str(game.score(0)), "#%d of %d" % [rank, game.nations.size()], C_GOOD if rank == 1 else C_DIM)
	chips["gold"][0].tooltip_text = "Gold %d.  Per turn: %+d  (cities + tribe trade %+d)" % [me["gold"], inc_g, game._trade_income(0)]


func _set_chip(key: String, value: String, delta: String, delta_col: Color) -> void:
	var c: Array = chips[key]
	c[1].text = value
	c[2].text = delta
	c[2].add_theme_color_override("font_color", delta_col)


# =============================================================
#  Toast (short hints / errors) and the event feed
# =============================================================
func _build_toast() -> void:
	toast = PanelContainer.new()
	var tsb := _skin("panel", 10)
	tsb.content_margin_left = 22
	tsb.content_margin_right = 22
	toast.add_theme_stylebox_override("panel", tsb)
	toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(toast)
	toast.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	toast.grow_horizontal = Control.GROW_DIRECTION_BOTH
	toast.offset_top = 64
	toast_label = _label("", 17, C_TEXT, f_bold)
	toast.add_child(toast_label)
	toast.modulate.a = 0.0


func show_toast(text: String) -> void:
	if toast == null or text == "":
		return
	toast_label.text = text
	if toast_tween != null:
		toast_tween.kill()
	toast.modulate.a = 1.0
	toast_tween = toast.create_tween()
	toast_tween.tween_interval(2.6)
	toast_tween.tween_property(toast, "modulate:a", 0.0, 0.5)


func _build_notifications() -> void:
	notif_box = _vbox(6)
	ui.add_child(notif_box)
	notif_box.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	notif_box.offset_left = 12
	notif_box.offset_top = 62


const BAD_WORDS := ["raid", "starving", "Disease", "Fire", "resent"]

func push_event(text: String) -> void:
	if notif_box == null or text == "":
		return
	var bad := false
	for w in BAD_WORDS:
		if text.contains(w):
			bad = true
	var p := PanelContainer.new()
	var sb := _skin("event_bad" if bad else "event", 8)
	sb.content_margin_left = 12
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := _label(text, 15, C_TEXT)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(380, 0)
	p.add_child(l)
	notif_box.add_child(p)
	while notif_box.get_child_count() > 5:
		var old := notif_box.get_child(0)
		notif_box.remove_child(old)
		old.queue_free()
	p.modulate.a = 0.0
	var tw := p.create_tween()
	tw.tween_property(p, "modulate:a", 1.0, 0.25)
	tw.tween_interval(7.0)
	tw.tween_property(p, "modulate:a", 0.0, 0.8)
	tw.tween_callback(p.queue_free)


# =============================================================
#  Bottom-left: the selected unit or city
# =============================================================
func _build_selection_panel() -> void:
	sel_panel = PanelContainer.new()
	ui.add_child(sel_panel)
	sel_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE, 12)
	sel_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	sel_panel.custom_minimum_size = Vector2(500, 0)
	sel_box = _vbox(8)
	sel_panel.add_child(sel_box)
	sel_panel.visible = false


func _sel_sig() -> Array:
	var me: Dictionary = game.me()
	var u: Dictionary = game.selected_unit
	if not u.is_empty():
		return ["u", u["id"], u["cell"], u["mp"], u["job"], u["job_left"], u["sleep"], me["gold"]]
	var c: Dictionary = game.selected_city
	if not c.is_empty():
		return ["c", c["id"], c["build"], c["prod"], c["grain"], c["pop"], c["blds"].size(), c["radius"], me["gold"], game.turn]
	return []


func _rebuild_selection() -> void:
	_clear(sel_box)
	if not game.selected_unit.is_empty():
		_unit_panel(game.selected_unit)
	elif not game.selected_city.is_empty():
		_city_panel(game.selected_city)
	else:
		sel_panel.visible = false
		return
	sel_panel.visible = true


func _unit_panel(u: Dictionary) -> void:
	var spec: Dictionary = game.UNITS[u["type"]]
	var hb := _hbox(12)
	sel_box.add_child(hb)
	# portrait in a nation-coloured frame
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", _box(C_INSET, game.ncol(0), 2, 8, 2))
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pic := TextureRect.new()
	pic.texture = _portrait(u["type"], 0)
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pic.custom_minimum_size = Vector2(92, 92)
	frame.add_child(pic)
	hb.add_child(frame)
	var info := _vbox(4)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(info)
	var title_row := _hbox(8)
	title_row.add_child(_label(spec["name"], 24, C_BRASS_HI, f_title))
	info.add_child(title_row)
	# movement pips
	var mp_row := _hbox(6)
	mp_row.add_child(_icon("moves", 20))
	var full: int = spec["mp"]
	var left: float = u["mp"]
	var pips := ""
	for i in full:
		pips += "● " if left > i else "○ "
	mp_row.add_child(_label(pips.strip_edges(), 18, C_BRASS_HI if left > 0.0 else C_DIM, f_bold))
	mp_row.add_child(_label("%s / %d moves" % [str(snappedf(left, 0.5)), full], 15, C_DIM))
	info.add_child(mp_row)
	var status := ""
	if u["job"] != "":
		status = "Working: %s  —  %d turn%s left" % [u["job"], u["job_left"], "" if u["job_left"] == 1 else "s"]
	elif u["sleep"]:
		status = "Sleeping (select it to wake it up)"
	else:
		match u["type"]:
			"settler": status = "Founds new cities. Needs open land 4+ hexes from other cities."
			"worker": status = "Improves land inside your borders."
			"scout": status = "Sees 3 hexes. Village chiefs give scouts bigger gifts."
			"guard": status = "Protects your cities. (Combat arrives in a later lesson)"
	var sl := _label(status, 15, C_DIM)
	sl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sl.custom_minimum_size = Vector2(360, 0)
	info.add_child(sl)
	# action buttons (disabled ones explain why in their tooltip)
	var acts := HFlowContainer.new()
	acts.add_theme_constant_override("h_separation", 6)
	acts.add_theme_constant_override("v_separation", 6)
	sel_box.add_child(_divider())
	sel_box.add_child(acts)
	match u["type"]:
		"settler":
			var why: String = game._found_problem(u["cell"], 0)
			acts.add_child(_act("Found City", KEY_B, "B", why, "city"))
		"worker":
			for j in [["Farm", "farm", KEY_F, "F", "food"], ["Mine", "mine", KEY_M, "M", "production"],
					["Road", "road", KEY_R, "R", "moves"], ["Chop Forest", "chop", KEY_C, "C", "production"]]:
				acts.add_child(_act(j[0], j[2], j[3], game._job_problem(u, j[1]), j[4]))
	var v: Dictionary = game._village_near(u["cell"])
	if not v.is_empty():
		var why_g := "" if game.me()["gold"] >= game.GIFT_GOLD else "Needs %d gold" % game.GIFT_GOLD
		acts.add_child(_act("Gift %d gold" % game.GIFT_GOLD, KEY_T, "T", why_g, "gold",
			"Give %d gold to the %s (+%d attitude)" % [game.GIFT_GOLD, game.TRIBES[v["tribe"]]["name"], game.GIFT_ATT]))
	acts.add_child(_act("Skip", KEY_SPACE, "Space", "", "", "Do nothing this turn"))
	acts.add_child(_act("Sleep", KEY_H, "H", "", "", "Stay here until selected again"))
	var hint := _label("Right-click the map to move.   Tab: next unit.", 13, C_DIM)
	sel_box.add_child(hint)


func _act(text: String, key: int, hotkey: String, why: String, icon_name := "", tip := "") -> Button:
	var b := _button("%s  [%s]" % [text, hotkey], key, icon_name, tip)
	if why != "":
		b.disabled = true
		b.tooltip_text = why
	return b


func _city_panel(city: Dictionary) -> void:
	var y: Dictionary = game.city_yield(city)
	# header
	var head := _hbox(10)
	var swatch := ColorRect.new()
	swatch.color = game.ncol(0)
	swatch.custom_minimum_size = Vector2(6, 30)
	swatch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(swatch)
	var nm := _label(city["name"], 26, C_BRASS_HI, f_title)
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(nm)
	head.add_child(_stat("population", game.fmt_int(city["pop"])))
	head.add_child(_stat("culture", "Borders %d" % city["radius"], C_DIM))
	var open := _button("City View  [C]", 0, "city", "Open the city (or double-click it on the map)")
	open.pressed.connect(open_city_view)
	head.add_child(open)
	sel_box.add_child(head)
	# growth and production bars
	var r1 := _hbox(8)
	r1.add_child(_icon("food", 22))
	r1.add_child(_bar(C_FOOD if y["cov"] >= 1.0 else C_BAD, y["cov"] * 100.0, 100, _food_text(y)))
	sel_box.add_child(r1)
	var item: String = city["build"]
	var r2 := _hbox(8)
	r2.add_child(_icon("production", 22))
	if item == "":
		r2.add_child(_bar(C_BAD.darkened(0.3), 0, 1, "Choose something to build!"))
	else:
		var cost: int = game.build_cost(item)
		var turns := _turns(cost - city["prod"], y["p"])
		r2.add_child(_bar(C_PROD, city["prod"], cost, "%s  %d / %d   (+%d)  ·  %d turn%s" % [game._item_name(item),
			city["prod"], cost, y["p"], turns, "" if turns == 1 else "s"]))
	sel_box.add_child(r2)
	# yields
	var yr := _hbox(18)
	var ls: float = y["ls"]
	var lsl := _stat("population", "%s %.2f   ·   %s" % [_ls_word(ls), ls, _growth_text(city)], _ls_col(ls))
	lsl.tooltip_text = "Standard of living = income per person ÷ cost of living"
	yr.add_child(lsl)
	yr.add_child(_stat("production", "+%d" % y["p"]))
	yr.add_child(_stat("gold", "+%d" % y["g"]))
	yr.add_child(_stat("research", "+%d" % y["sci"]))
	var blds: Array = city["blds"]
	var bl := _label("Buildings: " + (", ".join(blds.map(func(b): return game._item_name(b))) if not blds.is_empty() else "none"), 14, C_DIM)
	bl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	yr.add_child(bl)
	sel_box.add_child(yr)
	sel_box.add_child(_divider())
	# build menu: 4 x 2 cards
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	sel_box.add_child(grid)
	for i in game.BUILD_ORDER.size():
		var key: String = game.BUILD_ORDER[i]
		var cost: int = game.build_cost(key)
		var built: bool = key in blds
		var turns := _turns(cost - city["prod"], y["p"])
		var b := _button("%s\n%s" % [game._item_name(key), "built" if built else "%d  ·  %dt" % [cost, turns]], KEY_1 + i)
		b.custom_minimum_size = Vector2(118, 50)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_font_size_override("font_size", 14)
		if game.UNITS.has(key):
			b.icon = _portrait(key, 0)
			b.add_theme_constant_override("icon_max_width", 34)
			var why: String = game.complete_problem(city, key)
			b.tooltip_text = "%s — takes %d people from the city%s" % [game._item_name(key), game.UNITS[key]["people"], ("\n" + why) if why != "" else ""]
		else:
			b.icon = icons[BUILD_ICONS[key]]
			b.tooltip_text = game.BUILDINGS[key]["desc"]
		if built:
			b.disabled = true
		if key == item:
			b.add_theme_stylebox_override("normal", _skin("button_on", 6))
			b.add_theme_stylebox_override("hover", _skin("button_on", 6))
		b.tooltip_text = ("[%d]  " % (i + 1)) + (b.tooltip_text if b.tooltip_text != "" else game._item_name(key))
		grid.add_child(b)
	# buy
	if item != "":
		var cost_g: int = maxi(0, (game.build_cost(item) - int(city["prod"])) * 2)
		var buy := _button("Buy %s now for %d gold   [G]" % [game._item_name(item), cost_g], KEY_G, "gold")
		if cost_g > game.me()["gold"]:
			buy.disabled = true
			buy.tooltip_text = "Not enough gold"
		elif not game._can_complete(city, item):
			buy.disabled = true
			buy.tooltip_text = game.complete_problem(city, item)
		sel_box.add_child(buy)


# =============================================================
#  Bottom-right: hovered hex, End Turn, minimap
# =============================================================
func _build_right_column() -> void:
	var col := _vbox(8)
	right_col = col
	ui.add_child(col)
	col.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, 12)
	col.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	col.grow_vertical = Control.GROW_DIRECTION_BEGIN
	col.custom_minimum_size = Vector2(280, 0)
	# hovered hex info
	tile_panel = PanelContainer.new()
	tile_panel.add_theme_stylebox_override("panel", _skin("panel", 11))
	tile_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tv := _vbox(3)
	tile_panel.add_child(tv)
	tile_title = _label("", 17, C_BRASS_HI, f_title)
	tv.add_child(tile_title)
	tile_yields = _hbox(12)
	tv.add_child(tile_yields)
	tile_note = _label("", 14, C_DIM)
	tile_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tile_note.custom_minimum_size = Vector2(250, 0)
	tv.add_child(tile_note)
	col.add_child(tile_panel)
	# end turn
	end_btn = Button.new()
	end_btn.focus_mode = Control.FOCUS_NONE
	end_btn.custom_minimum_size = Vector2(280, 56)
	end_btn.add_theme_font_override("font", f_title)
	end_btn.add_theme_font_size_override("font_size", 21)
	_gold_button(end_btn)
	end_btn.tooltip_text = "Enter: end the turn   ·   Tab: next unit"
	end_btn.pressed.connect(_on_end_pressed)
	col.add_child(end_btn)
	end_any = _button("End the turn anyway   [Enter]", KEY_ENTER)
	end_any.flat = true
	end_any.add_theme_font_size_override("font_size", 14)
	end_any.add_theme_color_override("font_color", C_DIM)
	col.add_child(end_any)
	# minimap
	var mp := PanelContainer.new()
	mp.add_theme_stylebox_override("panel", _skin("panel", 7))
	col.add_child(mp)
	mini = Control.new()
	mini.custom_minimum_size = Vector2(270, 126)
	mini.mouse_filter = Control.MOUSE_FILTER_STOP
	mini.tooltip_text = "Click to move the camera"
	mini.draw.connect(_draw_minimap)
	mini.gui_input.connect(_minimap_input)
	mp.add_child(mini)


func _waiting() -> int:
	return game.units.filter(func(u): return game._needs_orders(u)).size()


func _on_end_pressed() -> void:
	_press(KEY_TAB if _waiting() > 0 else KEY_ENTER)


func _update_end_turn() -> void:
	var w := _waiting()
	end_btn.text = "Next Unit  (%d)" % w if w > 0 else "End Turn"
	end_btn.disabled = game.game_over
	end_any.visible = w > 0 and not game.game_over


func _update_tile_info() -> void:
	var c: Vector2i = game.hovered
	var sig := [c, game.turn, game.seen.has(c), game.improvements.get(c, ""), game.roads.has(c), game.territory.get(c, -1)]
	if sig == tile_sig:
		return
	tile_sig = sig
	if not game.terrain.has(c):
		tile_panel.visible = false
		return
	tile_panel.visible = true
	_clear(tile_yields)
	if not game.seen.has(c):
		tile_title.text = "Unexplored"
		tile_note.text = "Send a scout to see what lies here."
		return
	if game.village_at.has(c):
		var v: Dictionary = game.village_at[c]
		var t: int = v["tribe"]
		var a: int = game.tribes[t]["att"][0]
		tile_title.text = "%s village" % game.TRIBES[t]["name"]
		tile_yields.add_child(_stat("diplomacy", "Attitude %d  (%s)" % [a, game.mood(a)], C_GOOD if a >= game.TRADE_ATT else (C_BAD if a < 0 else C_TEXT)))
		tile_note.text = "Walk next to it to visit." if not v["visited"] else "Already visited.  [T] next to it: gift %d gold." % game.GIFT_GOLD
		return
	var ti: Dictionary = game.tile_info(c)
	tile_title.text = game.TERRAIN[game.terrain[c]]["name"]
	if ti["cap"] > 0:
		var crop: Dictionary = game.Econ.CROPS[ti["crop"]]
		var st := _stat("food", "%s  %.1f t × %d" % [crop["name"], crop["t"] * ti["fert"], ti["cap"]])
		st.tooltip_text = "%s: %.1f t a year per worker, room for %d workers" % [crop["name"], crop["t"] * ti["fert"], ti["cap"]]
		tile_yields.add_child(st)
	if ti["prod_cap"] > 0:
		tile_yields.add_child(_stat("production", "%d workers" % ti["prod_cap"]))
	if ti["cap"] == 0 and ti["prod_cap"] == 0:
		tile_yields.add_child(_label("Nothing to work here", 14, C_DIM))
	var notes := []
	if game.improvements.has(c): notes.append(str(game.improvements[c]).capitalize())
	if game.roads.has(c): notes.append("Road")
	if game.territory.has(c):
		var city: Dictionary = game._city_by_id(game.territory[c])
		notes.append("%s  (%s)" % [city["name"], game.ndef(city["owner"])["name"]])
	elif game.tribe_land.has(c):
		notes.append("%s land" % game.TRIBES[game.tribe_land[c]]["name"])
	var move: int = game.TERRAIN[game.terrain[c]]["move"]
	notes.append("Move cost %s" % ("—" if move == 0 else str(move)))
	if game.in_sight.has(c):
		for u in game.units:
			if u["cell"] == c and u["owner"] != 0:
				notes.append("%s %s" % [game.ndef(u["owner"])["name"], game.UNITS[u["type"]]["name"]])
	tile_note.text = "   ·   ".join(notes)


# ---- minimap: one 4x3 block per hex, odd rows shifted like the real map ----
func _rebuild_minimap() -> void:
	var w: int = game.MAP_W * 4 + 2
	var h: int = game.MAP_H * 3
	mini.custom_minimum_size = Vector2(270, roundf(270.0 * h / w))    # keep the map's shape
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.05, 0.05, 0.06))
	for c in game.terrain.keys():
		if not game.seen.has(c):
			continue
		var o: Vector2i = game.axial_to_offset(c)
		var col: Color = game.TERRAIN[game.terrain[c]]["col"]
		if game.territory.has(c):
			col = col.lerp(game.ncol(game._cell_nation(c)), 0.55)
		elif game.tribe_land.has(c):
			col = col.lerp(game.TRIBES[game.tribe_land[c]]["col"], 0.35)
		if game.city_at.has(c):
			col = Color(1, 1, 1)
		elif game.village_at.has(c):
			col = Color(0.95, 0.85, 0.6)
		img.fill_rect(Rect2i(o.x * 4 + (2 if o.y % 2 == 1 else 0), o.y * 3, 4, 3), col)
	mini_tex = ImageTexture.create_from_image(img)


func _mini_scale() -> Vector2:
	return mini.size / Vector2(game.MAP_W * 4 + 2, game.MAP_H * 3)


func _draw_minimap() -> void:
	if mini_tex == null:
		return
	mini.draw_texture_rect(mini_tex, Rect2(Vector2.ZERO, mini.size), false)
	# the camera's view as a rectangle
	var vp: Vector2 = game.get_viewport_rect().size
	var s := _mini_scale()
	var a := _screen_to_mini(Vector2.ZERO) * s
	var b := _screen_to_mini(vp) * s
	var rect := Rect2(a, b - a).intersection(Rect2(Vector2.ZERO, mini.size))
	mini.draw_rect(rect, Color(1, 1, 1, 0.9), false, 1.5)


func _screen_to_mini(p: Vector2) -> Vector2:
	var w: Vector2 = (p - game.origin) / game.zoom
	w.y /= game.TILT
	return Vector2(w.x / (game.SQ3 * game.HEX) * 4.0 + 2.0, w.y / (1.5 * game.HEX) * 3.0 + 1.5)


func _minimap_input(ev: InputEvent) -> void:
	var drag: bool = ev is InputEventMouseMotion and (ev.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0
	if (ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT) or drag:
		var m: Vector2 = ev.position / _mini_scale()
		var world := Vector2((m.x - 2.0) / 4.0 * game.SQ3 * game.HEX, (m.y - 1.5) / 3.0 * 1.5 * game.HEX)
		var c: Vector2i = game._world_to_hex(world)
		if game.terrain.has(c):
			game._center_on(c)
			game.queue_redraw()
			mini.queue_redraw()


# =============================================================
#  Windows: technology, diplomacy, menu, game over
# =============================================================
func _window(title: String, width: float, closable := true) -> Array:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _skin("window", 20))
	ui.add_child(p)
	p.custom_minimum_size = Vector2(width, 0)
	var v := _vbox(12)
	p.add_child(v)
	var hb := _hbox(8)
	var t := _label(title, 28, C_BRASS_HI, f_title)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(t)
	if closable:
		var close := _button("Close", 0, "", "Esc")
		close.pressed.connect(func(): _close(p))
		hb.add_child(close)
	v.add_child(hb)
	v.add_child(_divider())
	var body := _vbox(10)
	v.add_child(body)
	p.visible = false
	return [p, body]


# Containers learn their new minimum size one frame after their content changes,
# so the panels are (re)placed every frame: bottom-left, bottom-right, centred windows.
func _process(_delta: float) -> void:
	if root == null:
		return
	var vp := root.get_viewport_rect().size
	if title_ui.visible:
		_place_title(vp)
		return
	if sel_panel.visible:
		sel_panel.size = sel_panel.get_combined_minimum_size()
		sel_panel.position = Vector2(12, vp.y - sel_panel.size.y - 12)
	right_col.size = right_col.get_combined_minimum_size()
	right_col.position = vp - right_col.size - Vector2(12, 12)
	for p in [tech_win, diplo_win, menu_win, over_win]:
		if p.visible:
			p.size = p.get_combined_minimum_size()
			p.position = ((vp - p.size) * 0.5).floor()
	toast.size = toast.get_combined_minimum_size()
	toast.position = Vector2(floorf((vp.x - toast.size.x) * 0.5), 64)


func _toggle(p: Control) -> void:
	var show := not p.visible
	close_windows()
	if show:
		p.visible = true
		win_sig = []
		refresh(true)


func _close(p: Control) -> void:
	if p == diplo_win:
		if game.show_diplo:
			_press(KEY_D)
		return
	p.visible = false


# Esc: close whatever is open. Returns true if something was closed.
func close_windows() -> bool:
	if cv != null and cv.visible:
		close_city_view()
		return true
	var any := false
	for p in [tech_win, menu_win]:
		if p.visible:
			p.visible = false
			any = true
	if game.show_diplo:
		game.show_diplo = false
		diplo_win.visible = false
		any = true
	return any


func _build_windows() -> void:
	var w := _window("Technology", 760)
	tech_win = w[0]
	tech_body = w[1]
	w = _window("Diplomacy", 900)
	diplo_win = w[0]
	diplo_body = w[1]
	w = _window("Menu", 520)
	menu_win = w[0]
	var mb: VBoxContainer = w[1]
	var row := _hbox(8)
	for spec in [["Save  [F5]", KEY_F5], ["Load  [F9]", KEY_F9], ["New Map  [F2]", KEY_F2]]:
		var b := _button(spec[0], spec[1])
		b.custom_minimum_size = Vector2(150, 40)
		b.pressed.connect(func(): menu_win.visible = false)
		row.add_child(b)
	mb.add_child(row)
	var row2 := _hbox(8)
	var to_title := _button("Main Menu")
	to_title.custom_minimum_size = Vector2(150, 40)
	to_title.pressed.connect(func():
		menu_win.visible = false
		game.go_to_menu())
	row2.add_child(to_title)
	var fs := _button("Fullscreen  [F11]")
	fs.custom_minimum_size = Vector2(150, 40)
	fs.pressed.connect(func():
		game.fullscreen = not game.fullscreen
		game.apply_settings()
		game.save_settings())
	row2.add_child(fs)
	var quit := _button("Quit Game")
	quit.custom_minimum_size = Vector2(150, 40)
	quit.pressed.connect(func(): get_tree().quit())
	row2.add_child(quit)
	mb.add_child(row2)
	mb.add_child(_label("Controls", 18, C_BRASS_HI, f_title))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 18)
	for pair in [["Left click", "Select a unit or city (click again to cycle)"], ["Right click", "Move the selected unit"],
			["Enter / Tab", "End turn / next unit"], ["B  F  M  R  C", "Found city / farm / mine / road / chop"],
			["T", "Gift gold to a nearby village"], ["Space / H", "Skip / sleep"], ["1 - 8,  G", "City: choose build, buy it"],
			["Q  W  E", "Research a technology"], ["D", "Diplomacy"], ["Arrows, middle drag, wheel", "Move and zoom the camera"],
			["Esc", "Close windows / deselect"]]:
		grid.add_child(_label(pair[0], 15, C_TEXT, f_bold))
		grid.add_child(_label(pair[1], 15, C_DIM))
	mb.add_child(grid)
	w = _window("The Year 1811", 620, false)
	over_win = w[0]
	over_body = w[1]


func _rebuild_tech() -> void:
	_clear(tech_body)
	var me: Dictionary = game.me()
	tech_body.add_child(_stat("research", "%d research points" % me["research"], C_TEXT, 18))
	var row := _hbox(12)
	tech_body.add_child(row)
	for key in game.TECHS.keys():
		var t: Dictionary = game.TECHS[key]
		var owned: bool = me["tech"][key]
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel", _skin("card_on" if owned else "card", 12))
		card.custom_minimum_size = Vector2(228, 0)
		var v := _vbox(8)
		card.add_child(v)
		v.add_child(_label(str(key).capitalize(), 20, C_BRASS_HI, f_title))
		var d := _label(t["desc"], 15, C_TEXT)
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		d.custom_minimum_size = Vector2(200, 44)
		v.add_child(d)
		v.add_child(_stat("research", "%d" % t["cost"], C_TEXT))
		var keycode: int = OS.find_keycode_from_string(t["key"])
		var b := _button("Known" if owned else "Research  [%s]" % t["key"], 0 if owned else keycode)
		if owned:
			b.disabled = true
		elif me["research"] < t["cost"]:
			b.disabled = true
			b.tooltip_text = "Needs %d more research" % (t["cost"] - me["research"])
		v.add_child(b)
		row.add_child(card)


func _rebuild_diplomacy() -> void:
	_clear(diplo_body)
	diplo_body.add_child(_label("Colonial powers", 19, C_BRASS_HI, f_title))
	var g := GridContainer.new()
	g.columns = 6
	g.add_theme_constant_override("h_separation", 22)
	g.add_theme_constant_override("v_separation", 6)
	diplo_body.add_child(g)
	for h in ["Nation", "Relation", "Cities", "Pop", "Score", "Trait"]:
		g.add_child(_label(h, 14, C_DIM, f_bold))
	for n in game.nations.size():
		var met: bool = n == 0 or game.nations[n]["met"]
		var name_row := _hbox(8)
		var sw := ColorRect.new()
		sw.color = game.ncol(n) if met else Color(0.3, 0.3, 0.3)
		sw.custom_minimum_size = Vector2(14, 14)
		name_row.add_child(sw)
		name_row.add_child(_label(game.ndef(n)["name"] if met else "Unknown", 17, C_TEXT if met else C_DIM, f_bold))
		g.add_child(name_row)
		if not met:
			for i in 5:
				g.add_child(_label("?" if i < 4 else "Not met yet", 15, C_DIM))
			continue
		var cs := 0
		var pop := 0
		for city in game.cities:
			if city["owner"] == n:
				cs += 1
				pop += city["pop"]
		g.add_child(_label("You" if n == 0 else "Peace", 15, C_BRASS_HI if n == 0 else C_GOOD))
		g.add_child(_label(str(cs), 15))
		g.add_child(_label(game.fmt_int(pop), 15))
		g.add_child(_label(str(game.score(n)), 15))
		g.add_child(_label(game.ndef(n)["desc"], 14, C_DIM))
	diplo_body.add_child(_divider())
	diplo_body.add_child(_label("Native tribes", 19, C_BRASS_HI, f_title))
	var tg := GridContainer.new()
	tg.columns = 4
	tg.add_theme_constant_override("h_separation", 22)
	tg.add_theme_constant_override("v_separation", 6)
	diplo_body.add_child(tg)
	for h in ["Tribe", "Villages", "Attitude towards you", "Trade"]:
		tg.add_child(_label(h, 14, C_DIM, f_bold))
	for t in game.tribes.size():
		if not game._tribe_alive(t):
			continue
		var met: bool = game.tribes[t]["met"]
		var nr := _hbox(8)
		var sw := ColorRect.new()
		sw.color = game.TRIBES[t]["col"] if met else Color(0.3, 0.3, 0.3)
		sw.custom_minimum_size = Vector2(14, 14)
		nr.add_child(sw)
		nr.add_child(_label(game.TRIBES[t]["name"] if met else "Unknown", 17, C_TEXT if met else C_DIM, f_bold))
		tg.add_child(nr)
		if not met:
			tg.add_child(_label("?", 15, C_DIM))
			tg.add_child(_label("Not met yet", 15, C_DIM))
			tg.add_child(_label("", 15))
			continue
		tg.add_child(_label(str(game.villages.filter(func(v): return v["tribe"] == t).size()), 15))
		var a: int = game.tribes[t]["att"][0]
		var col := C_GOOD if a >= game.TRADE_ATT else (C_BAD if a <= -20 else C_GOLD)
		var bar := _bar(col, a + 100, 200, "%d   %s" % [a, game.mood(a)])
		bar.custom_minimum_size = Vector2(240, 20)
		tg.add_child(bar)
		tg.add_child(_stat("gold", "+%d / turn" % game._trade_income(0, t), C_TEXT, 15))
	var rules := _label("Walk next to a village to visit it (first visit = a gift).  [T] next to a village gives %d gold (+%d).\nFriendly (%d+) with one of your cities within %d hexes: +1 gold per village each turn.\nSettling within 4 hexes of a village: -%d.  At %d or below, they raid your nearest city." % [
		game.GIFT_GOLD, game.GIFT_ATT, game.TRADE_ATT, game.TRADE_RANGE, game.LAND_GRAB, game.RAID_ATT], 14, C_DIM)
	diplo_body.add_child(_divider())
	diplo_body.add_child(rules)


func _rebuild_game_over() -> void:
	_clear(over_body)
	var order: Array = game.ranking()
	var place: int = order.find(0) + 1
	over_body.add_child(_label("You finished #%d of %d" % [place, order.size()], 22, C_GOOD if place == 1 else C_TEXT, f_title))
	var g := GridContainer.new()
	g.columns = 3
	g.add_theme_constant_override("h_separation", 30)
	for i in order.size():
		var n: int = order[i]
		g.add_child(_label("%d." % (i + 1), 18, C_DIM, f_bold))
		g.add_child(_label(game.ndef(n)["name"] + ("  (you)" if n == 0 else ""), 18, game.ncol(n), f_bold))
		g.add_child(_label(str(game.score(n)), 18, C_TEXT, f_bold))
	over_body.add_child(g)
	over_body.add_child(_label("Score = population / 125 + cities x10 + land + technologies x10 + gold / 20", 14, C_DIM))
	var row := _hbox(10)
	var b := _button("Play Again  [F2]", KEY_F2)
	b.custom_minimum_size = Vector2(200, 42)
	row.add_child(b)
	var m := _button("Main Menu")
	m.custom_minimum_size = Vector2(200, 42)
	m.pressed.connect(func(): game.go_to_menu())
	row.add_child(m)
	over_body.add_child(row)


# =============================================================
#  Refresh — called by main.gd whenever something visible changed
# =============================================================
func refresh(force := false) -> void:
	if game == null or game.nations.is_empty() or root == null or game.in_menu:
		return
	if force:
		sel_sig = []
		top_sig = []
		tile_sig = []
	_update_top()
	var s := _sel_sig()
	if s != sel_sig:
		sel_sig = s
		_rebuild_selection()
	_update_tile_info()
	_update_end_turn()
	var ms := [game.turn, game.seen.size(), game.cities.size(), game.territory.size(), game.improvements.size()]
	if ms != mini_sig:
		mini_sig = ms
		_rebuild_minimap()
	mini.queue_redraw()
	# windows
	diplo_win.visible = game.show_diplo
	over_win.visible = game.game_over
	var ws := [game.turn, game.me()["gold"], game.me()["research"], game.me()["tech"].values(), game.show_diplo, tech_win.visible, game.game_over,
		game.tribes.map(func(t): return t["att"][0]), game.nations.map(func(n): return n["met"])]
	if force or ws != win_sig:
		win_sig = ws
		if tech_win.visible:
			_rebuild_tech()
		if diplo_win.visible:
			_rebuild_diplomacy()
		if over_win.visible:
			_rebuild_game_over()
	_update_city_view(force)


func on_new_game() -> void:
	close_city_view()
	for ch in notif_box.get_children():
		ch.queue_free()
	mini_sig = []
	win_sig = []
	refresh(true)


# =============================================================
#  Title screen: main menu, new-game setup, settings
#  (the live map drifting behind it is drawn by main.gd)
# =============================================================
var title_col: VBoxContainer
var main_menu: VBoxContainer
var continue_btn: Button
var setup_panel: PanelContainer
var settings_panel: PanelContainer
var settings_info: Label
var footer: Label
var nation_cards := []
var size_btns := {}
var rival_btns := []
var fs_btns := []
var scale_btns := {}
var pick_nation := 0
var pick_size := "standard"
var pick_rivals := 2


func _build_title() -> void:
	title_ui = Control.new()
	title_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	title_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(title_ui)
	# darker towards the edges (vignette) so the text reads well over the map
	var g := Gradient.new()
	g.set_color(0, Color(0, 0, 0, 0.0))
	g.set_color(1, Color(0, 0, 0, 0.78))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.62, 0.5)
	gt.fill_to = Vector2(1.25, 0.5)
	gt.width = 256
	gt.height = 256
	var shade := TextureRect.new()
	shade.texture = gt
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_ui.add_child(shade)
	var band := ColorRect.new()
	band.color = Color(0.04, 0.035, 0.03, 0.62)
	band.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	band.offset_right = 560
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_ui.add_child(band)
	var edge := ColorRect.new()
	edge.color = Color(C_BRASS, 0.7)
	edge.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	edge.offset_left = 560
	edge.offset_right = 562
	edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_ui.add_child(edge)
	# title + main menu
	title_col = _vbox(10)
	title_ui.add_child(title_col)
	var t := _label("Colony", 78, C_BRASS_HI, f_title)
	var t2 := _label("Empire", 78, C_BRASS_HI, f_title)
	for l in [t, t2]:
		l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
		l.add_theme_constant_override("shadow_offset_x", 3)
		l.add_theme_constant_override("shadow_offset_y", 4)
		title_col.add_child(l)
	title_col.add_child(_label("A New World   ·   1500 – 1811", 22, C_DIM, f_title))
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 36)
	title_col.add_child(gap)
	main_menu = _vbox(12)
	title_col.add_child(main_menu)
	var b_new := _menu_button("New Game")
	b_new.pressed.connect(func(): show_page("setup"))
	main_menu.add_child(b_new)
	continue_btn = _menu_button("Continue")
	continue_btn.pressed.connect(func(): game.continue_game())
	main_menu.add_child(continue_btn)
	var b_set := _menu_button("Settings")
	b_set.pressed.connect(func(): show_page("settings"))
	main_menu.add_child(b_set)
	var b_quit := _menu_button("Quit")
	b_quit.pressed.connect(func(): get_tree().quit())
	main_menu.add_child(b_quit)
	footer = _label("Prototype  ·  Fonts: Cinzel & Alegreya Sans (SIL Open Font License)", 13, Color(C_DIM, 0.8))
	title_ui.add_child(footer)
	_build_setup()
	_build_settings()
	title_ui.visible = false


func _menu_button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(320, 56)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.add_theme_font_override("font", f_title)
	b.add_theme_font_size_override("font_size", 24)
	var normal := _skin("button", 14)
	normal.content_margin_left = 24
	var hover := _skin("button_hover", 14)
	hover.content_margin_left = 30
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", hover)
	b.add_theme_color_override("font_hover_color", C_BRASS_HI)
	return b


# A toggle button that belongs to a group (only one pressed at a time)
func _option_button(text: String, group: ButtonGroup) -> Button:
	var b := Button.new()
	b.text = text
	b.toggle_mode = true
	b.button_group = group
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_stylebox_override("normal", _skin("card", 10))
	b.add_theme_stylebox_override("hover", _skin("button_hover", 10))
	var on := _skin("button_on", 10)
	b.add_theme_stylebox_override("pressed", on)
	b.add_theme_stylebox_override("hover_pressed", on)
	b.add_theme_color_override("font_pressed_color", Color(1, 0.95, 0.8))
	b.add_theme_color_override("font_hover_pressed_color", Color(1, 0.95, 0.8))
	return b


func _section(text: String) -> Label:
	return _label(text, 20, C_DIM, f_title)


func _build_setup() -> void:
	setup_panel = PanelContainer.new()
	setup_panel.add_theme_stylebox_override("panel", _skin("window", 26))
	title_ui.add_child(setup_panel)
	var v := _vbox(14)
	setup_panel.add_child(v)
	v.add_child(_label("New Game", 36, C_BRASS_HI, f_title))
	v.add_child(_divider())
	v.add_child(_section("Choose your nation"))
	var cards := _hbox(14)
	v.add_child(cards)
	var ng := ButtonGroup.new()
	for i in game.NATIONS.size():
		var card := _nation_card(i, ng)
		cards.add_child(card)
		nation_cards.append(card)
	v.add_child(_section("Map size"))
	var sizes := _hbox(12)
	v.add_child(sizes)
	var sg := ButtonGroup.new()
	for key in game.MAP_SIZES.keys():
		var sz: Dictionary = game.MAP_SIZES[key]
		var b := _option_button("%s\n%d × %d hexes  ·  %d native tribes" % [sz["name"], sz["w"], sz["h"], sz["tribes"]], sg)
		b.custom_minimum_size = Vector2(290, 66)
		b.add_theme_font_size_override("font_size", 17)
		b.pressed.connect(func(): _pick_size(key))
		sizes.add_child(b)
		size_btns[key] = b
	v.add_child(_section("Rival colonies"))
	var rv := _hbox(12)
	v.add_child(rv)
	var rg := ButtonGroup.new()
	for n in [1, 2, 3]:
		var b := _option_button(str(n), rg)
		b.custom_minimum_size = Vector2(76, 46)
		b.add_theme_font_override("font", f_title)
		b.add_theme_font_size_override("font_size", 22)
		b.pressed.connect(func(): pick_rivals = n)
		rv.add_child(b)
		rival_btns.append(b)
	var hint := _label("   More rivals = less free land and a tougher race for the New World.", 15, C_DIM)
	rv.add_child(hint)
	v.add_child(_divider())
	var row := _hbox(12)
	v.add_child(row)
	var back := _button("Back")
	back.custom_minimum_size = Vector2(140, 48)
	back.pressed.connect(func(): show_page("main"))
	row.add_child(back)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(sp)
	var start := Button.new()
	start.text = "Set Sail"
	start.focus_mode = Control.FOCUS_NONE
	start.custom_minimum_size = Vector2(260, 54)
	start.add_theme_font_override("font", f_title)
	start.add_theme_font_size_override("font_size", 24)
	_gold_button(start)
	start.pressed.connect(func(): game.start_game(pick_nation, pick_size, pick_rivals))
	row.add_child(start)
	nation_cards[0].button_pressed = true
	size_btns["standard"].button_pressed = true
	rival_btns[1].button_pressed = true
	setup_panel.visible = false


# One nation: a colonist in the nation's colour, its name and its trait
func _nation_card(i: int, group: ButtonGroup) -> Button:
	var d: Dictionary = game.NATIONS[i]
	var col: Color = d["col"]
	var b := _option_button("", group)
	b.custom_minimum_size = Vector2(214, 262)
	b.tooltip_text = "Play as %s" % d["name"]
	var m := MarginContainer.new()
	m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		m.add_theme_constant_override(side, 12)
	b.add_child(m)
	var v := _vbox(6)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	m.add_child(v)
	var ring := PanelContainer.new()
	ring.add_theme_stylebox_override("panel", _box(Color(col.darkened(0.55), 0.8), col, 2, 60, 4))
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ring.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var pic := TextureRect.new()
	pic.texture = _portrait_col("settler", col)
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pic.custom_minimum_size = Vector2(112, 112)
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ring.add_child(pic)
	v.add_child(ring)
	var nm := _label(d["name"], 25, col.lightened(0.25), f_title)
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(nm)
	var tr := _label(d["desc"], 15, C_TEXT)
	tr.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tr.custom_minimum_size = Vector2(186, 40)
	v.add_child(tr)
	b.pressed.connect(func(): pick_nation = i)
	return b


func _pick_size(key: String) -> void:
	pick_size = key
	pick_rivals = game.MAP_SIZES[key]["ai"]
	rival_btns[pick_rivals - 1].button_pressed = true


func _build_settings() -> void:
	settings_panel = PanelContainer.new()
	settings_panel.add_theme_stylebox_override("panel", _skin("window", 26))
	title_ui.add_child(settings_panel)
	var v := _vbox(14)
	settings_panel.add_child(v)
	v.add_child(_label("Settings", 36, C_BRASS_HI, f_title))
	v.add_child(_divider())
	v.add_child(_section("Display"))
	var row := _hbox(12)
	v.add_child(row)
	var dg := ButtonGroup.new()
	for spec in [["Window", false], ["Fullscreen", true]]:
		var b := _option_button(spec[0], dg)
		b.custom_minimum_size = Vector2(170, 46)
		b.pressed.connect(func():
			game.fullscreen = spec[1]
			game.apply_settings()
			game.save_settings())
		row.add_child(b)
		fs_btns.append(b)
	v.add_child(_section("Interface size"))
	var row2 := _hbox(12)
	v.add_child(row2)
	var ug := ButtonGroup.new()
	for sc in [0.85, 1.0, 1.15]:
		var b := _option_button("%d%%" % roundi(sc * 100), ug)
		b.custom_minimum_size = Vector2(110, 46)
		b.pressed.connect(func():
			game.ui_scale = sc
			game.apply_settings()
			game.save_settings())
		row2.add_child(b)
		scale_btns[sc] = b
	settings_info = _label("", 15, C_DIM)
	settings_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	settings_info.custom_minimum_size = Vector2(560, 0)
	v.add_child(settings_info)
	v.add_child(_divider())
	var back := _button("Back")
	back.custom_minimum_size = Vector2(140, 48)
	back.pressed.connect(func(): show_page("main"))
	v.add_child(back)
	settings_panel.visible = false


func show_page(page: String) -> void:
	title_col.visible = page == "main"
	setup_panel.visible = page == "setup"
	settings_panel.visible = page == "settings"
	if page == "main":
		continue_btn.disabled = not FileAccess.file_exists("user://save_v10.json")
		continue_btn.tooltip_text = "" if not continue_btn.disabled else "No saved game yet (F5 saves during a game)"
	if page == "settings":
		fs_btns[1 if game.fullscreen else 0].button_pressed = true
		var best: float = 1.0
		for sc in scale_btns.keys():
			if absf(sc - game.ui_scale) < absf(best - game.ui_scale):
				best = sc
		scale_btns[best].button_pressed = true
		var win := DisplayServer.window_get_size()
		settings_info.text = "The game is drawn at your screen's full resolution (now %d × %d) and laid out for 1600 × 900, so text and art stay sharp on any monitor.   F11 switches fullscreen at any time." % [win.x, win.y]


func show_menu() -> void:
	close_city_view()
	ui.visible = false
	title_ui.visible = true
	for p in [tech_win, menu_win]:
		p.visible = false
	show_page("main")


func show_game() -> void:
	title_ui.visible = false
	ui.visible = true
	refresh(true)


func _place_title(vp: Vector2) -> void:
	title_col.size = title_col.get_combined_minimum_size()
	title_col.position = Vector2(90, floorf((vp.y - title_col.size.y) * 0.5))
	for p in [setup_panel, settings_panel]:
		if p.visible:
			p.size = p.get_combined_minimum_size()
			p.position = ((vp - p.size) * 0.5).floor()
	footer.size = footer.get_combined_minimum_size()
	footer.position = vp - footer.size - Vector2(16, 12)



# =============================================================
#  City view (Lesson 10f): a full-screen window with the city as
#  a 2.5D diorama in the middle — every building you own stands
#  on the board, the one being built is a scaffold, the rest are
#  empty plots you can click to start building.
# =============================================================
const CV_BUILD_SLOTS := { "granary": Vector2(-0.5, -0.08), "workshop": Vector2(0.52, -0.08),
	"market": Vector2(-0.36, 0.34), "school": Vector2(0.38, 0.36) }
const CV_HALL := Vector2(0, -0.45)
const CV_HOUSES := [Vector2(-0.34, -0.68), Vector2(0.34, -0.68), Vector2(-0.66, -0.4), Vector2(0.68, -0.4),
	Vector2(-0.82, 0.1), Vector2(0.84, 0.1), Vector2(-0.68, 0.5), Vector2(0.7, 0.52), Vector2(-0.3, 0.7), Vector2(0.32, 0.72)]
# view height of each sprite image (must match tools/render_sprites.gd)
const CV_VIEW := { "b_plate": 2.3, "b_townhall": 0.8, "b_granary": 0.8, "b_workshop": 0.8, "b_market": 0.8,
	"b_school": 0.8, "b_scaffold": 0.8, "b_plot": 0.8, "b_house_a": 0.45, "b_house_b": 0.45 }
const CV_PLATE_TOP := 0.1        # height of the board's grass surface
const CV_EFFECT := { "granary": "Stores grain for bad years  ·  10 jobs", "workshop": "+2 production  ·  60 jobs",
	"market": "+3 gold  ·  60 jobs", "school": "+2 research  ·  20 jobs" }

var cv: Control
var cv_frame: PanelContainer
var cv_swatch: ColorRect
var cv_title: Label
var cv_stats: HBoxContainer
var cv_bars: HBoxContainer      # food and production bars under the name
var cv_bottom: HBoxContainer    # current production + the build grid
var cv_left: VBoxContainer
var cv_right: VBoxContainer
var cv_scene: Control
var cv_bg: GradientTexture2D
var cv_city := {}
var cv_sig := []
var cv_hover := ""
var cv_objs := []        # picking info from the last drawn frame: [key, rect, kind, item, ground]


func _build_city_view() -> void:
	cv = Control.new()
	cv.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cv.offset_top = 50                      # keep the resource bar visible above it
	cv.mouse_filter = Control.MOUSE_FILTER_STOP
	ui.add_child(cv)
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.02, 0.03, 0.7)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cv.add_child(dim)
	cv_frame = PanelContainer.new()
	cv_frame.add_theme_stylebox_override("panel", _skin("window", 18))
	cv.add_child(cv_frame)
	cv_frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cv_frame.offset_left = 22
	cv_frame.offset_top = 14
	cv_frame.offset_right = -22
	cv_frame.offset_bottom = -18
	var v := _vbox(8)
	cv_frame.add_child(v)
	# header (4X city-screen style): ◀  NAME  ▶ centred, close on the right
	var head := _hbox(12)
	v.add_child(head)
	cv_swatch = ColorRect.new()
	cv_swatch.custom_minimum_size = Vector2(8, 40)
	cv_swatch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(cv_swatch)
	cv_stats = _hbox(18)
	cv_stats.custom_minimum_size = Vector2(420, 0)
	head.add_child(cv_stats)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(sp)
	var prev := _button("<", 0, "", "Previous city")
	prev.add_theme_font_override("font", f_title)
	prev.add_theme_font_size_override("font_size", 26)
	prev.custom_minimum_size = Vector2(44, 40)
	prev.pressed.connect(func(): _cycle_city(-1))
	head.add_child(prev)
	cv_title = _label("", 38, C_BRASS_HI, f_title)
	cv_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cv_title.custom_minimum_size = Vector2(380, 0)
	head.add_child(cv_title)
	var nxt := _button(">", 0, "", "Next city")
	nxt.add_theme_font_override("font", f_title)
	nxt.add_theme_font_size_override("font_size", 26)
	nxt.custom_minimum_size = Vector2(44, 40)
	nxt.pressed.connect(func(): _cycle_city(1))
	head.add_child(nxt)
	var sp2 := Control.new()
	sp2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sp2.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(sp2)
	var close := _button("Close  [Esc]")
	var close_box := HBoxContainer.new()
	close_box.alignment = BoxContainer.ALIGNMENT_END
	close_box.custom_minimum_size = Vector2(420 + 20, 0)
	close.custom_minimum_size = Vector2(140, 40)
	close.pressed.connect(close_city_view)
	close_box.add_child(close)
	head.add_child(close_box)
	# the two big bars: food and production
	cv_bars = _hbox(16)
	v.add_child(cv_bars)
	v.add_child(_divider())
	# body: info | diorama | buildings
	var body := _hbox(16)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(body)
	var lscroll := ScrollContainer.new()
	lscroll.custom_minimum_size = Vector2(350, 0)
	lscroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(lscroll)
	cv_left = _vbox(10)
	cv_left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lscroll.add_child(cv_left)
	cv_scene = Control.new()
	cv_scene.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cv_scene.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cv_scene.mouse_filter = Control.MOUSE_FILTER_STOP
	cv_scene.clip_contents = true
	cv_scene.draw.connect(_draw_city_scene)
	cv_scene.gui_input.connect(_city_scene_input)
	cv_scene.mouse_exited.connect(func():
		cv_hover = ""
		cv_scene.queue_redraw())
	body.add_child(cv_scene)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(330, 0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	cv_right = _vbox(8)
	cv_right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(cv_right)
	# bottom strip: what is being built + everything that can be built
	v.add_child(_divider())
	cv_bottom = _hbox(14)
	v.add_child(cv_bottom)
	# soft light behind the board
	var g := Gradient.new()
	g.set_color(0, Color(0.24, 0.32, 0.4, 0.85))
	g.set_color(1, Color(0.04, 0.06, 0.09, 0.0))
	cv_bg = GradientTexture2D.new()
	cv_bg.gradient = g
	cv_bg.fill = GradientTexture2D.FILL_RADIAL
	cv_bg.fill_from = Vector2(0.5, 0.45)
	cv_bg.fill_to = Vector2(1.05, 0.45)
	cv.visible = false


func open_city_view() -> void:
	var c: Dictionary = game.selected_city
	if c.is_empty() or c["owner"] != 0:
		return
	for p in [tech_win, menu_win]:
		p.visible = false
	cv.visible = true
	cv_sig = []
	cv_hover = ""
	refresh(true)


func close_city_view() -> void:
	if cv != null:
		cv.visible = false


func _cycle_city(step: int) -> void:
	var mine: Array = game.cities.filter(func(c): return c["owner"] == 0)
	if mine.is_empty():
		return
	var i: int = 0
	for k in mine.size():
		if mine[k]["id"] == cv_city.get("id", -1):
			i = k
	game._select(mine[(i + step + mine.size()) % mine.size()])
	game._center_on(game.selected_city["cell"])
	game.queue_redraw()
	cv_hover = ""
	refresh(true)


func _update_city_view(force: bool) -> void:
	if cv == null or not cv.visible:
		return
	var c: Dictionary = game.selected_city
	if c.is_empty() or c["owner"] != 0:
		close_city_view()
		return
	cv_city = c
	var sig := [c["id"], c["build"], c["prod"], c["grain"], c["pop"], c["blds"].size(), c["radius"], game.me()["gold"], game.turn]
	if force or sig != cv_sig:
		cv_sig = sig
		_rebuild_city_view()
	cv_scene.queue_redraw()


# One growth limit: green = fine, yellow = tight, red = blocking growth
func _limit(icon_name: String, title: String, ok: bool, warn: bool, detail: String) -> Control:
	var col := C_GOOD if ok else (Color(0.95, 0.8, 0.3) if warn else C_BAD)
	var st := _stat(icon_name, title, col, 15)
	st.tooltip_text = "%s: %s" % [title, detail]
	st.mouse_filter = Control.MOUSE_FILTER_PASS
	return st


func _building_thumb(sname: String) -> Texture2D:
	var tex: Texture2D = game._sprite_tex(sname, game.ncol(0))
	if tex == null:
		return null
	var at := AtlasTexture.new()
	at.atlas = tex
	var w := tex.get_width()
	at.region = Rect2(w * 0.14, w * 0.3, w * 0.72, w * 0.62)
	return at


func _thumb(key: String) -> Texture2D:
	if game.UNITS.has(key):
		return _portrait(key, 0)
	return _building_thumb("b_" + key)


func _section_title(parent: Control, text: String) -> void:
	parent.add_child(_label(text, 20, C_BRASS_HI, f_title))


func _rebuild_city_view() -> void:
	var city := cv_city
	var y: Dictionary = game.city_yield(city)
	var blds: Array = city["blds"]
	cv_swatch.color = game.ncol(0)
	cv_title.text = city["name"]
	_clear(cv_stats)
	cv_stats.add_child(_stat("population", "%s people" % game.fmt_int(city["pop"]), C_TEXT, 18))
	cv_stats.add_child(_stat("culture", "Borders %d" % city["radius"], C_DIM, 18))
	cv_stats.add_child(_stat("city", "%d building%s" % [blds.size(), "" if blds.size() == 1 else "s"], C_DIM, 18))
	# ---- the big bars
	_clear(cv_bars)
	var fb := _hbox(8)
	fb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fb.add_child(_icon("food", 28))
	var food_bar := _bar(C_FOOD if y["cov"] >= 1.0 else C_BAD, y["cov"] * 100.0, 100, _food_text(y))
	food_bar.custom_minimum_size = Vector2(0, 28)
	fb.add_child(food_bar)
	cv_bars.add_child(fb)
	var pbx := _hbox(8)
	pbx.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pbx.add_child(_icon("production", 28))
	var item: String = city["build"]
	var prod_bar: ProgressBar
	if item == "":
		prod_bar = _bar(C_BAD.darkened(0.3), 0, 1, "Nothing is being built — pick something below")
	else:
		var cost: int = game.build_cost(item)
		var turns := _turns(cost - city["prod"], y["p"])
		prod_bar = _bar(C_PROD, city["prod"], cost, "%s   %d / %d   (+%d)   ·   %d turn%s" % [game._item_name(item),
			city["prod"], cost, y["p"], turns, "" if turns == 1 else "s"])
	prod_bar.custom_minimum_size = Vector2(0, 28)
	pbx.add_child(prod_bar)
	cv_bars.add_child(pbx)
	# ---- left: growth, production, yields, citizens
	_clear(cv_left)
	_section_title(cv_left, "People")
	var ls: float = y["ls"]
	var why := "income %d ÷ cost of living %d pesos" % [int(y["income"]), int(y["subsist"])]
	if y["cov"] < 1.0: why += ", hunger"
	if y["crowd"] > 0.0: why += ", − %.2f overcrowding" % y["crowd"]
	var lsl := _label("Standard of living %.2f — %s   (%s)" % [ls, _ls_word(ls), why], 15, _ls_col(ls))
	lsl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cv_left.add_child(lsl)
	var r: Dictionary = city.get("last", {})
	if not r.is_empty():
		var txt := "Last turn %+.1f%%:  +%s born  ·  −%s died  ·  +%s arrived  ·  −%s left" % [r["pct"],
			game.fmt_int(r["births"]), game.fmt_int(r["deaths"]), game.fmt_int(r["imm"]), game.fmt_int(r["emi"])]
		if r["plague"] > 0:
			txt += "  ·  plague −%s" % game.fmt_int(r["plague"])
		cv_left.add_child(_label(txt, 14, C_GOOD if r["change"] >= 0 else C_BAD))
	# the four limits on growth: food, jobs, housing, health
	var lim := _hbox(14)
	var pop := float(city["pop"])
	var hr: float = pop / float(y["housing"])
	var unemp: float = y["unemp"]
	lim.add_child(_limit("food", "Food", y["cov"] >= 1.0, y["cov"] >= 0.9, "%d%% fed" % int(y["cov"] * 100)))
	lim.add_child(_limit("production", "Jobs", unemp < 0.05, unemp < 0.15, "%d%% idle" % int(unemp * 100)))
	lim.add_child(_limit("city", "Housing", hr < 0.9, hr <= 1.0, "%s / %s" % [game.fmt_int(pop), game.fmt_int(y["housing"])]))
	var vac: bool = game.me()["tech"]["vaccines"]
	lim.add_child(_limit("research", "Health", vac or pop < 3000, pop < 8000, "plague %.1f%%/yr" % (200.0 * sqrt(pop / 5000.0) * (0.25 if vac else 1.0))))
	cv_left.add_child(lim)
	cv_left.add_child(_divider())
	_section_title(cv_left, "Yields per turn")
	var bp := 2 if "workshop" in blds else 0
	var bg := 3 if "market" in blds else 0
	var bs := 2 if "school" in blds else 0
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 4)
	cv_left.add_child(grid)
	var crops := []
	for k in y["crops"].keys():
		crops.append("%s %s" % [game.Econ.CROPS[k]["name"], game.fmt_int(y["crops"][k])])
	for row in [["food", "%s t" % game.fmt_int(y["food"]), "a year: %s  ·  eaten %s t" % [", ".join(crops) if not crops.is_empty() else "nothing",
				game.fmt_int(y["need"])], C_GOOD if y["cov"] >= 1.0 else C_BAD],
			["production", "+%d" % y["p"], "town 1 + workers %d + buildings %d" % [y["p_land"], bp], C_TEXT],
			["gold", "+%d" % y["g"], "taxes %d + other %d + buildings %d" % [y["tax"], y["g"] - y["tax"] - bg, bg], C_TEXT],
			["research", "+%d" % y["sci"], "people %d + school %d" % [y["sci"] - bs, bs], C_TEXT]]:
		grid.add_child(_icon(row[0], 22))
		grid.add_child(_label(row[1], 18, row[3], f_bold))
		grid.add_child(_label(row[2], 14, C_DIM))
	cv_left.add_child(_divider())
	_section_title(cv_left, "Work")
	var people := HFlowContainer.new()
	people.add_theme_constant_override("h_separation", 2)
	people.add_theme_constant_override("v_separation", 2)
	for i in clampi(ceili(float(city["pop"]) / 500.0), 1, 24):
		people.add_child(_icon("population", 22))
	cv_left.add_child(people)
	cv_left.add_child(_label("Workers %s of %s people  (one figure ≈ 500)" % [game.fmt_int(y["labor"]), game.fmt_int(city["pop"])], 14, C_DIM))
	var wg := GridContainer.new()
	wg.columns = 2
	wg.add_theme_constant_override("h_separation", 16)
	cv_left.add_child(wg)
	for row in [["Farmers", y["farmers"]], ["Fishers", y["fishers"]], ["Woodcutters & miners", y["prod_workers"]],
			["Trades & services", y["jobs"]], ["Idle", y["idle"]]]:
		wg.add_child(_label(row[0], 14, C_BAD if row[0] == "Idle" and row[1] > 1.0 else C_TEXT))
		wg.add_child(_label(game.fmt_int(row[1]), 14, C_TEXT, f_bold))
	var owned := 0
	for h in game.territory.keys():
		if game.territory[h] == city["id"]:
			owned += 1
	cv_left.add_child(_label("%d of %d hexes inside the borders are worked" % [y["worked"].size(), owned], 14, C_DIM))
	# ---- right: owned buildings, construction list, units
	_clear(cv_right)
	_section_title(cv_right, "Buildings")
	if blds.is_empty():
		cv_right.add_child(_label("No buildings yet — only the town hall and houses.", 15, C_DIM))
	for b in blds:
		var row := PanelContainer.new()
		row.add_theme_stylebox_override("panel", _skin("card", 7))
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var hb := _hbox(10)
		row.add_child(hb)
		var t := TextureRect.new()
		t.texture = _building_thumb("b_" + b)
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		t.custom_minimum_size = Vector2(64, 54)
		hb.add_child(t)
		var tv := _vbox(2)
		tv.add_child(_label(game._item_name(b), 18, C_TEXT, f_title))
		tv.add_child(_label(CV_EFFECT.get(b, ""), 15, C_GOOD))
		hb.add_child(tv)
		cv_right.add_child(row)
	# ---- bottom: current production (with Buy) and the build grid
	_clear(cv_bottom)
	var cur := PanelContainer.new()
	cur.add_theme_stylebox_override("panel", _skin("inset", 8))
	cur.custom_minimum_size = Vector2(330, 0)
	cv_bottom.add_child(cur)
	var ch := _hbox(10)
	cur.add_child(ch)
	var pic := TextureRect.new()
	pic.texture = _thumb(item) if item != "" else null
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pic.custom_minimum_size = Vector2(76, 76)
	pic.visible = item != ""
	ch.add_child(pic)
	var cvb := _vbox(4)
	cvb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ch.add_child(cvb)
	cvb.add_child(_label("Building" if item != "" else "Idle!", 14, C_DIM))
	cvb.add_child(_label(game._item_name(item) if item != "" else "Nothing", 22, C_TEXT if item != "" else C_BAD, f_title))
	if item != "":
		var cost_g: int = maxi(0, (game.build_cost(item) - int(city["prod"])) * 2)
		var buy := _button("Buy  %d gold   [G]" % cost_g, KEY_G, "gold")
		if cost_g > game.me()["gold"]:
			buy.disabled = true
			buy.tooltip_text = "Not enough gold"
		elif not game._can_complete(city, item):
			buy.disabled = true
			buy.tooltip_text = game.complete_problem(city, item)
		cvb.add_child(buy)
	var bgrid := HBoxContainer.new()
	bgrid.add_theme_constant_override("separation", 8)
	bgrid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bgrid.alignment = BoxContainer.ALIGNMENT_CENTER
	cv_bottom.add_child(bgrid)
	for i in game.BUILD_ORDER.size():
		var key: String = game.BUILD_ORDER[i]
		if not (key in blds):
			bgrid.add_child(_build_tile(city, key, i, y))


# A square build button with a picture (the city screen's build grid)
func _build_tile(city: Dictionary, key: String, i: int, y: Dictionary) -> Button:
	var cost: int = game.build_cost(key)
	var turns := _turns(cost - city["prod"], y["p"])
	var desc: String = CV_EFFECT.get(key, "")
	if game.UNITS.has(key):
		desc = {"settler": "Founds a new city with 150 people", "worker": "Builds farms, mines, roads",
			"scout": "Explores; better village gifts", "guard": "Protects a city"}.get(key, "")
		if key != "settler":
			desc += "  ·  %d people" % game.UNITS[key]["people"]
		var why: String = game.complete_problem(city, key)
		if why != "":
			desc += "\n" + why
	var b := _button("%s\n%d · %dt" % [game._item_name(key), cost, turns], KEY_1 + i)
	b.icon = _thumb(key)
	b.expand_icon = true
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	b.custom_minimum_size = Vector2(106, 112)
	b.add_theme_constant_override("icon_max_width", 70)
	b.add_theme_font_size_override("font_size", 14)
	b.tooltip_text = "[%d]  %s — %d production, %d turn%s\n%s" % [i + 1, game._item_name(key), cost, turns, "" if turns == 1 else "s", desc]
	if key == city["build"]:
		b.add_theme_stylebox_override("normal", _skin("button_on", 7))
		b.add_theme_stylebox_override("hover", _skin("button_on", 7))
	return b


# ---- the diorama ----
func _cv_sprite(sname: String, ground: Vector2, r: float, anchor := 0.84, modulate := Color(1, 1, 1)) -> float:
	var tex: Texture2D = game._sprite_tex(sname, game.ncol(0))
	if tex == null:
		return 0.0
	var size: float = CV_VIEW[sname] * r
	cv_scene.draw_texture_rect(tex, Rect2(ground.x - size * 0.5, ground.y - size * anchor, size, size), false, modulate)
	return size


func _cv_ellipse(c: Vector2, rx: float, ry: float, col: Color) -> void:
	cv_scene.draw_set_transform(c, 0.0, Vector2(1.0, ry / rx))
	cv_scene.draw_circle(Vector2.ZERO, rx, col)
	cv_scene.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_city_scene() -> void:
	if cv_city.is_empty():
		return
	var sz := cv_scene.size
	cv_scene.draw_texture_rect(cv_bg, Rect2(Vector2.ZERO, sz), false)
	var r := minf(sz.x / 2.3, sz.y / 1.45)
	var p := Vector2(sz.x * 0.5, sz.y * 0.5 + r * 0.02)
	var tilt: float = game.TILT
	var lift := Vector2(0, -CV_PLATE_TOP * game.RISE * r)
	_cv_ellipse(p + Vector2(r * 0.04, r * 0.62), r * 1.05, r * 0.2, Color(0, 0, 0, 0.35))
	_cv_sprite("b_plate", p, r, 0.5)
	# everything standing on the board, sorted back to front
	var city := cv_city
	var blds: Array = city["blds"]
	var objs := [[CV_HALL, "hall", "b_townhall", "hall", ""]]
	for b in CV_BUILD_SLOTS.keys():
		var kind: String = "built" if b in blds else ("site" if city["build"] == b else "plot")
		var spr: String = "b_" + b if kind == "built" else ("b_scaffold" if kind == "site" else "b_plot")
		objs.append([CV_BUILD_SLOTS[b], b, spr, kind, b])
	for i in clampi(ceili(float(city["pop"]) / 500.0), 1, CV_HOUSES.size()):
		objs.append([CV_HOUSES[i], "house%d" % i, "b_house_a" if i % 3 != 1 else "b_house_b", "house", ""])
	objs.sort_custom(func(a, b): return a[0].y < b[0].y)
	cv_objs.clear()
	for o in objs:
		var pos: Vector2 = o[0]
		var g := p + Vector2(pos.x * r, pos.y * tilt * r) + lift
		var hov: bool = o[1] == cv_hover
		var mod := Color(1.15, 1.13, 1.08) if hov else Color(1, 1, 1)
		if o[3] == "plot":
			mod = Color(1, 1, 1, 1.0 if hov else 0.75)
		_cv_sprite(o[2], g, r, 0.84, mod)
		var small: bool = o[3] == "house"
		var fw := r * (0.2 if small else 0.34)
		var fh := r * (0.22 if small else 0.4)
		if o[3] == "plot":
			fh = r * 0.16
		cv_objs.append([o[1], Rect2(g.x - fw * 0.5, g.y - fh, fw, fh + r * 0.06), o[3], o[4], g])
	# markers: "+" over empty plots, a progress bar over the construction site
	var font := f_bold
	for info in cv_objs:
		var g: Vector2 = info[4]
		if info[2] == "plot":
			var m := g + Vector2(0, -r * 0.07)
			cv_scene.draw_circle(m, r * 0.045, Color(0.1, 0.08, 0.06, 0.85))
			cv_scene.draw_arc(m, r * 0.045, 0, TAU, 20, C_BRASS_HI, 2.0)
			cv_scene.draw_line(m + Vector2(-r * 0.022, 0), m + Vector2(r * 0.022, 0), C_BRASS_HI, 3.0)
			cv_scene.draw_line(m + Vector2(0, -r * 0.022), m + Vector2(0, r * 0.022), C_BRASS_HI, 3.0)
		elif info[2] == "site":
			var cost: int = game.build_cost(info[3])
			var frac := clampf(float(city["prod"]) / float(cost), 0.0, 1.0)
			var bw := r * 0.26
			var bp := g + Vector2(-bw * 0.5, -r * 0.27)
			cv_scene.draw_rect(Rect2(bp - Vector2(2, 2), Vector2(bw + 4, 12)), Color(0, 0, 0, 0.7))
			cv_scene.draw_rect(Rect2(bp, Vector2(bw * frac, 8)), C_PROD)
	# hover label
	for info in cv_objs:
		if info[0] != cv_hover:
			continue
		var title := ""
		var sub := ""
		match info[2]:
			"hall":
				title = "Town Hall"
				sub = "The heart of %s" % city["name"]
			"house":
				title = "Houses"
				sub = "Home to %s people (room for %s)" % [game.fmt_int(city["pop"]), game.fmt_int(game.city_yield(city)["housing"])]
			"built":
				title = game._item_name(info[3])
				sub = CV_EFFECT.get(info[3], "")
			"site":
				var y: Dictionary = game.city_yield(city)
				var left := maxi(0, game.build_cost(info[3]) - int(city["prod"]))
				title = "Building: %s" % game._item_name(info[3])
				sub = "%d turn%s left" % [_turns(left, y["p"]), "" if _turns(left, y["p"]) == 1 else "s"]
			"plot":
				var y2: Dictionary = game.city_yield(city)
				var cost2: int = game.build_cost(info[3])
				title = "Build %s" % game._item_name(info[3])
				sub = "%s  ·  %d production  ·  %d turns  —  click" % [CV_EFFECT.get(info[3], ""), cost2,
					_turns(cost2 - city["prod"], y2["p"])]
		var g2: Vector2 = info[4]
		var tw := maxf(font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x, font.get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x) + 24
		var box := Rect2(g2.x - tw * 0.5, g2.y - r * 0.5 - 58, tw, 54)
		box.position.x = clampf(box.position.x, 4, sz.x - tw - 4)
		cv_scene.draw_style_box(_skin("tooltip", 0), box)
		cv_scene.draw_string(f_title, box.position + Vector2(12, 24), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, C_BRASS_HI)
		cv_scene.draw_string(font, box.position + Vector2(12, 45), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, C_TEXT)


func _city_scene_input(ev: InputEvent) -> void:
	if ev is InputEventMouseMotion:
		var hit := ""
		for i in range(cv_objs.size() - 1, -1, -1):     # front-most first
			if (cv_objs[i][1] as Rect2).has_point(ev.position):
				hit = cv_objs[i][0]
				break
		if hit != cv_hover:
			cv_hover = hit
			cv_scene.queue_redraw()
	elif ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		for info in cv_objs:
			if info[0] == cv_hover and info[2] == "plot":
				_press(KEY_1 + game.BUILD_ORDER.find(info[3]))
				return
