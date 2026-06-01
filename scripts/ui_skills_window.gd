extends RefCounted
class_name UISkillsWindow

static func percent(skill: Dictionary) -> int:
	var required: int = max(1, int(skill.get("xp_required", 1)))
	return int(clamp(round(float(skill.get("xp", 0)) / float(required) * 100.0), 0, 100))

static func icon_for(skill_id: String) -> Texture2D:
	return load(str(SkillProgressionSystem.SKILL_ICONS.get(skill_id, "res://assets/sprites/icon_skill_arcane_blast.png"))) as Texture2D
