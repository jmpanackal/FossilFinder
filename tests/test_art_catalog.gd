extends SceneTree

## Only art/final/ overrides _draw. AI and templates stay off the runtime path.
## Run: godot --headless --path <project> -s res://tests/test_art_catalog.gd

var _failed: int = 0
var _passed: int = 0
var Catalog: GDScript
var Matrix: GDScript
var TN: Node

const CELL_IDS: PackedStringArray = ["dirt_loose", "dirt_packed", "dirt_clay", "rock"]
const TOOL_IDS: PackedStringArray = ["hands", "shovel", "pickaxe", "brush"]
const MUSEUM_IDS: PackedStringArray = [
	"t_rex", "triceratops", "brachiosaurus", "velociraptor", "stegosaurus", "small_finds", "plant_fossils"
]
const SCRAP_IDS: PackedStringArray = [
	"pebble", "shell", "scale", "seed", "speck", "sparkle", "glint", "amber", "opal", "crystal",
	"nodule", "flake"
]
const KINDS: PackedStringArray = ["cells", "bones", "tools", "scraps", "museum"]


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	TN = root.get_node("Tuning")
	Matrix = load("res://matrix_find.gd") as GDScript
	_test_catalog_script_exists()
	if Catalog != null:
		_test_live_repo_uses_draw_until_final_exists()
		_test_resolve_never_uses_ai_or_templates()
		_test_real_final_png_is_the_only_override()
		_test_empty_white_tiny_finals_are_ignored()
		_test_missing_files_return_empty()
		_test_id_helpers_match_game()
		_test_ai_placeholders_exist_at_exact_sizes()
		_test_templates_match_ai_sizes()
		_test_final_folders_are_empty_drops()
		_test_draw_paths_use_catalog_with_fallback()
	print("art_catalog %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _test_catalog_script_exists() -> void:
	Catalog = load("res://art_catalog.gd") as GDScript
	_assert(Catalog != null, "art_catalog.gd exists")
	if Catalog == null:
		return
	var src: String = FileAccess.get_file_as_string("res://art_catalog.gd")
	_assert(src.find("func resolve") >= 0, "ArtCatalog.resolve only considers art/final")
	_assert(src.find("func texture") >= 0, "ArtCatalog.texture loads a usable PNG")
	_assert(src.find("func draw_if_present") >= 0, "ArtCatalog.draw_if_present can paint a drop file")
	_assert(src.find("art/ai") < 0, "runtime catalog does not mention art/ai")
	_assert(src.find("art/templates") < 0, "runtime catalog does not mention art/templates")


func _test_live_repo_uses_draw_until_final_exists() -> void:
	_reset_catalog_roots()
	_assert(FileAccess.file_exists("res://art/ai/cells/dirt_loose.png"), "artist AI dirt still exists on disk")
	_assert(FileAccess.file_exists("res://art/templates/cells/dirt_loose.png"), "artist dirt template still exists on disk")
	_assert(str(Catalog.resolve("cells", "dirt_loose")) == "", "no final dirt means the tan _draw cell")
	_assert(Catalog.texture("cells", "dirt_loose") == null, "AI dirt is never a live texture")
	_assert(str(Catalog.resolve("tools", "hands")) == "", "no final tool means the _draw glyph")
	_assert(Catalog.texture("tools", "shovel") == null, "AI tools are never live textures")
	_assert(str(Catalog.resolve("bones", "t_rex_skull")) == "", "no final bone means the silhouette doodle")
	_assert(str(Catalog.resolve("scraps", "pebble")) == "", "no final scrap means the vector scrap")
	_assert(not bool(Catalog.has_final("museum", "t_rex")), "no final museum mount")


func _test_resolve_never_uses_ai_or_templates() -> void:
	_reset_catalog_roots()
	var base: String = "user://art_catalog_no_ai"
	_wipe_tree(base)
	Catalog.final_root = "%s/final" % base
	_write_png("%s/ai/cells/dirt_loose.png" % base, 64, 40, Color("C4A36A"))
	_write_png("%s/templates/cells/dirt_loose.png" % base, 64, 40, Color("FFFFFF"))
	var path: String = str(Catalog.resolve("cells", "dirt_loose"))
	_assert(path == "", "AI and template PNGs are ignored when final is missing")
	_assert(path.find("/ai/") < 0, "resolve never returns an art/ai path")
	_assert(path.find("/templates/") < 0, "resolve never returns an art/templates path")
	_reset_catalog_roots()
	_wipe_tree(base)


func _test_real_final_png_is_the_only_override() -> void:
	_reset_catalog_roots()
	var base: String = "user://art_catalog_test"
	_wipe_tree(base)
	Catalog.final_root = "%s/final" % base
	_write_png("%s/ai/cells/dirt_loose.png" % base, 64, 40, Color("C4A36A"))
	_assert(str(Catalog.resolve("cells", "dirt_loose")) == "", "missing final keeps _draw even when AI exists")
	_write_png("%s/final/cells/dirt_loose.png" % base, 64, 40, Color("11AA33"))
	var final_path: String = str(Catalog.resolve("cells", "dirt_loose"))
	_assert(final_path.find("/final/cells/dirt_loose.png") >= 0, "a real final PNG is the only texture override")
	_assert(Catalog.texture("cells", "dirt_loose") != null, "a real final PNG loads as a texture")
	_reset_catalog_roots()
	_wipe_tree(base)


func _test_empty_white_tiny_finals_are_ignored() -> void:
	_reset_catalog_roots()
	var base: String = "user://art_catalog_empty"
	_wipe_tree(base)
	Catalog.final_root = "%s/final" % base
	_write_png("%s/ai/tools/hands.png" % base, 32, 32, Color("E4B75A"))
	_write_empty("%s/final/tools/hands.png" % base)
	_assert(str(Catalog.resolve("tools", "hands")) == "", "an empty final file is not a valid override")
	_write_png("%s/final/cells/dirt_loose.png" % base, 64, 40, Color("FFFFFF"))
	_assert(str(Catalog.resolve("cells", "dirt_loose")) == "", "a white placeholder final is not a valid override")
	_write_png("%s/final/scraps/pebble.png" % base, 1, 1, Color("11AA33"))
	_assert(str(Catalog.resolve("scraps", "pebble")) == "", "a tiny placeholder final is not a valid override")
	_reset_catalog_roots()
	_wipe_tree(base)


func _test_missing_files_return_empty() -> void:
	_reset_catalog_roots()
	var base: String = "user://art_catalog_missing"
	_wipe_tree(base)
	Catalog.final_root = "%s/final" % base
	_assert(str(Catalog.resolve("cells", "dirt_loose")) == "", "no final means no texture path")
	_assert(Catalog.texture("cells", "dirt_loose") == null, "missing art returns null so _draw can fallback")
	_reset_catalog_roots()
	_wipe_tree(base)


func _test_id_helpers_match_game() -> void:
	_assert(str(Catalog.cell_id_for_material(TN.MAT_LOOSE)) == "dirt_loose", "loose dirt uses dirt_loose.png")
	_assert(str(Catalog.cell_id_for_material(TN.MAT_PACKED)) == "dirt_packed", "packed dirt uses dirt_packed.png")
	_assert(str(Catalog.cell_id_for_material(TN.MAT_CLAY)) == "dirt_clay", "clay uses dirt_clay.png")
	_assert(str(Catalog.cell_id_for_material(TN.MAT_ROCK)) == "rock", "rock uses rock.png")
	_assert(str(Catalog.tool_id_for(TN.TOOL_HANDS)) == "hands", "hands toolbar uses hands.png")
	_assert(str(Catalog.tool_id_for(TN.TOOL_SHOVEL)) == "shovel", "shovel toolbar uses shovel.png")
	_assert(str(Catalog.tool_id_for(TN.TOOL_PICKAXE)) == "pickaxe", "pickaxe toolbar uses pickaxe.png")
	_assert(str(Catalog.tool_id_for(TN.TOOL_BRUSH)) == "brush", "brush toolbar uses brush.png")
	for kind_name in ["pebble", "shell", "scale", "seed", "speck", "sparkle", "amber", "opal", "crystal", "nodule", "flake"]:
		_assert(SCRAP_IDS.has(kind_name), "scrap drop list includes matrix icon %s" % kind_name)
	_assert(str(Matrix.icon_kind("rust flake")) == "flake", "rust flake still maps to flake.png")
	_assert(str(Matrix.icon_kind("shell hash")) == "shell", "shell hash still maps to shell.png")
	_assert(str(Matrix.icon_kind("amber speck")) == "amber", "amber speck still maps to amber.png")


func _test_ai_placeholders_exist_at_exact_sizes() -> void:
	_reset_catalog_roots()
	for cell_id in CELL_IDS:
		_assert_png_size("ai", "cells", cell_id, Vector2i(64, 40))
	for tool_id in TOOL_IDS:
		_assert_png_size("ai", "tools", tool_id, Vector2i(32, 32))
	for scrap_id in SCRAP_IDS:
		_assert_png_size("ai", "scraps", scrap_id, Vector2i(16, 16))
	for museum_id in MUSEUM_IDS:
		var size: Vector2i = Vector2i(256, 160) if museum_id == "brachiosaurus" else Vector2i(256, 128)
		_assert_png_size("ai", "museum", museum_id, size)
	for piece_id in _roster_piece_ids():
		var data: Resource = _fossil_data(piece_id)
		_assert(data != null, "%s fossil data exists for a bone template" % piece_id)
		if data == null:
			continue
		var bounds: Vector2i = data.bounding_size()
		_assert_png_size("ai", "bones", piece_id, Vector2i(bounds.x * 64, bounds.y * 40))


func _test_templates_match_ai_sizes() -> void:
	for kind in KINDS:
		var folder: String = "res://art/templates/%s" % kind
		var names: PackedStringArray = _png_names_in(folder)
		_assert(not names.is_empty(), "templates/%s has exact-size guides" % kind)
		for name in names:
			var id: String = name.get_basename()
			var ai_path: String = "res://art/ai/%s/%s.png" % [kind, id]
			var tmpl_path: String = "res://art/templates/%s/%s.png" % [kind, id]
			_assert(FileAccess.file_exists(ai_path), "AI placeholder exists for template %s/%s" % [kind, id])
			var tmpl: Image = _load_image(tmpl_path)
			var ai: Image = _load_image(ai_path)
			if tmpl == null or ai == null:
				continue
			_assert(
				tmpl.get_width() == ai.get_width() and tmpl.get_height() == ai.get_height(),
				"template %s/%s matches the AI pixel size" % [kind, id]
			)


func _test_final_folders_are_empty_drops() -> void:
	for kind in KINDS:
		_assert(FileAccess.file_exists("res://art/final/%s/.gitkeep" % kind), "final/%s keeps the drop folder" % kind)
		_assert(_png_names_in("res://art/final/%s" % kind).is_empty(), "final/%s starts empty so _draw shows" % kind)


func _test_draw_paths_use_catalog_with_fallback() -> void:
	var site: String = FileAccess.get_file_as_string("res://dig_site.gd")
	_assert(site.find("ArtCatalog") >= 0, "dig site can paint dropped cell and bone art")
	_assert(site.find("draw_silhouette") >= 0, "dig site still falls back to the silhouette doodle")
	var tools: String = FileAccess.get_file_as_string("res://tool_icon.gd")
	_assert(tools.find("ArtCatalog") >= 0, "toolbar icons can use dropped tool PNGs")
	_assert(tools.find("_draw_shovel") >= 0, "toolbar still draws the gold shovel if no PNG")
	var scraps: String = FileAccess.get_file_as_string("res://matrix_find.gd")
	_assert(scraps.find("ArtCatalog") >= 0, "matrix/loot icons can use dropped scrap PNGs")
	_assert(scraps.find("draw_circle") >= 0, "matrix still draws vector scraps if no PNG")
	var hall: String = FileAccess.get_file_as_string("res://museum_exhibit.gd")
	_assert(hall.find("ArtCatalog") >= 0, "museum mounts can use dropped hall PNGs")
	_assert(hall.find("_draw_t_rex_bay") >= 0, "museum still draws the assembled doodle if no PNG")


func _roster_piece_ids() -> PackedStringArray:
	var ids: PackedStringArray = PackedStringArray()
	for path in TN.main_fossil_paths:
		var data: Resource = load(str(path))
		if data == null:
			continue
		var piece_id: String = str(data.get("piece_id"))
		if piece_id.is_empty() or ids.has(piece_id):
			continue
		ids.append(piece_id)
	for path in TN.extra_fossil_paths:
		var data: Resource = load(str(path))
		if data == null:
			continue
		var piece_id: String = str(data.get("piece_id"))
		if piece_id.is_empty() or ids.has(piece_id):
			continue
		ids.append(piece_id)
	for leftover in ["tooth", "vertebra"]:
		if FileAccess.file_exists("res://%s.tres" % leftover) and not ids.has(leftover):
			ids.append(leftover)
	return ids


func _fossil_data(piece_id: String) -> Resource:
	if FileAccess.file_exists("res://%s.tres" % piece_id):
		return load("res://%s.tres" % piece_id)
	return null


func _assert_png_size(root_name: String, kind: String, id: String, size: Vector2i) -> void:
	var path: String = "res://art/%s/%s/%s.png" % [root_name, kind, id]
	_assert(FileAccess.file_exists(path), "%s/%s/%s.png exists" % [root_name, kind, id])
	var image: Image = _load_image(path)
	if image == null:
		_assert(false, "%s/%s/%s.png is a readable PNG" % [root_name, kind, id])
		return
	_assert(
		image.get_width() == size.x and image.get_height() == size.y,
		"%s/%s/%s.png is %dx%d" % [root_name, kind, id, size.x, size.y]
	)


func _load_image(path: String) -> Image:
	if not FileAccess.file_exists(path):
		return null
	var image := Image.new()
	if image.load(path) != OK:
		return null
	return image


func _png_names_in(folder: String) -> PackedStringArray:
	var names: PackedStringArray = PackedStringArray()
	var dir := DirAccess.open(folder)
	if dir == null:
		return names
	dir.list_dir_begin()
	var name: String = dir.get_next()
	while name != "":
		if not dir.current_is_dir() and name.ends_with(".png"):
			names.append(name)
		name = dir.get_next()
	dir.list_dir_end()
	return names


func _write_png(path: String, width: int, height: int, color: Color) -> void:
	_ensure_dir(path.get_base_dir())
	var image := Image.create(width, height, false, Image.FORMAT_RGBA8)
	image.fill(color)
	image.save_png(path)


func _write_empty(path: String) -> void:
	_ensure_dir(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.close()


func _ensure_dir(path: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path))


func _wipe_tree(path: String) -> void:
	var abs_path: String = ProjectSettings.globalize_path(path)
	if DirAccess.dir_exists_absolute(abs_path):
		_remove_dir(abs_path)


func _remove_dir(abs_path: String) -> void:
	var dir := DirAccess.open(abs_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var name: String = dir.get_next()
	while name != "":
		var child: String = abs_path.path_join(name)
		if dir.current_is_dir():
			_remove_dir(child)
		else:
			DirAccess.remove_absolute(child)
		name = dir.get_next()
	dir.list_dir_end()
	DirAccess.remove_absolute(abs_path)


func _reset_catalog_roots() -> void:
	if Catalog != null and Catalog.has_method("reset_roots"):
		Catalog.reset_roots()


func _assert(ok: bool, label: String) -> void:
	if ok:
		_passed += 1
		print("PASS  %s" % label)
	else:
		_failed += 1
		print("FAIL  %s" % label)
