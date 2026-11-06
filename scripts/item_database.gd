extends Node
class_name ItemDatabase

var items: Dictionary = {}

func _ready() -> void:
	items = load_json("res://data/items.json")

static func load_json(path: String) -> Dictionary:
	var resolved_path := resolve_data_path(path)
	var file := FileAccess.open(resolved_path, FileAccess.READ)
	if file == null:
		push_error("Nao foi possivel abrir " + resolved_path)
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("JSON invalido em " + resolved_path)
		return {}
	return parsed

static func load_json_array(path: String) -> Array:
	var resolved_path := resolve_data_path(path)
	var file := FileAccess.open(resolved_path, FileAccess.READ)
	if file == null:
		push_error("Nao foi possivel abrir " + resolved_path)
		return []
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_ARRAY:
		push_error("JSON invalido em " + resolved_path)
		return []
	return parsed

static func resolve_data_path(path: String) -> String:
	if not path.begins_with("res://data/"):
		return path
	# Teste offline usa sempre os dados do projeto: um patch antigo baixado numa sessao
	# online escondia itens novos (armas, bijuterias, bolsas) de data/.
	if OS.get_cmdline_user_args().has("--offline-test") or bool(ProjectSettings.get_setting("paradise/offline_only", false)):
		return path
	var file_name := path.get_file()
	var patched_path := "user://patches/data/" + file_name
	if FileAccess.file_exists(patched_path):
		return patched_path
	return path

func get_item(item_name: String) -> Dictionary:
	return items.get(item_name, {})

func has_item(item_name: String) -> bool:
	return items.has(item_name)
