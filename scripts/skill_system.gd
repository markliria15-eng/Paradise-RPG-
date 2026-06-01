extends Node
class_name SkillSystem

static var cooldowns: Dictionary = {}

static func can_use(player: Player, skill: Dictionary) -> bool:
	var id := str(skill.get("id", ""))
	var cost := int(ceil(float(skill.get("mana", 0)) * (1.0 - SkillProgressionSystem.mana_efficiency_bonus(player.skills))))
	return float(cooldowns.get(id, 0.0)) <= Time.get_ticks_msec() / 1000.0 and player.mana >= cost

static func cast(player: Player, skill: Dictionary) -> void:
	var id := str(skill.get("id", ""))
	if not player.spend_mana(int(skill.get("mana", 0))):
		return
	cooldowns[id] = Time.get_ticks_msec() / 1000.0 + float(skill.get("cooldown", 1.0))
	match id:
		"war_cry":
			player.war_cry_bonus = float(skill.get("attack_bonus", 0.2))
			player.war_cry_timer = float(skill.get("duration", 8.0))
		"blade_spin", "arcane_blast", "arrow_rain":
			player.skill_area_requested.emit(float(skill.get("power", 1.0)), float(skill.get("radius", 90)), id)
		"mystic_shield":
			player.shield_points += int(skill.get("shield", 60))
		"quick_jump":
			player.dash_requested.emit(float(skill.get("distance", 120)), id)
		_:
			player.attack_requested.emit(float(skill.get("power", 1.0)), player.alcance, id)

static func cooldown_left(skill: Dictionary) -> float:
	var id := str(skill.get("id", ""))
	return max(0.0, float(cooldowns.get(id, 0.0)) - Time.get_ticks_msec() / 1000.0)
