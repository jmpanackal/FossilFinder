extends Node2D

const FloatingTextScene := preload("res://floating_text.gd")
const RevealPing := preload("res://reveal_ping.gd")

@onready var camera: Camera2D = $Camera2D
@onready var dig_site = $DigSite
@onready var hud = $HUD
@onready var summary = $Summary
@onready var debug_label: Label = $DebugOverlay/DebugLabel
@onready var extract_flash: ColorRect = $ExtractFlash/Flash
@onready var extract_label: Label = $ExtractFlash/ExtractLabel

var session_money: int = 0
var round_money: int = 0
var time_left: float = 0.0
var round_active: bool = false
var debug_on: bool = false
var _shake_left: float = 0.0
var _flash_left: float = 0.0


func _ready() -> void:
	randomize()
	dig_site.layer_cleared.connect(_on_layer_cleared)
	dig_site.fossil_cell_exposed.connect(_on_fossil_exposed)
	dig_site.fossil_extracted.connect(_on_fossil_extracted)
	dig_site.pickaxe_struck.connect(_on_pickaxe)
	summary.dig_again.connect(start_round)
	$ExtractFlash.visible = false
	$DebugOverlay.visible = false
	start_round()


func start_round() -> void:
	round_money = 0
	time_left = Tuning.round_seconds
	round_active = true
	_shake_left = 0.0
	_flash_left = 0.0
	camera.offset = Vector2.ZERO
	summary.hide_summary()
	$ExtractFlash.visible = false
	dig_site.input_enabled = true
	dig_site.start_round()


func _process(delta: float) -> void:
	if _shake_left > 0.0 and Tuning.shake_enabled:
		_shake_left -= delta
		camera.offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * Tuning.shake_strength
		if _shake_left <= 0.0:
			camera.offset = Vector2.ZERO
	if _flash_left > 0.0:
		_flash_left -= delta
		extract_flash.color.a = clampf(_flash_left / 0.35, 0.0, 0.55)
		if _flash_left <= 0.0:
			$ExtractFlash.visible = false
	if round_active:
		time_left -= delta
		if time_left <= 0.0:
			_end_round()
	hud.refresh(time_left, float(dig_site.deepest_layer) * Tuning.meters_per_layer, Tuning.TOOL_NAMES[dig_site.current_tool], round_money)
	if debug_on:
		_refresh_debug()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_F1:
			debug_on = not debug_on
			$DebugOverlay.visible = debug_on
		elif event.physical_keycode == KEY_F2 and round_active:
			_end_round()


func _end_round() -> void:
	if not round_active:
		return
	round_active = false
	time_left = 0.0
	dig_site.input_enabled = false
	var fossil_line := ""
	if dig_site.extracted:
		var value := int(round(float(dig_site.fossil.base_value) * dig_site.integrity))
		fossil_line = "Extracted %s — %d%% integrity  ($%d)" % [
			dig_site.fossil.name,
			int(round(dig_site.integrity * 100.0)),
			value
		]
	else:
		fossil_line = "Fossil left behind — %d%% exposed." % int(round(dig_site.fossil_exposure() * 100.0))
	summary.show_summary(
		float(dig_site.deepest_layer) * Tuning.meters_per_layer,
		round_money,
		session_money,
		fossil_line
	)


func _on_layer_cleared(amount: int, world_pos: Vector2) -> void:
	round_money += amount
	session_money += amount
	_spawn_float("+$%d" % amount, world_pos, Color("F2D36B"))


func _on_fossil_exposed(world_pos: Vector2, first: bool) -> void:
	if first:
		_spawn_float("BONE!", world_pos, Color("F3E6C8"))
		_ping(world_pos)


func _on_fossil_extracted(fossil_name: String, value: int, integrity: float) -> void:
	round_money += value
	session_money += value
	_flash_left = 0.45
	$ExtractFlash.visible = true
	extract_flash.color = Color(1, 1, 1, 0.55)
	extract_label.text = "%s\n$%d  (%d%% integrity)" % [fossil_name, value, int(round(integrity * 100.0))]


func _on_pickaxe() -> void:
	if Tuning.shake_enabled:
		_shake_left = Tuning.shake_time


func _spawn_float(text: String, world_pos: Vector2, color: Color) -> void:
	var floater = FloatingTextScene.new()
	floater.position = world_pos
	floater.setup(text, color)
	add_child(floater)


func _ping(world_pos: Vector2) -> void:
	var ring := Node2D.new()
	ring.position = world_pos
	ring.set_script(RevealPing)
	add_child(ring)


func _refresh_debug() -> void:
	var lines: PackedStringArray = []
	lines.append("FPS %d" % int(Engine.get_frames_per_second()))
	if dig_site.fossil:
		lines.append("Fossil %s at %s layer %d" % [dig_site.fossil.name, str(dig_site.fossil_origin), dig_site.fossil_layer])
		lines.append("Exposed %d/%d  integrity %d%%" % [
			dig_site.exposed_cells.size(),
			dig_site.fossil_cells.size(),
			int(round(dig_site.integrity * 100.0))
		])
	lines.append("Damage matrix (shovel / pick / brush × loose packed clay rock)")
	for row in Tuning.damage_matrix:
		lines.append("  " + str(row))
	debug_label.text = "\n".join(lines)
