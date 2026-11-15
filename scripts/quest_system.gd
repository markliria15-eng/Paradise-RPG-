extends RefCounted
class_name QuestSystem

# Mantem quests ativas separadas dos dados JSON para facilitar save e futura
# sincronizacao com servidor.
var quests: Dictionary = {}
var active: Dictionary = {}
var completed: Array = []

const OBJECTIVE_VERBS := {"kill": "Derrotar", "collect": "Coletar", "visit": "Visitar", "talk": "Falar com"}
const MAP_NAMES := {"city_eldoria": "Eldoria", "city_valdoria": "Valdoria", "forest_boars": "Floresta dos Javalis",
	"bat_cave": "Caverna Profunda", "arcane_ruins": "Ruinas Arcanas"}

func load_quests() -> void:
	quests = ItemDatabase.load_json("res://data/quests.json")

func accept(quest_id: String) -> bool:
	if completed.has(quest_id) or active.has(quest_id) or not quests.has(quest_id):
		return false
	var progress: Dictionary = {}
	for objective in quests[quest_id].get("objectives", []):
		progress[_objective_key(objective)] = 0
	active[quest_id] = progress
	return true

func register_kill(enemy_name: String) -> void:
	_register("kill", enemy_name, 1)

func register_collect(item_name: String, amount: int = 1) -> void:
	_register("collect", item_name, amount)

func register_visit(map_id: String) -> void:
	_register("visit", map_id, 1)

# Recado/entrega: falar com um NPC so conta depois que os outros objetivos da missao
# estao completos (ex.: "avise o Capitao Maren quando a rota estiver segura").
# Devolve os ids das missoes que avancaram.
func register_talk(npc_name: String) -> Array:
	var advanced: Array = []
	for quest_id in active.keys():
		var objectives: Array = quests[quest_id].get("objectives", [])
		var others_done := true
		for objective in objectives:
			if objective.get("type") != "talk" and int(active[quest_id].get(_objective_key(objective), 0)) < int(objective.get("amount", 1)):
				others_done = false
		if not others_done:
			continue
		for objective in objectives:
			if objective.get("type") == "talk" and objective.get("target") == npc_name:
				var key := _objective_key(objective)
				if int(active[quest_id].get(key, 0)) < int(objective.get("amount", 1)):
					active[quest_id][key] = int(objective.get("amount", 1))
					advanced.append(quest_id)
	return advanced

# Missao ativa que pede para falar com este NPC, mas ainda faltam outros objetivos
func pending_talk_quest(npc_name: String) -> String:
	for quest_id in active.keys():
		for objective in quests[quest_id].get("objectives", []):
			if objective.get("type") == "talk" and objective.get("target") == npc_name \
					and int(active[quest_id].get(_objective_key(objective), 0)) < int(objective.get("amount", 1)):
				return str(quest_id)
	return ""

func _register(kind: String, target: String, amount: int) -> void:
	for quest_id in active.keys():
		for objective in quests[quest_id].get("objectives", []):
			if objective.get("type") == kind and objective.get("target") == target:
				var key := _objective_key(objective)
				active[quest_id][key] = min(int(objective.get("amount", 1)), int(active[quest_id].get(key, 0)) + amount)

func is_ready(quest_id: String) -> bool:
	if not active.has(quest_id):
		return false
	for objective in quests[quest_id].get("objectives", []):
		if int(active[quest_id].get(_objective_key(objective), 0)) < int(objective.get("amount", 1)):
			return false
	return true

func complete(quest_id: String) -> Dictionary:
	if not is_ready(quest_id):
		return {}
	active.erase(quest_id)
	completed.append(quest_id)
	return quests[quest_id].get("rewards", {})

func quest_text(quest_id: String) -> String:
	if not quests.has(quest_id):
		return ""
	var lines := [str(quests[quest_id].get("title", quest_id))]
	for objective in quests[quest_id].get("objectives", []):
		var key := _objective_key(objective)
		var value := int(objective.get("amount", 1)) if completed.has(quest_id) else int(active.get(quest_id, {}).get(key, 0))
		var verb := str(OBJECTIVE_VERBS.get(str(objective.get("type", "")), objective.get("type", "")))
		var target := str(objective.get("target", ""))
		if objective.get("type") == "visit":
			target = str(MAP_NAMES.get(target, target))
		elif objective.get("type") == "talk":
			target = target.get_slice(",", 0)
		lines.append("%s %s: %d/%d" % [verb, target, value, int(objective.get("amount", 1))])
	return "\n".join(lines)

func _objective_key(objective: Dictionary) -> String:
	return "%s:%s" % [objective.get("type", ""), objective.get("target", "")]

func to_save() -> Dictionary:
	return {"active": active, "completed": completed}

func from_save(data: Dictionary) -> void:
	active = data.get("active", {})
	completed = data.get("completed", [])
