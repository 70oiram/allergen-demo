class_name Plate
extends Node2D
## 素白大平圓盤：固定五個錨點（上、下、左、右、中），每項食物獨立。

const TEX_SIZE := 1254.0
const ANCHOR_KEYS := ["上", "下", "左", "右", "中"]

var width := 470.0   # 加入場景前設定（出餐盤較小）
var foods: Array[FoodSprite] = []
var sprite: Sprite2D


func _ready() -> void:
	sprite = Sprite2D.new()
	sprite.texture = Assets.tex("res://assets/互動素材/盤子-大平圓盤.png")
	sprite.scale = Vector2.ONE * (width / TEX_SIZE)
	add_child(sprite)


func _draw() -> void:
	# 盤底陰影，讓盤子落在桌面上
	draw_set_transform(Vector2(0, 16), 0.0, Vector2(1.0, 0.72))
	draw_circle(Vector2.ZERO, width * 0.5, Color(0, 0, 0, 0.32))
	draw_set_transform(Vector2.ZERO)


func anchor_offset(key: String) -> Vector2:
	match key:
		"上": return Vector2(0, -0.17 * width)
		"下": return Vector2(0, 0.17 * width)
		"左": return Vector2(-0.24 * width, 0)
		"右": return Vector2(0.24 * width, 0)
	return Vector2.ZERO


func free_slots() -> Array:
	var used := foods.map(func(f): return f.slot_id)
	return ANCHOR_KEYS.filter(func(k): return not used.has(k))


## 放入一項完成料理：沿用 item 的餐位（slot）與外觀（visual），實際食材另存
func add_item(item: Dictionary, stage: int) -> FoodSprite:
	var f := FoodSprite.new().setup_dish(item.type, item.visual, width * 0.34, stage)   # 盤中料理顯示大小（第三版放大）
	f.is_allergen = item.is_allergen
	f.slot_id = item.slot
	f.anchor = anchor_offset(item.slot)
	f.position = f.anchor
	add_child(f)
	foods.append(f)
	return f


func refresh(stage: int) -> void:
	for f in foods:
		f.refresh(stage)


func contains(global_point: Vector2) -> bool:
	var p := (global_point - global_position) / scale
	var rx := width * 0.478
	var ry := width * 0.349
	return (p.x * p.x) / (rx * rx) + (p.y * p.y) / (ry * ry) <= 1.0


func food_at(global_point: Vector2) -> FoodSprite:
	for i in range(foods.size() - 1, -1, -1):
		if foods[i].hit(global_point):
			return foods[i]
	return null


func remove_food(f: FoodSprite) -> void:
	foods.erase(f)
	f.queue_free()
