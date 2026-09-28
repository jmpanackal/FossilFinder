class_name ShopHero
extends Control

## Header card at the top of each shop tab: big tool icon and live "power"
## tiles (Dig power, Reach, Hold speed...). Tiles flash and count up when a
## purchase changes them, so buying feels like getting stronger.

const Ui := preload("res://ui_style.gd")
const ShopIcon := preload("res://shop_icon.gd")

const ACCENTS := {
	"Hands": Color("E0B07A"),
	"Shovel": Color("D4A017"),
	"Pickaxe": Color("E0684A"),
	"Brush": Color("7EC8E3"),
	"Site": Color("9CCB6B"),
	"Museum": Color("C39BD3"),
}
const TAGLINES := {
	"Hands": "Careful digging, feeling for bone, plastering",
	"Shovel": "Fast digging through soil",
	"Pickaxe": "Breaking clay and stone",
	"Brush": "Cleaning bones for more $",
	"Site": "Your dig: time, size, what's buried",
	"Museum": "Visitors, income and repairs",
}

var cat: String = ""
var _icon: Control
var _tiles: Array = []
var _flash: Dictionary = {}
var _shown: Dictionary = {}


static func accent_for(category: String) -> Color:
	return ACCENTS.get(category, Ui.GOLD)


func setup(category: String) -> void:
	cat = category
	custom_minimum_size = Vector2(0, 104)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icon = ShopIcon.new()
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icon.position = Vector2(18, 18)
	_icon.size = Vector2(68, 68)
	add_child(_icon)
	if _icon.has_method("setup"):
		_icon.setup(ShopIcon.glyph_for_cat(cat), accent_for(cat))
	refresh()


func refresh() -> void:
	var stats: Array = GameState.shop_hero_stats(cat) if GameState.has_method("shop_hero_stats") else []
	for raw in stats:
		var stat: Dictionary = raw
		var label: String = str(stat["label"])
		var value: String = str(stat["value"])
		if _shown.has(label) and _shown[label] != value:
			_flash[label] = 1.0
		_shown[label] = value
	_tiles = stats
	queue_redraw()


func _process(delta: float) -> void:
	if _flash.is_empty():
		return
	for key in _flash.keys():
		_flash[key] = maxf(0.0, float(_flash[key]) - delta * 1.2)
		if float(_flash[key]) <= 0.0:
			_flash.erase(key)
	queue_redraw()


func _draw() -> void:
	var accent: Color = accent_for(cat)
	var rect := Rect2(Vector2.ZERO, size)
	## Accent band fading into the panel so each tab has its own color.
	draw_rect(rect, Color("1E1611"))
	for i in 12:
		var t: float = float(i) / 12.0
		draw_rect(Rect2(rect.position.x + rect.size.x * 0.35 * t, 0, rect.size.x * 0.35 / 12.0 + 1.0, rect.size.y), Color(accent, 0.16 * (1.0 - t)))
	draw_rect(rect, Color(accent, 0.8), false, 2.0)
	draw_circle(Vector2(52, 52), 40.0, Color(accent, 0.14))
	var font: Font = Ui.display_font()
	draw_string(font, Vector2(104, 34), cat, HORIZONTAL_ALIGNMENT_LEFT, -1, 26, accent)
	draw_string(font, Vector2(104, 56), str(TAGLINES.get(cat, "")), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Ui.MUTED)
	## Stat tiles on the right: big value, small label.
	var n: int = _tiles.size()
	if n <= 0:
		return
	var tile_w: float = 132.0
	var gap: float = 8.0
	var x: float = rect.end.x - 14.0 - float(n) * tile_w - float(n - 1) * gap
	x = maxf(x, 104.0)
	for raw in _tiles:
		var stat: Dictionary = raw
		var label: String = str(stat["label"])
		var flash: float = float(_flash.get(label, 0.0))
		var value: String = str(stat["value"])
		var locked: bool = value == "Locked"
		var tile := Rect2(Vector2(x, 20.0), Vector2(tile_w, 64.0))
		draw_rect(tile, Color("1A1410") if locked else Color("2A1D12").lerp(Color(accent, 0.35), flash))
		draw_rect(tile, Color(Ui.MUTED, 0.3) if locked else Color(accent, 0.5 + 0.5 * flash), false, 1.5)
		if locked:
			var lw0: float = font.get_string_size("Locked", HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
			draw_string(font, Vector2(tile.position.x + (tile_w - lw0) * 0.5, tile.position.y + 30.0), "Locked", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(Ui.MUTED, 0.6))
			var ll: float = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
			draw_string(font, Vector2(tile.position.x + (tile_w - ll) * 0.5, tile.position.y + 52.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(Ui.MUTED, 0.6))
			x += tile_w + gap
			continue
		var vs: int = 22
		while vs > 12 and font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, vs).x > tile_w - 12.0:
			vs -= 1
		var vw: float = font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, vs).x
		draw_string(font, Vector2(tile.position.x + (tile_w - vw) * 0.5, tile.position.y + 32.0), value, HORIZONTAL_ALIGNMENT_LEFT, -1, vs, Color.WHITE.lerp(accent, 0.35) if flash <= 0.0 else Color.WHITE)
		var lw: float = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
		draw_string(font, Vector2(tile.position.x + (tile_w - lw) * 0.5, tile.position.y + 52.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Ui.MUTED)
		x += tile_w + gap
