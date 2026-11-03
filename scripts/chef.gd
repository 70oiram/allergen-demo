class_name Chef
extends Node2D
## 廚師：節點位置 = 腳底點。四方向移動貼圖、0.2 秒交叉淡化、頭頂顯示持有的食材／料理圖標、加工上下平移。

const FEET := Vector2(512, 1522)   # 素材中的腳底點（alpha 下緣）
const FIG_H := 1514.0              # alpha 可見人物高度（頭頂 y≈8 至腳底 y≈1522）
const FAR_Y := 1005.0              # 工作站前（較遠）；烹煮時鍋子貼合灶台面
const NEAR_Y := 1125.0             # 玩家面前（較近）
const FAR_SCALE := 0.435           # 遠景依原深度比例（0.37/0.42）縮小
const NEAR_SCALE := 0.576          # 近景：桌沿以上可見高度約畫面 45%（(1125-253)/1514）
const FADE_TIME := 0.2
const STAGE_TINT := [Color(1, 1, 1), Color(0.86, 0.86, 0.95), Color(0.82, 0.62, 0.66)]
const ICON_GAP := 70.0             # 圖標中心距頭頂的距離（畫面像素）
const ICON_BUBBLE := 130.0         # 圖標底圓直徑

var speed := 250.0
var body: Node2D
var _spr_a: Sprite2D
var _spr_b: Sprite2D
var _active: Sprite2D
var _fade: Tween
var _pose := "正面"
var _stage := 1     # 美術階段：有分階段的姿勢（切菜）依此選圖
var _walking := false
var _working := false
var _t := 0.0
var _icon: Node2D       # 頭頂圖標（底圓＋持有物）
var _held: FoodSprite


func _ready() -> void:
	body = Node2D.new()
	add_child(body)
	_spr_a = _make_sprite()
	_spr_b = _make_sprite()
	_spr_b.modulate.a = 0.0
	_active = _spr_a

	_icon = Node2D.new()
	_icon.visible = false
	add_child(_icon)
	var bubble := Sprite2D.new()
	var grad := Gradient.new()
	grad.set_color(0, Color(1, 1, 1, 0.85))
	grad.set_color(1, Color(1, 1, 1, 0.0))
	grad.add_point(0.62, Color(1, 1, 1, 0.75))
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	gt.width = 256
	gt.height = 256
	bubble.texture = gt
	bubble.scale = Vector2.ONE * (ICON_BUBBLE / 256.0)
	_icon.add_child(bubble)
	_held = FoodSprite.new()
	_held.visible = false
	_icon.add_child(_held)


func _make_sprite() -> Sprite2D:
	var s := Sprite2D.new()
	s.centered = false
	s.offset = -FEET
	body.add_child(s)
	return s


func depth_scale() -> float:
	var k := clampf((position.y - FAR_Y) / (NEAR_Y - FAR_Y), 0.0, 1.0)
	return lerpf(FAR_SCALE, NEAR_SCALE, k)


func _process(delta: float) -> void:
	_t += delta
	var s := depth_scale()
	body.scale = Vector2(s, s)
	var bob := 0.0
	if _walking:
		bob = -absf(sin(_t * 7.0)) * 6.0
	elif _working:
		bob = sin(_t * 9.0) * 5.0   # 加工：小幅上下平移
	body.position.y = lerpf(body.position.y, bob, minf(1.0, delta * 20.0))
	# 頭頂圖標：跟隨頭頂位置與上下擺動
	_icon.position = Vector2(0, -FIG_H * s - ICON_GAP + body.position.y)


## 切換貼圖：舊圖漸淡、新圖同步漸顯 0.2 秒
func set_pose(pose: String) -> void:
	var tex := Assets.chef(pose, _stage)
	_pose = pose
	if _active.texture == tex:
		return
	if _fade and _fade.is_running():
		_fade.kill()
	var prev := _active
	var next := _spr_b if _active == _spr_a else _spr_a
	if prev.texture == null:
		prev.texture = tex
		prev.modulate.a = 1.0
		return
	next.texture = tex
	next.modulate.a = 0.0
	body.move_child(next, body.get_child_count() - 1)
	_active = next
	_fade = create_tween().set_parallel(true)
	_fade.tween_property(next, "modulate:a", 1.0, FADE_TIME)
	_fade.tween_property(prev, "modulate:a", 0.0, FADE_TIME)


## 直線最短路徑；時間依路程比例（由 speed 決定）。依主要方向選四方向貼圖。
func move_to(target: Vector2) -> void:
	var d := target - position
	var dist := d.length()
	if dist < 1.0:
		position = target
		return
	if absf(d.x) >= absf(d.y):
		set_pose("右側" if d.x > 0 else "左側")
	else:
		set_pose("背面" if d.y < 0 else "正面")
	_walking = true
	var tw := create_tween()
	tw.tween_property(self, "position", target, dist / speed)
	await tw.finished
	_walking = false


## 持有食材：搬運時於頭頂圖標顯示目前階段的 A 貼圖
func hold_food(type: String, stage: int) -> void:
	_held.setup(type, false, 92.0, stage)
	_held.visible = true
	_icon.visible = true


## 持有完成料理：頭頂圖標顯示本輪抽到的食物外觀，前往出餐盤
func hold_dish(visual: String, stage: int) -> void:
	_held.setup_dish("", visual, 104.0, stage)
	_held.visible = true
	_icon.visible = true


func hide_held() -> void:
	_icon.visible = false
	_held.visible = false
	_held.food_type = ""
	_held.visual_id = ""


## 加工：只顯示加工姿勢與小幅上下平移，不顯示食材
func start_work() -> void:
	_working = true


func stop_work() -> void:
	_working = false


func refresh(stage: int) -> void:
	_stage = stage
	if _active and _active.texture:
		set_pose(_pose)
	body.modulate = STAGE_TINT[stage - 1]
	_held.refresh(stage)
