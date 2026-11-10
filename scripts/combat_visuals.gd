extends RefCounted
# Visuals follow existing combat hits; no additional damage or status changes.
static var registry: Dictionary = {}
static var cache: Dictionary = {}

static func options(category: String, key: String) -> Array:
	if registry.is_empty():
		var data = JSON.parse_string(FileAccess.get_file_as_string("res://assets/sprites/combat_visuals.json"))
		if data is Dictionary:
			registry = data
	return registry.get(category, {}).get(key, [])

static func frames(path: String, actor: bool = false) -> Array:
	var key := path + str(actor)
	if cache.has(key):
		return cache[key]
	var result: Array = []
	var texture := load(path) as Texture2D
	if texture == null:
		return result
	var image := texture.get_image()
	if image.is_compressed():
		image.decompress()
	var cols := 8
	var rows := 1
	# Folhas ja recortadas (tools/pets/recortar_efeitos_pets.py): "<nome>_<N>f_<W>x<H>.png",
	# N celulas iguais numa linha. As folhas brutas 2172x724 seguem a regra antiga.
	var counted := RegEx.create_from_string("_(\\d+)f_\\d+x\\d+\\.png$").search(path)
	if counted != null:
		cols = int(counted.get_string(1))
	elif image.get_height() != 724:
		cols = 4
		rows = 2
	var width := float(image.get_width()) / cols
	var height := float(image.get_height()) / rows
	for row in range(rows):
		for col in range(cols):
			var cell := image.get_region(Rect2i(roundi(col * width), roundi(row * height), roundi(width), roundi(height)))
			if actor:
				var bounds := cell.get_used_rect()
				if not bounds.has_area():
					continue
				cell = cell.get_region(bounds)
				var factor := minf(120.0 / cell.get_height(), 184.0 / cell.get_width())
				cell.resize(maxi(1, roundi(cell.get_width() * factor)), maxi(1, roundi(cell.get_height() * factor)), Image.INTERPOLATE_LANCZOS)
				var canvas := Image.create(192, 192, false, Image.FORMAT_RGBA8)
				canvas.blit_rect(cell, Rect2i(Vector2i.ZERO, cell.get_size()), Vector2i((192 - cell.get_width()) / 2, 184 - cell.get_height()))
				cell = canvas
			result.append(ImageTexture.create_from_image(cell))
	cache[key] = result
	return result

# size: maior lado do efeito na tela; centered: position ja e o centro do alvo (sem o ajuste de -30);
# z_y: y dos pes do alvo, para o efeito ficar na frente dele mesmo sendo desenhado mais acima.
static func play(parent: Node, path: String, position: Vector2, facing_right: bool = false, size_px: float = 140.0, centered: bool = false, z_y: float = -1.0) -> void:
	var textures := frames(path)
	if textures.is_empty():
		return
	var animation := AnimatedSprite2D.new()
	var sequence := SpriteFrames.new()
	sequence.set_animation_loop("default", false)
	sequence.set_animation_speed("default", 14.0)
	for texture in textures:
		sequence.add_frame("default", texture)
	animation.sprite_frames = sequence
	animation.position = position if centered else position + Vector2(0, -30)
	animation.flip_h = facing_right
	# +1 fora do clamp: com y > 1024 o alvo tambem fica em 1024 e o y-sort jogaria o efeito para tras
	animation.z_index = clampi(int(z_y if z_y >= 0.0 else position.y) + 2, -1024, 1024) + 1
	var size: Vector2 = textures[0].get_size()
	animation.scale = Vector2.ONE * minf(size_px / size.x, size_px / size.y)
	parent.add_child(animation)
	animation.animation_finished.connect(animation.queue_free)
	animation.play()
