extends Button

@export var primary := false

func _ready() -> void:
	focus_mode = Control.FOCUS_NONE
	if Engine.has_singleton("ThemeManager"):
		ThemeManager.style_button(self, primary)

