extends Node
class_name CombatSystem

static func physical_damage(attacker_attack: float, defender_defense: float, multiplier: float = 1.0, bonus_pct: float = 0.0) -> int:
	var variance := randi_range(-2, 3)
	var raw := (attacker_attack * multiplier) + variance
	raw *= 1.0 + bonus_pct
	return max(1, int(round(raw - defender_defense)))

static func roll_critical(chance: float, multiplier: float = 1.5) -> float:
	if randf() <= chance:
		return multiplier
	return 1.0
