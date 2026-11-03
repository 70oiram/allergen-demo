class_name PushHandle
extends Node2D
## 低頭畫面：眼前盤子左側的互動點。滑鼠靠近時浮現並顯示「我不想吃這個」（空盤時為「下一盤...」），按住往右拖可把盤子推離桌面

const RADIUS := 46.0
const HIT_MARGIN := 24.0
const TEXT_FULL := "我不想吃這個"
const TEXT_EMPTY := "下一盤..."

var label: Label
var pulse_t := 0.0
var empty_plate := false:
	set(v):
		empty_plate = v
		if label:
			label.text = TEXT_EMPTY if v else TEXT_FULL


func _ready() -> void:
	label = Label.new()
	label.text = TEXT_EMPTY if empty_plate else TEXT_FULL
	label.add_theme_font_size_override("font_size", 36)
	label.add_theme_color_override("font_color", Color(1, 0.97, 0.9))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.75))
	label.add_theme_constant_override("outline_size", 9)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.size = Vector2(300, 52)
	label.position = Vector2(-150, -RADIUS - 70)
	add_child(label)


func hit(p: Vector2) -> bool:
	return p.distance_to(global_position) <= (RADIUS + HIT_MARGIN) * global_scale.x


func _process(delta: float) -> void:
	if modulate.a > 0.0:
		pulse_t += delta
		queue_redraw()


func _draw() -> void:
	var ink := Color(1, 0.97, 0.9)
	var breathe := 0.5 + 0.5 * sin(pulse_t * 4.0)
	draw_circle(Vector2.ZERO, RADIUS + 14.0 + 8.0 * breathe, Color(1, 0.9, 0.7, 0.10 + 0.08 * breathe))
	draw_circle(Vector2.ZERO, RADIUS, Color(0, 0, 0, 0.5))
	draw_arc(Vector2.ZERO, RADIUS, 0.0, TAU, 48, Color(ink, 0.85), 4.0, true)
	# 往右的雙箭頭：提示往右推
	for dx in [-12.0, 9.0]:
		draw_polyline(PackedVector2Array([Vector2(dx - 9, -17), Vector2(dx + 8, 0), Vector2(dx - 9, 17)]), ink, 6.0, true)
