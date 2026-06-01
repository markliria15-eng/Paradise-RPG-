extends Node
class_name DropSystem

var enemy_db: Dictionary = {}

func _ready() -> void:
	enemy_db = ItemDatabase.load_json("res://data/enemies.json")

func roll(enemy_name: String) -> Dictionary:
	var enemy: Dictionary = enemy_db.get(enemy_name, {})
	var drops: Array = []
	for entry in enemy.get("drops", []):
		if randf() <= float(entry.get("chance", 0.0)):
			drops.append(entry.get("item", ""))
	var gold_range: Array = enemy.get("ouro", [0, 0])
	return {
		"xp": int(enemy.get("xp", 0)),
		"ouro": randi_range(int(gold_range[0]), int(gold_range[1])),
		"items": drops
	}
