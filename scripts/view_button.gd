class_name ViewButton
extends Node2D
## 畫面右側的抬頭／低頭切換按鈕：抬頭時顯示向下箭頭（點擊低頭），低頭時顯示向上箭頭（點擊抬頭）

const RADIUS := 46.0

var arrow_down := true
var hover := false:
	set(v):
		if hover != v:
			hover = v
			queue_redraw()


func set_arrow_down(v: bool) -> void:
	arrow_down = v
	queue_redraw()


func hit(p: Vector2) -> bool:
	return p.distance_to(global_position) <= RADIUS + 6.0


func _draw() -> void:
	var ink := Color(1, 0.97, 0.9, 0.95)
	draw_circle(Vector2.ZERO, RADIUS, Color(0, 0, 0, 0.62 if hover else 0.42))
	draw_arc(Vector2.ZERO, RADIUS, 0.0, TAU, 64, Color(ink, 0.9 if hover else 0.6), 3.0, true)
	var d := 1.0 if arrow_down else -1.0
	draw_line(Vector2(0, -20 * d), Vector2(0, 18 * d), ink, 6.0, true)
	draw_polyline(PackedVector2Array([Vector2(-16, 4 * d), Vector2(0, 21 * d), Vector2(16, 4 * d)]), ink, 6.0, true)
