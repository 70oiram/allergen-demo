class_name EndScreen
extends CanvasLayer
## 遊戲結束畫面：全黑後於中央以打字機效果浮出結語，之後顯示「我還想吃更多...」作為再玩一次按鈕

signal retry

const TYPE_INTERVAL := 0.09     # 每字間隔（秒）
const LINE_PAUSE := 0.6         # 換行時多停頓
const RETRY_DELAY := 0.8        # 結語打完後，按鈕淡入前的停頓
const IDLE_COLOR := Color(0.85, 0.82, 0.78)
const HOVER_COLOR := Color(0.85, 0.06, 0.06)
const SHAKE_PX := 3.5

var message: Label
var retry_label: Label
var hovered := false:
	set(v):
		if hovered != v:
			hovered = v
			retry_label.add_theme_color_override("font_color", HOVER_COLOR if v else IDLE_COLOR)
			if not v:
				retry_label.position = _retry_base
var _retry_base := Vector2.ZERO


func _ready() -> void:
	layer = 20
	var bg := ColorRect.new()
	bg.color = Color.BLACK
	bg.size = Vector2(1920, 1080)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	message = Label.new()
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	message.size = Vector2(1920, 260)
	message.position = Vector2(0, 330)
	message.add_theme_font_size_override("font_size", 50)
	message.add_theme_color_override("font_color", Color(0.93, 0.9, 0.86))
	message.add_theme_constant_override("line_spacing", 22)
	message.visible_characters = 0
	message.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(message)

	retry_label = Label.new()
	retry_label.text = "我還想吃更多..."
	retry_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	retry_label.add_theme_font_size_override("font_size", 40)
	retry_label.add_theme_color_override("font_color", IDLE_COLOR)
	retry_label.mouse_filter = Control.MOUSE_FILTER_STOP
	retry_label.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	retry_label.modulate.a = 0.0
	retry_label.visible = false
	add_child(retry_label)
	retry_label.reset_size()
	_retry_base = Vector2((1920 - retry_label.size.x) * 0.5, 720)
	retry_label.position = _retry_base
	retry_label.mouse_entered.connect(func(): hovered = true)
	retry_label.mouse_exited.connect(func(): hovered = false)
	retry_label.gui_input.connect(_on_retry_input)


## 存活時間：例如「3分25秒」，不足一分鐘只顯示秒數
static func format_time(secs: int) -> String:
	if secs < 60:
		return "%d秒" % secs
	return "%d分%d秒" % [secs / 60, secs % 60]


func play(survived_secs: int) -> void:
	message.text = "在%s後\n你似乎忘記為什麼要吃下那些食物了" % format_time(survived_secs)
	var total := message.get_total_character_count()
	var line_break := message.text.find("\n")
	for i in range(1, total + 1):
		message.visible_characters = i
		await get_tree().create_timer(TYPE_INTERVAL + (LINE_PAUSE if i == line_break else 0.0)).timeout
	await get_tree().create_timer(RETRY_DELAY).timeout
	retry_label.visible = true
	create_tween().tween_property(retry_label, "modulate:a", 1.0, 0.8)


func _process(_delta: float) -> void:
	if hovered:
		retry_label.position = _retry_base + Vector2(randf_range(-SHAKE_PX, SHAKE_PX), randf_range(-SHAKE_PX, SHAKE_PX))


func _on_retry_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed \
			and retry_label.modulate.a > 0.5:
		retry.emit()
