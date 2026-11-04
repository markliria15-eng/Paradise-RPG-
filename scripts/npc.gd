extends Area2D
class_name Npc

var npc_name := ""
var role := ""
var quest_id := ""
var sprite_override := ""
var _idle_breath_frames: PackedInt32Array = PackedInt32Array([0, 1, 2, 1])
var _idle_breath_index := 0
var _idle_breath_timer := 0.0
var _idle_breath_enabled := false
var _idle_breath_frame_time := 0.28
# Deslocamento horizontal por frame para manter o corpo centralizado (os sheets
# tem o personagem em posicoes diferentes em cada frame).
var _frame_offsets_x: PackedFloat32Array = PackedFloat32Array()
var _hd := false
# Escala da arte nova igual a dos personagens (Player.HD_PLAYER_TARGET_HEIGHT / 192).
const HD_PIXEL_SCALE := 119.0 / 192.0

@onready var sprite: Sprite2D = $Sprite2D
@onready var label: Label = $Label
var shadow_sprite: Sprite2D

func setup(data: Dictionary) -> void:
	npc_name = str(data.get("name", "NPC"))
	role = str(data.get("role", ""))
	quest_id = str(data.get("quest", ""))
	sprite_override = str(data.get("sprite", ""))
	label.text = npc_name
	var sprite_path := sprite_override if not sprite_override.is_empty() else _sprite_path(role)
	if sprite_path.is_empty():
		sprite_path = _premium_sprite_path(role)
	# Arte nova (tools/char_sprites/process_npcs.py): mesma tira em 256 px, ja alinhada.
	var hd_path := sprite_path.replace("_idle_4f_128.png", "_idle_4f_256.png")
	_hd = hd_path != sprite_path and ResourceLoader.exists(hd_path)
	if _hd:
		sprite_path = hd_path
	sprite.texture = load(sprite_path)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_idle_breath_enabled = sprite_path.ends_with("_idle_4f_128.png") or _hd
	_idle_breath_index = 0
	_idle_breath_timer = 0.0
	_frame_offsets_x = PackedFloat32Array()
	if _hd:
		# respiracao em vai-e-volta: 1 2 3 4 3 2
		_idle_breath_frames = PackedInt32Array([0, 1, 2, 3, 2, 1])
		_idle_breath_frame_time = 0.22
	if _idle_breath_enabled and sprite.texture != null:
		sprite.hframes = 4
		sprite.vframes = 1
		sprite.frame = 0
		if not _hd:
			_compute_frame_offsets()
		_apply_frame_offset(0)
	_fit_sprite_to_npc()

func _process(delta: float) -> void:
	z_index = clampi(int(global_position.y), -1024, 1024)
	if not _idle_breath_enabled or sprite == null or sprite.texture == null:
		return
	_idle_breath_timer += delta
	if _idle_breath_timer < _idle_breath_frame_time:
		return
	_idle_breath_timer = 0.0
	_idle_breath_index = (_idle_breath_index + 1) % _idle_breath_frames.size()
	sprite.frame = _idle_breath_frames[_idle_breath_index]
	_apply_frame_offset(sprite.frame)

func _compute_frame_offsets() -> void:
	_frame_offsets_x = PackedFloat32Array()
	var image := sprite.texture.get_image()
	if image == null:
		return
	if image.is_compressed():
		image.decompress()
	var frame_width := image.get_width() / sprite.hframes
	var frame_height := image.get_height()
	for i in sprite.hframes:
		var used := image.get_region(Rect2i(i * frame_width, 0, frame_width, frame_height)).get_used_rect()
		if used.size.x <= 0:
			_frame_offsets_x.append(0.0)
			continue
		_frame_offsets_x.append(frame_width * 0.5 - (used.position.x + used.size.x * 0.5))

func _apply_frame_offset(frame_index: int) -> void:
	if frame_index < 0 or frame_index >= _frame_offsets_x.size():
		return
	sprite.offset.x = _frame_offsets_x[frame_index]

func _fit_sprite_to_npc() -> void:
	if sprite.texture == null:
		return
	_ensure_shadow()
	if _hd:
		sprite.scale = Vector2(HD_PIXEL_SCALE, HD_PIXEL_SCALE)
		# pes em y=248 do quadro de 256 -> mesmo chao dos sprites antigos (y~18)
		sprite.position = Vector2(0, -56)
		label.add_theme_font_size_override("font_size", 14)
		label.offset_left = -110
		label.offset_right = 110
		label.offset_top = -114
		label.offset_bottom = -88
		return
	var target_height := 109.5
	var texture_height: float = maxf(1.0, float(sprite.texture.get_height()))
	var sprite_scale: float = target_height / texture_height
	sprite.scale = Vector2(sprite_scale, sprite_scale)
	# Ajusta para manter os pes no "chao" do NPC.
	sprite.position = Vector2(0, -28.5)
	label.add_theme_font_size_override("font_size", 14)
	label.offset_left = -110
	label.offset_right = 110
	label.offset_top = -104
	label.offset_bottom = -78

func _ensure_shadow() -> void:
	if shadow_sprite != null:
		return
	var texture := load("res://assets/sprites/decor_shadow_soft.png") as Texture2D
	if texture == null:
		return
	shadow_sprite = Sprite2D.new()
	shadow_sprite.texture = texture
	shadow_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	shadow_sprite.position = Vector2(0, 17)
	shadow_sprite.scale = Vector2(0.62, 0.28)
	shadow_sprite.modulate = Color(1, 1, 1, 0.55)
	shadow_sprite.z_index = -1
	add_child(shadow_sprite)

func _sprite_path(npc_role: String) -> String:
	match npc_role:
		"healer":
			return "res://assets/characters/npcs/npc_sarah_curandeira_idle_4f_128.png"
		"shop":
			return "res://assets/characters/npcs/npc_borin_mercador_idle_4f_128.png"
		"class_master":
			return "res://assets/characters/npcs/npc_arion_mestre_classes_idle_4f_128.png"
		"forge":
			return "res://assets/characters/npcs/npc_bakka_ferreiro_idle_4f_128.png"
		"quest":
			return "res://assets/characters/npcs/npc_guarda_doran_idle_4f_128.png"
	return ""

func _premium_sprite_path(npc_role: String) -> String:
	match npc_role:
		"healer":
			return "res://assets/characters/npcs/npc_sarah_curandeira_idle_4f_128.png"
		"shop":
			return "res://assets/characters/npcs/npc_borin_mercador_idle_4f_128.png"
		"class_master":
			return "res://assets/characters/npcs/npc_arion_mestre_classes_idle_4f_128.png"
		"forge":
			return "res://assets/characters/npcs/npc_bakka_ferreiro_idle_4f_128.png"
		"quest":
			return "res://assets/characters/npcs/npc_guarda_doran_idle_4f_128.png"
		"pet_shop":
			return "res://assets/characters/npcs/npc_mira_pets_idle_4f_128.png"
		"mount_shop":
			return "res://assets/characters/npcs/npc_torin_montarias_idle_4f_128.png"
		"rare_forge":
			return "res://assets/characters/npcs/npc_durnan_forja_rara_idle_4f_128.png"
	return "res://assets/characters/npcs/npc_guarda_doran_idle_4f_128.png"
