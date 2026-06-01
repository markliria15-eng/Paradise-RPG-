extends PanelContainer

signal close_requested
signal submit_requested(quest_id: String)

@onready var close_button: Button = $Root/Header/Close
@onready var list: VBoxContainer = $Root/Body/Scroll/List

func _ready() -> void:
	if Engine.has_singleton("ThemeManager"):
		ThemeManager.apply_modal_panel(self)
		ThemeManager.style_button(close_button, true)
	close_button.pressed.connect(func() -> void:
		close_requested.emit()
		visible = false
	)

func set_quests(quests: Array) -> void:
	for child in list.get_children():
		child.queue_free()
	if quests.is_empty():
		var empty := Label.new()
		empty.text = "Nenhuma missao ativa."
		list.add_child(empty)
		return
	for q in quests:
		if typeof(q) != TYPE_DICTIONARY:
			continue
		var row := VBoxContainer.new()
		row.custom_minimum_size = Vector2(520, 74)
		var title := Label.new()
		title.text = str(q.get("title", "Missao"))
		row.add_child(title)
		var progress := Label.new()
		progress.text = str(q.get("progress", ""))
		row.add_child(progress)
		var action := Button.new()
		action.text = "Entregar"
		action.disabled = not bool(q.get("ready", false))
		action.pressed.connect(func() -> void:
			submit_requested.emit(str(q.get("id", "")))
		)
		row.add_child(action)
		list.add_child(row)

