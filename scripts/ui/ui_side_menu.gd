extends Control

signal action_pressed(action: String)

const MENU_ITEMS := [
	"Personagem",
	"Habilidades",
	"Equipar",
	"Bolsa",
	"Missoes",
	"Mapa",
	"Shop",
	"Guild",
	"Party",
	"Rank",
	"Mercado",
	"Pets",
	"Montarias",
	"Crafting",
	"Profissoes",
	"Dungeon",
	"VIP",
	"Conquistas",
	"Temporada",
	"HUD",
	"Wikipedia",
	"Configuracoes"
]

@onready var grid: GridContainer = $Root/Grid

func _ready() -> void:
	_build_buttons()

func _build_buttons() -> void:
	for child in grid.get_children():
		child.queue_free()
	var theme_manager := get_node_or_null("/root/ThemeManager")
	for item in MENU_ITEMS:
		var button := Button.new()
		button.text = str(item)
		button.custom_minimum_size = Vector2(146, 56)
		button.focus_mode = Control.FOCUS_NONE
		if theme_manager != null and theme_manager.has_method("style_button"):
			theme_manager.call("style_button", button)
		button.pressed.connect(func() -> void:
			action_pressed.emit(str(item))
		)
		grid.add_child(button)
