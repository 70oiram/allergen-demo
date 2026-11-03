extends Node2D
## 手部無法對準游標時（畫面邊緣），顯示的小圓點游標


func _draw() -> void:
	draw_circle(Vector2.ZERO, 7.0, Color(0, 0, 0, 0.45))
	draw_circle(Vector2.ZERO, 4.5, Color(1, 0.97, 0.9, 0.95))
