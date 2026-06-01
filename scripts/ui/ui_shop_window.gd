extends PanelContainer

signal close_requested
signal buy_requested(item_id: String)

@onready var close_button: Button = $Root/Header/Close
@onready var gold_label: Label = $Root/Header/Gold
@onready var list: VBoxContainer = $Root/Body/Scroll/List

func _ready() -> void:
	if Engine.has_singleton("ThemeManager"):
		ThemeManager.apply_modal_panel(self)
		ThemeManager.style_button(close_button, true)
	close_button.pressed.connect(func() -> void:
		close_requested.emit()
		visible = false
	)

func set_gold(value: int) -> void:
	gold_label.text = "%d ouro" % value

func set_goods(goods: Array) -> void:
	for child in list.get_children():
		child.queue_free()
	for entry in goods:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var row := HBoxContainer.new()
		row.custom_minimum_size = Vector2(520, 42)
		var label := Label.new()
		label.custom_minimum_size = Vector2(340, 24)
		label.text = "%s - %d ouro" % [str(entry.get("name", "Item")), int(entry.get("price", 0))]
		row.add_child(label)
		var buy := Button.new()
		buy.text = "Comprar"
		buy.pressed.connect(func() -> void:
			buy_requested.emit(str(entry.get("id", "")))
		)
		row.add_child(buy)
		list.add_child(row)

