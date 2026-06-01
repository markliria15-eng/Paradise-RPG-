extends RefCounted
class_name SkillProgressionSystem

const SKILL_ORDER := ["fighting", "distance", "magic", "protection"]
const SKILL_ICONS := {
	"fighting": "res://assets/sprites/icon_attack_sword.png",
	"distance": "res://assets/sprites/icon_attack_bow.png",
	"magic": "res://assets/sprites/icon_skill_arcane_blast.png",
	"protection": "res://assets/sprites/icon_skill_mystic_shield.png"
}
const CLASS_MULTIPLIERS := {
	"Guerreiro": {"fighting": 1.2, "protection": 1.2, "magic": 0.8, "distance": 1.0},
	"Mago": {"magic": 1.3, "protection": 0.9, "fighting": 0.8, "distance": 1.0},
	"Arqueiro": {"distance": 1.3, "fighting": 0.9, "protection": 1.0, "magic": 1.0}
}

static func default_skills() -> Dictionary:
	var data := ItemDatabase.load_json("res://data/skills.json")
	if data.is_empty():
		data = {
			"fighting": {"name": "Lutando", "level": 10, "xp": 0},
			"distance": {"name": "Distancia", "level": 10, "xp": 0},
			"magic": {"name": "Magica", "level": 10, "xp": 0},
			"protection": {"name": "Protecao", "level": 10, "xp": 0}
		}
	for skill_id in data.keys():
		var skill: Dictionary = data[skill_id]
		skill["xp_required"] = xp_required(int(skill.get("level", 10)))
		data[skill_id] = skill
	return data

static func xp_required(level: int) -> int:
	return 100 + level * 25

static func add_xp(skills: Dictionary, skill_id: String, base_amount: int, player_class: String) -> Array[String]:
	if not skills.has(skill_id):
		return []
	var skill: Dictionary = skills[skill_id]
	var multipliers: Dictionary = CLASS_MULTIPLIERS.get(player_class, {})
	var gained := int(round(float(base_amount) * float(multipliers.get(skill_id, 1.0))))
	skill["xp"] = int(skill.get("xp", 0)) + max(1, gained)
	var messages: Array[String] = []
	while int(skill["xp"]) >= xp_required(int(skill.get("level", 10))):
		var required := xp_required(int(skill.get("level", 10)))
		skill["xp"] = int(skill["xp"]) - required
		skill["level"] = int(skill.get("level", 10)) + 1
		skill["xp_required"] = xp_required(int(skill["level"]))
		messages.append("Sua habilidade %s subiu para %d!" % [str(skill.get("name", skill_id)), int(skill["level"])])
	skill["xp_required"] = xp_required(int(skill.get("level", 10)))
	skills[skill_id] = skill
	return messages

static func skill_level(skills: Dictionary, skill_id: String) -> int:
	if not skills.has(skill_id):
		return 10
	return int(Dictionary(skills[skill_id]).get("level", 10))

static func fighting_damage_bonus(skills: Dictionary) -> float:
	return max(0, skill_level(skills, "fighting") - 10) * 0.01

static func distance_damage_bonus(skills: Dictionary) -> float:
	return max(0, skill_level(skills, "distance") - 10) * 0.01

static func magic_damage_bonus(skills: Dictionary) -> float:
	return max(0, skill_level(skills, "magic") - 10) * 0.01

static func mana_efficiency_bonus(skills: Dictionary) -> float:
	return floor(max(0, skill_level(skills, "magic") - 10) / 5.0) * 0.01

static func protection_defense_bonus(skills: Dictionary) -> int:
	return int(floor(max(0, skill_level(skills, "protection") - 10) / 3.0))
