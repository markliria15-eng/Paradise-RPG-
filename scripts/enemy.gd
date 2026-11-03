extends CharacterBody2D
class_name Enemy

# Inimigo simples de MVP: persegue o jogador, ataca em alcance curto e emite
# sinal de morte para o mapa aplicar XP, ouro, drops e progresso de quest.
signal killed(enemy: Enemy)

const CombatVisuals = preload("res://scripts/combat_visuals.gd")
var special_attack_frames: Array = []
var special_attack_index := 0

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
var directional_frames: Dictionary = {}
var visual_direction := "front"
var visual_frame_index := 0
var visual_frame_timer := 0.0
var visual_base_scale := Vector2.ONE
var visual_base_position := Vector2.ZERO
var visual_animation_key := ""
var procedural_walk_time := 0.0
var visual_flip_from_left := false
# Arte so lateral (front/back sao copias de left): espelha pelo eixo X com
# zona morta, para o mob nao alternar de lado a cada frame na diagonal.
const FACING_DEADZONE := 14.0
const AXIS_HYSTERESIS := 1.3
const ATTACK_FRAME_TIME := 0.07
const DEATH_FRAME_TIME := 0.09
const DEATH_HOLD_TIME := 0.6
# Mobs cujos frames de morte atuais estao quebrados; remover ao regenerar a arte.
const DEATH_ANIM_BLOCKLIST := ["javali_selvagem", "javali_rei", "lobo_selvagem"]
static var _side_only_cache := {}
# Pasta em assets/sprites/mobs/ de cada mob a refazer (ver docs/PROMPT_SPRITES_MOBS.md).
const PACKED_MOB_ASSETS := {
	"Aranha Venenosa": "aranha_venenosa",
	"Aranha Rainha": "aranha_rainha",
	"Matriarca Venenosa": "aranha_matriarca",
	"Espirito Fraco": "espirito_fraco",
	"Aprendiz Corrompido": "aprendiz_corrompido",
	"Espectro Arcano": "espectro_arcano",
	"Sentinela Arcano": "sentinela_arcano",
	"Arquimago Corrompido": "arquimago_corrompido",
	"Bandido das Colinas": "bandido_colinas",
	"Golem de Pedra": "golem_pedra",
	"Senhor das Colinas": "senhor_colinas",
	"Guardiao Cristalino": "guardiao_cristalino",
	"Draco Jovem": "draco_jovem",
	"Tita de Cristal": "tita_cristal",
	"Cavaleiro Sombrio": "cavaleiro_sombrio",
	"General Infernal": "general_infernal",
}
# Tamanho em relacao ao jogador (altura VISIVEL do sprite, sem a borda transparente).
# A altura do jogador e medida no proprio sprite dele; 75 px e so o valor reserva.
# 1.0 = mesma altura do jogador.
const PLAYER_VISIBLE_HEIGHT := 75.0
const ENEMY_SIZE_DEFAULT := 0.9
const BOSS_SIZE_DEFAULT := 2.0
const ENEMY_SIZE := {
	"Espirito Fraco": 0.6,
	"Morcego Pequeno": 0.5,
	"Morcego Sombrio": 0.6,
	"Aranha Venenosa": 0.65,
	"Javali Selvagem": 0.7,
	"Lobo Cinzento": 0.72,
	"Javali Bruto": 0.85,
	"Lobo Alfa": 0.85,
	"Aprendiz Corrompido": 1.0,
	"Bandido das Colinas": 1.0,
	"Espectro Arcano": 1.05,
	"Sentinela Arcano": 1.1,
	"Cavaleiro Sombrio": 1.15,
	"Aranha Rainha": 1.1,
	"Draco Jovem": 1.45,
	"Guardiao Cristalino": 1.5,
	"Golem de Pedra": 1.6,
	"Rei Javali": 1.9,
	"Arquimago Corrompido": 1.9,
	"Matriarca Venenosa": 2.1,
	"Senhor das Colinas": 2.1,
	"General Infernal": 2.3,
	"Tita de Cristal": 2.4,
}
static var _visible_rect_cache: Dictionary = {}
# Alcance corpo a corpo cresce com o tamanho (golem/chefe nao "entram" no jogador).
var body_reach := 1.0
var visual_asset := ""
var visual_side_only := false
var visual_facing_right := false
# Golpes com peso (CombatJuice): empurrao, flash e achatamento ao apanhar.
const HIT_REACT_DURATION := 0.14
var knockback_velocity := Vector2.ZERO
var hit_react_timer := 0.0
var hit_flash_tween: Tween
# Investida de chefe (boss): aviso (para, treme, faixa vermelha) -> disparada -> cansado.
const CHARGE_RANGE_MIN := 90.0
const CHARGE_RANGE_MAX := 340.0
const CHARGE_WINDUP := 0.85
const CHARGE_DURATION := 0.5
const CHARGE_SPEED := 640.0
const CHARGE_TIRED := 1.2
const CHARGE_COOLDOWN := 4.0
const CHARGE_DAMAGE_MULT := 2.2
const CHARGE_HIT_RADIUS := 78.0
const CHARGE_STUN_SECONDS := 3.0
# Chefe bate mais pesado e mais devagar; abaixo de 35% de vida fica furioso
# (ataca e investe mais rapido).
const BOSS_ATTACK_INTERVAL := 1.6
const BOSS_ENRAGED_ATTACK_INTERVAL := 1.15
const BOSS_ENRAGE_HP_PCT := 0.35
const BOSS_ENRAGED_CHARGE_COOLDOWN_MULT := 0.65
const BOSS_TARGET_HEIGHT := 168.0
var charge_state := ""
var charge_timer := 0.0
var charge_cooldown := 2.0
var charge_dir := Vector2.ZERO
var charge_hit_done := false
var charge_marker: Polygon2D

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
	if hit_react_timer > 0.0:
		hit_react_timer = max(0.0, hit_react_timer - delta)
	if knockback_velocity.length() > 8.0:
		velocity = knockback_velocity
		var knock_previous := global_position
		move_and_slide()
		if obstacle_checker.is_valid() and bool(obstacle_checker.call(global_position)):
			global_position = knock_previous
			knockback_velocity = Vector2.ZERO
		knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, 2600.0 * delta)
		velocity = Vector2.ZERO
		_update_visual_animation(delta)
		z_index = clampi(int(global_position.y), -1024, 1024)
		return
	knockback_velocity = Vector2.ZERO
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
		_cancel_charge()
		velocity = Vector2.ZERO
		_update_visual_animation(delta)
		return
	if boss and _update_charge(delta):
		z_index = clampi(int(global_position.y), -1024, 1024)
		return
	var distance := global_position.distance_to(target.global_position)
	label.visible = true
	health_bar.visible = true
	if distance < 320 and distance > 34.0 * body_reach:
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
	if distance <= 42.0 * body_reach and attack_timer <= 0:
		attack_timer = 1.25
		if boss:
			attack_timer = BOSS_ENRAGED_ATTACK_INTERVAL if _is_enraged() else BOSS_ATTACK_INTERVAL
		var damage := CombatSystem.physical_damage(ataque, target.defesa)
		_prepare_special_visual()
		target.receive_damage(damage, poison_chance)
		visual_attack_timer = max(0.18, float(_attack_frames().size()) * ATTACK_FRAME_TIME)
	_update_visual_animation(delta)
	z_index = clampi(int(global_position.y), -1024, 1024)

func receive_damage(amount: int) -> void:
	vida = max(0, vida - amount)
	_update_health_bar()
	if vida <= 0:
		var world := get_parent()
		if world != null and sprite != null:
			var death_frames := _death_frames()
			if death_frames.is_empty():
				CombatJuice.spawn_death_burst(world, sprite.global_position, sprite.texture, sprite.global_scale, sprite.flip_h)
			else:
				CombatJuice.spawn_death_burst(world, sprite.global_position, null, sprite.global_scale, sprite.flip_h)
				_spawn_death_animation(world, death_frames)
		killed.emit(self)
		queue_free()

func apply_hit_reaction(from_pos: Vector2, force: float) -> void:
	if vida <= 0 or sprite == null:
		return
	if charge_state == "dash":
		force = 0.0
	var direction := from_pos.direction_to(global_position)
	if direction == Vector2.ZERO:
		direction = Vector2.RIGHT
	knockback_velocity = direction * force * (0.3 if boss else 1.0)
	hit_react_timer = HIT_REACT_DURATION
	if hit_flash_tween != null and hit_flash_tween.is_valid():
		hit_flash_tween.kill()
	sprite.modulate = Color(2.6, 2.6, 2.6, 1.0)
	hit_flash_tween = create_tween()
	hit_flash_tween.tween_property(sprite, "modulate", _rest_modulate(), 0.16)

func _update_charge(delta: float) -> bool:
	var distance := global_position.distance_to(target.global_position)
	match charge_state:
		"":
			charge_cooldown -= delta
			if charge_cooldown > 0.0 or distance > CHARGE_RANGE_MAX:
				return false
			if distance < CHARGE_RANGE_MIN:
				# Colado no jogador: recua alguns passos para ganhar distancia.
				charge_state = "backoff"
				charge_timer = 0.9
				return true
			charge_state = "windup"
			charge_timer = CHARGE_WINDUP
			charge_dir = global_position.direction_to(target.global_position)
			_show_charge_marker()
			velocity = Vector2.ZERO
			_update_visual_animation(delta)
			return true
		"backoff":
			charge_timer -= delta
			velocity = target.global_position.direction_to(global_position) * speed * 1.6
			var back_previous := global_position
			move_and_slide()
			if obstacle_checker.is_valid() and bool(obstacle_checker.call(global_position)):
				global_position = back_previous
				charge_timer = 0.0
			_update_visual_animation(delta)
			if charge_timer <= 0.0 or distance >= CHARGE_RANGE_MIN + 60.0:
				charge_state = "windup"
				charge_timer = CHARGE_WINDUP
				charge_dir = global_position.direction_to(target.global_position)
				_show_charge_marker()
				velocity = Vector2.ZERO
			return true
		"windup":
			charge_timer -= delta
			velocity = Vector2.ZERO
			_update_visual_animation(delta)
			sprite.position += Vector2(randf_range(-3.0, 3.0), randf_range(-1.0, 1.0))
			sprite.modulate = Color(1.7, 0.55, 0.45, 1.0) if int(charge_timer * 14.0) % 2 == 0 else _rest_modulate()
			if charge_timer <= 0.0:
				charge_state = "dash"
				charge_timer = CHARGE_DURATION
				charge_hit_done = false
				sprite.modulate = _rest_modulate()
			return true
		"dash":
			charge_timer -= delta
			velocity = charge_dir * CHARGE_SPEED
			var previous_position := global_position
			move_and_slide()
			if obstacle_checker.is_valid() and bool(obstacle_checker.call(global_position)):
				global_position = previous_position
				charge_timer = 0.0
			if not charge_hit_done and global_position.distance_to(target.global_position) <= CHARGE_HIT_RADIUS:
				charge_hit_done = true
				var damage := CombatSystem.physical_damage(int(round(ataque * CHARGE_DAMAGE_MULT)), target.defesa)
				_prepare_special_visual()
				target.receive_damage(damage, poison_chance)
				if target.has_method("apply_stun"):
					target.apply_stun(CHARGE_STUN_SECONDS)
				CombatJuice.shake(get_viewport().get_camera_2d(), 9.0, 0.3)
			_update_visual_animation(delta)
			if charge_timer <= 0.0:
				charge_state = "tired"
				charge_timer = CHARGE_TIRED
				_remove_charge_marker()
			return true
		"tired":
			charge_timer -= delta
			velocity = Vector2.ZERO
			_update_visual_animation(delta)
			if hit_flash_tween == null or not hit_flash_tween.is_running():
				sprite.modulate = Color(0.72, 0.8, 1.0, 1.0)
			if charge_timer <= 0.0:
				charge_state = ""
				charge_cooldown = CHARGE_COOLDOWN * (BOSS_ENRAGED_CHARGE_COOLDOWN_MULT if _is_enraged() else 1.0)
				sprite.modulate = _rest_modulate()
			return true
	return false

func _is_enraged() -> bool:
	return boss and vida_max > 0 and float(vida) / float(vida_max) <= BOSS_ENRAGE_HP_PCT

func _cancel_charge() -> void:
	if charge_state.is_empty():
		return
	charge_state = ""
	charge_cooldown = CHARGE_COOLDOWN * 0.5
	_remove_charge_marker()
	if sprite != null:
		sprite.modulate = _rest_modulate()

func _show_charge_marker() -> void:
	_remove_charge_marker()
	var world := get_parent()
	if world == null:
		return
	var length := CHARGE_SPEED * CHARGE_DURATION + 40.0
	var half := CHARGE_HIT_RADIUS * 0.55
	charge_marker = Polygon2D.new()
	charge_marker.polygon = PackedVector2Array([Vector2(0, -half), Vector2(length, -half), Vector2(length + 30.0, 0), Vector2(length, half), Vector2(0, half)])
	charge_marker.color = Color(1.0, 0.08, 0.04, 0.0)
	charge_marker.z_as_relative = false
	charge_marker.z_index = -30
	world.add_child(charge_marker)
	charge_marker.global_position = global_position
	charge_marker.rotation = charge_dir.angle()
	var tween := charge_marker.create_tween().set_loops()
	tween.tween_property(charge_marker, "color:a", 0.62, 0.16)
	tween.tween_property(charge_marker, "color:a", 0.32, 0.16)

func _remove_charge_marker() -> void:
	if charge_marker != null and is_instance_valid(charge_marker):
		charge_marker.queue_free()
	charge_marker = null

func _exit_tree() -> void:
	_remove_charge_marker()

func _rest_modulate() -> Color:
	if burn_timer > 0:
		return Color(1.25, 0.78, 0.48, 1.0)
	if is_targeted:
		return Color(1.25, 0.92, 0.92, 1)
	if _is_enraged():
		return Color(1.25, 0.82, 0.78, 1.0)  # furioso: avermelhado
	return Color.WHITE

func _fit_sprite_to_enemy() -> void:
	if sprite.texture == null:
		return
	var tex_size: Vector2 = sprite.texture.get_size()
	var used := _visible_rect(sprite.texture)
	var size_mult: float = float(ENEMY_SIZE.get(enemy_name, BOSS_SIZE_DEFAULT if boss else ENEMY_SIZE_DEFAULT))
	var visible_height: float = maxf(8.0, used.size.y)
	var sprite_scale: float = _player_visible_height() * size_mult / visible_height
	sprite.scale = Vector2(sprite_scale, sprite_scale)
	# Pes (base visivel) no chao do inimigo (y = +20), qualquer que seja a borda do PNG.
	var feet_from_center: float = (used.end.y - tex_size.y * 0.5) * sprite_scale
	var top_from_center: float = (used.position.y - tex_size.y * 0.5) * sprite_scale
	sprite.position = Vector2(0, 20.0 - feet_from_center)
	var top_y: float = sprite.position.y + top_from_center
	body_reach = clampf(size_mult, 1.0, 2.0)
	if shadow_sprite != null:
		var width_factor: float = clampf(used.size.x * sprite_scale / 70.0, 0.6, 3.2)
		shadow_sprite.position = Vector2(0, 22)
		shadow_sprite.scale = Vector2(0.86, 0.44) * width_factor
	# Nome e barra de vida logo acima da cabeca.
	label.offset_top = top_y - 34.0
	label.offset_bottom = top_y - 14.0
	health_bar.offset_top = top_y - 12.0
	health_bar.offset_bottom = top_y - 4.0

func _player_visible_height() -> float:
	if target != null and is_instance_valid(target) and "sprite" in target:
		var player_sprite: Sprite2D = target.sprite
		if player_sprite != null and player_sprite.texture != null:
			# 0.8: o recorte do jogador inclui a arma erguida acima da cabeca.
			var height: float = _visible_rect(player_sprite.texture).size.y * absf(player_sprite.scale.y) * 0.8
			if height >= 20.0:
				return height
	return PLAYER_VISIBLE_HEIGHT

static func _visible_rect(texture: Texture2D) -> Rect2:
	var key := texture.resource_path
	if not key.is_empty() and _visible_rect_cache.has(key):
		return _visible_rect_cache[key]
	var rect := Rect2(Vector2.ZERO, texture.get_size())
	var image := texture.get_image()
	if image != null:
		if image.is_compressed():
			image.decompress()
		var used: Rect2i = image.get_used_rect()
		if used.size.x > 0 and used.size.y > 0:
			rect = Rect2(used)
	if not key.is_empty():
		_visible_rect_cache[key] = rect
	return rect

func _load_visual_frames(sprite_path: String) -> void:
	idle_frames.clear()
	walk_frames.clear()
	directional_frames.clear()
	var packed_frames := _load_packed_mob_frames(sprite_path)
	if not packed_frames.is_empty():
		directional_frames = packed_frames
		idle_frames = directional_frames.get("idle_front", [])
		walk_frames = directional_frames.get("walk_front", directional_frames.get("fly_front", []))
		if not idle_frames.is_empty():
			sprite.texture = idle_frames[0]
		visual_side_only = _detect_side_only()
		return
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

func _load_packed_mob_frames(sprite_path: String) -> Dictionary:
	if not sprite_path.begins_with("res://assets/sprites/mobs/"):
		return {}
	var result: Dictionary = {}
	var parts := sprite_path.split("/")
	var mobs_index := parts.find("mobs")
	if mobs_index < 0 or mobs_index + 1 >= parts.size():
		return {}
	var asset := str(parts[mobs_index + 1])
	visual_asset = asset
	for animation in ["idle", "walk", "fly", "move", "run", "dash", "attack", "hit", "death"]:
		for direction in ["front", "back", "left", "right"]:
			var frames: Array = []
			for i in range(1, 25):
				var path := "res://assets/sprites/mobs/%s/%s_%s/%s_%s_%s_%02d.png" % [asset, animation, direction, asset, animation, direction, i]
				if not ResourceLoader.exists(path):
					break
				var texture := load(path)
				if texture != null:
					frames.append(texture)
			if not frames.is_empty():
				result["%s_%s" % [animation, direction]] = frames
	return result

func _detect_side_only() -> bool:
	if _side_only_cache.has(visual_asset):
		return bool(_side_only_cache[visual_asset])
	var front: Array = directional_frames.get("idle_front", [])
	var left: Array = directional_frames.get("idle_left", [])
	var result := front.is_empty() and not left.is_empty()
	if not front.is_empty() and not left.is_empty():
		var front_image := (front[0] as Texture2D).get_image()
		var left_image := (left[0] as Texture2D).get_image()
		result = front_image != null and left_image != null and front_image.get_size() == left_image.get_size() and front_image.get_data() == left_image.get_data()
	_side_only_cache[visual_asset] = result
	return result

func _visual_direction_from_velocity() -> String:
	if abs(velocity.x) > FACING_DEADZONE:
		visual_facing_right = velocity.x > 0.0
	if velocity.length() <= 4.0:
		return visual_direction
	# Histerese de eixo: na diagonal mantem a direcao atual em vez de alternar.
	var horizontal: bool = visual_direction in ["left", "right"]
	if abs(velocity.x) > abs(velocity.y) * AXIS_HYSTERESIS:
		horizontal = true
	elif abs(velocity.y) > abs(velocity.x) * AXIS_HYSTERESIS:
		horizontal = false
	if horizontal:
		visual_direction = "right" if visual_facing_right else "left"
	else:
		visual_direction = "back" if velocity.y < 0.0 else "front"
	return visual_direction

func _frames_for_state(moving: bool) -> Array:
	if directional_frames.is_empty():
		return walk_frames if moving and not walk_frames.is_empty() else idle_frames
	var direction := _visual_direction_from_velocity()
	visual_flip_from_left = false
	if visual_side_only:
		# Arte so lateral: sempre os frames da esquerda, espelhados para a direita.
		visual_flip_from_left = visual_facing_right
		direction = "left"
	var frame_direction := direction
	if direction == "right":
		var side_preferred := "walk" if moving else "idle"
		var side_frames: Array = directional_frames.get("%s_left" % side_preferred, [])
		if side_frames.is_empty() and moving:
			for side_alt in ["run", "fly", "move", "dash"]:
				side_frames = directional_frames.get("%s_left" % side_alt, [])
				if not side_frames.is_empty():
					break
		if side_frames.is_empty():
			side_frames = directional_frames.get("idle_left", [])
		if not side_frames.is_empty():
			visual_flip_from_left = true
			return side_frames
	var preferred := "walk" if moving else "idle"
	var frames: Array = directional_frames.get("%s_%s" % [preferred, frame_direction], [])
	if frames.is_empty() and moving:
		frames = directional_frames.get("run_%s" % frame_direction, [])
	if frames.is_empty() and moving:
		frames = directional_frames.get("fly_%s" % frame_direction, [])
	if frames.is_empty() and moving:
		frames = directional_frames.get("move_%s" % frame_direction, [])
	if frames.is_empty() and moving:
		frames = directional_frames.get("dash_%s" % frame_direction, [])
	if frames.is_empty():
		frames = directional_frames.get("idle_%s" % frame_direction, [])
	if frames.is_empty():
		frames = directional_frames.get("idle_front", [])
	return frames

func _update_visual_animation(delta: float) -> void:
	var moving := velocity.length() > 4.0
	var frames := _frames_for_state(moving)
	var state := "move" if moving else "idle"
	var attack_frames := _attack_frames() if visual_attack_timer > 0.0 else []
	if not attack_frames.is_empty():
		frames = attack_frames
		state = "attack"
	if frames.is_empty():
		return
	var direction := "side" if visual_side_only else _visual_direction_from_velocity()
	var anim_key := "%s_%s" % [state, direction]
	if anim_key != visual_animation_key:
		visual_animation_key = anim_key
		visual_frame_index = 0
		visual_frame_timer = 0.0
	if directional_frames.is_empty() and moving and abs(velocity.x) > FACING_DEADZONE:
		sprite.flip_h = velocity.x < 0.0
	elif not directional_frames.is_empty():
		sprite.flip_h = visual_flip_from_left
	var delay := ATTACK_FRAME_TIME if state == "attack" else (0.12 if moving else 0.42)
	visual_frame_timer += delta
	if visual_frame_timer >= delay:
		visual_frame_timer = 0.0
		if state == "attack":
			visual_frame_index = min(visual_frame_index + 1, frames.size() - 1)
		else:
			visual_frame_index = (visual_frame_index + 1) % frames.size()
	sprite.texture = frames[visual_frame_index % frames.size()]
	var movement_offset := Vector2.ZERO
	var movement_scale := Vector2.ONE
	if moving and frames.size() < 2:
		procedural_walk_time += delta
		var step := sin(procedural_walk_time * TAU * 5.5)
		var sway := cos(procedural_walk_time * TAU * 5.5)
		movement_offset = Vector2(sway * 1.6, -abs(step) * 2.0)
		movement_scale = Vector2(1.0 + abs(step) * 0.025, 1.0 - abs(step) * 0.018)
	elif not moving:
		procedural_walk_time = 0.0
	var punching := visual_attack_timer > 0.0 and state != "attack"
	visual_attack_timer = max(0.0, visual_attack_timer - delta)
	if punching:
		var side := -1.0 if sprite.flip_h else 1.0
		sprite.scale = visual_base_scale * 1.08
		sprite.position = visual_base_position + Vector2(3.0 * side, -1.0)
	else:
		sprite.scale = visual_base_scale * movement_scale
		sprite.position = visual_base_position + movement_offset
	if hit_react_timer > 0.0:
		var squash := hit_react_timer / HIT_REACT_DURATION
		sprite.scale *= Vector2(1.0 + 0.22 * squash, 1.0 - 0.18 * squash)

func _packed_frames_facing(animation: String) -> Array:
	if directional_frames.is_empty():
		return []
	var direction := visual_direction
	if visual_side_only or direction == "right":
		direction = "left"
	return directional_frames.get("%s_%s" % [animation, direction], directional_frames.get("%s_left" % animation, []))

func _prepare_special_visual() -> void:
	special_attack_frames = []
	var poses := CombatVisuals.options("actors", visual_asset)
	if not poses.is_empty():
		special_attack_frames = CombatVisuals.frames(str(poses[special_attack_index % poses.size()]), true)
	var effects := CombatVisuals.options("effects", visual_asset)
	if not effects.is_empty() and is_instance_valid(target):
		CombatVisuals.play(get_parent(), str(effects[special_attack_index % effects.size()]), target.global_position, target.global_position.x > global_position.x)
	special_attack_index += 1

func _attack_frames() -> Array:
	if not special_attack_frames.is_empty():
		return special_attack_frames
	return _packed_frames_facing("attack")

func _death_frames() -> Array:
	if visual_asset in DEATH_ANIM_BLOCKLIST:
		return []
	return _packed_frames_facing("death")

func _spawn_death_animation(world: Node, frames: Array) -> void:
	# O inimigo sai da arvore na hora (drops/XP/respawn); a morte toca num sprite solto.
	var corpse := Sprite2D.new()
	corpse.texture = frames[0]
	corpse.texture_filter = sprite.texture_filter
	corpse.flip_h = sprite.flip_h
	corpse.scale = visual_base_scale
	corpse.z_index = z_index
	world.add_child(corpse)
	corpse.global_position = to_global(visual_base_position)
	var tween := corpse.create_tween()
	for frame in frames.slice(1):
		tween.tween_interval(DEATH_FRAME_TIME)
		tween.tween_callback(corpse.set.bind("texture", frame))
	tween.tween_interval(DEATH_HOLD_TIME)
	tween.tween_property(corpse, "modulate:a", 0.0, 0.4)
	tween.tween_callback(corpse.queue_free)

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
	# Mobs refeitos com tools/mob_sprites/import_mob_strip.py passam a usar os
	# frames empacotados assim que a pasta existir; senao cai no PNG antigo.
	var packed_asset := str(PACKED_MOB_ASSETS.get(name_value, ""))
	if not packed_asset.is_empty():
		var packed_path := "res://assets/sprites/mobs/%s/idle_front/%s_idle_front_01.png" % [packed_asset, packed_asset]
		if ResourceLoader.exists(packed_path):
			return packed_path
	match name_value:
		"Javali Selvagem":
			return "res://assets/sprites/mobs/javali_selvagem/idle_front/javali_selvagem_idle_front_01.png"
		"Lobo Cinzento":
			return "res://assets/sprites/mobs/lobo_selvagem/idle_front/lobo_selvagem_idle_front_01.png"
		"Espirito Fraco":
			return "res://assets/sprites/enemy_espirito.png"
		"Aprendiz Corrompido":
			return "res://assets/sprites/enemy_aprendiz.png"
		"Morcego Pequeno":
			return "res://assets/sprites/mobs/morcego_selvagem/idle_front/morcego_selvagem_idle_front_01.png"
		"Aranha Venenosa":
			return "res://assets/sprites/enemy_aranha.png"
		"Javali Bruto":
			return "res://assets/sprites/mobs/javali_selvagem/idle_front/javali_selvagem_idle_front_01.png"
		"Lobo Alfa":
			return "res://assets/sprites/mobs/lobo_selvagem/idle_front/lobo_selvagem_idle_front_01.png"
		"Rei Javali":
			return "res://assets/sprites/mobs/javali_rei/idle_front/javali_rei_idle_front_01.png"
		"Espectro Arcano":
			return "res://assets/sprites/enemy_espirito_arcano.png"
		"Sentinela Arcano":
			return "res://assets/sprites/enemy_sentinela_arcano.png"
		"Arquimago Corrompido":
			return "res://assets/sprites/enemy_arquimago_corrompido.png"
		"Morcego Sombrio":
			return "res://assets/sprites/mobs/morcego_selvagem/idle_front/morcego_selvagem_idle_front_01.png"
		"Aranha Rainha":
			return "res://assets/sprites/enemy_aranha_rainha.png"
		"Matriarca Venenosa":
			return "res://assets/sprites/enemy_aranha_matriarca.png"
		"Bandido das Colinas":
			return "res://assets/sprites/enemy_bandido_colinas.png"
		"Golem de Pedra":
			return "res://assets/sprites/enemy_golem_pedra.png"
		"Senhor das Colinas":
			return "res://assets/sprites/mobs/javali_rei/idle_front/javali_rei_idle_front_01.png"
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
