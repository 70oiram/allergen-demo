extends Node2D
## 一局遊戲。規則來源：第二版遊戲更新交接包 01_規格/權威玩法規格.md
## 雙層狀態模型：整輪流程（_chef_round）＋ 單份食材記錄（_make_item）；逐項取材、逐項上出餐盤。

const VIEW := Vector2(1920, 1080)
const BG_SCALE := 1920.0 / 1672.0
const TABLE_EDGE_SRC := 644.0            # 背景素材中桌面上緣（第二版桌面滿版定稿，素材像素）

# 階段與計時
const STAGE_START := [0.0, 120.0, 240.0]  # 00:00 / 02:00 / 04:00
const STAGE_FOOD_CAP := [3, 3, 3]        # 三階段每輪上限皆為 3
const HINT_DURATION := 5.0
const STAGE_BLINK_CLOSE := 0.15          # 階段轉換：三次短眨眼，閉眼 0.15 秒
const STAGE_BLINK_OPEN := 0.20           # 睜眼 0.20 秒，共 1.05 秒
const STAGE_BLINK_COUNT := 3

# 飢餓值（原型初始平衡值）
const HUNGER_MAX := 100.0
const HUNGER_DRAIN := 0.5                 # 每秒 %
const HUNGER_STEP := 10.0                 # 正確 +10 / 錯誤 -10

# 抽選
const INITIAL_ALLERGENS := 2
const ALLERGEN_CHANCE := 0.15

# 廚師流程
const STATIONS := {
	"shelf": Vector2(264, 1005),   # 架子（最左）
	"stove": Vector2(930, 1005),   # 灶台
	"board": Vector2(1257, 1005),  # 砧板
	"fridge": Vector2(1745, 1005), # 冰箱（最右）
}
const CHEF_HOME := Vector2(960, 1125)    # 畫面中央、玩家面前
const LEFT_TO_RIGHT_TIME := 6.0
const RESTOCK_TIME := 1.0
const STEP_TIME := Vector2(3.0, 5.0)
const LINGER_TIME := Vector2(1.0, 4.0)

# 玩家互動
const EAT_ZONE_RATIO := Rect2(0.225, 0.78, 0.55, 0.22)   # 畫面下方中央 55% × 22%
const PLATE_POS := Vector2(960, 912)     # 盤緣不超過桌緣（桌緣 y≈740，盤面半高≈162）
const EAT_DURATION := 3.0                 # 吃下一口後咀嚼 3 秒，期間暫停所有操作
const EAT_RING_POS := Vector2(960, 1025)  # 進食進度圈：畫面最底部中央
const CHEW_SFX := "res://assets/音效/咀嚼/咀嚼音效_%s.wav"   # 各 3 秒，與咀嚼時間一致
const CHEW_BY_DISH := {   # 依玩家看到的料理外觀選咀嚼聲（實際食材不影響）
	"番茄燉蔬菜": "清脆蔬菜", "番茄焗烤通心麵": "酥脆餅乾",
	"奶油雞肉燉飯": "多汁柔軟", "燉牛肉": "多汁柔軟", "番茄燉豆": "多汁柔軟",
}
const COOK_SFX := ["res://assets/音效/烹飪/烹飪_熱油滋滋.wav", "res://assets/音效/烹飪/烹飪_平底鍋細煎.wav"]   # 灶台烹煮時循環播放（隨機其一）
const COOK_DONE_SFX := "res://assets/音效/烹飪/烹飪_翻炒起鍋.wav"   # 料理完成、端出成品時
const CHOP_SFX := "res://assets/音效/切菜/切菜_%s.wav"   # 砧板備料時循環播放，依食材選切法
const CHOP_BY_TYPE := {
	"番茄": "多汁食材", "雞肉": "多汁食材", "鮭魚": "多汁食材", "蝦": "多汁食材", "香腸": "多汁食材", "培根": "多汁食材",
	"馬鈴薯": "清脆蔬菜", "蘑菇": "清脆蔬菜",
}   # 其餘（雞蛋、吐司）→ 快速連切
const FRIDGE_OPEN_SFX := "res://assets/音效/冰箱/打開冰箱.wav"
const FRIDGE_CLOSE_SFX := "res://assets/音效/冰箱/關閉冰箱.wav"
const PICK_SFX := "res://assets/音效/拿取食材/拿取食材_%s.wav"
const VEGETABLES := ["番茄", "馬鈴薯", "蘑菇"]   # 取材時用「蔬菜輕拿」；其餘在冰箱為「包裝沙沙」、在架子為「架上餐具碰響」
const COOK_VOLUME_DB := -10.0
const PLATE_PUSH_DIST := 100.0
const PLATE_PULL_DIST := 90.0            # 抬頭時把盤子往下拉超過此距離 → 低頭，盤子移到眼前
const PLATE_PULL_MAX := 220.0
# 手臂只在握叉時顯示（其餘時候為系統滑鼠游標）。握叉時叉尖最高 y=460：
# 持叉素材叉尖以下手臂長約 635px，肩部截口仍落在畫面底部之外
const FORK_POINTER_TOP := 460.0
const FORK_POS := Vector2(1500, 935)     # 叉子只在低頭畫面的桌面右側
const FORK_SCALE := 0.24
# 抬頭／低頭
const DOWN_BG := "res://assets/場景素材/桌面特寫-低頭視角.png"
const DOWN_BG_STAGES := [DOWN_BG, "res://assets/場景素材/桌面特寫-低頭視角-第二階段.png", "res://assets/場景素材/桌面特寫-低頭視角-第三階段.png"]
const DOWN_PLATE_POS := Vector2(960, 700)   # 低頭畫面：盤子較近、較大（第三版實機上移 80px）
const DOWN_PLATE_WIDTH := 560.0
const PUSH_HANDLE_OFFSET := Vector2(-300, 0)   # 推離互動點：眼前盤子左側
const PUSH_HANDLE_NEAR := 280.0                # 滑鼠距互動點此距離內才浮現
const PUSH_AWAY_DIST := 320.0                  # 按住往右拖超過此距離 → 盤子推離桌面
const PULL_BLOCKED_MAX := 30.0                 # 眼前盤子未清理時，抬頭的盤子只能被拉動這麼多
const PULL_BLOCKED_SAY := "上一個盤子..."     # 眼前盤子未清理卻想拉下一盤時的自言自語
const SAY_DURATION := 2.0                       # 短句停留秒數（不鎖定操作）
const NOTEBOOK_TEX := "res://assets/互動素材/筆記本-闔上.png"
const NOTEBOOK_POS := Vector2(250, 850)    # 抬頭畫面：桌面左上角
const NOTEBOOK_WIDTH := 300.0
const VIEW_SWITCH_TIME := 0.45
const VIEW_BUTTON_POS := Vector2(1830, 700)
# 玩家手部：手臂素材（1536×1024，肩部為平直截口），空手／持叉共用同一縮放，切換時手臂大小一致；
# 0.64 使指標在最高位置時，肩部截口仍落在畫面底部之外
const HAND_SCALE := 0.64
const HAND_START_MARGIN := Vector2(0.02, 0.01)   # 空手初始：可見左緣距左 2%、底緣距底 1%
# 手部上緣限制改由握叉指標上限（FORK_POINTER_TOP）負責，手部始終對準指標
const HAND_TEX := {
	"rest": "res://assets/玩家角色素材/玩家左手-桌面休息.png",
	"fork": "res://assets/玩家角色素材/玩家左手-持叉.png",
}
const HAND_TIP := {"rest": Vector2(1506, 166), "fork": Vector2(1486, 18)}   # 素材像素中的指尖／叉尖

const OPENING_HINT := "……我不能吃%s，也不能吃%s。要小心一點。"
const NEW_ALLERGEN_HINTS := [
	"我感覺對%s開始不適……",
	"我突然討厭吃%s。",
	"……%s。光是看著，就讓我反胃。",
]
const VIGNETTE := [Vector2(0.25, 0.0), Vector2(0.5, 0.15), Vector2(0.78, 0.55)]  # (強度, 紅色比例)
const NEAR_DEATH_TINT := Color(0.7, 0.0, 0.03, 0.4)    # 瀕死：常駐的紅色濾鏡
const HEARTBEAT_PERIOD := 1.5                         # 周邊暗紅血管跳動間隔（模擬心跳）
const HEARTBEAT_PEAK := 1.0                           # 心跳最強時的 pulse 值
const HEARTBEAT_IN := 0.25                            # 血管加深、蔓延
const HEARTBEAT_OUT := 0.6                            # 血管退回
const HEARTBEAT_SFX_DELAY := 0.18                     # 心跳聲於加深途中播放，重擊（音檔 0.045 秒處）對齊血管最深
const HEARTBEAT_VOLUME_DB := -2.0
const NEAR_DEATH_FADE_IN := 0.6
const BGM_CALM := "res://assets/音樂/悠閒遊戲背景音樂_循環版.wav"
const BGM_TENSE := "res://assets/音樂/悠閒遊戲背景音樂_急促節奏變奏.wav"   # 第二階段
const BGM_STAGE3 := "res://assets/音樂/第三階段背景音樂_深沉急促.wav"
const BGM_VOLUME_DB := -8.0
const BGM_CROSSFADE := 1.0
const GAME_OVER_FADE := 2.0   # 遊戲結束：畫面漸黑至全黑

var stage := 1        # 邏輯階段（轉換時立即更新）
var art_stage := 1    # 美術階段（於第三次閉眼時更新）
var elapsed := 0.0
var started := false
var running := true
var hunger := HUNGER_MAX
var allergens: Array[String] = []
var held: Dictionary = {}     # 廚師目前持有（一次一項）
var output_slots: Array = []  # 本輪已完成料理（廚師備妥，待上菜）
var has_fork := false
var hint_active := false
var stage_blinking := false
var looking_down := false     # 低頭：看著眼前的盤子，才能用叉子進食
var view_switching := false
var hand_info := {}   # "rest"/"fork" → {scale, used(Rect2 素材像素)}
var allergen_hits := 0   # 吃下過敏原次數：第一次進入瀕死狀態，第二次結束遊戲

var world: Node2D
var bg: Sprite2D
var chef: Chef
var behind_table: Node2D
var table_fg: Sprite2D
var plate_layer: Node2D
var plate: Plate          # 抬頭畫面：桌上剛上菜的盤子（可推盤、可拉到眼前）
var eat_plate: Plate      # 低頭畫面：眼前正在吃的盤子
var eat_plate_types: Array[String] = []   # 眼前盤子上菜時的全部食材（已吃掉的也算）
var eating := false       # 咀嚼中：EAT_DURATION 秒內鎖定操作
var eat_time := 0.0
var _eat_bad := false
var eat_ring: EatRing
var chew_sfx: AudioStreamPlayer
var cook_sfx: AudioStreamPlayer   # 廚師烹飪音效（灶台滋滋聲、起鍋聲）
var stage_root: Node2D    # 兩個畫面＋手部（受擊震動整體移動）
var down_view: Node2D
var down_bg: Sprite2D
var down_plate_layer: Node2D
var view_button: ViewButton
var push_handle: PushHandle
var notebook_item: Sprite2D   # 抬頭畫面桌上闔起的筆記本（點擊打開）
var notebook: Notebook        # 打開的筆記本（記載目前過敏原）
var notebook_mask: Image      # 桌上筆記本的點擊判定（不透明像素）
var fork: Sprite2D
var fork_rect: Rect2
var eat_glow: Sprite2D
var hand: Sprite2D
var cursor_dot: Node2D

var hud: CanvasLayer
var vignette: ColorRect
var red_flash: ColorRect
var near_death_tint: ColorRect
var heartbeat: ColorRect
var heartbeat_sfx: AudioStreamPlayer
var bgm: AudioStreamPlayer   # 背景音樂（循環）；切換變奏時舊的淡出、新的淡入
var near_death := false      # 瀕死狀態（第一次吃到過敏原後）
var near_death_time := 0.0   # 進入瀕死後經過的實際秒數
var hunger_fill: ColorRect
var hunger_back: ColorRect
var timer_label: Label
var speed_label: Label
var hint_panel: PanelContainer
var hint_label: Label
var _say_tw: Tween   # 短句自言自語（不鎖定操作）
var lid_top: ColorRect
var lid_bottom: ColorRect
var fade: ColorRect

var _drag_food: FoodSprite
var _drag_plate := false
var _drag_push := false     # 低頭：按住互動點把眼前的盤子往右推
var _plate_origin := Vector2.ZERO
var _rest_pointer_top := 0.0   # 空手手臂顯示時，指尖最高位置（手臂截口不入鏡）
var _press_pos := Vector2.ZERO
static var from_retry := false   # 由結束畫面「我還想吃更多...」重來：開場字幕改用重來版本
var _sim := false
var _sim_mouse := Vector2(960, 900)


func _ready() -> void:
	randomize()
	Assets.preload_game()
	_sim = "--shot" in OS.get_cmdline_user_args()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE   # 空手時顯示系統游標；握叉時改顯示手臂（_set_hand）
	_build_world()
	_build_hud()
	_sim_mouse = _hand_start_tip()

	var pool := Assets.FOOD_TYPES.duplicate()
	pool.shuffle()
	for i in INITIAL_ALLERGENS:
		allergens.append(pool[i])
	_apply_stage_visuals()
	var retry := from_retry
	from_retry = false

	var tw := create_tween()
	tw.tween_property(fade, "color:a", 0.0, 0.8)
	if _sim:
		_play_bgm(BGM_CALM)
		_debug_run()
	else:
		# 前導字幕：全黑畫面逐句打字，播完淡出後才開始遊戲與音樂
		var intro := Intro.new()
		add_child(intro)
		intro.play(retry)
		await intro.finished
		_play_bgm(BGM_CALM)
	# 開場禁食提示；結束後正式開始
	await _show_hint(OPENING_HINT % [Assets.food_name(allergens[0]), Assets.food_name(allergens[1])])
	if not running:
		return
	started = true
	_chef_loop()


# ───────────────────────── 建立場景 ─────────────────────────

func _build_world() -> void:
	stage_root = Node2D.new()
	add_child(stage_root)
	world = Node2D.new()          # 抬頭畫面（廚房）
	stage_root.add_child(world)

	bg = Sprite2D.new()
	bg.centered = false
	bg.scale = Vector2.ONE * BG_SCALE
	world.add_child(bg)

	chef = Chef.new()
	chef.speed = (STATIONS["fridge"].x - STATIONS["shelf"].x) / LEFT_TO_RIGHT_TIME
	chef.position = CHEF_HOME
	world.add_child(chef)
	chef.set_pose("正面")

	behind_table = Node2D.new()   # 被推下桌的盤子在此層落下，被桌面遮住
	world.add_child(behind_table)

	table_fg = Sprite2D.new()     # 背景的桌面部分，用來遮住廚師下半身
	table_fg.centered = false
	table_fg.region_enabled = true
	table_fg.region_rect = Rect2(0, TABLE_EDGE_SRC, 1672, 941 - TABLE_EDGE_SRC)
	table_fg.position = Vector2(0, TABLE_EDGE_SRC * BG_SCALE)
	table_fg.scale = Vector2.ONE * BG_SCALE
	world.add_child(table_fg)

	notebook_item = Sprite2D.new()
	notebook_item.texture = Assets.tex(NOTEBOOK_TEX)
	notebook_item.scale = Vector2.ONE * (NOTEBOOK_WIDTH / notebook_item.texture.get_width())
	notebook_item.position = NOTEBOOK_POS
	notebook_mask = notebook_item.texture.get_image()
	world.add_child(notebook_item)

	plate_layer = Node2D.new()
	world.add_child(plate_layer)

	# 低頭畫面（桌面特寫）：平時位於畫面下方，低頭時往上捲入
	down_view = Node2D.new()
	down_view.position = Vector2(0, VIEW.y)
	down_view.visible = false
	stage_root.add_child(down_view)
	down_bg = Sprite2D.new()
	down_bg.centered = false
	down_bg.texture = Assets.tex(DOWN_BG)
	down_bg.scale = Vector2.ONE * BG_SCALE
	down_view.add_child(down_bg)

	fork = Sprite2D.new()
	fork.texture = Assets.tex("res://assets/互動素材/叉子-桌面用.png")
	fork.scale = Vector2.ONE * FORK_SCALE
	fork.position = FORK_POS
	down_view.add_child(fork)
	var used := fork.texture.get_image().get_used_rect()
	var half := fork.texture.get_size() * 0.5
	fork_rect = Rect2((Vector2(used.position) - half) * FORK_SCALE + FORK_POS, Vector2(used.size) * FORK_SCALE).grow(10)

	var g := Gradient.new()
	g.set_color(0, Color(1, 0.85, 0.6, 0.0))
	g.set_color(1, Color(1, 0.85, 0.6, 0.22))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill_from = Vector2(0.5, 0.0)
	gt.fill_to = Vector2(0.5, 1.0)
	gt.width = 64
	gt.height = 64
	var zone := eat_zone()
	eat_glow = Sprite2D.new()
	eat_glow.texture = gt
	eat_glow.centered = false
	eat_glow.position = zone.position
	eat_glow.scale = zone.size / 64.0
	eat_glow.modulate.a = 0.0
	down_view.add_child(eat_glow)

	down_plate_layer = Node2D.new()
	down_view.add_child(down_plate_layer)

	push_handle = PushHandle.new()
	push_handle.modulate.a = 0.0
	push_handle.visible = false
	down_view.add_child(push_handle)

	view_button = ViewButton.new()
	view_button.position = VIEW_BUTTON_POS
	stage_root.add_child(view_button)

	for k in HAND_TEX:
		var tex := Assets.tex(HAND_TEX[k])
		hand_info[k] = {"scale": HAND_SCALE, "used": Rect2(tex.get_image().get_used_rect())}
	var rest_used: Rect2 = hand_info["rest"].used
	_rest_pointer_top = VIEW.y + 12.0 - (rest_used.end.y - HAND_TIP["rest"].y) * HAND_SCALE
	hand = Sprite2D.new()
	hand.centered = false
	stage_root.add_child(hand)
	_set_hand("rest")

	cursor_dot = Node2D.new()
	cursor_dot.set_script(preload("res://scripts/cursor_dot.gd"))
	stage_root.add_child(cursor_dot)


func _build_hud() -> void:
	hud = CanvasLayer.new()
	hud.layer = 10
	add_child(hud)

	vignette = ColorRect.new()
	vignette.size = VIEW
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://scripts/vignette.gdshader")
	vignette.material = mat
	hud.add_child(vignette)

	red_flash = ColorRect.new()
	red_flash.size = VIEW
	red_flash.color = Color(0.55, 0.0, 0.02, 0.0)
	red_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(red_flash)

	# 瀕死狀態：紅色濾鏡＋周邊暗紅血管＋心跳聲（第一次吃到過敏原後啟動）
	near_death_tint = ColorRect.new()
	near_death_tint.size = VIEW
	near_death_tint.color = NEAR_DEATH_TINT
	near_death_tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	near_death_tint.visible = false
	hud.add_child(near_death_tint)
	heartbeat = ColorRect.new()
	heartbeat.size = VIEW
	heartbeat.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var hmat := ShaderMaterial.new()
	hmat.shader = preload("res://scripts/heartbeat.gdshader")
	hmat.set_shader_parameter("pulse", 0.0)
	heartbeat.material = hmat
	heartbeat.modulate.a = 0.0
	hud.add_child(heartbeat)
	heartbeat_sfx = AudioStreamPlayer.new()
	heartbeat_sfx.stream = preload("res://assets/音效/心跳-沉重穩定-單拍.wav")
	heartbeat_sfx.volume_db = HEARTBEAT_VOLUME_DB
	add_child(heartbeat_sfx)

	# 左下角飢餓值能量條
	notebook = Notebook.new()
	add_child(notebook)

	eat_ring = EatRing.new()
	eat_ring.position = EAT_RING_POS
	eat_ring.visible = false
	hud.add_child(eat_ring)
	chew_sfx = AudioStreamPlayer.new()
	add_child(chew_sfx)
	cook_sfx = AudioStreamPlayer.new()
	cook_sfx.volume_db = COOK_VOLUME_DB
	add_child(cook_sfx)

	hunger_back = ColorRect.new()
	hunger_back.position = Vector2(48, 1012)
	hunger_back.size = Vector2(380, 22)
	hunger_back.color = Color(0, 0, 0, 0.5)
	hud.add_child(hunger_back)
	hunger_fill = ColorRect.new()
	hunger_fill.position = Vector2(3, 3)
	hunger_fill.size = Vector2(374, 16)
	hunger_back.add_child(hunger_fill)

	# 右上角存活時間
	timer_label = Label.new()
	timer_label.text = "00:00"
	timer_label.position = Vector2(1680, 30)
	timer_label.size = Vector2(200, 60)
	timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	timer_label.add_theme_font_size_override("font_size", 46)
	timer_label.add_theme_color_override("font_color", Color(1, 0.97, 0.9))
	timer_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	timer_label.add_theme_constant_override("outline_size", 8)
	hud.add_child(timer_label)

	speed_label = Label.new()
	speed_label.position = Vector2(1680, 92)
	speed_label.size = Vector2(200, 40)
	speed_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	speed_label.add_theme_font_size_override("font_size", 26)
	speed_label.add_theme_color_override("font_color", Color(1, 0.9, 0.6))
	speed_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	speed_label.add_theme_constant_override("outline_size", 6)
	speed_label.visible = false
	hud.add_child(speed_label)

	# 畫面底部自言自語提示
	hint_panel = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0.55)
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 40
	sb.content_margin_right = 40
	sb.content_margin_top = 16
	sb.content_margin_bottom = 16
	hint_panel.add_theme_stylebox_override("panel", sb)
	hint_panel.modulate.a = 0.0
	hint_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(hint_panel)
	hint_label = Label.new()
	hint_label.add_theme_font_size_override("font_size", 40)
	hint_label.add_theme_color_override("font_color", Color(1, 0.98, 0.94))
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_panel.add_child(hint_label)

	# 眨眼效果（上下眼瞼）
	lid_top = ColorRect.new()
	lid_top.color = Color.BLACK
	lid_top.size = Vector2(VIEW.x, 0)
	hud.add_child(lid_top)
	lid_bottom = ColorRect.new()
	lid_bottom.color = Color.BLACK
	lid_bottom.position = Vector2(0, VIEW.y)
	lid_bottom.size = Vector2(VIEW.x, 0)
	hud.add_child(lid_bottom)

	fade = ColorRect.new()
	fade.size = VIEW
	fade.color = Color(0, 0, 0, 1)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(fade)


func eat_zone() -> Rect2:
	return Rect2(EAT_ZONE_RATIO.position * VIEW, EAT_ZONE_RATIO.size * VIEW)


## 進食判定：在進食區內且不在玩家餐盤上（餐盤下移後，靜置食物不會被誤判為進食）
func _in_eat_zone(m: Vector2) -> bool:
	return looking_down and eat_zone().has_point(m) and not (eat_plate and eat_plate.contains(m))


# ───────────────────────── 每幀更新 ─────────────────────────

func _process(delta: float) -> void:
	_update_hand()
	_update_near_death(delta)
	if not running:
		return
	if started:
		elapsed += delta
		hunger = maxf(0.0, hunger - HUNGER_DRAIN * delta)
		if stage < 3 and elapsed >= STAGE_START[stage]:
			_enter_stage(stage + 1)
		if hunger <= 0.0:
			_game_over()
	if eating:
		eat_time += delta
		eat_ring.remaining = maxf(0.0, 1.0 - eat_time / EAT_DURATION)
		if eat_time >= EAT_DURATION:
			eating = false
			eat_ring.visible = false
			_apply_eat(_eat_bad)
	var secs := int(elapsed)
	timer_label.text = "%02d:%02d" % [secs / 60, secs % 60]
	_update_hunger_bar()
	if _drag_food:
		var inside := _in_eat_zone(_mouse())
		eat_glow.modulate.a = lerpf(eat_glow.modulate.a, 1.0 if inside else 0.45, minf(1.0, delta * 12.0))
	else:
		eat_glow.modulate.a = lerpf(eat_glow.modulate.a, 0.0, minf(1.0, delta * 8.0))


func _update_hunger_bar() -> void:
	var r := hunger / HUNGER_MAX
	hunger_fill.size.x = 374.0 * r
	var hi := Color(0.98, 0.78, 0.35)
	var lo := Color(0.85, 0.15, 0.12)
	hunger_fill.color = lo.lerp(hi, clampf(r * 1.6, 0.0, 1.0))


func _raw_mouse() -> Vector2:
	return _sim_mouse if _sim else get_global_mouse_position()


## 玩家指標：空手時即系統游標位置；握叉時為叉尖、推盤時為空手指尖，皆有最高位置（手臂截口不入鏡）
func _mouse() -> Vector2:
	var m := _raw_mouse()
	var top := 0.0
	if has_fork:
		top = FORK_POINTER_TOP
	elif _drag_push:
		top = _rest_pointer_top
	return Vector2(clampf(m.x, 0.0, VIEW.x), clampf(m.y, top, VIEW.y))


## 手臂只在握叉、推盤時顯示；其餘時候隱藏手臂、改顯示系統游標
func _set_hand(k: String, show := k == "fork") -> void:
	hand.texture = Assets.tex(HAND_TEX[k])
	hand.scale = Vector2.ONE * float(hand_info[k].scale)
	hand.visible = show
	if not _sim:
		Input.mouse_mode = Input.MOUSE_MODE_HIDDEN if hand.visible else Input.MOUSE_MODE_VISIBLE


## 空手初始位置（可見範圍左緣距左 2%、底緣距底 1%）對應的指尖座標
func _hand_start_tip() -> Vector2:
	var s: float = hand_info["rest"].scale
	var used: Rect2 = hand_info["rest"].used
	var pos := Vector2(VIEW.x * HAND_START_MARGIN.x - used.position.x * s,
		VIEW.y * (1.0 - HAND_START_MARGIN.y) - used.end.y * s)
	return pos + HAND_TIP["rest"] * s


## 手部持續跟隨指標；指標對應指尖（握叉時為叉尖）
func _update_hand() -> void:
	var m := _mouse()
	var k := "fork" if has_fork else "rest"
	var s: float = hand_info[k].scale
	var tip: Vector2 = HAND_TIP[k] * s
	var pos := m - tip
	hand.position = pos
	# 握叉時游標超出叉尖可及範圍：以小圓點標示實際游標位置
	var raw := _raw_mouse()
	cursor_dot.position = raw
	cursor_dot.visible = hand.visible and raw.distance_to(m) > 4.0
	view_button.hover = not view_switching and view_button.hit(m)
	notebook_item.modulate = Color(1.18, 1.12, 1.0) if not _locked() and _notebook_hit(m) else Color.WHITE
	_update_push_handle(m)
	if _drag_food:
		_drag_food.global_position = m
	elif _drag_push and eat_plate:
		eat_plate.position.x = _plate_origin.x + maxf(0.0, m.x - _press_pos.x)
	elif _drag_plate and plate:
		# 往上推（推盤）或往下拉（拉到眼前、低頭）；眼前盤子未清理時拉不下來
		var off := m - _press_pos
		var down := minf(off.y, PLATE_PULL_MAX) if eat_plate == null else minf(off.y * 0.15, PULL_BLOCKED_MAX)
		plate.position = _plate_origin + Vector2(off.x * 0.35, down)


## 桌上筆記本：只在抬頭畫面可點（以素材不透明像素判定）
func _notebook_hit(m: Vector2) -> bool:
	if looking_down or not world.visible:
		return false
	var p := notebook_item.to_local(m) + notebook_item.texture.get_size() * 0.5
	if not Rect2(Vector2.ZERO, notebook_item.texture.get_size()).has_point(p):
		return false
	return notebook_mask.get_pixelv(Vector2i(p)).a > 0.5


## 推離互動點：跟著眼前的盤子；空手且滑鼠靠近（或推盤中）時淡入
func _update_push_handle(m: Vector2) -> void:
	if eat_plate:
		push_handle.position = eat_plate.position + PUSH_HANDLE_OFFSET
		push_handle.empty_plate = eat_plate.foods.is_empty()
	var show := _drag_push or (eat_plate != null and looking_down and not view_switching and not has_fork and not eating \
		and not _drag_food and m.distance_to(push_handle.global_position) <= PUSH_HANDLE_NEAR)
	var k := minf(1.0, get_process_delta_time() / maxf(Engine.time_scale, 0.001) * 10.0)
	push_handle.modulate.a = lerpf(push_handle.modulate.a, 1.0 if show else 0.0, k)
	if not show and push_handle.modulate.a < 0.02:
		push_handle.modulate.a = 0.0
	push_handle.visible = push_handle.modulate.a > 0.0


# ───────────────────────── 階段與過敏原 ─────────────────────────

func _enter_stage(n: int) -> void:
	stage = n
	var pool := Assets.FOOD_TYPES.filter(func(t): return not allergens.has(t))
	var added: String = pool.pick_random()
	allergens.append(added)   # 新增過敏原立即生效（判定時即時查詢清單）
	_refresh_allergen_flags()
	_show_hint(NEW_ALLERGEN_HINTS.pick_random() % Assets.food_name(added))
	_stage_blink()
	if n == 2:
		_play_bgm(BGM_TENSE)
	elif n == 3:
		_play_bgm(BGM_STAGE3)   # 第三階段加深低頻並加快節奏


## 播放背景音樂：已有音樂時交叉淡化（以實際時間計，不受遊戲速度影響）
func _play_bgm(path: String) -> void:
	var old := bgm
	bgm = AudioStreamPlayer.new()
	bgm.stream = load(path)
	bgm.volume_db = BGM_VOLUME_DB if old == null else -40.0
	add_child(bgm)
	bgm.play()
	if old:
		var tw := create_tween().set_parallel(true).set_speed_scale(1.0 / maxf(Engine.time_scale, 0.001))
		tw.tween_property(bgm, "volume_db", BGM_VOLUME_DB, BGM_CROSSFADE)
		tw.tween_property(old, "volume_db", -40.0, BGM_CROSSFADE)
		tw.chain().tween_callback(old.queue_free)


## 依當下清單更新廚師持有、本輪料理及玩家盤上的 is_allergen；外觀不變
func _refresh_allergen_flags() -> void:
	if not held.is_empty():
		held.is_allergen = allergens.has(held.type)
	for it in output_slots:
		it.is_allergen = allergens.has(it.type)
	for p in [plate, eat_plate]:
		if p:
			for f in p.foods:
				f.is_allergen = allergens.has(f.food_type)


## 階段轉換：三次短眨眼（包含在 5 秒提示內），第三次閉眼時換場景與食材階段美術
func _stage_blink() -> void:
	stage_blinking = true
	for i in STAGE_BLINK_COUNT:
		await _lids(true, STAGE_BLINK_CLOSE)
		if i == STAGE_BLINK_COUNT - 1:
			art_stage = stage
			_apply_stage_visuals()
		await _lids(false, STAGE_BLINK_OPEN)
	stage_blinking = false


## 套用目前美術階段：場景、廚師、所有顯示中食材
func _apply_stage_visuals() -> void:
	bg.texture = Assets.kitchen(art_stage)
	table_fg.texture = bg.texture
	chef.refresh(art_stage)
	down_bg.texture = Assets.tex(DOWN_BG_STAGES[art_stage - 1])   # 低頭畫面各階段桌面素材
	for p in [plate, eat_plate]:
		if p:
			p.refresh(art_stage)
	for n in behind_table.get_children():
		if n is Plate:
			n.refresh(art_stage)
	var v: Vector2 = VIGNETTE[art_stage - 1]
	var mat := vignette.material as ShaderMaterial
	mat.set_shader_parameter("strength", v.x)
	mat.set_shader_parameter("red", v.y)


## 自言自語提示：底部停留 5 秒，期間鎖定玩家操作（手部仍跟隨）
func _show_hint(text: String) -> void:
	hint_active = true
	if _say_tw:
		_say_tw.kill()
	notebook.close()
	_cancel_drags()
	hint_label.text = text
	hint_panel.reset_size()
	hint_panel.position = Vector2((VIEW.x - hint_panel.size.x) * 0.5, VIEW.y - hint_panel.size.y - 120)
	var tw := create_tween()
	tw.tween_property(hint_panel, "modulate:a", 1.0, 0.3)
	tw.tween_interval(HINT_DURATION - 0.3)
	await tw.finished
	hint_active = false
	create_tween().tween_property(hint_panel, "modulate:a", 0.0, 0.4)


## 短句自言自語：與提示同樣的底部對話框，停留 SAY_DURATION 秒，不鎖定操作；正式提示顯示中則略過
func _say(text: String) -> void:
	if hint_active:
		return
	if _say_tw:
		_say_tw.kill()
	hint_label.text = text
	hint_panel.reset_size()
	hint_panel.position = Vector2((VIEW.x - hint_panel.size.x) * 0.5, VIEW.y - hint_panel.size.y - 120)
	_say_tw = create_tween()
	_say_tw.tween_property(hint_panel, "modulate:a", 1.0, 0.2)
	_say_tw.tween_interval(SAY_DURATION)
	_say_tw.tween_property(hint_panel, "modulate:a", 0.0, 0.4)


# ───────────────────────── 廚師流程 ─────────────────────────

func _wait(t: float) -> void:
	var tw := create_tween()
	tw.tween_interval(t)
	await tw.finished


func _play_cook(path: String) -> void:
	cook_sfx.stream = load(path)
	cook_sfx.play()


## 單次音效：各自獨立播放，可與其他音效重疊（如開冰箱與拿取食材）
func _play_sfx(path: String) -> void:
	var p := AudioStreamPlayer.new()
	p.stream = load(path)
	p.volume_db = COOK_VOLUME_DB
	add_child(p)
	p.finished.connect(p.queue_free)
	p.play()


## 取材（共 RESTOCK_TIME 秒）：冰箱＝開門 → 拿取 → 關門；架子＝拿取
func _restock_sfx(type: String, at_fridge: bool) -> void:
	var pick: String = "蔬菜輕拿" if VEGETABLES.has(type) else ("包裝沙沙" if at_fridge else "架上餐具碰響")
	if at_fridge:
		_play_sfx(FRIDGE_OPEN_SFX)
	await _wait(RESTOCK_TIME * 0.35)
	_play_sfx(PICK_SFX % pick)
	await _wait(RESTOCK_TIME * 0.65)
	if at_fridge:
		_play_sfx(FRIDGE_CLOSE_SFX)


func _chef_loop() -> void:
	while running:
		await _chef_round()


## 每次取材：從本輪未用種類中，15% 走過敏原分支、否則非過敏原分支；分支無候選時改用另一分支
func _pick_ingredient(used: Array[String]) -> String:
	var allergen_pool := allergens.filter(func(t): return not used.has(t))
	var safe_pool := Assets.FOOD_TYPES.filter(func(t): return not allergens.has(t) and not used.has(t))
	var use_allergen := randf() < ALLERGEN_CHANCE
	if use_allergen and allergen_pool.is_empty():
		use_allergen = false
	elif not use_allergen and safe_pool.is_empty():
		use_allergen = true
	return (allergen_pool if use_allergen else safe_pool).pick_random()


## 單份食材記錄：加工次數 1–3；前置步驟備料／烹煮等機率，最後一步固定烹煮。
## 顯示外觀（visual）與實際食材（type）分開保存，判定只看 type 與當下過敏原清單。
func _make_item(type: String) -> Dictionary:
	var required := randi_range(1, 3)
	var actions: Array[String] = []
	for k in required - 1:
		actions.append(["prep", "cook"].pick_random())
	actions.append("cook")
	return {"type": type, "is_allergen": allergens.has(type), "required": required, "completed": 0,
		"actions": actions, "complete": false, "slot": "", "visual": ""}


func _chef_round() -> void:
	# 1. 新一輪：抽本輪料理數 1..3
	var n := randi_range(1, STAGE_FOOD_CAP[stage - 1])
	output_slots = []
	var used_types: Array[String] = []
	var used_visuals: Array[String] = []

	for i in n:
		# 2. 逐項取材：一次只持有一項（取材時使用背面素材，之後頭頂圖標顯示 A 貼圖）
		var type := _pick_ingredient(used_types)
		used_types.append(type)
		var at_fridge := randf() >= 0.5
		await chef.move_to(STATIONS["fridge" if at_fridge else "shelf"])
		chef.set_pose("背面")
		await _restock_sfx(type, at_fridge)
		held = _make_item(type)
		chef.hold_food(type, art_stage)

		# 3. 先完成這項食材的全部加工步驟（加工時隱藏食材；不顯示頭頂圖標）
		while held.completed < held.required:
			var action: String = held.actions[held.completed]
			await chef.move_to(STATIONS["stove" if action == "cook" else "board"])
			chef.hide_held()
			chef.set_pose("烹煮" if action == "cook" else "切菜")
			chef.start_work()
			if action == "cook":
				_play_cook(COOK_SFX.pick_random())
			else:
				_play_cook(CHOP_SFX % CHOP_BY_TYPE.get(type, "快速連切"))
			await _wait(randf_range(STEP_TIME.x, STEP_TIME.y))
			chef.stop_work()
			cook_sfx.stop()
			held.completed += 1
			if held.completed < held.required:
				chef.hold_food(type, art_stage)
		held.complete = true

		# 4. 抽本輪未用的食物外觀（完成時不再端出成品，只播起鍋聲），並決定盤上的隨機空位
		var visual: String = Assets.DISH_VISUALS.filter(func(v): return not used_visuals.has(v)).pick_random()
		used_visuals.append(visual)
		held.visual = visual
		_play_cook(COOK_DONE_SFX)
		await _wait(0.6)
		var used_slots := output_slots.map(func(it): return it.slot)
		held.slot = Plate.ANCHOR_KEYS.filter(func(k): return not used_slots.has(k)).pick_random()
		output_slots.append(held)
		held = {}

	# 5. 上菜：廚師端起料理走到玩家面前；玩家盤沿用相同餐位與外觀
	await _wait(0.6)
	chef.set_pose("端取料理")
	await _wait(0.5)
	await chef.move_to(CHEF_HOME)
	chef.set_pose("端取料理")
	await _wait(0.5)
	await _serve(output_slots)
	output_slots = []

	# 6. 在玩家面前停留 1–4 秒
	await _wait(0.4)
	chef.set_pose("正面")
	await _wait(randf_range(LINGER_TIME.x, LINGER_TIME.y))


## 上菜到抬頭畫面的桌上：桌上若還有舊盤直接覆蓋；低頭時眼前正在吃的盤子不受影響
func _serve(items: Array) -> void:
	if plate:
		_drag_plate = false
		plate.queue_free()
		plate = null
	plate = Plate.new()
	plate.position = PLATE_POS + Vector2(0, -24)
	plate.modulate.a = 0.0
	plate_layer.add_child(plate)
	for it in items:
		plate.add_item(it, art_stage)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(plate, "position", PLATE_POS, 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(plate, "modulate:a", 1.0, 0.25)
	await tw.finished


## 上下眼瞼開合
func _lids(close: bool, t: float) -> void:
	var h := VIEW.y * 0.5 + 4.0 if close else 0.0
	var tw := create_tween().set_parallel(true)
	tw.tween_property(lid_top, "size:y", h, t).set_trans(Tween.TRANS_SINE)
	tw.tween_property(lid_bottom, "size:y", h, t).set_trans(Tween.TRANS_SINE)
	tw.tween_property(lid_bottom, "position:y", VIEW.y - h, t).set_trans(Tween.TRANS_SINE)
	await tw.finished


# ───────────────────────── 玩家操作 ─────────────────────────

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var speed := {KEY_1: 1.0, KEY_2: 2.0, KEY_3: 3.0, KEY_KP_1: 1.0, KEY_KP_2: 2.0, KEY_KP_3: 3.0}
		if speed.has(event.keycode):
			_set_speed(speed[event.keycode])
		elif event.keycode == KEY_T and started and running:
			_apply_eat(true)   # 測試用：T 鍵等於吃下一次過敏原
		elif event.keycode == KEY_SPACE and not _locked():
			_set_view(not looking_down)   # 空白鍵：切換抬頭／低頭（同右側按鈕）
	if _sim:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_press(_mouse())
		else:
			_release(_mouse())
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		_right_press(_mouse())


## 數字鍵 1/2/3：遊戲運行速度 100% / 200% / 300%
func _set_speed(s: float) -> void:
	Engine.time_scale = s
	speed_label.text = "速度 %d%%" % int(s * 100)
	speed_label.visible = s != 1.0


func _locked() -> bool:
	return not started or not running or hint_active or view_switching or eating or notebook.is_open


func _press(m: Vector2) -> void:
	if notebook.is_open:                     # 筆記本打開時：點擊任一處關閉
		notebook.close()
		return
	if _locked():
		return
	if view_button.hit(m):                   # 右側箭頭按鈕：切換抬頭／低頭
		_set_view(not looking_down)
		return
	if _notebook_hit(m):                     # 抬頭：點桌上的筆記本打開
		notebook.open(allergens.map(func(t): return Assets.food_name(t)))
		return
	if looking_down:
		# 低頭：空手按住盤子左側互動點 → 往右推離；叉子只在此畫面，握叉才能拖食物進食
		if not has_fork and eat_plate and push_handle.visible and push_handle.hit(m):
			_drag_push = true
			_press_pos = m
			_plate_origin = eat_plate.position
			_set_hand("rest", true)
			return
		if not has_fork and fork.visible and fork_rect.has_point(m):
			has_fork = true                  # 左鍵拾取：桌上叉子消失，手部改為握叉
			fork.visible = false
			_set_hand("fork")
			return
		if has_fork and eat_plate:
			var f := eat_plate.food_at(m)
			if f:
				_drag_food = f
				f.z_index = 5
				f.global_position = m
	elif plate and plate.contains(m):        # 抬頭：空手抓盤，往上推盤或往下拉到眼前
		_drag_plate = true
		_press_pos = m
		_plate_origin = plate.position


## 右鍵：在畫面右下象限（x ≥ 50% 且 y ≥ 50%）任意位置放回叉子，手部切回空手
func _right_press(m: Vector2) -> void:
	if notebook.is_open:
		notebook.close()
		return
	if _locked() or not has_fork or _drag_food:
		return
	if m.x >= VIEW.x * 0.5 and m.y >= VIEW.y * 0.5:
		has_fork = false
		fork.visible = true
		_set_hand("rest")


func _release(m: Vector2) -> void:
	if _drag_food:
		var f := _drag_food
		_drag_food = null
		if _in_eat_zone(m):
			_eat(f)
		else:
			var tw := f.create_tween()
			tw.tween_property(f, "position", f.anchor, 0.15).set_ease(Tween.EASE_OUT)
			tw.tween_callback(func(): f.z_index = 0)
	elif _drag_push:
		_drag_push = false
		_set_hand("rest")
		if eat_plate and eat_plate.position.x - _plate_origin.x >= PUSH_AWAY_DIST:
			_push_away()
		elif eat_plate:
			eat_plate.create_tween().tween_property(eat_plate, "position", _plate_origin, 0.2).set_ease(Tween.EASE_OUT)
	elif _drag_plate:
		_drag_plate = false
		if plate and _plate_origin.y - plate.position.y >= PLATE_PUSH_DIST:
			_push_plate()
		elif plate and eat_plate == null and plate.position.y - _plate_origin.y >= PLATE_PULL_DIST:
			_pull_plate_down()
		elif plate:
			plate.create_tween().tween_property(plate, "position", _plate_origin, 0.2).set_ease(Tween.EASE_OUT)
		if plate and eat_plate and m.y - _press_pos.y >= PLATE_PULL_DIST:
			_say(PULL_BLOCKED_SAY)


## 提示出現或清盤時：拖曳中的物件立即回到拖曳前位置，盤上食物不變
func _cancel_drags() -> void:
	if _drag_food:
		if is_instance_valid(_drag_food):
			_drag_food.position = _drag_food.anchor
			_drag_food.z_index = 0
		_drag_food = null
	if _drag_plate:
		_drag_plate = false
		if plate:
			plate.position = _plate_origin
	if _drag_push:
		_drag_push = false
		_set_hand("fork" if has_fork else "rest")
		if eat_plate:
			eat_plate.position = _plate_origin


## 吃下一口：整盤只要有任一過敏原食材（含已吃掉的），吃盤上任何食物都算吃到過敏原。
## 依隱藏食材與當下清單判定，外觀不參與；咀嚼 EAT_DURATION 秒後才結算，期間鎖定操作
func _eat(f: FoodSprite) -> void:
	_eat_bad = eat_plate_types.any(func(t): return allergens.has(t))
	chew_sfx.stream = load(CHEW_SFX % CHEW_BY_DISH.get(f.visual_id, "多汁柔軟"))
	chew_sfx.play()
	eat_plate.remove_food(f)
	eating = true
	eat_time = 0.0
	eat_ring.remaining = 1.0
	eat_ring.visible = true


## 進食結果：飢餓值增減；第一次吃到過敏原進入瀕死狀態（T 鍵測試共用）
func _apply_eat(bad: bool) -> void:
	hunger = clampf(hunger + (-HUNGER_STEP if bad else HUNGER_STEP), 0.0, HUNGER_MAX)
	if bad:
		allergen_hits += 1
		var tw := create_tween()
		tw.tween_property(red_flash, "color:a", 0.35, 0.08)
		tw.tween_property(red_flash, "color:a", 0.0, 0.6)
		_shake()
		if allergen_hits >= 2:
			_game_over()   # 第二次吃下過敏原：直接結束
			return
		_enter_near_death()
	if hunger <= 0.0:
		_game_over()


## 瀕死狀態（第一次吃到過敏原）：常駐紅色濾鏡，周邊暗紅血管每 1.5 秒跳動一次並播放心跳聲。
## 特效不受遊戲速度（1/2/3 鍵）影響，維持實際時間的節奏。
func _enter_near_death() -> void:
	if near_death:
		return
	near_death = true
	near_death_time = 0.0
	near_death_tint.modulate.a = 0.0
	near_death_tint.visible = true


## 瀕死特效逐幀更新：以實際時間（delta 除以遊戲速度）推進，故 2/3 倍速時節奏不變
func _update_near_death(delta: float) -> void:
	if not near_death:
		return
	var real_dt := delta / maxf(Engine.time_scale, 0.001)
	var prev := near_death_time
	near_death_time += real_dt
	# 紅色濾鏡與周邊血管 0.6 秒淡入後常駐
	var fade_in := clampf(near_death_time / NEAR_DEATH_FADE_IN, 0.0, 1.0)
	near_death_tint.modulate.a = fade_in
	heartbeat.modulate.a = fade_in
	# 心跳：加深蔓延（HEARTBEAT_IN）→ 退回（HEARTBEAT_OUT）→ 停頓，週期 HEARTBEAT_PERIOD
	var phase := fmod(near_death_time, HEARTBEAT_PERIOD)
	var pulse := 0.0
	if phase < HEARTBEAT_IN:
		pulse = _ease_sine(phase / HEARTBEAT_IN)
	elif phase < HEARTBEAT_IN + HEARTBEAT_OUT:
		pulse = 1.0 - _ease_sine((phase - HEARTBEAT_IN) / HEARTBEAT_OUT)
	heartbeat.material.set_shader_parameter("pulse", pulse * HEARTBEAT_PEAK)
	# 心跳聲：每拍在 HEARTBEAT_SFX_DELAY 時播放一次
	var prev_phase := fmod(prev, HEARTBEAT_PERIOD)
	var crossed := prev_phase < HEARTBEAT_SFX_DELAY and phase >= HEARTBEAT_SFX_DELAY
	if crossed or (phase < prev_phase and phase >= HEARTBEAT_SFX_DELAY):
		heartbeat_sfx.play()


func _ease_sine(x: float) -> float:
	return 0.5 - 0.5 * cos(PI * x)


func _shake() -> void:
	var tw := create_tween()
	for i in 6:
		tw.tween_property(stage_root, "position", Vector2(randf_range(-10, 10), randf_range(-8, 8)), 0.04)
	tw.tween_property(stage_root, "position", Vector2.ZERO, 0.05)


## 低頭推盤：眼前的盤子往右滑出桌面；清掉後才能再把抬頭桌上的盤子拉到眼前
func _push_away() -> void:
	var p := eat_plate
	eat_plate = null
	var tw := p.create_tween().set_parallel(true)
	tw.tween_property(p, "position:x", VIEW.x + 500.0, 0.45).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(p, "rotation", 0.35, 0.45).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(p.queue_free)


## 抬頭畫面的盤子往下拉：移到低頭畫面成為眼前的盤子，並低頭（眼前已有盤子時不會觸發）
func _pull_plate_down() -> void:
	var items := plate.foods.map(func(f): return {"type": f.food_type, "visual": f.visual_id, "slot": f.slot_id, "is_allergen": f.is_allergen})
	plate.queue_free()
	plate = null
	if eat_plate:
		eat_plate.queue_free()
	eat_plate = Plate.new()
	eat_plate.width = DOWN_PLATE_WIDTH
	eat_plate.position = DOWN_PLATE_POS
	down_plate_layer.add_child(eat_plate)
	eat_plate_types.clear()
	for it in items:
		eat_plate.add_item(it, art_stage)
		eat_plate_types.append(it.type)
	_set_view(true)


## 抬頭／低頭切換：視線往下時廚房往上移出、桌面特寫由下方捲入（反之亦然）
func _set_view(down: bool) -> void:
	if view_switching or down == looking_down:
		return
	view_switching = true
	_cancel_drags()
	if not down and has_fork:                # 叉子只在低頭畫面：抬頭時自動放回桌上
		has_fork = false
		fork.visible = true
		_set_hand("rest")
	looking_down = down
	view_button.set_arrow_down(not down)
	down_view.visible = true
	world.visible = true
	var shift := -VIEW.y if down else 0.0
	var tw := create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(world, "position:y", shift, VIEW_SWITCH_TIME)
	tw.tween_property(down_view, "position:y", shift + VIEW.y, VIEW_SWITCH_TIME)
	await tw.finished
	world.visible = not down
	down_view.visible = down
	view_switching = false


## 推盤：盤子越過桌沿落向廚房地板，被桌面遮住
func _push_plate() -> void:
	var p := plate
	plate = null
	var gp := p.global_position
	plate_layer.remove_child(p)
	behind_table.add_child(p)
	p.global_position = gp
	var tw := p.create_tween()
	tw.set_parallel(true)
	tw.tween_property(p, "position:y", gp.y - 70, 0.18).set_ease(Tween.EASE_OUT)
	tw.tween_property(p, "scale", Vector2(0.85, 0.85), 0.18)
	tw.chain().set_parallel(true)
	tw.tween_property(p, "position:y", VIEW.y + 300, 0.5).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(p, "rotation", randf_range(-0.6, 0.6), 0.5)
	tw.chain().tween_callback(p.queue_free)


func _game_over() -> void:
	if not running:
		return
	running = false
	started = false
	_cancel_drags()
	_set_speed(1.0)
	eating = false
	notebook.close()
	var survived := int(elapsed)
	# 畫面漸黑至全黑，聲音一併淡出
	var tw := create_tween()
	tw.tween_property(fade, "color:a", 1.0, GAME_OVER_FADE)
	tw.parallel().tween_property(heartbeat_sfx, "volume_db", -40.0, GAME_OVER_FADE)
	tw.parallel().tween_property(bgm, "volume_db", -40.0, GAME_OVER_FADE)
	tw.parallel().tween_property(chew_sfx, "volume_db", -40.0, GAME_OVER_FADE)
	tw.parallel().tween_property(cook_sfx, "volume_db", -40.0, GAME_OVER_FADE)
	await tw.finished
	# 結束畫面：打字機結語＋「我還想吃更多...」再玩一次
	has_fork = false
	_set_hand("rest")   # 隱藏手臂、顯示系統游標
	var end := EndScreen.new()
	add_child(end)
	if not _sim:
		end.retry.connect(func():
			from_retry = true
			get_tree().reload_current_scene())
	await end.play(survived)
	if _sim:
		DebugShot.save(get_viewport(), "zz_gameover")
		await _sleep(1.0)
		var p := end.retry_label.get_global_rect().get_center()
		end.hovered = true
		await _sleep(0.2)
		DebugShot.save(get_viewport(), "zz_gameover_hover")
		print("end screen: text=", end.message.text.replace("\n", " / "), " retry at=", p, " color=", end.retry_label.get_theme_color("font_color"))
		end.retry.connect(func(): print("retry emitted"))
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = true
		end._on_retry_input(click)
		await _debug_intro()
		get_tree().quit()


# ───────────────────────── 測試用自動流程（--shot） ─────────────────────────


func _sleep(t: float) -> void:
	await get_tree().create_timer(t).timeout


func _fast_until(cond: Callable, scale := 6.0) -> void:
	Engine.time_scale = scale
	while not cond.call():
		await get_tree().process_frame
	Engine.time_scale = 1.0


## 前導字幕：開始版與重來版各跑一次，中途模擬左鍵跳句
func _debug_intro() -> void:
	Engine.time_scale = 1.0
	for retry in [false, true]:
		var intro := Intro.new()
		add_child(intro)
		var shown := []
		intro.play(retry)
		await _sleep(0.5)
		DebugShot.save(get_viewport(), "zz_intro_%s_typing" % ("retry" if retry else "start"))
		print("intro typing: line=", intro.index, " chars=", intro.label.visible_characters, "/", intro.label.get_total_character_count())
		while intro.index < intro._lines.size():
			shown.append(intro.label.text)
			if intro.index == intro._lines.size() - 1:
				await _sleep(0.8)
				DebugShot.save(get_viewport(), "zz_intro_%s_last" % ("retry" if retry else "start"))
				print("intro last color=", intro.label.get_theme_color("font_color"))
			var i := intro.index
			intro.skip()
			while intro.index == i:
				await get_tree().process_frame
		print("intro retry=", retry, " lines=", shown)
		await intro.finished


func _debug_run() -> void:
	var vp := get_viewport()
	await _sleep(1.5)
	DebugShot.save(vp, "01_opening_hint")
	print("bgm=", bgm.stream.resource_path.get_file(), " loop=", bgm.stream.loop_mode, " playing=", bgm.playing, " len=", bgm.stream.get_length())
	print("allergens=", allergens)
	while not started:
		await get_tree().process_frame
	await _sleep(0.3)
	DebugShot.save(vp, "02_hand_rest")
	# 指標不能超過桌子上緣；數字鍵速度
	_sim_mouse = Vector2(900, 300)
	print("pointer clamp y=", _mouse().y, " table edge=", TABLE_EDGE_SRC * BG_SCALE, " plate top=", PLATE_POS.y - 470 * 0.349)
	var ev := InputEventKey.new()
	ev.pressed = true
	ev.keycode = KEY_2
	_input(ev)
	print("key2 time_scale=", Engine.time_scale, " label=", speed_label.text, " visible=", speed_label.visible)
	await _sleep(0.6)
	DebugShot.save(vp, "02b_speed_hand_clamp")
	ev.keycode = KEY_3
	_input(ev)
	print("key3 time_scale=", Engine.time_scale)
	ev.keycode = KEY_1
	_input(ev)
	print("key1 time_scale=", Engine.time_scale, " label visible=", speed_label.visible)
	# 抬頭畫面看不到叉子（叉子在低頭畫面）
	_sim_mouse = FORK_POS
	_press(_sim_mouse)
	print("up view: fork pickable=", has_fork, " looking_down=", looking_down, " hand visible=", hand.visible, " pointer y at top=", _mouse().y)
	_sim_mouse = Vector2(900, 900)
	await _fast_until(func(): return not held.is_empty(), 4.0)
	print("held=", held.type, " steps=", held.required, " actions=", held.actions, " chef holding visible=", chef._held.visible)
	await _sleep(0.3)
	DebugShot.save(vp, "03_chef_holding")
	await _fast_until(func(): return chef._walking and chef._held.visible, 4.0)
	await _sleep(0.35)
	DebugShot.save(vp, "03b_walking_held_" + chef._pose)
	print("walking pose=", chef._pose, " held visible=", chef._held.visible)
	await _fast_until(func(): return chef._working, 4.0)
	await _sleep(0.3)
	var sfx_paths := [FRIDGE_OPEN_SFX, FRIDGE_CLOSE_SFX, COOK_DONE_SFX] + COOK_SFX
	for k in ["多汁食材", "清脆蔬菜", "快速連切"]: sfx_paths.append(CHOP_SFX % k)
	for k in ["蔬菜輕拿", "包裝沙沙", "架上餐具碰響"]: sfx_paths.append(PICK_SFX % k)
	for k in ["多汁柔軟", "清脆蔬菜", "酥脆餅乾"]: sfx_paths.append(CHEW_SFX % k)
	print("sfx check: ", sfx_paths.size(), " paths, missing=", sfx_paths.filter(func(p): return load(p) == null))
	print("working: held visible=", chef._held.visible, " cook sfx=", cook_sfx.stream.resource_path.get_file() if cook_sfx.stream else "-", " playing=", cook_sfx.playing, " loop=", cook_sfx.stream.loop_mode if cook_sfx.stream else -1, " action=", held.actions[held.completed])
	DebugShot.save(vp, "04_chef_working")
	# 砧板切菜姿勢：第一／第二階段（臨時廚師，不影響流程）
	var cut := Chef.new()
	cut.position = STATIONS["board"]
	chef.add_sibling(cut)   # 緊接在廚師之後，仍在桌面前景之下
	cut.set_pose("切菜")
	cut.refresh(1)
	await _sleep(0.3)
	print("cut pose stage1=", cut._active.texture.resource_path.get_file())
	DebugShot.save(vp, "04b_chef_cut_stage1")
	cut.refresh(2)
	await _sleep(0.4)
	print("cut pose stage2=", cut._active.texture.resource_path.get_file(), " stage3=", Assets.chef("切菜", 3).resource_path.get_file())
	DebugShot.save(vp, "04c_chef_cut_stage2")
	cut.queue_free()
	await _fast_until(func(): return not output_slots.is_empty(), 6.0)
	print("dish done: chef holding visible=", chef._held.visible, " cook sfx=", cook_sfx.stream.resource_path.get_file())
	DebugShot.save(vp, "05_chef_dish_done")
	var tray_record := []
	while plate == null or plate.modulate.a < 1.0:
		if not output_slots.is_empty():
			tray_record = output_slots.map(func(x): return "%s/%s/%s" % [x.slot, x.visual, x.type])
		Engine.time_scale = 6.0
		await get_tree().process_frame
	Engine.time_scale = 1.0
	DebugShot.save(vp, "06_plate_served")
	print("round =", tray_record)
	print("plate =", plate.foods.map(func(x): return "%s/%s/%s" % [x.slot_id, x.visual_id, x.food_type]))
	# 抬頭時空手點盤上食物：只會抓盤，不會進食
	var n_up := plate.foods.size()
	_sim_mouse = plate.foods[0].global_position
	_press(_sim_mouse)
	_sim_mouse = Vector2(960, 1040)
	_release(_sim_mouse)
	await _sleep(0.3)
	print("up view no eating: foods ", n_up, " -> ", plate.foods.size() if plate else -1, " looking_down=", looking_down)
	# 桌上筆記本：點擊打開，記載目前過敏原；再點任一處關閉
	_sim_mouse = NOTEBOOK_POS
	await _sleep(0.1)
	print("notebook hover hit=", _notebook_hit(_sim_mouse), " modulate=", notebook_item.modulate)
	DebugShot.save(vp, "06b_notebook_hover")
	_press(_sim_mouse)
	await _sleep(0.4)
	print("notebook open=", notebook.is_open, " text=", notebook.entries.text.replace("
", " "), " locked=", _locked())
	DebugShot.save(vp, "06c_notebook_open")
	_press(Vector2(1500, 300))
	await _sleep(0.4)
	print("notebook closed=", not notebook.is_open, " visible=", notebook.visible, " plate still=", plate != null)
	_press(Vector2(250, 300))
	print("click off notebook opens=", notebook.is_open)
	# 把盤子往下拉 → 低頭
	_sim_mouse = plate.global_position + Vector2(-60, 0)
	_press(_sim_mouse)
	_sim_mouse += Vector2(0, 200)
	await _sleep(0.2)
	DebugShot.save(vp, "07a_pulling_plate")
	_release(_sim_mouse)
	await _sleep(0.2)
	DebugShot.save(vp, "07b_view_switching")
	await _fast_until(func(): return not view_switching)
	print("after pull: looking_down=", looking_down, " up plate=", plate, " eat_plate foods=", eat_plate.foods.size() if eat_plate else -1, " arrow_down=", view_button.arrow_down)
	_sim_mouse = Vector2(1300, 900)
	await _sleep(0.1)
	DebugShot.save(vp, "07c_look_down")
	# 低頭：拿叉子、靜置鬆開不進食、拖到進食區進食
	_sim_mouse = fork.position
	_press(_sim_mouse)
	print("down view: has_fork=", has_fork, " hand visible=", hand.visible)
	_sim_mouse = Vector2(960, 200)
	print("fork pointer clamp y=", _mouse().y, " arm bottom=", _mouse().y - HAND_TIP["fork"].y * HAND_SCALE + hand_info["fork"].used.end.y * HAND_SCALE)
	await _sleep(0.15)
	DebugShot.save(vp, "07c2_fork_at_top")
	var f: FoodSprite = eat_plate.foods[0]
	_sim_mouse = f.global_position
	_press(_sim_mouse)
	_release(_sim_mouse)
	print("release at rest -> foods=", eat_plate.foods.size())
	await _sleep(0.3)
	f = eat_plate.foods[0]
	_sim_mouse = f.global_position
	_press(_sim_mouse)
	_sim_mouse = Vector2(960, 1040)
	await _sleep(0.3)
	DebugShot.save(vp, "07d_dragging_food")
	var before := hunger
	_release(_sim_mouse)
	var expect_bad := eat_plate_types.any(func(t): return allergens.has(t))
	print("eating: locked=", _locked(), " ring=", eat_ring.visible, " hunger unchanged=", hunger == before, " plate types=", eat_plate_types, " plate lethal=", _eat_bad, " expected=", expect_bad)
	print("chew sfx=", chew_sfx.stream.resource_path.get_file(), " playing=", chew_sfx.playing, " dish=", f.visual_id if is_instance_valid(f) else "?")
	var sp := InputEventKey.new()
	sp.keycode = KEY_SPACE
	sp.pressed = true
	_input(sp)
	print("space while eating: switching=", view_switching, " looking_down=", looking_down)
	await _sleep(1.5)
	DebugShot.save(vp, "07d2_eating_ring")
	_right_press(Vector2(1700, 600))
	print("mid-eat right-click ignored: has_fork=", has_fork, " ring remaining=", eat_ring.remaining)
	await _fast_until(func(): return not eating, 1.0)
	print("eaten: near_death=", near_death, " hunger ", before, " -> ", hunger, " hits=", allergen_hits, " eat_plate foods=", eat_plate.foods.size(), " ring=", eat_ring.visible)
	var sp2 := InputEventKey.new()
	sp2.keycode = KEY_SPACE
	sp2.pressed = true
	_input(sp2)
	await _fast_until(func(): return not view_switching)
	print("space -> looking_down=", looking_down)
	_input(sp2)
	await _fast_until(func(): return not view_switching)
	print("space -> looking_down=", looking_down)
	allergen_hits = 0   # 測試用：後段另行驗證過敏原次數
	await _sleep(0.5)
	_right_press(Vector2(300, 900))
	print("right-click outside quadrant has_fork=", has_fork)
	_right_press(Vector2(1700, 600))
	print("right-click in bottom-right quadrant has_fork=", has_fork, " fork.visible=", fork.visible)
	# 再拿起叉子，點右側按鈕抬頭 → 叉子自動放回
	_sim_mouse = fork.position
	_press(_sim_mouse)
	_sim_mouse = VIEW_BUTTON_POS
	await _sleep(0.1)
	DebugShot.save(vp, "07e_button_hover_down")
	_press(_sim_mouse)
	await _fast_until(func(): return not view_switching)
	print("button -> looking_down=", looking_down, " has_fork=", has_fork, " arrow_down=", view_button.arrow_down, " hand visible=", hand.visible)
	await _sleep(0.1)
	DebugShot.save(vp, "07f_look_up_again")
	# 低頭時上菜：新盤上到抬頭的桌上，不影響眼前的盤子
	_sim_mouse = VIEW_BUTTON_POS
	_press(_sim_mouse)
	await _fast_until(func(): return not view_switching)
	var eat_id := eat_plate.get_instance_id()
	var eat_n := eat_plate.foods.size()
	await _fast_until(func(): return plate != null and plate.modulate.a >= 1.0)
	print("served while down: up plate foods=", plate.foods.size(), " eat_plate same=", eat_plate.get_instance_id() == eat_id, " foods ", eat_n, "->", eat_plate.foods.size(), " looking_down=", looking_down)
	await _debug_view(false)
	# 舊盤仍在桌上時上菜：直接覆蓋
	var up_id := plate.get_instance_id()
	await _fast_until(func(): return plate != null and plate.get_instance_id() != up_id and plate.modulate.a >= 1.0)
	print("served over old up plate: replaced=", plate.get_instance_id() != up_id, " plates in layer=", plate_layer.get_child_count())
	# 眼前盤子未清理：抬頭的盤子拉不下來
	_sim_mouse = plate.global_position + Vector2(-60, 0)
	_press(_sim_mouse)
	_sim_mouse += Vector2(0, 400)
	await _sleep(0.1)
	print("blocked pull: plate dy=", plate.position.y - _plate_origin.y)
	_release(_sim_mouse)
	await _sleep(0.3)
	print("blocked pull: looking_down=", looking_down, " up plate still=", plate != null, " say=", hint_label.text, " alpha=", snappedf(hint_panel.modulate.a, 0.01), " locked=", _locked())
	DebugShot.save(vp, "08b_blocked_pull_say")
	# 低頭：盤子左側互動點，按住往右推離
	await _debug_view(true)
	_sim_mouse = Vector2(1300, 700)
	await _sleep(0.3)
	print("handle far: visible=", push_handle.visible)
	_sim_mouse = eat_plate.global_position + PUSH_HANDLE_OFFSET + Vector2(60, 40)
	await _sleep(0.4)
	print("handle near: alpha=", push_handle.modulate.a, " text=", push_handle.label.text, " foods=", eat_plate.foods.size(), " hand visible=", hand.visible, " rest pointer top=", _rest_pointer_top)
	DebugShot.save(vp, "07g_push_handle_hover")
	var saved_foods := eat_plate.foods.duplicate()
	eat_plate.foods.clear()   # 模擬空盤：只看文案，不移除實際節點
	await _sleep(0.1)
	print("handle empty plate: text=", push_handle.label.text)
	DebugShot.save(vp, "07g2_push_handle_empty")
	eat_plate.foods = saved_foods
	await _sleep(0.1)
	_sim_mouse = push_handle.global_position
	_press(_sim_mouse)
	print("push press: drag=", _drag_push, " hand visible=", hand.visible)
	_sim_mouse += Vector2(150, 0)
	await _sleep(0.2)
	DebugShot.save(vp, "07h_pushing")
	_release(_sim_mouse)
	await _sleep(0.3)
	print("short push: eat_plate kept=", eat_plate != null, " x=", eat_plate.position.x, " hand visible=", hand.visible)
	_sim_mouse = push_handle.global_position
	_press(_sim_mouse)
	_sim_mouse += Vector2(-200, 0)
	await _sleep(0.1)
	print("push left: x=", eat_plate.position.x)
	_sim_mouse += Vector2(600, 0)
	await _sleep(0.15)
	DebugShot.save(vp, "07i_pushing_far")
	_release(_sim_mouse)
	await _sleep(0.6)
	print("pushed away: eat_plate=", eat_plate, " layer children=", down_plate_layer.get_child_count(), " handle visible=", push_handle.visible)
	DebugShot.save(vp, "07j_table_cleared")
	await _debug_view(false)
	_sim_mouse = plate.global_position + Vector2(-60, 0)
	_press(_sim_mouse)
	_sim_mouse += Vector2(0, 200)
	await _sleep(0.1)
	_release(_sim_mouse)
	await _fast_until(func(): return not view_switching)
	print("pull after clear: looking_down=", looking_down, " eat_plate foods=", eat_plate.foods.size() if eat_plate else -1)
	await _debug_view(false)
	await _fast_until(func(): return plate != null and plate.modulate.a >= 1.0)
	# 抬頭推盤
	if plate:
		_sim_mouse = plate.global_position + Vector2(-60, 0)
		_press(_sim_mouse)
		_sim_mouse += Vector2(0, -600)
		await _sleep(0.2)
		DebugShot.save(vp, "08_dragging_plate")
		_release(_sim_mouse)
		await _sleep(0.25)
		print("plate after push=", plate, " looking_down=", looking_down)
	elapsed = 119.9
	while stage < 2:
		await get_tree().process_frame
	await _sleep(1.4)
	DebugShot.save(vp, "09_stage2_hint")
	await _sleep(1.2)
	print("stage2 bgm=", bgm.stream.resource_path.get_file(), " loop=", bgm.stream.loop_mode, " vol=", bgm.volume_db, " players=", get_children().filter(func(c): return c is AudioStreamPlayer).size())
	await _debug_view(true)
	print("stage2 down bg=", down_bg.texture.resource_path.get_file(), " modulate=", down_bg.modulate)
	DebugShot.save(vp, "09b_stage2_down")
	await _debug_view(false)
	print("stage=", stage, " art_stage=", art_stage, " allergens=", allergens)
	elapsed = 239.9
	while stage < 3:
		await get_tree().process_frame
	await _sleep(1.4)
	print("stage=", stage, " art_stage=", art_stage, " allergens=", allergens)
	await _fast_until(func(): return output_slots.size() >= 1)
	await _sleep(0.2)
	DebugShot.save(vp, "10_stage3_cooking")
	var old_id := plate.get_instance_id() if plate else 0
	await _fast_until(func(): return plate != null and plate.get_instance_id() != old_id and plate.modulate.a >= 1.0)
	_sim_mouse = Vector2(1300, 900)
	await _sleep(0.1)
	DebugShot.save(vp, "11_stage3_plate")
	await _debug_view(true)
	print("stage3 down bg=", down_bg.texture.resource_path.get_file())
	DebugShot.save(vp, "11b_stage3_down")
	await _debug_view(false)
	print("stage3 plate=", plate.foods.map(func(x): return "%s/%s/%s/allergen=%s" % [x.slot_id, x.visual_id, x.food_type, x.is_allergen]))
	var rounds := 0
	var counts := []
	while rounds < 6:
		var old := plate
		var rec := 0
		Engine.time_scale = 8.0
		while plate == old:
			if not output_slots.is_empty():
				rec = output_slots.size()
			await get_tree().process_frame
		while plate == null:
			await get_tree().process_frame
		counts.append(plate.foods.size())
		rounds += 1
	Engine.time_scale = 1.0
	print("round sizes=", counts)
	# 過敏原：第一次 → 紅色濾鏡＋心跳白光；第二次 → 遊戲結束
	await _fast_until(func(): return plate != null and plate.modulate.a >= 1.0)
	hunger = HUNGER_MAX
	_apply_eat(true)
	print("near-death 1: hits=", allergen_hits, " running=", running, " tint=", near_death_tint.visible)
	await _sleep(0.75)
	DebugShot.save(vp, "12_near_death_tint")
	var peak := 0.0
	_set_speed(3.0)   # 瀕死特效不隨遊戲速度加速：以實際時間量測拍距
	var t0 := Time.get_ticks_msec()
	var beats := []
	var was_high := false
	var frames := 0
	while Time.get_ticks_msec() - t0 < 4600:
		frames += 1
		var a: float = heartbeat.material.get_shader_parameter("pulse")
		if a > 0.95 and not was_high:
			beats.append("%d/%.2f" % [Time.get_ticks_msec() - t0, near_death_time])
		was_high = a > 0.95
		peak = maxf(peak, a)
		await get_tree().process_frame
	_set_speed(1.0)
	print("heartbeat (3x speed) peak=", peak, " beat times real ms/nd_time=", beats, " frames=", frames, " sfx stream=", heartbeat_sfx.stream.get_length(), "s playing=", heartbeat_sfx.playing)
	var tk := InputEventKey.new()
	tk.pressed = true
	tk.keycode = KEY_T
	_input(tk)   # 第二次改用 T 鍵測試
	print("near-death 2: hits=", allergen_hits, " running=", running, " hunger=", hunger)


func _debug_view(down: bool) -> void:
	await _fast_until(func(): return not _locked())
	_set_view(down)
	await _fast_until(func(): return not view_switching)
	print("view -> looking_down=", looking_down)
