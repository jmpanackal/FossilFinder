class_name ArtCatalog
extends RefCounted

## Drop-in pixel art: a real PNG in art/final/ overrides _draw. Artist folders are never loaded.

const DEFAULT_FINAL_ROOT := "res://art/final"
const MIN_EDGE_PX := 8
const MIN_FILE_BYTES := 32
const WHITE_CHANNEL := 0.90
const MIN_CONTENT_RATIO := 0.015
const CELL_PX := Vector2i(64, 40)
const TOOL_PX := Vector2i(32, 32)
const SCRAP_PX := Vector2i(16, 16)

static var final_root: String = DEFAULT_FINAL_ROOT


static func reset_roots() -> void:
	final_root = DEFAULT_FINAL_ROOT


static func rel_path(kind: String, id: String) -> String:
	return "%s/%s.png" % [kind, id]


static func is_usable(path: String) -> bool:
	if path.is_empty() or not FileAccess.file_exists(path):
		return false
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return false
	if file.get_length() < MIN_FILE_BYTES:
		return false
	var image := Image.new()
	if image.load(path) != OK:
		return false
	return _image_has_real_pixels(image)


static func _image_has_real_pixels(image: Image) -> bool:
	var width: int = image.get_width()
	var height: int = image.get_height()
	if width < MIN_EDGE_PX or height < MIN_EDGE_PX:
		return false
	var total: int = width * height
	var content: int = 0
	for y in height:
		for x in width:
			var pixel: Color = image.get_pixel(x, y)
			if pixel.a < 0.20:
				continue
			if pixel.r >= WHITE_CHANNEL and pixel.g >= WHITE_CHANNEL and pixel.b >= WHITE_CHANNEL:
				continue
			content += 1
	return float(content) / float(total) >= MIN_CONTENT_RATIO


static func has_final(kind: String, id: String) -> bool:
	if kind.is_empty() or id.is_empty():
		return false
	return is_usable("%s/%s" % [final_root.rstrip("/"), rel_path(kind, id)])


static func resolve(kind: String, id: String) -> String:
	if kind.is_empty() or id.is_empty():
		return ""
	var final_path: String = "%s/%s" % [final_root.rstrip("/"), rel_path(kind, id)]
	if is_usable(final_path):
		return final_path
	return ""


static func texture(kind: String, id: String) -> Texture2D:
	var path: String = resolve(kind, id)
	if path.is_empty():
		return null
	if ResourceLoader.exists(path):
		var loaded: Resource = load(path)
		if loaded is Texture2D:
			var tex: Texture2D = loaded as Texture2D
			if tex.get_width() >= MIN_EDGE_PX and tex.get_height() >= MIN_EDGE_PX:
				return tex
	var image := Image.new()
	if image.load(path) != OK:
		return null
	if not _image_has_real_pixels(image):
		return null
	return ImageTexture.create_from_image(image)


static func draw_if_present(
	item: CanvasItem,
	kind: String,
	id: String,
	dest: Rect2,
	modulate: Color = Color.WHITE
) -> bool:
	var tex: Texture2D = texture(kind, id)
	if tex == null or item == null or dest.size.x < 1.0 or dest.size.y < 1.0:
		return false
	item.draw_texture_rect(tex, dest, false, modulate)
	return true


static func draw_region_if_present(
	item: CanvasItem,
	kind: String,
	id: String,
	dest: Rect2,
	src: Rect2,
	modulate: Color = Color.WHITE
) -> bool:
	var tex: Texture2D = texture(kind, id)
	if tex == null or item == null or dest.size.x < 1.0 or dest.size.y < 1.0:
		return false
	item.draw_texture_rect_region(tex, dest, src, modulate)
	return true


static func cell_id_for_material(material: int) -> String:
	match material:
		Tuning.MAT_PACKED:
			return "dirt_packed"
		Tuning.MAT_CLAY:
			return "dirt_clay"
		Tuning.MAT_ROCK:
			return "rock"
		_:
			return "dirt_loose"


static func cell_id_for_layer(layer: int) -> String:
	return cell_id_for_material(Tuning.material_at_layer(layer))


static func tool_id_for(tool: int) -> String:
	match tool:
		Tuning.TOOL_PICKAXE:
			return "pickaxe"
		Tuning.TOOL_BRUSH:
			return "brush"
		Tuning.TOOL_HANDS:
			return "hands"
		_:
			return "shovel"


static func museum_size(stand_id: String) -> Vector2i:
	if stand_id == "brachiosaurus":
		return Vector2i(256, 160)
	return Vector2i(256, 128)
