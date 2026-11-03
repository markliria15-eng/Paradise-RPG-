extends Node

signal login_ok(payload: Dictionary)
signal login_failed(message: String)
signal world_connected()
signal world_disconnected()
signal world_message(payload: Dictionary)

const CONFIG_DIR := "res://client/config"
const DEFAULT_CONFIG_PATH := CONFIG_DIR + "/mmo_client_config.json"
const VALID_ENVIRONMENTS := ["local", "staging", "production"]

var http_base_url := "http://127.0.0.1:3000"
var ws_url := "ws://127.0.0.1:3000/ws"
var online_enabled := false
var environment_name := "staging"
var environment_label := "Teste online"
var active_config_path := DEFAULT_CONFIG_PATH
var active_config: Dictionary = {}
var token := ""
var selected_character_id := 0
var account_payload: Dictionary = {}
var launcher_start_offline := false
var launcher_class := "Guerreiro"
var launcher_boot_nonce := 0

var _socket: WebSocketPeer = WebSocketPeer.new()
var _http: HTTPRequest
var _http_in_flight := false
var _connecting := false
var _auth_sent := false
var _last_socket_state := WebSocketPeer.STATE_CLOSED

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_config()
	_http = HTTPRequest.new()
	_http.timeout = 15.0
	add_child(_http)
	set_process(true)

func _process(_delta: float) -> void:
	if _socket == null:
		return
	_socket.poll()
	var state := _socket.get_ready_state()
	if state == WebSocketPeer.STATE_OPEN:
		if _connecting and not _auth_sent:
			_auth_sent = true
			send({
				"type": "auth",
				"token": token,
				"characterId": selected_character_id
			})
		while _socket.get_available_packet_count() > 0:
			var data := _socket.get_packet().get_string_from_utf8()
			var parsed = JSON.parse_string(data)
			if typeof(parsed) == TYPE_DICTIONARY:
				if str(parsed.get("type", "")) == "auth_ok":
					_connecting = false
					world_connected.emit()
				world_message.emit(parsed)
	elif state == WebSocketPeer.STATE_CLOSED:
		if _last_socket_state != WebSocketPeer.STATE_CLOSED:
			if _connecting:
				login_failed.emit(_websocket_close_message())
			elif online_enabled:
				world_disconnected.emit()
			_connecting = false
			_auth_sent = false
	_last_socket_state = state

func _load_config() -> void:
	environment_name = _requested_environment()
	var profile_path := "%s/mmo_client_config.%s.json" % [CONFIG_DIR, environment_name]
	active_config_path = profile_path if FileAccess.file_exists(profile_path) else DEFAULT_CONFIG_PATH
	var file := FileAccess.open(active_config_path, FileAccess.READ)
	if file == null:
		return
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	active_config = parsed
	http_base_url = str(parsed.get("http_base_url", http_base_url)).strip_edges()
	if http_base_url.ends_with("/"):
		http_base_url = http_base_url.substr(0, http_base_url.length() - 1)
	ws_url = str(parsed.get("ws_url", ws_url)).strip_edges()
	online_enabled = bool(parsed.get("online_enabled", false))
	environment_label = str(parsed.get("environment_label", environment_name.capitalize()))
	print("MMO environment: %s (%s)" % [environment_name, http_base_url])

func _requested_environment() -> String:
	var requested := OS.get_environment("PARADISE_MMO_ENV").strip_edges().to_lower()
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--mmo-env="):
			requested = argument.trim_prefix("--mmo-env=").strip_edges().to_lower()
	if requested in VALID_ENVIRONMENTS:
		return requested
	if OS.has_feature("android"):
		return "production"
	return "staging"

func get_active_config() -> Dictionary:
	return active_config.duplicate(true)

func get_environment_label() -> String:
	return environment_label

func prepare_offline_start(chosen_class: String = "Guerreiro") -> void:
	launcher_start_offline = true
	launcher_class = chosen_class if not chosen_class.is_empty() else "Guerreiro"
	launcher_boot_nonce += 1
	online_enabled = false
	token = ""
	selected_character_id = 0
	account_payload = {}

func consume_offline_start() -> Dictionary:
	var payload := {
		"start_offline": launcher_start_offline,
		"class_name": launcher_class,
		"nonce": launcher_boot_nonce
	}
	launcher_start_offline = false
	launcher_class = "Guerreiro"
	return payload

func register_account(username: String, email: String, password: String, character_name: String, class_id: String) -> void:
	var body := {
		"username": username,
		"email": email,
		"password": password,
		"characterName": character_name,
		"className": class_id
	}
	_send_http("/auth/register", body, Callable(self, "_on_register_response"))

func login_account(login: String, password: String) -> void:
	_send_http("/auth/login", {"login": login, "password": password}, Callable(self, "_on_login_response"))

func connect_world(character_id: int) -> void:
	if token.is_empty():
		login_failed.emit("Token vazio.")
		return
	selected_character_id = character_id
	_socket.close()
	_socket = WebSocketPeer.new()
	_connecting = true
	_auth_sent = false
	_last_socket_state = WebSocketPeer.STATE_CONNECTING
	var tls_options: TLSOptions = null
	if ws_url.begins_with("wss://"):
		tls_options = TLSOptions.client()
	var err := _socket.connect_to_url(ws_url, tls_options)
	if err != OK:
		_connecting = false
		login_failed.emit("Falha ao conectar websocket. Erro: " + str(err))
		return

func send(payload: Dictionary) -> void:
	if _socket.get_ready_state() != WebSocketPeer.STATE_OPEN:
		return
	_socket.send_text(JSON.stringify(payload))

func _websocket_close_message() -> String:
	var code := _socket.get_close_code()
	var reason := _socket.get_close_reason()
	if reason.is_empty():
		return "Falha ao conectar websocket. Codigo: " + str(code)
	return "Falha ao conectar websocket. Codigo: " + str(code) + " - " + reason

func send_move(map_id: String, position: Vector2) -> void:
	send({
		"type": "move",
		"map": map_id,
		"pos": {"x": position.x, "y": position.y}
	})

func send_character_save(state: Dictionary) -> void:
	send({
		"type": "character_save",
		"state": state
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
	if _http_in_flight:
		return
	if _http.request_completed.is_connected(callback):
		_http.request_completed.disconnect(callback)
	_http.request_completed.connect(callback, CONNECT_ONE_SHOT)
	var headers := ["Content-Type: application/json"]
	_http_in_flight = true
	var err := _http.request(http_base_url + path, headers, HTTPClient.METHOD_POST, JSON.stringify(payload))
	if err != OK:
		_http_in_flight = false
		login_failed.emit(_http_error_message(err))

func _on_register_response(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	_http_in_flight = false
	if result != HTTPRequest.RESULT_SUCCESS:
		login_failed.emit("Erro: nao foi possivel conectar ao servidor.")
		return
	var parsed := _parse_json_dictionary(body)
	if response_code < 200 or response_code >= 300:
		login_failed.emit(str(parsed.get("message", _http_status_message(response_code))) if not parsed.is_empty() else _http_status_message(response_code))
		return
	if parsed.is_empty() or not bool(parsed.get("ok", false)):
		login_failed.emit(str(parsed.get("message", "Falha ao registrar.")) if not parsed.is_empty() else "Falha ao registrar.")
		return
	token = str(parsed.get("token", ""))
	account_payload = parsed
	selected_character_id = int(parsed.get("character", {}).get("id", 0))
	login_ok.emit(parsed)

func _on_login_response(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	_http_in_flight = false
	if result != HTTPRequest.RESULT_SUCCESS:
		login_failed.emit("Erro: nao foi possivel conectar ao servidor.")
		return
	var parsed := _parse_json_dictionary(body)
	if response_code < 200 or response_code >= 300:
		login_failed.emit(str(parsed.get("message", _http_status_message(response_code))) if not parsed.is_empty() else _http_status_message(response_code))
		return
	if parsed.is_empty() or not bool(parsed.get("ok", false)):
		login_failed.emit(str(parsed.get("message", "Falha no login.")) if not parsed.is_empty() else "Falha no login.")
		return
	token = str(parsed.get("token", ""))
	account_payload = parsed
	login_ok.emit(parsed)

func _parse_json_dictionary(body: PackedByteArray) -> Dictionary:
	var parser := JSON.new()
	if parser.parse(body.get_string_from_utf8()) != OK:
		return {}
	var data = parser.data
	return data if typeof(data) == TYPE_DICTIONARY else {}

func _http_error_message(err: int) -> String:
	if err == ERR_BUSY:
		return "Erro: aguarde, login em andamento."
	if err == ERR_CANT_CONNECT:
		return "Erro: nao foi possivel conectar ao servidor."
	if err == ERR_CANT_RESOLVE:
		return "Erro: servidor online nao encontrado."
	if err == ERR_INVALID_PARAMETER:
		return "Erro: endereco do servidor invalido."
	return "Erro: falha ao conectar ao servidor."

func _http_status_message(response_code: int) -> String:
	if response_code == 503:
		return "Erro: servidor online indisponivel no momento."
	if response_code >= 500:
		return "Erro: servidor online com instabilidade."
	if response_code == 401 or response_code == 403:
		return "Erro: login ou senha incorretos."
	return "Erro: falha no servidor online."
