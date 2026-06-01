extends Node
class_name ClassDatabase

var classes: Dictionary = {}

func _ready() -> void:
	classes = ItemDatabase.load_json("res://data/classes.json")

func get_class_data(class_label: String) -> Dictionary:
	return classes.get(class_label, {})

func all_classes() -> Array:
	return classes.keys()
