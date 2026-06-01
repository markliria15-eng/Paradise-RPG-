extends Node

var players: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_register_player("ui_click")
	_register_player("ui_open")
	_register_player("ui_close")
	_register_player("equip")
	_register_player("buy")
	_register_player("level_up")
	_register_player("rare_drop")
	_register_player("error")

func _register_player(key: String) -> void:
	var stream := AudioStreamPlayer.new()
	stream.name = key
	add_child(stream)
	players[key] = stream

func play_sfx(key: String) -> void:
	var stream: AudioStreamPlayer = players.get(key, null)
	if stream == null:
		return
	# Placeholder: sem arquivos finais de audio, usa beep sintetico no futuro.
	# Mantem a chamada centralizada para trocar por assets reais depois.
	stream.stop()
