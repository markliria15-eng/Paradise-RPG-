extends Button

@export var rarity: String = "common"
@onready var amount_label: Label = $Amount

func _ready() -> void:
	focus_mode = Control.FOCUS_NONE
	_apply_style()

func set_item(icon: Texture2D, amount: int, rarity_name: String) -> void:
	self.icon = icon
	self.expand_icon = true
	rarity = rarity_name
	amount_label.text = "x%d" % amount if amount > 1 else ""
	_apply_style()

func _apply_style() -> void:
	var border := Color("#70747d")
	match rarity:
		"incomum":
			border = Color("#4caf50")
		"raro":
			border = Color("#3478F6")
		"epico":
			border = Color("#9B4DFF")
		"lendario":
			border = Color("#D6A21E")
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color("#161822")
	normal.border_color = border
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(6)
	add_theme_stylebox_override("normal", normal)
	add_theme_stylebox_override("hover", normal)
	add_theme_stylebox_override("pressed", normal)

