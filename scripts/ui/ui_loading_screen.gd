extends Control

const TIPS := [
	"Ataque monstros para evoluir Lutando.",
	"Receber dano aumenta Protecao.",
	"Complete missoes para ganhar joias raras.",
	"Use a cidade para descansar e comprar pocoes."
]

@onready var map_label: Label = $Root/Map
@onready var tip_label: Label = $Root/Tip
@onready var bar: ProgressBar = $Root/Progress

func _ready() -> void:
	if Engine.has_singleton("ThemeManager"):
		ThemeManager.style_progress(bar, "xp")
	randomize_tip()

func set_map_name(name_value: String) -> void:
	map_label.text = "Carregando: %s" % name_value

func set_progress(value: float) -> void:
	bar.value = clamp(value, 0.0, 100.0)

func randomize_tip() -> void:
	tip_label.text = TIPS[randi() % TIPS.size()]

