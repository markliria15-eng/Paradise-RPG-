extends Node2D

# Orquestra o MVP: carrega dados, troca mapas, conecta combate, UI, drops,
# missoes e save sem esconder numeros de balanceamento dentro do codigo.
const PLAYER_SCENE := preload("res://scenes/player.tscn")
const ENEMY_SCENE := preload("res://scenes/enemy.tscn")
const NPC_SCENE := preload("res://scenes/npc.tscn")
const DROP_SCENE := preload("res://scenes/item_drop.tscn")
const POTION_SLOTS := [
	{"item": "Pocao pequena de vida", "label": "HP P", "icon": "res://assets/sprites/icon_potion_health_small.png"},
	{"item": "Pocao media de vida", "label": "HP M", "icon": "res://assets/sprites/icon_potion_health_medium.png"},
	{"item": "Pocao pequena de mana", "label": "MP P", "icon": "res://assets/sprites/icon_potion_mana_small.png"},
	{"item": "Pocao media de mana", "label": "MP M", "icon": "res://assets/sprites/icon_potion_mana_medium.png"}
]
const POTION_BUTTON_POSITIONS := [
	Vector2(862, 522),
	Vector2(936, 464),
	Vector2(1010, 406),
	Vector2(1084, 348)
]
const DEFAULT_MAP_SIZE := Vector2(2200, 1400)
const DROP_PICKUP_RADIUS := 128.0
const DROP_COLLECT_RADIUS := 24.0
const DROP_MAGNET_SPEED := 460.0
const SAFE_ZONE_REGEN := 5
const BEGINNER_QUESTS := ["tutorial_forest", "tutorial_ruins", "tutorial_cave"]
const ATTACK_ICON_BY_CLASS := {
	"Guerreiro": "res://assets/sprites/icon_attack_sword.png",
	"Mago": "res://assets/sprites/icon_attack_book.png",
	"Arqueiro": "res://assets/sprites/icon_attack_bow.png"
}
const SKILL_ICON_BY_ID := {
	"heavy_slash": "res://assets/sprites/icon_skill_heavy_slash.png",
	"war_cry": "res://assets/sprites/icon_skill_war_cry.png",
	"blade_spin": "res://assets/sprites/icon_skill_blade_spin.png",
	"fireball": "res://assets/sprites/icon_skill_fireball.png",
	"arcane_blast": "res://assets/sprites/icon_skill_arcane_blast.png",
	"mystic_shield": "res://assets/sprites/icon_skill_mystic_shield.png",
	"precise_shot": "res://assets/sprites/icon_skill_precise_shot.png",
	"arrow_rain": "res://assets/sprites/icon_skill_arrow_rain.png",
	"quick_jump": "res://assets/sprites/icon_skill_quick_jump.png",
	"death_area": "res://assets/sprites/icon_skill_death_area.png",
	"hero_hour": "res://assets/sprites/icon_skill_hero_hour.png",
	"soul_reaper": "res://assets/sprites/icon_skill_soul_reaper.png",
	"blue_meteor": "res://assets/sprites/icon_skill_blue_meteor.png",
	"burning_fireball": "res://assets/sprites/icon_skill_burning_fireball.png",
	"fire_hurricane": "res://assets/sprites/icon_skill_fire_hurricane.png",
	"agility": "res://assets/sprites/icon_skill_agility.png",
	"stun_shot": "res://assets/sprites/icon_skill_stun_shot.png"
}
const SIDE_MENU_ICONS := {
	"Batalha": "res://assets/sprites/icon_skill_heavy_slash.png",
	"Habilidades": "res://assets/sprites/icon_attack_sword.png",
	"Equipar": "res://assets/sprites/icon_slot_armor.png",
	"Roupa": "res://assets/sprites/icon_slot_helmet.png",
	"Bolsa": "res://assets/sprites/icon_slot_backpack.png",
	"Banco": "res://assets/sprites/drop_coin.png",
	"Mapa": "res://assets/sprites/decor_portal.png",
	"Shop": "res://assets/sprites/drop_coin.png",
	"Party": "res://assets/sprites/icon_slot_amulet.png",
	"Guild": "res://assets/sprites/icon_slot_shield.png",
	"Rank": "res://assets/sprites/drop_gem.png",
	"Missoes": "res://assets/sprites/drop_material.png",
	"Profissoes": "res://assets/sprites/drop_ore.png",
	"Crafting": "res://assets/sprites/npc_forge.png",
	"Pets": "res://assets/sprites/enemy_lobo.png",
	"Montarias": "res://assets/sprites/enemy_javali.png",
	"Dungeon": "res://assets/sprites/tile_cave.png",
	"Mercado": "res://assets/sprites/drop_bag.png",
	"Conquistas": "res://assets/sprites/drop_gem.png",
	"Temporada": "res://assets/sprites/icon_skill_arcane_blast.png",
	"VIP": "res://assets/sprites/icon_slot_jewel.png",
	"Wikipedia": "res://assets/sprites/icon_attack_book.png",
	"Zoom": "res://assets/sprites/icon_slot_ring.png",
	"Fechar": "res://assets/sprites/icon_menu_close.png"
}
const RANK_KEYS := {
	"Level": "top_level",
	"Ouro": "top_gold",
	"Lutando": "top_fighting",
	"Magica": "top_magic",
	"Distancia": "top_distance",
	"Protecao": "top_protection"
}
const MINIMAP_SIZE := Vector2(166, 122)
const EXPLORATION_CELL := 48

@onready var world: Node2D = $World
@onready var ui: CanvasLayer = $UI
@onready var item_db: ItemDatabase = $ItemDatabase
@onready var class_db: ClassDatabase = $ClassDatabase
@onready var drop_system: DropSystem = $DropSystem

var maps: Dictionary = {}
var enemies_db: Dictionary = {}
var quest_system := QuestSystem.new()
var player: Player
var current_map := "city_eldoria"
var hud_label: Label
var xp_label: Label
var xp_bar: ProgressBar
var hp_bar: ProgressBar
var mana_bar: ProgressBar
var mana_label: Label
var hp_label: Label
var xp_value_label: Label
var message_label: Label
var panel: PanelContainer
var panel_blocker: ColorRect
var input_guard: ColorRect
var side_menu_panel: PanelContainer
var side_menu_toggle_button: Button
var side_menu_visible := false
var selected_npc: Npc
var selected_portal: Area2D
var current_target: Enemy
var regen_timer := 0.0
var current_map_size := DEFAULT_MAP_SIZE
var touch_buttons: Array[Button] = []
var attack_button: Button
var skill_buttons: Array[Button] = []
var interact_button: Button
var inventory_button: Button
var character_button: Button
var quests_button: Button
var potion_buttons: Dictionary = {}
var touch_move_index := -1
var touch_move_center := Vector2(132, 586)
var touch_move_radius := 72.0
var joystick_base: TextureRect
var joystick_knob: TextureRect
var current_panel := ""
var safe_zone_nodes: Array[Dictionary] = []
var player_camera: Camera2D
var mmo_client: Node
var online_mode := false
var remote_players: Dictionary = {}
var net_move_accumulator := 0.0
var online_save_accumulator := 0.0
var mmo_cache: Dictionary = {}
var ui_input_lock_until := 0.0
var ui_controls_enabled := true
var minimap_panel: PanelContainer
var minimap_canvas: Control
var exploration_by_map: Dictionary = {}
var exploration_last_pos_by_map: Dictionary = {}
var pet_definitions: Array = []
var mount_definitions: Array = []
var pet_follower: Sprite2D
var mount_follower: Sprite2D
var pet_attack_timer := 0.0
var pet_allowed_target: Enemy
var companion_anim_time := 0.0
var dialog_bubble: PanelContainer
var solid_obstacles: Array[Rect2] = []
var last_valid_player_position := Vector2.ZERO

func _ready() -> void:
	randomize()
	maps = ItemDatabase.load_json("res://data/maps.json")
	enemies_db = ItemDatabase.load_json("res://data/enemies.json")
	pet_definitions = _load_json_array("res://data/mmo_pets.json")
	mount_definitions = _load_json_array("res://data/mmo_mounts.json")
	quest_system.load_quests()
	_build_ui()
	_setup_mmo_integration()
	if online_mode:
		_start_online_game_from_session()
		return
	var save := SaveSystem.load_game()
	if save.is_empty():
		_show_class_selection()
	else:
		_spawn_player_from_save(save)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_SIZE_CHANGED:
		_refresh_modal_layout()

func _process(delta: float) -> void:
	if player == null:
		return
	_enforce_world_collision()
	regen_timer += delta
	if regen_timer >= 1.0:
		regen_timer = 0
		_apply_map_regen()
	_update_safe_zone_state()
	_update_map_exploration()
	_update_current_target()
	_collect_nearby_drops(delta)
	_update_minimap()
	_update_companion_visuals(delta)
	_update_pet_combat(delta)
	_update_hud()
	if online_mode and mmo_client != null:
		net_move_accumulator += delta
		if net_move_accumulator >= 0.12:
			net_move_accumulator = 0.0
			mmo_client.call("send_move", current_map, player.global_position)
		online_save_accumulator += delta
		if online_save_accumulator >= 8.0:
			online_save_accumulator = 0.0
			_send_online_save_state()

func _unhandled_input(event: InputEvent) -> void:
	if player == null:
		return
	if event.is_action_pressed("inventory"):
		_show_inventory()
	elif event.is_action_pressed("character"):
		_show_character()
	elif event.is_action_pressed("quests"):
		_show_quests()
	elif event.is_action_pressed("interact"):
		_interact()
	elif event.is_action_pressed("save_game"):
		if online_mode:
			_send_online_save_state()
			_flash("Modo online: progresso enviado ao servidor.")
		else:
			SaveSystem.save_game(player, quest_system, current_map, exploration_by_map, mmo_cache)
			_flash("Jogo salvo.")

func _input(event: InputEvent) -> void:
	if player == null:
		return
	if _is_ui_locked():
		return
	if panel.visible:
		return
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed and _is_touch_blocked_by_panel(touch.position):
			return
		if touch.pressed:
			if _is_move_touch(touch.position):
				touch_move_index = touch.index
				_update_touch_move(touch.position)
		elif touch.index == touch_move_index:
			_release_touch_move()
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if panel.visible and _is_touch_blocked_by_panel(drag.position):
			return
		if drag.index == touch_move_index:
			_update_touch_move(drag.position)

func _is_ui_locked() -> bool:
	return Time.get_ticks_msec() < int(ui_input_lock_until * 1000.0)

func _is_touch_blocked_by_panel(pos: Vector2) -> bool:
	if not panel.visible:
		return false
	return Rect2(panel.position, panel.size).has_point(pos)

func _setup_mmo_integration() -> void:
	mmo_client = get_node_or_null("/root/MMOClient")
	if mmo_client == null:
		online_mode = false
		return
	online_mode = bool(mmo_client.get("online_enabled")) and not str(mmo_client.get("token")).is_empty()
	if not online_mode:
		return
	if not mmo_client.is_connected("world_message", Callable(self, "_on_mmo_world_message")):
		mmo_client.connect("world_message", Callable(self, "_on_mmo_world_message"))
	_flash("Modo MMO online ativo.")

func _start_online_game_from_session() -> void:
	if mmo_client == null:
		_show_class_selection()
		return
	var payload: Dictionary = mmo_client.get("account_payload")
	var character := _pick_online_character(payload)
	if character.is_empty():
		_flash("Nenhum personagem online selecionado, abrindo modo offline.")
		online_mode = false
		_show_class_selection()
		return
	var class_id := str(character.get("class", "Guerreiro"))
	player = PLAYER_SCENE.instantiate()
	world.add_child(player)
	player.setup(class_id, class_db.get_class_data(class_id), item_db)
	player.character_name = str(character.get("name", "Aventureiro"))
	player.set_meta("character_id", int(character.get("id", 0)))
	player.level = int(character.get("level", 1))
	player.xp = int(character.get("xp", 0))
	player.ouro = int(character.get("gold", 0))
	player.vida = int(character.get("hp", player.vida_max))
	player.mana = int(character.get("mana", player.mana_max))
	if character.has("skills") and typeof(character["skills"]) == TYPE_DICTIONARY:
		player.skills = character["skills"]
		_normalize_player_skills()
	player.recalculate_equipment()
	_connect_player()
	_update_action_icons()
	var map_id := str(character.get("map", "city_eldoria"))
	var spawn := Vector2(float(character.get("pos_x", 1080.0)), float(character.get("pos_y", 760.0)))
	_load_map(map_id, spawn)
	flash_online_help()

func flash_online_help() -> void:
	_flash("Online conectado. Outros jogadores serao sincronizados automaticamente.")

func _send_online_save_state() -> void:
	if not online_mode or mmo_client == null or player == null:
		return
	mmo_client.call("send_character_save", {
		"level": player.level,
		"xp": player.xp,
		"hp": player.vida,
		"mana": player.mana,
		"gold": player.ouro,
		"map": current_map,
		"pos": {"x": player.global_position.x, "y": player.global_position.y},
		"skills": player.skills
	})

func _normalize_player_skills() -> void:
	if player == null:
		return
	var defaults := SkillProgressionSystem.default_skills()
	for skill_id in defaults.keys():
		var base: Dictionary = defaults[skill_id]
		var current: Dictionary = player.skills.get(skill_id, {})
		current["name"] = str(current.get("name", base.get("name", skill_id)))
		current["level"] = int(current.get("level", base.get("level", 10)))
		current["xp"] = int(current.get("xp", base.get("xp", 0)))
		current["xp_required"] = SkillProgressionSystem.xp_required(int(current["level"]))
		player.skills[skill_id] = current

func _pick_online_character(payload: Dictionary) -> Dictionary:
	var selected_id := int(mmo_client.get("selected_character_id"))
	var chars: Array = payload.get("characters", [])
	for ch in chars:
		if typeof(ch) == TYPE_DICTIONARY and int(ch.get("id", 0)) == selected_id:
			return ch
	if payload.has("character") and typeof(payload["character"]) == TYPE_DICTIONARY:
		return payload["character"]
	if not chars.is_empty() and typeof(chars[0]) == TYPE_DICTIONARY:
		return chars[0]
	return {}

func _load_json_array(path: String) -> Array:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return []
	var parsed = JSON.parse_string(file.get_as_text())
	return parsed if typeof(parsed) == TYPE_ARRAY else []

func _ensure_local_companion_state() -> void:
	if online_mode:
		return
	if not mmo_cache.has("pets_state") or typeof(mmo_cache.get("pets_state")) != TYPE_DICTIONARY:
		mmo_cache["pets_state"] = {"pets": []}
	if not mmo_cache.has("mounts_state") or typeof(mmo_cache.get("mounts_state")) != TYPE_DICTIONARY:
		mmo_cache["mounts_state"] = {"mounts": []}

func _definition_by_code(definitions: Array, code: String) -> Dictionary:
	for entry in definitions:
		if typeof(entry) == TYPE_DICTIONARY and str(entry.get("code", "")) == code:
			return entry
	return {}

func _owned_entry(state_key: String, list_key: String, code: String) -> Dictionary:
	var payload: Dictionary = mmo_cache.get(state_key, {})
	for entry in payload.get(list_key, []):
		if typeof(entry) == TYPE_DICTIONARY and str(entry.get("code", "")) == code:
			return entry
	return {}

func _buy_local_pet(code: String) -> bool:
	_ensure_local_companion_state()
	if not _owned_entry("pets_state", "pets", code).is_empty():
		_equip_local_pet(code)
		return true
	var def := _definition_by_code(pet_definitions, code)
	if def.is_empty():
		return false
	var price := int(def.get("price", 0))
	if player.ouro < price:
		return false
	player.ouro -= price
	var payload: Dictionary = mmo_cache["pets_state"]
	var owned: Array = payload.get("pets", [])
	owned.append({"id": owned.size() + 1, "code": code, "level": 1, "xp": 0, "equipped": owned.is_empty()})
	payload["pets"] = owned
	mmo_cache["pets_state"] = payload
	_apply_companion_bonuses()
	return true

func _equip_local_pet(code: String) -> void:
	_ensure_local_companion_state()
	var payload: Dictionary = mmo_cache["pets_state"]
	var owned: Array = payload.get("pets", [])
	for i in range(owned.size()):
		if typeof(owned[i]) == TYPE_DICTIONARY:
			owned[i]["equipped"] = str(owned[i].get("code", "")) == code
	payload["pets"] = owned
	mmo_cache["pets_state"] = payload
	pet_attack_timer = 0.0
	_apply_companion_bonuses()

func _buy_local_mount(code: String) -> bool:
	_ensure_local_companion_state()
	if not _owned_entry("mounts_state", "mounts", code).is_empty():
		_equip_local_mount(code)
		return true
	var def := _definition_by_code(mount_definitions, code)
	if def.is_empty():
		return false
	var price := int(def.get("price", 0))
	if player.ouro < price:
		return false
	player.ouro -= price
	var payload: Dictionary = mmo_cache["mounts_state"]
	var owned: Array = payload.get("mounts", [])
	owned.append({"id": owned.size() + 1, "code": code, "equipped": owned.is_empty()})
	payload["mounts"] = owned
	mmo_cache["mounts_state"] = payload
	_apply_companion_bonuses()
	return true

func _equip_local_mount(code: String) -> void:
	_ensure_local_companion_state()
	var payload: Dictionary = mmo_cache["mounts_state"]
	var owned: Array = payload.get("mounts", [])
	for i in range(owned.size()):
		if typeof(owned[i]) == TYPE_DICTIONARY:
			owned[i]["equipped"] = str(owned[i].get("code", "")) == code
	payload["mounts"] = owned
	mmo_cache["mounts_state"] = payload
	_apply_companion_bonuses()

func _dismount_current_mount(reason: String = "") -> void:
	var code := _current_equipped_mount_code()
	if code.is_empty():
		return
	var payload: Dictionary = mmo_cache.get("mounts_state", {})
	var owned: Array = payload.get("mounts", [])
	for i in range(owned.size()):
		if typeof(owned[i]) == TYPE_DICTIONARY:
			owned[i]["equipped"] = false
	payload["mounts"] = owned
	mmo_cache["mounts_state"] = payload
	_apply_companion_bonuses()
	if not reason.is_empty():
		_flash(reason)

func _apply_companion_bonuses() -> void:
	if player == null:
		return
	player.companion_physical_damage_pct = 0.0
	player.companion_mana_regen_pct = 0.0
	player.companion_attack_speed_pct = 0.0
	player.companion_move_speed_pct = 0.0
	player.companion_vida_max_pct = 0.0
	var pet_def := _definition_by_code(pet_definitions, _current_equipped_pet_code())
	var pet_bonus: Dictionary = pet_def.get("base_bonus", {})
	player.companion_physical_damage_pct += float(pet_bonus.get("physical_attack_pct", 0.0))
	player.companion_physical_damage_pct += float(pet_bonus.get("magic_damage_pct", 0.0))
	player.companion_mana_regen_pct += float(pet_bonus.get("mana_regen_pct", 0.0))
	player.companion_attack_speed_pct += float(pet_bonus.get("attack_speed_pct", 0.0))
	player.companion_vida_max_pct += float(pet_bonus.get("max_hp_pct", 0.0))
	player.companion_move_speed_pct += float(pet_bonus.get("move_speed_pct", 0.0))
	var mount_def := _definition_by_code(mount_definitions, _current_equipped_mount_code())
	player.companion_move_speed_pct += float(mount_def.get("speed_bonus", 0.0))
	player.recalculate_equipment()

func _on_mmo_world_message(payload: Dictionary) -> void:
	var msg_type := str(payload.get("type", ""))
	match msg_type:
		"world_snapshot":
			_apply_online_snapshot(payload.get("players", []))
		"player_joined":
			_spawn_or_update_remote(payload.get("player", {}))
		"player_left":
			_remove_remote_player(int(payload.get("characterId", 0)))
		"entity_hp_sync":
			_update_remote_hp(int(payload.get("characterId", 0)), int(payload.get("hp", 0)))
		"chat_message":
			_flash("[%s] %s: %s" % [str(payload.get("channel", "global")), str(payload.get("from", "?")), str(payload.get("text", ""))])
		"system_event":
			_flash(str(payload.get("text", "Evento global.")))
		"professions_state", "crafting_recipes", "pets_state", "mounts_state", "dungeons_state", "rank_state", "market_state", "vip_state", "achievements_state", "season_state":
			mmo_cache[msg_type] = payload
			_refresh_mmo_panel_from_cache(msg_type)
		"crafting_result":
			var success: bool = bool(payload.get("success", false))
			_flash("Crafting: %s" % ("Sucesso!" if success else "Falhou."))
			if current_panel == "crafting":
				_show_crafting_window(true)
		"market_buy_result":
			_flash("Mercado: compra concluida.")
			if current_panel == "market":
				if mmo_client != null:
					mmo_client.call("request_market")
		"market_listing_created":
			_flash("Mercado: item anunciado.")
			if current_panel == "market":
				if mmo_client != null:
					mmo_client.call("request_market")
		"character_saved":
			if bool(payload.get("ok", false)):
				_flash("Progresso online salvo.")
		"dungeon_started":
			_flash("Dungeon iniciada: %s" % str(payload.get("dungeon", {}).get("name", "instancia")))
		"error":
			_flash("Online: " + str(payload.get("message", "erro")))
		"pvp_damage_taken":
			if player != null:
				var dmg := int(payload.get("damage", 0))
				player.receive_damage(dmg)
		_:
			pass

func _refresh_mmo_panel_from_cache(msg_type: String) -> void:
	match msg_type:
		"professions_state":
			if current_panel == "professions":
				_show_professions(true)
		"crafting_recipes":
			if current_panel == "crafting":
				_show_crafting_window(true)
		"pets_state":
			if current_panel == "pets":
				_show_pets(true)
		"mounts_state":
			if current_panel == "mounts":
				_show_mounts(true)
		"dungeons_state":
			if current_panel == "dungeons":
				_show_dungeons(true)
		"rank_state":
			if current_panel == "rank":
				_show_rank(true)
		"market_state":
			if current_panel == "market":
				_show_market(true)
		"vip_state":
			if current_panel == "vip":
				_show_vip(true)
		"achievements_state":
			if current_panel == "achievements":
				_show_achievements(true)
		"season_state":
			if current_panel == "season":
				_show_season(true)

func _apply_online_snapshot(players_data: Array) -> void:
	var seen: Dictionary = {}
	for entry in players_data:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var character_id := int(entry.get("characterId", 0))
		if player != null and character_id == int(player.get_meta("character_id", 0)):
			continue
		if character_id <= 0:
			continue
		seen[character_id] = true
		_spawn_or_update_remote(entry)
	var keys := remote_players.keys()
	for character_id in keys:
		if not seen.has(character_id):
			_remove_remote_player(int(character_id))

func _spawn_or_update_remote(data: Dictionary) -> void:
	var character_id := int(data.get("characterId", 0))
	if character_id <= 0:
		return
	var remote: Node2D = remote_players.get(character_id, null)
	if remote == null:
		remote = _create_remote_player_node(data)
		remote_players[character_id] = remote
		world.add_child(remote)
	remote.global_position = Vector2(float(data.get("pos", {}).get("x", 0.0)), float(data.get("pos", {}).get("y", 0.0)))
	remote.set_meta("map", str(data.get("map", current_map)))
	var name_label: Label = remote.get_node("NameLabel")
	name_label.text = "Lv %d %s" % [int(data.get("level", 1)), str(data.get("name", "Jogador"))]
	_update_remote_hp(character_id, int(data.get("hp", 100)))

func _create_remote_player_node(data: Dictionary) -> Node2D:
	var node := Node2D.new()
	node.name = "RemotePlayer_%d" % int(data.get("characterId", 0))
	var sprite := Sprite2D.new()
	sprite.texture = load(_player_sprite_path_from_class(str(data.get("className", "Guerreiro"))))
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if sprite.texture != null:
		var target_height := 64.0
		var texture_height: float = maxf(1.0, float(sprite.texture.get_height()))
		var sprite_scale: float = target_height / texture_height
		sprite.scale = Vector2(sprite_scale, sprite_scale)
		sprite.position = Vector2(0, -18)
	else:
		sprite.scale = Vector2(1.4, 1.4)
	node.add_child(sprite)
	var label := Label.new()
	label.name = "NameLabel"
	label.position = Vector2(-68, -58)
	label.size = Vector2(136, 16)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", Color("#e7f2ff"))
	label.add_theme_font_size_override("font_size", 11)
	node.add_child(label)
	var hp := ProgressBar.new()
	hp.name = "HP"
	hp.position = Vector2(-28, -36)
	hp.size = Vector2(56, 6)
	hp.max_value = 100
	hp.value = 100
	hp.show_percentage = false
	node.add_child(hp)
	return node

func _update_remote_hp(character_id: int, hp_value: int) -> void:
	var remote: Node2D = remote_players.get(character_id, null)
	if remote == null:
		return
	var hp := remote.get_node("HP") as ProgressBar
	if hp == null:
		return
	hp.max_value = max(1, hp.max_value)
	hp.value = clamp(hp_value, 0, hp.max_value)

func _remove_remote_player(character_id: int) -> void:
	var remote: Node2D = remote_players.get(character_id, null)
	if remote != null and is_instance_valid(remote):
		remote.queue_free()
	remote_players.erase(character_id)

func _cleanup_remote_players_for_map() -> void:
	for character_id in remote_players.keys():
		var remote: Node2D = remote_players[character_id]
		if remote == null or not is_instance_valid(remote):
			continue
		var map_id := str(remote.get_meta("map", ""))
		remote.visible = map_id == current_map

func _player_sprite_path_from_class(class_id: String) -> String:
	match class_id:
		"Guerreiro":
			if ResourceLoader.exists("res://assets/sprites/player_guerreiro_art_front.png"):
				return "res://assets/sprites/player_guerreiro_art_front.png"
			return "res://assets/sprites/player_guerreiro.png"
		"Mago":
			if ResourceLoader.exists("res://assets/sprites/player_mago_art_front.png"):
				return "res://assets/sprites/player_mago_art_front.png"
			return "res://assets/sprites/player_mago.png"
		"Arqueiro":
			if ResourceLoader.exists("res://assets/sprites/player_arqueiro_art_front.png"):
				return "res://assets/sprites/player_arqueiro_art_front.png"
			return "res://assets/sprites/player_arqueiro.png"
	return "res://assets/sprites/player_guerreiro.png"

func _build_ui() -> void:
	hud_label = Label.new()
	hud_label.position = Vector2(12, 6)
	hud_label.add_theme_color_override("font_color", Color.WHITE)
	hud_label.add_theme_font_size_override("font_size", 12)
	ui.add_child(hud_label)
	xp_label = Label.new()
	xp_label.position = Vector2(12, 22)
	xp_label.add_theme_color_override("font_color", Color("#f6f7ff"))
	xp_label.add_theme_font_size_override("font_size", 13)
	ui.add_child(xp_label)
	hp_label = Label.new()
	hp_label.position = Vector2(12, 38)
	hp_label.add_theme_color_override("font_color", Color("#ffd9d9"))
	hp_label.add_theme_font_size_override("font_size", 12)
	ui.add_child(hp_label)
	hp_bar = ProgressBar.new()
	hp_bar.position = Vector2(12, 52)
	hp_bar.size = Vector2(292, 10)
	hp_bar.show_percentage = false
	var hp_bg := StyleBoxFlat.new()
	hp_bg.bg_color = Color(0.04, 0.05, 0.08, 0.72)
	hp_bg.border_color = Color(1, 1, 1, 0.28)
	hp_bg.set_border_width_all(1)
	hp_bg.set_corner_radius_all(4)
	var hp_fill := StyleBoxFlat.new()
	hp_fill.bg_color = Color("#c64646")
	hp_fill.set_corner_radius_all(4)
	hp_bar.add_theme_stylebox_override("background", hp_bg)
	hp_bar.add_theme_stylebox_override("fill", hp_fill)
	ui.add_child(hp_bar)
	mana_label = Label.new()
	mana_label.position = Vector2(12, 66)
	mana_label.add_theme_color_override("font_color", Color("#d8e5ff"))
	mana_label.add_theme_font_size_override("font_size", 12)
	ui.add_child(mana_label)
	mana_bar = ProgressBar.new()
	mana_bar.position = Vector2(12, 80)
	mana_bar.size = Vector2(292, 10)
	mana_bar.show_percentage = false
	var mp_bg := StyleBoxFlat.new()
	mp_bg.bg_color = Color(0.04, 0.05, 0.08, 0.72)
	mp_bg.border_color = Color(0.50, 0.65, 1.0, 0.42)
	mp_bg.set_border_width_all(1)
	mp_bg.set_corner_radius_all(4)
	var mp_fill := StyleBoxFlat.new()
	mp_fill.bg_color = Color("#4f7dff")
	mp_fill.set_corner_radius_all(4)
	mana_bar.add_theme_stylebox_override("background", mp_bg)
	mana_bar.add_theme_stylebox_override("fill", mp_fill)
	ui.add_child(mana_bar)
	xp_value_label = Label.new()
	xp_value_label.position = Vector2(12, 94)
	xp_value_label.add_theme_color_override("font_color", Color("#f8e4aa"))
	xp_value_label.add_theme_font_size_override("font_size", 12)
	ui.add_child(xp_value_label)
	xp_bar = ProgressBar.new()
	xp_bar.position = Vector2(12, 108)
	xp_bar.size = Vector2(292, 10)
	xp_bar.show_percentage = false
	var xp_bg := StyleBoxFlat.new()
	xp_bg.bg_color = Color(0.04, 0.05, 0.08, 0.72)
	xp_bg.border_color = Color(1, 1, 1, 0.28)
	xp_bg.set_border_width_all(1)
	xp_bg.set_corner_radius_all(4)
	var xp_fill := StyleBoxFlat.new()
	xp_fill.bg_color = Color("#31a8ff")
	xp_fill.set_corner_radius_all(4)
	xp_bar.add_theme_stylebox_override("background", xp_bg)
	xp_bar.add_theme_stylebox_override("fill", xp_fill)
	ui.add_child(xp_bar)
	message_label = Label.new()
	message_label.position = Vector2(285, 676)
	message_label.add_theme_color_override("font_color", Color("#ffe8a3"))
	ui.add_child(message_label)
	minimap_panel = PanelContainer.new()
	minimap_panel.position = Vector2(112, 144)
	minimap_panel.size = MINIMAP_SIZE + Vector2(8, 8)
	minimap_panel.z_index = 150
	var minimap_style := StyleBoxFlat.new()
	minimap_style.bg_color = Color(0.01, 0.02, 0.04, 0.78)
	minimap_style.border_color = Color(1, 1, 1, 0.36)
	minimap_style.set_border_width_all(1)
	minimap_style.set_corner_radius_all(6)
	minimap_panel.add_theme_stylebox_override("panel", minimap_style)
	ui.add_child(minimap_panel)
	minimap_canvas = Control.new()
	minimap_canvas.position = Vector2(4, 4)
	minimap_canvas.size = MINIMAP_SIZE
	minimap_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	minimap_panel.add_child(minimap_canvas)
	panel_blocker = ColorRect.new()
	panel_blocker.color = Color(0, 0, 0, 0.28)
	panel_blocker.anchor_left = 0.0
	panel_blocker.anchor_top = 0.0
	panel_blocker.anchor_right = 1.0
	panel_blocker.anchor_bottom = 1.0
	panel_blocker.offset_left = 0.0
	panel_blocker.offset_top = 0.0
	panel_blocker.offset_right = 0.0
	panel_blocker.offset_bottom = 0.0
	panel_blocker.mouse_filter = Control.MOUSE_FILTER_STOP
	panel_blocker.visible = false
	panel_blocker.z_index = 900
	ui.add_child(panel_blocker)
	panel = PanelContainer.new()
	panel.visible = false
	panel.position = Vector2(180, 72)
	panel.size = Vector2(920, 560)
	panel.custom_minimum_size = Vector2(920, 560)
	panel.z_index = 901
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.015, 0.018, 0.023, 0.94)
	panel_style.border_color = Color(1, 1, 1, 0.30)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(8)
	panel.add_theme_stylebox_override("panel", panel_style)
	ui.add_child(panel)
	input_guard = ColorRect.new()
	input_guard.color = Color(0, 0, 0, 0)
	input_guard.anchor_left = 0.0
	input_guard.anchor_top = 0.0
	input_guard.anchor_right = 1.0
	input_guard.anchor_bottom = 1.0
	input_guard.offset_left = 0.0
	input_guard.offset_top = 0.0
	input_guard.offset_right = 0.0
	input_guard.offset_bottom = 0.0
	input_guard.mouse_filter = Control.MOUSE_FILTER_STOP
	input_guard.visible = false
	input_guard.z_index = 950
	ui.add_child(input_guard)
	_build_potion_bar()
	_build_touch_controls()
	_build_side_menu()
	_refresh_modal_layout()

func _build_potion_bar() -> void:
	for i in range(POTION_SLOTS.size()):
		var slot: Dictionary = POTION_SLOTS[i]
		var item_name := str(slot["item"])
		var button := Button.new()
		button.position = POTION_BUTTON_POSITIONS[i]
		button.size = Vector2(62, 58)
		button.custom_minimum_size = button.size
		button.focus_mode = Control.FOCUS_NONE
		button.text = ""
		button.disabled = true
		button.add_theme_font_size_override("font_size", 13)
		button.icon = load(str(slot["icon"]))
		button.expand_icon = true
		_style_potion_button(button)
		var count_label := Label.new()
		count_label.position = Vector2(5, 37)
		count_label.size = Vector2(52, 18)
		count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		count_label.add_theme_color_override("font_color", Color.WHITE)
		count_label.add_theme_color_override("font_shadow_color", Color.BLACK)
		count_label.add_theme_constant_override("shadow_offset_x", 1)
		count_label.add_theme_constant_override("shadow_offset_y", 1)
		count_label.add_theme_font_size_override("font_size", 14)
		count_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(count_label)
		button.pressed.connect(func() -> void:
			_use_potion_item(item_name)
		)
		ui.add_child(button)
		potion_buttons[item_name] = {"button": button, "label": str(slot["label"]), "count": count_label}

func _style_potion_button(button: Button) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.05, 0.05, 0.06, 0.58)
	normal.border_color = Color(1, 1, 1, 0.36)
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(8)
	var pressed := StyleBoxFlat.new()
	pressed.bg_color = Color(0.38, 0.16, 0.16, 0.72)
	pressed.border_color = Color(1, 0.82, 0.82, 0.8)
	pressed.set_border_width_all(2)
	pressed.set_corner_radius_all(8)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", normal)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_color_override("font_color", Color.WHITE)
	button.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.35))

func _build_touch_controls() -> void:
	_build_joystick()
	attack_button = _make_tap_button("ATK", Vector2(1112, 572), Vector2(110, 82), func() -> void:
		if player != null:
			player.basic_attack()
	)
	skill_buttons.clear()
	var skill_1 := _make_tap_button("1", Vector2(896, 590), Vector2(66, 60), func() -> void:
		if player != null:
			player.use_skill(0)
	)
	skill_buttons.append(skill_1)
	var skill_2 := _make_tap_button("2", Vector2(972, 532), Vector2(66, 60), func() -> void:
		if player != null:
			player.use_skill(1)
	)
	skill_buttons.append(skill_2)
	var skill_3 := _make_tap_button("3", Vector2(1048, 474), Vector2(66, 60), func() -> void:
		if player != null:
			player.use_skill(2)
	)
	skill_buttons.append(skill_3)
	interact_button = _make_tap_button("OK", Vector2(1162, 452), Vector2(60, 54), _interact)
	_style_interact_button(interact_button)
	inventory_button = _make_tap_button("", Vector2(1018, 78), Vector2(60, 54), _show_inventory)
	character_button = _make_tap_button("", Vector2(1086, 78), Vector2(60, 54), _show_skills_window)
	quests_button = _make_tap_button("", Vector2(1154, 78), Vector2(60, 54), _show_quests)
	_style_quick_top_button(inventory_button, "res://assets/sprites/icon_slot_backpack.png", "Bolsa")
	_style_quick_top_button(character_button, "res://assets/sprites/icon_attack_book.png", "Habilidades")
	_style_quick_top_button(quests_button, "res://assets/sprites/drop_material.png", "Missoes")

func _style_quick_top_button(button: Button, icon_path: String, tooltip: String) -> void:
	if button == null:
		return
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.04, 0.055, 0.07, 0.92)
	normal.border_color = Color(0.82, 0.90, 1.0, 0.40)
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(12)
	var pressed := StyleBoxFlat.new()
	pressed.bg_color = Color(0.08, 0.16, 0.24, 0.96)
	pressed.border_color = Color(0.90, 0.96, 1.0, 0.72)
	pressed.set_border_width_all(2)
	pressed.set_corner_radius_all(12)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", normal)
	button.add_theme_stylebox_override("pressed", pressed)
	button.icon = load(icon_path)
	button.expand_icon = true
	button.tooltip_text = tooltip

func _style_interact_button(button: Button) -> void:
	if button == null:
		return
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.08, 0.13, 0.08, 0.94)
	normal.border_color = Color("#89ff88")
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(12)
	var pressed := StyleBoxFlat.new()
	pressed.bg_color = Color(0.14, 0.32, 0.14, 0.98)
	pressed.border_color = Color("#d8ffd2")
	pressed.set_border_width_all(2)
	pressed.set_corner_radius_all(12)
	button.text = "OK"
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", normal)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_color_override("font_color", Color("#f5fff0"))
	button.add_theme_color_override("font_pressed_color", Color.WHITE)
	button.add_theme_font_size_override("font_size", 18)
	button.tooltip_text = "Interagir"

func _build_side_menu() -> void:
	side_menu_toggle_button = Button.new()
	side_menu_toggle_button.text = "MENU"
	side_menu_toggle_button.position = Vector2(1128, 8)
	side_menu_toggle_button.size = Vector2(110, 42)
	UISideMenu.style_button(side_menu_toggle_button, true)
	side_menu_toggle_button.pressed.connect(func() -> void:
		if panel.visible:
			return
		side_menu_visible = not side_menu_visible
		side_menu_panel.visible = side_menu_visible
	)
	ui.add_child(side_menu_toggle_button)

	side_menu_panel = PanelContainer.new()
	side_menu_panel.position = Vector2(980, 54)
	side_menu_panel.size = Vector2(286, 618)
	side_menu_panel.visible = false
	side_menu_panel.z_index = 210
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.024, 0.03, 0.92)
	style.border_color = Color(1, 1, 1, 0.22)
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	side_menu_panel.add_theme_stylebox_override("panel", style)
	var scroller := ScrollContainer.new()
	scroller.custom_minimum_size = Vector2(274, 606)
	scroller.size = Vector2(274, 606)
	scroller.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroller.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	side_menu_panel.add_child(scroller)
	var list := GridContainer.new()
	list.columns = 2
	list.add_theme_constant_override("h_separation", 8)
	list.add_theme_constant_override("v_separation", 8)
	scroller.add_child(list)
	for item in UISideMenu.MENU_ITEMS:
		var item_label := str(item)
		var button := Button.new()
		button.text = item_label
		var icon_path := str(SIDE_MENU_ICONS.get(item_label, ""))
		if not icon_path.is_empty():
			button.icon = load(icon_path)
			button.expand_icon = true
		UISideMenu.style_button(button)
		button.pressed.connect(func() -> void:
			_handle_side_menu(item_label)
		)
		list.add_child(button)
	ui.add_child(side_menu_panel)

func _handle_side_menu(item: String) -> void:
	match item:
		"Habilidades":
			_show_skills_window()
		"Roupa":
			_show_equipment_window()
		"Bolsa":
			_show_inventory()
		"Mapa":
			_show_world_map()
		"Missoes":
			_show_quests()
		"Profissoes":
			_show_professions()
		"Pets":
			_show_pets()
		"Montarias":
			_show_mounts()
		"Dungeon":
			_show_dungeons()
		"Rank":
			_show_rank()
		"Mercado":
			_show_market()
		"VIP":
			_show_vip()
		"Conquistas":
			_show_achievements()
		"Temporada":
			_show_season()
		"Wikipedia":
			_show_wikipedia()
		"Fechar":
			side_menu_visible = false
			side_menu_panel.visible = false
		_:
			_flash("Sistema ainda em desenvolvimento.")

func _build_joystick() -> void:
	joystick_base = _make_texture_rect("res://assets/sprites/ui_joystick_base.png", touch_move_center - Vector2(84, 84), Vector2(168, 168))
	joystick_base.modulate = Color(1, 1, 1, 0.82)
	joystick_knob = _make_texture_rect("res://assets/sprites/ui_joystick_knob.png", touch_move_center - Vector2(34, 34), Vector2(68, 68))
	joystick_knob.modulate = Color(1, 1, 1, 0.92)

func _make_texture_rect(path: String, pos: Vector2, size: Vector2) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = load(path)
	rect.position = pos
	rect.size = size
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(rect)
	return rect

func _is_move_touch(pos: Vector2) -> bool:
	return pos.distance_to(touch_move_center) <= 105

func _activate_touch_region(pos: Vector2) -> void:
	if Rect2(Vector2(1080, 535), Vector2(170, 150)).has_point(pos):
		player.basic_attack()
	elif Rect2(Vector2(0, 72), Vector2(415, 58)).has_point(pos):
		_activate_potion_region(pos)
	elif Rect2(Vector2(875, 565), Vector2(105, 95)).has_point(pos):
		player.use_skill(0)
	elif Rect2(Vector2(950, 505), Vector2(105, 95)).has_point(pos):
		player.use_skill(1)
	elif Rect2(Vector2(1025, 445), Vector2(105, 95)).has_point(pos):
		player.use_skill(2)
	elif Rect2(Vector2(1140, 430), Vector2(105, 95)).has_point(pos):
		_interact()
	elif Rect2(Vector2(1015, 60), Vector2(85, 90)).has_point(pos):
		_show_inventory()
	elif Rect2(Vector2(1080, 60), Vector2(85, 90)).has_point(pos):
		_show_character()
	elif Rect2(Vector2(1140, 60), Vector2(95, 90)).has_point(pos):
		_show_quests()

func _activate_potion_region(pos: Vector2) -> void:
	var index: int = clamp(int(pos.x / 100.0), 0, POTION_SLOTS.size() - 1)
	_use_potion_item(str(POTION_SLOTS[index]["item"]))

func _update_touch_move(pos: Vector2) -> void:
	var delta := (pos - touch_move_center).limit_length(touch_move_radius)
	var axis := delta / touch_move_radius
	var dead_zone := 0.16
	if joystick_knob != null:
		joystick_knob.position = touch_move_center + delta - joystick_knob.size * 0.5
	_set_touch_action_strength("move_left", max(0.0, -axis.x) if abs(axis.x) >= dead_zone else 0.0)
	_set_touch_action_strength("move_right", max(0.0, axis.x) if abs(axis.x) >= dead_zone else 0.0)
	_set_touch_action_strength("move_up", max(0.0, -axis.y) if abs(axis.y) >= dead_zone else 0.0)
	_set_touch_action_strength("move_down", max(0.0, axis.y) if abs(axis.y) >= dead_zone else 0.0)

func _set_touch_action(action: String, pressed: bool) -> void:
	if pressed:
		Input.action_press(action)
	else:
		Input.action_release(action)

func _set_touch_action_strength(action: String, strength: float) -> void:
	if strength > 0.05:
		Input.action_press(action, strength)
	else:
		Input.action_release(action)

func _release_touch_move() -> void:
	touch_move_index = -1
	for action in ["move_left", "move_right", "move_up", "move_down"]:
		Input.action_release(action)
	if joystick_knob != null:
		joystick_knob.position = touch_move_center - joystick_knob.size * 0.5

func _make_hold_button(text: String, pos: Vector2, size: Vector2, action: String) -> Button:
	var button := _make_touch_button(text, pos, size)
	button.button_down.connect(func() -> void:
		Input.action_press(action)
	)
	button.button_up.connect(func() -> void:
		Input.action_release(action)
	)
	return button

func _make_tap_button(text: String, pos: Vector2, size: Vector2, callback: Callable) -> Button:
	var button := _make_touch_button(text, pos, size)
	button.pressed.connect(callback)
	return button

func _make_touch_button(text: String, pos: Vector2, size: Vector2) -> Button:
	var button := Button.new()
	button.text = text
	button.position = pos
	button.size = size
	button.custom_minimum_size = size
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 22)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.04, 0.05, 0.06, 0.48)
	normal.border_color = Color(1, 1, 1, 0.38)
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(10)
	var pressed := StyleBoxFlat.new()
	pressed.bg_color = Color(0.45, 0.55, 0.62, 0.62)
	pressed.border_color = Color(1, 1, 1, 0.7)
	pressed.set_border_width_all(2)
	pressed.set_corner_radius_all(10)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", normal)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_color_override("font_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color.WHITE)
	ui.add_child(button)
	touch_buttons.append(button)
	return button

func _apply_button_icon(button: Button, icon_path: String, fallback_text: String, tooltip: String = "") -> void:
	if button == null:
		return
	var icon := load(icon_path) as Texture2D
	if icon == null:
		button.text = fallback_text
		return
	button.text = ""
	button.icon = icon
	button.expand_icon = true
	button.tooltip_text = tooltip

func _update_action_icons() -> void:
	if player == null:
		return
	var attack_icon := str(ATTACK_ICON_BY_CLASS.get(player.class_name_selected, ""))
	if not attack_icon.is_empty():
		_apply_button_icon(attack_button, attack_icon, "ATK", "Ataque basico")
	var skills: Array = player.class_data.get("skills", [])
	for i in range(skill_buttons.size()):
		var button := skill_buttons[i]
		if i >= skills.size():
			button.text = str(i + 1)
			continue
		var skill: Dictionary = skills[i]
		var skill_id := str(skill.get("id", ""))
		var skill_icon := str(SKILL_ICON_BY_ID.get(skill_id, ""))
		if skill_icon.is_empty():
			button.text = str(i + 1)
		else:
			_apply_button_icon(button, skill_icon, str(i + 1), str(skill.get("name", "")))

func _show_class_selection() -> void:
	if online_mode:
		_flash("Modo online ativo: escolha de classe e personagem no launcher.")
		return
	var box := VBoxContainer.new()
	box.position = Vector2(430, 150)
	box.custom_minimum_size = Vector2(420, 380)
	ui.add_child(box)
	var title := Label.new()
	title.text = "Arcadia Realms 2D\nEscolha sua classe"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	for class_label in class_db.all_classes():
		var btn := Button.new()
		btn.text = class_label
		btn.custom_minimum_size = Vector2(360, 64)
		btn.pressed.connect(func() -> void:
			box.queue_free()
			_start_new_game(str(class_label))
		)
		box.add_child(btn)

func _start_new_game(chosen_class: String) -> void:
	if online_mode:
		_flash("Use o launcher MMO para iniciar online.")
		return
	player = PLAYER_SCENE.instantiate()
	world.add_child(player)
	player.setup(chosen_class, class_db.get_class_data(chosen_class), item_db)
	mmo_cache = {}
	_ensure_local_companion_state()
	_ensure_beginner_quests()
	_connect_player()
	_update_action_icons()
	_load_map("city_eldoria", Vector2(1080, 760))
	_flash("Bem-vindo a Cidade de Eldoria. Use OK para interagir.")

func _spawn_player_from_save(save: Dictionary) -> void:
	if online_mode:
		_flash("Save local desativado no modo online.")
		return
	player = PLAYER_SCENE.instantiate()
	world.add_child(player)
	player.from_save(save.get("player", {}), item_db, class_db)
	quest_system.from_save(save.get("quests", {}))
	exploration_by_map = save.get("exploration", {})
	mmo_cache = save.get("mmo_cache", {})
	_ensure_local_companion_state()
	_ensure_beginner_quests()
	_connect_player()
	_update_action_icons()
	_apply_companion_bonuses()
	var pos_arr: Array = save.get("position", [640, 380])
	_load_map(str(save.get("current_map", "city_eldoria")), Vector2(float(pos_arr[0]), float(pos_arr[1])))
	_flash("Save carregado.")

func _connect_player() -> void:
	player.attack_requested.connect(_player_attack)
	player.skill_area_requested.connect(_player_area_attack)
	player.dash_requested.connect(_player_dash)
	player.self_effect_requested.connect(_player_self_effect)
	player.damage_taken.connect(func(amount: int) -> void:
		_dismount_current_mount("Voce desceu da montaria ao tomar dano.")
		_spawn_floating_text(player.global_position + Vector2(0, -42), "-%d" % amount, Color("#ff4f4f"))
	)
	player.healed.connect(func(amount: int) -> void:
		_spawn_floating_text(player.global_position + Vector2(0, -56), "+%d" % amount, Color("#69ff7c"))
	)
	player.message_requested.connect(_flash)
	player.died.connect(_player_died)
	_ensure_player_camera()

func _ensure_beginner_quests() -> void:
	for quest_id in BEGINNER_QUESTS:
		if quest_system.completed.has(quest_id):
			continue
		if not quest_system.active.has(quest_id):
			quest_system.accept(quest_id)

func _load_map(map_id: String, spawn_position: Vector2 = Vector2.ZERO) -> void:
	current_map = map_id
	_ensure_map_exploration(map_id)
	safe_zone_nodes.clear()
	solid_obstacles.clear()
	for child in world.get_children():
		if child != player:
			child.queue_free()
	var map_data: Dictionary = maps.get(map_id, {})
	var size_data: Array = map_data.get("size", [int(DEFAULT_MAP_SIZE.x), int(DEFAULT_MAP_SIZE.y)])
	current_map_size = Vector2(float(size_data[0]), float(size_data[1]))
	_draw_map_background(map_data)
	if player != null:
		var spawn: Array = map_data.get("spawn", [1080, 760])
		player.global_position = spawn_position if spawn_position != Vector2.ZERO else Vector2(float(spawn[0]), float(spawn[1]))
		last_valid_player_position = player.global_position
		quest_system.register_visit(map_id)
	_spawn_npcs(map_data)
	_spawn_portals(map_data)
	_spawn_safe_zones(map_data)
	_spawn_enemies(map_data)
	_update_safe_zone_state()
	_update_camera_limits()
	_cleanup_remote_players_for_map()
	_flash(str(map_data.get("name", map_id)))

func _draw_map_background(map_data: Dictionary) -> void:
	_draw_map_terrain(map_data)
	_spawn_ground_details()
	var title := Label.new()
	title.text = str(map_data.get("name", "Mapa"))
	title.position = Vector2(540, 48)
	title.z_index = 100
	title.add_theme_color_override("font_color", Color.WHITE)
	world.add_child(title)
	_spawn_map_decor()

func _draw_map_terrain(map_data: Dictionary) -> void:
	match current_map:
		"city_eldoria":
			_draw_city_terrain()
		"city_valdoria":
			_draw_valdoria_terrain()
		"forest_boars":
			_draw_forest_terrain()
		"arcane_ruins":
			_draw_arcane_terrain()
		"bat_cave":
			_draw_cave_terrain()
		"highland_pass":
			_draw_highland_terrain()
		"crystal_mines":
			_draw_crystal_mines_terrain()
		"ember_fortress":
			_draw_ember_fortress_terrain()
		_:
			_add_world_rect(Rect2(Vector2.ZERO, current_map_size), Color(map_data.get("color", "#303030")), -100)

func _draw_city_terrain() -> void:
	_draw_tiled_rect("res://assets/sprites/tile_water.png", Rect2(0, 0, current_map_size.x, current_map_size.y), 64, -100)
	_draw_tiled_rect("res://assets/sprites/tile_grass.png", Rect2(150, 120, current_map_size.x - 300, current_map_size.y - 240), 64, -96)
	_draw_tiled_rect("res://assets/sprites/tile_stone.png", Rect2(430, 250, 1300, 770), 64, -94)
	_draw_tiled_rect("res://assets/sprites/tile_path.png", Rect2(1020, 350, 220, 900), 64, -93)
	_draw_tiled_rect("res://assets/sprites/tile_path.png", Rect2(520, 570, 1120, 130), 64, -93)
	for bridge_x in [900, 1040, 1180]:
		_draw_tiled_rect("res://assets/sprites/tile_bridge.png", Rect2(bridge_x, 0, 80, 280), 64, -92)
	for wall in [
		Rect2(400, 220, 1360, 40), Rect2(400, 1020, 1360, 40),
		Rect2(400, 220, 40, 840), Rect2(1720, 220, 40, 840)
	]:
		_add_world_rect(wall, Color("#39414a"), -91)
		_register_solid_rect(wall)
	_add_world_label("Shop", Vector2(1210, 490), Color("#ffe0a3"))
	_add_world_label("Forja", Vector2(1335, 760), Color("#ffd06b"))
	_add_world_label("Fonte", Vector2(1040, 735), Color("#bdeaff"))

func _draw_valdoria_terrain() -> void:
	_draw_tiled_rect("res://assets/sprites/tile_water.png", Rect2(0, 0, current_map_size.x, current_map_size.y), 64, -100)
	_draw_tiled_rect("res://assets/sprites/tile_stone.png", Rect2(260, 160, current_map_size.x - 520, current_map_size.y - 300), 64, -96)
	_draw_tiled_rect("res://assets/sprites/tile_ruin.png", Rect2(520, 310, 1160, 620), 64, -94)
	_draw_tiled_rect("res://assets/sprites/tile_path.png", Rect2(980, 260, 210, 930), 64, -93)
	_draw_tiled_rect("res://assets/sprites/tile_path.png", Rect2(520, 710, 1180, 130), 64, -93)
	for wall in [
		Rect2(235, 135, 1730, 42), Rect2(235, 1110, 1730, 42),
		Rect2(235, 135, 42, 1015), Rect2(1925, 135, 42, 1015)
	]:
		_add_world_rect(wall, Color("#273347"), -91)
		_register_solid_rect(wall)
	_add_world_label("Pets", Vector2(570, 525), Color("#9effb0"))
	_add_world_label("Montarias", Vector2(1300, 525), Color("#ffe0a3"))
	_add_world_label("Forja Rara", Vector2(1490, 805), Color("#ffd06b"))

func _draw_forest_terrain() -> void:
	_draw_tiled_rect("res://assets/sprites/tile_grass.png", Rect2(0, 0, current_map_size.x, current_map_size.y), 64, -100)
	_draw_tiled_rect("res://assets/sprites/tile_water.png", Rect2(0, 0, 240, current_map_size.y), 64, -99)
	_draw_tiled_rect("res://assets/sprites/tile_sand.png", Rect2(220, 0, 60, current_map_size.y), 64, -98)
	_draw_path_points("res://assets/sprites/tile_path.png", [Vector2(1080, 1300), Vector2(900, 1110), Vector2(1020, 900), Vector2(760, 720), Vector2(1040, 550), Vector2(1380, 470), Vector2(1700, 330), Vector2(1900, 240)], 150, -96)
	_draw_tiled_blob("res://assets/sprites/tile_path.png", Vector2(1080, 1300), 250, 135, -95)
	_draw_tiled_blob("res://assets/sprites/tile_path.png", Vector2(1900, 250), 250, 150, -95)
	_draw_tiled_blob("res://assets/sprites/tile_grass.png", Vector2(520, 760), 250, 160, -97, 64, Color("#d8bd82"))
	_register_solid_rect(Rect2(0, 0, 170, current_map_size.y))

func _draw_arcane_terrain() -> void:
	_draw_tiled_rect("res://assets/sprites/tile_arcane.png", Rect2(0, 0, current_map_size.x, current_map_size.y), 64, -100)
	_draw_tiled_blob("res://assets/sprites/tile_ruin.png", Vector2(1070, 760), 760, 500, -96)
	_draw_path_points("res://assets/sprites/tile_path.png", [Vector2(1080, 1300), Vector2(980, 1040), Vector2(1220, 810), Vector2(980, 620), Vector2(1420, 430), Vector2(1900, 240)], 135, -95)
	_draw_tiled_blob("res://assets/sprites/tile_ruin.png", Vector2(1900, 255), 260, 160, -94)
	for ruin in [Rect2(500, 360, 180, 72), Rect2(1460, 370, 220, 72), Rect2(430, 860, 250, 75), Rect2(1460, 850, 230, 75)]:
		_add_world_rect(ruin, Color("#4b4d76"), -94)
		_register_solid_rect(ruin)

func _draw_cave_terrain() -> void:
	_draw_tiled_rect("res://assets/sprites/tile_cave.png", Rect2(0, 0, current_map_size.x, current_map_size.y), 64, -100)
	_draw_path_points("res://assets/sprites/tile_cave_floor.png", [Vector2(1080, 1300), Vector2(930, 1080), Vector2(590, 900), Vector2(850, 700), Vector2(1230, 690), Vector2(1510, 500), Vector2(1900, 240)], 260, -97)
	_draw_tiled_blob("res://assets/sprites/tile_cave_floor.png", Vector2(590, 900), 330, 210, -96)
	_draw_tiled_blob("res://assets/sprites/tile_cave_floor.png", Vector2(1260, 690), 390, 240, -96)
	_draw_tiled_blob("res://assets/sprites/tile_cave_floor.png", Vector2(1900, 240), 260, 180, -96)
	for dark_pool in [Rect2(360, 250, 230, 130), Rect2(1510, 210, 280, 150), Rect2(420, 960, 210, 120), Rect2(1330, 980, 260, 110)]:
		_add_world_rect(dark_pool, Color("#151923"), -95)
		_register_solid_rect(dark_pool.grow(-18))

func _draw_highland_terrain() -> void:
	_draw_tiled_rect("res://assets/sprites/tile_grass.png", Rect2(0, 0, current_map_size.x, current_map_size.y), 64, -100)
	_draw_path_points("res://assets/sprites/tile_path.png", [Vector2(1080, 1300), Vector2(740, 1110), Vector2(980, 900), Vector2(760, 690), Vector2(1180, 540), Vector2(1450, 410), Vector2(1900, 240)], 155, -96)
	for ridge in [Rect2(140, 160, 480, 150), Rect2(1500, 180, 520, 160), Rect2(210, 760, 380, 150), Rect2(1520, 810, 430, 150)]:
		_add_world_rect(ridge, Color("#405945"), -95)
		_register_solid_rect(ridge.grow(-22))
	for clearing in [Rect2(680, 430, 250, 130), Rect2(1220, 560, 280, 150), Rect2(720, 900, 240, 130)]:
		_add_world_rect(clearing, Color("#c7b783"), -94)

func _draw_crystal_mines_terrain() -> void:
	_draw_tiled_rect("res://assets/sprites/tile_cave.png", Rect2(0, 0, current_map_size.x, current_map_size.y), 64, -100)
	_draw_path_points("res://assets/sprites/tile_cave_floor.png", [Vector2(1080, 1300), Vector2(880, 1020), Vector2(1160, 780), Vector2(850, 560), Vector2(1370, 430), Vector2(1900, 240)], 230, -97)
	_draw_tiled_blob("res://assets/sprites/tile_ruin.png", Vector2(1120, 760), 610, 380, -96)
	for seam in [Rect2(380, 260, 150, 760), Rect2(1690, 240, 160, 790), Rect2(830, 360, 470, 110)]:
		_add_world_rect(seam, Color("#26385d"), -95)
		_register_solid_rect(seam.grow(-20))
	for glow in [Rect2(650, 650, 180, 110), Rect2(1330, 670, 180, 110)]:
		_add_world_rect(glow, Color("#345a80"), -94)

func _draw_ember_fortress_terrain() -> void:
	_draw_tiled_rect("res://assets/sprites/tile_ruin.png", Rect2(0, 0, current_map_size.x, current_map_size.y), 64, -100)
	_draw_tiled_blob("res://assets/sprites/tile_stone.png", Vector2(1100, 720), 820, 520, -97)
	_draw_path_points("res://assets/sprites/tile_path.png", [Vector2(1080, 1300), Vector2(900, 1030), Vector2(1210, 820), Vector2(970, 640), Vector2(1360, 470), Vector2(1900, 240)], 150, -96)
	for lava in [Rect2(140, 280, 230, 680), Rect2(1840, 260, 230, 700), Rect2(650, 250, 840, 80)]:
		_add_world_rect(lava, Color("#7a2d19"), -95)
		_register_solid_rect(lava.grow(-12))
	for wall in [Rect2(350, 250, 1500, 44), Rect2(350, 1010, 1500, 44), Rect2(350, 250, 44, 804), Rect2(1806, 250, 44, 804)]:
		_add_world_rect(wall, Color("#2b2424"), -94)
		_register_solid_rect(wall)

func _spawn_map_decor() -> void:
	if current_map == "city_eldoria":
		_add_world_sprite("res://assets/sprites/decor_fountain.png", Vector2(640, 365), 2.0, -10)
		_add_world_sprite("res://assets/sprites/decor_house.png", Vector2(430, 255), 2.2, -8)
		_add_world_sprite("res://assets/sprites/decor_house.png", Vector2(790, 272), 2.0, -8)
		_add_world_sprite("res://assets/sprites/decor_forge.png", Vector2(892, 458), 2.0, -8)
		for p in [Vector2(160, 185), Vector2(1090, 172), Vector2(186, 430), Vector2(1100, 455), Vector2(355, 505), Vector2(1005, 615)]:
			_add_world_sprite("res://assets/sprites/decor_tree.png", p, 1.7, -12)
	elif current_map == "city_valdoria":
		_add_world_sprite("res://assets/sprites/decor_fountain.png", Vector2(1080, 560), 2.0, -10)
		_add_world_sprite("res://assets/sprites/decor_forge.png", Vector2(1660, 785), 2.2, -8)
		for p in [Vector2(420, 310), Vector2(700, 330), Vector2(1325, 330), Vector2(1600, 330), Vector2(620, 1000), Vector2(1380, 1000)]:
			_add_world_sprite("res://assets/sprites/decor_house.png", p, 1.75, -8)
		for p in [Vector2(330, 250), Vector2(1840, 250), Vector2(390, 1030), Vector2(1830, 1010)]:
			_add_world_sprite("res://assets/sprites/decor_crystal.png", p, 1.7, -12)
	elif current_map == "forest_boars":
		for p in [Vector2(120, 130), Vector2(260, 230), Vector2(410, 120), Vector2(930, 160), Vector2(1110, 270), Vector2(180, 470), Vector2(1030, 490)]:
			_add_world_sprite("res://assets/sprites/decor_tree.png", p, 2.0, -12)
		for p in [Vector2(330, 430), Vector2(770, 210), Vector2(920, 380)]:
			_add_world_sprite("res://assets/sprites/decor_rock.png", p, 1.8, -12)
	elif current_map == "arcane_ruins":
		for p in [Vector2(180, 170), Vector2(1010, 165), Vector2(300, 475), Vector2(890, 430)]:
			_add_world_sprite("res://assets/sprites/decor_crystal.png", p, 2.0, -12)
		for p in [Vector2(420, 250), Vector2(760, 180), Vector2(1100, 510)]:
			_add_world_sprite("res://assets/sprites/decor_rock.png", p, 1.8, -12)
	elif current_map == "bat_cave":
		for p in [Vector2(160, 160), Vector2(340, 460), Vector2(720, 180), Vector2(950, 470), Vector2(1120, 240)]:
			_add_world_sprite("res://assets/sprites/decor_stalagmite.png", p, 2.0, -12)
		for p in [Vector2(250, 270), Vector2(825, 350), Vector2(1060, 570)]:
			_add_world_sprite("res://assets/sprites/decor_rock.png", p, 1.8, -12)
	elif current_map == "highland_pass":
		for p in [Vector2(260, 220), Vector2(520, 340), Vector2(1540, 280), Vector2(1800, 440), Vector2(420, 860), Vector2(1640, 930)]:
			_add_world_sprite("res://assets/sprites/decor_tree.png", p, 1.9, -12)
		for p in [Vector2(720, 230), Vector2(1240, 420), Vector2(880, 860), Vector2(1510, 720)]:
			_add_world_sprite("res://assets/sprites/decor_rock.png", p, 2.0, -12)
	elif current_map == "crystal_mines":
		for p in [Vector2(410, 260), Vector2(700, 670), Vector2(1180, 420), Vector2(1510, 760), Vector2(1760, 1030)]:
			_add_world_sprite("res://assets/sprites/decor_crystal.png", p, 2.2, -12)
		for p in [Vector2(300, 560), Vector2(1010, 910), Vector2(1620, 350)]:
			_add_world_sprite("res://assets/sprites/decor_stalagmite.png", p, 2.0, -12)
	elif current_map == "ember_fortress":
		for p in [Vector2(460, 300), Vector2(1560, 300), Vector2(470, 980), Vector2(1570, 980)]:
			_add_world_sprite("res://assets/sprites/decor_forge.png", p, 1.8, -12)
		for p in [Vector2(680, 430), Vector2(1320, 460), Vector2(790, 910), Vector2(1390, 900)]:
			_add_world_sprite("res://assets/sprites/decor_rock.png", p, 2.0, -12)

func _add_world_sprite(path: String, pos: Vector2, sprite_scale: float, z: int) -> Sprite2D:
	if _should_cast_world_shadow(path):
		var shadow_texture := load("res://assets/sprites/decor_shadow_soft.png") as Texture2D
		if shadow_texture != null:
			var shadow := Sprite2D.new()
			shadow.texture = shadow_texture
			shadow.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			shadow.position = pos + Vector2(0, 34 * sprite_scale)
			shadow.scale = Vector2(sprite_scale, sprite_scale) * 0.75
			shadow.z_index = z - 1
			shadow.modulate = Color(1, 1, 1, 0.72)
			world.add_child(shadow)
	var sprite := Sprite2D.new()
	sprite.texture = load(path)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.position = pos
	sprite.scale = Vector2(sprite_scale, sprite_scale)
	sprite.z_index = z
	world.add_child(sprite)
	_register_sprite_obstacle(path, pos, sprite_scale)
	return sprite

func _should_cast_world_shadow(path: String) -> bool:
	for token in ["decor_tree", "decor_house", "decor_forge", "decor_portal", "decor_crystal", "decor_rock", "decor_stalagmite", "decor_barrel", "decor_crate", "decor_well", "decor_healer_shrine"]:
		if path.find(token) >= 0:
			return true
	return false

func _register_sprite_obstacle(path: String, pos: Vector2, sprite_scale: float) -> void:
	var rect := Rect2()
	if path.find("decor_tree") >= 0:
		rect = Rect2(pos + Vector2(-24, 4) * sprite_scale, Vector2(48, 36) * sprite_scale)
	elif path.find("decor_house") >= 0:
		rect = Rect2(pos + Vector2(-44, -24) * sprite_scale, Vector2(88, 72) * sprite_scale)
	elif path.find("decor_forge") >= 0:
		rect = Rect2(pos + Vector2(-40, -26) * sprite_scale, Vector2(80, 74) * sprite_scale)
	elif path.find("decor_rock") >= 0 and sprite_scale >= 1.35:
		rect = Rect2(pos + Vector2(-18, -12) * sprite_scale, Vector2(36, 28) * sprite_scale)
	elif path.find("decor_stalagmite") >= 0 and sprite_scale >= 1.35:
		rect = Rect2(pos + Vector2(-18, -26) * sprite_scale, Vector2(36, 52) * sprite_scale)
	elif path.find("decor_crystal") >= 0 and sprite_scale >= 1.45:
		rect = Rect2(pos + Vector2(-18, -26) * sprite_scale, Vector2(36, 52) * sprite_scale)
	elif path.find("decor_barrel") >= 0 or path.find("decor_crate") >= 0:
		rect = Rect2(pos + Vector2(-16, -16) * sprite_scale, Vector2(32, 32) * sprite_scale)
	elif path.find("decor_well") >= 0 or path.find("decor_healer_shrine") >= 0:
		rect = Rect2(pos + Vector2(-24, -22) * sprite_scale, Vector2(48, 44) * sprite_scale)
	if rect.size != Vector2.ZERO:
		_register_solid_rect(rect)

func _register_solid_rect(rect: Rect2) -> void:
	if rect.size.x <= 0 or rect.size.y <= 0:
		return
	solid_obstacles.append(rect)

func _is_point_blocked(pos: Vector2) -> bool:
	if pos.x < 18 or pos.y < 18 or pos.x > current_map_size.x - 18 or pos.y > current_map_size.y - 18:
		return true
	for rect in solid_obstacles:
		if rect.has_point(pos):
			return true
	return false

func _enforce_world_collision() -> void:
	if player == null:
		return
	if last_valid_player_position == Vector2.ZERO:
		last_valid_player_position = player.global_position
	if _is_point_blocked(player.global_position):
		player.global_position = last_valid_player_position
	else:
		last_valid_player_position = player.global_position

func _add_world_rect(rect: Rect2, color: Color, z: int) -> ColorRect:
	var node := ColorRect.new()
	node.position = rect.position
	node.size = rect.size
	node.color = color
	node.z_index = z
	world.add_child(node)
	return node

func _draw_tiled_blob(path: String, center: Vector2, radius_x: float, radius_y: float, z: int, tile_size: int = 64, tint: Color = Color.WHITE) -> void:
	var textures := _tile_textures_for(path)
	if textures.is_empty():
		return
	var min_x := int(floor((center.x - radius_x) / tile_size)) * tile_size
	var max_x := int(ceil((center.x + radius_x) / tile_size)) * tile_size
	var min_y := int(floor((center.y - radius_y) / tile_size)) * tile_size
	var max_y := int(ceil((center.y + radius_y) / tile_size)) * tile_size
	for y in range(min_y, max_y + tile_size, tile_size):
		for x in range(min_x, max_x + tile_size, tile_size):
			var p := Vector2(x + tile_size * 0.5, y + tile_size * 0.5)
			var nx: float = (p.x - center.x) / maxf(1.0, radius_x)
			var ny: float = (p.y - center.y) / maxf(1.0, radius_y)
			var jitter := sin(float(x) * 0.021 + float(y) * 0.017) * 0.18
			if nx * nx + ny * ny <= 1.0 + jitter:
				var texture := textures[abs((x * 92821 + y * 68917)) % textures.size()] as Texture2D
				var sprite := Sprite2D.new()
				sprite.texture = texture
				sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
				sprite.position = p
				sprite.scale = Vector2(float(tile_size) / float(texture.get_width()), float(tile_size) / float(texture.get_height()))
				sprite.modulate = tint
				sprite.z_index = z
				world.add_child(sprite)

func _draw_path_points(path: String, points: Array, width: float, z: int) -> void:
	for i in range(points.size()):
		var point: Vector2 = points[i]
		_draw_tiled_blob(path, point, width * 0.62, width * 0.48, z)
		if i <= 0:
			continue
		var previous: Vector2 = points[i - 1]
		var distance := previous.distance_to(point)
		var steps: int = maxi(1, int(distance / 74.0))
		for s in range(1, steps + 1):
			var t := float(s) / float(steps + 1)
			var middle := previous.lerp(point, t)
			_draw_tiled_blob(path, middle, width * 0.50, width * 0.40, z)

func _draw_tiled_rect(path: String, rect: Rect2, tile_size: int, z: int) -> void:
	var textures := _tile_textures_for(path)
	if textures.is_empty():
		_add_world_rect(rect, Color("#303030"), z)
		return
	var cols := int(ceil(rect.size.x / float(tile_size)))
	var rows := int(ceil(rect.size.y / float(tile_size)))
	for y in range(rows):
		for x in range(cols):
			var texture := textures[abs((x * 92821 + y * 68917 + int(rect.position.x) + int(rect.position.y))) % textures.size()] as Texture2D
			var sprite := Sprite2D.new()
			sprite.texture = texture
			sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			sprite.position = rect.position + Vector2(x * tile_size + tile_size * 0.5, y * tile_size + tile_size * 0.5)
			sprite.scale = Vector2(float(tile_size) / float(texture.get_width()), float(tile_size) / float(texture.get_height()))
			sprite.z_index = z
			world.add_child(sprite)

func _tile_textures_for(path: String) -> Array:
	var variants := []
	match path:
		"res://assets/sprites/tile_grass.png":
			variants = ["res://assets/sprites/tile_grass_01.png", "res://assets/sprites/tile_grass_02.png", "res://assets/sprites/tile_grass_03.png", "res://assets/sprites/tile_grass_04.png"]
		"res://assets/sprites/tile_path.png":
			variants = ["res://assets/sprites/tile_path_01.png", "res://assets/sprites/tile_path_02.png", "res://assets/sprites/tile_path_03.png"]
		"res://assets/sprites/tile_water.png":
			variants = ["res://assets/sprites/tile_water_01.png", "res://assets/sprites/tile_water_02.png"]
		"res://assets/sprites/tile_stone.png":
			variants = ["res://assets/sprites/tile_stone_01.png", "res://assets/sprites/tile_stone_02.png"]
		"res://assets/sprites/tile_ruin.png":
			variants = ["res://assets/sprites/tile_ruin_01.png", "res://assets/sprites/tile_ruin_02.png"]
		"res://assets/sprites/tile_cave_floor.png":
			variants = ["res://assets/sprites/tile_cave_floor_01.png", "res://assets/sprites/tile_cave_floor_02.png"]
		"res://assets/sprites/tile_arcane.png":
			variants = ["res://assets/sprites/tile_arcane_01.png", "res://assets/sprites/tile_arcane_02.png"]
		"res://assets/sprites/tile_sand.png":
			variants = ["res://assets/sprites/tile_sand_01.png"]
		_:
			variants = [path]
	var result := []
	for variant_path in variants:
		var texture := load(str(variant_path)) as Texture2D
		if texture != null:
			result.append(texture)
	return result

func _spawn_ground_details() -> void:
	match current_map:
		"city_eldoria", "city_valdoria":
			_scatter_detail(["res://assets/sprites/decor_flower_patch.png", "res://assets/sprites/decor_grass_tuft.png", "res://assets/sprites/decor_leaf_patch.png"], 42, 0.62)
			_scatter_detail(["res://assets/sprites/decor_sign.png", "res://assets/sprites/decor_fence.png", "res://assets/sprites/decor_crate.png", "res://assets/sprites/decor_barrel.png"], 18, 0.9)
			_spawn_city_visual_props()
		"forest_boars", "highland_pass":
			_scatter_detail(["res://assets/sprites/decor_bush.png", "res://assets/sprites/decor_flower_patch.png", "res://assets/sprites/decor_grass_tuft.png", "res://assets/sprites/decor_rock.png", "res://assets/sprites/decor_leaf_patch.png", "res://assets/sprites/decor_stump.png"], 92, 0.78)
			_scatter_detail(["res://assets/sprites/decor_dirt_blend.png", "res://assets/sprites/decor_path_edge_grass.png"], 26, 0.9)
		"bat_cave", "crystal_mines":
			_scatter_detail(["res://assets/sprites/decor_rock.png", "res://assets/sprites/decor_stalagmite.png", "res://assets/sprites/decor_crystal.png"], 42, 0.72)
		"arcane_ruins":
			_scatter_detail(["res://assets/sprites/decor_crystal.png", "res://assets/sprites/decor_rock.png", "res://assets/sprites/decor_grass_tuft.png"], 46, 0.72)
		"ember_fortress":
			_scatter_detail(["res://assets/sprites/decor_rock.png", "res://assets/sprites/decor_fence.png"], 36, 0.74)

func _scatter_detail(paths: Array, count: int, scale_base: float) -> void:
	if paths.is_empty():
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = abs(current_map.hash()) + count * 97
	for i in range(count):
		var pos := Vector2(rng.randf_range(120, current_map_size.x - 120), rng.randf_range(140, current_map_size.y - 120))
		if _is_point_in_safe_zone(pos):
			continue
		var path := str(paths[rng.randi_range(0, paths.size() - 1)])
		var sprite := _add_world_sprite(path, pos, scale_base * rng.randf_range(0.82, 1.18), -89)
		sprite.modulate = Color(1, 1, 1, rng.randf_range(0.88, 1.0))

func _spawn_city_visual_props() -> void:
	if current_map == "city_eldoria":
		for p in [Vector2(1260, 635), Vector2(1300, 635), Vector2(1360, 610), Vector2(1450, 900), Vector2(1500, 910)]:
			_add_world_sprite("res://assets/sprites/decor_barrel.png", p, 0.85, -8)
		for p in [Vector2(1370, 920), Vector2(1540, 925), Vector2(700, 420)]:
			_add_world_sprite("res://assets/sprites/decor_crate.png", p, 0.95, -8)
		for p in [Vector2(520, 800), Vector2(610, 810)]:
			_add_world_sprite("res://assets/sprites/decor_healer_shrine.png", p, 0.95, -8)
		for p in [Vector2(780, 350), Vector2(880, 345)]:
			_add_world_sprite("res://assets/sprites/decor_magic_rune.png", p, 0.85, -9)
		for p in [Vector2(450, 610), Vector2(1660, 615), Vector2(1030, 500), Vector2(1210, 500)]:
			_add_world_sprite("res://assets/sprites/decor_torch.png", p, 0.9, -8)
	elif current_map == "city_valdoria":
		for p in [Vector2(590, 695), Vector2(660, 690), Vector2(1350, 700), Vector2(1430, 700)]:
			_add_world_sprite("res://assets/sprites/decor_crate.png", p, 0.95, -8)
		for p in [Vector2(1520, 965), Vector2(1610, 965), Vector2(1690, 960)]:
			_add_world_sprite("res://assets/sprites/decor_barrel.png", p, 0.9, -8)
		for p in [Vector2(735, 915), Vector2(840, 920)]:
			_add_world_sprite("res://assets/sprites/decor_healer_shrine.png", p, 0.9, -8)
		for p in [Vector2(520, 480), Vector2(1260, 500), Vector2(1540, 760), Vector2(1700, 760)]:
			_add_world_sprite("res://assets/sprites/decor_torch.png", p, 0.9, -8)

func _add_world_label(text: String, pos: Vector2, color: Color = Color.WHITE) -> Label:
	var label := Label.new()
	label.text = text
	label.position = pos
	label.z_index = 60
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color.BLACK)
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	world.add_child(label)
	return label

func _spawn_npcs(map_data: Dictionary) -> void:
	var city_house_offsets := [Vector2(82, -18), Vector2(86, -10), Vector2(84, -16), Vector2(90, -14), Vector2(78, -12)]
	var npc_index := 0
	for npc_data in map_data.get("npcs", []):
		var npc: Npc = NPC_SCENE.instantiate()
		npc.add_to_group("npcs")
		world.add_child(npc)
		npc.setup(npc_data)
		var pos: Array = npc_data.get("pos", [100, 100])
		npc.global_position = Vector2(float(pos[0]), float(pos[1]))
		if current_map == "city_eldoria" or current_map == "city_valdoria":
			var house := _add_world_sprite("res://assets/sprites/decor_house.png", npc.global_position + city_house_offsets[npc_index % city_house_offsets.size()], 1.5, -7)
			house.modulate = Color(0.95, 0.95, 0.95, 0.98)
			npc_index += 1
		npc.body_entered.connect(func(body: Node) -> void:
			if body == player:
				selected_npc = npc
				_flash("OK: falar com " + npc.npc_name)
		)
		npc.body_exited.connect(func(body: Node) -> void:
			if body == player and selected_npc == npc:
				selected_npc = null
		)

func _spawn_portals(map_data: Dictionary) -> void:
	for portal_data in map_data.get("portals", []):
		var portal := Area2D.new()
		portal.set_meta("target", str(portal_data.get("target", "city_eldoria")))
		portal.set_meta("label", str(portal_data.get("label", "Portal")))
		portal.set_meta("requires_boss_clear", bool(portal_data.get("requires_boss_clear", false)))
		portal.set_meta("boss_enemy", str(portal_data.get("boss_enemy", "")))
		portal.set_meta("target_spawn", portal_data.get("spawn", []))
		var shape := CollisionShape2D.new()
		var rect_shape := RectangleShape2D.new()
		rect_shape.size = Vector2(80, 44)
		shape.shape = rect_shape
		portal.add_child(shape)
		var visual := Sprite2D.new()
		visual.texture = load("res://assets/sprites/decor_portal.png")
		visual.scale = Vector2(1.8, 1.8)
		visual.z_index = -5
		portal.add_child(visual)
		var label := Label.new()
		label.text = str(portal_data.get("label", "Portal"))
		if bool(portal_data.get("requires_boss_clear", false)):
			label.text += " *"
		label.position = Vector2(-28, -14)
		portal.add_child(label)
		var pos: Array = portal_data.get("pos", [100, 100])
		portal.global_position = Vector2(float(pos[0]), float(pos[1]))
		world.add_child(portal)
		portal.body_entered.connect(func(body: Node) -> void:
			if body == player:
				selected_portal = portal
				_flash("OK: entrar em " + label.text)
		)
		portal.body_exited.connect(func(body: Node) -> void:
			if body == player and selected_portal == portal:
				selected_portal = null
		)

func _spawn_safe_zones(map_data: Dictionary) -> void:
	if bool(map_data.get("safe", false)):
		return
	for zone_data in map_data.get("safe_zones", []):
		var pos_arr: Array = zone_data.get("pos", [0, 0])
		var radius: float = float(zone_data.get("radius", 120))
		var center := Vector2(float(pos_arr[0]), float(pos_arr[1]))
		var ring := Line2D.new()
		ring.width = 3.0
		ring.default_color = Color(0.24, 0.95, 0.42, 0.52)
		ring.closed = true
		ring.z_index = -20
		for i in range(56):
			var angle := TAU * float(i) / 56.0
			ring.add_point(Vector2(cos(angle), sin(angle)) * radius)
		ring.global_position = center
		world.add_child(ring)
		_add_world_label("Zona Segura", center + Vector2(-48, -radius - 18), Color("#8dff9f"))
		safe_zone_nodes.append({"center": center, "radius": radius})

func _is_point_in_safe_zone(pos: Vector2) -> bool:
	for zone in safe_zone_nodes:
		var center: Vector2 = zone.get("center", Vector2.ZERO)
		var radius: float = float(zone.get("radius", 0.0))
		if pos.distance_to(center) <= radius:
			return true
	return false

func _spawn_enemies(map_data: Dictionary) -> void:
	for spawn in map_data.get("spawns", []):
		for i in range(int(spawn.get("count", 1))):
			_spawn_enemy_from_spawn(spawn)

func _spawn_enemy_from_spawn(spawn: Dictionary) -> void:
	var enemy_name := str(spawn.get("enemy", ""))
	if enemy_name.is_empty():
		return
	var enemy: Enemy = ENEMY_SCENE.instantiate()
	world.add_child(enemy)
	enemy.setup(enemy_name, enemies_db.get(enemy_name, {}), player)
	enemy.safe_zone_checker = Callable(self, "_is_point_in_safe_zone")
	enemy.obstacle_checker = Callable(self, "_is_point_blocked")
	enemy.global_position = _random_enemy_spawn_position(spawn)
	enemy.set_meta("spawn_data", spawn.duplicate(true))
	enemy.set_meta("spawn_map", current_map)
	if bool(spawn.get("boss", false)):
		enemy.add_to_group("bosses")
	enemy.killed.connect(_enemy_killed)

func _random_enemy_spawn_position(spawn: Dictionary = {}) -> Vector2:
	var zone: Array = spawn.get("zone", [])
	var pos := Vector2(randf_range(120, current_map_size.x - 120), randf_range(120, current_map_size.y - 120))
	if zone.size() >= 4:
		pos = Vector2(randf_range(float(zone[0]), float(zone[0]) + float(zone[2])), randf_range(float(zone[1]), float(zone[1]) + float(zone[3])))
	var retries := 0
	while (_is_point_in_safe_zone(pos) or _is_point_blocked(pos)) and retries < 28:
		if zone.size() >= 4:
			pos = Vector2(randf_range(float(zone[0]), float(zone[0]) + float(zone[2])), randf_range(float(zone[1]), float(zone[1]) + float(zone[3])))
		else:
			pos = Vector2(randf_range(120, current_map_size.x - 120), randf_range(120, current_map_size.y - 120))
		retries += 1
	return pos

func _enemy_respawn_delay(enemy_name: String, spawn_data: Dictionary) -> float:
	if spawn_data.has("respawn"):
		return max(4.0, float(spawn_data.get("respawn", 10.0)))
	var data: Dictionary = enemies_db.get(enemy_name, {})
	var level_value := int(data.get("level", 1))
	var is_boss := bool(data.get("boss", false)) or bool(spawn_data.get("boss", false))
	if is_boss:
		return 80.0 + float(level_value) * 5.0
	return clamp(6.0 + float(level_value) * 2.5, 8.0, 80.0)

func _schedule_enemy_respawn(enemy_name: String, spawn_data: Dictionary, map_id: String) -> void:
	var delay := _enemy_respawn_delay(enemy_name, spawn_data)
	await get_tree().create_timer(delay).timeout
	if current_map != map_id or player == null:
		return
	_spawn_enemy_from_spawn(spawn_data)

func _is_portal_blocked_by_boss(portal: Area2D) -> bool:
	if portal == null or not bool(portal.get_meta("requires_boss_clear", false)):
		return false
	var boss_name := str(portal.get_meta("boss_enemy", ""))
	for node in get_tree().get_nodes_in_group("bosses"):
		if node is Enemy and is_instance_valid(node):
			var enemy := node as Enemy
			if enemy.vida > 0 and (boss_name.is_empty() or enemy.enemy_name == boss_name):
				return true
	return false

func _player_attack(power: float, radius: float, skill_id: String) -> void:
	if player.in_safe_zone:
		_flash_red("Nao pode atacar em zona segura")
		return
	var multiplier := power
	if player.class_name_selected == "Arqueiro":
		multiplier *= CombatSystem.roll_critical(0.10, 1.5)
	var enemy := _get_closest_enemy_in_range(radius)
	if enemy == null:
		_flash("Ataque errou: aproxime-se ou mire melhor.")
		return
	if _is_point_in_safe_zone(enemy.global_position):
		_flash_red("Nao pode atacar em zona segura")
		return
	_dismount_current_mount("Voce desceu da montaria para lutar.")
	_set_current_target(enemy)
	pet_allowed_target = enemy
	if skill_id == "basic_attack":
		_spawn_basic_attack_effect(enemy)
	else:
		_spawn_skill_projectile(skill_id, enemy)
	multiplier *= player.damage_multiplier_for(skill_id)
	var attack_value: float = player.get_attack_value()
	if player.class_name_selected == "Arqueiro" or skill_id in ["precise_shot", "arrow_rain", "stun_shot"]:
		attack_value += player.ataque_distancia
	if skill_id in ["fireball", "arcane_blast", "blue_meteor", "burning_fireball", "fire_hurricane"]:
		attack_value += player.ataque_magico
	var damage := CombatSystem.physical_damage(attack_value, enemy.defesa, multiplier, player.physical_damage_pct)
	enemy.receive_damage(damage)
	_spawn_floating_text(enemy.global_position + Vector2(0, -34), "-%d" % damage, Color("#ff4c4c"))
	var skill_data := _skill_data(skill_id)
	if skill_id == "burning_fireball":
		enemy.apply_burn(int(skill_data.get("burn_damage", 4)), float(skill_data.get("burn_duration", 4.0)))
		_spawn_floating_text(enemy.global_position + Vector2(0, -52), "queimando", Color("#ff9a38"))
	if skill_id == "stun_shot":
		enemy.apply_stun(float(skill_data.get("stun_duration", 2.0)))
		_spawn_floating_text(enemy.global_position + Vector2(0, -52), "stun", Color("#8fd7ff"))
	player.on_hit_enemy(skill_id)

func _player_area_attack(power: float, radius: float, skill_id: String) -> void:
	if player.in_safe_zone:
		_flash_red("Nao pode atacar em zona segura")
		return
	var hits := 0
	var center := player.global_position
	if skill_id in ["arrow_rain", "fire_hurricane"]:
		var target := _get_closest_enemy_in_range(_auto_target_radius())
		if target != null:
			if _is_point_in_safe_zone(target.global_position):
				_flash_red("Nao pode atacar em zona segura")
				return
			center = target.global_position
			_set_current_target(target)
			pet_allowed_target = target
	_dismount_current_mount("Voce desceu da montaria para lutar.")
	_spawn_area_effect(center, radius, skill_id)
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if _is_point_in_safe_zone(enemy.global_position):
			continue
		if center.distance_to(enemy.global_position) <= radius:
			var attack_value: float = player.get_attack_value()
			if skill_id == "arrow_rain":
				attack_value += player.ataque_distancia
			if skill_id in ["arcane_blast", "fire_hurricane"]:
				attack_value += player.ataque_magico
			var damage := CombatSystem.physical_damage(attack_value, enemy.defesa, power * player.damage_multiplier_for(skill_id), player.physical_damage_pct)
			enemy.receive_damage(damage)
			_spawn_floating_text(enemy.global_position + Vector2(0, -34), "-%d" % damage, Color("#ff4c4c"))
			player.on_hit_enemy(skill_id)
			if pet_allowed_target == null:
				pet_allowed_target = enemy
			hits += 1
	if skill_id == "fire_hurricane":
		_start_area_dot(center, radius, skill_id, power, 3.0, 0.75)
	elif skill_id == "arrow_rain":
		_start_area_dot(center, radius, skill_id, power * 0.7, 1.5, 0.5)
	_flash("Habilidade acertou %d alvo(s)." % hits)

func _get_closest_enemy_in_range(radius: float) -> Enemy:
	var best: Enemy = null
	var best_distance: float = INF
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Enemy
		if enemy == null or enemy.vida <= 0:
			continue
		var distance: float = player.global_position.distance_to(enemy.global_position)
		if distance <= radius and distance < best_distance:
			best = enemy
			best_distance = distance
	return best

func _update_current_target() -> void:
	if player == null:
		_set_current_target(null)
		return
	var target_radius := _auto_target_radius()
	_set_current_target(_get_closest_enemy_in_range(target_radius))

func _auto_target_radius() -> float:
	match player.class_name_selected:
		"Arqueiro":
			return 280.0
		"Mago":
			return 260.0
	return player.alcance

func _skill_data(skill_id: String) -> Dictionary:
	if player == null:
		return {}
	var skills: Array = player.class_data.get("skills", [])
	for entry in skills:
		if typeof(entry) == TYPE_DICTIONARY and str(entry.get("id", "")) == skill_id:
			return entry
	return {}

func _start_area_dot(center: Vector2, radius: float, skill_id: String, power: float, duration: float, tick_interval: float) -> void:
	var elapsed := 0.0
	while elapsed < duration and player != null:
		await get_tree().create_timer(tick_interval).timeout
		if player.in_safe_zone:
			return
		elapsed += tick_interval
		_spawn_area_effect(center, radius, skill_id)
		for node in get_tree().get_nodes_in_group("enemies"):
			var enemy := node as Enemy
			if enemy == null or enemy.vida <= 0:
				continue
			if _is_point_in_safe_zone(enemy.global_position):
				continue
			if center.distance_to(enemy.global_position) > radius:
				continue
			var attack_value: float = player.get_attack_value()
			if skill_id == "arrow_rain":
				attack_value += player.ataque_distancia
			elif skill_id == "fire_hurricane":
				attack_value += player.ataque_magico
			var damage := CombatSystem.physical_damage(attack_value, enemy.defesa, power * player.damage_multiplier_for(skill_id), player.physical_damage_pct)
			enemy.receive_damage(damage)
			_spawn_floating_text(enemy.global_position + Vector2(0, -34), "-%d" % damage, Color("#ff7c3f") if skill_id == "fire_hurricane" else Color("#e8f0ff"))
			player.on_hit_enemy(skill_id)

func _set_current_target(enemy: Enemy) -> void:
	if current_target != null and is_instance_valid(current_target) and current_target != enemy:
		current_target.set_targeted(false)
	current_target = enemy
	if current_target != null and is_instance_valid(current_target):
		current_target.set_targeted(true)

func _player_dash(distance: float, skill_id: String) -> void:
	var start: Vector2 = player.global_position
	var dir: Vector2 = -player.global_position.direction_to(get_global_mouse_position())
	if dir.length() == 0:
		dir = Vector2.DOWN
	player.global_position += dir.normalized() * distance
	_spawn_dash_effect(start, player.global_position, skill_id)

func _player_self_effect(skill_id: String) -> void:
	if skill_id in ["war_cry", "mystic_shield", "hero_hour", "agility"]:
		if skill_id in ["hero_hour"]:
			_dismount_current_mount("Voce desceu da montaria para lutar.")
		_spawn_self_effect(skill_id)

func _spawn_basic_attack_effect(enemy: Enemy) -> void:
	if enemy == null or not is_instance_valid(enemy):
		return
	match player.class_name_selected:
		"Mago":
			var orb := Sprite2D.new()
			orb.texture = load("res://assets/sprites/drop_gem.png")
			orb.scale = Vector2(0.34, 0.34)
			orb.modulate = Color("#8dc7ff")
			orb.global_position = player.global_position
			orb.z_index = 84
			world.add_child(orb)
			var tween_orb := create_tween()
			tween_orb.tween_property(orb, "global_position", enemy.global_position, 0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			tween_orb.parallel().tween_property(orb, "modulate", Color(1, 1, 1, 0), 0.15)
			tween_orb.tween_callback(func() -> void:
				if is_instance_valid(orb):
					orb.queue_free()
			)
		"Arqueiro":
			var arrow := Sprite2D.new()
			arrow.texture = load("res://assets/sprites/icon_skill_precise_shot.png")
			arrow.scale = Vector2(0.46, 0.46)
			arrow.global_position = player.global_position
			arrow.z_index = 84
			world.add_child(arrow)
			arrow.rotation = (enemy.global_position - player.global_position).angle()
			var tween_arrow := create_tween()
			tween_arrow.tween_property(arrow, "global_position", enemy.global_position, 0.12).set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN)
			tween_arrow.parallel().tween_property(arrow, "modulate", Color(1, 1, 1, 0), 0.12)
			tween_arrow.tween_callback(func() -> void:
				if is_instance_valid(arrow):
					arrow.queue_free()
			)
		_:
			var slash := Line2D.new()
			slash.width = 5.0
			slash.default_color = Color("#ffe3ad")
			slash.z_index = 83
			slash.add_point(Vector2(-14, -12))
			slash.add_point(Vector2(14, 12))
			slash.global_position = enemy.global_position + Vector2(0, -8)
			world.add_child(slash)
			var tween_slash := create_tween()
			tween_slash.tween_property(slash, "modulate", Color(1, 1, 1, 0), 0.18)
			tween_slash.tween_callback(func() -> void:
				if is_instance_valid(slash):
					slash.queue_free()
			)

func _spawn_skill_projectile(skill_id: String, enemy: Enemy) -> void:
	if enemy == null or not is_instance_valid(enemy):
		return
	var icon_path := str(SKILL_ICON_BY_ID.get(skill_id, ""))
	if icon_path.is_empty():
		return
	var effect := Sprite2D.new()
	effect.texture = load(icon_path)
	effect.global_position = player.global_position
	effect.scale = Vector2(0.55, 0.55)
	effect.z_index = 80
	world.add_child(effect)
	var impact_pos := enemy.global_position
	var tween := create_tween()
	tween.tween_property(effect, "global_position", impact_pos, 0.22).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(effect, "rotation", effect.rotation + TAU, 0.22)
	tween.tween_callback(func() -> void:
		_spawn_impact_effect(impact_pos, skill_id)
		if is_instance_valid(effect):
			effect.queue_free()
	)

func _spawn_impact_effect(pos: Vector2, skill_id: String) -> void:
	var icon_path := str(SKILL_ICON_BY_ID.get(skill_id, ""))
	if icon_path.is_empty():
		return
	var hit := Sprite2D.new()
	hit.texture = load(icon_path)
	hit.global_position = pos
	hit.scale = Vector2(0.35, 0.35)
	hit.modulate = Color(1, 1, 1, 0.82)
	hit.z_index = 81
	world.add_child(hit)
	var tween := create_tween()
	tween.tween_property(hit, "scale", Vector2(1.15, 1.15), 0.28)
	tween.parallel().tween_property(hit, "modulate", Color(1, 1, 1, 0), 0.28)
	tween.tween_callback(func() -> void:
		if is_instance_valid(hit):
			hit.queue_free()
	)

func _spawn_area_effect(center: Vector2, radius: float, skill_id: String) -> void:
	var line := Line2D.new()
	line.width = 4.0
	line.closed = true
	line.default_color = _skill_color(skill_id)
	line.z_index = 79
	for i in range(40):
		var angle := TAU * float(i) / 40.0
		line.add_point(Vector2(cos(angle), sin(angle)) * radius)
	line.global_position = center
	line.scale = Vector2(0.18, 0.18)
	world.add_child(line)
	var tween := create_tween()
	tween.tween_property(line, "scale", Vector2.ONE, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(line, "modulate", Color(1, 1, 1, 0), 0.36)
	tween.tween_callback(func() -> void:
		if is_instance_valid(line):
			line.queue_free()
	)

func _spawn_self_effect(skill_id: String) -> void:
	var icon_path := str(SKILL_ICON_BY_ID.get(skill_id, ""))
	if icon_path.is_empty():
		return
	var effect := Sprite2D.new()
	effect.texture = load(icon_path)
	effect.global_position = player.global_position + Vector2(0, -34)
	effect.scale = Vector2(0.55, 0.55)
	effect.z_index = 90
	world.add_child(effect)
	var tween := create_tween()
	tween.tween_property(effect, "global_position", effect.global_position + Vector2(0, -28), 0.48)
	tween.parallel().tween_property(effect, "modulate", Color(1, 1, 1, 0), 0.48)
	tween.tween_callback(func() -> void:
		if is_instance_valid(effect):
			effect.queue_free()
	)
	if skill_id == "mystic_shield":
		_spawn_area_effect(player.global_position, 52, skill_id)

func _spawn_dash_effect(from: Vector2, to: Vector2, skill_id: String) -> void:
	var line := Line2D.new()
	line.width = 5.0
	line.default_color = _skill_color(skill_id)
	line.z_index = 75
	line.add_point(from)
	line.add_point(to)
	world.add_child(line)
	var tween := create_tween()
	tween.tween_property(line, "modulate", Color(1, 1, 1, 0), 0.28)
	tween.tween_callback(func() -> void:
		if is_instance_valid(line):
			line.queue_free()
	)

func _skill_color(skill_id: String) -> Color:
	match skill_id:
		"fireball", "burning_fireball", "fire_hurricane":
			return Color("#ff8d2e")
		"arcane_blast", "mystic_shield", "blue_meteor":
			return Color("#5ca8ff")
		"arrow_rain", "precise_shot", "quick_jump", "agility", "stun_shot":
			return Color("#8eea77")
		"war_cry", "heavy_slash", "blade_spin", "hero_hour", "death_area", "soul_reaper":
			return Color("#ffe4a3")
		"fire_hurricane":
			return Color("#9a63ff")
	return Color("#dce7ef")

func _enemy_killed(enemy: Enemy) -> void:
	if pet_allowed_target == enemy:
		pet_allowed_target = null
	var spawn_data: Dictionary = enemy.get_meta("spawn_data", {})
	var spawn_map := str(enemy.get_meta("spawn_map", current_map))
	var result := drop_system.roll(enemy.enemy_name)
	player.gain_xp(int(result["xp"]))
	player.on_enemy_killed()
	quest_system.register_kill(enemy.enemy_name)
	var gold := int(result["ouro"])
	if gold > 0:
		_spawn_coin_drop(gold, enemy.global_position + Vector2(randf_range(-18, 18), randf_range(-18, 18)))
	for item_name in result["items"]:
		_spawn_drop(str(item_name), enemy.global_position + Vector2(randf_range(-24, 24), randf_range(-24, 24)))
	_flash("+%d XP, moedas e drops no chao" % int(result["xp"]))
	if not spawn_data.is_empty():
		_schedule_enemy_respawn(enemy.enemy_name, spawn_data, spawn_map)

func _spawn_coin_drop(amount: int, pos: Vector2) -> void:
	var drop: ItemDrop = DROP_SCENE.instantiate()
	world.add_child(drop)
	drop.setup_coin(amount)
	drop.global_position = pos
	drop.body_entered.connect(func(body: Node) -> void:
		if body == player:
			_collect_drop(drop)
	)

func _spawn_drop(item_name: String, pos: Vector2) -> void:
	var drop: ItemDrop = DROP_SCENE.instantiate()
	world.add_child(drop)
	drop.setup(item_name, 1)
	drop.global_position = pos
	drop.body_entered.connect(func(body: Node) -> void:
		if body == player:
			_collect_drop(drop)
	)

func _collect_nearby_drops(delta: float) -> void:
	for node in get_tree().get_nodes_in_group("drops"):
		var drop := node as ItemDrop
		if drop == null or not is_instance_valid(drop) or not drop.can_auto_collect():
			continue
		var distance := player.global_position.distance_to(drop.global_position)
		if distance <= DROP_PICKUP_RADIUS:
			drop.global_position = drop.global_position.move_toward(player.global_position, DROP_MAGNET_SPEED * delta)
		if distance <= DROP_COLLECT_RADIUS:
			_collect_drop(drop)

func _collect_drop(drop: ItemDrop) -> bool:
	if drop == null or not is_instance_valid(drop):
		return false
	if drop.is_coin:
		player.ouro += drop.amount
		drop.queue_free()
		_flash("+%d ouro" % drop.amount)
		return true
	if player.inventory.add_item(drop.item_name, drop.amount):
		quest_system.register_collect(drop.item_name, drop.amount)
		drop.queue_free()
		_flash("Coletado: " + drop.item_name)
		return true
	return false

func _interact() -> void:
	if selected_portal != null:
		if _is_portal_blocked_by_boss(selected_portal):
			var boss_name := str(selected_portal.get_meta("boss_enemy"))
			_flash_red("Derrote %s para liberar este portal." % boss_name)
			return
		var spawn := Vector2.ZERO
		var spawn_data = selected_portal.get_meta("target_spawn")
		if typeof(spawn_data) == TYPE_ARRAY and spawn_data.size() >= 2:
			spawn = Vector2(float(spawn_data[0]), float(spawn_data[1]))
		_load_map(str(selected_portal.get_meta("target")), spawn)
		return
	if selected_npc == null:
		_hide_panel()
		return
	match selected_npc.role:
		"healer":
			_use_healer()
		"shop":
			_show_shop()
		"forge":
			_show_forge()
		"rare_forge":
			_show_forge("rare")
		"pet_shop":
			_show_pet_shop()
		"mount_shop":
			_show_mount_shop()
		"class_master":
			_flash("Arion: treine usando ataque, defesa e velocidade em combate real.")
		"quest":
			_handle_quest_npc(selected_npc.quest_id)

func _use_healer() -> void:
	var cost := 0 if player.level <= 5 else 10
	if player.ouro >= cost:
		player.ouro -= cost
		player.vida = player.vida_max
		player.mana = player.mana_max
		player.stats_changed.emit()
		_flash("Helena curou voce.")
	else:
		_flash("Helena cobra 10 ouro depois do level 5.")

func _handle_quest_npc(quest_id: String) -> void:
	if selected_npc != null:
		_show_npc_bubble(selected_npc, _quest_intro_text(quest_id))
	if quest_system.completed.has(quest_id):
		_show_quest_dialog(quest_id, "Missao ja concluida. Obrigado pela ajuda, aventureiro.", false)
	elif quest_system.active.has(quest_id) and quest_system.is_ready(quest_id):
		var rewards := quest_system.complete(quest_id)
		player.gain_xp(int(rewards.get("xp", 0)))
		player.ouro += int(rewards.get("ouro", 0))
		for item_name in rewards.get("items", []):
			player.inventory.add_item(str(item_name), 1)
		_show_quest_dialog(quest_id, "Voce voltou com tudo que eu precisava. Aqui esta sua recompensa.", false)
	elif quest_system.active.has(quest_id):
		_show_quest_dialog(quest_id, _quest_intro_text(quest_id), false)
	else:
		_show_quest_dialog(quest_id, _quest_intro_text(quest_id), true)

func _show_npc_bubble(npc: Npc, text: String) -> void:
	if dialog_bubble != null and is_instance_valid(dialog_bubble):
		dialog_bubble.queue_free()
	dialog_bubble = PanelContainer.new()
	dialog_bubble.z_index = 150
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.02, 0.025, 0.88)
	style.border_color = Color("#d8b45a")
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	dialog_bubble.add_theme_stylebox_override("panel", style)
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(260, 54)
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", Color("#fff3cf"))
	dialog_bubble.add_child(label)
	world.add_child(dialog_bubble)
	dialog_bubble.global_position = npc.global_position + Vector2(-130, -104)
	get_tree().create_timer(5.0).timeout.connect(func() -> void:
		if dialog_bubble != null and is_instance_valid(dialog_bubble):
			dialog_bubble.queue_free()
			dialog_bubble = null
	)

func _quest_intro_text(quest_id: String) -> String:
	match quest_id:
		"furia_javalis":
			return "Preciso de couro e presas para preparar uma pocao de cura para minha esposa. Traga os materiais e eu lhe recompensarei."
		"cristal_quebrado":
			return "As ruinas estao liberando orbes arcanos instaveis. Derrote os espiritos, recolha fragmentos e salve Eldoria."
		"sombras_caverna":
			return "A caverna acordou. Morcegos e aranhas estao atacando viajantes. Limpe o caminho e traga asas como prova."
		"tutorial_forest":
			return "Primeiro conheca a floresta. Derrote monstros fracos, recolha moedas e volte mais forte."
		"tutorial_ruins":
			return "As ruinas mostram como inimigos magicos lutam. Explore com cuidado e complete seu treino."
		"tutorial_cave":
			return "A caverna ensina perigo real: veneno, mobs rapidos e alvos mais fortes. Va preparado."
	return "Tenho uma tarefa para voce. Aceite a missao e acompanhe os objetivos."

func _show_quest_dialog(quest_id: String, intro: String, can_accept: bool) -> void:
	var quest: Dictionary = quest_system.quests.get(quest_id, {})
	var title := str(quest.get("title", "Missao"))
	var box := _start_modal(title, "quest_dialog")
	box.add_child(_panel_label(intro, 15, Color("#fff3cf")))
	box.add_child(_panel_label(quest_system.quest_text(quest_id), 14, Color("#d7e3f1")))
	var actions := HBoxContainer.new()
	box.add_child(actions)
	if can_accept:
		var accept := Button.new()
		accept.text = "Aceitar"
		_style_panel_button(accept)
		accept.pressed.connect(func() -> void:
			quest_system.accept(quest_id)
			_flash("Missao aceita: " + title)
			_show_quests()
		)
		actions.add_child(accept)
	var quests_btn := Button.new()
	quests_btn.text = "Missoes"
	_style_panel_button(quests_btn)
	quests_btn.pressed.connect(_show_quests)
	actions.add_child(quests_btn)

func _show_shop() -> void:
	if panel.visible and current_panel == "shop":
		_hide_panel()
		return
	var box := _start_modal("Loja de Borin", "shop")
	box.add_child(_panel_label("Ouro: %d moedas" % player.ouro, 17, Color("#ffd36b")))
	for item_name in NpcShop.GOODS:
		var item := item_db.get_item(item_name)
		var btn := Button.new()
		btn.text = "%s - %d ouro" % [item_name, int(item.get("price", 0))]
		_style_panel_button(btn)
		btn.pressed.connect(func() -> void:
			if NpcShop.buy(player, item_db, item_name):
				_flash("Comprado: " + item_name)
				_update_potion_buttons()
				_show_shop()
			else:
				_flash("Ouro insuficiente.")
		)
		box.add_child(btn)

func _show_pet_shop() -> void:
	if panel.visible and current_panel == "pet_shop":
		_hide_panel()
		return
	_ensure_local_companion_state()
	var box := _start_modal("Mercado de Pets de Valdoria", "pet_shop")
	box.add_child(_panel_label("Ouro: %d moedas" % player.ouro, 17, Color("#ffd36b")))
	box.add_child(_panel_label("Pets atacam seu alvo automatico e aplicam passivas/debuffs.", 13, Color("#cfd6df")))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	grid.custom_minimum_size = Vector2(840, 400)
	box.add_child(grid)
	for def in pet_definitions:
		if typeof(def) != TYPE_DICTIONARY:
			continue
		var code := str(def.get("code", ""))
		var owned := not _owned_entry("pets_state", "pets", code).is_empty()
		var card := _market_card()
		grid.add_child(card)
		var row := HBoxContainer.new()
		row.custom_minimum_size = Vector2(398, 130)
		card.add_child(row)
		var icon := TextureRect.new()
		icon.texture = load(_pet_icon_path(code))
		icon.custom_minimum_size = Vector2(76, 76)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_SCALE
		row.add_child(icon)
		var info := VBoxContainer.new()
		info.custom_minimum_size = Vector2(280, 128)
		row.add_child(info)
		info.add_child(_panel_label("%s  |  %s" % [str(def.get("name", code)), str(def.get("rarity", "common")).to_upper()], 15, Color.WHITE))
		info.add_child(_panel_label("%d ouro  |  Dano %d" % [int(def.get("price", 0)), int(def.get("attack", 1))], 13, Color("#ffd36b")))
		info.add_child(_panel_label("Passiva: %s" % str(def.get("passive_desc", "")), 12, Color("#d8e6f2")))
		info.add_child(_panel_label("Ataque: %s" % str(def.get("active_desc", "")), 12, Color("#c7d6e5")))
		var buy := Button.new()
		buy.text = "Equipar" if owned else "Comprar"
		_style_panel_button(buy)
		buy.pressed.connect(func() -> void:
			if _buy_local_pet(code):
				_flash(("Equipado: " if owned else "Comprado: ") + str(def.get("name", code)))
				_show_pet_shop()
			else:
				_flash("Ouro insuficiente para comprar este pet.")
		)
		info.add_child(buy)

func _show_mount_shop() -> void:
	if panel.visible and current_panel == "mount_shop":
		_hide_panel()
		return
	_ensure_local_companion_state()
	var box := _start_modal("Mercado de Montarias", "mount_shop")
	box.add_child(_panel_label("Ouro: %d moedas" % player.ouro, 17, Color("#ffd36b")))
	box.add_child(_panel_label("Montarias sao exclusivas para velocidade. Raras custam mais e correm mais.", 13, Color("#cfd6df")))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	grid.custom_minimum_size = Vector2(840, 360)
	box.add_child(grid)
	for def in mount_definitions:
		if typeof(def) != TYPE_DICTIONARY:
			continue
		var code := str(def.get("code", ""))
		var owned := not _owned_entry("mounts_state", "mounts", code).is_empty()
		var card := _market_card()
		grid.add_child(card)
		var row := HBoxContainer.new()
		row.custom_minimum_size = Vector2(398, 118)
		card.add_child(row)
		var icon := TextureRect.new()
		icon.texture = load(_mount_icon_path(code))
		icon.custom_minimum_size = Vector2(76, 76)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_SCALE
		row.add_child(icon)
		var info := VBoxContainer.new()
		info.custom_minimum_size = Vector2(280, 116)
		row.add_child(info)
		info.add_child(_panel_label("%s  |  %s" % [str(def.get("name", code)), str(def.get("rarity", "common")).to_upper()], 15, Color.WHITE))
		info.add_child(_panel_label("%d ouro  |  +%d%% velocidade" % [int(def.get("price", 0)), int(round(float(def.get("speed_bonus", 0.0)) * 100.0))], 13, Color("#ffd36b")))
		info.add_child(_panel_label(str(def.get("desc", "")), 12, Color("#c8d3e0")))
		var buy := Button.new()
		buy.text = "Montar" if owned else "Comprar"
		_style_panel_button(buy)
		buy.pressed.connect(func() -> void:
			if _buy_local_mount(code):
				_flash(("Montado: " if owned else "Comprado: ") + str(def.get("name", code)))
				_show_mount_shop()
			else:
				_flash("Ouro insuficiente para comprar esta montaria.")
		)
		info.add_child(buy)

func _market_card() -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(410, 140)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.045, 0.052, 0.068, 0.96)
	style.border_color = Color("#8a6a2f")
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	card.add_theme_stylebox_override("panel", style)
	return card

func _show_forge(tier: String = "basic") -> void:
	if panel.visible and current_panel == "forge":
		_hide_panel()
		return
	var title := "Forja Rara de Valdoria" if tier == "rare" else "Forja"
	var box := _start_modal(title, "forge")
	box.add_child(_panel_label("Ouro: %d moedas" % player.ouro, 17, Color("#ffd36b")))
	box.add_child(_panel_label("Use materiais dos monstros e moedas para criar equipamentos.", 14, Color("#cfd6df")))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(840, 405)
	box.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	var recipes := CraftingSystem.load_recipes()
	for recipe_name in recipes.keys():
		var recipe_id := str(recipe_name)
		var recipe: Dictionary = recipes[recipe_id]
		var recipe_tier := str(recipe.get("tier", "basic"))
		if tier == "rare" and recipe_tier != "rare":
			continue
		if tier != "rare" and recipe_tier == "rare":
			continue
		var row := HBoxContainer.new()
		row.custom_minimum_size = Vector2(820, 56)
		var data := item_db.get_item(str(recipe.get("result", recipe_id)))
		var icon := TextureRect.new()
		icon.texture = load(str(data.get("icon", "res://assets/sprites/drop_bag.png")))
		icon.custom_minimum_size = Vector2(42, 42)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_SCALE
		row.add_child(icon)
		var info := VBoxContainer.new()
		info.custom_minimum_size = Vector2(570, 54)
		info.add_child(_panel_label("%s  |  %d ouro" % [recipe_id, int(recipe.get("gold", 0))], 15, Color.WHITE))
		info.add_child(_panel_label(CraftingSystem.material_text(recipe, player.inventory), 12, Color("#aeb8c3")))
		row.add_child(info)
		var craft := Button.new()
		craft.text = "Criar"
		craft.custom_minimum_size = Vector2(100, 42)
		craft.disabled = not CraftingSystem.can_craft(player, recipe)
		_style_panel_button(craft)
		craft.pressed.connect(func() -> void:
			if CraftingSystem.craft(player, recipe):
				player.recalculate_equipment()
				_flash("Forjado: " + str(recipe.get("result", recipe_id)))
				_show_forge()
			else:
				_flash("Materiais ou ouro insuficientes.")
		)
		row.add_child(craft)
		list.add_child(row)

func _show_inventory() -> void:
	if panel.visible and current_panel == "inventory":
		_hide_panel()
		return
	_open_inventory_panel()

func _open_inventory_panel() -> void:
	var body := _start_modal("Bolsa", "inventory")
	var root := HBoxContainer.new()
	root.custom_minimum_size = Vector2(850, 470)
	body.add_child(root)
	var equipment_box := VBoxContainer.new()
	equipment_box.custom_minimum_size = Vector2(300, 470)
	root.add_child(equipment_box)
	equipment_box.add_child(_panel_label("Ouro: %d moedas" % player.ouro, 17, Color("#ffd36b")))
	equipment_box.add_child(_panel_label("Equipamentos", 16, Color("#f4f4f4")))
	var slot_data := ItemDatabase.load_json("res://data/equipment_slots.json")
	var equip_grid := GridContainer.new()
	equip_grid.columns = 3
	equip_grid.custom_minimum_size = Vector2(290, 360)
	equip_grid.add_theme_constant_override("h_separation", 8)
	equip_grid.add_theme_constant_override("v_separation", 8)
	equipment_box.add_child(equip_grid)
	for slot in EquipmentSystem.SLOT_ORDER:
		var slot_name := str(slot)
		var button := _inventory_equipment_slot_button(slot_name, slot_data)
		equip_grid.add_child(button)

	var bag_box := VBoxContainer.new()
	bag_box.custom_minimum_size = Vector2(535, 470)
	root.add_child(bag_box)
	bag_box.add_child(_panel_label("Bolsa (20 slots)", 18, Color.WHITE))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(535, 430)
	bag_box.add_child(scroll)
	var bag_grid := GridContainer.new()
	bag_grid.columns = 5
	bag_grid.custom_minimum_size = Vector2(510, 420)
	bag_grid.add_theme_constant_override("h_separation", 8)
	bag_grid.add_theme_constant_override("v_separation", 8)
	scroll.add_child(bag_grid)
	var keys: Array = player.inventory.items.keys()
	keys.sort()
	var shown := 0
	for item_name in keys:
		if shown >= InventorySystem.MAX_SLOTS:
			break
		var bag_item_name := str(item_name)
		var data := item_db.get_item(bag_item_name)
		var amount: int = int(player.inventory.items.get(bag_item_name, 0))
		var slot_btn := Button.new()
		slot_btn.custom_minimum_size = Vector2(96, 76)
		slot_btn.text = "x%d" % amount
		slot_btn.icon = load(str(data.get("icon", "res://assets/sprites/drop_bag.png")))
		slot_btn.expand_icon = true
		slot_btn.tooltip_text = "%s\n%s" % [bag_item_name, str(data.get("description", ""))]
		_style_panel_button(slot_btn)
		slot_btn.pressed.connect(func() -> void:
			_use_or_equip_item(bag_item_name)
			_open_inventory_panel()
		)
		bag_grid.add_child(slot_btn)
		shown += 1
	while shown < InventorySystem.MAX_SLOTS:
		var empty_slot := PanelContainer.new()
		empty_slot.custom_minimum_size = Vector2(96, 76)
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.03, 0.04, 0.05, 0.9)
		style.border_color = Color(1, 1, 1, 0.2)
		style.set_border_width_all(1)
		style.set_corner_radius_all(6)
		empty_slot.add_theme_stylebox_override("panel", style)
		bag_grid.add_child(empty_slot)
		shown += 1

func _use_or_equip_item(item_name: String) -> void:
	var data := item_db.get_item(item_name)
	match str(data.get("type", "")):
		"consumivel":
			_use_potion_item(item_name)
		"equipment", "equipamento", "joia":
			var slot: String = player.inventory.equip(item_name, data)
			if not slot.is_empty():
				player.recalculate_equipment()
				_flash("Equipado em " + EquipmentSystem.slot_label(slot) + ": " + item_name)
		_:
			_flash(str(data.get("description", "Item sem acao.")))

func _remove_equipped_item(slot: String) -> void:
	var removed: String = player.inventory.remove_equipment(slot)
	if removed.is_empty():
		_flash("Slot vazio.")
		return
	player.recalculate_equipment()
	_flash("Removido: " + removed)

func _use_potion_item(item_name: String) -> void:
	if player == null:
		return
	if int(player.inventory.items.get(item_name, 0)) <= 0:
		_flash("Sem " + item_name)
		_update_potion_buttons()
		return
	var data := item_db.get_item(item_name)
	if str(data.get("type", "")) != "consumivel":
		_flash("Este item nao e consumivel.")
		return
	var heal_amount := int(data.get("heal", 0))
	var mana_amount := int(data.get("mana", 0))
	if heal_amount > 0 and player.vida >= player.vida_max:
		_flash("Vida ja esta cheia.")
		return
	if mana_amount > 0 and player.mana >= player.mana_max:
		_flash("Mana ja esta cheia.")
		return
	if not player.inventory.remove_item(item_name, 1):
		_flash("Sem " + item_name)
		return
	if heal_amount > 0:
		player.heal(heal_amount)
	if mana_amount > 0:
		player.recover_mana(mana_amount)
	_flash("Usado: " + item_name)
	_update_potion_buttons()

func _show_character() -> void:
	_show_skills_window()

func _show_skills_window() -> void:
	if panel.visible and current_panel == "character":
		_hide_panel()
		return
	var box := _start_modal("Habilidades", "character")
	box.add_child(_panel_label("Nome: %s    Nivel: %d    XP: %d/%d" % [player.character_name, player.level, player.xp, player.xp_to_next_level()], 16, Color.WHITE))
	box.add_child(_panel_label("HP: %d/%d    MP: %d/%d" % [player.vida, player.vida_max, player.mana, player.mana_max], 16, Color.WHITE))
	box.add_child(_panel_label("HABILIDADES", 18, Color("#9cff72")))
	for skill_id in SkillProgressionSystem.SKILL_ORDER:
		var skill: Dictionary = player.skills.get(skill_id, {})
		box.add_child(_skill_progress_row(skill_id, skill))

func _show_equipment_window() -> void:
	if panel.visible and current_panel == "equipment":
		_hide_panel()
		return
	var box := _start_modal("Equipamento", "equipment")
	var grid := GridContainer.new()
	grid.columns = 3
	grid.custom_minimum_size = Vector2(470, 430)
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	box.add_child(grid)
	var slot_data := ItemDatabase.load_json("res://data/equipment_slots.json")
	for row in EquipmentSystem.SLOT_GRID:
		for slot in row:
			var slot_name := str(slot)
			grid.add_child(_equipment_slot_button(slot_name, slot_data))
		if row.size() == 1:
			grid.add_child(Control.new())
			grid.add_child(Control.new())

func _show_quests() -> void:
	if panel.visible and current_panel == "quests":
		_hide_panel()
		return
	var box := VBoxContainer.new()
	_set_panel_content(box, "quests")
	box.add_child(_panel_title("Missoes"))
	if quest_system.active.is_empty():
		var empty := Label.new()
		empty.text = "Nenhuma missao ativa."
		box.add_child(empty)
	for quest_id in quest_system.active.keys():
		var label := Label.new()
		label.text = quest_system.quest_text(str(quest_id))
		box.add_child(label)

func _show_wikipedia() -> void:
	if panel.visible and current_panel == "wikipedia":
		_hide_panel()
		return
	var box := _start_modal("Wikipedia", "wikipedia")
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(850, 450)
	box.add_child(scroll)
	var content := VBoxContainer.new()
	scroll.add_child(content)
	content.add_child(_panel_label("Classes e habilidades", 18, Color("#ffd36b")))
	for class_key in class_db.classes.keys():
		var data: Dictionary = class_db.classes.get(class_key, {})
		var base: Dictionary = data.get("base", {})
		content.add_child(_panel_label("%s | HP %s | MP %s | ATK %s | DEF %s" % [
			str(class_key),
			str(base.get("vida", "-")),
			str(base.get("mana", "-")),
			str(base.get("ataque", "-")),
			str(base.get("defesa", "-"))
		], 15, Color.WHITE))
		content.add_child(_panel_label("Passiva: %s" % str(data.get("passive", "")), 13, Color("#b8c3d1")))
		for skill in data.get("skills", []):
			if typeof(skill) == TYPE_DICTIONARY:
				content.add_child(_panel_label("- %s: %s mana, recarga %ss" % [str(skill.get("name", "")), str(skill.get("mana", 0)), str(skill.get("cooldown", 0))], 13, Color("#d7e3f1")))
	content.add_child(_panel_label("Pets", 18, Color("#ffd36b")))
	for pet in pet_definitions:
		if typeof(pet) != TYPE_DICTIONARY:
			continue
		content.add_child(_panel_label("%s [%s] - %d moedas" % [str(pet.get("name", "")), str(pet.get("rarity", "")), int(pet.get("price", 0))], 15, Color.WHITE))
		content.add_child(_panel_label("Passiva: %s | Ativa: %s" % [str(pet.get("passive_desc", "")), str(pet.get("active_desc", ""))], 13, Color("#b8c3d1")))
	content.add_child(_panel_label("Montarias", 18, Color("#ffd36b")))
	for mount in mount_definitions:
		if typeof(mount) != TYPE_DICTIONARY:
			continue
		content.add_child(_panel_label("%s [%s] - +%d%% velocidade - %d moedas" % [
			str(mount.get("name", "")),
			str(mount.get("rarity", "")),
			int(round(float(mount.get("speed_bonus", 0.0)) * 100.0)),
			int(mount.get("price", 0))
		], 15, Color.WHITE))
	content.add_child(_panel_label("NPCs e mapas", 18, Color("#ffd36b")))
	for map_id in maps.keys():
		var map_data: Dictionary = maps.get(map_id, {})
		content.add_child(_panel_label(str(map_data.get("name", map_id)), 15, Color.WHITE))
		for npc in map_data.get("npcs", []):
			if typeof(npc) == TYPE_DICTIONARY:
				content.add_child(_panel_label("- %s: %s" % [str(npc.get("name", "")), str(npc.get("role", ""))], 13, Color("#b8c3d1")))
	content.add_child(_panel_label("Monstros", 18, Color("#ffd36b")))
	for enemy_name in enemies_db.keys():
		var enemy_data: Dictionary = enemies_db.get(enemy_name, {})
		var level_text := str(enemy_data.get("level", 1))
		var level_range: Array = enemy_data.get("level_range", [])
		if level_range.size() >= 2:
			level_text = "%d-%d" % [int(level_range[0]), int(level_range[1])]
		var special := "Veneno %.0f%%" % [float(enemy_data.get("poison_chance", 0.0)) * 100.0] if float(enemy_data.get("poison_chance", 0.0)) > 0.0 else "Sem habilidade especial"
		content.add_child(_panel_label("%s Lv %s | HP %s | ATK %s | DEF %s | %s" % [
			str(enemy_name),
			level_text,
			str(enemy_data.get("vida", 0)),
			str(enemy_data.get("ataque", 0)),
			str(enemy_data.get("defesa", 0)),
			special
		], 13, Color("#d7e3f1")))

func _show_professions(force_refresh: bool = false) -> void:
	if panel.visible and current_panel == "professions" and not force_refresh:
		_hide_panel()
		return
	if online_mode and mmo_client != null and not force_refresh:
		mmo_client.call("request_professions")
	var box := _start_modal("Profissoes", "professions")
	var payload: Dictionary = mmo_cache.get("professions_state", {})
	var professions: Dictionary = payload.get("professions", {})
	if professions.is_empty():
		box.add_child(_panel_label("Sem dados online ainda. Coletando...", 14, Color("#d4d9e1")))
		var refresh := Button.new()
		refresh.text = "Atualizar"
		_style_panel_button(refresh)
		refresh.pressed.connect(func() -> void:
			if mmo_client != null:
				mmo_client.call("request_professions")
		)
		box.add_child(refresh)
		return
	var info := _panel_label("Profissoes evoluem com coleta/crafting. VIP +10% XP de profissao.", 13, Color("#b8c3d1"))
	box.add_child(info)
	for key in professions.keys():
		var row: Dictionary = professions.get(key, {})
		var level: int = int(row.get("level", 1))
		var xp: int = int(row.get("xp", 0))
		var xp_required: int = max(1, int(row.get("xp_required", 100)))
		box.add_child(_panel_label("%s  Lv.%d" % [str(row.get("name", key)), level], 16, Color.WHITE))
		box.add_child(_xp_bar_row("%d/%d" % [xp, xp_required], xp, xp_required, Color("#55d86a")))

func _show_crafting_window(force_refresh: bool = false) -> void:
	if panel.visible and current_panel == "crafting" and not force_refresh:
		_hide_panel()
		return
	if online_mode and mmo_client != null and not force_refresh:
		mmo_client.call("request_crafting_recipes")
	var box := _start_modal("Crafting", "crafting")
	var payload: Dictionary = mmo_cache.get("crafting_recipes", {})
	var recipes: Array = payload.get("recipes", [])
	if recipes.is_empty():
		box.add_child(_panel_label("Nenhuma receita recebida ainda.", 14, Color("#d4d9e1")))
		return
	box.add_child(_panel_label("Crie armas, armaduras, pocoes e materiais refinados.", 13, Color("#b8c3d1")))
	for recipe in recipes:
		if typeof(recipe) != TYPE_DICTIONARY:
			continue
		var row := HBoxContainer.new()
		row.custom_minimum_size = Vector2(820, 60)
		var recipe_name: String = str(recipe.get("name", recipe.get("code", "receita")))
		var profession: String = str(recipe.get("profession", ""))
		var req_level: int = int(recipe.get("profession_level_required", 1))
		var success_chance: int = int(recipe.get("success_chance", 100))
		row.add_child(_panel_label("%s  |  %s Lv.%d  |  %d%%" % [recipe_name, profession, req_level, success_chance], 14, Color.WHITE))
		var spacer := Control.new()
		spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(spacer)
		var craft_button := Button.new()
		craft_button.text = "Criar"
		_style_panel_button(craft_button)
		craft_button.pressed.connect(func() -> void:
			if online_mode and mmo_client != null:
				mmo_client.call("craft", str(recipe.get("code", "")))
				_flash("Pedido de craft enviado.")
		)
		row.add_child(craft_button)
		box.add_child(row)

func _show_pets(force_refresh: bool = false) -> void:
	if panel.visible and current_panel == "pets" and not force_refresh:
		_hide_panel()
		return
	if online_mode and mmo_client != null and not force_refresh:
		mmo_client.call("request_pets")
	var box := _start_modal("Pets", "pets")
	box.add_child(_panel_label("Pets desbloqueados ficam nitidos. Bloqueados aparecem escurecidos.", 13, Color("#b8c3d1")))
	var payload: Dictionary = mmo_cache.get("pets_state", {})
	var owned: Array = payload.get("pets", [])
	var by_code: Dictionary = {}
	for pet in owned:
		if typeof(pet) != TYPE_DICTIONARY:
			continue
		by_code[str(pet.get("code", ""))] = pet
	var cards := GridContainer.new()
	cards.columns = 2
	cards.add_theme_constant_override("h_separation", 10)
	cards.add_theme_constant_override("v_separation", 10)
	cards.custom_minimum_size = Vector2(840, 400)
	box.add_child(cards)
	for def in pet_definitions:
		if typeof(def) != TYPE_DICTIONARY:
			continue
		var code := str(def.get("code", ""))
		var owned_pet: Dictionary = by_code.get(code, {})
		var unlocked: bool = not owned_pet.is_empty()
		var card := PanelContainer.new()
		card.custom_minimum_size = Vector2(410, 140)
		var card_style := StyleBoxFlat.new()
		card_style.bg_color = Color(0.05, 0.06, 0.08, 0.95)
		card_style.border_color = Color(1, 1, 1, 0.2)
		card_style.set_border_width_all(1)
		card_style.set_corner_radius_all(6)
		card.add_theme_stylebox_override("panel", card_style)
		cards.add_child(card)
		var row := HBoxContainer.new()
		row.custom_minimum_size = Vector2(394, 130)
		card.add_child(row)
		var icon_holder := Control.new()
		icon_holder.custom_minimum_size = Vector2(92, 92)
		row.add_child(icon_holder)
		var icon := TextureRect.new()
		icon.texture = load(_pet_icon_path(code))
		icon.custom_minimum_size = Vector2(92, 92)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_SCALE
		icon_holder.add_child(icon)
		if not unlocked:
			var shade := ColorRect.new()
			shade.color = Color(0, 0, 0, 0.58)
			shade.size = Vector2(92, 92)
			icon_holder.add_child(shade)
		var info := VBoxContainer.new()
		info.custom_minimum_size = Vector2(290, 128)
		row.add_child(info)
		var level: int = int(owned_pet.get("level", 1))
		var equipped: bool = bool(owned_pet.get("equipped", false))
		info.add_child(_panel_label("%s %s" % [str(def.get("name", code)), "(Lv.%d)" % level if unlocked else "(Bloqueado)"], 15, Color.WHITE))
		info.add_child(_panel_label("Passiva: %s" % str(def.get("passive_desc", _pet_bonus_text(def.get("base_bonus", {})))), 12, Color("#d8e6f2")))
		info.add_child(_panel_label("Ativa: %s" % str(def.get("active_desc", "Sem ativa por enquanto.")), 12, Color("#c7d6e5")))
		if unlocked:
			var equip_btn := Button.new()
			equip_btn.text = "Equipado" if equipped else "Equipar"
			equip_btn.disabled = equipped
			_style_panel_button(equip_btn)
			var character_pet_id: int = int(owned_pet.get("id", 0))
			equip_btn.pressed.connect(func() -> void:
				if online_mode and mmo_client != null:
					mmo_client.call("equip_pet", character_pet_id)
				else:
					_equip_local_pet(code)
					_show_pets(true)
			)
			info.add_child(equip_btn)

func _show_mounts(force_refresh: bool = false) -> void:
	if panel.visible and current_panel == "mounts" and not force_refresh:
		_hide_panel()
		return
	if online_mode and mmo_client != null and not force_refresh:
		mmo_client.call("request_mounts")
	var box := _start_modal("Montarias", "mounts")
	box.add_child(_panel_label("Montarias aumentam mobilidade. Bloqueadas aparecem escurecidas.", 13, Color("#b8c3d1")))
	var payload: Dictionary = mmo_cache.get("mounts_state", {})
	var owned: Array = payload.get("mounts", [])
	var by_code: Dictionary = {}
	for mount in owned:
		if typeof(mount) != TYPE_DICTIONARY:
			continue
		by_code[str(mount.get("code", ""))] = mount
	var cards := GridContainer.new()
	cards.columns = 2
	cards.add_theme_constant_override("h_separation", 10)
	cards.add_theme_constant_override("v_separation", 10)
	cards.custom_minimum_size = Vector2(840, 380)
	box.add_child(cards)
	for def in mount_definitions:
		if typeof(def) != TYPE_DICTIONARY:
			continue
		var code := str(def.get("code", ""))
		var owned_mount: Dictionary = by_code.get(code, {})
		var unlocked: bool = not owned_mount.is_empty()
		var card := PanelContainer.new()
		card.custom_minimum_size = Vector2(410, 122)
		var card_style := StyleBoxFlat.new()
		card_style.bg_color = Color(0.05, 0.06, 0.08, 0.95)
		card_style.border_color = Color(1, 1, 1, 0.2)
		card_style.set_border_width_all(1)
		card_style.set_corner_radius_all(6)
		card.add_theme_stylebox_override("panel", card_style)
		cards.add_child(card)
		var row := HBoxContainer.new()
		row.custom_minimum_size = Vector2(394, 116)
		card.add_child(row)
		var icon_holder := Control.new()
		icon_holder.custom_minimum_size = Vector2(92, 92)
		row.add_child(icon_holder)
		var icon := TextureRect.new()
		icon.texture = load(_mount_icon_path(code))
		icon.custom_minimum_size = Vector2(92, 92)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_SCALE
		icon_holder.add_child(icon)
		if not unlocked:
			var shade := ColorRect.new()
			shade.color = Color(0, 0, 0, 0.58)
			shade.size = Vector2(92, 92)
			icon_holder.add_child(shade)
		var info := VBoxContainer.new()
		info.custom_minimum_size = Vector2(290, 116)
		row.add_child(info)
		var speed_bonus: float = float(def.get("speed_bonus", 0.0)) * 100.0
		var equipped: bool = bool(owned_mount.get("equipped", false))
		info.add_child(_panel_label("%s %s" % [str(def.get("name", code)), "(Bloqueada)" if not unlocked else ""], 15, Color.WHITE))
		info.add_child(_panel_label("+%.0f%% velocidade" % speed_bonus, 13, Color("#d9e8f7")))
		info.add_child(_panel_label(str(def.get("desc", "Montaria de exploracao.")), 12, Color("#c8d3e0")))
		if unlocked:
			var equip_btn := Button.new()
			equip_btn.text = "Montada" if equipped else "Montar"
			equip_btn.disabled = equipped
			_style_panel_button(equip_btn)
			var character_mount_id: int = int(owned_mount.get("id", 0))
			equip_btn.pressed.connect(func() -> void:
				if online_mode and mmo_client != null:
					mmo_client.call("equip_mount", character_mount_id)
				else:
					_equip_local_mount(code)
					_show_mounts(true)
			)
			info.add_child(equip_btn)

func _show_dungeons(force_refresh: bool = false) -> void:
	if panel.visible and current_panel == "dungeons" and not force_refresh:
		_hide_panel()
		return
	if online_mode and mmo_client != null and not force_refresh:
		mmo_client.call("request_dungeons")
	var box := _start_modal("Dungeons", "dungeons")
	var payload: Dictionary = mmo_cache.get("dungeons_state", {})
	var dungeons: Array = payload.get("dungeons", [])
	if dungeons.is_empty():
		box.add_child(_panel_label("Nenhuma dungeon configurada.", 14, Color("#d4d9e1")))
		return
	for dungeon in dungeons:
		if typeof(dungeon) != TYPE_DICTIONARY:
			continue
		var row := HBoxContainer.new()
		row.custom_minimum_size = Vector2(820, 46)
		var dungeon_name: String = str(dungeon.get("name", "Dungeon"))
		var min_level: int = int(dungeon.get("min_level", 1))
		var time_limit: int = int(dungeon.get("time_limit_seconds", 1200))
		row.add_child(_panel_label("%s  |  Min Lv.%d  |  %d min" % [dungeon_name, min_level, int(time_limit / 60)], 15, Color.WHITE))
		var spacer := Control.new()
		spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(spacer)
		var start_btn := Button.new()
		start_btn.text = "Entrar"
		_style_panel_button(start_btn)
		var dungeon_code: String = str(dungeon.get("code", ""))
		start_btn.pressed.connect(func() -> void:
			if mmo_client != null:
				mmo_client.call("start_dungeon", dungeon_code)
		)
		row.add_child(start_btn)
		box.add_child(row)

func _show_rank(force_refresh: bool = false) -> void:
	if panel.visible and current_panel == "rank" and not force_refresh:
		_hide_panel()
		return
	if online_mode and mmo_client != null and not force_refresh:
		mmo_client.call("request_rank", "top_level")
	var box := _start_modal("Rank", "rank")
	var tabs := HBoxContainer.new()
	for tab_name in RANK_KEYS.keys():
		var rank_key: String = str(RANK_KEYS[tab_name])
		var tab_button := Button.new()
		tab_button.text = str(tab_name)
		_style_panel_button(tab_button)
		tab_button.pressed.connect(func() -> void:
			if mmo_client != null:
				mmo_client.call("request_rank", rank_key)
		)
		tabs.add_child(tab_button)
	box.add_child(tabs)
	var payload: Dictionary = mmo_cache.get("rank_state", {})
	var rows: Array = payload.get("rows", [])
	if rows.is_empty():
		box.add_child(_panel_label("Ranking indisponivel ainda.", 14, Color("#d4d9e1")))
		return
	for i in range(rows.size()):
		var row: Dictionary = rows[i]
		box.add_child(_panel_label("%d. %s - %s" % [i + 1, str(row.get("name", "Jogador")), str(row.get("score", row.get("level", 0)))], 14, Color.WHITE))

func _show_market(force_refresh: bool = false) -> void:
	if panel.visible and current_panel == "market" and not force_refresh:
		_hide_panel()
		return
	if online_mode and mmo_client != null and not force_refresh:
		mmo_client.call("request_market")
	var box := _start_modal("Mercado", "market")
	var actions := HBoxContainer.new()
	var refresh := Button.new()
	refresh.text = "Atualizar"
	_style_panel_button(refresh)
	refresh.pressed.connect(func() -> void:
		if mmo_client != null:
			mmo_client.call("request_market")
	)
	actions.add_child(refresh)
	var quick_list := Button.new()
	quick_list.text = "Anunciar Pocao"
	_style_panel_button(quick_list)
	quick_list.pressed.connect(func() -> void:
		if mmo_client != null:
			mmo_client.call("list_market_item", "Pocao pequena de vida", 1, 99, "consumivel", "common")
	)
	actions.add_child(quick_list)
	box.add_child(actions)
	var payload: Dictionary = mmo_cache.get("market_state", {})
	var listings: Array = payload.get("listings", [])
	if listings.is_empty():
		box.add_child(_panel_label("Sem ofertas no mercado.", 14, Color("#d4d9e1")))
		return
	for listing in listings:
		if typeof(listing) != TYPE_DICTIONARY:
			continue
		var row := HBoxContainer.new()
		row.custom_minimum_size = Vector2(820, 44)
		row.add_child(_panel_label("%s x%d - %d ouro" % [str(listing.get("item_id", "item")), int(listing.get("quantity", 1)), int(listing.get("price", 0))], 14, Color.WHITE))
		var spacer := Control.new()
		spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(spacer)
		var buy_btn := Button.new()
		buy_btn.text = "Comprar"
		_style_panel_button(buy_btn)
		var listing_id: int = int(listing.get("id", 0))
		buy_btn.pressed.connect(func() -> void:
			if mmo_client != null and listing_id > 0:
				mmo_client.call("buy_market_item", listing_id)
		)
		row.add_child(buy_btn)
		box.add_child(row)

func _show_vip(force_refresh: bool = false) -> void:
	if panel.visible and current_panel == "vip" and not force_refresh:
		_hide_panel()
		return
	if online_mode and mmo_client != null and not force_refresh:
		mmo_client.call("request_vip")
	var box := _start_modal("VIP", "vip")
	var payload: Dictionary = mmo_cache.get("vip_state", {})
	var vip: Dictionary = payload.get("vip", {})
	if vip.is_empty():
		box.add_child(_panel_label("VIP nao carregado.", 14, Color("#d4d9e1")))
		return
	box.add_child(_panel_label("Ativo: %s" % ("Sim" if bool(vip.get("vip_active", false)) else "Nao"), 16, Color.WHITE))
	box.add_child(_panel_label("Dias restantes: %d" % int(vip.get("vip_days", 0)), 16, Color("#ffd36b")))
	box.add_child(_panel_label("Beneficios: +10% XP geral, +10% XP profissao, +5 slots, cosmÃ©ticos.", 13, Color("#b8c3d1")))

func _show_achievements(force_refresh: bool = false) -> void:
	if panel.visible and current_panel == "achievements" and not force_refresh:
		_hide_panel()
		return
	if online_mode and mmo_client != null and not force_refresh:
		mmo_client.call("request_achievements")
	var box := _start_modal("Conquistas", "achievements")
	var payload: Dictionary = mmo_cache.get("achievements_state", {})
	var achievements: Array = payload.get("achievements", [])
	if achievements.is_empty():
		box.add_child(_panel_label("Nenhuma conquista recebida.", 14, Color("#d4d9e1")))
		return
	for ach in achievements:
		if typeof(ach) != TYPE_DICTIONARY:
			continue
		var done: bool = bool(ach.get("completed", false))
		var progress: int = int(ach.get("progress", 0))
		var objective: int = max(1, int(ach.get("objective", 1)))
		box.add_child(_panel_label("%s %s" % [str(ach.get("name", "Conquista")), "(OK)" if done else ""], 14, Color("#eaf1ff")))
		box.add_child(_xp_bar_row("%d/%d" % [progress, objective], progress, objective, Color("#6ad87a")))

func _show_season(force_refresh: bool = false) -> void:
	if panel.visible and current_panel == "season" and not force_refresh:
		_hide_panel()
		return
	if online_mode and mmo_client != null and not force_refresh:
		mmo_client.call("request_season")
	var box := _start_modal("Temporada", "season")
	var payload: Dictionary = mmo_cache.get("season_state", {})
	var season: Dictionary = payload.get("season", {})
	var progress: Dictionary = payload.get("progress", {})
	if season.is_empty():
		box.add_child(_panel_label("Sem temporada ativa.", 14, Color("#d4d9e1")))
		return
	box.add_child(_panel_label(str(season.get("name", "Temporada")), 18, Color("#ffd57e")))
	var level: int = int(progress.get("level", 1))
	var xp: int = int(progress.get("xp", 0))
	box.add_child(_panel_label("Nivel passe: %d" % level, 15, Color.WHITE))
	box.add_child(_panel_label("XP passe: %d" % xp, 15, Color.WHITE))
	var premium: bool = bool(progress.get("premium_unlocked", false))
	box.add_child(_panel_label("Passe premium: %s" % ("Liberado" if premium else "Nao"), 15, Color("#d6b56e")))

func _show_world_map(force_refresh: bool = false) -> void:
	if panel.visible and current_panel == "world_map" and not force_refresh:
		_hide_panel()
		return
	var box := _start_modal("Mapa do Mundo", "world_map")
	box.add_child(_panel_label("Explore andando: o mapa vai revelando as areas visitadas.", 13, Color("#b8c3d1")))
	var canvas := PanelContainer.new()
	canvas.custom_minimum_size = Vector2(860, 430)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.03, 0.04, 0.06, 0.98)
	style.border_color = Color(1, 1, 1, 0.25)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	canvas.add_theme_stylebox_override("panel", style)
	box.add_child(canvas)
	var map_data: Dictionary = maps.get(current_map, {})
	var map_size_arr: Array = map_data.get("size", [2200, 1400])
	var map_size := Vector2(float(map_size_arr[0]), float(map_size_arr[1]))
	var canvas_size := Vector2(850, 420)
	var bg := ColorRect.new()
	bg.position = Vector2(5, 5)
	bg.size = canvas_size
	bg.color = Color(map_data.get("color", "#2e3a3d"))
	canvas.add_child(bg)
	_draw_world_map_preview(canvas, current_map, map_size, canvas_size)
	for portal_data in map_data.get("portals", []):
		var pos_arr: Array = portal_data.get("pos", [0, 0])
		var dot := ColorRect.new()
		dot.size = Vector2(6, 6)
		dot.color = Color("#9cd3ff")
		dot.position = Vector2(5, 5) + _map_canvas_pos(map_size, canvas_size, Vector2(float(pos_arr[0]), float(pos_arr[1]))) - Vector2(3, 3)
		canvas.add_child(dot)
	for npc_data in map_data.get("npcs", []):
		var pos_arr: Array = npc_data.get("pos", [0, 0])
		var dot := ColorRect.new()
		dot.size = Vector2(6, 6)
		dot.color = Color("#74f29b")
		dot.position = Vector2(5, 5) + _map_canvas_pos(map_size, canvas_size, Vector2(float(pos_arr[0]), float(pos_arr[1]))) - Vector2(3, 3)
		canvas.add_child(dot)
	var player_dot := ColorRect.new()
	player_dot.size = Vector2(8, 8)
	player_dot.color = Color("#ffef8a")
	player_dot.position = Vector2(5, 5) + _map_canvas_pos(map_size, canvas_size, player.global_position) - Vector2(4, 4)
	canvas.add_child(player_dot)
	var exp: Dictionary = _ensure_map_exploration(current_map)
	var grid_w: int = int(exp.get("w", 1))
	var grid_h: int = int(exp.get("h", 1))
	var data: Array = exp.get("data", [])
	for gy in range(grid_h):
		for gx in range(grid_w):
			var idx := gy * grid_w + gx
			if idx < data.size() and int(data[idx]) == 1:
				continue
			var fog := ColorRect.new()
			fog.color = Color(0, 0, 0, 0.95)
			fog.position = Vector2(5, 5) + Vector2(gx * EXPLORATION_CELL * canvas_size.x / map_size.x, gy * EXPLORATION_CELL * canvas_size.y / map_size.y)
			fog.size = Vector2(EXPLORATION_CELL * canvas_size.x / map_size.x + 1, EXPLORATION_CELL * canvas_size.y / map_size.y + 1)
			canvas.add_child(fog)

func _draw_world_map_preview(canvas: Control, map_id: String, map_size: Vector2, canvas_size: Vector2) -> void:
	var origin := Vector2(5, 5)
	match map_id:
		"city_eldoria":
			_map_preview_rect(canvas, map_size, canvas_size, Rect2(150, 120, map_size.x - 300, map_size.y - 240), Color("#4a7d4f"), origin)
			_map_preview_rect(canvas, map_size, canvas_size, Rect2(430, 250, 1300, 770), Color("#61727f"), origin)
			_map_preview_rect(canvas, map_size, canvas_size, Rect2(1020, 350, 220, 900), Color("#84725a"), origin)
		"forest_boars":
			_map_preview_rect(canvas, map_size, canvas_size, Rect2(0, 0, map_size.x, map_size.y), Color("#3f6f3e"), origin)
			_map_preview_rect(canvas, map_size, canvas_size, Rect2(0, 0, 240, map_size.y), Color("#2d5f9c"), origin)
			_map_preview_rect(canvas, map_size, canvas_size, Rect2(1030, 310, 120, 980), Color("#8a7a5d"), origin)
		"arcane_ruins":
			_map_preview_rect(canvas, map_size, canvas_size, Rect2(0, 0, map_size.x, map_size.y), Color("#474a76"), origin)
			_map_preview_rect(canvas, map_size, canvas_size, Rect2(350, 170, 1500, 920), Color("#6a6d93"), origin)
		"bat_cave":
			_map_preview_rect(canvas, map_size, canvas_size, Rect2(0, 0, map_size.x, map_size.y), Color("#2b2f3f"), origin)
			_map_preview_rect(canvas, map_size, canvas_size, Rect2(240, 130, map_size.x - 480, map_size.y - 220), Color("#3c4152"), origin)

func _map_preview_rect(canvas: Control, map_size: Vector2, canvas_size: Vector2, world_rect: Rect2, color: Color, origin: Vector2) -> void:
	var p := _map_canvas_pos(map_size, canvas_size, world_rect.position) + origin
	var sz := Vector2(world_rect.size.x * canvas_size.x / map_size.x, world_rect.size.y * canvas_size.y / map_size.y)
	var rect := ColorRect.new()
	rect.position = p
	rect.size = sz
	rect.color = color
	canvas.add_child(rect)

func _map_canvas_pos(map_size: Vector2, canvas_size: Vector2, world_pos: Vector2) -> Vector2:
	var x: float = clamp(world_pos.x / max(1.0, map_size.x), 0.0, 1.0)
	var y: float = clamp(world_pos.y / max(1.0, map_size.y), 0.0, 1.0)
	return Vector2(x * canvas_size.x, y * canvas_size.y)

func _ensure_map_exploration(map_id: String) -> Dictionary:
	if exploration_by_map.has(map_id):
		return exploration_by_map[map_id]
	var map_data: Dictionary = maps.get(map_id, {})
	var map_size_arr: Array = map_data.get("size", [2200, 1400])
	var w: int = int(ceil(float(map_size_arr[0]) / float(EXPLORATION_CELL)))
	var h: int = int(ceil(float(map_size_arr[1]) / float(EXPLORATION_CELL)))
	var data: Array = []
	data.resize(w * h)
	for i in range(data.size()):
		data[i] = 0
	var entry := {"w": w, "h": h, "data": data}
	exploration_by_map[map_id] = entry
	return entry

func _update_map_exploration() -> void:
	if player == null:
		return
	var last_pos: Vector2 = exploration_last_pos_by_map.get(current_map, Vector2.INF)
	if last_pos != Vector2.INF and player.global_position.distance_to(last_pos) < 18.0:
		return
	exploration_last_pos_by_map[current_map] = player.global_position
	if last_pos == Vector2.INF:
		return
	var exp: Dictionary = _ensure_map_exploration(current_map)
	var w: int = int(exp.get("w", 1))
	var h: int = int(exp.get("h", 1))
	var data: Array = exp.get("data", [])
	var cx: int = int(floor(player.global_position.x / float(EXPLORATION_CELL)))
	var cy: int = int(floor(player.global_position.y / float(EXPLORATION_CELL)))
	var reveal_radius := 2
	for y in range(cy - reveal_radius, cy + reveal_radius + 1):
		if y < 0 or y >= h:
			continue
		for x in range(cx - reveal_radius, cx + reveal_radius + 1):
			if x < 0 or x >= w:
				continue
			var idx := y * w + x
			if idx >= 0 and idx < data.size():
				data[idx] = 1
	exp["data"] = data
	exploration_by_map[current_map] = exp

func _set_panel_content(control: Control, panel_name: String = "") -> void:
	for child in panel.get_children():
		child.queue_free()
	panel.add_child(control)
	_refresh_modal_layout()
	side_menu_visible = false
	if side_menu_panel != null:
		side_menu_panel.visible = false
	if panel_blocker != null:
		panel_blocker.visible = true
	if input_guard != null:
		input_guard.visible = false
	_set_game_controls_enabled(false)
	panel.visible = true
	current_panel = panel_name

func _start_modal(title: String, panel_name: String) -> VBoxContainer:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 22)
	margin.add_theme_constant_override("margin_right", 22)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 18)
	var root := VBoxContainer.new()
	root.custom_minimum_size = Vector2(876, 520)
	margin.add_child(root)
	var header := HBoxContainer.new()
	root.add_child(header)
	header.add_child(_panel_title(title))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)
	var close := Button.new()
	close.text = "X"
	close.custom_minimum_size = Vector2(44, 34)
	close.focus_mode = Control.FOCUS_NONE
	var close_style := StyleBoxFlat.new()
	close_style.bg_color = Color("#9e1d24")
	close_style.border_color = Color(1, 0.55, 0.55, 0.85)
	close_style.set_border_width_all(1)
	close_style.set_corner_radius_all(6)
	close.add_theme_stylebox_override("normal", close_style)
	close.add_theme_stylebox_override("hover", close_style)
	close.add_theme_stylebox_override("pressed", close_style)
	close.add_theme_color_override("font_color", Color.WHITE)
	close.pressed.connect(_hide_panel)
	header.add_child(close)
	var body := VBoxContainer.new()
	body.custom_minimum_size = Vector2(860, 470)
	root.add_child(body)
	_set_panel_content(margin, panel_name)
	return body

func _hide_panel() -> void:
	for child in panel.get_children():
		child.queue_free()
	panel.visible = false
	current_panel = ""
	ui_input_lock_until = float(Time.get_ticks_msec()) / 1000.0 + 0.45
	if input_guard != null:
		input_guard.visible = true
	get_tree().create_timer(0.45).timeout.connect(func() -> void:
		if panel_blocker != null:
			panel_blocker.visible = false
		if input_guard != null:
			input_guard.visible = false
		if not panel.visible:
			_set_game_controls_enabled(true)
	)

func _refresh_modal_layout() -> void:
	if panel == null:
		return
	var viewport_size := get_viewport_rect().size
	if panel_blocker != null:
		panel_blocker.size = viewport_size
	if input_guard != null:
		input_guard.size = viewport_size
	var desired := Vector2(920, 560)
	var width: float = clampf(viewport_size.x * 0.92, 680.0, desired.x)
	var height: float = clampf(viewport_size.y * 0.86, 460.0, desired.y)
	panel.size = Vector2(width, height)
	panel.position = (viewport_size - panel.size) * 0.5

func _set_game_controls_enabled(enabled: bool) -> void:
	ui_controls_enabled = enabled
	for b in touch_buttons:
		if b == null:
			continue
		b.disabled = not enabled
		b.mouse_filter = Control.MOUSE_FILTER_STOP if enabled else Control.MOUSE_FILTER_IGNORE
	for item_name in potion_buttons.keys():
		var entry: Dictionary = potion_buttons[item_name]
		var b := entry.get("button", null) as Button
		if b != null:
			b.disabled = not enabled
			b.mouse_filter = Control.MOUSE_FILTER_STOP if enabled else Control.MOUSE_FILTER_IGNORE
	if side_menu_toggle_button != null:
		side_menu_toggle_button.disabled = not enabled
	if side_menu_panel != null:
		side_menu_panel.mouse_filter = Control.MOUSE_FILTER_STOP if enabled else Control.MOUSE_FILTER_IGNORE
		for child in side_menu_panel.get_children():
			if child is Control:
				(child as Control).mouse_filter = Control.MOUSE_FILTER_STOP if enabled else Control.MOUSE_FILTER_IGNORE
	if enabled:
		_update_potion_buttons()

func _panel_title(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", Color.WHITE)
	return label

func _equipment_slot_button(slot: String, slot_data: Dictionary) -> Button:
	var item_name := str(player.inventory.equipment.get(slot, ""))
	var info: Dictionary = slot_data.get(slot, {})
	var fallback_icon := str(info.get("icon", "res://assets/sprites/icon_slot_weapon.png"))
	var button := Button.new()
	button.custom_minimum_size = Vector2(140, 96)
	button.text = EquipmentSystem.slot_label(slot)
	button.icon = UIEquipmentWindow.slot_icon(item_db, item_name, fallback_icon)
	button.expand_icon = true
	button.tooltip_text = UIEquipmentWindow.slot_tooltip(slot, item_name)
	_style_equipment_slot(button, item_name.is_empty())
	button.pressed.connect(func() -> void:
		if item_name.is_empty():
			_flash("Slot vazio: " + EquipmentSystem.slot_label(slot))
		else:
			_remove_equipped_item(slot)
			_show_equipment_window()
	)
	return button

func _style_equipment_slot(button: Button, empty: bool) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.055, 0.06, 0.072, 0.96)
	normal.border_color = Color(0.75, 0.78, 0.82, 0.36)
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(7)
	var pressed := StyleBoxFlat.new()
	pressed.bg_color = Color(0.12, 0.14, 0.16, 0.98)
	pressed.border_color = Color(1, 1, 1, 0.58)
	pressed.set_border_width_all(2)
	pressed.set_corner_radius_all(7)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", normal)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_color_override("font_color", Color(1, 1, 1, 0.55 if empty else 1.0))
	button.add_theme_font_size_override("font_size", 12)

func _inventory_equipment_slot_button(slot: String, slot_data: Dictionary) -> Button:
	var item_name := str(player.inventory.equipment.get(slot, ""))
	var info: Dictionary = slot_data.get(slot, {})
	var fallback_icon := str(info.get("icon", "res://assets/sprites/icon_slot_weapon.png"))
	var button := Button.new()
	button.custom_minimum_size = Vector2(88, 72)
	button.text = ""
	button.icon = UIEquipmentWindow.slot_icon(item_db, item_name, fallback_icon)
	button.expand_icon = true
	button.tooltip_text = "%s: %s" % [EquipmentSystem.slot_label(slot), item_name if not item_name.is_empty() else "vazio"]
	_style_equipment_slot(button, item_name.is_empty())
	button.pressed.connect(func() -> void:
		if item_name.is_empty():
			_flash("Slot vazio: " + EquipmentSystem.slot_label(slot))
		else:
			_remove_equipped_item(slot)
			_open_inventory_panel()
	)
	return button

func _skill_progress_row(skill_id: String, skill: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(820, 76)
	var icon := TextureRect.new()
	icon.texture = UISkillsWindow.icon_for(skill_id)
	icon.custom_minimum_size = Vector2(48, 48)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_SCALE
	row.add_child(icon)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(720, 68)
	row.add_child(box)
	var top := HBoxContainer.new()
	top.add_child(_panel_label(str(skill.get("name", skill_id)), 16, Color.WHITE))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(spacer)
	top.add_child(_panel_label(str(skill.get("level", 10)), 16, Color.WHITE))
	box.add_child(top)
	var percent := UISkillsWindow.percent(skill)
	box.add_child(_xp_bar_row("%d/%d  %d%%" % [int(skill.get("xp", 0)), int(skill.get("xp_required", 1)), percent], int(skill.get("xp", 0)), int(skill.get("xp_required", 1)), Color("#55d86a")))
	return row

func _panel_label(text: String, font_size: int = 15, color: Color = Color.WHITE) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color.BLACK)
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	return label

func _style_panel_button(button: Button) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.08, 0.095, 0.11, 0.96)
	normal.border_color = Color(1, 1, 1, 0.18)
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(5)
	var pressed := StyleBoxFlat.new()
	pressed.bg_color = Color(0.16, 0.20, 0.24, 0.98)
	pressed.border_color = Color(1, 1, 1, 0.38)
	pressed.set_border_width_all(1)
	pressed.set_corner_radius_all(5)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", normal)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("disabled", normal)
	button.add_theme_color_override("font_color", Color.WHITE)
	button.add_theme_color_override("font_disabled_color", Color("#aeb4bd"))
	button.add_theme_font_size_override("font_size", 14)

func _slot_label(slot: String) -> String:
	match slot:
		"cabeca":
			return "Cabeca"
		"peitoral":
			return "Peitoral"
		"luvas":
			return "Luvas"
		"calca":
			return "Calca"
		"botas":
			return "Botas"
		"arma":
			return "Arma"
		"joia_1":
			return "Joia 1"
		"joia_2":
			return "Joia 2"
		"joia_3":
			return "Joia 3"
	return slot

func _xp_bar_row(title: String, value: int, maximum: int, fill_color: Color) -> Control:
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(500, 42)
	box.add_child(_panel_label(title, 13, Color("#dce2ea")))
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(500, 12)
	bar.max_value = max(1, maximum)
	bar.value = clamp(value, 0, maximum)
	bar.show_percentage = false
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.02, 0.025, 0.032, 0.96)
	bg.border_color = Color(1, 1, 1, 0.18)
	bg.set_border_width_all(1)
	bg.set_corner_radius_all(4)
	var fill := StyleBoxFlat.new()
	fill.bg_color = fill_color
	fill.set_corner_radius_all(4)
	bar.add_theme_stylebox_override("background", bg)
	bar.add_theme_stylebox_override("fill", fill)
	box.add_child(bar)
	return box

func _apply_map_regen() -> void:
	var map_data: Dictionary = maps.get(current_map, {})
	if bool(map_data.get("safe", false)):
		var near_fountain: bool = player.global_position.distance_to(Vector2(640, 365)) < 110
		var amount := 8 if near_fountain else 3
		player.heal(amount)
		player.recover_mana(int(amount * (1.0 + player.mana_regen_pct)))
	elif player.in_safe_zone:
		player.heal(SAFE_ZONE_REGEN)
		player.recover_mana(int(SAFE_ZONE_REGEN * (1.0 + player.mana_regen_pct)))

func _update_safe_zone_state() -> void:
	if player == null:
		return
	var map_data: Dictionary = maps.get(current_map, {})
	player.in_safe_zone = bool(map_data.get("safe", false)) or _is_point_in_safe_zone(player.global_position)

func _ensure_player_camera() -> void:
	if player == null:
		return
	player_camera = player.get_node_or_null("PlayerCamera")
	if player_camera == null:
		player_camera = Camera2D.new()
		player_camera.name = "PlayerCamera"
		player.add_child(player_camera)
	player_camera.enabled = true
	player_camera.position_smoothing_enabled = true
	player_camera.position_smoothing_speed = 7.0
	player_camera.anchor_mode = Camera2D.ANCHOR_MODE_DRAG_CENTER
	player_camera.make_current()

func _update_camera_limits() -> void:
	if player_camera == null:
		return
	player_camera.limit_left = 0
	player_camera.limit_top = 0
	player_camera.limit_right = int(current_map_size.x)
	player_camera.limit_bottom = int(current_map_size.y)

func _spawn_floating_text(pos: Vector2, text: String, color: Color) -> void:
	var label := Label.new()
	label.text = text
	label.position = pos
	label.z_index = 130
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	world.add_child(label)
	var tween := create_tween()
	tween.tween_property(label, "position", pos + Vector2(0, -34), 0.55)
	tween.parallel().tween_property(label, "modulate", Color(1, 1, 1, 0), 0.55)
	tween.tween_callback(func() -> void:
		if is_instance_valid(label):
			label.queue_free()
	)

func _update_minimap() -> void:
	if minimap_canvas == null or player == null:
		return
	for child in minimap_canvas.get_children():
		child.queue_free()
	var bg := ColorRect.new()
	bg.position = Vector2.ZERO
	bg.size = MINIMAP_SIZE
	bg.color = Color(0.01, 0.03, 0.05, 0.75)
	minimap_canvas.add_child(bg)
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy == null or not is_instance_valid(enemy):
			continue
		_add_minimap_dot(_minimap_pos(enemy.global_position), Color("#ff4a4a"), 3.0)
	for npc in get_tree().get_nodes_in_group("npcs"):
		if npc == null or not is_instance_valid(npc):
			continue
		_add_minimap_dot(_minimap_pos(npc.global_position), Color("#4ae67a"), 3.0)
	_add_minimap_dot(_minimap_pos(player.global_position), Color("#69beff"), 4.0)

func _minimap_pos(world_pos: Vector2) -> Vector2:
	var x: float = clamp(world_pos.x / max(1.0, current_map_size.x), 0.0, 1.0)
	var y: float = clamp(world_pos.y / max(1.0, current_map_size.y), 0.0, 1.0)
	return Vector2(x * MINIMAP_SIZE.x, y * MINIMAP_SIZE.y)

func _add_minimap_dot(pos: Vector2, color: Color, size: float) -> void:
	var dot := ColorRect.new()
	dot.position = pos - Vector2(size, size)
	dot.size = Vector2(size * 2.0, size * 2.0)
	dot.color = color
	minimap_canvas.add_child(dot)

func _update_pet_combat(delta: float) -> void:
	if player == null or pet_allowed_target == null or not is_instance_valid(pet_allowed_target):
		return
	if player.in_safe_zone or _is_point_in_safe_zone(pet_allowed_target.global_position):
		return
	if pet_allowed_target.vida <= 0:
		pet_allowed_target = null
		return
	var pet_code := _current_equipped_pet_code()
	if pet_code.is_empty():
		return
	var pet_def := _definition_by_code(pet_definitions, pet_code)
	if pet_def.is_empty():
		return
	var distance := player.global_position.distance_to(pet_allowed_target.global_position)
	if distance > 330.0:
		return
	pet_attack_timer -= delta
	if pet_attack_timer > 0:
		return
	pet_attack_timer = max(0.65, float(pet_def.get("attack_interval", 1.6)))
	var pet_entry := _current_equipped_pet_entry()
	var pet_level := int(pet_entry.get("level", 1))
	var damage: int = max(1, int(round(float(pet_def.get("attack", 5)) + float(pet_level - 1) * 1.5 - float(pet_allowed_target.defesa) * 0.25)))
	var from := player.global_position + Vector2(-28, 18)
	if pet_follower != null and is_instance_valid(pet_follower):
		from = pet_follower.global_position
	_spawn_pet_attack_line(from, pet_allowed_target.global_position)
	pet_allowed_target.receive_damage(damage)
	_spawn_floating_text(pet_allowed_target.global_position + Vector2(0, -48), "-%d pet" % damage, Color("#8eea77"))
	var debuff: Dictionary = pet_def.get("debuff", {})
	if not debuff.is_empty():
		pet_allowed_target.apply_pet_debuff(str(debuff.get("type", "")), float(debuff.get("amount", 0.0)), float(debuff.get("duration", 2.0)))
		_spawn_floating_text(pet_allowed_target.global_position + Vector2(0, -64), "debuff", Color("#b68cff"))

func _spawn_pet_attack_line(from: Vector2, to: Vector2) -> void:
	var line := Line2D.new()
	line.width = 4.0
	line.default_color = Color("#8eea77")
	line.z_index = 92
	line.add_point(from)
	line.add_point(to)
	world.add_child(line)
	var tween := create_tween()
	tween.tween_property(line, "modulate", Color(1, 1, 1, 0), 0.26)
	tween.tween_callback(func() -> void:
		if is_instance_valid(line):
			line.queue_free()
	)

func _current_equipped_pet_entry() -> Dictionary:
	var payload: Dictionary = mmo_cache.get("pets_state", {})
	for pet in payload.get("pets", []):
		if typeof(pet) == TYPE_DICTIONARY and bool(pet.get("equipped", false)):
			return pet
	return {}

func _pet_icon_path(code: String) -> String:
	match code:
		"mini_wolf":
			return "res://assets/sprites/enemy_lobo.png"
		"arcane_fairy":
			return "res://assets/sprites/decor_crystal.png"
		"shadow_bat":
			return "res://assets/sprites/enemy_morcego.png"
		"baby_boar":
			return "res://assets/sprites/enemy_javali.png"
		"forest_sprite":
			return "res://assets/sprites/decor_tree.png"
		"ember_imp":
			return "res://assets/sprites/drop_gem.png"
		"frost_wisp":
			return "res://assets/sprites/decor_crystal.png"
		"stone_turtle":
			return "res://assets/sprites/tile_cave.png"
		"venom_spider":
			return "res://assets/sprites/enemy_aranha.png"
		"golden_drake":
			return "res://assets/sprites/enemy_aprendiz.png"
	return "res://assets/sprites/drop_bag.png"

func _pet_bonus_text(bonus: Dictionary) -> String:
	if bonus.has("physical_attack_pct"):
		return "+%d%% ataque fisico" % int(round(float(bonus.get("physical_attack_pct", 0.0)) * 100.0))
	if bonus.has("mana_regen_pct"):
		return "+%d%% regen mana" % int(round(float(bonus.get("mana_regen_pct", 0.0)) * 100.0))
	if bonus.has("attack_speed_pct"):
		return "+%d%% vel. ataque" % int(round(float(bonus.get("attack_speed_pct", 0.0)) * 100.0))
	if bonus.has("max_hp_pct"):
		return "+%d%% vida maxima" % int(round(float(bonus.get("max_hp_pct", 0.0)) * 100.0))
	return "Bonus desconhecido"

func _mount_icon_path(code: String) -> String:
	match code:
		"brown_horse":
			return "res://assets/sprites/enemy_lobo.png"
		"gray_wolf":
			return "res://assets/sprites/enemy_lobo.png"
		"war_boar":
			return "res://assets/sprites/enemy_javali.png"
		"shadow_panther":
			return "res://assets/sprites/enemy_lobo.png"
		"crystal_stag":
			return "res://assets/sprites/decor_crystal.png"
	return "res://assets/sprites/drop_bag.png"

func _update_companion_visuals(delta: float) -> void:
	if player == null:
		return
	companion_anim_time += delta
	var bob := sin(companion_anim_time * 8.0) * 3.0
	var pet_code := _current_equipped_pet_code()
	if not pet_code.is_empty():
		if pet_follower == null or not is_instance_valid(pet_follower):
			pet_follower = Sprite2D.new()
			pet_follower.z_index = 14
			world.add_child(pet_follower)
		pet_follower.texture = load(_pet_icon_path(pet_code))
		pet_follower.scale = Vector2(1.15, 1.15) * (1.0 + sin(companion_anim_time * 10.0) * 0.025)
		pet_follower.flip_h = player.velocity.x > 8.0
		pet_follower.global_position = player.global_position + Vector2(-32, 24 + bob)
	else:
		if pet_follower != null and is_instance_valid(pet_follower):
			pet_follower.queue_free()
			pet_follower = null
	var mount_code := _current_equipped_mount_code()
	if not mount_code.is_empty():
		if mount_follower == null or not is_instance_valid(mount_follower):
			mount_follower = Sprite2D.new()
			mount_follower.z_index = 13
			world.add_child(mount_follower)
		mount_follower.texture = load(_mount_icon_path(mount_code))
		mount_follower.scale = Vector2(1.45, 1.45) * (1.0 + abs(sin(companion_anim_time * 7.0)) * 0.018)
		mount_follower.modulate = Color(1, 1, 1, 0.65)
		mount_follower.flip_h = player.velocity.x > 8.0
		mount_follower.global_position = player.global_position + Vector2(0, 16 + bob * 0.4)
	else:
		if mount_follower != null and is_instance_valid(mount_follower):
			mount_follower.queue_free()
			mount_follower = null

func _current_equipped_pet_code() -> String:
	var payload: Dictionary = mmo_cache.get("pets_state", {})
	for pet in payload.get("pets", []):
		if typeof(pet) == TYPE_DICTIONARY and bool(pet.get("equipped", false)):
			return str(pet.get("code", ""))
	return ""

func _current_equipped_mount_code() -> String:
	var payload: Dictionary = mmo_cache.get("mounts_state", {})
	for mount in payload.get("mounts", []):
		if typeof(mount) == TYPE_DICTIONARY and bool(mount.get("equipped", false)):
			return str(mount.get("code", ""))
	if not online_mode:
		return ""
	return ""

func _player_died() -> void:
	player.revive_in_city()
	_load_map("city_eldoria", Vector2(640, 380))
	_flash("Voce morreu, perdeu 5% do ouro e voltou para Eldoria.")

func _update_hud() -> void:
	if player == null:
		return
	var skills: Array = player.class_data.get("skills", [])
	var cd_text := []
	for i in range(skills.size()):
		cd_text.append("%d:%0.1fs" % [i + 1, SkillSystem.cooldown_left(skills[i])])
	hud_label.text = "%s  |  %s  |  Ouro %d  |  %s" % [player.character_name, player.class_name_selected, player.ouro, " ".join(cd_text)]
	xp_label.text = "Nivel %d" % player.level
	hp_label.text = "HP %d/%d" % [player.vida, player.vida_max]
	mana_label.text = "MP %d/%d" % [player.mana, player.mana_max]
	xp_value_label.text = "XP %d/%d" % [player.xp, player.xp_to_next_level()]
	hp_bar.max_value = max(1, player.vida_max)
	hp_bar.value = player.vida
	xp_bar.max_value = player.xp_to_next_level()
	xp_bar.value = player.xp
	mana_bar.max_value = max(1, player.mana_max)
	mana_bar.value = player.mana
	_update_potion_buttons()

func _update_potion_buttons() -> void:
	if player == null:
		return
	for item_name in potion_buttons.keys():
		var entry: Dictionary = potion_buttons[item_name]
		var button := entry["button"] as Button
		if button == null:
			continue
		var amount := int(player.inventory.items.get(item_name, 0))
		button.text = ""
		button.disabled = (amount <= 0) or (not ui_controls_enabled)
		var count_label := entry["count"] as Label
		if count_label != null:
			count_label.text = "x%d" % amount
			count_label.modulate = Color(1, 1, 1, 1.0 if amount > 0 else 0.42)

func _flash(text: String) -> void:
	message_label.text = text
	message_label.modulate = Color("#f7d67a")

func _flash_red(text: String) -> void:
	message_label.text = text
	message_label.modulate = Color("#ff4b4b")
