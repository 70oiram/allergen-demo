class_name FoodSprite
extends Sprite2D
## 單項食物圖像：依目前階段切換數字後綴。
## food_type 為真實食材（ingredient_id）；visual_id 非空時改顯示「食物-」外觀，外觀不參與判定。

var food_type := ""
var visual_id := ""
var cooked := false
var is_allergen := false
var slot_id := ""
var target_size := 120.0
var anchor := Vector2.ZERO  # 餐盤上的錨點（plate 區域座標）


func setup(type: String, is_cooked: bool, size: float, stage: int) -> FoodSprite:
	food_type = type
	visual_id = ""
	cooked = is_cooked
	target_size = size
	refresh(stage)
	return self


func setup_dish(type: String, visual: String, size: float, stage: int) -> FoodSprite:
	food_type = type
	visual_id = visual
	cooked = true
	target_size = size
	refresh(stage)
	return self


func refresh(stage: int) -> void:
	if visual_id != "":
		texture = Assets.dish(visual_id, stage)
	elif food_type != "":
		texture = Assets.food(food_type, cooked, stage)
	else:
		return
	var m := maxf(texture.get_width(), texture.get_height())
	scale = Vector2.ONE * (target_size / m)


func hit(global_point: Vector2) -> bool:
	return global_point.distance_to(global_position) <= target_size * 0.45
