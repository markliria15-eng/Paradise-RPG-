extends Control

signal class_selected(selected_class: String)

func _ready() -> void:
	$Root/Cards/Warrior/Select.pressed.connect(func() -> void:
		class_selected.emit("Guerreiro")
	)
	$Root/Cards/Mage/Select.pressed.connect(func() -> void:
		class_selected.emit("Mago")
	)
	$Root/Cards/Archer/Select.pressed.connect(func() -> void:
		class_selected.emit("Arqueiro")
	)
