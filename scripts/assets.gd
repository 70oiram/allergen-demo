extends Node
## 素材載入與快取。路徑對應《食材素材命名規格》：食材名稱-A或B-階段編號.png

const FOOD_TYPES: Array[String] = ["雞蛋", "培根", "香腸", "小麥麵團吐司", "馬鈴薯", "番茄", "蘑菇", "雞肉", "鮭魚", "蝦"]
const FOOD_NAMES := {"小麥麵團吐司": "吐司"}
## 上菜外觀（只代表顯示，與實際食材無關）：食物-名稱-階段.png
const DISH_VISUALS: Array[String] = ["奶油雞肉燉飯", "燉牛肉", "番茄焗烤通心麵", "番茄燉蔬菜", "番茄燉豆"]
const STAGE_NAMES := ["第一", "第二", "第三"]
const MENU_FRAME_COUNT := 11

var _cache := {}


func tex(path: String) -> Texture2D:
	if not _cache.has(path):
		_cache[path] = load(path)
	return _cache[path]


## cooked = false → A（未烹煮），true → B（已烹煮）；stage = 1..3
func food(type: String, cooked: bool, stage: int) -> Texture2D:
	return tex("res://assets/食材/%s-%s-%d.png" % [type, "B" if cooked else "A", stage])


func dish(visual: String, stage: int) -> Texture2D:
	return tex("res://assets/食物外觀/食物-%s-%d.png" % [visual, stage])


func food_name(type: String) -> String:
	return FOOD_NAMES.get(type, type)


## 廚師：多數姿勢只有第一階段定稿、所有階段共用；切菜有第一／第二階段（第三階段沿用第二階段）
const CHEF_STAGED_POSES := ["切菜"]

func chef(pose: String, stage := 1) -> Texture2D:
	var s := mini(stage, 2) if CHEF_STAGED_POSES.has(pose) else 1
	return tex("res://assets/角色素材/廚師-%s階段-%s.png" % [STAGE_NAMES[s - 1], pose])


func kitchen(stage: int) -> Texture2D:
	return tex("res://assets/場景素材/廚房背景-%s階段.png" % STAGE_NAMES[stage - 1])


func menu_frame(i: int) -> Texture2D:
	return tex("res://assets/場景素材/主選單樹影/frame_%02d.jpg" % i)


func preload_game() -> void:
	for t in FOOD_TYPES:
		for s in range(1, 4):
			food(t, false, s)
			food(t, true, s)
	for v in DISH_VISUALS:
		for s in range(1, 4):
			dish(v, s)
	for p in ["正面", "背面", "左側", "右側", "烹煮", "端取料理"]:
		chef(p)
	for s in range(1, 4):
		chef("切菜", s)
	for s in range(1, 4):
		kitchen(s)
	for s in ["", "-第二階段", "-第三階段"]:
		tex("res://assets/場景素材/桌面特寫-低頭視角%s.png" % s)
