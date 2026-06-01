extends Node
class_name ItemDatabase

var items: Dictionary = {}

func _ready() -> void:
	items = load_json("res://data/items.json")

static func load_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Nao foi possivel abrir " + path)
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("JSON invalido em " + path)
		return {}
	return parsed

func get_item(item_name: String) -> Dictionary:
	return items.get(item_name, {})

func has_item(item_name: String) -> bool:
	return items.has(item_name)
