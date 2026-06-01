extends PanelContainer

signal close_requested

@onready var title_label: Label = $Root/Header/Title
@onready var close_button: Button = $Root/Header/Close
@onready var content: Control = $Root/Content

func _ready() -> void:
	if Engine.has_singleton("ThemeManager"):
		ThemeManager.apply_modal_panel(self)
		ThemeManager.style_button(close_button, true)
	close_button.pressed.connect(func() -> void:
		close_requested.emit()
		visible = false
	)

func set_title(text: String) -> void:
	title_label.text = text

