extends Control
## 主選單：樹影循環背景 +「開始遊戲」「遊戲教學」按鈕。遊戲結束後返回此處（無重新開始選項）。

const FRAME_TIME := 0.15
const TUTORIAL_PAGES := [
	"res://assets/教學/教學-1-把食物拉到面前.png",
	"res://assets/教學/教學-2-推開食物或空盤.png",
]

var _bg: TextureRect
var _frame := 0
var _acc := 0.0
var _fade: ColorRect
var _starting := false
var _tutorial: Control      # 遊戲教學（圖片翻頁）
var _tut_image: TextureRect
var _tut_page_label: Label
var _tut_prev: Button
var _tut_next: Button
var _tut_page := 0


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Engine.time_scale = 1.0

	_bg = TextureRect.new()
	_bg.texture = Assets.menu_frame(0)
	_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bg)

	var shade := ColorRect.new()
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0, 0, 0, 0.18)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)

	var title := Label.new()
	title.text = "過敏原"
	title.add_theme_font_size_override("font_size", 128)
	title.add_theme_color_override("font_color", Color(1, 0.97, 0.92))
	title.add_theme_color_override("font_shadow_color", Color(0.15, 0.07, 0.02, 0.75))
	title.add_theme_constant_override("shadow_offset_x", 4)
	title.add_theme_constant_override("shadow_offset_y", 5)
	title.add_theme_constant_override("shadow_outline_size", 18)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(960 - 400, 230)
	title.size = Vector2(800, 170)
	add_child(title)

	var btn := _button("開始遊戲", 44, Vector2(360, 96), Vector2(960 - 180, 560))
	btn.pressed.connect(_on_start)
	add_child(btn)
	var tut_btn := _button("遊戲教學", 38, Vector2(300, 80), Vector2(960 - 150, 690))
	tut_btn.pressed.connect(_open_tutorial)
	add_child(tut_btn)

	_build_tutorial()

	_fade = ColorRect.new()
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.color = Color(0, 0, 0, 1)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fade)
	create_tween().tween_property(_fade, "color:a", 0.0, 0.8)

	if "--shot" in OS.get_cmdline_user_args():
		_debug_shot()


func _button(text: String, font_px: int, size: Vector2, pos: Vector2) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.add_theme_font_size_override("font_size", font_px)
	btn.size = size
	btn.position = pos
	btn.add_theme_color_override("font_color", Color(0.25, 0.14, 0.06))
	btn.add_theme_color_override("font_hover_color", Color(0.1, 0.05, 0.0))
	btn.add_theme_color_override("font_pressed_color", Color(0.1, 0.05, 0.0))
	btn.add_theme_color_override("font_disabled_color", Color(0.25, 0.14, 0.06, 0.35))
	btn.add_theme_stylebox_override("normal", _box(Color(1, 0.96, 0.88, 0.82)))
	btn.add_theme_stylebox_override("hover", _box(Color(1, 0.92, 0.78, 0.95)))
	btn.add_theme_stylebox_override("pressed", _box(Color(0.95, 0.85, 0.7, 1.0)))
	btn.add_theme_stylebox_override("disabled", _box(Color(1, 0.96, 0.88, 0.4)))
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	return btn


func _box(c: Color) -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color = c
	b.set_corner_radius_all(14)
	b.shadow_color = Color(0, 0, 0, 0.25)
	b.shadow_size = 10
	return b


## 遊戲教學：半透明遮罩上顯示教學圖片，可用按鈕或左右方向鍵翻頁，Esc／關閉按鈕離開
func _build_tutorial() -> void:
	_tutorial = Control.new()
	_tutorial.set_anchors_preset(Control.PRESET_FULL_RECT)
	_tutorial.visible = false
	add_child(_tutorial)
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.82)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP   # 擋住主選單按鈕
	_tutorial.add_child(dim)

	_tut_image = TextureRect.new()
	_tut_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_tut_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_tut_image.size = Vector2(1600, 900)
	_tut_image.position = Vector2(160, 30)
	_tut_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tutorial.add_child(_tut_image)

	_tut_prev = _button("上一頁", 32, Vector2(200, 72), Vector2(560, 968))
	_tut_prev.pressed.connect(func(): _show_page(_tut_page - 1))
	_tutorial.add_child(_tut_prev)
	_tut_page_label = Label.new()
	_tut_page_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tut_page_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_tut_page_label.size = Vector2(200, 72)
	_tut_page_label.position = Vector2(860, 968)
	_tut_page_label.add_theme_font_size_override("font_size", 34)
	_tut_page_label.add_theme_color_override("font_color", Color(1, 0.96, 0.9))
	_tutorial.add_child(_tut_page_label)
	_tut_next = _button("下一頁", 32, Vector2(200, 72), Vector2(1160, 968))
	_tut_next.pressed.connect(func(): _show_page(_tut_page + 1))
	_tutorial.add_child(_tut_next)
	var close := _button("關閉", 32, Vector2(160, 72), Vector2(1700, 968))
	close.pressed.connect(_close_tutorial)
	_tutorial.add_child(close)


func _open_tutorial() -> void:
	if _starting:
		return
	_show_page(0)
	_tutorial.visible = true
	_tutorial.modulate.a = 0.0
	create_tween().tween_property(_tutorial, "modulate:a", 1.0, 0.25)


func _close_tutorial() -> void:
	_tutorial.visible = false


func _show_page(i: int) -> void:
	_tut_page = clampi(i, 0, TUTORIAL_PAGES.size() - 1)
	_tut_image.texture = Assets.tex(TUTORIAL_PAGES[_tut_page])
	_tut_page_label.text = "%d / %d" % [_tut_page + 1, TUTORIAL_PAGES.size()]
	_tut_prev.disabled = _tut_page == 0
	_tut_next.disabled = _tut_page == TUTORIAL_PAGES.size() - 1


func _unhandled_input(event: InputEvent) -> void:
	if not _tutorial.visible or not (event is InputEventKey and event.pressed):
		return
	match event.keycode:
		KEY_LEFT: _show_page(_tut_page - 1)
		KEY_RIGHT: _show_page(_tut_page + 1)
		KEY_ESCAPE: _close_tutorial()


func _process(delta: float) -> void:
	_acc += delta
	if _acc >= FRAME_TIME:
		_acc -= FRAME_TIME
		_frame = (_frame + 1) % Assets.MENU_FRAME_COUNT
		_bg.texture = Assets.menu_frame(_frame)


func _on_start() -> void:
	if _starting:
		return
	_starting = true
	_fade.mouse_filter = Control.MOUSE_FILTER_STOP
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 1.0, 0.6)
	await tw.finished
	get_tree().change_scene_to_file("res://scenes/game.tscn")


# 測試用：--shot 參數時自動截圖並進入遊戲
func _debug_shot() -> void:
	await get_tree().create_timer(1.2).timeout
	DebugShot.save(get_viewport(), "menu")
	_open_tutorial()
	await get_tree().create_timer(0.4).timeout
	DebugShot.save(get_viewport(), "menu_tutorial_1")
	_tut_next.pressed.emit()
	await get_tree().process_frame
	DebugShot.save(get_viewport(), "menu_tutorial_2")
	print("tutorial page=", _tut_page, " next disabled=", _tut_next.disabled, " prev disabled=", _tut_prev.disabled)
	_close_tutorial()
	_on_start()
