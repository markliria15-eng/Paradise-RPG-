extends Control

signal login_pressed(email: String, password: String)
signal register_pressed(username: String, email: String, password: String)

@onready var email_input: LineEdit = $Root/Form/Email
@onready var password_input: LineEdit = $Root/Form/Password
@onready var username_input: LineEdit = $Root/Form/Username
@onready var status_label: Label = $Root/Form/Status

func _ready() -> void:
	$Root/Form/Login.pressed.connect(func() -> void:
		login_pressed.emit(email_input.text.strip_edges(), password_input.text)
	)
	$Root/Form/Register.pressed.connect(func() -> void:
		register_pressed.emit(username_input.text.strip_edges(), email_input.text.strip_edges(), password_input.text)
	)

func set_status(text_value: String) -> void:
	status_label.text = text_value

