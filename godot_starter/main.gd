extends Node2D
# =============================================================
#  Colony Empire — 第二課:資源系統與 UI
#  新增:木材資源、蓋房要花木材、每棟房子持續產出木材、畫面顯示數量
# =============================================================

# --- 可調整的參數 ---
const GRID_W := 20
const GRID_H := 20
const TILE_W := 64.0
const TILE_H := 32.0

# --- 第二課新增:經濟參數 ---
const START_WOOD := 50          # 開局木材
const BUILD_COST := 10          # 蓋一棟房子要花的木材
const REFUND := 5               # 拆房子退回的木材
const WOOD_PER_HOUSE := 1       # 每棟房子每次產出多少木材
const PRODUCE_INTERVAL := 2.0   # 每隔幾秒產一次

var origin := Vector2(512, 120)
var buildings := {}
var hovered := Vector2i(-1, -1)

# --- 第二課新增:遊戲狀態 ---
var wood := START_WOOD          # 目前木材數量
var produce_timer := 0.0        # 累積時間,到達 PRODUCE_INTERVAL 就產出
var message := ""               # 給玩家的提示文字(例如木材不足)
var message_timer := 0.0        # 提示顯示幾秒後消失


func grid_to_screen(col: int, row: int) -> Vector2:
	var x := (col - row) * TILE_W * 0.5
	var y := (col + row) * TILE_H * 0.5
	return origin + Vector2(x, y)


func screen_to_grid(pos: Vector2) -> Vector2i:
	var p := pos - origin
	var fcol := (p.x / (TILE_W * 0.5) + p.y / (TILE_H * 0.5)) * 0.5
	var frow := (p.y / (TILE_H * 0.5) - p.x / (TILE_W * 0.5)) * 0.5
	return Vector2i(floori(fcol), floori(frow))


func _process(delta: float) -> void:
	# 1) 追蹤滑鼠所在格子
	var cell := screen_to_grid(get_global_mouse_position())
	if cell != hovered:
		hovered = cell
		queue_redraw()

	# 2) 房子產出木材(時間累積到一個間隔就結算一次)
	if buildings.size() > 0:
		produce_timer += delta
		if produce_timer >= PRODUCE_INTERVAL:
			produce_timer -= PRODUCE_INTERVAL
			wood += buildings.size() * WOOD_PER_HOUSE
			queue_redraw()

	# 3) 提示訊息倒數消失
	if message_timer > 0.0:
		message_timer -= delta
		if message_timer <= 0.0:
			message = ""
			queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		var cell := screen_to_grid(get_global_mouse_position())
		if not _in_grid(cell):
			return

		if event.button_index == MOUSE_BUTTON_LEFT:
			# 已經有房子就不重蓋
			if buildings.has(cell):
				_show_message("這格已經有建築了")
				return
			# 木材不夠就不能蓋
			if wood < BUILD_COST:
				_show_message("木材不足!需要 %d" % BUILD_COST)
				return
			wood -= BUILD_COST
			buildings[cell] = true

		elif event.button_index == MOUSE_BUTTON_RIGHT:
			if buildings.has(cell):
				buildings.erase(cell)
				wood += REFUND

		queue_redraw()


func _show_message(text: String) -> void:
	message = text
	message_timer = 2.0   # 顯示 2 秒
	queue_redraw()


func _in_grid(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < GRID_W and cell.y >= 0 and cell.y < GRID_H


func _draw() -> void:
	# 地面
	for row in range(GRID_H):
		for col in range(GRID_W):
			var c := Vector2i(col, row)
			var color := Color(0.30, 0.55, 0.30)
			if buildings.has(c):
				color = Color(0.55, 0.40, 0.25)
			if c == hovered and _in_grid(c):
				color = color.lightened(0.35)
			_draw_tile(col, row, color)

	# 建築
	for c in buildings.keys():
		_draw_building(c.x, c.y)

	# --- 第二課新增:畫 UI 文字 ---
	_draw_ui()


# 在畫面左上角用文字顯示遊戲狀態
func _draw_ui() -> void:
	var font := ThemeDB.fallback_font   # 用 Godot 內建字型,免匯入
	# 木材數量
	draw_string(font, Vector2(20, 36), "木材: %d" % wood,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color(1, 1, 1))
	# 操作說明
	draw_string(font, Vector2(20, 66), "左鍵蓋房(花 %d) / 右鍵拆房(退 %d)" % [BUILD_COST, REFUND],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.85, 0.85, 0.85))
	draw_string(font, Vector2(20, 90), "房子數: %d  每 %.0f 秒產 %d 木材/棟" % [buildings.size(), PRODUCE_INTERVAL, WOOD_PER_HOUSE],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.85, 0.85, 0.85))
	# 提示訊息(紅字)
	if message != "":
		draw_string(font, Vector2(20, 124), message,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(1, 0.4, 0.4))


func _draw_tile(col: int, row: int, color: Color) -> void:
	var center := grid_to_screen(col, row)
	var pts := PackedVector2Array([
		center + Vector2(0, -TILE_H * 0.5),
		center + Vector2(TILE_W * 0.5, 0),
		center + Vector2(0, TILE_H * 0.5),
		center + Vector2(-TILE_W * 0.5, 0),
	])
	draw_colored_polygon(pts, color)
	var outline := pts.duplicate()
	outline.append(pts[0])
	draw_polyline(outline, Color(0, 0, 0, 0.25), 1.0)


func _draw_building(col: int, row: int) -> void:
	var base := grid_to_screen(col, row)
	var h := 30.0
	var top := PackedVector2Array([
		base + Vector2(0, -TILE_H * 0.5 - h),
		base + Vector2(TILE_W * 0.4, -h),
		base + Vector2(0, TILE_H * 0.5 - h),
		base + Vector2(-TILE_W * 0.4, -h),
	])
	var left := PackedVector2Array([
		base + Vector2(-TILE_W * 0.4, -h),
		base + Vector2(0, TILE_H * 0.5 - h),
		base + Vector2(0, TILE_H * 0.5),
		base + Vector2(-TILE_W * 0.4, 0),
	])
	var right := PackedVector2Array([
		base + Vector2(TILE_W * 0.4, -h),
		base + Vector2(0, TILE_H * 0.5 - h),
		base + Vector2(0, TILE_H * 0.5),
		base + Vector2(TILE_W * 0.4, 0),
	])
	draw_colored_polygon(left, Color(0.45, 0.30, 0.18))
	draw_colored_polygon(right, Color(0.55, 0.38, 0.22))
	draw_colored_polygon(top, Color(0.70, 0.50, 0.30))
