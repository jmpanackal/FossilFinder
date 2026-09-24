extends CanvasLayer

signal closed

const Ui := preload("res://ui_style.gd")
const UpgradeRow := preload("res://upgrade_node.gd")
const ShopIcon := preload("res://shop_icon.gd")

const CATS: Array[String] = ["Hands", "Shovel", "Pickaxe", "Brush", "Site", "Exhibit"]
const RAIL_W := 176.0

var _title: Label
var _wallet: Label
var _buttons: Dictionary = {}
var _tabs: Dictionary = {}
var _pages: Dictionary = {}
var _chapters: Dictionary = {}
var _gates: Dictionary = {}
var _selected_cat: String = "Hands"
var _user_picked_tab: bool = false
var _banner: Label
var _banner_life: float = 0.0
var _scroll: ScrollContainer
var _pages_host: VBoxContainer
var _fitting_pages: bool = false
var _fit_queued: bool = false


func _ready() -> void:
	layer = 12
	visible = false

	var bg := ColorRect.new()
	bg.color = Color("16110D")
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var bar := Panel.new()
	bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	bar.offset_bottom = 64
	bar.mouse_filter = Control.MOUSE_FILTER_STOP
	Ui.apply_bar(bar, Ui.PAPER_DEEP, false)
	add_child(bar)

	var back := Button.new()
	back.text = "Back"
	back.position = Vector2(20, 12)
	back.custom_minimum_size = Vector2(100, 40)
	Ui.apply_button(back)
	back.pressed.connect(func() -> void:
		Sfx.play("ui")
		closed.emit()
	)
	add_child(back)

	_title = Label.new()
	_title.text = "Upgrades"
	_title.position = Vector2(136, 16)
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	Ui.apply_label(_title, 26, Ui.GOLD)
	add_child(_title)

	_wallet = Label.new()
	_wallet.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_wallet.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_wallet.offset_left = -280
	_wallet.offset_right = -28
	_wallet.offset_top = 14
	_wallet.offset_bottom = 52
	_wallet.mouse_filter = Control.MOUSE_FILTER_IGNORE
	Ui.apply_label(_wallet, 28, Ui.GOLD)
	add_child(_wallet)

	var body := HBoxContainer.new()
	add_child(body)
	body.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	body.offset_left = 20
	body.offset_right = -20
	body.offset_top = 76
	body.offset_bottom = -16
	body.add_theme_constant_override("separation", 16)

	var rail := Panel.new()
	rail.custom_minimum_size = Vector2(RAIL_W, 0)
	Ui.apply_panel(rail, Color("1B1410"))
	body.add_child(rail)
	var rail_list := VBoxContainer.new()
	rail_list.add_theme_constant_override("separation", 8)
	rail.add_child(rail_list)
	rail_list.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rail_list.offset_left = 10
	rail_list.offset_right = -10
	rail_list.offset_top = 10
	rail_list.offset_bottom = -10

	for cat in CATS:
		rail_list.add_child(_make_tab(cat))

	_scroll = ScrollContainer.new()
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_ALWAYS
	body.add_child(_scroll)

	_pages_host = VBoxContainer.new()
	_pages_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_pages_host.add_theme_constant_override("separation", 0)
	_scroll.add_child(_pages_host)
	_scroll.resized.connect(_queue_fit_pages)

	for cat in CATS:
		var page := VBoxContainer.new()
		page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		page.add_theme_constant_override("separation", 14)
		_pages_host.add_child(page)
		_pages[cat] = page
		_fill_page(page, cat)

	_banner = Label.new()
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_banner.offset_left = -300
	_banner.offset_right = 300
	_banner.offset_top = 68
	_banner.offset_bottom = 124
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner.modulate.a = 0.0
	Ui.apply_label(_banner, 34, Ui.GOLD)
	add_child(_banner)

	GameState.money_changed.connect(refresh)
	GameState.upgrades_changed.connect(refresh)
	_select_cat("Hands")
	refresh()
	_fit_pages()


func _queue_fit_pages() -> void:
	if _fit_queued:
		return
	_fit_queued = true
	call_deferred("_fit_pages")


func _fit_pages() -> void:
	_fit_queued = false
	if _fitting_pages or _scroll == null or _pages_host == null:
		return
	_fitting_pages = true
	var gutter: float = 0.0
	var bar: VScrollBar = _scroll.get_v_scroll_bar()
	if bar != null:
		gutter = maxf(bar.get_combined_minimum_size().x, bar.size.x)
	var width: float = maxf(_scroll.size.x - gutter, 420.0)
	if not is_equal_approx(_pages_host.custom_minimum_size.x, width):
		_pages_host.custom_minimum_size.x = width
	_fitting_pages = false


func _make_tab(cat: String) -> Button:
	var tab := Button.new()
	tab.custom_minimum_size = Vector2(0, 62)
	tab.text = ""
	tab.pressed.connect(func() -> void:
		Sfx.play("ui")
		_user_picked_tab = true
		_select_cat(cat)
	)
	Ui.apply_tab(tab, false)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tab.add_child(row)
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 8
	row.offset_right = -8
	row.offset_top = 6
	row.offset_bottom = -6

	var icon: Control = ShopIcon.new()
	icon.custom_minimum_size = Vector2(36, 36)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon)
	if icon.has_method("setup"):
		icon.setup(ShopIcon.glyph_for_cat(cat), Ui.GOLD)

	var caption := Label.new()
	caption.text = cat
	caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	Ui.apply_label(caption, 16, Ui.INK)
	row.add_child(caption)

	var badge := Label.new()
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.custom_minimum_size = Vector2(22, 22)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	Ui.apply_label(badge, 13, Color("1B1410"))
	row.add_child(badge)

	_tabs[cat] = {"button": tab, "icon": icon, "caption": caption, "badge": badge}
	return tab


func _fill_page(page: VBoxContainer, cat: String) -> void:
	var last_tier := -1
	for item in GameState.catalog:
		if str(item.get("cat", "")) != cat:
			continue
		var tier: int = int(item.get("tier", 1))
		if tier != last_tier:
			_add_chapter(page, cat, tier)
			_add_gate(page, cat, tier)
			last_tier = tier
		_add_row(item, cat, tier)


func _add_chapter(page: VBoxContainer, cat: String, tier: int) -> void:
	var key: String = _chapter_key(cat, tier)
	var frame := PanelContainer.new()
	frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	frame.add_theme_stylebox_override("panel", Ui.chapter_box())
	page.add_child(frame)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	frame.add_child(col)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	col.add_child(head)

	var mark := Label.new()
	mark.text = GameState.tier_title(cat, tier)
	Ui.apply_label(mark, 22, Ui.GOLD)
	head.add_child(mark)

	var progress := Label.new()
	progress.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	progress.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	Ui.apply_label(progress, 14, Ui.MUTED)
	head.add_child(progress)

	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 8)
	col.add_child(body)

	_chapters[key] = {"wrap": frame, "title": mark, "progress": progress, "body": body}


func _add_gate(page: VBoxContainer, cat: String, tier: int) -> void:
	if tier <= 1:
		return
	var key: String = _chapter_key(cat, tier)
	var gate := PanelContainer.new()
	gate.custom_minimum_size = Vector2(0, 168)
	gate.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gate.add_theme_stylebox_override("panel", Ui.gate_box())
	page.add_child(gate)

	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 6)
	gate.add_child(col)

	var icon: Control = ShopIcon.new()
	icon.custom_minimum_size = Vector2(72, 56)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(icon)
	if icon.has_method("setup"):
		icon.setup("chest", Color("A88858"))

	var title := Label.new()
	title.text = GameState.tier_title(cat, tier)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Ui.apply_label(title, 22, Ui.GOLD)
	col.add_child(title)

	var reason := Label.new()
	reason.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reason.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	reason.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reason.custom_minimum_size.x = 240
	Ui.apply_label(reason, 15, Ui.MUTED)
	col.add_child(reason)

	_gates[key] = {"wrap": gate, "title": title, "reason": reason, "icon": icon}


func _add_row(item: Dictionary, cat: String, tier: int) -> void:
	var id: String = str(item["id"])
	var key: String = _chapter_key(cat, tier)
	var chapter: Dictionary = _chapters[key]
	var row = UpgradeRow.new()
	chapter["body"].add_child(row)
	row.setup(id)
	row.buy_pressed.connect(_on_buy)
	_buttons[id] = row


func _select_cat(cat: String) -> void:
	_selected_cat = cat
	for page_cat in _pages.keys():
		var page: VBoxContainer = _pages[page_cat]
		page.visible = str(page_cat) == cat
	for rail_cat in CATS:
		if _tabs.has(rail_cat):
			_refresh_tab(rail_cat)
	_queue_fit_pages()


func _on_buy(id: String) -> void:
	var cost: int = GameState.cost_of(id)
	if not GameState.buy(id):
		return
	GameState.save_game()
	_celebrate_buy(id, cost)


func refresh() -> void:
	_wallet.text = "$%d" % GameState.money
	if not _user_picked_tab:
		var ready_cat: String = _first_ready_cat()
		if not ready_cat.is_empty():
			_selected_cat = ready_cat
	for cat in CATS:
		var page: VBoxContainer = _pages[cat]
		page.visible = cat == _selected_cat
		_refresh_tab(cat)
	for item in GameState.catalog:
		var id: String = str(item["id"])
		if not _buttons.has(id):
			continue
		var row: Panel = _buttons[id]
		if row.has_method("refresh"):
			row.refresh()
	for cat in CATS:
		_refresh_tiers(cat)


func _refresh_tab(cat: String) -> void:
	var tab: Dictionary = _tabs[cat]
	var button: Button = tab["button"]
	var glow_count: int = _cat_glow_count(cat)
	var selected: bool = cat == _selected_cat
	Ui.apply_tab(button, selected, glow_count > 0)
	var caption: Label = tab["caption"]
	caption.add_theme_color_override("font_color", Ui.GOLD if selected else Ui.INK)
	var badge: Label = tab["badge"]
	badge.visible = glow_count > 0
	badge.text = str(glow_count)
	if glow_count > 0:
		var pip := StyleBoxFlat.new()
		pip.bg_color = Ui.GOLD
		pip.set_corner_radius_all(10)
		pip.content_margin_left = 6
		pip.content_margin_right = 6
		badge.add_theme_stylebox_override("normal", pip)
		badge.add_theme_color_override("font_color", Color("1B1410"))
	if tab["icon"].has_method("setup"):
		tab["icon"].setup(ShopIcon.glyph_for_cat(cat), Ui.GOLD if selected or glow_count > 0 else Color("A88858"))


func _refresh_tiers(cat: String) -> void:
	var tiers: Array[int] = _tiers_for(cat)
	for tier in tiers:
		var key: String = _chapter_key(cat, tier)
		var open: bool = _tier_open(cat, tier)
		if _chapters.has(key):
			var chapter: Dictionary = _chapters[key]
			var frame: Control = chapter["wrap"]
			frame.visible = open
			var done: int = 0
			var total: int = 0
			for item in GameState.catalog:
				if str(item.get("cat", "")) != cat or int(item.get("tier", 1)) != tier:
					continue
				total += int(item.get("max", 1))
				done += mini(int(GameState.levels.get(str(item["id"]), 0)), int(item.get("max", 1)))
			var progress: Label = chapter["progress"]
			if total > 0 and done >= total:
				progress.text = "COMPLETE"
				progress.add_theme_color_override("font_color", Ui.GOLD)
			else:
				progress.text = "%d / %d ranks" % [done, total]
				progress.add_theme_color_override("font_color", Ui.MUTED)
		if _gates.has(key):
			var gate: Dictionary = _gates[key]
			var gate_wrap: Control = gate["wrap"]
			gate_wrap.visible = not open
			if not open:
				var sample: String = _first_id_in(cat, tier)
				var left: int = _ranks_left(cat, tier - 1)
				var reason: String = GameState.lock_reason(sample) if not sample.is_empty() else "Locked"
				if left > 0:
					reason = "%s  ·  %d rank%s left on %s" % [reason, left, "" if left == 1 else "s", GameState.tier_title(cat, tier - 1)]
				gate["reason"].text = reason
				if gate["icon"].has_method("setup"):
					var close: bool = left <= 2
					gate["icon"].setup("chest", Color("E4B75A") if close else Color("A88858"), not close)


func _first_ready_cat() -> String:
	for cat in CATS:
		if _cat_glow_count(cat) > 0:
			return cat
	return ""


func _cat_glow_count(cat: String) -> int:
	var count: int = 0
	for item in GameState.catalog:
		if str(item.get("cat", "")) != cat:
			continue
		if GameState.shop_row_heat(str(item["id"])) == "glow":
			count += 1
	return count


func _tiers_for(cat: String) -> Array[int]:
	var seen: Dictionary = {}
	var tiers: Array[int] = []
	for item in GameState.catalog:
		if str(item.get("cat", "")) != cat:
			continue
		var tier: int = int(item.get("tier", 1))
		if seen.has(tier):
			continue
		seen[tier] = true
		tiers.append(tier)
	return tiers


func _tier_open(cat: String, tier: int) -> bool:
	var sample: String = _first_id_in(cat, tier)
	if sample.is_empty():
		return false
	return GameState.tier_unlocked(sample)


func _first_id_in(cat: String, tier: int) -> String:
	for item in GameState.catalog:
		if str(item.get("cat", "")) == cat and int(item.get("tier", 1)) == tier:
			return str(item["id"])
	return ""


func _ranks_left(cat: String, tier: int) -> int:
	var left: int = 0
	for item in GameState.catalog:
		if str(item.get("cat", "")) != cat or int(item.get("tier", 1)) != tier:
			continue
		var max_level: int = int(item.get("max", 1))
		var level: int = int(GameState.levels.get(str(item["id"]), 0))
		left += maxi(0, max_level - level)
	return left


func _chapter_key(cat: String, tier: int) -> String:
	return "%s:%d" % [cat, tier]


func _card_juicing(card: Panel) -> bool:
	if not card.has_meta("juice_tween"):
		return false
	var tw: Tween = card.get_meta("juice_tween")
	return tw != null and is_instance_valid(tw) and tw.is_running()


func _process(delta: float) -> void:
	if visible:
		var pulse: float = 0.78 + 0.22 * absf(sin(float(Time.get_ticks_msec()) * 0.007))
		for item in GameState.catalog:
			var id: String = str(item["id"])
			if not _buttons.has(id):
				continue
			var card: Panel = _buttons[id]
			if _card_juicing(card):
				continue
			if GameState.shop_row_heat(id) != "glow":
				continue
			card.modulate = Color("FFE08A").lerp(Color("E4B75A"), 1.0 - pulse)
		for cat in CATS:
			if not _tabs.has(cat):
				continue
			var glow_count: int = _cat_glow_count(cat)
			var tab: Dictionary = _tabs[cat]
			var button: Button = tab["button"]
			if glow_count > 0 and cat != _selected_cat:
				button.modulate = Color("FFE08A").lerp(Color.WHITE, 1.0 - pulse)
			else:
				button.modulate = Color.WHITE
			var badge: Label = tab["badge"]
			if badge.visible:
				badge.modulate = Color("FFE08A").lerp(Color.WHITE, 1.0 - pulse)
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
	var item_name: String = GameState.shop_display_name(id)
	if item_name.is_empty():
		item_name = str(item.get("name", id))
	_pulse_card(id, Color("FFE08A"))
	_slam_rank(id, "+ %s" % item_name)
	_flash_spend(cost)
	var unlock_title: String = GameState.last_unlock_title
	if not unlock_title.is_empty():
		Sfx.play("unlock")
		_show_unlock_banner("%s unlocked" % unlock_title)
		_pulse_chapter(unlock_title)
	for unlocked_id in GameState.last_unlocked_ids:
		_pulse_card(str(unlocked_id), Color("FFF4D2"))


func _pulse_chapter(title: String) -> void:
	for key in _chapters.keys():
		var chapter: Dictionary = _chapters[key]
		if str(chapter["title"].text) != title:
			continue
		var frame: Control = chapter["wrap"]
		if frame.has_meta("juice_tween"):
			var old: Tween = frame.get_meta("juice_tween")
			if old != null and is_instance_valid(old):
				old.kill()
		frame.pivot_offset = frame.size * 0.5
		frame.scale = Vector2(1.04, 1.06)
		frame.modulate = Color("FFF4D2")
		var tw := create_tween()
		tw.tween_property(frame, "scale", Vector2.ONE, 0.34).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(frame, "modulate", Color.WHITE, 0.42)
		frame.set_meta("juice_tween", tw)


func _pulse_card(id: String, flash: Color) -> void:
	if not _buttons.has(id):
		return
	var card: Panel = _buttons[id]
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
	var card: Panel = _buttons[id]
	var slam := Label.new()
	slam.text = text
	slam.mouse_filter = Control.MOUSE_FILTER_IGNORE
	Ui.apply_label(slam, 26, Ui.GOLD)
	slam.position = Vector2(72, 6)
	slam.scale = Vector2(1.4, 1.4)
	card.add_child(slam)
	var tw := create_tween()
	tw.tween_property(slam, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(slam, "position:y", slam.position.y - 30.0, 0.7)
	tw.tween_property(slam, "modulate:a", 0.0, 0.22)
	tw.tween_callback(slam.queue_free)


func _flash_spend(cost: int) -> void:
	_wallet.modulate = Color("FFE08A")
	var chip := Label.new()
	chip.text = "-$%d" % cost
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	Ui.apply_label(chip, 22, Color("E24B4B"))
	chip.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	chip.offset_left = -280
	chip.offset_right = -28
	chip.offset_top = 48
	chip.offset_bottom = 78
	add_child(chip)
	var tw := create_tween()
	tw.tween_property(_wallet, "modulate", Color.WHITE, 0.45)
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
