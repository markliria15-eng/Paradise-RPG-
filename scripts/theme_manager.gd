extends Node

const COLORS := {
	"background": Color("#101014"),
	"panel": Color("#1B1B24"),
	"border": Color("#8A6A2F"),
	"text": Color("#F2EBD3"),
	"hp": Color("#B83232"),
	"mana": Color("#2F5FB8"),
	"xp": Color("#C99A2E"),
	"rare": Color("#3478F6"),
	"epic": Color("#9B4DFF"),
	"legendary": Color("#D6A21E")
}

func color_of(name: String, fallback: Color = Color.WHITE) -> Color:
	return COLORS.get(name, fallback)

func apply_modal_panel(panel: PanelContainer) -> void:
	if panel == null:
		return
	var style := StyleBoxFlat.new()
	style.bg_color = COLORS.panel
	style.border_color = COLORS.border
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	panel.add_theme_stylebox_override("panel", style)

func make_button_style(primary: bool = false) -> Dictionary:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color("#242633") if not primary else Color("#3D3020")
	normal.border_color = COLORS.border
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(8)
	var pressed := StyleBoxFlat.new()
	pressed.bg_color = Color("#2f3445") if not primary else Color("#584229")
	pressed.border_color = Color(COLORS.border.r * 1.1, COLORS.border.g * 1.1, COLORS.border.b * 1.1, 1.0)
	pressed.set_border_width_all(2)
	pressed.set_corner_radius_all(8)
	return {"normal": normal, "pressed": pressed}

func style_button(button: Button, primary: bool = false) -> void:
	if button == null:
		return
	var styles := make_button_style(primary)
	button.add_theme_stylebox_override("normal", styles["normal"])
	button.add_theme_stylebox_override("hover", styles["normal"])
	button.add_theme_stylebox_override("pressed", styles["pressed"])
	button.add_theme_color_override("font_color", COLORS.text)
	button.add_theme_font_size_override("font_size", 16)

func style_progress(bar: ProgressBar, key: String) -> void:
	if bar == null:
		return
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.08, 0.08, 0.11, 0.9)
	bg.border_color = Color(1, 1, 1, 0.16)
	bg.set_border_width_all(1)
	bg.set_corner_radius_all(5)
	var fill := StyleBoxFlat.new()
	fill.bg_color = color_of(key, Color.WHITE)
	fill.set_corner_radius_all(5)
	bar.add_theme_stylebox_override("background", bg)
	bar.add_theme_stylebox_override("fill", fill)
	bar.show_percentage = false
