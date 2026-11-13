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

func _pedestrian_frames() -> SpriteFrames:
	for state in main.kit_vehicles:
		if bool(state.get("flying", false)):
			continue
		var sprite := state.get("node") as AnimatedSprite2D
		if sprite != null and is_instance_valid(sprite) and sprite.sprite_frames != null:
			var w := float(main._kit_vehicle_rect(state, sprite.position).size.x)
			if w < 80.0:  # pedestre, nao carroca
				thief_offsets = state.get("offsets", {})
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
