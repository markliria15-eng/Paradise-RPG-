extends Area2D
class_name Npc

var npc_name := ""
var role := ""
var quest_id := ""
var sprite_override := ""

@onready var sprite: Sprite2D = $Sprite2D
@onready var label: Label = $Label

func setup(data: Dictionary) -> void:
	npc_name = str(data.get("name", "NPC"))
	role = str(data.get("role", ""))
	quest_id = str(data.get("quest", ""))
	sprite_override = str(data.get("sprite", ""))
	label.text = npc_name
	var sprite_path := sprite_override if not sprite_override.is_empty() else _sprite_path(role)
	sprite.texture = load(sprite_path)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_fit_sprite_to_npc()

func _fit_sprite_to_npc() -> void:
	if sprite.texture == null:
		return
	var target_height := 132.0
	var texture_height: float = maxf(1.0, float(sprite.texture.get_height()))
	var sprite_scale: float = target_height / texture_height
	sprite.scale = Vector2(sprite_scale, sprite_scale)
	# Ajusta para manter os pes no "chao" do NPC.
	sprite.position = Vector2(0, -34)
	label.offset_left = -130
	label.offset_right = 130
	label.offset_top = -112
	label.offset_bottom = -86

func _sprite_path(npc_role: String) -> String:
	match npc_role:
		"healer":
			return "res://assets/sprites/npc_healer.png"
		"shop":
			return "res://assets/sprites/npc_shop.png"
		"class_master":
			return "res://assets/sprites/npc_master.png"
		"forge":
			return "res://assets/sprites/npc_forge.png"
		"quest":
			return "res://assets/sprites/npc_quest.png"
	return "res://assets/sprites/npc_quest.png"
