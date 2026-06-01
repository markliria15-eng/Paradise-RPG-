extends ProgressBar

@export var color_key := "xp"

func _ready() -> void:
	if Engine.has_singleton("ThemeManager"):
		ThemeManager.style_progress(self, color_key)

