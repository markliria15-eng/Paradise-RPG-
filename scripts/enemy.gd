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
var visual_attack_timer := 0.0
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
var obstacle_checker: Callable

@onready var sprite: Sprite2D = $Sprite2D
@onready var label: Label = $Label
@onready var health_bar: ProgressBar = $HealthBar
var shadow_sprite: Sprite2D
var idle_frames: Array = []
var walk_frames: Array = []
var visual_frame_index := 0
var visual_frame_timer := 0.0
var visual_base_scale := Vector2.ONE
var visual_base_position := Vector2.ZERO

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
	_ensure_shadow()
	var sprite_path := _sprite_path(name_value)
	sprite.texture = load(sprite_path)
	_load_visual_frames(sprite_path)
	label.text = "BOSS Lv %d %s" % [level, name_value] if boss else "Lv %d %s" % [level, name_value]
	_fit_sprite_to_enemy()
	if boss:
		sprite.scale *= 1.32
		label.add_theme_color_override("font_color", Color("#ffd36b"))
	visual_base_scale = sprite.scale
	visual_base_position = sprite.position
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
		_update_visual_animation(delta)
		return
	if burn_timer > 0:
		burn_timer -= delta
		burn_tick_timer -= delta
		if burn_tick_timer <= 0:
			burn_tick_timer = 1.0
			receive_damage(max(1, burn_damage))
	if target.in_safe_zone or (safe_zone_checker.is_valid() and bool(safe_zone_checker.call(global_position))):
		velocity = Vector2.ZERO
		_update_visual_animation(delta)
		return
	var distance := global_position.distance_to(target.global_position)
	label.visible = true
	health_bar.visible = true
	if distance < 320 and distance > 34:
		velocity = global_position.direction_to(target.global_position) * speed * slow_multiplier
		var previous_position := global_position
		move_and_slide()
		if obstacle_checker.is_valid() and bool(obstacle_checker.call(global_position)):
			global_position = previous_position
			velocity = Vector2.ZERO
	else:
		velocity = Vector2.ZERO
	if attack_timer > 0:
		attack_timer -= delta
	if distance <= 42 and attack_timer <= 0:
		attack_timer = 1.25
		var damage := CombatSystem.physical_damage(ataque, target.defesa)
		target.receive_damage(damage, poison_chance)
		visual_attack_timer = 0.18
	_update_visual_animation(delta)

func receive_damage(amount: int) -> void:
	vida = max(0, vida - amount)
	_update_health_bar()
	if vida <= 0:
		killed.emit(self)
		queue_free()

func _fit_sprite_to_enemy() -> void:
	if sprite.texture == null:
		return
	var target_height := 54.0
	var texture_height: float = maxf(1.0, float(sprite.texture.get_height()))
	var sprite_scale: float = target_height / texture_height
	sprite.scale = Vector2(sprite_scale, sprite_scale)
	sprite.position = Vector2(0, -12)
	if shadow_sprite != null:
		shadow_sprite.position = Vector2(0, 20)
		shadow_sprite.scale = Vector2(0.72, 0.38)

func _load_visual_frames(sprite_path: String) -> void:
	idle_frames.clear()
	walk_frames.clear()
	var base := sprite_path.replace(".png", "")
	for i in range(1, 3):
		var path := "%s_idle_%d.png" % [base, i]
		if ResourceLoader.exists(path):
			idle_frames.append(load(path))
	for i in range(1, 5):
		var path := "%s_walk_%d.png" % [base, i]
		if ResourceLoader.exists(path):
			walk_frames.append(load(path))
	if sprite.texture != null and idle_frames.is_empty():
		idle_frames.append(sprite.texture)

func _update_visual_animation(delta: float) -> void:
	var moving := velocity.length() > 4.0
	var frames := walk_frames if moving and not walk_frames.is_empty() else idle_frames
	if frames.is_empty():
		return
	if moving and abs(velocity.x) > 4.0:
		sprite.flip_h = velocity.x < 0.0
	var delay := 0.12 if moving else 0.42
	visual_frame_timer += delta
	if visual_frame_timer >= delay:
		visual_frame_timer = 0.0
		visual_frame_index = (visual_frame_index + 1) % frames.size()
	sprite.texture = frames[visual_frame_index % frames.size()]
	if visual_attack_timer > 0.0:
		visual_attack_timer -= delta
		var side := -1.0 if sprite.flip_h else 1.0
		sprite.scale = visual_base_scale * 1.08
		sprite.position = visual_base_position + Vector2(3.0 * side, -1.0)
	else:
		sprite.scale = visual_base_scale
		sprite.position = visual_base_position

func _ensure_shadow() -> void:
	if shadow_sprite != null:
		return
	var texture := load("res://assets/sprites/decor_shadow_soft.png") as Texture2D
	if texture == null:
		return
	shadow_sprite = Sprite2D.new()
	shadow_sprite.texture = texture
	shadow_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	shadow_sprite.modulate = Color(1, 1, 1, 0.70)
	shadow_sprite.z_index = -1
	add_child(shadow_sprite)

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
			return "res://assets/sprites/enemy_javali_bruto.png"
		"Lobo Alfa":
			return "res://assets/sprites/enemy_lobo_alfa.png"
		"Rei Javali":
			return "res://assets/sprites/enemy_javali_rei.png"
		"Espectro Arcano":
			return "res://assets/sprites/enemy_espirito_arcano.png"
		"Sentinela Arcano":
			return "res://assets/sprites/enemy_sentinela_arcano.png"
		"Arquimago Corrompido":
			return "res://assets/sprites/enemy_arquimago_corrompido.png"
		"Morcego Sombrio":
			return "res://assets/sprites/enemy_morcego_sombrio.png"
		"Aranha Rainha":
			return "res://assets/sprites/enemy_aranha_rainha.png"
		"Matriarca Venenosa":
			return "res://assets/sprites/enemy_aranha_matriarca.png"
		"Bandido das Colinas":
			return "res://assets/sprites/enemy_bandido_colinas.png"
		"Golem de Pedra":
			return "res://assets/sprites/enemy_golem_pedra.png"
		"Senhor das Colinas":
			return "res://assets/sprites/enemy_javali_rei.png"
		"Guardiao Cristalino":
			return "res://assets/sprites/enemy_guardiao_cristalino.png"
		"Draco Jovem":
			return "res://assets/sprites/enemy_draco_jovem.png"
		"Tita de Cristal":
			return "res://assets/sprites/enemy_tita_cristal.png"
		"Cavaleiro Sombrio":
			return "res://assets/sprites/enemy_cavaleiro_sombrio.png"
		"General Infernal":
			return "res://assets/sprites/enemy_general_infernal.png"
	return "res://assets/sprites/enemy_javali.png"
