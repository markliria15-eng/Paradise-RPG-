extends PanelContainer

signal close_requested

@onready var close_button: Button = $Root/Header/Close
@onready var info_label: Label = $Root/Body/Info
@onready var list: VBoxContainer = $Root/Body/Scroll/List

func _ready() -> void:
	if Engine.has_singleton("ThemeManager"):
		ThemeManager.apply_modal_panel(self)
		ThemeManager.style_button(close_button, true)
	close_button.pressed.connect(func() -> void:
		close_requested.emit()
		visible = false
	)

func set_summary(name: String, level: int, xp: int, xp_need: int, hp: int, hp_max: int, mp: int, mp_max: int) -> void:
	info_label.text = "Nome: %s | Lv.%d | XP %d/%d | HP %d/%d | MP %d/%d" % [name, level, xp, xp_need, hp, hp_max, mp, mp_max]

func set_skills(rows: Array) -> void:
	for child in list.get_children():
		child.queue_free()
	for row_data in rows:
		if typeof(row_data) != TYPE_DICTIONARY:
			continue
		var row := HBoxContainer.new()
		row.custom_minimum_size = Vector2(520, 50)
		var name_label := Label.new()
		name_label.custom_minimum_size = Vector2(180, 26)
		name_label.text = "%s  %d" % [str(row_data.get("name", "")), int(row_data.get("level", 1))]
		row.add_child(name_label)
		var bar := ProgressBar.new()
		var xp := int(row_data.get("xp", 0))
		var need: int = max(1, int(row_data.get("xp_required", 1)))
		bar.max_value = need
		bar.value = clamp(xp, 0, need)
		bar.custom_minimum_size = Vector2(220, 14)
		if Engine.has_singleton("ThemeManager"):
			ThemeManager.style_progress(bar, "xp")
		row.add_child(bar)
		var pct := Label.new()
		pct.text = "%d%%" % int(round(float(xp) / float(need) * 100.0))
		row.add_child(pct)
		list.add_child(row)
