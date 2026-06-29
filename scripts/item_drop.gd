extends Area2D
class_name ItemDrop

var item_name := ""
var amount := 1
var is_coin := false
var life_time := 0.0
var collect_delay := 0.18

@onready var label: Label = $Label
@onready var sprite: Sprite2D = $Sprite2D
@onready var accent_sprite: Sprite2D = get_node_or_null("AccentSprite2D") as Sprite2D

func _ready() -> void:
	add_to_group("drops")
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.z_index = 0
	if accent_sprite != null:
		accent_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		accent_sprite.z_index = 1
	label.z_index = 2

func _process(delta: float) -> void:
	life_time += delta

func setup(name_value: String, amount_value: int = 1) -> void:
	item_name = name_value
	amount = amount_value
	is_coin = false
	label.text = "%s x%d" % [item_name, amount]
	_apply_visual_profile(item_name)

func setup_coin(amount_value: int) -> void:
	item_name = "Moedas"
	amount = amount_value
	is_coin = true
	label.text = "%d ouro" % amount
	if accent_sprite != null:
		accent_sprite.visible = false
	sprite.texture = load("res://assets/sprites/drop_coin.png")
	sprite.scale = Vector2(2.0, 2.0)
	sprite.position = Vector2.ZERO
	sprite.z_index = 0
	label.position = Vector2(-55.0, -34.0)

func can_auto_collect() -> bool:
	return life_time >= collect_delay

func _apply_visual_profile(name_value: String) -> void:
	var profile := _visual_profile_for(name_value)
	var base_path := str(profile.get("base", _sprite_path(name_value)))
	var accent_path := str(profile.get("accent", ""))
	var scale := float(profile.get("scale", 2.0))
	var accent_scale := float(profile.get("accent_scale", scale))
	var accent_offset := profile.get("accent_offset", Vector2.ZERO) as Vector2
	var label_offset := profile.get("label_offset", Vector2(-55.0, -34.0)) as Vector2
	var base_offset := profile.get("base_offset", Vector2.ZERO) as Vector2

	sprite.texture = load(base_path)
	sprite.scale = Vector2(scale, scale)
	sprite.position = base_offset
	sprite.visible = true

	if accent_sprite != null:
		if accent_path.is_empty():
			accent_sprite.visible = false
		else:
			accent_sprite.texture = load(accent_path)
			accent_sprite.scale = Vector2(accent_scale, accent_scale)
			accent_sprite.position = accent_offset
			accent_sprite.visible = true

	label.position = label_offset

func _visual_profile_for(name_value: String) -> Dictionary:
	var lower := name_value.to_lower()
	if _is_forest_plant(lower):
		if lower.contains("flor") or lower.contains("flower"):
			return {
				"base": "res://assets/sprites/decor_flower_patch.png",
				"accent": "res://assets/sprites/decor_grass_tuft.png",
				"scale": 2.65,
				"accent_scale": 1.15,
				"accent_offset": Vector2(0.0, 4.0),
				"label_offset": Vector2(-66.0, -42.0)
			}
		if lower.contains("cogum") or lower.contains("fung") or lower.contains("mush"):
			return {
				"base": "res://assets/sprites/decor_leaf_patch.png",
				"accent": "res://assets/sprites/decor_flower_patch.png",
				"scale": 2.55,
				"accent_scale": 1.0,
				"accent_offset": Vector2(3.0, -1.0),
				"label_offset": Vector2(-66.0, -42.0)
			}
		if lower.contains("erva") or lower.contains("raiz") or lower.contains("broto") or lower.contains("semente"):
			return {
				"base": "res://assets/sprites/decor_leaf_patch.png",
				"accent": "res://assets/sprites/decor_grass_tuft.png",
				"scale": 2.45,
				"accent_scale": 1.08,
				"accent_offset": Vector2(2.0, 1.0),
				"label_offset": Vector2(-66.0, -42.0)
			}
		return {
			"base": "res://assets/sprites/decor_bush.png",
			"accent": "res://assets/sprites/decor_flower_patch.png",
			"scale": 2.55,
			"accent_scale": 1.0,
			"accent_offset": Vector2(0.0, 2.0),
			"label_offset": Vector2(-66.0, -42.0)
		}
	return {}

func _is_forest_plant(lower: String) -> bool:
	return (
		lower.contains("erva")
		or lower.contains("folha")
		or lower.contains("flor")
		or lower.contains("planta")
		or lower.contains("raiz")
		or lower.contains("broto")
		or lower.contains("semente")
		or lower.contains("cogum")
		or lower.contains("fung")
		or lower.contains("musgo")
	)

func _sprite_path(name_value: String) -> String:
	var lower := name_value.to_lower()
	if lower.contains("moeda") or lower.contains("ouro"):
		return "res://assets/sprites/drop_coin.png"
	if lower.contains("pocao"):
		return "res://assets/sprites/drop_potion.png"
	if lower.contains("rubi") or lower.contains("safira") or lower.contains("esmeralda"):
		return "res://assets/sprites/drop_gem.png"
	if lower.contains("erva") or lower.contains("folha") or lower.contains("flor"):
		if lower.contains("vermelha") or lower.contains("curativa"):
			return "res://assets/sprites/decor_flower_patch.png"
		return "res://assets/sprites/decor_leaf_patch.png"
	if lower.contains("capuz") or lower.contains("peitoral") or lower.contains("luvas") or lower.contains("botas"):
		return "res://assets/sprites/drop_bag.png"
	if lower.contains("ferro"):
		return "res://assets/sprites/drop_ore.png"
	if lower.contains("madeira"):
		return "res://assets/sprites/drop_wood.png"
	return "res://assets/sprites/drop_material.png"
