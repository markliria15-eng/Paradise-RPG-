extends Area2D
class_name ItemDrop

var item_name := ""
var amount := 1
var is_coin := false
var life_time := 0.0
var collect_delay := 0.18

@onready var label: Label = $Label
@onready var sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	add_to_group("drops")

func _process(delta: float) -> void:
	life_time += delta

func setup(name_value: String, amount_value: int = 1) -> void:
	item_name = name_value
	amount = amount_value
	is_coin = false
	label.text = "%s x%d" % [item_name, amount]
	sprite.texture = load(_sprite_path(item_name))

func setup_coin(amount_value: int) -> void:
	item_name = "Moedas"
	amount = amount_value
	is_coin = true
	label.text = "%d ouro" % amount
	sprite.texture = load("res://assets/sprites/drop_coin.png")

func can_auto_collect() -> bool:
	return life_time >= collect_delay

func _sprite_path(name_value: String) -> String:
	var lower := name_value.to_lower()
	if lower.contains("moeda") or lower.contains("ouro"):
		return "res://assets/sprites/drop_coin.png"
	if lower.contains("pocao"):
		return "res://assets/sprites/drop_potion.png"
	if lower.contains("rubi") or lower.contains("safira") or lower.contains("esmeralda"):
		return "res://assets/sprites/drop_gem.png"
	if lower.contains("capuz") or lower.contains("peitoral") or lower.contains("luvas") or lower.contains("botas"):
		return "res://assets/sprites/drop_bag.png"
	if lower.contains("ferro"):
		return "res://assets/sprites/drop_ore.png"
	if lower.contains("madeira"):
		return "res://assets/sprites/drop_wood.png"
	return "res://assets/sprites/drop_material.png"
