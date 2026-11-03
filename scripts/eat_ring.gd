class_name EatRing
extends Node2D
## 進食中：畫面最底部的圓形進度條，剩餘部分以順時鐘方向消失

const RADIUS := 30.0
const WIDTH := 9.0

var remaining := 1.0:
	set(v):
		remaining = v
		queue_redraw()


func _draw() -> void:
	draw_circle(Vector2.ZERO, RADIUS + WIDTH, Color(0, 0, 0, 0.45))
	draw_arc(Vector2.ZERO, RADIUS, 0.0, TAU, 64, Color(1, 0.97, 0.9, 0.18), WIDTH, true)
	if remaining > 0.0:
		# 從 12 點方向起算：起點隨時間順時鐘推進，剩餘弧段因而順時鐘消失
		var start := -PI * 0.5 + TAU * (1.0 - remaining)
		draw_arc(Vector2.ZERO, RADIUS, start, -PI * 0.5 + TAU, 64, Color(1, 0.9, 0.65, 0.95), WIDTH, true)
