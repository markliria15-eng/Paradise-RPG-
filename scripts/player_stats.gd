extends RefCounted
class_name PlayerStats

const STAT_ALIASES := {
	"defense": "defesa",
	"hp_max": "vida_max",
	"mp_max": "mana_max",
	"attack": "ataque",
	"magic_attack": "ataque_magico",
	"distance_attack": "ataque_distancia",
	"move_speed": "move_speed_pct",
	"attack_speed": "attack_speed_pct"
}

static func normalized_stats(item_data: Dictionary) -> Dictionary:
	var result := {}
	var stats: Dictionary = item_data.get("stats", {})
	for raw_key in stats.keys():
		var key := str(STAT_ALIASES.get(str(raw_key), str(raw_key)))
		result[key] = stats[raw_key]
	return result
