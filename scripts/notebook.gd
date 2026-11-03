class_name Notebook
extends CanvasLayer
## 打開的筆記本：畫面中央的攤開筆記本，左頁以文字記載目前的過敏原；點擊任一處關閉（由 game.gd 處理點擊）

const OPEN_TEX := "res://assets/互動素材/筆記本-打開.png"
const BOOK_WIDTH := 1400.0
const LEFT_PAGE := Rect2(0.13, 0.10, 0.34, 0.80)   # 左頁可書寫範圍（素材比例）
const INK := Color(0.27, 0.15, 0.07)
const ANIM_TIME := 0.22

var is_open := false
var book: Sprite2D
var dim: ColorRect
var title: Label
var entries: Label
var _tw: Tween


func _ready() -> void:
	layer = 15
	visible = false
	dim = ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.size = Vector2(1920, 1080)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

	book = Sprite2D.new()
	book.texture = Assets.tex(OPEN_TEX)
	var s := BOOK_WIDTH / book.texture.get_width()
	book.scale = Vector2.ONE * s
	book.position = Vector2(960, 540)
	add_child(book)

	var size := book.texture.get_size()
	var top_left := -size * 0.5
	title = _page_label(top_left, size, LEFT_PAGE, 44)
	title.text = "我不能吃的東西"
	title.size.y = 90
	entries = _page_label(top_left, size, LEFT_PAGE, 40)
	entries.position.y += 130 / s
	entries.size.y -= 130
	entries.add_theme_constant_override("line_spacing", 18)


## 頁面上的文字：以素材像素座標放在 book 底下，隨書本縮放
func _page_label(top_left: Vector2, size: Vector2, page: Rect2, font_px: int) -> Label:
	var s := book.scale.x
	var l := Label.new()
	l.position = top_left + page.position * size
	l.size = page.size * size
	l.scale = Vector2.ONE / s
	l.size = l.size * s           # 以螢幕像素排版，再整體縮回素材座標
	l.add_theme_font_size_override("font_size", font_px)
	l.add_theme_color_override("font_color", INK)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	book.add_child(l)
	return l


func open(names: Array) -> void:
	entries.text = "\n".join(names.map(func(n): return "・" + n))
	is_open = true
	visible = true
	_animate(true)


func close() -> void:
	if not is_open:
		return
	is_open = false
	await _animate(false)
	if not is_open:
		visible = false


func _animate(show: bool) -> void:
	if _tw:
		_tw.kill()
	var s := BOOK_WIDTH / book.texture.get_width()
	_tw = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_tw.tween_property(dim, "color:a", 0.6 if show else 0.0, ANIM_TIME)
	_tw.tween_property(book, "modulate:a", 1.0 if show else 0.0, ANIM_TIME)
	_tw.tween_property(book, "scale", Vector2.ONE * s * (1.0 if show else 0.9), ANIM_TIME)
	if show:
		book.scale = Vector2.ONE * s * 0.9
		book.modulate.a = 0.0
		dim.color.a = 0.0
	await _tw.finished
