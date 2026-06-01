extends Node
class_name CombatFeedback

const FLOATING_TEXT_SCENE := preload("res://scenes/ui/components/floating_text.tscn")

func show(world: Node, at: Vector2, text: String, kind: String = "damage") -> void:
	if world == null:
		return
	var floating = FLOATING_TEXT_SCENE.instantiate()
	world.add_child(floating)
	floating.global_position = at
	floating.call("setup_kind", text, kind)

