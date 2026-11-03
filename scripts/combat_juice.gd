extends RefCounted
class_name CombatJuice

# "Golpes com peso": feedback de impacto do combate.
# Tudo e visual/local (nao muda dano, XP, drops, save nem rede):
# - empurrao + flash + achatamento no inimigo (Enemy.apply_hit_reaction)
# - faiscas de impacto
# - micro pausa (hit-stop) e tremida de camera mais forte em golpe pesado/morte

const HITSTOP_LIGHT := 0.045
const HITSTOP_HEAVY := 0.10
const HITSTOP_TIME_SCALE := 0.06
const KNOCKBACK_LIGHT := 520.0
const KNOCKBACK_HEAVY := 820.0

static var _hitstop_token := 0
static var _shake_tween: Tween


static func on_enemy_hit(world: Node, camera: Camera2D, enemy: Node2D, from_pos: Vector2, killed: bool, heavy: bool = false, area: bool = false) -> void:
	if world == null or enemy == null or not is_instance_valid(enemy):
		return
	var strong := killed or heavy
	var force := KNOCKBACK_HEAVY if strong else KNOCKBACK_LIGHT
	if area:
		force *= 0.6
	if enemy.has_method("apply_hit_reaction"):
		enemy.call("apply_hit_reaction", from_pos, force)
	spawn_impact_sparks(world, enemy.global_position + Vector2(0, -16), from_pos, strong)
	if area:
		shake(camera, 3.0 if strong else 1.5, 0.12)
		return
	hitstop(world, HITSTOP_HEAVY if strong else HITSTOP_LIGHT)
	shake(camera, 7.0 if killed else (5.0 if heavy else 2.5), 0.24 if strong else 0.12)


static func hitstop(world: Node, duration: float) -> void:
	if world == null or not world.is_inside_tree():
		return
	var tree := world.get_tree()
	if tree == null or tree.paused:
		return
	CombatJuice._hitstop_token += 1
	var token := CombatJuice._hitstop_token
	Engine.time_scale = HITSTOP_TIME_SCALE
	# ignore_time_scale = true: o timer conta o tempo sem a desaceleracao.
	tree.create_timer(duration, true, false, true).timeout.connect(func() -> void:
		if token == CombatJuice._hitstop_token:
			Engine.time_scale = 1.0
	)


static func shake(camera: Camera2D, intensity: float, duration: float) -> void:
	if camera == null or not is_instance_valid(camera) or not camera.is_inside_tree():
		return
	if _shake_tween != null and _shake_tween.is_valid():
		_shake_tween.kill()
	_shake_tween = camera.create_tween()
	_shake_tween.set_ignore_time_scale(true)
	_shake_tween.tween_method(func(t: float) -> void:
		if is_instance_valid(camera):
			var falloff := 1.0 - t
			camera.offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * intensity * falloff
	, 0.0, 1.0, duration)
	_shake_tween.tween_callback(func() -> void:
		if is_instance_valid(camera):
			camera.offset = Vector2.ZERO
	)


static func spawn_impact_sparks(world: Node, at: Vector2, from_pos: Vector2, strong: bool) -> void:
	var sparks := CPUParticles2D.new()
	sparks.one_shot = true
	sparks.explosiveness = 1.0
	sparks.amount = 22 if strong else 14
	sparks.lifetime = 0.32
	sparks.direction = from_pos.direction_to(at) if from_pos.distance_to(at) > 1.0 else Vector2.UP
	sparks.spread = 70.0
	sparks.initial_velocity_min = 110.0
	sparks.initial_velocity_max = 260.0 if strong else 190.0
	sparks.damping_min = 300.0
	sparks.damping_max = 420.0
	sparks.gravity = Vector2.ZERO
	sparks.scale_amount_min = 3.0
	sparks.scale_amount_max = 7.0 if strong else 5.0
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.0, 1.0, 0.9, 1.0))
	ramp.set_color(1, Color(1.0, 0.45, 0.1, 0.0))
	sparks.color_ramp = ramp
	sparks.z_index = 2000
	sparks.z_as_relative = false
	world.add_child(sparks)
	sparks.global_position = at
	sparks.emitting = true
	sparks.get_tree().create_timer(0.8, false).timeout.connect(sparks.queue_free)


static func spawn_death_burst(world: Node, at: Vector2, texture: Texture2D, sprite_scale: Vector2, flip_h: bool) -> void:
	if world == null or not world.is_inside_tree():
		return
	if texture != null:
		var ghost := Sprite2D.new()
		ghost.texture = texture
		ghost.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		ghost.flip_h = flip_h
		ghost.scale = sprite_scale
		ghost.modulate = Color(2.2, 2.2, 2.2, 1.0)
		ghost.z_index = 1999
		ghost.z_as_relative = false
		world.add_child(ghost)
		ghost.global_position = at
		var tween := ghost.create_tween()
		tween.set_parallel(true)
		tween.tween_property(ghost, "scale", sprite_scale * Vector2(1.35, 0.55), 0.22)
		tween.tween_property(ghost, "modulate", Color(1.0, 0.85, 0.6, 0.0), 0.22)
		tween.chain().tween_callback(ghost.queue_free)
	var dust := CPUParticles2D.new()
	dust.one_shot = true
	dust.explosiveness = 1.0
	dust.amount = 22
	dust.lifetime = 0.55
	dust.spread = 180.0
	dust.initial_velocity_min = 60.0
	dust.initial_velocity_max = 170.0
	dust.damping_min = 160.0
	dust.damping_max = 260.0
	dust.gravity = Vector2(0, 60)
	dust.scale_amount_min = 3.0
	dust.scale_amount_max = 6.0
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.0, 0.95, 0.75, 1.0))
	ramp.set_color(1, Color(0.55, 0.42, 0.3, 0.0))
	dust.color_ramp = ramp
	dust.z_index = 1998
	dust.z_as_relative = false
	world.add_child(dust)
	dust.global_position = at + Vector2(0, -10)
	dust.emitting = true
	dust.get_tree().create_timer(1.2, false).timeout.connect(dust.queue_free)
