extends Control
## 主選單：樹影循環背景 +「開始遊戲」「遊戲教學」「設定」按鈕。

const FRAME_TIME := 0.15
const TUTORIAL_PAGES := [
	"res://assets/教學/教學-1-把食物拉到面前.png",
	"res://assets/教學/教學-2-推開食物或空盤.png",
	"res://assets/教學/教學-3-用WS切換視角.png",
]
const DEV_KEYS_NOTE := "以下按鍵僅供開發時輔助測試，正式遊玩請勿使用"
const DEV_KEYS := [
	["1", "遊戲速度 100%（恢復正常）"],
	["2", "遊戲速度 200%（快轉）"],
	["3", "遊戲速度 300%（快轉）"],
	["T", "模擬吃下一次過敏原（測試瀕死／死亡）"],
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
var _settings: Control     # 設定（音量、開發者按鍵）
var _dev_keys: Control
var _volume_sliders := {}


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
	var set_btn := _button("設定", 38, Vector2(300, 80), Vector2(960 - 150, 800))
	set_btn.pressed.connect(_open_settings)
	add_child(set_btn)

	_build_tutorial()
	_build_settings()

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
	if not (event is InputEventKey and event.pressed):
		return
	if _settings.visible:
		if event.keycode == KEY_ESCAPE:
			if _dev_keys.visible:
				_dev_keys.visible = false
			else:
				_close_settings()
		return
	if not _tutorial.visible:
		return
	match event.keycode:
		KEY_LEFT: _show_page(_tut_page - 1)
		KEY_RIGHT: _show_page(_tut_page + 1)
		KEY_ESCAPE: _close_tutorial()


## 設定：音量滑動條（主音量／音樂／音效，變更即時套用、關閉時儲存）＋開發者按鍵說明
func _build_settings() -> void:
	_settings = Control.new()
	_settings.set_anchors_preset(Control.PRESET_FULL_RECT)
	_settings.visible = false
	add_child(_settings)
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.7)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_settings.add_child(dim)

	var panel := _panel(Vector2(900, 600), Vector2(510, 240))
	_settings.add_child(panel)
	var title := _text("設定", 52, Vector2(0, 36), Vector2(900, 70))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(title)
	var names := {"Master": "主音量", Settings.MUSIC: "音樂", Settings.SFX: "音效"}
	var y := 150.0
	for bus in Settings.BUSES:
		panel.add_child(_text(names[bus], 36, Vector2(70, y), Vector2(180, 60)))
		var value := _text("", 32, Vector2(720, y), Vector2(120, 60))
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		panel.add_child(value)
		var slider := HSlider.new()
		slider.min_value = 0
		slider.max_value = 100
		slider.step = 1
		slider.position = Vector2(250, y + 12)
		slider.size = Vector2(450, 36)
		slider.add_theme_icon_override("grabber", _knob(Color(1, 0.96, 0.88)))
		slider.add_theme_icon_override("grabber_highlight", _knob(Color(1, 1, 1)))
		slider.add_theme_stylebox_override("slider", _track(Color(1, 1, 1, 0.25)))
		slider.add_theme_stylebox_override("grabber_area", _track(Color(1, 0.82, 0.5)))
		slider.add_theme_stylebox_override("grabber_area_highlight", _track(Color(1, 0.86, 0.6)))
		slider.value_changed.connect(func(v: float):
			Settings.set_volume(bus, v / 100.0)
			value.text = "%d%%" % int(v))
		slider.value = roundf(Settings.volumes[bus] * 100.0)
		value.text = "%d%%" % int(slider.value)
		panel.add_child(slider)
		_volume_sliders[bus] = slider
		y += 100.0

	var dev := _button("開發者按鍵", 32, Vector2(260, 72), Vector2(170, 480))
	dev.pressed.connect(func(): _dev_keys.visible = true)
	panel.add_child(dev)
	var close := _button("關閉", 32, Vector2(260, 72), Vector2(470, 480))
	close.pressed.connect(_close_settings)
	panel.add_child(close)

	# 開發者按鍵說明（疊在設定上）
	_dev_keys = Control.new()
	_dev_keys.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dev_keys.visible = false
	_settings.add_child(_dev_keys)
	var dim2 := ColorRect.new()
	dim2.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim2.color = Color(0, 0, 0, 0.5)
	dim2.mouse_filter = Control.MOUSE_FILTER_STOP
	_dev_keys.add_child(dim2)
	var box := _panel(Vector2(980, 640), Vector2(470, 220))
	_dev_keys.add_child(box)
	var head := _text("開發者按鍵", 46, Vector2(0, 32), Vector2(980, 64))
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(head)
	var note := _text(DEV_KEYS_NOTE, 28, Vector2(0, 100), Vector2(980, 50))
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.add_theme_color_override("font_color", Color(1, 0.75, 0.55))
	box.add_child(note)
	var ky := 180.0
	for row in DEV_KEYS:
		var key := _text(row[0], 34, Vector2(110, ky), Vector2(120, 56))
		key.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		key.add_theme_stylebox_override("normal", _box(Color(1, 0.96, 0.88, 0.16)))
		box.add_child(key)
		box.add_child(_text(row[1], 32, Vector2(270, ky), Vector2(650, 56)))
		ky += 80.0
	var back := _button("返回", 32, Vector2(220, 72), Vector2(380, 528))
	back.pressed.connect(func(): _dev_keys.visible = false)
	box.add_child(back)


func _panel(size: Vector2, pos: Vector2) -> Panel:
	var p := Panel.new()
	p.size = size
	p.position = pos
	var sb := _box(Color(0.16, 0.1, 0.06, 0.94))
	sb.border_color = Color(1, 0.9, 0.75, 0.35)
	sb.set_border_width_all(2)
	p.add_theme_stylebox_override("panel", sb)
	return p


func _text(t: String, px: int, pos: Vector2, size: Vector2) -> Label:
	var l := Label.new()
	l.text = t
	l.position = pos
	l.size = size
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", px)
	l.add_theme_color_override("font_color", Color(1, 0.96, 0.9))
	return l


func _track(c: Color) -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color = c
	b.set_corner_radius_all(6)
	b.content_margin_top = 6
	b.content_margin_bottom = 6
	return b


func _knob(c: Color) -> Texture2D:
	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	for y in 32:
		for x in 32:
			var d := Vector2(x + 0.5, y + 0.5).distance_to(Vector2(16, 16))
			img.set_pixel(x, y, Color(c, clampf(15.0 - d, 0.0, 1.0)))
	return ImageTexture.create_from_image(img)


func _open_settings() -> void:
	if _starting:
		return
	_dev_keys.visible = false
	_settings.visible = true
	_settings.modulate.a = 0.0
	create_tween().tween_property(_settings, "modulate:a", 1.0, 0.25)


func _close_settings() -> void:
	_settings.visible = false
	Settings.save()


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
	_tut_next.pressed.emit()
	await get_tree().process_frame
	DebugShot.save(get_viewport(), "menu_tutorial_3")
	print("tutorial page=", _tut_page, " next disabled=", _tut_next.disabled, " prev disabled=", _tut_prev.disabled)
	_close_tutorial()
	_open_settings()
	await get_tree().create_timer(0.4).timeout
	_volume_sliders[Settings.MUSIC].value = 40
	await get_tree().process_frame
	DebugShot.save(get_viewport(), "menu_settings")
	print("settings: music=", Settings.volumes[Settings.MUSIC], " bus db=", snappedf(AudioServer.get_bus_volume_db(AudioServer.get_bus_index(Settings.MUSIC)), 0.1), " buses=", AudioServer.bus_count)
	_dev_keys.visible = true
	await get_tree().process_frame
	DebugShot.save(get_viewport(), "menu_dev_keys")
	_volume_sliders[Settings.MUSIC].value = 100
	_close_settings()
	var cfg := ConfigFile.new()
	print("settings saved=", cfg.load(Settings.PATH) == OK, " music=", cfg.get_value("audio", Settings.MUSIC, -1))
	_on_start()
