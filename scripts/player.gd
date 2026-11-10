extends CharacterBody2D
class_name Player

# Estado e regras do personagem jogavel. Os atributos "raw" guardam a
# progressao real; os atributos exibidos recebem bonus de equipamentos/joias.
signal stats_changed
signal message_requested(text: String)
signal damage_taken(amount: int)
signal healed(amount: int)
signal died
signal attack_requested(power: float, radius: float, skill_id: String)
signal skill_area_requested(power: float, radius: float, skill_id: String)
signal dash_requested(distance: float, skill_id: String)
signal self_effect_requested(skill_id: String)

var class_name_selected := ""
var character_name := "Aventureiro"
var level := 1
var xp := 0
var ouro := 0
var diamantes := 0
var vida := 100
var vida_max := 100
var mana := 50
var mana_max := 50
var ataque := 10
var ataque_distancia := 0
var defesa := 5
var raw_ataque := 10
var raw_defesa := 5
var velocidade_ataque := 1.0
var velocidade_movimento := 180.0
var alcance := 60.0
var ataque_magico := 0
var xp_ataque := 0
var xp_defesa := 0
var xp_speed_attack := 0
var speed_attack_level := 1
var incoming_hits := 0
var physical_damage_pct := 0.0
var mana_regen_pct := 0.0
var attack_speed_pct := 0.0
var move_speed_pct := 0.0
var companion_physical_damage_pct := 0.0
var companion_mana_regen_pct := 0.0
var companion_attack_speed_pct := 0.0
var companion_move_speed_pct := 0.0
var companion_vida_max_pct := 0.0
var shield_points := 0
var poison_timer := 0.0
# Atordoamento (ex.: investida do Rei Javali): sem mover, atacar ou usar skills.
var stun_timer := 0.0
var stun_fx: Node2D
var skills: Dictionary = {}
var in_safe_zone := false

var inventory := InventorySystem.new()
var class_data: Dictionary = {}
var item_db: ItemDatabase
var can_attack := true
var war_cry_timer := 0.0
var war_cry_bonus := 0.0
var hero_hour_timer := 0.0
var hero_attack_bonus := 0.0
var hero_defense_bonus := 0.0
var agility_timer := 0.0
var agility_move_bonus := 0.0
var agility_attack_bonus := 0.0
var current_sprite_path := ""
var mount_lift := 0.0  # px que o heroi sobe quando esta montado (main.gd _update_mount_rider)
var current_sprite_flip := false
var current_sprite_direction := "front"
var walk_anim_time := 0.0
var walk_anim_frame := 0
var walk_frame_cache: Dictionary = {}
var walk_anim_sequence_cache: Dictionary = {}
var idle_anim_time := 0.0
# Animacao de acao por cima de parado/andar: "attack", "hurt" ou "death".
var action_anim := ""
var action_time := 0.0
var action_frame_cache: Dictionary = {}
var is_dying := false
var death_emitted := false
const CUSTOM_PLAYER_TARGET_HEIGHT := 128.0
# Pack frames_192 (quadro 192, corpo ~168 px) reduzido na proporcao 157/192:
# a textura vira 119 px na tela e o corpo fica com ~104 px.
const HD_PLAYER_TARGET_HEIGHT := 119.0
const WALK_FRAME_TIME := 0.11
const IDLE_FRAME_TIME := 0.2
const ACTION_FRAME_TIME := {"attack": 0.075, "hurt": 0.07, "death": 0.2}
const DEATH_HOLD_TIME := 0.7
const FALLBACK_PLAYER_SCALE := 3.05
const WALK_CLASS_ASSET_ROOT := "res://assets/sprites/player_frames_caminhada_classes"

@onready var sprite: Sprite2D = $Sprite2D
@onready var health_bar: ProgressBar = $HealthBar
@onready var name_label: Label = $NameLabel
var shadow_sprite: Sprite2D

func setup(chosen_class: String, data: Dictionary, database: ItemDatabase) -> void:
	collision_layer = 1
	collision_mask = 0
	class_name_selected = chosen_class
	class_data = data
	item_db = database
	if skills.is_empty():
		skills = SkillProgressionSystem.default_skills()
	var base: Dictionary = data.get("base", {})
	vida_max = int(base.get("vida", 100))
	mana_max = int(base.get("mana", 50))
	vida = vida_max
	mana = mana_max
	ataque = int(base.get("ataque", 10))
	ataque_distancia = 0
	defesa = int(base.get("defesa", 5))
	raw_ataque = ataque
	raw_defesa = defesa
	velocidade_ataque = float(base.get("velocidade_ataque", 1.0))
	velocidade_movimento = float(base.get("velocidade_movimento", 180))
	alcance = float(base.get("alcance", 60))
	_set_player_sprite(_player_sprite_path(chosen_class), false)
	_refresh_walk_frame_cache()
	inventory.add_item(str(data.get("weapon", "")), 1)
	inventory.equip(str(data.get("weapon", "")), item_db.get_item(str(data.get("weapon", ""))))
	inventory.add_item("Pocao pequena de vida", 3)
	inventory.add_item("Pocao pequena de mana", 3)
	recalculate_equipment()
	_update_health_bar()
	stats_changed.emit()

func _physics_process(delta: float) -> void:
	var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if is_dying:
		input = Vector2.ZERO
	if stun_timer > 0.0:
		stun_timer -= delta
		input = Vector2.ZERO
		if stun_fx != null:
			stun_fx.rotation += delta * 5.0
		if stun_timer <= 0.0:
			_clear_stun()
	_update_directional_sprite(input, delta)
	velocity = input * velocidade_movimento * (1.0 + move_speed_pct + agility_move_bonus)
	move_and_slide()
	z_index = clampi(int(global_position.y), -1024, 1024)
	_update_health_bar()
	if war_cry_timer > 0:
		war_cry_timer -= delta
		if war_cry_timer <= 0:
			war_cry_bonus = 0
			stats_changed.emit()
	if hero_hour_timer > 0:
		hero_hour_timer -= delta
		if hero_hour_timer <= 0:
			hero_attack_bonus = 0
			hero_defense_bonus = 0
			stats_changed.emit()
	if agility_timer > 0:
		agility_timer -= delta
		if agility_timer <= 0:
			agility_move_bonus = 0
			agility_attack_bonus = 0
			stats_changed.emit()
	if poison_timer > 0:
		poison_timer -= delta
		if int(poison_timer * 10) % 10 == 0:
			_take_raw_damage(1)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("attack"):
		basic_attack()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("skill_1"):
		use_skill(0)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("skill_2"):
		use_skill(1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("skill_3"):
		use_skill(2)
		get_viewport().set_input_as_handled()

func is_stunned() -> bool:
	return stun_timer > 0.0

func apply_stun(seconds: float) -> void:
	stun_timer = maxf(stun_timer, seconds)
	sprite.modulate = Color(0.72, 0.78, 1.0, 1.0)
	if stun_fx == null:
		stun_fx = Node2D.new()
		stun_fx.position = Vector2(0, -92)
		stun_fx.z_as_relative = false
		stun_fx.z_index = 1100
		add_child(stun_fx)
		for i in 3:
			var star := Polygon2D.new()
			var points := PackedVector2Array()
			for k in 10:
				var radius := 9.0 if k % 2 == 0 else 4.0
				var angle := TAU * float(k) / 10.0 - PI / 2.0
				points.append(Vector2(cos(angle), sin(angle)) * radius)
			star.polygon = points
			star.color = Color("#ffe066")
			var orbit := TAU * float(i) / 3.0
			star.position = Vector2(cos(orbit) * 26.0, sin(orbit) * 9.0)
			stun_fx.add_child(star)
	message_requested.emit("Atordoado!")

func _clear_stun() -> void:
	stun_timer = 0.0
	sprite.modulate = Color.WHITE
	if stun_fx != null:
		stun_fx.queue_free()
		stun_fx = null

func basic_attack() -> void:
	if not can_attack or is_stunned() or is_dying:
		return
	if in_safe_zone:
		message_requested.emit("Zona segura: ataques bloqueados perto dos portais.")
		return
	_gain_speed_attack_xp()
	attack_requested.emit(1.0, alcance, "basic_attack")
	_play_action("attack")
	_start_attack_cooldown()

func use_skill(index: int) -> void:
	var skills: Array = class_data.get("skills", [])
	if index >= skills.size() or is_stunned() or is_dying:
		return
	var skill: Dictionary = skills[index]
	if in_safe_zone:
		message_requested.emit("Zona segura: habilidades de ataque bloqueadas.")
		return
	if not SkillSystem.can_use(self, skill):
		return
	SkillSystem.cast(self, skill)
	_add_skill_xp("magic", 4)
	_gain_speed_attack_xp()
	self_effect_requested.emit(str(skill.get("id", "")))
	_play_action("attack")
	_start_attack_cooldown()

func _start_attack_cooldown() -> void:
	can_attack = false
	if not is_inside_tree():
		can_attack = true
		return
	var tree := get_tree()
	if tree == null:
		can_attack = true
		return
	await tree.create_timer(1.0 / get_attack_speed()).timeout
	can_attack = true

func get_attack_speed() -> float:
	return min(2.35, velocidade_ataque * (1.0 + attack_speed_pct + agility_attack_bonus))

func get_attack_value() -> float:
	return ataque * (1.0 + war_cry_bonus + hero_attack_bonus)

func receive_damage(amount: int, poison_chance: float = 0.0) -> void:
	if is_dying:
		return
	var final_damage := amount
	if shield_points > 0:
		var absorbed: int = min(shield_points, final_damage)
		shield_points -= absorbed
		final_damage -= absorbed
	if class_name_selected == "Guerreiro":
		incoming_hits += 1
		if incoming_hits >= 5:
			final_damage = int(ceil(final_damage * 0.7))
			incoming_hits = 0
	if hero_defense_bonus > 0:
		final_damage = max(1, int(ceil(float(final_damage) * (1.0 - hero_defense_bonus))))
	if final_damage > 0:
		_take_raw_damage(final_damage)
		_gain_defense_xp()
		if not is_dying and action_anim != "attack":
			_play_action("hurt")
	if poison_chance > 0 and randf() <= poison_chance:
		poison_timer = 5.0

func _take_raw_damage(amount: int) -> void:
	if amount <= 0 or is_dying:
		return
	# PROVISORIO (fase de testes): paradise/invencivel no project.godot deixa a vida infinita.
	if bool(ProjectSettings.get_setting("paradise/invencivel", false)):
		return
	vida = max(0, vida - amount)
	damage_taken.emit(amount)
	_update_health_bar()
	stats_changed.emit()
	if vida <= 0:
		_start_death()

# Toca a animacao de morte e so depois avisa o main (que leva o jogador de
# volta). Sem frames de morte no pack, morre na hora como antes.
func _start_death() -> void:
	if _action_frames("death", current_sprite_direction).is_empty() or not is_inside_tree():
		died.emit()
		return
	is_dying = true
	death_emitted = false
	_clear_stun()
	poison_timer = 0.0
	_play_action("death")

func heal(amount: int) -> void:
	if amount <= 0:
		return
	var before := vida
	vida = min(vida_max, vida + amount)
	var recovered := vida - before
	if recovered > 0:
		healed.emit(recovered)
	_update_health_bar()
	stats_changed.emit()

func recover_mana(amount: int) -> void:
	mana = min(mana_max, mana + amount)
	stats_changed.emit()

func spend_mana(amount: int) -> bool:
	var reduced_amount := int(ceil(float(amount) * (1.0 - SkillProgressionSystem.mana_efficiency_bonus(skills))))
	if mana < reduced_amount:
		return false
	mana -= reduced_amount
	stats_changed.emit()
	return true

func pay_life_percent(percent: float) -> bool:
	var cost: int = int(ceil(float(vida_max) * percent))
	if vida <= int(ceil(float(vida_max) * 0.2)):
		message_requested.emit("Seifador de Almas nao pode ser usado com 20% de vida ou menos.")
		return false
	if vida - cost <= 0:
		return false
	_take_raw_damage(cost)
	return true

func on_hit_enemy(skill_id: String = "basic_attack") -> void:
	xp_ataque += 5
	var needed := 100 + ataque * 25
	if xp_ataque >= needed:
		xp_ataque -= needed
		raw_ataque += 1
		recalculate_equipment()
	var progression_id := _progression_for_attack(skill_id)
	var xp_amount := 6 if progression_id == "magic" else 5
	_add_skill_xp(progression_id, xp_amount)
	stats_changed.emit()

func _gain_defense_xp() -> void:
	xp_defesa += 6
	var needed := 100 + defesa * 25
	if xp_defesa >= needed:
		xp_defesa -= needed
		raw_defesa += 1
		recalculate_equipment()
	_add_skill_xp("protection", 6)
	stats_changed.emit()

func _gain_speed_attack_xp() -> void:
	xp_speed_attack += 2
	var needed := 100 + speed_attack_level * 30
	if xp_speed_attack >= needed and velocidade_ataque < 2.0:
		xp_speed_attack -= needed
		speed_attack_level += 1
		velocidade_ataque = min(2.0, velocidade_ataque + 0.03)
	stats_changed.emit()

func _add_skill_xp(skill_id: String, amount: int) -> void:
	var messages := SkillProgressionSystem.add_xp(skills, skill_id, amount, class_name_selected)
	for message in messages:
		recalculate_equipment()
		message_requested.emit(message)

func _progression_for_attack(skill_id: String) -> String:
	if skill_id in ["fireball", "arcane_blast", "mystic_shield", "blue_meteor", "burning_fireball", "fire_hurricane"]:
		return "magic"
	if skill_id in ["precise_shot", "arrow_rain", "stun_shot", "agility"] or class_name_selected == "Arqueiro":
		return "distance"
	return "fighting"

func damage_multiplier_for(skill_id: String) -> float:
	match _progression_for_attack(skill_id):
		"magic":
			return 1.0 + SkillProgressionSystem.magic_damage_bonus(skills)
		"distance":
			return 1.0 + SkillProgressionSystem.distance_damage_bonus(skills)
	return 1.0 + SkillProgressionSystem.fighting_damage_bonus(skills)

func gain_xp(amount: int) -> void:
	xp += amount
	while xp >= xp_to_next_level():
		xp -= xp_to_next_level()
		level += 1
		vida_max += 10
		mana_max += 5
		raw_ataque += 1
		if level % 2 == 0:
			raw_defesa += 1
		vida = vida_max
		mana = mana_max
		recalculate_equipment()
	stats_changed.emit()

func xp_to_next_level() -> int:
	return 100 + level * 80

func on_enemy_killed() -> void:
	if class_name_selected == "Mago":
		recover_mana(int(mana_max * 0.08))

func recalculate_equipment() -> void:
	var keep_hp_ratio: float = float(vida) / max(1.0, float(vida_max))
	var keep_mp_ratio: float = float(mana) / max(1.0, float(mana_max))
	var base: Dictionary = class_data.get("base", {})
	vida_max = int(base.get("vida", vida_max)) + (level - 1) * 10
	var magic_level := int(skills.get("magic", {}).get("level", 10))
	mana_max = int(base.get("mana", mana_max)) + (level - 1) * 5 + max(0, magic_level - 10) * 3
	ataque = raw_ataque
	inventory.extra_slots = int(item_db.get_item(str(inventory.equipment.get("backpack", ""))).get("bag_slots", 0))
	ataque_distancia = 0
	defesa = raw_defesa
	ataque_magico = 0
	physical_damage_pct = 0
	mana_regen_pct = 0
	attack_speed_pct = 0
	move_speed_pct = 0
	for item_name in inventory.equipment.values():
		if str(item_name).is_empty():
			continue
		var item: Dictionary = item_db.get_item(str(item_name))
		var stats: Dictionary = PlayerStats.normalized_stats(item)
		for stat in stats.keys():
			match str(stat):
				"vida_max":
					vida_max += int(stats[stat])
				"mana_max":
					mana_max += int(stats[stat])
				"ataque":
					ataque += int(stats[stat])
				"ataque_distancia":
					ataque_distancia += int(stats[stat])
				"defesa":
					defesa += int(stats[stat])
				"ataque_magico":
					ataque_magico += int(stats[stat])
				"physical_damage_pct":
					physical_damage_pct += float(stats[stat])
				"mana_regen_pct":
					mana_regen_pct += float(stats[stat])
				"attack_speed_pct":
					attack_speed_pct += float(stats[stat])
				"move_speed_pct":
					move_speed_pct += float(stats[stat])
	defesa += SkillProgressionSystem.protection_defense_bonus(skills)
	_apply_set_bonuses()
	vida = clamp(int(vida_max * keep_hp_ratio), 1, vida_max)
	mana = clamp(int(mana_max * keep_mp_ratio), 0, mana_max)
	stats_changed.emit()

func _apply_set_bonuses() -> void:
	var counts := {}
	for item_name in inventory.equipment.values():
		var set_name := str(item_db.get_item(str(item_name)).get("set", ""))
		if not set_name.is_empty():
			counts[set_name] = int(counts.get(set_name, 0)) + 1
	if int(counts.get("Couro do Aventureiro", 0)) >= 4:
		vida_max += 10
		defesa += 2
		move_speed_pct += 0.03
	if int(counts.get("Ferro do Guardiao", 0)) >= 4:
		vida_max += 25
		defesa += 6
		move_speed_pct -= 0.03
	if int(counts.get("Tecido Arcano", 0)) >= 4:
		mana_max += 30
		ataque_magico += 3
		mana_regen_pct += 0.05
	if int(counts.get("Set de Couro", 0)) >= 8:
		vida_max += 18
		defesa += 3
		move_speed_pct += 0.03
	if int(counts.get("Set de Ferro", 0)) >= 8:
		vida_max += 45
		defesa += 9
	if int(counts.get("Set de Ouro", 0)) >= 8:
		vida_max += 70
		defesa += 13
		physical_damage_pct += 0.03
	if int(counts.get("Set de Titanio", 0)) >= 8:
		vida_max += 110
		defesa += 20
		attack_speed_pct += 0.03
	if int(counts.get("Set de Mithril", 0)) >= 8:
		mana_max += 120
		defesa += 24
		mana_regen_pct += 0.08
		move_speed_pct += 0.04
	if int(counts.get("Set de Obsidiana", 0)) >= 8:
		vida_max += 180
		defesa += 32
		physical_damage_pct += 0.08
	if int(counts.get("Set de Cristal", 0)) >= 8:
		vida_max += 240
		mana_max += 180
		defesa += 42
		mana_regen_pct += 0.12
		attack_speed_pct += 0.06
		move_speed_pct += 0.06
	if int(counts.get("Draconico", 0)) >= 4:
		vida_max += 80
		defesa += 10
		physical_damage_pct += 0.06
	if int(counts.get("Celestial", 0)) >= 1:
		ataque_magico += 2
		mana_regen_pct += 0.04
	if int(counts.get("Aco Sombrio", 0)) >= 4:
		vida_max += 120
		defesa += 18
		physical_damage_pct += 0.08
	if int(counts.get("Cristal Ancestral", 0)) >= 4:
		mana_max += 120
		ataque_magico += 12
		mana_regen_pct += 0.10
	if int(counts.get("Infernal", 0)) >= 2:
		vida_max += 140
		defesa += 18
		physical_damage_pct += 0.08
		attack_speed_pct += 0.04
	_apply_companion_bonuses()

func _apply_companion_bonuses() -> void:
	if companion_vida_max_pct > 0:
		vida_max += int(round(float(vida_max) * companion_vida_max_pct))
	physical_damage_pct += companion_physical_damage_pct
	mana_regen_pct += companion_mana_regen_pct
	attack_speed_pct += companion_attack_speed_pct
	move_speed_pct += companion_move_speed_pct

func revive_in_city() -> void:
	_clear_stun()
	is_dying = false
	death_emitted = false
	action_anim = ""
	action_time = 0.0
	ouro = int(ouro * 0.95)
	vida = int(vida_max * 0.5)
	mana = int(mana_max * 0.5)
	_update_health_bar()
	stats_changed.emit()

func to_save() -> Dictionary:
	return {
		"name": character_name, "class": class_name_selected, "level": level, "xp": xp, "ouro": ouro, "diamantes": diamantes,
		"vida": vida, "mana": mana, "vida_max": vida_max, "mana_max": mana_max,
		"ataque": ataque, "ataque_distancia": ataque_distancia, "defesa": defesa, "raw_ataque": raw_ataque, "raw_defesa": raw_defesa, "velocidade_ataque": velocidade_ataque,
		"velocidade_movimento": velocidade_movimento, "xp_ataque": xp_ataque,
		"xp_defesa": xp_defesa, "xp_speed_attack": xp_speed_attack,
		"speed_attack_level": speed_attack_level, "skills": skills, "inventory": inventory.to_save()
	}

func from_save(data: Dictionary, database: ItemDatabase, class_db: ClassDatabase) -> void:
	setup(str(data.get("class", "Guerreiro")), class_db.get_class_data(str(data.get("class", "Guerreiro"))), database)
	character_name = str(data.get("name", "Aventureiro"))
	level = int(data.get("level", level))
	xp = int(data.get("xp", xp))
	ouro = int(data.get("ouro", ouro))
	diamantes = int(data.get("diamantes", diamantes))
	raw_ataque = int(data.get("raw_ataque", data.get("ataque", ataque)))
	raw_defesa = int(data.get("raw_defesa", data.get("defesa", defesa)))
	velocidade_ataque = float(data.get("velocidade_ataque", velocidade_ataque))
	velocidade_movimento = float(data.get("velocidade_movimento", velocidade_movimento))
	xp_ataque = int(data.get("xp_ataque", 0))
	xp_defesa = int(data.get("xp_defesa", 0))
	xp_speed_attack = int(data.get("xp_speed_attack", 0))
	speed_attack_level = int(data.get("speed_attack_level", 1))
	skills = data.get("skills", SkillProgressionSystem.default_skills())
	inventory.from_save(data.get("inventory", {}))
	recalculate_equipment()
	vida = int(data.get("vida", vida_max))
	mana = int(data.get("mana", mana_max))
	_update_health_bar()
	stats_changed.emit()

func _update_health_bar() -> void:
	if health_bar == null:
		return
	health_bar.max_value = vida_max
	health_bar.value = vida
	if name_label != null:
		name_label.text = "%s  Lv %d" % [character_name, level]

func _player_sprite_path(chosen_class: String) -> String:
	var art_front := _class_pack_idle_path(chosen_class, "front")
	if ResourceLoader.exists(art_front):
		return art_front
	match chosen_class:
		"Guerreiro":
			return "res://assets/sprites/player_guerreiro.png"
		"Mago":
			return "res://assets/sprites/player_mago.png"
		"Arqueiro":
			return "res://assets/sprites/player_arqueiro.png"
	return "res://assets/sprites/player_guerreiro.png"

func _play_action(anim: String) -> void:
	if _action_frames(anim, current_sprite_direction).is_empty():
		return
	action_anim = anim
	action_time = 0.0

func _action_frames(anim: String, direction: String) -> Array:
	var key := "%s|%s|%s" % [class_name_selected, anim, direction]
	if action_frame_cache.has(key):
		return action_frame_cache[key]
	var frames: Array[String] = []
	var base := _class_pack_base_path(class_name_selected)
	if not base.is_empty():
		for i in range(1, 9):
			var path := "%s_%s_%s_%d.png" % [base, anim, direction, i]
			if not ResourceLoader.exists(path):
				break
			frames.append(path)
	action_frame_cache[key] = frames
	return frames

# Avanca a animacao de acao; devolve true enquanto ela controla o sprite.
func _update_action_sprite(delta: float) -> bool:
	if action_anim.is_empty():
		return false
	var frames := _action_frames(action_anim, current_sprite_direction)
	if frames.is_empty():
		action_anim = ""
		return false
	action_time += delta
	var frame_time: float = float(ACTION_FRAME_TIME.get(action_anim, 0.08))
	var index := int(action_time / frame_time)
	if index >= frames.size():
		if action_anim != "death":
			action_anim = ""
			return false
		index = frames.size() - 1
		if not death_emitted and action_time >= frame_time * frames.size() + DEATH_HOLD_TIME:
			death_emitted = true
			died.emit()
	_set_player_sprite(str(frames[index]), false)
	return true

func _update_directional_sprite(input: Vector2, delta: float) -> void:
	if input.length() >= 0.08 and not _class_sprite_prefix(class_name_selected).is_empty():
		if abs(input.y) > abs(input.x):
			current_sprite_direction = "back" if input.y < 0 else "front"
		else:
			current_sprite_direction = "right" if input.x > 0 else "left"
	if _update_action_sprite(delta):
		return
	if input.length() < 0.08:
		walk_anim_time = 0.0
		walk_anim_frame = 0
		var idle_frames := _action_frames("idle", current_sprite_direction)
		if idle_frames.size() >= 2:
			# respiracao em vai-e-volta: 1 2 3 4 3 2
			idle_anim_time += delta
			var cycle := idle_frames.size() * 2 - 2
			var step := int(idle_anim_time / IDLE_FRAME_TIME) % cycle
			var index := step if step < idle_frames.size() else cycle - step
			_set_player_sprite(str(idle_frames[index]), false)
			return
		_set_direction_sprite_or_default(current_sprite_direction, current_sprite_flip, false)
		return
	idle_anim_time = 0.0
	if _class_sprite_prefix(class_name_selected).is_empty():
		return
	var next_direction := "front"
	var next_flip := false
	if abs(input.y) > abs(input.x):
		next_direction = "back" if input.y < 0 else "front"
	else:
		next_direction = "right" if input.x > 0 else "left"
		next_flip = false
	if next_direction != current_sprite_direction or next_flip != current_sprite_flip:
		walk_anim_time = 0.0
		walk_anim_frame = 0
	walk_anim_time += delta
	var frame_count := _walk_frame_count_for_direction(next_direction)
	if frame_count <= 0:
		frame_count = 1
	while walk_anim_time >= WALK_FRAME_TIME:
		walk_anim_time -= WALK_FRAME_TIME
		walk_anim_frame = (walk_anim_frame + 1) % frame_count
	_set_direction_sprite_or_default(next_direction, next_flip, true)

func _set_direction_sprite_or_default(direction: String, flip_h: bool, moving: bool) -> void:
	current_sprite_direction = direction
	var path := ""
	if moving:
		var frames: Array = walk_frame_cache.get(direction, [])
		if not frames.is_empty():
			path = str(frames[_walk_sequence_frame_index(direction) % frames.size()])
		else:
			path = _class_pack_walk_path(class_name_selected, direction, _walk_sequence_frame_index(direction) + 1)
	if path.is_empty() or not ResourceLoader.exists(path):
		path = _class_pack_idle_path(class_name_selected, direction)
	if (path.is_empty() or not ResourceLoader.exists(path)) and direction in ["left", "right"]:
		path = _class_pack_idle_path(class_name_selected, "left")
		if moving:
			var fallback_frame := _walk_sequence_frame_index(direction) + 1
			var fallback_walk := _class_pack_walk_path(class_name_selected, "left", fallback_frame)
			if ResourceLoader.exists(fallback_walk):
				path = fallback_walk
				flip_h = direction == "right"
	if ResourceLoader.exists(path):
		_set_player_sprite(path, flip_h)
	else:
		_set_player_sprite(_player_sprite_path(class_name_selected), false)

func _class_pack_folder(chosen_class: String) -> String:
	match chosen_class:
		"Guerreiro":
			return "guerreiro"
		"Mago":
			return "maga_de_fogo"
		"Maga de Fogo":
			return "maga_de_fogo"
		"Maga":
			return "maga_de_fogo"
		"Arqueiro":
			return "arqueiro"
	return ""

func _class_pack_base_path(chosen_class: String) -> String:
	var folder := _class_pack_folder(chosen_class)
	if folder.is_empty():
		return ""
	# Unico pack: frames_192 (tools/char_sprites folhas <classe>). Os de 64 px foram apagados.
	return "%s/%s/frames_192/%s" % [WALK_CLASS_ASSET_ROOT, folder, folder]

func _class_pack_idle_path(chosen_class: String, direction: String) -> String:
	var base := _class_pack_base_path(chosen_class)
	if base.is_empty():
		return ""
	return "%s_idle_%s.png" % [base, direction]

func _class_pack_walk_path(chosen_class: String, direction: String, frame: int) -> String:
	var base := _class_pack_base_path(chosen_class)
	if base.is_empty():
		return ""
	return "%s_walk_%s_%d.png" % [base, direction, frame]

func _class_direction_sprite_path(chosen_class: String, direction: String, suffix: String = "") -> String:
	var normalized_direction := direction
	if normalized_direction == "side":
		normalized_direction = "left"
	if suffix.is_empty():
		var pack_idle := _class_pack_idle_path(chosen_class, normalized_direction)
		if ResourceLoader.exists(pack_idle):
			return pack_idle
	else:
		var frame_text := suffix.trim_prefix("_walk_")
		if frame_text.is_valid_int():
			var pack_walk := _class_pack_walk_path(chosen_class, normalized_direction, int(frame_text))
			if ResourceLoader.exists(pack_walk):
				return pack_walk
	var prefix := _class_sprite_prefix(chosen_class)
	if prefix.is_empty():
		return ""
	return "res://assets/sprites/player_%s_art_%s%s.png" % [prefix, direction, suffix]

func _walk_frame_count_for_direction(direction: String) -> int:
	var sequence: PackedInt32Array = _walk_sequence_for_direction(direction)
	if sequence.size() > 0:
		return sequence.size()
	var frames: Array = walk_frame_cache.get(direction, [])
	if not frames.is_empty():
		return frames.size()
	var count := 0
	for i in range(1, 13):
		if ResourceLoader.exists(_class_pack_walk_path(class_name_selected, direction, i)):
			count = i
	return max(1, count)

func _refresh_walk_frame_cache() -> void:
	walk_frame_cache.clear()
	walk_anim_sequence_cache.clear()
	action_frame_cache.clear()
	for direction in ["front", "left", "right", "back"]:
		var frames: Array[String] = []
		for i in range(1, 13):
			var path := _class_pack_walk_path(class_name_selected, direction, i)
			if ResourceLoader.exists(path):
				frames.append(path)
		if not frames.is_empty():
			walk_frame_cache[direction] = frames

func _walk_sequence_for_direction(direction: String) -> PackedInt32Array:
	if walk_anim_sequence_cache.has(direction):
		return walk_anim_sequence_cache[direction]
	var frames: Array = walk_frame_cache.get(direction, [])
	var sequence := PackedInt32Array([0])
	if frames.size() >= 4:
		# pack 192: passo esquerdo, passagem, passo direito, passagem ja desenhados
		sequence = PackedInt32Array([0, 1, 2, 3])
	elif frames.size() >= 3:
		# passo esquerdo -> passagem -> passo direito -> passagem
		sequence = PackedInt32Array([0, 1, 2, 1])
	elif frames.size() == 2:
		sequence = PackedInt32Array([0, 1])
	elif frames.size() == 1:
		sequence = PackedInt32Array([0])
	walk_anim_sequence_cache[direction] = sequence
	return sequence

func _walk_sequence_frame_index(direction: String) -> int:
	var sequence := _walk_sequence_for_direction(direction)
	if sequence.is_empty():
		return 0
	return int(sequence[walk_anim_frame % sequence.size()])

func _class_sprite_prefix(chosen_class: String) -> String:
	match chosen_class:
		"Guerreiro":
			return "guerreiro"
		"Mago":
			return "mago"
		"Arqueiro":
			return "arqueiro"
	return ""

func _class_has_custom_sprite(chosen_class: String) -> bool:
	for direction in ["front", "left", "right", "back"]:
		if ResourceLoader.exists(_class_pack_idle_path(chosen_class, direction)):
			return true
	return false

func _set_player_sprite(path: String, flip_h: bool) -> void:
	if current_sprite_path == path and current_sprite_flip == flip_h:
		return
	current_sprite_path = path
	current_sprite_flip = flip_h
	sprite.texture = load(path)
	sprite.flip_h = flip_h
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_fit_player_sprite()

# Sobe o heroi (sprite, nome e vida) para sentar na sela; 0 = no chao.
func set_mount_lift(value: float) -> void:
	if absf(value - mount_lift) < 0.01:
		return
	mount_lift = value
	_fit_player_sprite()

func _fit_player_sprite() -> void:
	if sprite.texture == null:
		return
	_ensure_shadow()
	if _class_has_custom_sprite(class_name_selected):
		var texture_height: float = maxf(1.0, float(sprite.texture.get_height()))
		var hd := texture_height >= 128.0
		var target_height := HD_PLAYER_TARGET_HEIGHT if hd else CUSTOM_PLAYER_TARGET_HEIGHT
		var sprite_scale: float = target_height / texture_height
		sprite.scale = Vector2(sprite_scale, sprite_scale)
		# pes: y=62 de 64 (pack antigo) ou y=184 de 192 (pack HD) -> mesma linha do chao (y~20)
		sprite.position = Vector2(0, -35 if hd else -40)
		# nome e vida logo acima da cabeca (~y -85 no pack HD)
		name_label.add_theme_font_size_override("font_size", 13)
		name_label.offset_left = -122
		name_label.offset_top = -127
		name_label.offset_right = 122
		name_label.offset_bottom = -109
		health_bar.offset_left = -56
		health_bar.offset_top = -95
		health_bar.offset_right = 56
		health_bar.offset_bottom = -87
	else:
		sprite.scale = Vector2(FALLBACK_PLAYER_SCALE, FALLBACK_PLAYER_SCALE)
		sprite.position = Vector2(0, -10)
		name_label.add_theme_font_size_override("font_size", 13)
		name_label.offset_left = -122
		name_label.offset_top = -128
		name_label.offset_right = 122
		name_label.offset_bottom = -110
		health_bar.offset_left = -52
		health_bar.offset_top = -102
		health_bar.offset_right = 52
		health_bar.offset_bottom = -94
	if mount_lift > 0.0:
		# montado: heroi, nome e vida sobem ate a sela; a sombra do heroi some (a montaria tem o corpo no chao)
		sprite.position.y -= mount_lift
		name_label.offset_top -= mount_lift
		name_label.offset_bottom -= mount_lift
		health_bar.offset_top -= mount_lift
		health_bar.offset_bottom -= mount_lift
	if shadow_sprite != null:
		shadow_sprite.visible = mount_lift <= 0.0

func _ensure_shadow() -> void:
	if shadow_sprite != null:
		return
	var texture := load("res://assets/sprites/decor_shadow_soft.png") as Texture2D
	if texture == null:
		return
	shadow_sprite = Sprite2D.new()
	shadow_sprite.texture = texture
	shadow_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	shadow_sprite.position = Vector2(0, 22)
	shadow_sprite.scale = Vector2(0.70, 0.34)
	shadow_sprite.modulate = Color(1, 1, 1, 0.58)
	shadow_sprite.z_index = -1
	add_child(shadow_sprite)
