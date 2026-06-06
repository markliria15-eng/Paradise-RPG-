extends Control

@onready var status_label: Label = $Root/Panel/Margin/VBox/Status
@onready var tabs: TabContainer = $Root/Panel/Margin/VBox/Tabs
@onready var login_input: LineEdit = $Root/Panel/Margin/VBox/Tabs/Entrar/Login
@onready var login_password_input: LineEdit = $Root/Panel/Margin/VBox/Tabs/Entrar/Senha
@onready var register_username_input: LineEdit = $Root/Panel/Margin/VBox/Tabs/Registrar/Login
@onready var register_password_input: LineEdit = $Root/Panel/Margin/VBox/Tabs/Registrar/Senha
@onready var register_email_input: LineEdit = $Root/Panel/Margin/VBox/Tabs/Registrar/Email
@onready var register_character_input: LineEdit = $Root/Panel/Margin/VBox/Tabs/Registrar/Personagem
@onready var class_input: OptionButton = $Root/Panel/Margin/VBox/Tabs/Registrar/Classe

var selected_character_id := 0
var pending_auto_enter := false

func _ready() -> void:
	class_input.add_item("Guerreiro")
	class_input.add_item("Mago")
	class_input.add_item("Arqueiro")
	var mmo := _mmo()
	if mmo != null:
		if not mmo.is_connected("login_ok", Callable(self, "_on_login_ok")):
			mmo.connect("login_ok", Callable(self, "_on_login_ok"))
		if not mmo.is_connected("login_failed", Callable(self, "_on_login_failed")):
			mmo.connect("login_failed", Callable(self, "_on_login_failed"))
		if not mmo.is_connected("world_connected", Callable(self, "_on_world_connected")):
			mmo.connect("world_connected", Callable(self, "_on_world_connected"))
		if not mmo.is_connected("world_message", Callable(self, "_on_world_message")):
			mmo.connect("world_message", Callable(self, "_on_world_message"))
	_set_status("Entre na sua conta ou registre uma nova.", false)

func _on_login_pressed() -> void:
	var login := login_input.text.strip_edges()
	var password := login_password_input.text
	if not _validate_login(login, password):
		return
	pending_auto_enter = true
	_set_status("Entrando...", false)
	_mmo().call("login_account", login, password)

func _on_register_pressed() -> void:
	var username := register_username_input.text.strip_edges()
	var password := register_password_input.text
	var email := register_email_input.text.strip_edges()
	var character_name := register_character_input.text.strip_edges()
	if not _validate_register(username, password, email, character_name):
		return
	pending_auto_enter = true
	_set_status("Criando conta...", false)
	_mmo().call(
		"register_account",
		username,
		email,
		password,
		character_name,
		class_input.get_item_text(class_input.selected)
	)

func _on_open_game_pressed() -> void:
	pending_auto_enter = false
	get_tree().change_scene_to_file("res://scenes/main.tscn")

func _on_login_ok(payload: Dictionary) -> void:
	var chars: Array = payload.get("characters", [])
	if chars.is_empty() and payload.has("character"):
		chars = [payload.get("character")]
	selected_character_id = _first_character_id(chars)
	if pending_auto_enter and selected_character_id > 0:
		_set_status("Conectando no mundo online...", false)
		_mmo().call("connect_world", selected_character_id)
		return
	_set_status("Conta conectada.", false)

func _on_login_failed(message: String) -> void:
	pending_auto_enter = false
	_set_status(_friendly_error(message), true)

func _on_world_connected() -> void:
	_set_status("Online conectado. Entrando no jogo...", false)
	call_deferred("_open_online_game")

func _on_world_message(payload: Dictionary) -> void:
	var msg_type := str(payload.get("type", ""))
	if msg_type == "error":
		pending_auto_enter = false
		_set_status(_friendly_error(str(payload.get("message", "Erro no servidor."))), true)

func _open_online_game() -> void:
	get_tree().change_scene_to_file("res://scenes/main.tscn")

func _first_character_id(characters: Array) -> int:
	for ch in characters:
		if typeof(ch) == TYPE_DICTIONARY:
			return int(ch.get("id", 0))
	return 0

func _validate_login(login: String, password: String) -> bool:
	if login.is_empty():
		return _fail("Erro: informe seu login ou email.")
	if login.find(" ") >= 0:
		return _fail("Erro: nao pode colocar espaco em login.")
	if password.is_empty():
		return _fail("Erro: informe sua senha.")
	if password.length() < 6:
		return _fail("Erro: a senha precisa ter pelo menos 6 caracteres.")
	return true

func _validate_register(username: String, password: String, email: String, character_name: String) -> bool:
	if username.is_empty():
		return _fail("Erro: informe um login.")
	if username.find(" ") >= 0:
		return _fail("Erro: nao pode colocar espaco em login.")
	if not _is_valid_login(username):
		return _fail("Erro: use apenas letras, numeros e _ no login.")
	if not _is_valid_email(email):
		return _fail("Erro: email invalido.")
	if password.length() < 6:
		return _fail("Erro: a senha precisa ter pelo menos 6 caracteres.")
	if character_name.length() < 3:
		return _fail("Erro: nome do personagem muito curto.")
	return true

func _is_valid_login(value: String) -> bool:
	var regex := RegEx.new()
	regex.compile("^[A-Za-z0-9_]+$")
	return regex.search(value) != null

func _is_valid_email(value: String) -> bool:
	var regex := RegEx.new()
	regex.compile("^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$")
	return regex.search(value) != null

func _fail(message: String) -> bool:
	_set_status(message, true)
	return false

func _friendly_error(message: String) -> String:
	var lower := message.to_lower()
	if lower.find("invalid_type") >= 0 or lower.find("invalid_string") >= 0 or lower.find("zod") >= 0:
		return "Erro: dados invalidos. Confira login, email e senha."
	if lower.find("email") >= 0 and lower.find("invalid") >= 0:
		return "Erro: email invalido."
	if lower.find("username") >= 0 and lower.find("regex") >= 0:
		return "Erro: nao pode colocar espaco em login."
	if lower.find("credenciais") >= 0:
		return "Erro: login ou senha incorretos."
	if lower.find("cadastrado") >= 0:
		return "Erro: essa conta ja existe."
	if lower.find("personagem") >= 0 and lower.find("uso") >= 0:
		return "Erro: nome de personagem ja esta em uso."
	if lower.find("websocket") >= 0:
		return "Erro: nao foi possivel conectar ao mundo online."
	if message.begins_with("[") or message.begins_with("{"):
		return "Erro: dados invalidos. Confira os campos."
	return "Erro: " + message.trim_prefix("Erro: ")

func _set_status(message: String, is_error: bool) -> void:
	status_label.text = message
	status_label.add_theme_color_override("font_color", Color(1.0, 0.25, 0.22, 1.0) if is_error else Color(0.92, 0.84, 0.66, 1.0))

func _mmo() -> Node:
	return get_node_or_null("/root/MMOClient")
