extends Node
class_name SaveSystem

const SAVE_PATH := "user://arcadia_realms_save.json"

static func save_game(player, quest_system: QuestSystem, current_map: String, exploration: Dictionary = {}) -> void:
	var payload := {
		"player": player.to_save(),
		"quests": quest_system.to_save(),
		"current_map": current_map,
		"position": [player.global_position.x, player.global_position.y],
		"exploration": exploration
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(payload, "\t"))

static func load_game() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		return {}
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	return parsed
