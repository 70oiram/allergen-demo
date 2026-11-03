class_name Intro
extends CanvasLayer
## 開場前導字幕：全黑畫面中央逐句以打字機效果顯示；左鍵點擊直接跳到下一句，全部播完後淡出

signal finished

const TYPE_INTERVAL := 0.08     # 每字間隔（秒）
const HOLD_TIME := 1.8          # 一句打完後停留，之後自動下一句
const LAST_HOLD_TIME := 2.2     # 最後一句停留較久
const FADE_OUT := 1.0
const TEXT_COLOR := Color(0.93, 0.9, 0.86)
const RED := Color(0.85, 0.06, 0.06)

## 從主選單開始
const LINES_START := [
	["所以...你想吃東西?"],
	["是的，但我不知道為什麼我想吃"],
	["我可以為你準備一些食物"],
	["但是..."],
	["別貪吃", RED],
]
## 從結束畫面「我還想吃更多...」回來
const LINES_RETRY := [
	["所以...你想吃更多?"],
	["沒錯"],
	["為什麼?"],
	["我也不知道......"],
	["也許你該問問螢幕前的這個人"],
	["好吧...記住  吃到你開心為止"],
]

var bg: ColorRect
var label: Label
var index := -1          # 目前顯示中的句子
var _skip := false       # 點擊：結束目前這句，直接跳到下一句
var _lines: Array


func _ready() -> void:
	layer = 25
	bg = ColorRect.new()
	bg.color = Color.BLACK
	bg.size = Vector2(1920, 1080)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP   # 播放中擋住遊戲的滑鼠操作
	add_child(bg)

	label = Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size = Vector2(1920, 200)
	label.position = Vector2(0, 440)
	label.add_theme_font_size_override("font_size", 52)
	label.visible_characters = 0
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)


func play(retry: bool) -> void:
	_lines = LINES_RETRY if retry else LINES_START
	for i in _lines.size():
		index = i
		_skip = false
		var line: Array = _lines[i]
		label.text = line[0]
		label.add_theme_color_override("font_color", line[1] if line.size() > 1 else TEXT_COLOR)
		label.visible_characters = 0
		var total := label.get_total_character_count()
		var t := 0.0
		while not _skip and label.visible_characters < total:
			await get_tree().process_frame
			t += get_process_delta_time() / maxf(Engine.time_scale, 0.001)
			label.visible_characters = mini(total, int(t / TYPE_INTERVAL) + 1)
		label.visible_characters = -1
		var hold := LAST_HOLD_TIME if i == _lines.size() - 1 else HOLD_TIME
		t = 0.0
		while not _skip and t < hold:
			await get_tree().process_frame
			t += get_process_delta_time() / maxf(Engine.time_scale, 0.001)
	index = _lines.size()
	label.visible = false
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tw := create_tween()
	tw.tween_property(bg, "color:a", 0.0, FADE_OUT)
	await tw.finished
	finished.emit()
	queue_free()


## 左鍵：直接跳到下一句
func skip() -> void:
	if index >= 0 and index < _lines.size():
		_skip = true


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		skip()
		get_viewport().set_input_as_handled()
