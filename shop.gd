extends CanvasLayer

signal closed

const Ui := preload("res://ui_style.gd")

var _header: Label
var _list: VBoxContainer
var _buttons: Dictionary = {}
var _banner: Label
var _banner_life: float = 0.0


func _ready() -> void:
	layer = 12
	visible = false
	var bg := ColorRect.new()
	bg.color = Color("16110D")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var back := Button.new()
	back.text = "Back"
	back.position = Vector2(24, 16)
	back.custom_minimum_size = Vector2(100, 40)
	Ui.apply_button(back)
	back.pressed.connect(func() -> void:
		Sfx.play("ui")
		closed.emit()
	)
	add_child(back)

	_header = Label.new()
	_header.position = Vector2(140, 18)
	Ui.apply_label(_header, 26, Ui.GOLD)
	add_child(_header)

	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 36
	root.offset_right = -36
	root.offset_top = 68
	root.offset_bottom = -24
	root.add_theme_constant_override("separation", 10)
	add_child(root)

	var hint := Label.new()
	hint.text = "Max a whole tier before the next one unlocks. First ranks buy the tool."
	Ui.apply_label(hint, 15, Ui.MUTED)
	root.add_child(hint)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 8)
	scroll.add_child(_list)

	var last_cat := ""
	var last_tier := -1
	for item in GameState.catalog:
		var cat: String = str(item.get("cat", "Other"))
		var tier: int = int(item.get("tier", 1))
		if cat != last_cat:
			var heading := Label.new()
			heading.text = cat
			Ui.apply_label(heading, 22, Ui.GOLD)
			_list.add_child(heading)
			last_cat = cat
			last_tier = -1
		if tier != last_tier:
			var tier_name := Label.new()
			tier_name.text = _tier_title(cat, tier)
			Ui.apply_label(tier_name, 16, Ui.MUTED)
			_list.add_child(tier_name)
			last_tier = tier
		_add_row(item)

	_banner = Label.new()
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_banner.offset_left = -280
	_banner.offset_right = 280
	_banner.offset_top = 58
	_banner.offset_bottom = 110
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner.modulate.a = 0.0
	Ui.apply_label(_banner, 34, Ui.GOLD)
	add_child(_banner)

	GameState.money_changed.connect(refresh)
	GameState.upgrades_changed.connect(refresh)
	refresh()


func _tier_title(cat: String, tier: int) -> String:
	return GameState.tier_title(cat, tier)


func _add_row(item: Dictionary) -> void:
	var id: String = str(item["id"])
	var card := Panel.new()
	card.custom_minimum_size = Vector2(0, 78)
	Ui.apply_panel(card, Color("2A211A"))
	_list.add_child(card)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	card.add_child(row)
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 10
	row.offset_right = -10
	row.offset_top = 6
	row.offset_bottom = -6

	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text)
	var title := Label.new()
	Ui.apply_label(title, 17, Ui.INK)
	text.add_child(title)
	var desc := Label.new()
	desc.text = GameState.shop_item_desc(id)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	Ui.apply_label(desc, 13, Ui.MUTED)
	text.add_child(desc)

	var button := Button.new()
	button.custom_minimum_size = Vector2(176, 42)
	Ui.apply_button(button, true)
	button.pressed.connect(_on_buy.bind(id))
	row.add_child(button)
	_buttons[id] = {"title": title, "desc": desc, "button": button, "card": card}


func _on_buy(id: String) -> void:
	var cost: int = GameState.cost_of(id)
	if not GameState.buy(id):
		return
	_celebrate_buy(id, cost)


func refresh() -> void:
	_header.text = "Upgrades      $%d" % GameState.money
	for item in GameState.catalog:
		var id: String = str(item["id"])
		if not _buttons.has(id):
			continue
		var level: int = int(GameState.levels.get(id, 0))
		var max_level: int = int(item["max"])
		var row: Dictionary = _buttons[id]
		row["title"].text = "%s    %d / %d" % [GameState.shop_display_name(id), level, max_level]
		if row.has("desc"):
			row["desc"].text = GameState.shop_item_desc(id)
		var button: Button = row["button"]
		var unlocked: bool = GameState.tier_unlocked(id) and GameState.requirements_met(id)
		if not unlocked:
			button.text = GameState.lock_reason(id)
			button.disabled = true
			if not _card_juicing(row["card"]):
				row["card"].modulate = Color(0.7, 0.66, 0.62)
		elif level >= max_level:
			button.text = "Maxed"
			button.disabled = true
			if not _card_juicing(row["card"]):
				row["card"].modulate = Color.WHITE
		else:
			button.text = GameState.shop_button_label(id)
			button.disabled = not GameState.can_buy(id)
			if not _card_juicing(row["card"]):
				row["card"].modulate = Color.WHITE


func _card_juicing(card: Panel) -> bool:
	if not card.has_meta("juice_tween"):
		return false
	var tw: Tween = card.get_meta("juice_tween")
	return tw != null and is_instance_valid(tw) and tw.is_running()


func _process(delta: float) -> void:
	if _banner_life <= 0.0:
		if _banner != null and _banner.modulate.a > 0.0:
			_banner.modulate.a = maxf(0.0, _banner.modulate.a - delta * 1.8)
		return
	_banner_life -= delta
	_banner.modulate.a = 1.0 if _banner_life > 0.4 else clampf(_banner_life / 0.4, 0.0, 1.0)


func _celebrate_buy(id: String, cost: int) -> void:
	var item: Dictionary = {}
	for entry in GameState.catalog:
		if str(entry["id"]) == id:
			item = entry
			break
	var item_name: String = str(item.get("name", id))
	_pulse_card(id, Color("FFE08A"))
	_slam_rank(id, "+ %s" % item_name)
	_flash_spend(cost)
	var unlock_title: String = GameState.last_unlock_title
	if not unlock_title.is_empty():
		Sfx.play("unlock")
		_show_unlock_banner("%s unlocked" % unlock_title)
	for unlocked_id in GameState.last_unlocked_ids:
		_pulse_card(str(unlocked_id), Color("FFF4D2"))


func _pulse_card(id: String, flash: Color) -> void:
	if not _buttons.has(id):
		return
	var row: Dictionary = _buttons[id]
	var card: Panel = row["card"]
	if card.has_meta("juice_tween"):
		var old: Tween = card.get_meta("juice_tween")
		if old != null and is_instance_valid(old):
			old.kill()
	card.pivot_offset = card.size * 0.5
	card.scale = Vector2(1.06, 1.08)
	card.modulate = flash
	var tw := create_tween()
	tw.tween_property(card, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(card, "modulate", Color.WHITE, 0.38)
	card.set_meta("juice_tween", tw)


func _slam_rank(id: String, text: String) -> void:
	if not _buttons.has(id):
		return
	var row: Dictionary = _buttons[id]
	var card: Panel = row["card"]
	var slam := Label.new()
	slam.text = text
	slam.mouse_filter = Control.MOUSE_FILTER_IGNORE
	Ui.apply_label(slam, 26, Ui.GOLD)
	slam.position = Vector2(16, 6)
	slam.scale = Vector2(1.4, 1.4)
	card.add_child(slam)
	var tw := create_tween()
	tw.tween_property(slam, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(slam, "position:y", slam.position.y - 30.0, 0.7)
	tw.tween_property(slam, "modulate:a", 0.0, 0.22)
	tw.tween_callback(slam.queue_free)


func _flash_spend(cost: int) -> void:
	_header.modulate = Color("FFE08A")
	var chip := Label.new()
	chip.text = "-$%d" % cost
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	Ui.apply_label(chip, 22, Color("E24B4B"))
	chip.position = _header.position + Vector2(260, 4)
	add_child(chip)
	var tw := create_tween()
	tw.tween_property(_header, "modulate", Color.WHITE, 0.45)
	tw.parallel().tween_property(chip, "position:y", chip.position.y - 34.0, 0.55)
	tw.parallel().tween_property(chip, "modulate:a", 0.0, 0.55)
	tw.tween_callback(chip.queue_free)


func _show_unlock_banner(text: String) -> void:
	_banner.text = text
	_banner.modulate.a = 1.0
	_banner.scale = Vector2(1.18, 1.18)
	_banner.pivot_offset = Vector2(_banner.size.x * 0.5, _banner.size.y * 0.5)
	_banner_life = 2.4
	var tw := create_tween()
	tw.tween_property(_banner, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
