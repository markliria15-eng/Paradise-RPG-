extends RefCounted
class_name UISideMenu

const MENU_ITEMS := [
	"Batalha", "Habilidades", "Roupa", "Bolsa", "Banco", "Mapa",
	"Party", "Guild", "Rank", "Missoes", "Profissoes", "Pets", "Montarias",
	"Dungeon", "Mercado", "Conquistas", "Temporada", "VIP", "Wikipedia", "Zoom", "Fechar"
]

static func style_button(button: Button, compact: bool = false) -> void:
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(126, 64) if not compact else Vector2(110, 42)
	button.add_theme_font_size_override("font_size", 12 if not compact else 16)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.04, 0.045, 0.055, 0.92)
	normal.border_color = Color(1, 1, 1, 0.28)
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(8)
	var pressed := StyleBoxFlat.new()
	pressed.bg_color = Color(0.14, 0.17, 0.20, 0.96)
	pressed.border_color = Color(1, 1, 1, 0.44)
	pressed.set_border_width_all(2)
	pressed.set_corner_radius_all(8)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", normal)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_color_override("font_color", Color.WHITE)
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
