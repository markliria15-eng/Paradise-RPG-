extends Node
class_name GameExtras
# Interatividade extra (fora do main.gd para ele nao crescer mais):
#  1. missoes diarias com contador na tela
#  2. truques do pet com afinidade alta (busca itens, avisa de chefe)
#  3. estabulo: cuidar da montaria da +10% de velocidade por 1 hora (main._apply_companion_bonuses)
#  4. NPCs que lembram de voce (saudacao pelo nome, presente na 5a visita)
#  5. eventos aleatorios: mercador viajante, ladrao fugindo, corrida ate a bandeira
#  6. modo foto (tecla P ou menu Foto): esconde o HUD
#  7. livro de colecao: monstros derrotados, pets e montarias
# Tudo salvo em main.mmo_cache (vai junto no save local).

var main: Node

# ---------- 1. missoes diarias ----------
const DAILY_POOL := [
	{"id": "kill_any", "text": "Derrote %d monstros", "goal": [15, 30], "reward": 250},
	{"id": "kill_boar", "text": "Derrote %d javalis", "goal": [8, 15], "reward": 220},
	{"id": "collect", "text": "Colete %d itens", "goal": [8, 15], "reward": 200},
	{"id": "pet_need", "text": "Atenda %d pedidos do seu pet", "goal": [2, 3], "reward": 260},
	{"id": "ride", "text": "Percorra %d m montado", "goal": [300, 600], "reward": 180},
	{"id": "event", "text": "Venca %d evento", "goal": [1, 1], "reward": 300},
	{"id": "boss", "text": "Derrote %d chefe", "goal": [1, 1], "reward": 400},
]
var daily_label: Button
var ride_last_pos := Vector2.INF

# ---------- 2. truques do pet ----------
const PET_FETCH_RADIUS := 380.0
var pet_boss_warn_at := 0.0
var pet_fetch_emote_at := 0.0

# ---------- 3. estabulo ----------
const MOUNT_CARE_PRICE := 60
const MOUNT_CARE_SECONDS := 3600.0
const MOUNT_CARE_BONUS := 0.10
var mount_care_was_active := false

# ---------- 4. NPCs ----------
const NPC_GREETINGS := [
	"Que bom te ver de novo, %s!",
	"%s! Voltou rapido, hein?",
	"Ola, %s. Precisando de algo hoje?",
	"Sempre bom ver %s por aqui.",
]

# ---------- 5. eventos ----------
var event_kind := ""
var event_until := 0.0
var event_next_at := 0.0
var event_label: Button
var event_node: Node2D
var event_target := Vector2.ZERO
var event_waypoint := Vector2.ZERO

# ---------- 6. modo foto ----------
var photo_mode := false
var photo_layer: CanvasLayer
var photo_hidden: Array = []


func setup(owner_main: Node) -> void:
	main = owner_main
	event_next_at = _now() + main._rule_range(["eventos", "primeiro_apos_s"], 150.0, 240.0)
	daily_label = _hud_button(Vector2(452, 34), Vector2(376, 30), func() -> void: show_daily())
	event_label = _hud_button(Vector2(452, 68), Vector2(376, 30), func() -> void: show_events())
	event_label.visible = false
	_ensure_daily()
	AudioManager.sfx_volume = clampf(float(_cache().get("sfx_volume", 0.8)), 0.0, 1.0)


func _now() -> float:
	return float(Time.get_ticks_msec()) / 1000.0


func _cache() -> Dictionary:
	return main.mmo_cache


func _hud_button(pos: Vector2, size: Vector2, callback: Callable) -> Button:
	var button: Button = main._make_tap_button("", pos, size, callback)
	button.add_theme_font_size_override("font_size", 15)
	button.add_theme_color_override("font_color", Color("#ffe7a3"))
	button.add_theme_color_override("font_outline_color", Color.BLACK)
	button.add_theme_constant_override("outline_size", 4)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.03, 0.03, 0.05, 0.72)
	style.border_color = Color("#c49b3f")
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		button.add_theme_stylebox_override(state, style)
	return button


func process(delta: float) -> void:
	if main.player == null:
		return
	_update_daily_hud()
	_track_ride()
	_pet_tricks()
	_update_mount_care()
	_update_event(delta)
	_update_quest_marks(delta)
	_update_ambient(delta)
	_update_sfx_hooks(delta)
	_update_tracker(delta)
	_update_boss_bar(delta)
	_update_dodge_button()
	_update_event_bosses(delta)
	_update_gear_aura(delta)


# ======================= 1. missoes diarias =======================
func _ensure_daily() -> Dictionary:
	var today := Time.get_date_string_from_system()
	var daily = _cache().get("daily", {})
	if typeof(daily) != TYPE_DICTIONARY or str(daily.get("date", "")) != today:
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(today + str(main.player.character_name if main.player != null else ""))
		var from_rules: Variant = main._rule(["diarias"], null)
		var pool: Array = (from_rules as Array).duplicate(true) if typeof(from_rules) == TYPE_ARRAY and (from_rules as Array).size() >= 3 else DAILY_POOL.duplicate(true)
		var tasks: Array = []
		for i in range(3):
			var pick: Dictionary = pool.pop_at(rng.randi() % pool.size())
			var goal_range: Array = pick["goal"]
			var goal := rng.randi_range(int(goal_range[0]), int(goal_range[1]))
			if pick["id"] == "ride":
				goal = int(round(goal / 50.0)) * 50
			tasks.append({"id": pick["id"], "text": str(pick["text"]) % goal, "goal": goal, "progress": 0, "reward": int(pick["reward"]), "done": false, "item": str(pick.get("item", ""))})
		daily = {"date": today, "tasks": tasks}
		_cache()["daily"] = daily
	return daily


func daily_progress(kind: String, amount: int = 1, item_name: String = "") -> void:
	var daily := _ensure_daily()
	for task in daily.get("tasks", []):
		if typeof(task) != TYPE_DICTIONARY or bool(task.get("done", false)) or str(task.get("id", "")) != kind:
			continue
		# coleta de um item especifico (ex.: Carne Crua)
		if not str(task.get("item", "")).is_empty() and str(task.get("item", "")) != item_name:
			continue
		task["progress"] = mini(int(task["goal"]), int(task.get("progress", 0)) + amount)
		if int(task["progress"]) >= int(task["goal"]):
			task["done"] = true
			main.player.ouro += int(task["reward"])
			main._flash("Missao diaria completa: %s! +%d ouro" % [str(task["text"]), int(task["reward"])])
			if AudioManager != null:
				AudioManager.play_sfx("rare_drop")


func _update_daily_hud() -> void:
	if daily_label == null or not is_instance_valid(daily_label):
		return
	var daily := _ensure_daily()
	var done := 0
	var next_task: Dictionary = {}
	for task in daily.get("tasks", []):
		if bool(task.get("done", false)):
			done += 1
		elif next_task.is_empty():
			next_task = task
	if next_task.is_empty():
		daily_label.text = "Diarias completas (3/3)! Volte amanha"
	else:
		daily_label.text = "Diaria %d/3: %s  %d/%d" % [done, str(next_task["text"]), int(next_task.get("progress", 0)), int(next_task["goal"])]


func _track_ride() -> void:
	var pos: Vector2 = main.player.global_position
	if main._current_equipped_mount_code() != "" and ride_last_pos != Vector2.INF:
		var step := pos.distance_to(ride_last_pos)
		if step > 0.0 and step < 60.0:
			var acc := float(_cache().get("ride_acc", 0.0)) + step / 10.0  # 10 px = 1 m
			if acc >= 10.0:
				daily_progress("ride", int(acc))
				acc -= int(acc)
			_cache()["ride_acc"] = acc
	ride_last_pos = pos


func show_daily() -> void:
	var box: VBoxContainer = main._start_modal("Missoes Diarias", "daily")
	box.add_child(main._panel_label("Novas missoes todo dia. A recompensa cai sozinha quando voce completa.", 13, Color("#cfd6df")))
	var daily := _ensure_daily()
	for task in daily.get("tasks", []):
		var done := bool(task.get("done", false))
		var line := "%s %s   %d/%d   (+%d ouro)" % ["[OK]" if done else "[  ]", str(task["text"]), int(task.get("progress", 0)), int(task["goal"]), int(task["reward"])]
		box.add_child(main._panel_label(line, 16, Color("#8fe3a8") if done else Color.WHITE))


# ======================= 2. truques do pet =======================
func _pet_tricks() -> void:
	var code: String = main._current_equipped_pet_code()
	if code.is_empty() or main.pet_follower == null or not is_instance_valid(main.pet_follower):
		return
	var affinity: float = main._pet_affinity(code)
	var pet_pos: Vector2 = main.pet_pos
	var player_pos: Vector2 = main.player.global_position
	if affinity >= 80.0:
		# busca itens: o que cair perto do pet vem ate voce
		var fetched := false
		for node in get_tree().get_nodes_in_group("drops"):
			var drop := node as ItemDrop
			if drop == null or not is_instance_valid(drop) or not drop.can_auto_collect() or bool(drop.get_meta("manual_collect", false)):
				continue
			var far: float = drop.global_position.distance_to(player_pos)
			if far > main.DROP_PICKUP_RADIUS and drop.global_position.distance_to(pet_pos) < PET_FETCH_RADIUS:
				drop.global_position = drop.global_position.move_toward(player_pos, main.DROP_MAGNET_SPEED * 0.8 * get_process_delta_time())
				fetched = true
		if fetched and _now() >= pet_fetch_emote_at:
			pet_fetch_emote_at = _now() + 8.0
			main._pet_emote("alerta")
	if affinity >= 100.0 and _now() >= pet_boss_warn_at:
		for node in get_tree().get_nodes_in_group("bosses"):
			var boss := node as Node2D
			if boss != null and is_instance_valid(boss) and boss.global_position.distance_to(player_pos) < 900.0:
				pet_boss_warn_at = _now() + 60.0
				main._pet_emote("preocupado", true)
				main._flash_red("Seu pet sente um chefe por perto! Prepare-se.")
				break


# ======================= 3. estabulo =======================
func mount_care_active() -> bool:
	return float(_cache().get("mount_care_until", 0.0)) > Time.get_unix_time_from_system()


func _care(key: String, default_value: float) -> float:
	return float(main._rule(["montaria", "estabulo", key], default_value))


func mount_care_bonus() -> float:
	return _care("bonus_velocidade", MOUNT_CARE_BONUS) if mount_care_active() else 0.0


func care_for_mount() -> void:
	if main._owned_mount_codes().is_empty():
		main._flash_red("Voce ainda nao tem montaria.")
		return
	var price := int(_care("preco", MOUNT_CARE_PRICE))
	if main.player.ouro < price:
		main._flash_red("Cuidar da montaria custa %d ouro." % price)
		return
	main.player.ouro -= price
	_cache()["mount_care_until"] = Time.get_unix_time_from_system() + _care("duracao_s", MOUNT_CARE_SECONDS)
	main._apply_companion_bonuses()
	main._flash("Montaria escovada e alimentada: +%d%% de velocidade por %d min!" % [int(round(_care("bonus_velocidade", MOUNT_CARE_BONUS) * 100)), int(_care("duracao_s", MOUNT_CARE_SECONDS) / 60.0)])


func mount_care_text() -> String:
	var left := float(_cache().get("mount_care_until", 0.0)) - Time.get_unix_time_from_system()
	var bonus := int(round(_care("bonus_velocidade", MOUNT_CARE_BONUS) * 100))
	if left <= 0.0:
		return "Cuidar da montaria (escovar e alimentar): +%d%% de velocidade por %d min, %d ouro." % [bonus, int(_care("duracao_s", MOUNT_CARE_SECONDS) / 60.0), int(_care("preco", MOUNT_CARE_PRICE))]
	return "Montaria bem cuidada: +%d%% de velocidade por mais %d min." % [bonus, int(ceil(left / 60.0))]


func _update_mount_care() -> void:
	var active := mount_care_active()
	if active != mount_care_was_active:
		mount_care_was_active = active
		main._apply_companion_bonuses()
		if not active:
			main._flash("O cuidado com a montaria acabou. Volte ao Mercado de Montarias para cuidar dela.")


# ======================= 4. NPCs que lembram =======================
func on_npc(npc: Node) -> void:
	if npc == null or not is_instance_valid(npc):
		return
	var npc_name := str(npc.get("npc_name"))
	if npc_name.is_empty():
		return
	var visits: Dictionary = _cache().get("npc_visits", {})
	var count := int(visits.get(npc_name, 0)) + 1
	visits[npc_name] = count
	_cache()["npc_visits"] = visits
	var hero := str(main.player.character_name)
	var greetings: Variant = main._rule(["npcs", "saudacoes"], NPC_GREETINGS)
	if typeof(greetings) != TYPE_ARRAY or (greetings as Array).is_empty():
		greetings = NPC_GREETINGS
	if count == int(main._rule(["npcs", "presente_na_visita"], 5)):
		var gold := int(main._rule(["npcs", "presente_ouro"], 100))
		main.player.ouro += gold
		var gifts: Array = []
		for gift in main._rule(["npcs", "presente_itens"], [{"item": "Pocao pequena de vida", "amount": 2}]):
			main.player.inventory.add_item(str(gift.get("item", "")), int(gift.get("amount", 1)))
			gifts.append("%d %s" % [int(gift.get("amount", 1)), str(gift.get("item", ""))])
		main._show_npc_bubble(npc, "%s, voce e um cliente fiel! Tome um presente." % hero)
		main._flash("%s te deu %d ouro e %s!" % [npc_name, gold, ", ".join(gifts)])
	elif count >= 2:
		var line := str(greetings[randi() % (greetings as Array).size()])
		main._show_npc_bubble(npc, line % hero if "%s" in line else line)


# ======================= 5. eventos =======================
func _update_event(delta: float) -> void:
	if event_kind.is_empty():
		event_label.visible = false
		if _now() >= event_next_at and not photo_mode:
			_start_random_event()
		return
	var left := event_until - _now()
	event_label.visible = true
	match event_kind:
		"mercador":
			event_label.text = "Evento: Mercador viajante (%ds) - toque para comprar" % int(left)
		"ladrao":
			event_label.text = "Evento: pegue o ladrao! (%ds)" % int(left)
			_update_thief(delta)
		"corrida":
			var dist := int(main.player.global_position.distance_to(event_target) / 10.0)
			event_label.text = "Evento: corra ate a bandeira! %d m (%ds)" % [dist, int(left)]
			if main.player.global_position.distance_to(event_target) < 70.0:
				var prize := int(main._rule(["eventos", "corrida", "recompensa"], 200))
				_finish_event(true, "Voce chegou na bandeira! +%d ouro" % prize, prize)
				return
	if left <= 0.0:
		var msg := {"mercador": "O mercador viajante foi embora.", "ladrao": "O ladrao fugiu...", "corrida": "O tempo da corrida acabou."}
		_finish_event(false, str(msg.get(event_kind, "")), 0)


func _start_random_event() -> void:
	var options := ["mercador", "corrida"]
	if _pedestrian_frames() != null:
		options.append("ladrao")
	event_kind = options[randi() % options.size()]
	match event_kind:
		"mercador":
			event_until = _now() + float(main._rule(["eventos", "mercador", "duracao_s"], 150.0))
			main._flash("Um mercador viajante chegou! Toque no aviso do evento para comprar.")
		"ladrao":
			if not _spawn_thief():
				event_kind = ""
				event_next_at = _now() + 60.0
				return
			event_until = _now() + float(main._rule(["eventos", "ladrao", "duracao_s"], 45.0))
			main._flash_red("Pega ladrao! Alguem roubou a bolsa de um mercador. Encoste nele!")
		"corrida":
			if not _spawn_race_flag():
				event_kind = ""
				event_next_at = _now() + 60.0
				return
			event_until = _now() + float(main._rule(["eventos", "corrida", "duracao_s"], 35.0))
			main._flash("Corrida! Chegue na bandeira dourada antes do tempo acabar (montaria ajuda).")


func _finish_event(won: bool, text: String, gold: int) -> void:
	if event_node != null and is_instance_valid(event_node):
		event_node.queue_free()
	event_node = null
	var kind := event_kind
	event_kind = ""
	event_next_at = _now() + main._rule_range(["eventos", "intervalo_s"], 300.0, 480.0)
	if main.current_panel == "event_shop" and main.panel.visible:
		main._hide_panel()
	if won:
		main.player.ouro += gold
		main._flash(text)
		daily_progress("event")
		main._pet_emote("nota", true)
	elif kind != "" and not text.is_empty():
		main._flash(text)


func show_events() -> void:
	if event_kind == "mercador":
		_show_merchant()
		return
	var box: VBoxContainer = main._start_modal("Eventos", "events")
	box.add_child(main._panel_label("De tempos em tempos acontece algo no mundo:", 14, Color("#cfd6df")))
	box.add_child(main._panel_label("- Mercador viajante: itens com desconto por pouco tempo.", 14, Color.WHITE))
	box.add_child(main._panel_label("- Ladrao: encoste nele antes que fuja e ganhe a recompensa.", 14, Color.WHITE))
	box.add_child(main._panel_label("- Corrida: chegue na bandeira dourada antes do tempo.", 14, Color.WHITE))
	var wait := int(maxf(0.0, event_next_at - _now()))
	var now_text := "Agora: %s" % event_kind if not event_kind.is_empty() else "Proximo evento em uns %d min." % maxi(1, int(ceil(wait / 60.0)))
	box.add_child(main._panel_label(now_text, 14, Color("#ffd36b")))


func _merchant_offers() -> Array:
	var from_rules: Variant = main._rule(["eventos", "mercador", "ofertas"], null)
	if typeof(from_rules) == TYPE_ARRAY and not (from_rules as Array).is_empty():
		return from_rules
	var offers := [
		{"item": "Carne Crua", "amount": 3, "price": 45, "text": "3 Carne Crua (comida do pet)"},
		{"item": "Pocao media de vida", "amount": 2, "price": 55, "text": "2 Pocoes medias de vida"},
		{"item": "Pocao media de mana", "amount": 2, "price": 55, "text": "2 Pocoes medias de mana"},
	]
	return offers


func _show_merchant() -> void:
	var box: VBoxContainer = main._start_modal("Mercador Viajante", "event_shop")
	box.add_child(main._panel_label("Ouro: %d   |   So enquanto o mercador estiver por aqui!" % main.player.ouro, 15, Color("#ffd36b")))
	for offer in _merchant_offers():
		var row := HBoxContainer.new()
		box.add_child(row)
		row.add_child(main._panel_label("%s - %d ouro" % [offer["text"], int(offer["price"])], 15, Color.WHITE))
		var buy := Button.new()
		buy.text = "Comprar"
		main._style_panel_button(buy)
		buy.pressed.connect(func() -> void:
			if main.player.ouro < int(offer["price"]):
				main._flash_red("Ouro insuficiente.")
				return
			if not main.player.inventory.add_item(str(offer["item"]), int(offer["amount"])):
				main._flash_red("Bolsa cheia.")
				return
			main.player.ouro -= int(offer["price"])
			main._flash("Comprado: %s" % offer["text"])
			_show_merchant()
		)
		row.add_child(buy)


var thief_offsets: Dictionary = {}
var thief_scale := Vector2.ONE

func _pedestrian_frames() -> SpriteFrames:
	for state in main.kit_vehicles:
		if bool(state.get("flying", false)):
			continue
		var sprite := state.get("node") as AnimatedSprite2D
		if sprite != null and is_instance_valid(sprite) and sprite.sprite_frames != null:
			var w := float(main._kit_vehicle_rect(state, sprite.position).size.x)
			if w < 80.0:  # pedestre, nao carroca
				thief_offsets = state.get("offsets", {})
				thief_scale = sprite.scale
				return sprite.sprite_frames
	return null


func _random_walkable_near(center: Vector2, min_d: float, max_d: float) -> Vector2:
	for i in range(40):
		var angle := randf() * TAU
		var p := center + Vector2(cos(angle), sin(angle)) * randf_range(min_d, max_d)
		if not main._is_point_blocked(p):
			return p
	return Vector2.INF


func _spawn_thief() -> bool:
	var frames := _pedestrian_frames()
	var start := _random_walkable_near(main.player.global_position, 260.0, 420.0)
	if frames == null or start == Vector2.INF:
		return false
	var thief := AnimatedSprite2D.new()
	thief.sprite_frames = frames
	thief.centered = false  # como os pedestres: a posicao e o pe
	thief.modulate = Color(0.55, 0.45, 0.75)  # roupa escura de ladrao
	thief.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	thief.scale = thief_scale
	thief.position = start
	var tag := Label.new()
	tag.text = "LADRAO!"
	tag.add_theme_color_override("font_color", Color("#ff6b6b"))
	tag.add_theme_color_override("font_outline_color", Color.BLACK)
	tag.add_theme_constant_override("outline_size", 5)
	tag.position = Vector2(-30, -150)
	thief.add_child(tag)
	main.world.add_child(thief)
	event_node = thief
	event_waypoint = start
	return true


func _update_thief(delta: float) -> void:
	var thief := event_node as AnimatedSprite2D
	if thief == null or not is_instance_valid(thief):
		return
	var hero: Vector2 = main.player.global_position
	if thief.position.distance_to(hero + Vector2(0, main.MOUNT_GROUND_Y)) < 60.0:
		var prize := int(main._rule(["eventos", "ladrao", "recompensa"], 250))
		_finish_event(true, "Voce pegou o ladrao! O mercador te deu %d ouro." % prize, prize)
		return
	if thief.position.distance_to(event_waypoint) < 12.0:
		# foge para longe do heroi
		var away := (thief.position - hero).normalized()
		var next := _random_walkable_near(thief.position + away * 220.0, 0.0, 160.0)
		event_waypoint = next if next != Vector2.INF else _random_walkable_near(thief.position, 120.0, 260.0)
		if event_waypoint == Vector2.INF:
			event_waypoint = thief.position
	var base_speed := float(main._rule(["eventos", "ladrao", "velocidade"], 150.0))
	var speed := base_speed if thief.position.distance_to(hero) > 200.0 else base_speed * 1.15
	var dir := (event_waypoint - thief.position)
	thief.position = thief.position.move_toward(event_waypoint, speed * delta)
	var side := "left" if dir.x < 0.0 else "right"
	var anim := "move_" + side
	if absf(dir.y) > absf(dir.x):
		var vertical := "move_" + ("up" if dir.y < 0.0 else "down")
		if thief.sprite_frames.has_animation(vertical):
			anim = vertical
	if not thief.sprite_frames.has_animation(anim):
		anim = "move_left" if thief.sprite_frames.has_animation("move_left") else str(thief.sprite_frames.get_animation_names()[0])
	if thief.animation != anim or not thief.is_playing():
		thief.offset = thief_offsets.get(anim, Vector2.ZERO)
		thief.play(anim)
	thief.z_index = clampi(int(thief.position.y), -1024, 1024)


func _spawn_race_flag() -> bool:
	var dist_range: Variant = main._rule(["eventos", "corrida", "distancia_px"], [700, 1100])
	var target := _random_walkable_near(main.player.global_position, float(dist_range[0]), float(dist_range[1]))
	if target == Vector2.INF:
		return false
	event_target = target + Vector2(0, main.MOUNT_GROUND_Y)
	var flag := Node2D.new()
	flag.position = event_target
	var ring := Line2D.new()
	ring.width = 5.0
	ring.default_color = Color(1.0, 0.82, 0.25, 0.9)
	for i in range(33):
		var a := TAU * i / 32.0
		ring.add_point(Vector2(cos(a) * 60.0, sin(a) * 26.0))
	flag.add_child(ring)
	var pole := Line2D.new()
	pole.width = 4.0
	pole.default_color = Color("#6b4a2a")
	pole.points = PackedVector2Array([Vector2(0, 0), Vector2(0, -120)])
	flag.add_child(pole)
	var cloth := Polygon2D.new()
	cloth.color = Color("#ffd23f")
	cloth.polygon = PackedVector2Array([Vector2(0, -120), Vector2(56, -104), Vector2(0, -86)])
	flag.add_child(cloth)
	flag.z_index = clampi(int(event_target.y), -1024, 1024)
	main.world.add_child(flag)
	event_node = flag
	return true


# ======================= 6. modo foto =======================
func toggle_photo_mode() -> void:
	photo_mode = not photo_mode
	if photo_mode:
		main._hide_panel()
		photo_hidden.clear()
		for layer in main.find_children("*", "CanvasLayer", true, false):
			if layer.visible:
				layer.visible = false
				photo_hidden.append(layer)
		photo_layer = CanvasLayer.new()
		photo_layer.layer = 120
		var hint := Label.new()
		hint.text = "MODO FOTO  -  P ou toque aqui para sair"
		hint.position = Vector2(20, 680)
		hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.75))
		hint.add_theme_color_override("font_outline_color", Color.BLACK)
		hint.add_theme_constant_override("outline_size", 4)
		hint.mouse_filter = Control.MOUSE_FILTER_STOP
		hint.gui_input.connect(func(ev: InputEvent) -> void:
			if ev is InputEventMouseButton and ev.pressed:
				toggle_photo_mode()
		)
		photo_layer.add_child(hint)
		main.add_child(photo_layer)
		# o pet vem posar do lado do heroi
		main.pet_pos = main.player.global_position + Vector2(78, 18)
	else:
		for layer in photo_hidden:
			if is_instance_valid(layer):
				layer.visible = true
		photo_hidden.clear()
		if photo_layer != null and is_instance_valid(photo_layer):
			photo_layer.queue_free()
		photo_layer = null


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).keycode == KEY_P:
		if main.panel == null or not main.panel.visible or photo_mode:
			toggle_photo_mode()
			get_viewport().set_input_as_handled()


# ======================= 7. colecao =======================
func on_kill(enemy_name: String, boss: bool) -> void:
	if boss:
		_victory_banner(enemy_name)
		_give_trophy_first_kill(enemy_name)
		_event_boss_reward(enemy_name)
	var col: Dictionary = _cache().get("collection", {})
	var monsters: Dictionary = col.get("monsters", {})
	var first := not monsters.has(enemy_name)
	monsters[enemy_name] = int(monsters.get(enemy_name, 0)) + 1
	col["monsters"] = monsters
	_cache()["collection"] = col
	if first:
		main._flash("Novo na colecao: %s!" % enemy_name)
	daily_progress("kill_any")
	if "Javali" in enemy_name:
		daily_progress("kill_boar")
	if boss:
		daily_progress("boss")


func show_collection() -> void:
	var box: VBoxContainer = main._start_modal("Livro de Colecao", "collection")
	var monsters: Dictionary = _cache().get("collection", {}).get("monsters", {})
	var owned_pets := []
	for entry in _cache().get("pets_state", {}).get("pets", []):
		owned_pets.append(str(entry.get("code", "")))
	var owned_mounts: Array = main._owned_mount_codes()
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(860, 430)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	var list := VBoxContainer.new()
	scroll.add_child(list)
	var total_m: int = main.enemies_db.size()
	list.add_child(main._panel_label("Monstros: %d de %d" % [monsters.size(), total_m], 18, Color("#ffd36b")))
	list.add_child(_icon_grid(main.enemies_db.keys(), func(name) -> Array:
		var seen := monsters.has(name)
		return [_enemy_icon(str(name)), (str(name) + "\n%d derrotados" % int(monsters.get(name, 0))) if seen else "???\nainda nao visto", seen]
	))
	list.add_child(main._panel_label("Pets: %d de %d" % [owned_pets.size(), main.pet_definitions.size()], 18, Color("#ffd36b")))
	var pet_codes := []
	for d in main.pet_definitions:
		pet_codes.append(str(d.get("code", "")))
	list.add_child(_icon_grid(pet_codes, func(code) -> Array:
		var has := owned_pets.has(code)
		var d: Dictionary = main._definition_by_code(main.pet_definitions, str(code))
		return [main._pet_icon_path(str(code)), str(d.get("name", code)) + ("\nafinidade %d%%" % int(main._pet_affinity(str(code))) if has else "\nnao tem"), has]
	))
	list.add_child(main._panel_label("Montarias: %d de %d" % [owned_mounts.size(), main.mount_definitions.size()], 18, Color("#ffd36b")))
	var mount_codes := []
	for d in main.mount_definitions:
		mount_codes.append(str(d.get("code", "")))
	list.add_child(_icon_grid(mount_codes, func(code) -> Array:
		var has := owned_mounts.has(code)
		var d: Dictionary = main._definition_by_code(main.mount_definitions, str(code))
		return [main._mount_icon_path(str(code)), str(d.get("name", code)) + ("\nna sua cocheira" if has else "\nnao tem"), has]
	))
	var trophies: Dictionary = main._rule(["trofeus"], {})
	var got: Dictionary = _cache().get("trofeus", {})
	list.add_child(main._panel_label("Trofeus de chefe: %d de %d" % [got.size(), trophies.size()], 18, Color("#ffd36b")))
	list.add_child(_icon_grid(trophies.keys(), func(boss_name) -> Array:
		var item_name := str(trophies[boss_name])
		var has := got.has(boss_name)
		var item: Dictionary = main.item_db.get_item(item_name) if main.item_db != null else {}
		return [str(item.get("icon", "")), (item_name + "\n" + str(boss_name)) if has else "???\nvenca: " + str(boss_name), has]
	))


func _icon_grid(keys: Array, info: Callable) -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = 6
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	for key in keys:
		var data: Array = info.call(key)
		var cell := VBoxContainer.new()
		cell.custom_minimum_size = Vector2(134, 118)
		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(134, 70)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		if ResourceLoader.exists(str(data[0])):
			icon.texture = load(str(data[0]))
		if not bool(data[2]):
			icon.modulate = Color(0, 0, 0, 0.55)  # silhueta do que falta
		cell.add_child(icon)
		var label: Label = main._panel_label(str(data[1]), 12, Color.WHITE if bool(data[2]) else Color("#8a93a0"))
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		cell.add_child(label)
		grid.add_child(cell)
	return grid


func _enemy_icon(enemy_name: String) -> String:
	var probe := Enemy.new()
	var path := str(probe.call("_sprite_path", enemy_name))
	probe.free()
	return path


# ======================= 8. cidade viva: esbarroes =======================
const BUMP_FALLBACK := ["Ei! Olha por onde anda!", "Cuidado, aventureiro!", "Com licenca tambem funciona!"]
var bump_last_at := -10.0
var bump_actor_at: Dictionary = {}


# chamado pelo main quando o heroi (a pe ou montado) esbarra num NPC ou pedestre
func on_bump(actor: Dictionary, mounted: bool) -> void:
	var node: Node2D = actor.get("node")
	if node == null or not is_instance_valid(node):
		return
	var now := _now()
	var key := node.get_instance_id()
	if now - bump_last_at < 1.5 or now - float(bump_actor_at.get(key, -100.0)) < 6.0:
		return
	bump_last_at = now
	bump_actor_at[key] = now
	var lines: Variant = null
	var npc_name := str(actor.get("name", ""))
	if not npc_name.is_empty():
		lines = main._rule(["esbarrao", "npcs", npc_name], null)
	if lines == null and mounted and randf() < 0.6:
		lines = main._rule(["esbarrao", "montado"], null)
	if lines == null:
		lines = main._rule(["esbarrao", "pedestres"], BUMP_FALLBACK)
	if typeof(lines) != TYPE_ARRAY or (lines as Array).is_empty():
		lines = BUMP_FALLBACK
	var line := str(lines[randi() % (lines as Array).size()])
	if node is Npc:
		main._show_npc_bubble(node, line)
	else:
		_bump_bubble(node, line)


# balaozinho que sobe e some em cima do pedestre (filho dele: acompanha se ele andar)
func _bump_bubble(node: Node2D, text: String) -> void:
	var old := node.get_node_or_null("BumpBubble")
	if old != null:
		old.queue_free()
	var bubble := PanelContainer.new()
	bubble.name = "BumpBubble"
	bubble.z_index = 4000
	bubble.z_as_relative = false
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.98, 0.96, 0.9, 0.95)
	style.border_color = Color("#5b4422")
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 3
	style.content_margin_bottom = 3
	bubble.add_theme_stylebox_override("panel", style)
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color("#2a1d0c"))
	bubble.add_child(label)
	node.add_child(bubble)
	bubble.reset_size()
	# a origem do pedestre/carroca e o ponto dos pes no centro; o balao fica acima do desenho
	var top := -150.0
	var sprite := node as AnimatedSprite2D
	if sprite != null and sprite.sprite_frames != null:
		top = sprite.offset.y - bubble.size.y - 6.0
	bubble.scale = Vector2.ONE / node.scale  # pedestre encolhido pela regra de tamanhos: texto igual
	bubble.position = Vector2(-bubble.size.x * 0.5 * bubble.scale.x, top)
	var tween := bubble.create_tween()
	tween.tween_property(bubble, "position:y", bubble.position.y - 14.0, 0.25)
	tween.tween_interval(1.8)
	tween.tween_property(bubble, "modulate:a", 0.0, 0.4)
	tween.tween_callback(bubble.queue_free)


# ======================= 9. cidade viva: marcas de missao =======================
var quest_mark_timer := 0.0


func _update_quest_marks(delta: float) -> void:
	quest_mark_timer -= delta
	if quest_mark_timer > 0.0:
		return
	quest_mark_timer = 0.5
	var qs = main.quest_system
	if qs == null:
		return
	for npc in get_tree().get_nodes_in_group("npcs"):
		if not (npc is Npc) or not is_instance_valid(npc):
			continue
		var text := ""
		var color := Color("#ffd23f")
		match str(main._npc_quest_state(str(npc.npc_name))):
			"available":
				text = "!"
			"ready":
				text = "?"
			"progress":
				text = "?"
				color = Color("#b8b8b8")
		if text.is_empty() and qs.has_method("pending_talk_quest") and not qs.pending_talk_quest(str(npc.npc_name)).is_empty():
			text = "!"
			color = Color("#6fd3ff")
		_set_quest_mark(npc, text, color)


func _set_quest_mark(npc: Node2D, text: String, color: Color) -> void:
	var mark := npc.get_node_or_null("QuestMark") as Label
	if text.is_empty():
		if mark != null:
			mark.queue_free()
		return
	if mark == null:
		mark = Label.new()
		mark.name = "QuestMark"
		mark.add_theme_font_size_override("font_size", 46)
		mark.add_theme_color_override("font_outline_color", Color.BLACK)
		mark.add_theme_constant_override("outline_size", 8)
		mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		mark.size = Vector2(40, 56)
		mark.position = Vector2(-20, -164)
		mark.z_index = 4000
		mark.z_as_relative = false
		npc.add_child(mark)
		var tween := mark.create_tween().set_loops()
		tween.tween_property(mark, "position:y", -172.0, 0.5).set_trans(Tween.TRANS_SINE)
		tween.tween_property(mark, "position:y", -164.0, 0.5).set_trans(Tween.TRANS_SINE)
	mark.text = text
	mark.add_theme_color_override("font_color", color)


# ======================= 10. som ambiente =======================
const AMBIENT_DIR := "res://assets/audio/ambiente/"
const AMBIENT_FADE := 1.5
var ambient_players: Array = []
var ambient_active := 0
var ambient_map := ""


func _ambient_volume() -> float:
	return clampf(float(_cache().get("ambient_volume", 0.7)), 0.0, 1.0)


func _ambient_db(scale: float) -> float:
	var v := _ambient_volume() * scale
	return -60.0 if v <= 0.001 else linear_to_db(v) - 6.0


func _update_ambient(delta: float) -> void:
	if ambient_players.is_empty():
		for i in 2:
			var p := AudioStreamPlayer.new()
			p.name = "Ambiente%d" % i
			p.volume_db = -60.0
			add_child(p)
			ambient_players.append(p)
	var map_id := str(main.current_map)
	if map_id == "world_reset":
		map_id = "forest_boars"
	if map_id != ambient_map:
		ambient_map = map_id
		var path := AMBIENT_DIR + map_id + ".ogg"
		var next: AudioStreamPlayer = ambient_players[1 - ambient_active]
		next.stop()
		next.stream = null
		if ResourceLoader.exists(path):
			var stream := load(path) as AudioStreamOggVorbis
			if stream != null:
				stream.loop = true
				next.stream = stream
				next.volume_db = -60.0
				next.play(randf() * maxf(stream.get_length() - 1.0, 0.0))
		ambient_active = 1 - ambient_active
	# crossfade: o ativo sobe ate o volume escolhido, o outro desce e para
	for i in 2:
		var p: AudioStreamPlayer = ambient_players[i]
		if not p.playing:
			continue
		var target := _ambient_db(1.0) if i == ambient_active else -60.0
		var step := 60.0 / AMBIENT_FADE * delta
		p.volume_db = move_toward(p.volume_db, target, step)
		if i != ambient_active and p.volume_db <= -59.0:
			p.stop()


func show_settings() -> void:
	var box: VBoxContainer = main._start_modal("Configuracoes", "settings")
	box.add_child(main._panel_label("Som ambiente (mar, passaros, vento, caverna...)", 16, Color("#fff3cf")))
	var row := HBoxContainer.new()
	box.add_child(row)
	var slider := HSlider.new()
	slider.min_value = 0
	slider.max_value = 100
	slider.step = 5
	slider.value = round(_ambient_volume() * 100.0)
	slider.custom_minimum_size = Vector2(300, 36)
	row.add_child(slider)
	var value_label: Label = main._panel_label("%d%%" % int(slider.value), 16, Color("#ffd36b"))
	row.add_child(value_label)
	slider.value_changed.connect(func(v: float) -> void:
		_cache()["ambient_volume"] = v / 100.0
		value_label.text = "%d%%" % int(v)
	)
	var mute := Button.new()
	mute.text = "Desligar som ambiente" if _ambient_volume() > 0.0 else "Ligar som ambiente"
	main._style_panel_button(mute)
	mute.pressed.connect(func() -> void:
		var v := 0.0 if _ambient_volume() > 0.0 else 0.7
		_cache()["ambient_volume"] = v
		slider.value = round(v * 100.0)
		mute.text = "Desligar som ambiente" if v > 0.0 else "Ligar som ambiente"
	)
	box.add_child(mute)
	box.add_child(main._panel_label("Efeitos sonoros (golpes, moedas, menus...)", 16, Color("#fff3cf")))
	var row2 := HBoxContainer.new()
	box.add_child(row2)
	var sfx_slider := HSlider.new()
	sfx_slider.min_value = 0
	sfx_slider.max_value = 100
	sfx_slider.step = 5
	sfx_slider.value = round(AudioManager.sfx_volume * 100.0)
	sfx_slider.custom_minimum_size = Vector2(300, 36)
	row2.add_child(sfx_slider)
	var sfx_label: Label = main._panel_label("%d%%" % int(sfx_slider.value), 16, Color("#ffd36b"))
	row2.add_child(sfx_label)
	sfx_slider.value_changed.connect(func(v: float) -> void:
		AudioManager.sfx_volume = v / 100.0
		_cache()["sfx_volume"] = v / 100.0
		sfx_label.text = "%d%%" % int(v)
		AudioManager.play_sfx("moeda", 1.0, 0.2)
	)
	box.add_child(main._panel_label("Distancia da camera (zoom). Tambem: botoes + e - ao lado do mini mapa ou roda do mouse.", 16, Color("#fff3cf")))
	var row3 := HBoxContainer.new()
	box.add_child(row3)
	var zoom_label: Label = main._panel_label(main._zoom_texto(), 16, Color("#ffd36b"))
	for dados in [["Mais longe", -1], ["Mais perto", 1], ["Padrao", 0]]:
		var b := Button.new()
		b.text = str(dados[0])
		main._style_panel_button(b)
		var passo := int(dados[1])
		b.pressed.connect(func() -> void:
			if passo == 0:
				main._mudar_zoom(main.CAMERA_ZOOM_PADRAO - main.hud_zoom_index)
			else:
				main._mudar_zoom(passo)
			zoom_label.text = main._zoom_texto()
		)
		row3.add_child(b)
	row3.add_child(zoom_label)


# ======================= 11. sons de acao =======================
var sfx_hooked_player: Node = null
var sfx_last_level := -1
var hoof_timer := 0.0


func _update_sfx_hooks(delta: float) -> void:
	var player: Player = main.player
	if player != sfx_hooked_player:
		sfx_hooked_player = player
		sfx_last_level = player.level
		player.attack_requested.connect(func(_p, _r, _s) -> void: AudioManager.play_sfx("golpe", 0.8, 0.08))
		player.skill_area_requested.connect(func(_p, _r, _s) -> void: AudioManager.play_sfx("golpe", 1.0, 0.08))
		player.dash_requested.connect(func(_d, _s) -> void: AudioManager.play_sfx("golpe", 0.9, 0.08))
		player.damage_taken.connect(func(_a) -> void: AudioManager.play_sfx("dano", 0.7, 0.18))
	if player.level > sfx_last_level and sfx_last_level >= 0:
		AudioManager.play_sfx("nivel")
		if not player.talent_tree.is_empty():
			main._flash("Nivel %d! Voce ganhou 1 ponto de talento (Menu > Talentos)." % player.level)
	sfx_last_level = player.level
	# passos da montaria
	hoof_timer -= delta
	if hoof_timer <= 0.0 and not str(main._current_equipped_mount_code()).is_empty() and player.velocity.length() > 30.0:
		hoof_timer = 0.34
		AudioManager.play_sfx("casco", 0.45, 0.2)


# ======================= 12. rastreador de missao + seta =======================
const TRACKER_POS := Vector2(12, 338)
const TRACKER_SIZE := Vector2(268, 70)
var tracker_button: Button
var tracker_arrow: Polygon2D
var tracker_timer := 0.0
var tracker_dest := Vector2.INF
var tracker_dest_node: Node2D = null


func _tracked_quest() -> String:
	var qs = main.quest_system
	if qs == null or qs.active.is_empty():
		return ""
	var ids: Array = qs.active.keys()
	ids.sort()
	for quest_id in ids:
		if str(quest_id).begins_with("jornada_"):
			return str(quest_id)
	return str(ids[0])


func _update_tracker(delta: float) -> void:
	if tracker_button == null:
		tracker_button = _hud_button(TRACKER_POS, TRACKER_SIZE, func() -> void: main._show_quests())
		tracker_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		tracker_button.add_theme_font_size_override("font_size", 13)
		tracker_button.clip_text = true
	if tracker_arrow == null or not is_instance_valid(tracker_arrow):
		tracker_arrow = Polygon2D.new()
		tracker_arrow.polygon = PackedVector2Array([Vector2(42, 0), Vector2(-16, -24), Vector2(-5, 0), Vector2(-16, 24)])
		tracker_arrow.color = Color("#ffd23f")
		var outline := Line2D.new()
		outline.points = PackedVector2Array([Vector2(42, 0), Vector2(-16, -24), Vector2(-5, 0), Vector2(-16, 24), Vector2(42, 0)])
		outline.width = 3.0
		outline.default_color = Color(0.1, 0.06, 0.0, 0.9)
		tracker_arrow.add_child(outline)
		tracker_arrow.z_as_relative = false
		tracker_arrow.z_index = 3900
		main.world.add_child(tracker_arrow)
	tracker_timer -= delta
	if tracker_timer <= 0.0:
		tracker_timer = 0.5
		_refresh_tracker()
	var player_pos: Vector2 = main.player.global_position
	var dest := tracker_dest
	if tracker_dest_node != null and is_instance_valid(tracker_dest_node):
		dest = tracker_dest_node.global_position
	var show := dest != Vector2.INF and dest.distance_to(player_pos) > 150.0 and not photo_mode
	tracker_arrow.visible = show
	if show:
		var dir := player_pos.direction_to(dest)
		tracker_arrow.global_position = player_pos + Vector2(0, -20) + dir * 95.0
		tracker_arrow.rotation = dir.angle()
		tracker_arrow.modulate.a = 0.65 + 0.35 * sin(_now() * 6.0)


func _refresh_tracker() -> void:
	var quest_id := _tracked_quest()
	tracker_button.visible = not quest_id.is_empty() and not photo_mode
	tracker_dest = Vector2.INF
	tracker_dest_node = null
	if quest_id.is_empty():
		return
	var qs = main.quest_system
	var quest: Dictionary = qs.quests.get(quest_id, {})
	var lines: Array = []
	var title := str(quest.get("title", quest_id))
	var target_map := ""
	var target_kind := ""
	var target_name := ""
	if qs.is_ready(quest_id):
		var entrega := str(quest.get("entrega", quest.get("npc", "")))
		lines.append("Volte para %s" % entrega.get_slice(",", 0) if entrega == str(quest.get("npc", "")) else "Fale com %s" % entrega.get_slice(",", 0))
		target_kind = "npc"
		target_name = entrega
		target_map = str(main._npc_home_map(target_name))
	else:
		var others_done := true
		for o in quest.get("objectives", []):
			if o.get("type") != "talk" and int(qs.active[quest_id].get(qs._objective_key(o), 0)) < int(o.get("amount", 1)):
				others_done = false
		for o in quest.get("objectives", []):
			var have := int(qs.active[quest_id].get(qs._objective_key(o), 0))
			var need := int(o.get("amount", 1))
			if have >= need:
				continue
			var kind := str(o.get("type", ""))
			var target := str(o.get("target", ""))
			if kind == "talk" and not others_done:
				continue
			var label: String = str(qs.OBJECTIVE_VERBS.get(kind, kind)) + " " + (str(qs.MAP_NAMES.get(target, target)) if kind == "visit" else target.get_slice(",", 0))
			lines.append("%s %d/%d" % [label, have, need] if need > 1 else label)
			if target_kind.is_empty():
				target_kind = kind
				target_name = target
				target_map = _objective_map(kind, target)
	tracker_button.text = "> " + title + "\n  " + "\n  ".join(lines.slice(0, 2))
	if target_map.is_empty():
		return
	var current := str(main.current_map)
	if current == "world_reset":
		current = "forest_boars"
	if target_map != current:
		var next_map := _next_map_toward(current, target_map)
		for portal in main.portal_nodes:
			if is_instance_valid(portal) and str(portal.get_meta("target", "")) == next_map:
				tracker_dest_node = portal
				return
		return
	match target_kind:
		"npc", "talk":
			for npc in get_tree().get_nodes_in_group("npcs"):
				if str(npc.get("npc_name")) == target_name:
					tracker_dest_node = npc
					return
		"kill":
			tracker_dest_node = _nearest(get_tree().get_nodes_in_group("enemies").filter(func(e): return is_instance_valid(e) and str(e.enemy_name) == target_name))
		"collect":
			var candidates: Array = []
			for child in main.world.get_children():
				if child is ItemDrop and str(child.item_name) == target_name:
					candidates.append(child)
			if candidates.is_empty():
				var droppers := _droppers_of(target_name)
				candidates = get_tree().get_nodes_in_group("enemies").filter(func(e): return is_instance_valid(e) and droppers.has(str(e.enemy_name)))
			tracker_dest_node = _nearest(candidates)


func _nearest(nodes: Array) -> Node2D:
	var best: Node2D = null
	var best_d := INF
	var p: Vector2 = main.player.global_position
	for n in nodes:
		var d: float = p.distance_squared_to((n as Node2D).global_position)
		if d < best_d:
			best_d = d
			best = n
	return best


func _droppers_of(item_name: String) -> Array:
	var out: Array = []
	for enemy_name in main.enemies_db:
		for d in main.enemies_db[enemy_name].get("drops", []):
			if str(d.get("item", "")) == item_name:
				out.append(str(enemy_name))
	return out


# em que mapa da para cumprir o objetivo (o mais perto, contando portais)
func _objective_map(kind: String, target: String) -> String:
	var current := str(main.current_map)
	var options: Array = []
	match kind:
		"visit":
			return target
		"talk":
			return str(main._npc_home_map(target))
		"kill":
			for map_id in main.maps:
				for s in main.maps[map_id].get("spawns", []):
					if str(s.get("enemy", "")) == target:
						options.append(str(map_id))
		"collect":
			var droppers := _droppers_of(target)
			for map_id in main.maps:
				for s in main.maps[map_id].get("spawns", []):
					if droppers.has(str(s.get("enemy", ""))):
						options.append(str(map_id))
				for c in main.maps[map_id].get("collectibles", []):
					if typeof(c) == TYPE_DICTIONARY and str(c.get("item", "")) == target:
						options.append(str(map_id))
	var best := ""
	var best_d := 999
	for map_id in options:
		var d := _map_distance(current, map_id)
		if d < best_d:
			best_d = d
			best = map_id
	return best


func _map_links(map_id: String) -> Array:
	var out: Array = []
	for portal in main.maps.get(map_id, {}).get("portals", []):
		out.append(str(portal.get("target", "")))
	return out


func _bfs_parents(start: String) -> Dictionary:
	var parents := {start: ""}
	var queue: Array = [start]
	while not queue.is_empty():
		var m: String = queue.pop_front()
		for n in _map_links(m):
			if not parents.has(n) and main.maps.has(n):
				parents[n] = m
				queue.append(n)
	return parents


func _map_distance(a: String, b: String) -> int:
	var parents := _bfs_parents(a)
	if not parents.has(b):
		return 999
	var d := 0
	var m := b
	while m != a:
		m = parents[m]
		d += 1
	return d


func _next_map_toward(a: String, b: String) -> String:
	var parents := _bfs_parents(a)
	if not parents.has(b):
		return ""
	var m := b
	while str(parents[m]) != a:
		m = parents[m]
	return m


# ======================= 13. barra do chefe + vitoria =======================
var boss_panel: Control
var boss_name_label: Label
var boss_bar: ProgressBar
var boss_tracked: Node2D = null
var boss_timer := 0.0


func _update_boss_bar(delta: float) -> void:
	if boss_panel == null:
		var host: Node = daily_label.get_parent()
		boss_panel = VBoxContainer.new()
		boss_panel.position = Vector2(390, 104)
		boss_panel.size = Vector2(500, 56)
		boss_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		host.add_child(boss_panel)
		boss_name_label = main._panel_label("", 18, Color("#ffd36b"))
		boss_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		boss_name_label.add_theme_color_override("font_outline_color", Color.BLACK)
		boss_name_label.add_theme_constant_override("outline_size", 6)
		boss_panel.add_child(boss_name_label)
		boss_bar = ProgressBar.new()
		boss_bar.custom_minimum_size = Vector2(500, 18)
		boss_bar.show_percentage = false
		var bg := StyleBoxFlat.new()
		bg.bg_color = Color(0.05, 0.02, 0.02, 0.85)
		bg.border_color = Color("#c49b3f")
		bg.set_border_width_all(2)
		bg.set_corner_radius_all(6)
		var fill := StyleBoxFlat.new()
		fill.bg_color = Color("#c8261c")
		fill.set_corner_radius_all(5)
		boss_bar.add_theme_stylebox_override("background", bg)
		boss_bar.add_theme_stylebox_override("fill", fill)
		boss_panel.add_child(boss_bar)
		boss_panel.visible = false
	boss_timer -= delta
	if boss_timer <= 0.0:
		boss_timer = 0.25
		var p: Vector2 = main.player.global_position
		if boss_tracked == null or not is_instance_valid(boss_tracked) or boss_tracked.global_position.distance_to(p) > 900.0:
			boss_tracked = null
			for b in get_tree().get_nodes_in_group("bosses"):
				if is_instance_valid(b) and b.global_position.distance_to(p) < 620.0:
					boss_tracked = b
					break
	var show := boss_tracked != null and is_instance_valid(boss_tracked) and not photo_mode
	boss_panel.visible = show
	if show:
		var e: Enemy = boss_tracked
		boss_name_label.text = "%s  Lv %d%s" % [e.enemy_name, e.level, "  -  FURIA!" if e._is_enraged() else ""]
		boss_bar.max_value = e.vida_max
		boss_bar.value = e.vida


func _victory_banner(enemy_name: String) -> void:
	AudioManager.play_sfx("vitoria", 1.0, 1.0)
	var host: Node = daily_label.get_parent()
	var label := Label.new()
	label.text = "VITORIA!\n%s derrotado" % enemy_name + _record_line(enemy_name)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 46)
	label.add_theme_color_override("font_color", Color("#ffd23f"))
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 12)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.size = Vector2(800, 140)
	label.position = Vector2(240, 200)
	label.pivot_offset = Vector2(400, 70)
	label.scale = Vector2(0.6, 0.6)
	host.add_child(label)
	var tween := label.create_tween()
	tween.tween_property(label, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_interval(2.2)
	tween.tween_property(label, "modulate:a", 0.0, 0.5)
	tween.tween_callback(label.queue_free)


# ======================= 14. bloco 2: esquiva, morte, trofeus, chefes de evento =======================
var dodge_button: Button


func _update_dodge_button() -> void:
	var player: Player = main.player
	if dodge_button == null:
		dodge_button = _hud_button(Vector2(752, 616), Vector2(108, 58), func() -> void:
			if main.player.start_dodge():
				AudioManager.play_sfx("abrir", 0.8, 0.1)
			elif main.player.dodge_cooldown <= 0.0:
				main._flash_red("Sem mana para esquivar")
		)
		dodge_button.add_theme_font_size_override("font_size", 16)
		var round_style := StyleBoxFlat.new()
		round_style.bg_color = Color(0.08, 0.1, 0.16, 0.85)
		round_style.border_color = Color("#7fc8ff")
		round_style.set_border_width_all(2)
		round_style.set_corner_radius_all(29)
		for state in ["normal", "hover", "pressed", "disabled", "focus"]:
			dodge_button.add_theme_stylebox_override(state, round_style)
	dodge_button.visible = not photo_mode
	if player.dodge_cooldown > 0.0:
		dodge_button.text = "%.1f" % player.dodge_cooldown
		dodge_button.modulate = Color(1, 1, 1, 0.55)
	else:
		dodge_button.text = "ESQUIVA"
		dodge_button.modulate = Color.WHITE


func show_death(killer: Dictionary) -> void:
	var golpe := str(killer.get("golpe", ""))
	var de := str(killer.get("de", ""))
	var tips: Dictionary = main._rule(["dicas_morte"], {})
	var list: Variant = tips.get(golpe, tips.get("inimigo_comum", []))
	var tip := ""
	if typeof(list) == TYPE_ARRAY and not (list as Array).is_empty():
		tip = str(list[randi() % (list as Array).size()])
	var box: VBoxContainer = main._start_modal("Voce foi derrotado", "death")
	var what := ""
	match golpe:
		"":
			what = "Voce caiu em combate."
		"veneno":
			what = "O veneno acabou com voce" + (" (de %s)." % de if not de.is_empty() else ".")
		"inimigo_comum", "chefe_corpo_a_corpo":
			what = "Derrotado por: %s" % de
		_:
			what = "Derrotado por: %s de %s" % [golpe, de]
	box.add_child(main._panel_label(what, 20, Color("#ff8a7a")))
	if not tip.is_empty():
		var tip_label: Label = main._panel_label("Dica: " + tip, 17, Color("#ffe7a3"))
		tip_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		tip_label.custom_minimum_size = Vector2(560, 0)
		box.add_child(tip_label)
	if golpe != "" and golpe != "inimigo_comum" and golpe != "veneno":
		box.add_child(main._panel_label("Lembre: ESPACO (ou o botao ESQUIVA) rola para fora do golpe.", 14, Color("#b8c6d8")))
	box.add_child(main._panel_label("Voce perdeu 5% do ouro e voltou para a cidade.", 14, Color("#b8c6d8")))


func _give_trophy_first_kill(boss_name: String) -> void:
	var trophies: Dictionary = main._rule(["trofeus"], {})
	if not trophies.has(boss_name):
		return
	var got: Dictionary = _cache().get("trofeus", {})
	if got.has(boss_name):
		return
	var item_name := str(trophies[boss_name])
	got[boss_name] = true
	_cache()["trofeus"] = got
	main.player.inventory.add_item(item_name)
	main._flash("TROFEU! %s foi para a sua bolsa." % item_name)
	AudioManager.play_sfx("item", 1.0, 0.1)


var event_boss_next: Dictionary = {}
var event_boss_alive: Node2D = null
var event_boss_name := ""
var event_boss_until := 0.0
var event_boss_check := 0.0


func _update_event_bosses(delta: float) -> void:
	event_boss_check -= delta
	if event_boss_check > 0.0:
		return
	event_boss_check = 2.0
	var now := _now()
	if event_boss_alive != null:
		if not is_instance_valid(event_boss_alive):
			event_boss_alive = null
		elif now > event_boss_until or str(event_boss_alive.get_meta("spawn_map", "")) != str(main.current_map):
			event_boss_alive.queue_free()
			event_boss_alive = null
			main._flash("%s foi embora..." % event_boss_name)
		return
	var cfg: Dictionary = main._rule(["chefes_evento"], {})
	for boss_name in cfg:
		var c: Dictionary = cfg[boss_name]
		if not event_boss_next.has(boss_name):
			event_boss_next[boss_name] = now + randf_range(float(c.get("intervalo_min_s", 2700)), float(c.get("intervalo_max_s", 4500)))
		if now < float(event_boss_next[boss_name]):
			continue
		if str(main.current_map) != str(c.get("mapa", "")) or main.player.level < int(c.get("nivel_minimo_jogador", 1)):
			continue
		if spawn_event_boss(str(boss_name)):
			event_boss_next[boss_name] = now + randf_range(float(c.get("intervalo_min_s", 2700)), float(c.get("intervalo_max_s", 4500)))
			return


# tambem usado para testar: game_extras.spawn_event_boss("Tita de Cristal")
func spawn_event_boss(boss_name: String) -> bool:
	var c: Dictionary = main._rule(["chefes_evento", boss_name], {})
	var p: Vector2 = main.player.global_position
	for _i in 12:
		var pos := p + Vector2.from_angle(randf() * TAU) * randf_range(420.0, 560.0)
		var boss: Variant = main._spawn_event_boss(boss_name, pos)
		if boss != null:
			event_boss_alive = boss
			event_boss_name = boss_name
			event_boss_until = _now() + float(c.get("dura_s", 600))
			var banner := str(c.get("anuncio", "%s apareceu!" % boss_name))
			main._flash(banner)
			_big_banner(banner, Color("#ff7a4a"))
			AudioManager.play_sfx("chefe_aviso", 1.0, 0.5)
			return true
	return false


func _event_boss_reward(boss_name: String) -> void:
	if boss_name != event_boss_name:
		return
	var c: Dictionary = main._rule(["chefes_evento", boss_name], {})
	var data: Dictionary = main.enemies_db.get(boss_name, {})
	var xp := int(float(data.get("xp", 100)) * (float(c.get("bonus_xp_mult", 1.0)) - 1.0))
	var ouro_data: Variant = data.get("ouro", 50)
	var gold_base := (float(ouro_data[0]) + float(ouro_data[1])) * 0.5 if typeof(ouro_data) == TYPE_ARRAY else float(ouro_data)
	var gold := int(gold_base * (float(c.get("bonus_ouro_mult", 1.0)) - 1.0))
	if xp > 0:
		main.player.gain_xp(xp)
	if gold > 0:
		main.player.ouro += gold
	main._flash("Bonus do evento: +%d XP e +%d ouro!" % [xp, gold])
	event_boss_name = ""


func _big_banner(text: String, color: Color) -> void:
	var host: Node = daily_label.get_parent()
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 30)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 10)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.size = Vector2(900, 100)
	label.position = Vector2(190, 170)
	host.add_child(label)
	var tween := label.create_tween()
	tween.tween_interval(3.0)
	tween.tween_property(label, "modulate:a", 0.0, 0.6)
	tween.tween_callback(label.queue_free)


# ======================= 15. bloco 3: talentos =======================
func _branch_spent(player: Player, branch: Dictionary) -> int:
	var n := 0
	for t in branch.get("talentos", []):
		n += int(player.talents.get(str(t.get("id", "")), 0))
	return n


func show_talents() -> void:
	var player: Player = main.player
	var box: VBoxContainer = main._start_modal("Talentos - %s" % player.class_name_selected, "talents")
	if player.talent_tree.is_empty():
		box.add_child(main._panel_label("Sua classe ainda nao tem talentos.", 16, Color.WHITE))
		return
	var free := player.talent_points_total() - player.talent_points_spent()
	var head := HBoxContainer.new()
	box.add_child(head)
	head.add_child(main._panel_label("Pontos livres: %d   (1 ponto por nivel)" % free, 18, Color("#ffd36b")))
	var spent := player.talent_points_spent()
	if spent > 0:
		var cost := spent * int(main._rule(["talentos_resetar_ouro_por_ponto"], 25))
		var reset := Button.new()
		reset.text = "Refazer (%d ouro)" % cost
		main._style_panel_button(reset)
		reset.pressed.connect(func() -> void:
			if player.ouro < cost:
				main._flash_red("Ouro insuficiente para refazer os talentos.")
				return
			player.ouro -= cost
			player.talents.clear()
			player.recalculate_equipment()
			player.stats_changed.emit()
			show_talents()
		)
		head.add_child(reset)
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 10)
	box.add_child(cols)
	for branch in player.talent_tree:
		var col := VBoxContainer.new()
		col.custom_minimum_size = Vector2(280, 0)
		cols.add_child(col)
		var color := Color(str(branch.get("cor", "#ffd36b")))
		var in_branch := _branch_spent(player, branch)
		col.add_child(main._panel_label("%s  (%d)" % [str(branch.get("nome", "")), in_branch], 18, color))
		for t in branch.get("talentos", []):
			var tid := str(t.get("id", ""))
			var rank := int(player.talents.get(tid, 0))
			var mx := int(t.get("max", 3))
			var need := int(t.get("requer_pontos_no_ramo", 0))
			var locked := in_branch < need
			var row := HBoxContainer.new()
			col.add_child(row)
			var info := VBoxContainer.new()
			info.custom_minimum_size = Vector2(220, 0)
			row.add_child(info)
			var name_label: Label = main._panel_label("%s  %d/%d" % [str(t.get("nome", tid)), rank, mx], 15, Color("#8a93a0") if locked else Color.WHITE)
			info.add_child(name_label)
			var desc := str(t.get("descricao", ""))
			var values := _talent_values(t, maxi(rank, 1))
			if desc.count("%s") == values.size():
				desc = desc % values
			else:
				desc = desc.replace("%s", " / ".join(values))
			if locked:
				desc = "Libera com %d pontos neste ramo" % need
			var desc_label: Label = main._panel_label(desc, 12, Color("#b8c6d8"))
			desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			desc_label.custom_minimum_size = Vector2(215, 0)
			info.add_child(desc_label)
			var plus := Button.new()
			plus.text = "+"
			plus.custom_minimum_size = Vector2(46, 40)
			main._style_panel_button(plus)
			plus.disabled = locked or rank >= mx or free <= 0
			plus.pressed.connect(func() -> void:
				player.talents[tid] = rank + 1
				player.recalculate_equipment()
				player.stats_changed.emit()
				AudioManager.play_sfx("item", 0.8, 0.05)
				show_talents()
			)
			row.add_child(plus)


func _talent_values(t: Dictionary, rank: int) -> Array:
	var parts: Array = []
	var bonus: Dictionary = t.get("bonus_por_nivel", {})
	for stat in bonus:
		var v := float(bonus[stat]) * rank
		if str(stat).ends_with("_pct"):
			parts.append("%d%%" % int(round(v * 100.0)))
		else:
			parts.append("%d" % int(v))
	return parts


# ======================= 16. bloco 3: equipamento aparece no heroi (aura por raridade) =======================
# O desenho do heroi ainda nao troca por peca (precisaria de arte de cada conjunto em cada classe);
# por enquanto o melhor item equipado da uma aura no chao com a cor da raridade.
const RARITY_ORDER := ["common", "uncommon", "rare", "super_rare", "epic", "legendary", "mega_legendary", "god"]
const RARITY_COLORS := {"rare": Color("#4aa3ff"), "super_rare": Color("#38e0d0"), "epic": Color("#b061ff"),
	"legendary": Color("#ff9a2e"), "mega_legendary": Color("#ff4a4a"), "god": Color("#fff27a")}
var gear_aura: Polygon2D
var gear_aura_check := 0.0
var gear_aura_rarity := ""


func _update_gear_aura(delta: float) -> void:
	var player: Player = main.player
	if gear_aura == null or not is_instance_valid(gear_aura) or gear_aura.get_parent() != player:
		gear_aura = Polygon2D.new()
		var pts := PackedVector2Array()
		for i in 28:
			var ang := TAU * float(i) / 28.0
			pts.append(Vector2(cos(ang) * 38.0, sin(ang) * 13.0))
		gear_aura.polygon = pts
		gear_aura.position = Vector2(0, 20)
		var ring := Line2D.new()
		ring.name = "Ring"
		pts.append(pts[0])
		ring.points = pts
		ring.width = 3.0
		gear_aura.add_child(ring)
		gear_aura.z_index = -1
		gear_aura.visible = false
		player.add_child(gear_aura)
		gear_aura_rarity = ""
	gear_aura_check -= delta
	if gear_aura_check <= 0.0:
		gear_aura_check = 1.0
		var best := -1
		for item_name in player.inventory.equipment.values():
			if str(item_name).is_empty():
				continue
			var r := RARITY_ORDER.find(str(main.item_db.get_item(str(item_name)).get("rarity", "common")))
			best = maxi(best, r)
		gear_aura_rarity = RARITY_ORDER[best] if best >= 0 else ""
	var color: Variant = RARITY_COLORS.get(gear_aura_rarity, null)
	gear_aura.visible = color != null and str(main._current_equipped_mount_code()).is_empty()
	if gear_aura.visible:
		var c: Color = color
		var pulse := 0.5 + 0.5 * sin(_now() * 3.0)
		gear_aura.color = Color(c.r, c.g, c.b, 0.35 + 0.2 * pulse)
		(gear_aura.get_node("Ring") as Line2D).default_color = Color(c.r, c.g, c.b, 0.7 + 0.3 * pulse)


# ======================= 17. bloco 4: recorde de tempo contra cada chefe =======================
# O cronometro comeca no primeiro dano do heroi no chefe (enemy.gd: meta luta_inicio_ms).
var last_boss_fight_s := -1.0


func note_boss_fight(enemy: Node) -> void:
	last_boss_fight_s = -1.0
	if enemy != null and is_instance_valid(enemy) and enemy.has_meta("luta_inicio_ms"):
		last_boss_fight_s = float(Time.get_ticks_msec() - int(enemy.get_meta("luta_inicio_ms"))) / 1000.0


func _record_line(boss_name: String) -> String:
	if last_boss_fight_s <= 0.0:
		return ""
	var secs := last_boss_fight_s
	last_boss_fight_s = -1.0
	var records: Dictionary = _cache().get("recordes_chefes", {})
	var best := float(records.get(boss_name, 0.0))
	if best <= 0.0 or secs < best:
		records[boss_name] = snappedf(secs, 0.1)
		_cache()["recordes_chefes"] = records
		return "\nNOVO RECORDE: %s" % _fmt_time(secs)
	return "\nTempo: %s  (recorde %s)" % [_fmt_time(secs), _fmt_time(best)]


func _fmt_time(secs: float) -> String:
	var s := int(round(secs))
	return "%d:%02d" % [s / 60, s % 60] if s >= 60 else "%d s" % s


func show_records() -> void:
	var box: VBoxContainer = main._start_modal("Recordes contra chefes", "records")
	var records: Dictionary = _cache().get("recordes_chefes", {})
	box.add_child(main._panel_label("Seu menor tempo para derrotar cada chefe (desde o primeiro golpe).", 15, Color("#b8c6d8")))
	var names: Array = main._rule(["trofeus"], {}).keys()
	for boss_name in names:
		var t := float(records.get(boss_name, 0.0))
		var txt := "%s:  %s" % [boss_name, _fmt_time(t) if t > 0.0 else "ainda nao venceu"]
		box.add_child(main._panel_label(txt, 18, Color("#ffd36b") if t > 0.0 else Color("#8a93a0")))
	box.add_child(main._panel_label("Desafie quem assiste: poste o print do seu recorde!", 14, Color("#b8c6d8")))
