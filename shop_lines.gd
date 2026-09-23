extends Control

var links: Array = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	for link in links:
		var from: Control = link[0]
		var to: Control = link[1]
		if from == null or to == null:
			continue
		var start := from.position + Vector2(from.size.x * 0.5, from.size.y)
		var finish := to.position + Vector2(to.size.x * 0.5, 0.0)
		var mid_y := (start.y + finish.y) * 0.5
		var color := Color("6A523C")
		if _owned(from) and _owned(to):
			color = Color("E4B75A")
		elif _owned(from):
			color = Color("A88858")
		draw_line(start, Vector2(start.x, mid_y), color, 2.0)
		draw_line(Vector2(start.x, mid_y), Vector2(finish.x, mid_y), color, 2.0)
		draw_line(Vector2(finish.x, mid_y), finish, color, 2.0)


func _owned(node: Control) -> bool:
	var id: Variant = node.get("item_id")
	if id == null or str(id).is_empty():
		return false
	return int(GameState.levels.get(str(id), 0)) > 0
