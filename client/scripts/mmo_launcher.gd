extends Control

@onready var status_label: Label = $Root/Status
@onready var email_input: LineEdit = $Root/Form/Email
@onready var password_input: LineEdit = $Root/Form/Password
@onready var username_input: LineEdit = $Root/Form/Username
@onready var character_input: LineEdit = $Root/Form/Character
@onready var class_input: OptionButton = $Root/Form/Class
@onready var character_select: OptionButton = $Root/Form/CharacterSelect
@onready var connect_world_button: Button = $Root/Form/ConnectWorld

var selected_character_id := 0

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
		if not mmo.is_connected("world_message", Callable(self, "_on_world_message")):
			mmo.connect("world_message", Callable(self, "_on_world_message"))
	_update_character_select([])

func _on_login_pressed() -> void:
	status_label.text = "Entrando..."
	_mmo().call("login_account", email_input.text.strip_edges(), password_input.text)

func _on_register_pressed() -> void:
	status_label.text = "Registrando..."
	_mmo().call(
		"register_account",
		username_input.text.strip_edges(),
		email_input.text.strip_edges(),
		password_input.text,
		character_input.text.strip_edges(),
		class_input.get_item_text(class_input.selected)
	)

func _on_connect_world_pressed() -> void:
	if selected_character_id <= 0:
		status_label.text = "Selecione um personagem."
		return
	status_label.text = "Conectando no mundo..."
	_mmo().call("connect_world", selected_character_id)

func _on_open_game_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main.tscn")

func _on_login_ok(payload: Dictionary) -> void:
	status_label.text = "Login OK."
	var chars: Array = payload.get("characters", [])
	if chars.is_empty() and payload.has("character"):
		chars = [payload.get("character")]
	_update_character_select(chars)

func _on_login_failed(message: String) -> void:
	status_label.text = "Erro: " + message

func _on_world_message(payload: Dictionary) -> void:
	var msg_type := str(payload.get("type", ""))
	if msg_type == "auth_ok":
		status_label.text = "Conectado no mundo. Abra o jogo."
	elif msg_type == "error":
		status_label.text = str(payload.get("message", "Erro no servidor."))

func _update_character_select(characters: Array) -> void:
	character_select.clear()
	selected_character_id = 0
	for ch in characters:
		if typeof(ch) != TYPE_DICTIONARY:
			continue
		var ch_id := int(ch.get("id", 0))
		var name := str(ch.get("name", "Sem nome"))
		var class_id := str(ch.get("class", ""))
		character_select.add_item("%s (%s)" % [name, class_id], ch_id)
	if character_select.item_count > 0:
		character_select.select(0)
		selected_character_id = character_select.get_selected_id()
	connect_world_button.disabled = character_select.item_count == 0

func _on_character_select_item_selected(_index: int) -> void:
	selected_character_id = character_select.get_selected_id()

func _mmo() -> Node:
	return get_node_or_null("/root/MMOClient")
