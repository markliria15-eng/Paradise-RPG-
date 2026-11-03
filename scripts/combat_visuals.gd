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
	if image.get_height() != 724:
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

static func play(parent: Node, path: String, position: Vector2, facing_right: bool = false) -> void:
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
	animation.position = position + Vector2(0, -30)
	animation.flip_h = facing_right
	animation.z_index = clampi(int(position.y) + 1, -1024, 1024)
	var size: Vector2 = textures[0].get_size()
	animation.scale = Vector2.ONE * minf(140.0 / size.x, 140.0 / size.y)
	parent.add_child(animation)
	animation.animation_finished.connect(animation.queue_free)
	animation.play()
