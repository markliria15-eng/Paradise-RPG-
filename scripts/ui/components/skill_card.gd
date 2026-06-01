extends PanelContainer

@onready var icon_rect: TextureRect = $Root/Icon
@onready var name_label: Label = $Root/Info/Top/Name
@onready var level_label: Label = $Root/Info/Top/Level
@onready var bar: ProgressBar = $Root/Info/Bar
@onready var xp_label: Label = $Root/Info/Xp

func _ready() -> void:
	if Engine.has_singleton("ThemeManager"):
		ThemeManager.apply_modal_panel(self)
		ThemeManager.style_progress(bar, "xp")

func set_skill(icon: Texture2D, skill_name: String, level: int, xp: int, xp_required: int) -> void:
	icon_rect.texture = icon
	name_label.text = skill_name
	level_label.text = str(level)
	bar.max_value = max(1, xp_required)
	bar.value = clamp(xp, 0, xp_required)
	var pct := int((float(xp) / max(1.0, float(xp_required))) * 100.0)
	xp_label.text = "%d/%d (%d%%)" % [xp, xp_required, pct]

