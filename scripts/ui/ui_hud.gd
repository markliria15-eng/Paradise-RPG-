extends Control

signal inventory_pressed
signal character_pressed
signal quests_pressed
signal skill_pressed(index: int)
signal attack_pressed

@onready var name_label: Label = $Root/Top/Name
@onready var class_icon: TextureRect = $Root/Top/ClassIcon
@onready var level_label: Label = $Root/Top/Level
@onready var gold_label: Label = $Root/Top/Gold
@onready var hp_bar: ProgressBar = $Root/Bars/HpBar
@onready var mp_bar: ProgressBar = $Root/Bars/MpBar
@onready var xp_bar: ProgressBar = $Root/Bars/XpBar
@onready var feedback_label: Label = $Root/Feedback

func _ready() -> void:
	if Engine.has_singleton("ThemeManager"):
		ThemeManager.style_progress(hp_bar, "hp")
		ThemeManager.style_progress(mp_bar, "mana")
		ThemeManager.style_progress(xp_bar, "xp")
		ThemeManager.style_button($Root/Buttons/Inventory)
		ThemeManager.style_button($Root/Buttons/Character)
		ThemeManager.style_button($Root/Buttons/Quests)
		ThemeManager.style_button($Root/Bottom/Attack, true)
		ThemeManager.style_button($Root/Bottom/Skill1)
		ThemeManager.style_button($Root/Bottom/Skill2)
		ThemeManager.style_button($Root/Bottom/Skill3)
	$Root/Buttons/Inventory.pressed.connect(func() -> void: inventory_pressed.emit())
	$Root/Buttons/Character.pressed.connect(func() -> void: character_pressed.emit())
	$Root/Buttons/Quests.pressed.connect(func() -> void: quests_pressed.emit())
	$Root/Bottom/Attack.pressed.connect(func() -> void: attack_pressed.emit())
	$Root/Bottom/Skill1.pressed.connect(func() -> void: skill_pressed.emit(0))
	$Root/Bottom/Skill2.pressed.connect(func() -> void: skill_pressed.emit(1))
	$Root/Bottom/Skill3.pressed.connect(func() -> void: skill_pressed.emit(2))

func set_top_info(character_name: String, level: int, gold: int, icon: Texture2D) -> void:
	name_label.text = character_name
	level_label.text = "Lv.%d" % level
	gold_label.text = "%d ouro" % gold
	class_icon.texture = icon

func update_health_bar(current: int, maximum: int) -> void:
	hp_bar.max_value = max(1, maximum)
	hp_bar.value = clamp(current, 0, maximum)

func update_mana_bar(current: int, maximum: int) -> void:
	mp_bar.max_value = max(1, maximum)
	mp_bar.value = clamp(current, 0, maximum)

func update_xp_bar(current: int, maximum: int) -> void:
	xp_bar.max_value = max(1, maximum)
	xp_bar.value = clamp(current, 0, maximum)

func update_gold(gold: int) -> void:
	gold_label.text = "%d ouro" % gold

func update_level(level: int) -> void:
	level_label.text = "Lv.%d" % level

func update_skill_cooldowns(values: Array[float]) -> void:
	var buttons := [$Root/Bottom/Skill1, $Root/Bottom/Skill2, $Root/Bottom/Skill3]
	for i in range(min(values.size(), buttons.size())):
		var b := buttons[i] as Button
		var left: float = max(0.0, float(values[i]))
		b.text = str(i + 1) if left <= 0.01 else "%.1f" % left

func show_damage_feedback(text: String) -> void:
	feedback_label.text = text
	feedback_label.modulate = Color("#ff7f7f")

func show_xp_feedback(text: String) -> void:
	feedback_label.text = text
	feedback_label.modulate = Color("#ffd779")
