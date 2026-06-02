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
	"Wikipedia",
	"Configuracoes"
]

@onready var grid: GridContainer = $Root/Grid

func _ready() -> void:
	_build_buttons()

func _build_buttons() -> void:
	for child in grid.get_children():
		child.queue_free()
	for item in MENU_ITEMS:
		var button := Button.new()
		button.text = str(item)
		button.custom_minimum_size = Vector2(146, 56)
		button.focus_mode = Control.FOCUS_NONE
		if Engine.has_singleton("ThemeManager"):
			ThemeManager.style_button(button)
		button.pressed.connect(func() -> void:
			action_pressed.emit(str(item))
		)
		grid.add_child(button)
