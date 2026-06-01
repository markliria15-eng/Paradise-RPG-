extends Node

signal login_ok(payload: Dictionary)
signal login_failed(message: String)
signal world_connected()
signal world_disconnected()
signal world_message(payload: Dictionary)

var http_base_url := "http://127.0.0.1:8080"
var ws_url := "ws://127.0.0.1:8081"
var online_enabled := false
var token := ""
var selected_character_id := 0
var account_payload: Dictionary = {}

var _socket := WebSocketPeer.new()
var _http: HTTPRequest

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_config()
	_http = HTTPRequest.new()
	add_child(_http)
	set_process(true)

func _process(_delta: float) -> void:
	if _socket == null:
		return
	_socket.poll()
	var state := _socket.get_ready_state()
	if state == WebSocketPeer.STATE_OPEN:
		while _socket.get_available_packet_count() > 0:
			var data := _socket.get_packet().get_string_from_utf8()
			var parsed = JSON.parse_string(data)
			if typeof(parsed) == TYPE_DICTIONARY:
				world_message.emit(parsed)
	elif state == WebSocketPeer.STATE_CLOSED:
		if online_enabled:
			world_disconnected.emit()

func _load_config() -> void:
	var file := FileAccess.open("res://client/config/mmo_client_config.json", FileAccess.READ)
	if file == null:
		return
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	http_base_url = str(parsed.get("http_base_url", http_base_url))
	ws_url = str(parsed.get("ws_url", ws_url))
	online_enabled = bool(parsed.get("online_enabled", false))

func register_account(username: String, email: String, password: String, character_name: String, class_id: String) -> void:
	var body := {
		"username": username,
		"email": email,
		"password": password,
		"characterName": character_name,
		"className": class_id
	}
	_send_http("/auth/register", body, Callable(self, "_on_register_response"))

func login_account(email: String, password: String) -> void:
	_send_http("/auth/login", {"email": email, "password": password}, Callable(self, "_on_login_response"))

func connect_world(character_id: int) -> void:
	if token.is_empty():
		login_failed.emit("Token vazio.")
		return
	selected_character_id = character_id
	var err := _socket.connect_to_url(ws_url)
	if err != OK:
		login_failed.emit("Falha ao conectar websocket.")
		return
	await get_tree().create_timer(0.5).timeout
	send({
		"type": "auth",
		"token": token,
		"characterId": character_id
	})

func send(payload: Dictionary) -> void:
	if _socket.get_ready_state() != WebSocketPeer.STATE_OPEN:
		return
	_socket.send_text(JSON.stringify(payload))

func send_move(map_id: String, position: Vector2) -> void:
	send({
		"type": "move",
		"map": map_id,
		"pos": {"x": position.x, "y": position.y}
	})

func send_chat(channel: String, text: String) -> void:
	send({
		"type": "chat",
		"channel": channel,
		"text": text
	})

func send_pvp_attack(target_character_id: int, power: float, base_attack: int) -> void:
	send({
		"type": "pvp_attack",
		"targetCharacterId": target_character_id,
		"power": power,
		"baseAttack": base_attack
	})

func request_professions() -> void:
	send({"type": "professions_get"})

func request_crafting_recipes() -> void:
	send({"type": "crafting_list"})

func craft(recipe_code: String) -> void:
	send({"type": "crafting_craft", "recipeCode": recipe_code})

func request_pets() -> void:
	send({"type": "pets_get"})

func equip_pet(character_pet_id: int) -> void:
	send({"type": "pets_equip", "characterPetId": character_pet_id})

func request_mounts() -> void:
	send({"type": "mounts_get"})

func equip_mount(character_mount_id: int) -> void:
	send({"type": "mounts_equip", "characterMountId": character_mount_id})

func request_dungeons() -> void:
	send({"type": "dungeons_get"})

func start_dungeon(dungeon_code: String) -> void:
	send({"type": "dungeon_start", "dungeonCode": dungeon_code})

func request_rank(rank_key: String) -> void:
	send({"type": "rank_get", "rankKey": rank_key})

func request_market(category: String = "", rarity: String = "", search: String = "") -> void:
	send({
		"type": "market_get",
		"category": category,
		"rarity": rarity,
		"search": search
	})

func list_market_item(item_id: String, quantity: int, price: int, category: String, rarity: String = "common") -> void:
	send({
		"type": "market_list_item",
		"itemId": item_id,
		"quantity": quantity,
		"price": price,
		"category": category,
		"rarity": rarity
	})

func buy_market_item(listing_id: int) -> void:
	send({"type": "market_buy", "listingId": listing_id})

func request_vip() -> void:
	send({"type": "vip_get"})

func request_achievements() -> void:
	send({"type": "achievements_get"})

func request_season() -> void:
	send({"type": "season_get"})

func _send_http(path: String, payload: Dictionary, callback: Callable) -> void:
	if _http.request_completed.is_connected(callback):
		_http.request_completed.disconnect(callback)
	_http.request_completed.connect(callback, CONNECT_ONE_SHOT)
	var headers := ["Content-Type: application/json"]
	var err := _http.request(http_base_url + path, headers, HTTPClient.METHOD_POST, JSON.stringify(payload))
	if err != OK:
		login_failed.emit("Falha HTTP: " + str(err))

func _on_register_response(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	var parsed = JSON.parse_string(body.get_string_from_utf8())
	if response_code >= 400 or typeof(parsed) != TYPE_DICTIONARY or not bool(parsed.get("ok", false)):
		login_failed.emit(str(parsed.get("message", "Falha ao registrar.")) if typeof(parsed) == TYPE_DICTIONARY else "Falha ao registrar.")
		return
	token = str(parsed.get("token", ""))
	account_payload = parsed
	selected_character_id = int(parsed.get("character", {}).get("id", 0))
	login_ok.emit(parsed)

func _on_login_response(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	var parsed = JSON.parse_string(body.get_string_from_utf8())
	if response_code >= 400 or typeof(parsed) != TYPE_DICTIONARY or not bool(parsed.get("ok", false)):
		login_failed.emit(str(parsed.get("message", "Falha no login.")) if typeof(parsed) == TYPE_DICTIONARY else "Falha no login.")
		return
	token = str(parsed.get("token", ""))
	account_payload = parsed
	login_ok.emit(parsed)
