extends SceneTree
# =============================================================
#  Colony Empire — 2.5D sprite renderer (Lesson 10c)
#  Builds every unit / map prop from simple 3D shapes, then
#  photographs it with the same tilted camera the map uses
#  (sin(pitch) = 0.6 = TILT in main.gd) -> "pre-rendered" sprites.
#
#  Run (from the godot_starter folder, needs a normal window/GPU):
#     godot --path . -s res://tools/render_sprites.gd
#  Output: res://assets/sprites/<name>.png  (+ <name>_team.png =
#  white where the nation / tribe colour is applied in the game)
# =============================================================

const PITCH := 36.87          # camera elevation in degrees
const ANCHOR_Y := 0.84        # the model's ground origin lands at 84% of the image height
const SS := 4                 # render 4x bigger, then shrink = smooth edges
const OUT_DIR := "res://assets/sprites/"
const OUTLINE := Color(0.13, 0.1, 0.09)

# name: [builder, view height in world units (1 unit = hex radius), output px, yaw]
var JOBS := {
	"settler":  ["_colonist", 3.0, 160, 22.0],
	"scout":    ["_scout",    3.0, 160, 22.0],
	"guard":    ["_guard",    3.0, 160, 22.0],
	"worker":   ["_worker",   3.0, 160, 22.0],
	"tree_pine": ["_tree_pine", 1.3, 96, 0.0],
	"tree_leaf": ["_tree_leaf", 1.3, 96, 0.0],
	"hill":     ["_hill",     2.2, 160, 0.0],
	"mountain": ["_mountain", 2.6, 192, 0.0],
	"city":     ["_city",     2.4, 192, 0.0],
	"village":  ["_village",  2.2, 160, 0.0],
}

# Palette (sRGB)
const SKIN := Color(0.96, 0.78, 0.63)
const HAIR := Color(0.40, 0.25, 0.14)
const FELT := Color(0.43, 0.30, 0.19)
const FELT_DARK := Color(0.28, 0.19, 0.12)
const LEATHER := Color(0.56, 0.36, 0.20)
const PANTS := Color(0.30, 0.27, 0.24)
const BUFF := Color(0.82, 0.72, 0.52)
const BOOT := Color(0.20, 0.15, 0.12)
const CREAM := Color(0.95, 0.91, 0.80)
const METAL := Color(0.80, 0.83, 0.87)
const BRASS := Color(0.88, 0.66, 0.24)
const WOOD := Color(0.55, 0.37, 0.21)
const STRAW := Color(0.92, 0.80, 0.46)
const EYE := Color(0.08, 0.06, 0.05)
const TEAM := Color(0.88, 0.88, 0.88)     # grey, multiplied by the nation colour in-game

var vp: SubViewport
var cam: Camera3D
var model: Node3D


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	vp = SubViewport.new()
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.msaa_3d = Viewport.MSAA_4X
	root.add_child(vp)
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.85, 0.88, 1.0)
	env.ambient_light_energy = 0.32
	var we := WorldEnvironment.new()
	we.environment = env
	vp.add_child(we)
	var sun := DirectionalLight3D.new()      # key light from the upper left
	sun.rotation_degrees = Vector3(-52, -38, 0)
	sun.light_energy = 0.8
	sun.light_color = Color(1.0, 0.96, 0.88)
	sun.shadow_enabled = true
	vp.add_child(sun)
	var fill := DirectionalLight3D.new()     # soft cool fill from the right
	fill.rotation_degrees = Vector3(-15, 120, 0)
	fill.light_energy = 0.18
	fill.light_color = Color(0.8, 0.88, 1.0)
	vp.add_child(fill)
	cam = Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	vp.add_child(cam)
	model = Node3D.new()
	vp.add_child(model)
	var only := OS.get_cmdline_user_args()      # optional: -- settler scout  (render just these)
	for sprite_name in JOBS.keys():
		if only.is_empty() or sprite_name in only:
			await _render(sprite_name)
	print("Sprites written to ", OUT_DIR)
	quit()


# ---------------------------------------------------------------- rendering
func _frames(n: int) -> void:
	for i in n:
		await RenderingServer.frame_post_draw


func _render(sprite_name: String) -> void:
	var job: Array = JOBS[sprite_name]
	for ch in model.get_children():
		ch.free()
	model.rotation_degrees = Vector3(0, job[3], 0)
	call(job[0])
	var view: float = job[1]
	var px: int = job[2]
	vp.size = Vector2i(px * SS, px * SS)
	cam.size = view
	var th := deg_to_rad(PITCH)
	var up := Vector3(0, cos(th), -sin(th))
	var fwd := Vector3(0, -sin(th), -cos(th))
	var look := up * ((ANCHOR_Y - 0.5) * view)
	cam.look_at_from_position(look - fwd * 30.0, look, Vector3.UP)
	await _frames(3)
	var img := vp.get_texture().get_image()
	_finish(img, px, true).save_png(OUT_DIR + sprite_name + ".png")
	if _has_team():
		_mask_mode(true)
		await _frames(3)
		var mask := vp.get_texture().get_image()
		_mask_mode(false)
		_finish_mask(mask, px).save_png(OUT_DIR + sprite_name + "_team.png")
	print("  rendered ", sprite_name)


func _all_parts(n: Node) -> Array:
	var out := []
	for ch in n.get_children():
		if ch is MeshInstance3D:
			out.append(ch)
		out.append_array(_all_parts(ch))
	return out


func _has_team() -> bool:
	for mi in _all_parts(model):
		if mi.get_meta("team", false):
			return true
	return false


func _mask_mode(on: bool) -> void:
	# Team parts -> flat white, everything else -> flat black (so the mask respects occlusion)
	for mi in _all_parts(model):
		if on:
			var m := StandardMaterial3D.new()
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			m.albedo_color = Color.WHITE if mi.get_meta("team", false) else Color.BLACK
			mi.material_override = m
		else:
			mi.material_override = mi.get_meta("mat")


func _finish(img: Image, px: int, outline: bool) -> Image:
	img.convert(Image.FORMAT_RGBA8)
	img.resize(px, px, Image.INTERPOLATE_LANCZOS)
	if not outline:
		return img
	# Dark 1px outline behind the art (dilate the alpha) — keeps sprites readable on any terrain
	var out := Image.create(px, px, false, Image.FORMAT_RGBA8)
	for y in px:
		for x in px:
			var a := 0.0
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					var xx := clampi(x + dx, 0, px - 1)
					var yy := clampi(y + dy, 0, px - 1)
					a = maxf(a, img.get_pixel(xx, yy).a)
			if a > 0.0:
				out.set_pixel(x, y, Color(OUTLINE, minf(1.0, a * 1.3)))
	out.blend_rect(img, Rect2i(0, 0, px, px), Vector2i.ZERO)
	return out


func _finish_mask(img: Image, px: int) -> Image:
	img.convert(Image.FORMAT_RGBA8)
	img.resize(px, px, Image.INTERPOLATE_LANCZOS)
	var out := Image.create(px, px, false, Image.FORMAT_RGBA8)
	for y in px:
		for x in px:
			var c := img.get_pixel(x, y)
			out.set_pixel(x, y, Color(1, 1, 1, clampf(c.r * c.a, 0.0, 1.0)))
	return out


# ---------------------------------------------------------------- building blocks
func mat(col: Color, rough := 0.85, metal := 0.0, glow := false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = rough
	m.metallic = metal
	if glow:
		m.emission_enabled = true
		m.emission = col
		m.emission_energy_multiplier = 1.5
	return m


func add(mesh: Mesh, col, pos: Vector3, rot := Vector3.ZERO, scl := Vector3.ONE, team := false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	var m: StandardMaterial3D = col if col is StandardMaterial3D else mat(TEAM if team else col)
	mi.material_override = m
	mi.set_meta("mat", m)
	mi.set_meta("team", team)
	mi.position = pos
	mi.rotation_degrees = rot
	mi.scale = scl
	model.add_child(mi)
	return mi


func sphere(r: float, seg := 24) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = seg
	s.rings = maxi(4, seg / 2)
	return s


func hemi(r: float, seg := 24) -> SphereMesh:
	var s := sphere(r, seg)
	s.is_hemisphere = true
	s.height = r
	return s


func cyl(top: float, bottom: float, h: float, seg := 24) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = top
	c.bottom_radius = bottom
	c.height = h
	c.radial_segments = seg
	c.rings = 1
	return c


func box(x: float, y: float, z: float) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = Vector3(x, y, z)
	return b


func _orient(mi: MeshInstance3D, a: Vector3, b: Vector3) -> void:
	var y := (b - a).normalized()
	var ref := Vector3.FORWARD if absf(y.dot(Vector3.FORWARD)) < 0.95 else Vector3.RIGHT
	var x := y.cross(ref).normalized()
	mi.basis = Basis(x, y, x.cross(y))
	mi.position = (a + b) * 0.5


func rod(a: Vector3, b: Vector3, r: float, col, team := false, seg := 12) -> MeshInstance3D:
	var mi := add(cyl(r, r, a.distance_to(b), seg), col, Vector3.ZERO, Vector3.ZERO, Vector3.ONE, team)
	_orient(mi, a, b)
	return mi


func limb(a: Vector3, b: Vector3, r: float, col, team := false) -> MeshInstance3D:
	var c := CapsuleMesh.new()
	c.radius = r
	c.height = a.distance_to(b) + r * 2.0
	c.radial_segments = 16
	c.rings = 6
	var mi := add(c, col, Vector3.ZERO, Vector3.ZERO, Vector3.ONE, team)
	_orient(mi, a, b)
	return mi


# ---------------------------------------------------------------- characters
# Chibi proportions, ~2.3 units tall, facing +Z (towards the camera).
func _body(torso_col, torso_team: bool, pants := PANTS, boots := BOOT, tall_boots := false, skirt := 0.35) -> void:
	for sx in [-1.0, 1.0]:
		limb(Vector3(0.13 * sx, 0.62, 0), Vector3(0.14 * sx, 0.2, 0.02), 0.1, pants)
		if tall_boots:
			add(cyl(0.12, 0.12, 0.42, 16), boots, Vector3(0.14 * sx, 0.21, 0.02))
			add(cyl(0.135, 0.135, 0.07, 16), boots, Vector3(0.14 * sx, 0.42, 0.02))
		add(box(0.19, 0.14, 0.3), boots, Vector3(0.14 * sx, 0.07, 0.06))
	var cap := CapsuleMesh.new()
	cap.radius = 0.31
	cap.height = 0.92
	add(cap, torso_col, Vector3(0, 1.0, 0), Vector3.ZERO, Vector3.ONE, torso_team)
	add(cyl(0.31, 0.37, skirt, 24), torso_col, Vector3(0, 0.8 - skirt * 0.5, 0), Vector3.ZERO, Vector3.ONE, torso_team)


func _belt(col := LEATHER, buckle := BRASS) -> void:
	add(cyl(0.318, 0.318, 0.07, 24), col, Vector3(0, 0.82, 0))
	add(box(0.1, 0.09, 0.04), mat(buckle, 0.4, 0.4), Vector3(0, 0.82, 0.31))


func _head(eyes_closed_right := false) -> void:
	add(sphere(0.35), SKIN, Vector3(0, 1.79, 0))
	add(sphere(0.36), HAIR, Vector3(0, 1.84, -0.06))
	for sx in [-1.0, 1.0]:
		if eyes_closed_right and sx > 0:
			add(box(0.09, 0.022, 0.03), EYE, Vector3(0.12 * sx, 1.81, 0.31), Vector3(0, 0, 10))
		else:
			add(sphere(0.048, 12), EYE, Vector3(0.12 * sx, 1.81, 0.3))
		add(sphere(0.05, 10), Color(0.95, 0.62, 0.56), Vector3(0.2 * sx, 1.7, 0.26), Vector3.ZERO, Vector3(1, 0.6, 0.4))
	add(sphere(0.055, 12), SKIN.darkened(0.06), Vector3(0, 1.74, 0.34))


func _hand(p: Vector3) -> void:
	add(sphere(0.1, 16), SKIN, p)


func _colonist() -> void:
	# bedroll on the back
	add(cyl(0.15, 0.15, 0.86, 18), CREAM, Vector3(0, 1.32, -0.33), Vector3(0, 0, 90))
	for sx in [-0.3, 0.3]:
		add(cyl(0.158, 0.158, 0.05, 18), LEATHER, Vector3(sx, 1.32, -0.33), Vector3(0, 0, 90))
	_body(TEAM, true)
	for y in [1.17, 1.02]:
		add(sphere(0.03, 8), mat(BRASS, 0.4, 0.4), Vector3(0.05, y, 0.305))
	_belt()
	# spade in the right hand
	rod(Vector3(-0.55, 0.12, 0.2), Vector3(-0.5, 1.2, 0.18), 0.035, WOOD)
	rod(Vector3(-0.58, 1.2, 0.18), Vector3(-0.42, 1.2, 0.18), 0.03, WOOD)
	add(box(0.24, 0.28, 0.035), mat(METAL, 0.35, 0.3), Vector3(-0.55, 0.12, 0.2))
	limb(Vector3(-0.33, 1.3, 0), Vector3(-0.5, 0.88, 0.16), 0.095, TEAM, true)
	_hand(Vector3(-0.51, 0.84, 0.18))
	limb(Vector3(0.33, 1.3, 0), Vector3(0.45, 0.88, 0.06), 0.095, TEAM, true)
	_hand(Vector3(0.46, 0.84, 0.07))
	_head()
	# wide-brim felt hat with a buckle
	add(cyl(0.56, 0.56, 0.045, 32), FELT, Vector3(0, 2.02, 0))
	add(cyl(0.27, 0.3, 0.34, 28), FELT, Vector3(0, 2.2, 0))
	add(cyl(0.305, 0.305, 0.08, 28), FELT_DARK, Vector3(0, 2.09, 0))
	add(box(0.1, 0.08, 0.02), mat(BRASS, 0.4, 0.4), Vector3(0, 2.09, 0.305))


func _scout() -> void:
	# team cloak behind the body
	add(cyl(0.33, 0.55, 1.0, 24), TEAM, Vector3(0, 0.88, -0.1), Vector3(-6, 0, 0), Vector3(1, 1, 0.7), true)
	_body(LEATHER, false, BUFF, LEATHER.darkened(0.3), true, 0.5)
	add(sphere(0.15, 16), TEAM, Vector3(0, 1.38, 0.2), Vector3.ZERO, Vector3(1.3, 0.8, 0.7), true)   # neckerchief
	# satchel + strap
	rod(Vector3(-0.28, 1.35, 0.2), Vector3(0.3, 0.72, 0.26), 0.03, LEATHER.darkened(0.3))
	add(box(0.26, 0.22, 0.12), WOOD, Vector3(0.34, 0.7, 0.2), Vector3(0, 20, 0))
	_belt(LEATHER.darkened(0.35))
	# left arm hanging, right arm raised holding a spyglass to the eye
	limb(Vector3(-0.33, 1.3, 0), Vector3(-0.45, 0.88, 0.06), 0.095, LEATHER)
	_hand(Vector3(-0.46, 0.84, 0.07))
	limb(Vector3(0.33, 1.3, 0), Vector3(0.3, 1.62, 0.34), 0.095, LEATHER)
	var eye := Vector3(0.12, 1.81, 0.32)
	var dir := Vector3(0.45, 0.28, 0.85).normalized()
	var brass := mat(BRASS, 0.35, 0.45)
	rod(eye, eye + dir * 0.22, 0.05, brass, false, 16)
	rod(eye + dir * 0.22, eye + dir * 0.44, 0.065, brass, false, 16)
	rod(eye + dir * 0.44, eye + dir * 0.66, 0.082, brass, false, 16)
	_hand(eye + dir * 0.3 + Vector3(0, -0.06, 0))
	_head(true)
	# slouch hat with a team feather
	add(sphere(0.58, 32), FELT, Vector3(0, 2.02, 0), Vector3(0, 0, -6), Vector3(1, 0.1, 0.95))
	add(sphere(0.29, 24), FELT, Vector3(0, 2.1, 0), Vector3.ZERO, Vector3(1, 0.8, 1))
	add(cyl(0.285, 0.285, 0.06, 24), FELT_DARK, Vector3(0, 2.07, 0))
	add(sphere(0.1, 16), TEAM, Vector3(-0.34, 2.3, -0.1), Vector3(20, 0, 38), Vector3(0.9, 3.4, 0.35), true)


func _guard() -> void:
	# halberd
	var steel := mat(METAL, 0.3, 0.35)
	rod(Vector3(-0.52, 0.02, 0.16), Vector3(-0.52, 2.55, 0.16), 0.036, WOOD)
	add(cyl(0.0, 0.05, 0.28, 12), steel, Vector3(-0.52, 2.68, 0.16))
	add(box(0.3, 0.34, 0.035), steel, Vector3(-0.7, 2.32, 0.16), Vector3(0, 0, -8))
	add(box(0.14, 0.08, 0.03), steel, Vector3(-0.4, 2.36, 0.16), Vector3(0, 0, 25))
	_body(TEAM, true)
	var plate := CapsuleMesh.new()      # breastplate wrapped around the chest
	plate.radius = 0.34
	plate.height = 0.8
	add(plate, steel, Vector3(0, 1.12, 0.0))
	_belt(LEATHER.darkened(0.3), METAL)
	limb(Vector3(-0.33, 1.3, 0), Vector3(-0.5, 0.98, 0.14), 0.095, TEAM, true)
	_hand(Vector3(-0.52, 0.96, 0.16))
	limb(Vector3(0.33, 1.3, 0), Vector3(0.42, 0.98, 0.2), 0.095, TEAM, true)
	# round shield: team face, steel rim + boss, cream ring
	var sh := Vector3(0.5, 0.98, 0.3)
	add(cyl(0.37, 0.37, 0.06, 32), TEAM, sh, Vector3(90, -25, 0), Vector3.ONE, true)
	var rim := TorusMesh.new()
	rim.inner_radius = 0.34
	rim.outer_radius = 0.4
	add(rim, steel, sh, Vector3(90, -25, 0))
	var ring := TorusMesh.new()
	ring.inner_radius = 0.16
	ring.outer_radius = 0.2
	add(ring, CREAM, sh + Vector3(0.012, 0, 0.03), Vector3(90, -25, 0), Vector3(1, 0.4, 1))
	add(sphere(0.08, 16), steel, sh + Vector3(0.02, 0, 0.05))
	_head()
	# morion helmet with a team plume
	add(hemi(0.37, 28), steel, Vector3(0, 1.96, 0))
	add(sphere(0.37, 32), steel, Vector3(0, 1.97, 0), Vector3.ZERO, Vector3(1.45, 0.14, 1.25))
	add(box(0.035, 0.16, 0.5), steel, Vector3(0, 2.34, 0), Vector3(0, 0, 0))
	add(sphere(0.12, 16), TEAM, Vector3(0.0, 2.44, -0.2), Vector3(-35, 0, 0), Vector3(0.7, 1.4, 2.0), true)


func _worker() -> void:
	_body(TEAM, true, PANTS, BOOT, false, 0.2)
	_belt()
	# pickaxe resting on the left shoulder (handle + a pointed steel head across the top)
	var steel := mat(METAL, 0.35, 0.3)
	var grip := Vector3(0.5, 0.92, 0.16)
	var top := Vector3(0.78, 1.74, -0.04)
	rod(grip + (grip - top) * 0.15, top, 0.035, WOOD)
	var across := Vector3(0.95, -0.32, 0).normalized()
	rod(top - across * 0.36, top + across * 0.36, 0.045, steel, false, 10)
	limb(Vector3(-0.33, 1.3, 0), Vector3(-0.45, 0.88, 0.06), 0.095, CREAM)
	_hand(Vector3(-0.46, 0.84, 0.07))
	limb(Vector3(0.33, 1.3, 0), grip + Vector3(-0.02, 0.03, -0.02), 0.095, CREAM)
	_hand(grip)
	_head()
	# straw hat
	add(cyl(0.12, 0.56, 0.2, 32), STRAW, Vector3(0, 2.07, 0))
	add(cyl(0.2, 0.26, 0.16, 24), STRAW.darkened(0.08), Vector3(0, 2.2, 0))
	add(cyl(0.27, 0.27, 0.05, 24), Color(0.7, 0.25, 0.2), Vector3(0, 2.12, 0))


# ---------------------------------------------------------------- map props
func _tree_pine() -> void:
	add(cyl(0.05, 0.06, 0.2, 8), WOOD.darkened(0.2), Vector3(0, 0.1, 0))
	var g := Color(0.16, 0.42, 0.22)
	add(cyl(0.0, 0.34, 0.46, 7), g, Vector3(0, 0.4, 0))
	add(cyl(0.0, 0.27, 0.4, 7), g.lightened(0.05), Vector3(0, 0.6, 0))
	add(cyl(0.0, 0.19, 0.34, 7), g.lightened(0.1), Vector3(0, 0.8, 0))


func _tree_leaf() -> void:
	add(cyl(0.05, 0.07, 0.34, 8), WOOD.darkened(0.15), Vector3(0, 0.17, 0))
	var g := Color(0.33, 0.58, 0.24)
	add(sphere(0.27, 10), g, Vector3(0, 0.52, 0))
	add(sphere(0.2, 10), g.lightened(0.08), Vector3(0.15, 0.66, 0.06))
	add(sphere(0.19, 10), g.darkened(0.05), Vector3(-0.16, 0.62, -0.05))


func _hill() -> void:
	var g := Color(0.41, 0.46, 0.27)
	add(hemi(0.62, 9), g, Vector3(0.18, 0, 0.12), Vector3(0, 20, 0), Vector3(1, 0.42, 0.75))
	add(hemi(0.5, 9), g.darkened(0.08), Vector3(-0.34, 0, -0.2), Vector3(0, 50, 0), Vector3(1, 0.55, 0.75))
	add(hemi(0.3, 8), g.lightened(0.05), Vector3(-0.05, 0, 0.5), Vector3.ZERO, Vector3(1, 0.4, 0.8))
	for p in [Vector3(0.1, 0.3, 0.3), Vector3(-0.45, 0.25, 0.05)]:
		add(sphere(0.06, 8), Color(0.55, 0.52, 0.47), p)


func _mountain() -> void:
	var rock := Color(0.55, 0.53, 0.5)
	var snow := Color(0.96, 0.97, 1.0)
	var peaks := [[Vector3(0.1, 0, 0.05), 0.82, 1.45, 7], [Vector3(-0.48, 0, -0.25), 0.55, 0.95, 6], [Vector3(0.5, 0, -0.3), 0.45, 0.7, 6]]
	for pk in peaks:
		var base: Vector3 = pk[0]
		var rr: float = pk[1]
		var hh: float = pk[2]
		add(cyl(0.0, rr, hh, pk[3]), rock.darkened(randf() * 0.08), base + Vector3(0, hh * 0.5, 0), Vector3(0, randf() * 60, 0))
		var sh := hh * 0.34
		add(cyl(0.0, rr * sh / hh * 1.06, sh, pk[3]), snow, base + Vector3(0, hh - sh * 0.5 + 0.01, 0), Vector3(0, randf() * 60, 0))
	for p in [Vector3(0.6, 0.05, 0.4), Vector3(-0.3, 0.05, 0.5), Vector3(0.75, 0.04, 0.05)]:
		add(sphere(0.09, 6), rock.darkened(0.15), p)


func _house(p: Vector3, w: float, d: float, h: float, yaw: float) -> void:
	var walls := add(box(w, h, d), CREAM, p + Vector3(0, h * 0.5, 0), Vector3(0, yaw, 0))
	var roof := PrismMesh.new()
	roof.size = Vector3(w * 1.18, h * 0.85, d * 1.12)
	add(roof, TEAM, p + Vector3(0, h + h * 0.425, 0), Vector3(0, yaw, 0), Vector3.ONE, true)
	var door := add(box(0.08, 0.14, 0.02), WOOD.darkened(0.3), Vector3.ZERO, Vector3(0, yaw, 0))
	door.position = p + walls.basis.z * (d * 0.5 + 0.005) + Vector3(0, 0.07, 0)


func _city() -> void:
	_house(Vector3(-0.42, 0, 0.18), 0.42, 0.34, 0.3, 0)
	_house(Vector3(0.38, 0, 0.26), 0.38, 0.32, 0.28, 90)
	_house(Vector3(-0.1, 0, 0.55), 0.34, 0.3, 0.26, 0)
	_house(Vector3(0.52, 0, -0.28), 0.36, 0.3, 0.28, 0)
	# church tower at the back
	add(box(0.26, 0.7, 0.26), CREAM, Vector3(-0.12, 0.35, -0.35))
	add(cyl(0.0, 0.25, 0.42, 4), TEAM, Vector3(-0.12, 0.91, -0.35), Vector3(0, 45, 0), Vector3.ONE, true)
	add(box(0.08, 0.12, 0.02), WOOD.darkened(0.3), Vector3(-0.12, 0.5, -0.215))
	# low stone wall around it
	for i in 18:
		var a := TAU * i / 18.0
		add(box(0.26, 0.09, 0.07), Color(0.6, 0.58, 0.55), Vector3(cos(a) * 0.88, 0.045, sin(a) * 0.72), Vector3(0, -rad_to_deg(a) + 90, 0))


func _tipi(p: Vector3, s: float) -> void:
	var hide := Color(0.87, 0.75, 0.56)
	add(cyl(0.0, 0.3 * s, 0.78 * s, 14), hide, p + Vector3(0, 0.39 * s, 0))
	# tribe-coloured band around the tipi
	var y0 := 0.2 * s
	var y1 := 0.3 * s
	add(cyl(0.3 * s * (1.0 - y1 / (0.78 * s)) * 1.04, 0.3 * s * (1.0 - y0 / (0.78 * s)) * 1.04, y1 - y0, 14), TEAM,
		p + Vector3(0, (y0 + y1) * 0.5, 0), Vector3.ZERO, Vector3.ONE, true)
	for a in [0.0, 120.0, 240.0]:
		var dirv := Vector3(cos(deg_to_rad(a)), 0, sin(deg_to_rad(a)))
		rod(p + Vector3(0, 0.62 * s, 0), p + Vector3(0, 0.98 * s, 0) + dirv * 0.1 * s, 0.016, WOOD.darkened(0.3))
	add(box(0.1 * s, 0.16 * s, 0.03), Color(0.25, 0.17, 0.1), p + Vector3(0, 0.08 * s, 0.27 * s))


func _village() -> void:
	_tipi(Vector3(-0.42, 0, 0.1), 1.0)
	_tipi(Vector3(0.36, 0, 0.22), 0.95)
	_tipi(Vector3(0.0, 0, -0.38), 1.08)
	add(sphere(0.07, 8), mat(Color(1.0, 0.55, 0.15), 0.9, 0.0, true), Vector3(-0.02, 0.06, 0.42))
	for i in 7:
		var a := TAU * i / 7.0
		add(sphere(0.035, 6), Color(0.5, 0.48, 0.45), Vector3(-0.02 + cos(a) * 0.11, 0.02, 0.42 + sin(a) * 0.08))
