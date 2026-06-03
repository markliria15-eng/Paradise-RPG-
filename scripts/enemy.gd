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
var base_defesa := 0
var base_ataque := 1
var slow_multiplier := 1.0
var debuff_timer := 0.0
var stun_timer := 0.0
var burn_timer := 0.0
var burn_tick_timer := 0.0
var burn_damage := 0
var safe_zone_checker: Callable

@onready var sprite: Sprite2D = $Sprite2D
@onready var label: Label = $Label
@onready var health_bar: ProgressBar = $HealthBar

func setup(name_value: String, data: Dictionary, player: Player) -> void:
	collision_layer = 2
	collision_mask = 0
	enemy_name = name_value
	target = player
	level = int(data.get("level", 1))
	var level_range: Array = data.get("level_range", [])
	if level_range.size() >= 2:
		level = randi_range(int(level_range[0]), int(level_range[1]))
	vida_max = int(data.get("vida", 1))
	ataque = int(data.get("ataque", 1))
	defesa = int(data.get("defesa", 0))
	var base_level := int(data.get("level", level))
	var level_bonus: int = max(0, level - base_level)
	vida_max += level_bonus * 9
	ataque += level_bonus * 2
	defesa += int(floor(float(level_bonus) * 0.75))
	vida = vida_max
	base_ataque = ataque
	base_defesa = defesa
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
	if debuff_timer > 0:
		debuff_timer -= delta
		if debuff_timer <= 0:
			defesa = base_defesa
			ataque = base_ataque
			slow_multiplier = 1.0
	if stun_timer > 0:
		stun_timer -= delta
		velocity = Vector2.ZERO
		return
	if burn_timer > 0:
		burn_timer -= delta
		burn_tick_timer -= delta
		if burn_tick_timer <= 0:
			burn_tick_timer = 1.0
			receive_damage(max(1, burn_damage))
	if target.in_safe_zone or (safe_zone_checker.is_valid() and bool(safe_zone_checker.call(global_position))):
		velocity = Vector2.ZERO
		return
	var distance := global_position.distance_to(target.global_position)
	label.visible = true
	health_bar.visible = true
	if distance < 320 and distance > 34:
		velocity = global_position.direction_to(target.global_position) * speed * slow_multiplier
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

func apply_pet_debuff(kind: String, amount: float, duration: float) -> void:
	debuff_timer = max(debuff_timer, duration)
	match kind:
		"defense_down", "magic_mark":
			defesa = max(0, base_defesa - int(round(amount)))
		"weakness":
			ataque = max(1, base_ataque - int(round(amount)))
		"slow":
			slow_multiplier = clamp(1.0 - amount, 0.45, 1.0)

func apply_stun(duration: float) -> void:
	stun_timer = max(stun_timer, duration)
	label.add_theme_color_override("font_color", Color("#8fd7ff"))

func apply_burn(amount: int, duration: float) -> void:
	burn_damage = max(1, amount)
	burn_timer = max(burn_timer, duration)
	burn_tick_timer = 1.0
	sprite.modulate = Color(1.25, 0.78, 0.48, 1.0)

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
