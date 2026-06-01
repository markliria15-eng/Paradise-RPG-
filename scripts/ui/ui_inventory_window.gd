extends PanelContainer

signal close_requested
signal equip_requested(item_id: String)
signal use_requested(item_id: String)

@onready var title_label: Label = $Root/Header/Title
@onready var gold_label: Label = $Root/Header/Gold
@onready var list_container: VBoxContainer = $Root/Body/Scroll/List
@onready var close_button: Button = $Root/Header/Close

func _ready() -> void:
	title_label.text = "Bolsa"
	if Engine.has_singleton("ThemeManager"):
		ThemeManager.apply_modal_panel(self)
		ThemeManager.style_button(close_button, true)
	close_button.pressed.connect(func() -> void:
		close_requested.emit()
		visible = false
	)

func set_gold(value: int) -> void:
	gold_label.text = "%d ouro" % value

func set_items(items: Array) -> void:
	for child in list_container.get_children():
		child.queue_free()
	if items.is_empty():
		var empty := Label.new()
		empty.text = "Inventario vazio."
		list_container.add_child(empty)
		return
	for entry in items:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var row := HBoxContainer.new()
		row.custom_minimum_size = Vector2(500, 40)
		var name_label := Label.new()
		name_label.text = "%s x%d" % [str(entry.get("name", "Item")), int(entry.get("amount", 1))]
		name_label.custom_minimum_size = Vector2(280, 28)
		row.add_child(name_label)
		var use_button := Button.new()
		use_button.text = "Usar"
		use_button.pressed.connect(func() -> void:
			use_requested.emit(str(entry.get("id", "")))
		)
		row.add_child(use_button)
		var equip_button := Button.new()
		equip_button.text = "Equipar"
		equip_button.pressed.connect(func() -> void:
			equip_requested.emit(str(entry.get("id", "")))
		)
		row.add_child(equip_button)
		list_container.add_child(row)

