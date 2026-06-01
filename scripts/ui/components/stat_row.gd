extends HBoxContainer

@onready var key_label: Label = $Key
@onready var value_label: Label = $Value

func set_stat(k: String, v: String) -> void:
	key_label.text = k
	value_label.text = v

