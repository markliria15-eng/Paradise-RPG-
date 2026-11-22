extends Node
class_name BossSkills
# Golpes especiais de cada chefe (antes todos usavam so a investida do Rei Javali).
# Os golpes vem do ChatGPT em data/game_rules.json -> "chefes" -> <nome do chefe>:
#   tipos: investida, pocas, projeteis, teleporte, invocar, nova.
# Todo golpe tem aviso no chao/no chefe (aviso_s) antes de acertar, para dar tempo de desviar.
# O chefe fica parado enquanto prepara o golpe; a investida usa a maquina de estados do enemy.gd.
# Campos opcionais de arte por golpe (sem eles, circulos coloridos como antes):
#   "cor": "#rrggbb" do aviso/poca; "pose": tira do chefe tocada durante o aviso
#   (<nome>_<N>f_192x192.png); "visual": tira de efeito -- poca em loop no chao (pocas),
#   onda em voo (projeteis) ou impacto (nova/teleporte).

const CombatVisuals = preload("res://scripts/combat_visuals.gd")
const RULES_PATH := "res://data/game_rules.json"
const GLOBAL_GAP := 1.6          # pausa minima entre dois golpes especiais
const RECOVER_TIME := 0.35       # chefe parado logo depois de soltar o golpe
const ACTIVE_RANGE := 720.0      # so usa golpes com o jogador por perto
const PROJECTILE_LIFE := 3.2
const PUDDLE_TICK := 0.7
const SLOW_PCT := 0.4

static var _all_rules: Dictionary = {}
static var _rules_loaded := false

var enemy: Enemy
var attacks: Array = []
var furia: Dictionary = {}
var cooldowns: Array = []
var gap := 2.0
var cast: Dictionary = {}
var markers: Array = []
var puddles: Array = []
var projectiles: Array = []
var minions: Array = []
var fury_announced := false


static func config_for(boss_name: String) -> Dictionary:
	if not _rules_loaded:
		_rules_loaded = true
		if FileAccess.file_exists(RULES_PATH):
			var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(RULES_PATH))
			if typeof(data) == TYPE_DICTIONARY:
				_all_rules = (data as Dictionary).get("chefes", {})
	return _all_rules.get(boss_name, {})


func setup(owner_enemy: Enemy, config: Dictionary) -> void:
	enemy = owner_enemy
	attacks = config.get("ataques", [])
	furia = config.get("furia", {})
	cooldowns.clear()
	for i in attacks.size():
		cooldowns.append(float(attacks[i].get("recarga_s", 8.0)) * 0.45 + float(i) * 1.2)


func has_attacks() -> bool:
	return not attacks.is_empty()


func _enraged() -> bool:
	return enemy != null and enemy._is_enraged()


# Chamado pelo enemy.gd a cada quadro; true = o chefe esta preparando/soltando um golpe (fica parado).
func update(delta: float) -> bool:
	if enemy == null or enemy.target == null:
		return false
	if not fury_announced and _enraged():
		fury_announced = true
		_shout("FURIA!", Color("#ff4a3a"))
	if not cast.is_empty():
		_update_cast(delta)
		return true
	var speed_up := 1.0 / maxf(0.2, float(furia.get("recarga_mult", 1.0))) if _enraged() else 1.0
	for i in cooldowns.size():
		cooldowns[i] -= delta * speed_up
	gap -= delta
	if gap > 0.0 or enemy.target.in_safe_zone or enemy.target.is_dying:
		return false
	var distance := enemy.global_position.distance_to(enemy.target.global_position)
	if distance > ACTIVE_RANGE:
		return false
	var start := randi() % maxi(1, attacks.size())
	for k in attacks.size():
		var i := (start + k) % attacks.size()
		if cooldowns[i] > 0.0:
			continue
		var a: Dictionary = attacks[i]
		if not _usable(a, distance):
			continue
		cooldowns[i] = float(a.get("recarga_s", 8.0))
		gap = GLOBAL_GAP
		_shout(str(a.get("nome", "")), _effect_color(a))
		if str(a.get("tipo", "")) == "investida":
			enemy.begin_charge(a)
			return true
		_start_cast(a)
		return true
	return false


func _usable(a: Dictionary, distance: float) -> bool:
	match str(a.get("tipo", "")):
		"investida":
			return distance <= float(a.get("alcance_max", 340.0))
		"nova":
			return distance <= float(a.get("raio", 150.0)) * 1.5
		"invocar":
			_clean_minions()
			return minions.size() < _max_minions(a)
		"projeteis":
			return distance <= 560.0
		_:
			return distance <= 620.0


# ------------------------------------------------------------------ preparar e soltar
func _start_cast(a: Dictionary) -> void:
	var fury := _enraged()
	cast = {"a": a, "timer": maxf(0.6, float(a.get("aviso_s", 1.0))), "phase": "aviso", "data": {}}
	if not str(a.get("pose", "")).is_empty():
		enemy.play_pose(CombatVisuals.frames(str(a["pose"]), true), float(cast["timer"]) + RECOVER_TIME)
	var color := _effect_color(a)
	var player_pos: Vector2 = enemy.target.global_position
	match str(a.get("tipo", "")):
		"pocas":
			var count := int(a.get("quantidade", 4)) + (2 if fury else 0)
			var radius := float(a.get("raio", 50.0))
			var spread := float(a.get("espalhamento", 220.0))
			var spots: Array = [player_pos]
			var tries := 0
			while spots.size() < count and tries < count * 6:
				tries += 1
				var p := player_pos + Vector2.from_angle(randf() * TAU) * randf_range(radius * 1.2, spread)
				if _blocked(p):
					continue
				spots.append(p)
			cast["data"]["spots"] = spots
			for p in spots:
				markers.append(_circle(p, radius, color, true))
		"nova":
			var nova_radius := float(a.get("raio", 150.0)) * (1.25 if fury else 1.0)
			cast["data"]["radius"] = nova_radius
			markers.append(_circle(enemy.global_position, nova_radius, color, true))
		"projeteis":
			var dirs := _projectile_dirs(a, fury)
			cast["data"]["dirs"] = dirs
			for d in dirs:
				markers.append(_ray(enemy.global_position, d, 150.0, color))
		"teleporte":
			var dist := float(a.get("distancia_do_jogador", 180.0))
			var dest := player_pos + Vector2.from_angle(randf() * TAU) * dist
			for _i in 8:
				if not _blocked(dest):
					break
				dest = player_pos + Vector2.from_angle(randf() * TAU) * dist
			cast["data"]["dest"] = dest
			markers.append(_circle(dest, float(a.get("raio_explosao", 100.0)), color, true))
			var fade := enemy.create_tween()
			fade.tween_property(enemy.sprite, "modulate:a", 0.15, float(cast["timer"]) * 0.8)
		"invocar":
			var spots2: Array = []
			var want := mini(int(a.get("quantidade", 2)), _max_minions(a) - minions.size())
			for i in want:
				var p2 := enemy.global_position + Vector2.from_angle(TAU * float(i) / maxf(1.0, float(want)) + randf() * 0.6) * 90.0
				spots2.append(p2)
				markers.append(_circle(p2, 34.0, color, true))
			cast["data"]["spots"] = spots2


func _update_cast(delta: float) -> void:
	cast["timer"] = float(cast["timer"]) - delta
	if str(cast["phase"]) == "aviso":
		enemy.velocity = Vector2.ZERO
		enemy.sprite.position = enemy.visual_base_position + Vector2(randf_range(-2.0, 2.0), 0.0)
		if float(cast["timer"]) <= 0.0:
			enemy.sprite.position = enemy.visual_base_position
			_release(cast["a"], cast["data"])
			_clear_markers()
			cast["phase"] = "recuperar"
			cast["timer"] = RECOVER_TIME
	elif float(cast["timer"]) <= 0.0:
		cast = {}


func _release(a: Dictionary, data: Dictionary) -> void:
	var color := _effect_color(a)
	var player: Player = enemy.target
	match str(a.get("tipo", "")):
		"pocas":
			var radius := float(a.get("raio", 50.0))
			var hit := false
			for p in data.get("spots", []):
				_burst(p, radius, color)
				if not hit and _player_in(p, radius):
					hit = true
					_hit_player(a, 1.0)
				var dura := float(a.get("dura_s", 0.0)) + (2.0 if _enraged() and float(a.get("dura_s", 0.0)) > 0.0 else 0.0)
				if dura > 0.0:
					var node := _circle(p, radius, color, false)
					node.color.a = 0.32
					var fx := _fx_loop(str(a.get("visual", "")), p, radius * 2.3, -29)
					if fx != null:
						node.color.a = 0.12
					puddles.append({"node": node, "fx": fx, "pos": p, "radius": radius, "until": dura, "tick": 0.0, "a": a})
		"nova":
			var nova_radius := float(data.get("radius", 150.0))
			_burst(enemy.global_position, nova_radius, color)
			_fx_once(str(a.get("visual", "")), enemy.global_position, nova_radius * 2.3)
			CombatJuice.shake(enemy.get_viewport().get_camera_2d(), 7.0, 0.25)
			if _player_in(enemy.global_position, nova_radius):
				_hit_player(a, 1.0)
		"projeteis":
			var radius2 := float(a.get("raio", 14.0))
			var speed := float(a.get("velocidade", 250.0))
			for d in data.get("dirs", []):
				var shot := _circle(enemy.global_position + d * 30.0, radius2, color, false)
				shot.color.a = 0.95
				shot.z_index = 3500
				var wave := _fx_loop(str(a.get("visual", "")), Vector2.ZERO, radius2 * 4.5, 0, shot)
				if wave != null:
					wave.rotation = (d as Vector2).angle()
					shot.color.a = 0.2
				projectiles.append({"node": shot, "dir": d, "speed": speed, "radius": radius2, "life": PROJECTILE_LIFE, "a": a})
		"teleporte":
			var dest: Vector2 = data.get("dest", enemy.global_position)
			enemy.global_position = dest
			enemy.sprite.modulate.a = 1.0
			var r := float(a.get("raio_explosao", 100.0))
			_burst(dest, r, color)
			_fx_once(str(a.get("visual", "")), dest, r * 2.3)
			CombatJuice.shake(enemy.get_viewport().get_camera_2d(), 6.0, 0.22)
			if _player_in(dest, r):
				_hit_player(a, 1.0)
		"invocar":
			if enemy.summon_callback.is_valid():
				for p in data.get("spots", []):
					var minion: Variant = enemy.summon_callback.call(str(a.get("inimigo", "")), p)
					if minion != null:
						minions.append(minion)
				_burst(enemy.global_position, 80.0, color)


# ------------------------------------------------------------------ pocas e projeteis em voo
func _process(delta: float) -> void:
	if enemy == null or not is_instance_valid(enemy) or enemy.target == null:
		return
	for p in puddles.duplicate():
		p["until"] = float(p["until"]) - delta
		p["tick"] = float(p["tick"]) - delta
		if float(p["until"]) <= 0.0:
			if is_instance_valid(p["node"]):
				var t: Tween = p["node"].create_tween()
				t.tween_property(p["node"], "color:a", 0.0, 0.35)
				t.tween_callback(p["node"].queue_free)
			if p.get("fx") != null and is_instance_valid(p["fx"]):
				var tf: Tween = p["fx"].create_tween()
				tf.tween_property(p["fx"], "modulate:a", 0.0, 0.35)
				tf.tween_callback(p["fx"].queue_free)
			puddles.erase(p)
			continue
		if float(p["tick"]) <= 0.0 and _player_in(p["pos"], float(p["radius"])):
			p["tick"] = PUDDLE_TICK
			_hit_player(p["a"], 0.25)
	for s in projectiles.duplicate():
		var node: Node2D = s["node"]
		s["life"] = float(s["life"]) - delta
		if not is_instance_valid(node):
			projectiles.erase(s)
			continue
		node.global_position += (s["dir"] as Vector2) * float(s["speed"]) * delta
		var gone := float(s["life"]) <= 0.0 or _blocked(node.global_position)
		if not gone and _player_in(node.global_position, float(s["radius"]) + 16.0):
			_hit_player(s["a"], 1.0)
			gone = true
		if gone:
			node.queue_free()
			projectiles.erase(s)


func _exit_tree() -> void:
	_clear_markers()
	for p in puddles:
		if is_instance_valid(p["node"]):
			p["node"].queue_free()
		if p.get("fx") != null and is_instance_valid(p["fx"]):
			p["fx"].queue_free()
	for s in projectiles:
		if is_instance_valid(s["node"]):
			s["node"].queue_free()
	puddles.clear()
	projectiles.clear()


# ------------------------------------------------------------------ dano e efeitos
func _hit_player(a: Dictionary, scale: float) -> void:
	var player: Player = enemy.target
	if player == null or player.in_safe_zone or player.is_dying:
		return
	var raw := float(enemy.ataque) * float(a.get("dano_mult", 0.6)) * scale
	player.last_hit = {"golpe": str(a.get("nome", "")), "de": enemy.enemy_name}
	player.receive_damage(CombatSystem.physical_damage(raw, player.defesa))
	var secs := float(a.get("efeito_s", 0.0))
	match str(a.get("efeito", "nenhum")):
		"veneno":
			player.poison_timer = maxf(player.poison_timer, maxf(secs, 3.0))
		"lento":
			player.apply_slow(SLOW_PCT, maxf(secs, 1.0))
		"atordoa":
			player.apply_stun(maxf(secs, 0.4))


func _player_in(center: Vector2, radius: float) -> bool:
	return enemy.target.global_position.distance_to(center) <= radius + 14.0


func _blocked(p: Vector2) -> bool:
	return enemy.obstacle_checker.is_valid() and bool(enemy.obstacle_checker.call(p))


func _max_minions(a: Dictionary) -> int:
	return int(a.get("max_vivos", 3)) + (1 if _enraged() else 0)


func _clean_minions() -> void:
	minions = minions.filter(func(m): return m != null and is_instance_valid(m))


func _projectile_dirs(a: Dictionary, fury: bool) -> Array:
	var count := int(a.get("quantidade", 5)) + (2 if fury else 0)
	var base := enemy.global_position.direction_to(enemy.target.global_position)
	if base == Vector2.ZERO:
		base = Vector2.RIGHT
	var dirs: Array = []
	match str(a.get("padrao", "leque")):
		"anel":
			for i in count:
				dirs.append(base.rotated(TAU * float(i) / float(count)))
		_:
			var spread := deg_to_rad(float(a.get("abertura_graus", 45.0)))
			for i in count:
				var t := 0.5 if count == 1 else float(i) / float(count - 1)
				dirs.append(base.rotated(-spread * 0.5 + spread * t))
	return dirs


# ------------------------------------------------------------------ visual
func _effect_color(a: Dictionary) -> Color:
	if not str(a.get("cor", "")).is_empty():
		return Color(str(a["cor"]))
	match str(a.get("efeito", "nenhum")):
		"veneno":
			return Color(0.35, 0.95, 0.25)
		"lento":
			return Color(0.45, 0.85, 1.0)
		"atordoa":
			return Color(1.0, 0.85, 0.25)
	if str(a.get("tipo", "")) == "invocar":
		return Color(0.75, 0.4, 1.0)
	return Color(1.0, 0.2, 0.1)


func _world() -> Node:
	return enemy.get_parent()


# Efeito da tira em loop (poca no chao, onda em voo). parent: no do projetil (posicao local) ou o mundo.
func _fx_loop(path: String, pos: Vector2, size_px: float, z: int, parent: Node2D = null) -> AnimatedSprite2D:
	if path.is_empty():
		return null
	var textures: Array = CombatVisuals.frames(path)
	if textures.is_empty():
		return null
	var anim := AnimatedSprite2D.new()
	var seq := SpriteFrames.new()
	seq.set_animation_loop("default", true)
	seq.set_animation_speed("default", 10.0)
	for t in textures:
		seq.add_frame("default", t)
	anim.sprite_frames = seq
	var size: Vector2 = (textures[0] as Texture2D).get_size()
	anim.scale = Vector2.ONE * (size_px / maxf(size.x, size.y))
	if parent != null:
		parent.add_child(anim)
		anim.position = pos
	else:
		anim.z_as_relative = false
		anim.z_index = z
		_world().add_child(anim)
		anim.global_position = pos
	anim.play()
	return anim


func _fx_once(path: String, pos: Vector2, size_px: float) -> void:
	if not path.is_empty():
		CombatVisuals.play(_world(), path, pos, false, size_px, true)


func _circle(center: Vector2, radius: float, color: Color, pulse: bool) -> Polygon2D:
	var poly := Polygon2D.new()
	var pts := PackedVector2Array()
	for i in 32:
		pts.append(Vector2.from_angle(TAU * float(i) / 32.0) * radius)
	poly.polygon = pts
	poly.color = Color(color.r, color.g, color.b, 0.0 if pulse else 0.5)
	poly.z_as_relative = false
	poly.z_index = -30
	_world().add_child(poly)
	poly.global_position = center
	if pulse:
		var tween := poly.create_tween().set_loops()
		tween.tween_property(poly, "color:a", 0.55, 0.18)
		tween.tween_property(poly, "color:a", 0.25, 0.18)
	return poly


func _ray(origin: Vector2, dir: Vector2, length: float, color: Color) -> Polygon2D:
	var poly := Polygon2D.new()
	poly.polygon = PackedVector2Array([Vector2(20, -5), Vector2(length, -5), Vector2(length + 18, 0), Vector2(length, 5), Vector2(20, 5)])
	poly.color = Color(color.r, color.g, color.b, 0.0)
	poly.z_as_relative = false
	poly.z_index = -30
	_world().add_child(poly)
	poly.global_position = origin
	poly.rotation = dir.angle()
	var tween := poly.create_tween().set_loops()
	tween.tween_property(poly, "color:a", 0.7, 0.16)
	tween.tween_property(poly, "color:a", 0.3, 0.16)
	return poly


func _burst(center: Vector2, radius: float, color: Color) -> void:
	var ring := _circle(center, radius, color, false)
	ring.color.a = 0.75
	ring.z_index = 3400
	var tween := ring.create_tween()
	tween.set_parallel(true)
	tween.tween_property(ring, "scale", Vector2(1.15, 1.15), 0.3)
	tween.tween_property(ring, "color:a", 0.0, 0.3)
	tween.chain().tween_callback(ring.queue_free)


func _clear_markers() -> void:
	for m in markers:
		if m != null and is_instance_valid(m):
			m.queue_free()
	markers.clear()


func _shout(text: String, color: Color) -> void:
	if text.is_empty() or enemy == null:
		return
	AudioManager.play_sfx("chefe_aviso", 0.9, 0.3)
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_color", color.lightened(0.35))
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 6)
	label.z_as_relative = false
	label.z_index = 4000
	enemy.add_child(label)
	label.reset_size()
	label.position = Vector2(-label.size.x * 0.5, enemy.visual_base_position.y - 150.0)
	var tween := label.create_tween()
	tween.tween_property(label, "position:y", label.position.y - 30.0, 1.1)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 1.1).set_delay(0.5)
	tween.tween_callback(label.queue_free)
