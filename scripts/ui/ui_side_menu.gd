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
	"Configuracoes",
	"Deslogar"
]

const MENU_ICON_BY_ITEM := {
	"Personagem": "res://assets/ui/buttons/btn_menu.png",
	"Habilidades": "res://assets/sprites/icon_ui_skills_premium.png",
	"Equipar": "res://assets/sprites/icon_slot_armor.png",
	"Bolsa": "res://assets/sprites/icon_ui_bag_premium.png",
	"Missoes": "res://assets/sprites/icon_ui_quests_premium.png",
	"Mapa": "res://assets/sprites/decor_portal.png",
	"Shop": "res://assets/sprites/drop_coin.png",
	"Guild": "res://assets/sprites/icon_slot_shield.png",
	"Party": "res://assets/sprites/icon_slot_amulet.png",
	"Rank": "res://assets/sprites/drop_gem.png",
	"Mercado": "res://assets/sprites/drop_bag.png",
	"Pets": "res://assets/sprites/enemy_lobo.png",
	"Montarias": "res://assets/sprites/enemy_javali.png",
	"Crafting": "res://assets/sprites/npc_forge.png",
	"Profissoes": "res://assets/sprites/drop_ore.png",
	"Dungeon": "res://assets/sprites/tile_cave.png",
	"VIP": "res://assets/sprites/icon_slot_jewel.png",
	"Conquistas": "res://assets/sprites/drop_gem.png",
	"Temporada": "res://assets/ui/skills/skill_mana_viva.png",
	"HUD": "res://assets/ui/buttons/btn_menu.png",
	"Wikipedia": "res://assets/ui/buttons/btn_wiki.png",
	"Configuracoes": "res://assets/sprites/icon_menu_close.png",
	"Deslogar": "res://assets/sprites/icon_menu_close.png"
}

@onready var grid: GridContainer = $Root/Grid
@onready var root_panel: PanelContainer = $Root

func _ready() -> void:
	_style_root_panel()
	_build_buttons()

func _style_root_panel() -> void:
	if root_panel == null:
		return
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color(0.016, 0.014, 0.012, 0.94)
	panel.border_color = Color("#c89d40")
	panel.set_border_width_all(2)
	panel.set_corner_radius_all(10)
	panel.content_margin_left = 12
	panel.content_margin_right = 12
	panel.content_margin_top = 12
	panel.content_margin_bottom = 12
	root_panel.add_theme_stylebox_override("panel", panel)

func _build_buttons() -> void:
	for child in grid.get_children():
		child.queue_free()
	for item in MENU_ITEMS:
		var item_label := str(item)
		var button := Button.new()
		button.text = item_label
		button.custom_minimum_size = Vector2(150, 66)
		button.focus_mode = Control.FOCUS_NONE
		button.mouse_filter = Control.MOUSE_FILTER_STOP
		_style_button(button)
		var icon_path := str(MENU_ICON_BY_ITEM.get(item_label, ""))
		if not icon_path.is_empty():
			var icon := load(icon_path)
			if icon != null:
				button.icon = icon
				button.expand_icon = true
		button.tooltip_text = item_label
		button.pressed.connect(Callable(self, "_emit_menu_action").bind(item_label))
		grid.add_child(button)

func _emit_menu_action(item_label: String) -> void:
	action_pressed.emit(item_label)

func _style_button(button: Button) -> void:
	if button == null:
		return
	button.add_theme_font_size_override("font_size", 13)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.04, 0.035, 0.025, 0.96)
	normal.border_color = Color("#c89d40")
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(8)
	normal.content_margin_left = 12
	normal.content_margin_right = 10
	normal.content_margin_top = 8
	normal.content_margin_bottom = 8
	var hover := StyleBoxFlat.new()
	hover.bg_color = Color(0.085, 0.068, 0.04, 0.98)
	hover.border_color = Color("#f0cf78")
	hover.set_border_width_all(2)
	hover.set_corner_radius_all(8)
	hover.content_margin_left = 12
	hover.content_margin_right = 10
	hover.content_margin_top = 8
	hover.content_margin_bottom = 8
	var pressed := StyleBoxFlat.new()
	pressed.bg_color = Color(0.12, 0.095, 0.05, 0.98)
	pressed.border_color = Color("#ffe08f")
	pressed.set_border_width_all(2)
	pressed.set_corner_radius_all(8)
	pressed.content_margin_left = 12
	pressed.content_margin_right = 10
	pressed.content_margin_top = 8
	pressed.content_margin_bottom = 8
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_color_override("font_color", Color("#f2e5c7"))
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color("#fff2c9"))
	button.add_theme_constant_override("h_separation", 10)
	button.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
