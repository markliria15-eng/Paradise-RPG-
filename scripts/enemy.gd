extends CharacterBody2D
class_name Enemy

# Inimigo simples de MVP: persegue o jogador, ataca em alcance curto e emite
# sinal de morte para o mapa aplicar XP, ouro, drops e progresso de quest.
signal killed(enemy: Enemy)

var enemy_name := ""
var level := 1
var vida := 1
var vida_max := 1
var ataque := 1
var defesa := 0
var xp := 0
var speed := 90.0
var poison_chance := 0.0
var boss := false
var target: Player
var attack_timer := 0.0
var is_targeted := false

@onready var sprite: Sprite2D = $Sprite2D
@onready var label: Label = $Label
@onready var health_bar: ProgressBar = $HealthBar

func setup(name_value: String, data: Dictionary, player: Player) -> void:
	collision_layer = 2
	collision_mask = 0
	enemy_name = name_value
	target = player
	level = int(data.get("level", 1))
	vida_max = int(data.get("vida", 1))
	vida = vida_max
	ataque = int(data.get("ataque", 1))
	defesa = int(data.get("defesa", 0))
	xp = int(data.get("xp", 0))
	speed = float(data.get("speed", 90))
	poison_chance = float(data.get("poison_chance", 0.0))
	boss = bool(data.get("boss", false))
	sprite.texture = load(_sprite_path(name_value))
	label.text = "BOSS Lv %d %s" % [level, name_value] if boss else "Lv %d %s" % [level, name_value]
	if boss:
		sprite.scale *= 1.32
		label.add_theme_color_override("font_color", Color("#ffd36b"))
	label.visible = true
	_update_health_bar()

func _physics_process(delta: float) -> void:
	if target == null:
		return
	if target.in_safe_zone:
		velocity = Vector2.ZERO
		return
	var distance := global_position.distance_to(target.global_position)
	label.visible = true
	health_bar.visible = true
	if distance < 320 and distance > 34:
		velocity = global_position.direction_to(target.global_position) * speed
		move_and_slide()
	else:
		velocity = Vector2.ZERO
	if attack_timer > 0:
		attack_timer -= delta
	if distance <= 42 and attack_timer <= 0:
		attack_timer = 1.25
		var damage := CombatSystem.physical_damage(ataque, target.defesa)
		target.receive_damage(damage, poison_chance)

func receive_damage(amount: int) -> void:
	vida = max(0, vida - amount)
	_update_health_bar()
	if vida <= 0:
		killed.emit(self)
		queue_free()

func set_targeted(value: bool) -> void:
	is_targeted = value
	if label == null or sprite == null:
		return
	if is_targeted:
		label.add_theme_color_override("font_color", Color("#ff4b4b"))
		sprite.modulate = Color(1.25, 0.92, 0.92, 1)
	else:
		label.add_theme_color_override("font_color", Color("#ffd36b") if boss else Color.WHITE)
		sprite.modulate = Color.WHITE

func _update_health_bar() -> void:
	if health_bar == null:
		return
	health_bar.max_value = vida_max
	health_bar.value = vida

func _sprite_path(name_value: String) -> String:
	match name_value:
		"Javali Selvagem":
			return "res://assets/sprites/enemy_javali.png"
		"Lobo Cinzento":
			return "res://assets/sprites/enemy_lobo.png"
		"Espirito Fraco":
			return "res://assets/sprites/enemy_espirito.png"
		"Aprendiz Corrompido":
			return "res://assets/sprites/enemy_aprendiz.png"
		"Morcego Pequeno":
			return "res://assets/sprites/enemy_morcego.png"
		"Aranha Venenosa":
			return "res://assets/sprites/enemy_aranha.png"
		"Javali Bruto":
			return "res://assets/sprites/enemy_javali.png"
		"Lobo Alfa":
			return "res://assets/sprites/enemy_lobo.png"
		"Rei Javali":
			return "res://assets/sprites/enemy_javali.png"
		"Espectro Arcano":
			return "res://assets/sprites/enemy_espirito.png"
		"Sentinela Arcano":
			return "res://assets/sprites/enemy_aprendiz.png"
		"Arquimago Corrompido":
			return "res://assets/sprites/enemy_aprendiz.png"
		"Morcego Sombrio":
			return "res://assets/sprites/enemy_morcego.png"
		"Aranha Rainha":
			return "res://assets/sprites/enemy_aranha.png"
		"Matriarca Venenosa":
			return "res://assets/sprites/enemy_aranha.png"
	return "res://assets/sprites/enemy_javali.png"
