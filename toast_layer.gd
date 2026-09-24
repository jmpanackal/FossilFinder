extends CanvasLayer

const Ui := preload("res://ui_style.gd")
const StarRating := preload("res://star_rating.gd")

var _box: VBoxContainer
var _title: Label
var _subtitle: Label
var _stars
var _life: float = 0.0


func _ready() -> void:
	layer = 9
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 2)
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.modulate.a = 0.0
	add_child(_box)
	_layout_footer()

	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	Ui.apply_label(_title, 20, Ui.GOLD)
	_box.add_child(_title)

	_subtitle = Label.new()
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	Ui.apply_label(_subtitle, 14, Ui.MUTED)
	_box.add_child(_subtitle)

	_stars = Control.new()
	_stars.set_script(StarRating)
	_stars.visible = false
	_box.add_child(_stars)


func show_toast(title: String, subtitle: String = "", stars: int = 0) -> void:
	_title.text = title
	_subtitle.text = subtitle
	_subtitle.visible = not subtitle.is_empty()
	if _stars.has_method("set_rating"):
		_stars.set_rating(stars)
	_stars.visible = stars > 0
	_life = 3.4 if stars > 0 or not subtitle.is_empty() else 2.2
	_layout_footer()
	_box.modulate.a = 1.0
	_box.pivot_offset = Vector2(_box.size.x * 0.5, _box.size.y * 0.5)
	_box.scale = Vector2(1.12, 1.12)
	var tw := create_tween()
	tw.tween_property(_box, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func is_showing() -> bool:
	return _box != null and (_life > 0.0 or _box.modulate.a > 0.05)


func _layout_footer() -> void:
	if _box == null:
		return
	_box.anchor_left = 0.0
	_box.anchor_top = 0.0
	_box.anchor_right = 0.0
	_box.anchor_bottom = 0.0
	var toast_h: float = maxf(28.0, _box.get_combined_minimum_size().y)
	var top: float = Tuning.footer_top() - toast_h - 4.0
	top = maxf(Tuning.pit_face_bottom() + 2.0, top)
	top = minf(top, Tuning.footer_top() - toast_h - 4.0)
	_box.position = Vector2(80.0, top)
	_box.size = Vector2(Tuning.view_w - 160.0, toast_h)


func _process(delta: float) -> void:
	_layout_footer()
	if _life <= 0.0:
		_box.modulate.a = maxf(_box.modulate.a - delta * 2.0, 0.0)
		return
	_life -= delta
	_box.modulate.a = 1.0 if _life > 0.5 else clampf(_life / 0.5, 0.0, 1.0)
