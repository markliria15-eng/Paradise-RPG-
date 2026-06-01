extends PanelContainer

signal close_requested
signal unequip_requested(slot_name: String)

const SLOT_ORDER := ["amulet", "helmet", "backpack", "shield", "armor", "weapon", "ring", "pants", "jewel", "boots"]

@onready var close_button: Button = $Root/Header/Close
@onready var grid: GridContainer = $Root/Body/Slots
@onready var name_label: Label = $Root/Header/Name
@onready var class_level_label: Label = $Root/Header/ClassLevel

func _ready() -> void:
	if Engine.has_singleton("ThemeManager"):
		ThemeManager.apply_modal_panel(self)
		ThemeManager.style_button(close_button, true)
	close_button.pressed.connect(func() -> void:
		close_requested.emit()
		visible = false
	)

func set_player_info(character_name: String, class_id: String, level: int) -> void:
	name_label.text = character_name
	class_level_label.text = "%s  Lv.%d" % [class_id, level]

func set_equipment(equipment: Dictionary, slot_icons: Dictionary) -> void:
	for child in grid.get_children():
		child.queue_free()
	for slot_name in SLOT_ORDER:
		var button := Button.new()
		button.custom_minimum_size = Vector2(76, 76)
		button.tooltip_text = str(slot_name)
		button.text = ""
		var item := str(equipment.get(slot_name, ""))
		var icon_path := str(slot_icons.get(slot_name, ""))
		if not item.is_empty():
			button.text = item.substr(0, min(2, item.length()))
		elif not icon_path.is_empty():
			button.icon = load(icon_path)
			button.expand_icon = true
		button.pressed.connect(func() -> void:
			unequip_requested.emit(str(slot_name))
		)
		grid.add_child(button)
