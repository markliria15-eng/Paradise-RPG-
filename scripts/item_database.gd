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

# Itens encantados (profissoes.gd, Ferreiro Grao-Mestre): "Espada Infernal +3" e o item base com os
# atributos +8% por nivel (data/profissoes.json -> encantamento.bonus_por_nivel). Nao ficam no items.json:
# o nome com " +N" ja guarda o nivel no inventario e no equipamento.
const ENCANTO_BONUS := 0.08
var _encantados: Dictionary = {}

static func nivel_encanto(item_name: String) -> int:
	var i := item_name.rfind(" +")
	if i <= 0:
		return 0
	var n := item_name.substr(i + 2)
	return int(n) if n.is_valid_int() else 0

static func nome_base(item_name: String) -> String:
	var n := nivel_encanto(item_name)
	return item_name.substr(0, item_name.rfind(" +")) if n > 0 else item_name

func get_item(item_name: String) -> Dictionary:
	if items.has(item_name):
		return items[item_name]
	var n := nivel_encanto(item_name)
	if n <= 0 or not items.has(nome_base(item_name)):
		return {}
	if not _encantados.has(item_name):
		var base: Dictionary = items[nome_base(item_name)]
		var copia: Dictionary = base.duplicate(true)
		var fator := 1.0 + ENCANTO_BONUS * n
		var stats: Dictionary = copia.get("stats", {})
		for k in stats.keys():
			if typeof(stats[k]) == TYPE_INT:
				stats[k] = int(ceil(float(stats[k]) * fator))
			elif typeof(stats[k]) == TYPE_FLOAT:
				stats[k] = snappedf(float(stats[k]) * fator, 0.001)
		copia["stats"] = stats
		copia["name"] = item_name
		copia["enchant"] = n
		copia["base_item"] = nome_base(item_name)
		copia["price"] = int(float(base.get("price", 100)) * (1.0 + 0.6 * n))
		copia["description"] = "Encantado +%d (+%d%% nos atributos). %s" % [n, int(round(ENCANTO_BONUS * n * 100)), str(base.get("description", ""))]
		_encantados[item_name] = copia
	return _encantados[item_name]

func has_item(item_name: String) -> bool:
	return items.has(item_name) or (nivel_encanto(item_name) > 0 and items.has(nome_base(item_name)))
