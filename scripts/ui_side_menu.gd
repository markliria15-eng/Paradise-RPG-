extends RefCounted
class_name UISideMenu

const MENU_ITEMS := [
	"Batalha", "Habilidades", "Roupa", "Bolsa", "Banco", "Mapa",
	"Party", "Guild", "Rank", "Missoes", "Profissoes", "Pets", "Montarias",
	"Dungeon", "Mercado", "Conquistas", "Temporada", "VIP", "HUD", "Wikipedia", "Zoom", "Deslogar"
]

const MENU_ICON_BY_ITEM := {
	"Batalha": "res://assets/ui/buttons/btn_attack.png",
	"Habilidades": "res://assets/sprites/icon_ui_skills_premium.png",
	"Roupa": "res://assets/sprites/icon_slot_armor.png",
	"Bolsa": "res://assets/sprites/icon_ui_bag_premium.png",
	"Banco": "res://assets/sprites/drop_coin.png",
	"Mapa": "res://assets/sprites/decor_portal.png",
	"Party": "res://assets/sprites/icon_slot_amulet.png",
	"Guild": "res://assets/sprites/icon_slot_shield.png",
	"Rank": "res://assets/sprites/drop_gem.png",
	"Missoes": "res://assets/sprites/icon_ui_quests_premium.png",
	"Profissoes": "res://assets/sprites/drop_ore.png",
	"Pets": "res://assets/sprites/enemy_lobo.png",
	"Montarias": "res://assets/sprites/enemy_javali.png",
	"Dungeon": "res://assets/sprites/tile_cave.png",
	"Mercado": "res://assets/sprites/drop_bag.png",
	"Conquistas": "res://assets/sprites/drop_gem.png",
	"Temporada": "res://assets/ui/skills/skill_mana_viva.png",
	"VIP": "res://assets/sprites/icon_slot_jewel.png",
	"HUD": "res://assets/ui/buttons/btn_menu.png",
	"Wikipedia": "res://assets/ui/buttons/btn_wiki.png",
	"Zoom": "res://assets/sprites/icon_slot_ring.png",
	"Deslogar": "res://assets/sprites/icon_menu_close.png"
}

static func style_button(button: Button, compact: bool = false) -> void:
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(146, 64) if not compact else Vector2(122, 46)
	button.add_theme_font_size_override("font_size", 13 if not compact else 16)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.035, 0.032, 0.024, 0.96)
	normal.border_color = Color("#c49b3f")
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(8)
	normal.content_margin_left = 10
	normal.content_margin_right = 10
	normal.content_margin_top = 6
	normal.content_margin_bottom = 6
	var pressed := StyleBoxFlat.new()
	pressed.bg_color = Color(0.12, 0.095, 0.055, 0.98)
	pressed.border_color = Color("#f0cd73")
	pressed.set_border_width_all(2)
	pressed.set_corner_radius_all(8)
	pressed.content_margin_left = 10
	pressed.content_margin_right = 10
	pressed.content_margin_top = 6
	pressed.content_margin_bottom = 6
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", normal)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_color_override("font_color", Color("#f2e5c7"))
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color("#fff0c8"))
	button.add_theme_constant_override("h_separation", 10)
	button.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
