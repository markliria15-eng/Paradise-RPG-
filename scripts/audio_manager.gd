extends Node
# Efeitos sonoros curtos: assets/audio/sfx/<nome>.wav (gerados por tools/audio/gerar_efeitos.py).
# Uso: AudioManager.play_sfx("moeda"). Nomes antigos (ui_click, level_up...) viram os novos.
# Volume em Menu > Configuracoes (game_extras.gd grava em sfx_volume).

const SFX_DIR := "res://assets/audio/sfx/"
const ALIASES := {"ui_click": "clique", "ui_open": "abrir", "ui_close": "clique", "equip": "item",
	"buy": "moeda", "level_up": "nivel", "rare_drop": "item", "error": "erro"}
const POOL_SIZE := 8

var sfx_volume := 0.8
var streams: Dictionary = {}
var pool: Array = []
var next_player := 0
var last_played: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.name = "Sfx%d" % i
		add_child(p)
		pool.append(p)

func _stream(key: String) -> AudioStream:
	if not streams.has(key):
		var path := SFX_DIR + key + ".wav"
		streams[key] = load(path) if ResourceLoader.exists(path) else null
	return streams[key]

# min_gap: nao repete o mesmo som mais rapido que isso (ex.: varios golpes no mesmo quadro)
func play_sfx(key: String, volume: float = 1.0, min_gap: float = 0.05) -> void:
	key = str(ALIASES.get(key, key))
	if sfx_volume <= 0.001:
		return
	var now := Time.get_ticks_msec() / 1000.0
	if now - float(last_played.get(key, -10.0)) < min_gap:
		return
	var stream := _stream(key)
	if stream == null:
		return
	last_played[key] = now
	var p: AudioStreamPlayer = pool[next_player]
	next_player = (next_player + 1) % pool.size()
	p.stream = stream
	p.volume_db = linear_to_db(clampf(sfx_volume * volume, 0.001, 1.0)) - 4.0
	p.pitch_scale = randf_range(0.95, 1.05)
	p.play()
