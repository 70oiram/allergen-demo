extends Node2D
## 開發工具：以遊戲實際素材組出教學圖片，輸出到 res://assets/教學/。
## 用法：Godot --path <專案> res://tools/tutorial_render.tscn

const G := preload("res://scripts/game.gd")
const OUT := "res://assets/教學/"
const PANEL_SCALE := 0.448
const PANEL_POS := [Vector2(70, 205), Vector2(990, 205)]
const BG_COLOR := Color(0.11, 0.08, 0.06)
const TEXT_COLOR := Color(1, 0.96, 0.9)
const ACCENT := Color(1, 0.82, 0.4)

var pages := [
	{
		"file": "教學-1-把食物拉到面前.png",
		"title": "①  把食物拉到面前",
		"panels": ["up_drag", "down_eat"],
		"captions": ["抬頭時，按住桌上的盤子往下拖", "盤子來到面前（低頭），拿起叉子就能進食"],
		"tip": "也可以按 W／S、空白鍵或畫面右側的箭頭按鈕，切換抬頭／低頭",
	},
	{
		"file": "教學-2-推開食物或空盤.png",
		"title": "②  推開食物或空盤",
		"panels": ["down_handle", "down_push"],
		"captions": ["低頭時滑鼠靠近盤子左側，出現「我不想吃這個」（空盤時為「下一盤...」）", "按住左鍵往右拖，把盤子推離桌面"],
		"tip": "眼前的盤子沒清掉之前，無法把新的盤子拉到面前",
	},
	{
		"file": "教學-3-用WS切換視角.png",
		"title": "③  用 W／S 切換視角",
		"panels": ["up_key_w", "down_key_s"],
		"captions": ["按 W：抬頭，看廚師做菜", "按 S：低頭，看眼前的盤子"],
		"tip": "空白鍵或畫面右側的箭頭按鈕，也能切換抬頭／低頭",
		"no_mid_arrow": true,
	},
]


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	for page in pages:
		var root := Node2D.new()
		add_child(root)
		_build_page(root, page)
		for i in 8:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		img.convert(Image.FORMAT_RGB8)
		var path: String = OUT + page.file
		print(path, " -> ", img.save_png(ProjectSettings.globalize_path(path)))
		root.queue_free()
		await get_tree().process_frame
	get_tree().quit()


func _build_page(root: Node2D, page: Dictionary) -> void:
	var bg := ColorRect.new()
	bg.color = BG_COLOR
	bg.size = Vector2(1920, 1080)
	root.add_child(bg)
	root.add_child(_label(page.title, 66, ACCENT, Vector2(0, 60), 1920))
	for i in 2:
		var p: Vector2 = PANEL_POS[i]
		var frame := ColorRect.new()
		frame.color = Color(1, 0.9, 0.75, 0.35)
		frame.position = p - Vector2(6, 6)
		frame.size = Vector2(1920, 1080) * PANEL_SCALE + Vector2(12, 12)
		root.add_child(frame)
		var svc := SubViewportContainer.new()
		svc.position = p
		var sv := SubViewport.new()
		sv.size = Vector2i(1920, 1080)
		sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		svc.scale = Vector2.ONE * PANEL_SCALE
		svc.size = Vector2(1920, 1080)
		svc.add_child(sv)
		root.add_child(svc)
		call("_scene_" + page.panels[i], sv)
		root.add_child(_label(page.captions[i], 38, TEXT_COLOR, Vector2(p.x, 720), 1920 * PANEL_SCALE))
	# 兩格之間的箭頭
	if not page.get("no_mid_arrow", false):
		var mid := Annot.new()
		mid.arrows = [[Vector2(936, 447), Vector2(972, 447), 11.0]]
		root.add_child(mid)
	root.add_child(_label(page.tip, 34, Color(TEXT_COLOR, 0.75), Vector2(0, 860), 1920))


func _label(text: String, px: int, color: Color, pos: Vector2, width: float) -> Label:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.size = Vector2(width, 100)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", px)
	l.add_theme_color_override("font_color", color)
	return l


# ───────── 各格場景（1920×1080 座標） ─────────

func _up_base(sv: SubViewport) -> Plate:
	var bg := Sprite2D.new()
	bg.centered = false
	bg.texture = Assets.kitchen(1)
	bg.scale = Vector2.ONE * G.BG_SCALE
	sv.add_child(bg)
	var chef := Chef.new()
	chef.position = G.CHEF_HOME
	sv.add_child(chef)
	chef.set_pose("正面")
	var table := Sprite2D.new()
	table.centered = false
	table.texture = bg.texture
	table.region_enabled = true
	table.region_rect = Rect2(0, G.TABLE_EDGE_SRC, 1672, 941 - G.TABLE_EDGE_SRC)
	table.position = Vector2(0, G.TABLE_EDGE_SRC * G.BG_SCALE)
	table.scale = Vector2.ONE * G.BG_SCALE
	sv.add_child(table)
	var nb := Sprite2D.new()
	nb.texture = Assets.tex(G.NOTEBOOK_TEX)
	nb.scale = Vector2.ONE * (G.NOTEBOOK_WIDTH / nb.texture.get_width())
	nb.position = G.NOTEBOOK_POS
	sv.add_child(nb)
	var plate := Plate.new()
	plate.position = G.PLATE_POS
	sv.add_child(plate)
	_fill(plate)
	return plate


func _down_base(sv: SubViewport, with_fork := true) -> Plate:
	var bg := Sprite2D.new()
	bg.centered = false
	bg.texture = Assets.tex(G.DOWN_BG)
	bg.scale = Vector2.ONE * G.BG_SCALE
	sv.add_child(bg)
	if with_fork:
		var fork := Sprite2D.new()
		fork.texture = Assets.tex("res://assets/互動素材/叉子-桌面用.png")
		fork.scale = Vector2.ONE * G.FORK_SCALE
		fork.position = G.FORK_POS
		sv.add_child(fork)
	var plate := Plate.new()
	plate.width = G.DOWN_PLATE_WIDTH
	plate.position = G.DOWN_PLATE_POS
	sv.add_child(plate)
	_fill(plate)
	return plate


func _fill(plate: Plate) -> void:
	plate.add_item({"type": "雞肉", "visual": "奶油雞肉燉飯", "slot": "上", "is_allergen": false}, 1)
	plate.add_item({"type": "番茄", "visual": "番茄燉蔬菜", "slot": "左", "is_allergen": false}, 1)
	plate.add_item({"type": "馬鈴薯", "visual": "燉牛肉", "slot": "右", "is_allergen": false}, 1)


func _scene_up_drag(sv: SubViewport) -> void:
	var plate := _up_base(sv)
	var a := Annot.new()
	a.arrows = [[Vector2(960, 640), Vector2(960, 1040), 34.0]]
	a.cursors = [Vector2(1080, 840)]
	sv.add_child(a)


func _scene_down_eat(sv: SubViewport) -> void:
	_down_base(sv)
	var a := Annot.new()
	a.cursors = [G.FORK_POS + Vector2(20, 10)]
	a.rings = [[G.FORK_POS, 120.0]]
	sv.add_child(a)


func _scene_down_handle(sv: SubViewport) -> void:
	var plate := _down_base(sv)
	var h := PushHandle.new()
	h.scale = Vector2.ONE * 1.3   # 縮圖中仍看得清楚
	h.position = plate.position + G.PUSH_HANDLE_OFFSET
	sv.add_child(h)
	var a := Annot.new()
	a.cursors = [h.position + Vector2(70, 60)]
	sv.add_child(a)


func _scene_down_push(sv: SubViewport) -> void:
	var plate := _down_base(sv)
	plate.position.x += 260
	plate.rotation = 0.06
	var tip := plate.position + G.PUSH_HANDLE_OFFSET
	var h := PushHandle.new()
	h.position = tip
	sv.add_child(h)
	h.label.visible = false
	var hand := Sprite2D.new()
	hand.centered = false
	hand.texture = Assets.tex(G.HAND_TEX["rest"])
	hand.scale = Vector2.ONE * G.HAND_SCALE
	hand.position = tip - G.HAND_TIP["rest"] * G.HAND_SCALE
	sv.add_child(hand)
	var a := Annot.new()
	a.arrows = [[Vector2(560, 420), Vector2(1260, 420), 34.0]]
	sv.add_child(a)


func _scene_up_key_w(sv: SubViewport) -> void:
	_up_base(sv)
	var a := Annot.new()
	a.keys = [[Vector2(1420, 330), "W"]]
	a.arrows = [[Vector2(1420, 205), Vector2(1420, 60), 30.0]]
	sv.add_child(a)


func _scene_down_key_s(sv: SubViewport) -> void:
	_down_base(sv)
	var a := Annot.new()
	a.keys = [[Vector2(960, 300), "S"]]
	a.arrows = [[Vector2(960, 425), Vector2(960, 540), 30.0]]
	sv.add_child(a)


## 標註：粗箭頭、滑鼠游標、提示圈
class Annot extends Node2D:
	var arrows := []    # [from, to, width]
	var cursors := []   # 游標尖端位置
	var rings := []     # [center, radius]
	var keys := []      # [中心, 字]：鍵帽

	func _draw() -> void:
		for k in keys:
			var r := Rect2(k[0] - Vector2(110, 110), Vector2(220, 220))
			draw_rect(Rect2(r.position + Vector2(0, 16), r.size), Color(0, 0, 0, 0.55))
			draw_rect(r, Color(0.97, 0.94, 0.88))
			draw_rect(r, Color(0.3, 0.2, 0.1), false, 6.0)
			var f := ThemeDB.fallback_font
			var sz := f.get_string_size(k[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 150)
			draw_string(f, k[0] + Vector2(-sz.x * 0.5, 52), k[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 150, Color(0.25, 0.15, 0.06))
		for r in rings:
			draw_arc(r[0], r[1], 0.0, TAU, 64, Color(0, 0, 0, 0.6), 16.0, true)
			draw_arc(r[0], r[1], 0.0, TAU, 64, Color(1, 0.85, 0.4), 8.0, true)
		for ar in arrows:
			_arrow(ar[0], ar[1], ar[2], Color(0, 0, 0, 0.65), 10.0)
			_arrow(ar[0], ar[1], ar[2], Color(1, 0.85, 0.4), 0.0)
		for c in cursors:
			var pts := PackedVector2Array([Vector2(0, 0), Vector2(0, 78), Vector2(19, 61), Vector2(33, 92),
				Vector2(47, 86), Vector2(33, 56), Vector2(57, 56)])
			for i in pts.size():
				pts[i] += c
			draw_colored_polygon(pts, Color.WHITE)
			pts.append(pts[0])
			draw_polyline(pts, Color.BLACK, 5.0, true)

	func _arrow(a: Vector2, b: Vector2, w: float, col: Color, grow: float) -> void:
		var d := (b - a).normalized()
		var n := Vector2(-d.y, d.x)
		var head := w * 2.2 + grow
		var base := b - d * head * 1.1
		draw_line(a - d * grow * 0.5, base, col, w + grow, true)
		draw_colored_polygon(PackedVector2Array([b + d * grow * 0.6, base + n * head, base - n * head]), col)
