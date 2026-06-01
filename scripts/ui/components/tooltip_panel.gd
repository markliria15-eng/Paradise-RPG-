extends PanelContainer

@onready var title_label: Label = $Root/Title
@onready var desc_label: Label = $Root/Desc
@onready var rarity_label: Label = $Root/Rarity

func _ready() -> void:
	if Engine.has_singleton("ThemeManager"):
		ThemeManager.apply_modal_panel(self)

func set_tooltip(item_name: String, description: String, rarity: String) -> void:
	title_label.text = item_name
	desc_label.text = description
	rarity_label.text = "Raridade: " + rarity

