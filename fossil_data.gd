class_name FossilData
extends Resource

@export var name: String = "Fossil"
@export var shape_width: int = 4
@export var shape: PackedInt32Array = PackedInt32Array()
@export var min_layer: int = 6
@export var max_layer: int = 14
@export var base_value: int = 100


func cell_offsets() -> Array[Vector2i]:
	var offsets: Array[Vector2i] = []
	if shape_width <= 0:
		return offsets
	for i in shape.size():
		if shape[i] != 0:
			var x: int = i % shape_width
			var y: int = int(float(i) / float(shape_width))
			offsets.append(Vector2i(x, y))
	return offsets
