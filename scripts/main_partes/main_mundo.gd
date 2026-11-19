extends "res://scripts/main_partes/main_util.gd"

# Parte do main.gd (dividido em 2026-11-15 para ficar mais facil de manter).
# Mundo: desenho dos mapas (chunks/kits), colisoes, NPCs, portais, zonas seguras, camera e minimapa.
# Cadeia: main_estado -> main_util -> main_mundo -> main_combate -> main_companheiros
#         -> main_interface -> scripts/main.gd (o no Main da cena usa main.gd).
# Cada parte so chama funcoes dela mesma ou das partes de baixo da cadeia.

func _update_nearby_portal() -> void:
	if player == null:
		selected_portal = null
		return
	if not is_inside_tree():
		return
	var tree := get_tree()
	if tree == null:
		return
	var nearest_portal: Area2D = null
	var nearest_distance := 1.0e12
	for portal in tree.get_nodes_in_group("portals"):
		if portal == null or not is_instance_valid(portal):
			continue
		var portal_area := portal as Area2D
		if portal_area == null:
			continue
		var distance := player.global_position.distance_to(portal_area.global_position)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest_portal = portal_area
	if nearest_portal != null and nearest_distance <= 170.0:
		selected_portal = nearest_portal
	elif selected_portal != null and is_instance_valid(selected_portal):
		if player.global_position.distance_to(selected_portal.global_position) > 190.0:
			selected_portal = null
	else:
		selected_portal = null

func _cleanup_remote_players_for_map() -> void:
	var invalid_ids: Array = []
	for character_id in remote_players.keys():
		var remote: Node2D = remote_players[character_id]
		if remote == null or not is_instance_valid(remote):
			invalid_ids.append(character_id)
			continue
		var map_id := str(remote.get_meta("map", ""))
		remote.visible = map_id == current_map
	for character_id in invalid_ids:
		remote_players.erase(character_id)

func _layout_minimap_hud() -> void:
	hud_minimap_scale = clampf(hud_minimap_scale, 0.55, 1.55)
	var scale := hud_minimap_scale
	var frame_size := MINIMAP_FRAME_SIZE * scale
	var canvas_offset := (MINIMAP_CANVAS_POS - MINIMAP_FRAME_POS) * scale
	var canvas_size := MINIMAP_SIZE * scale
	_set_control_rect(minimap_frame_rect, hud_minimap_frame_pos, frame_size)
	_set_control_rect(minimap_panel, hud_minimap_frame_pos + canvas_offset, canvas_size)
	_set_control_rect(minimap_canvas, hud_minimap_frame_pos + canvas_offset, canvas_size)

# Cidade de renascimento/inicio: Eldoria ate o jogador chegar em Valdoria.
func _home_city() -> String:
	if maps.has("city_valdoria") and _has_world_flag("chegou_valdoria"):
		return "city_valdoria"
	return "city_eldoria" if maps.has("city_eldoria") else FOREST_PRIMARY_MAP_ID

func _draw_map_background(map_data: Dictionary) -> void:
	_draw_map_terrain(map_data)
	if current_map == "city_eldoria" or _ruins_v2_active() or _cave_v2_active() or _valdoria_v2_active() or _swamp_v2_active():
		return
	_spawn_ground_details()
	if current_map != "city_eldoria" and not _is_new_eldoria_map() and not _is_forest_base_map():
		var title := Label.new()
		title.text = str(map_data.get("name", "Mapa"))
		title.position = Vector2(540, 48)
		title.z_index = 100
		title.add_theme_color_override("font_color", Color.WHITE)
		world.add_child(title)
	_spawn_map_decor()

func _draw_map_terrain(map_data: Dictionary) -> void:
	if current_map == "arcane_ruins" and _draw_ruins_v2():
		return
	if current_map == "bat_cave" and _draw_cave_v2():
		return
	if current_map == "city_valdoria" and _draw_valdoria_v2():
		return
	if current_map == SWAMP_MAP_ID and _draw_swamp_v2():
		return
	if _is_rebuild_base_only_map():
		_draw_rebuild_base_terrain(map_data)
		return
	match current_map:
		"city_eldoria":
			_draw_city_terrain()
		"city_valdoria":
			_draw_valdoria_terrain()
		"forest_boars":
			if not _draw_forest_background():
				push_error("Floresta 7x7 indisponivel: faltam chunks do mapa.")
				return
			_register_forest_background_collision()
			return
		"world_reset":
			if _draw_forest_background():
				_register_forest_background_collision()
				return
			if _draw_forest_base_background():
				return
			_add_world_rect(Rect2(Vector2.ZERO, current_map_size), Color(map_data.get("color", "#303030")), -100)
		"arcane_ruins":
			_draw_arcane_terrain()
		"bat_cave":
			if _draw_cave_background():
				_register_cave_background_collision()
				return
			_draw_cave_terrain()
		"highland_pass":
			_draw_highland_terrain()
		"crystal_mines":
			_draw_crystal_mines_terrain()
		"ember_fortress":
			_draw_ember_fortress_terrain()
		_:
			_add_world_rect(Rect2(Vector2.ZERO, current_map_size), Color(map_data.get("color", "#303030")), -100)

func _draw_city_terrain() -> void:
	if current_map == "city_eldoria":
		current_map_size = ELDORIA_WORLD_SIZE
		if _draw_eldoria_v2():
			return
		if _draw_eldoria_chunked_background():
			return
		_draw_eldoria_rebuild_base()
		return
	var center := current_map_size * 0.5
	_draw_tiled_rect("res://assets/sprites/tile_grass.png", Rect2(Vector2.ZERO, current_map_size), 64, -100)
	_draw_tiled_rect("res://assets/sprites/tile_stone.png", Rect2(310, 230, current_map_size.x - 620, current_map_size.y - 430), 64, -97)
	_draw_tiled_rect("res://assets/sprites/tile_path.png", Rect2(center.x - 164, 260, 328, current_map_size.y - 410), 64, -95)
	_draw_tiled_rect("res://assets/sprites/tile_path.png", Rect2(390, center.y - 132, current_map_size.x - 780, 264), 64, -95)
	_draw_tiled_blob("res://assets/sprites/tile_stone.png", center, 310, 235, -94)
	_draw_tiled_blob("res://assets/sprites/tile_path.png", center, 190, 155, -93)
	for garden in [
		Rect2(410, 320, 650, 420), Rect2(1950, 330, 690, 420),
		Rect2(410, 1520, 650, 410), Rect2(1980, 1510, 660, 410),
		Rect2(1120, 340, 300, 420), Rect2(1665, 1500, 260, 390)
	]:
		_draw_tiled_rect("res://assets/sprites/tile_grass.png", garden, 64, -96)
	for wall in [
		Rect2(285, 205, current_map_size.x - 570, 46),
		Rect2(285, current_map_size.y - 230, 1060, 46),
		Rect2(1730, current_map_size.y - 230, current_map_size.x - 2015, 46),
		Rect2(285, 205, 46, current_map_size.y - 389),
		Rect2(current_map_size.x - 331, 205, 46, current_map_size.y - 389)
	]:
		_add_world_rect(wall, Color("#303844"), -91)
		_register_solid_rect(wall)
	for gate_post in [Rect2(1344, current_map_size.y - 252, 42, 86), Rect2(1688, current_map_size.y - 252, 42, 86)]:
		_add_world_rect(gate_post, Color("#44505d"), -90)
		_register_solid_rect(gate_post)
	for curb in [
		Rect2(center.x - 204, 250, 18, current_map_size.y - 420),
		Rect2(center.x + 186, 250, 18, current_map_size.y - 420),
		Rect2(380, center.y - 166, current_map_size.x - 760, 18),
		Rect2(380, center.y + 148, current_map_size.x - 760, 18)
	]:
		_add_world_rect(curb, Color("#6d6558"), -92)
	_add_world_label("Classes", Vector2(830, 530), Color("#ffe0a3"))
	_add_world_label("Mercador", Vector2(2070, 700), Color("#ffe0a3"))
	_add_world_label("Curandeira", Vector2(590, 1350), Color("#d8ffd2"))
	_add_world_label("Forja", Vector2(2095, 1440), Color("#ffd06b"))

func _draw_eldoria_rebuild_base() -> void:
	var center := current_map_size * 0.5
	_draw_tiled_rect("res://assets/sprites/tile_grass.png", Rect2(Vector2.ZERO, current_map_size), 64, -100)
	_draw_tiled_rect("res://assets/sprites/tile_path.png", Rect2(center.x - 150, 520, 300, current_map_size.y - 760), 64, -96)
	_draw_tiled_rect("res://assets/sprites/tile_path.png", Rect2(640, center.y - 150, current_map_size.x - 1280, 300), 64, -96)
	_draw_tiled_rect("res://assets/sprites/tile_path.png", Rect2(1700, 900, 1600, 260), 64, -96)
	_draw_tiled_rect("res://assets/sprites/tile_path.png", Rect2(1700, 3600, 1600, 260), 64, -96)
	_draw_tiled_blob("res://assets/sprites/tile_stone.png", center, 360, 260, -95)
	_draw_tiled_blob("res://assets/sprites/tile_path.png", center, 250, 170, -94)

func _is_rebuild_base_only_map(map_id: String = current_map) -> bool:
	return bool(MAPS_REBUILD_BASE_ONLY.get(map_id, false))

func _draw_rebuild_base_terrain(map_data: Dictionary) -> void:
	var base_color := Color(str(map_data.get("color", "#303030")))
	var path_color := Color("#b99b62")
	var center := current_map_size * 0.5
	_add_world_rect(Rect2(Vector2.ZERO, current_map_size), base_color, -100)
	_draw_tiled_rect("res://assets/sprites/tile_path.png", Rect2(center.x - 80, 120, 160, current_map_size.y - 240), 64, -96)
	_draw_tiled_rect("res://assets/sprites/tile_path.png", Rect2(120, center.y - 80, current_map_size.x - 240, 160), 64, -96)
	_draw_tiled_blob("res://assets/sprites/tile_path.png", center, 170, 120, -95)
	_add_world_label("Base para implantar", center + Vector2(-165, -210), path_color)

func _eldoria_background_available() -> bool:
	return not ELDORIA_REBUILD_BASE_ONLY and ResourceLoader.exists(ELDORIA_BACKGROUND_PATH)

func _is_new_eldoria_map() -> bool:
	return current_map == "city_eldoria" and _eldoria_background_available()

func _valdoria_background_available() -> bool:
	if not _get_valdoria_kit_data().is_empty():
		return false
	return ResourceLoader.exists(VALDORIA_BACKGROUND_PATH)

func _is_new_valdoria_map() -> bool:
	return current_map == "city_valdoria" and _valdoria_background_available()

func _eldoria_point(x: float, y: float) -> Vector2:
	return Vector2(x, y)

func _eldoria_rect(x: float, y: float, w: float, h: float) -> Rect2:
	return Rect2(_eldoria_point(x, y), Vector2(w, h))

func _eldoria_chunk_path(grid_x: int, grid_y: int) -> String:
	return "%s/eldoria_chunk_%02d_%02d.png" % [ELDORIA_CHUNKS_DIR, grid_x, grid_y]

func _eldoria_water_frame_path(grid_x: int, grid_y: int, frame_index: int) -> String:
	return "%s/eldoria_water_%02d_%02d_frame_%02d.png" % [ELDORIA_WATER_FRAMES_DIR, grid_x, grid_y, frame_index]

func _valdoria_point(x: float, y: float) -> Vector2:
	return Vector2(x, y)

func _valdoria_rect(x: float, y: float, w: float, h: float) -> Rect2:
	return Rect2(_valdoria_point(x, y), Vector2(w, h))

func _forest_chunk_path(grid_x: int, grid_y: int) -> String:
	return "%s/floresta_v2_chunk_%02d_%02d.png" % [FOREST_CHUNKS_DIR, grid_x, grid_y]

func _forest_point(x: float, y: float) -> Vector2:
	return Vector2(x, y) * FOREST_WORLD_SCALE

func _forest_rect(x: float, y: float, width: float, height: float) -> Rect2:
	return Rect2(_forest_point(x, y), Vector2(width, height) * FOREST_WORLD_SCALE)

func _map_data_point(pos_data: Array) -> Vector2:
	if pos_data.size() < 2:
		return Vector2.ZERO
	var point := Vector2(float(pos_data[0]), float(pos_data[1]))
	if current_map == "forest_boars":
		return point * FOREST_WORLD_SCALE
	return point

func _map_data_radius(radius: float) -> float:
	if current_map == "forest_boars":
		return radius * FOREST_WORLD_SCALE
	return radius

func _cave_chunk_path(grid_x: int, grid_y: int) -> String:
	return "%s/caverna_chunk_%02d_%02d.png" % [CAVE_CHUNKS_DIR, grid_x, grid_y]

func _forest_background_available() -> bool:
	return _forest_chunks_available()

func _cave_background_available() -> bool:
	return ResourceLoader.exists(CAVE_BACKGROUND_PATH)

func _forest_chunks_available() -> bool:
	for grid_y in range(FOREST_CHUNK_GRID.y):
		for grid_x in range(FOREST_CHUNK_GRID.x):
			if not ResourceLoader.exists(_forest_chunk_path(grid_x, grid_y)):
				return false
	return true

func _eldoria_chunks_available() -> bool:
	for grid_y in range(ELDORIA_CHUNK_GRID.y):
		for grid_x in range(ELDORIA_CHUNK_GRID.x):
			if not ResourceLoader.exists(_eldoria_chunk_path(grid_x, grid_y)):
				return false
	return true

func _cave_chunks_available() -> bool:
	for grid_y in range(4):
		for grid_x in range(5):
			if not ResourceLoader.exists(_cave_chunk_path(grid_x, grid_y)):
				return false
	return true

func _is_new_forest_map() -> bool:
	return current_map == "forest_boars"

func _is_new_cave_map() -> bool:
	return current_map == "bat_cave" and _cave_background_available()

func _get_cave_kit_data() -> Dictionary:
	if not cave_kit_data.is_empty():
		return cave_kit_data
	if not FileAccess.file_exists(CAVE_KIT_DATA_PATH):
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(CAVE_KIT_DATA_PATH))
	if typeof(parsed) == TYPE_DICTIONARY:
		cave_kit_data = parsed
	return cave_kit_data

func _cave_v2_active() -> bool:
	return current_map == "bat_cave" and not _get_cave_kit_data().is_empty()

func _cave_minimap_path() -> String:
	if _cave_v2_active():
		return str(_get_cave_kit_data().get("minimap", ""))
	return CAVE_MINIMAP_PATH

func _get_valdoria_kit_data() -> Dictionary:
	if not valdoria_kit_data.is_empty():
		return valdoria_kit_data
	if not FileAccess.file_exists(VALDORIA_KIT_DATA_PATH):
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(VALDORIA_KIT_DATA_PATH))
	if typeof(parsed) == TYPE_DICTIONARY:
		valdoria_kit_data = parsed
	return valdoria_kit_data

func _valdoria_v2_active() -> bool:
	return current_map == "city_valdoria" and not _get_valdoria_kit_data().is_empty()

func _get_swamp_kit_data() -> Dictionary:
	if not swamp_kit_data.is_empty():
		return swamp_kit_data
	if not FileAccess.file_exists(SWAMP_KIT_DATA_PATH):
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(SWAMP_KIT_DATA_PATH))
	if typeof(parsed) == TYPE_DICTIONARY:
		swamp_kit_data = parsed
	return swamp_kit_data

func _swamp_v2_active() -> bool:
	return current_map == SWAMP_MAP_ID and not _get_swamp_kit_data().is_empty()

# Pantano das Almas Perdidas (tools/pantano_v2/gerar_pantano.py): kit igual Valdoria, sem mar
# animado e com mascara de chao lento (lama e agua rasa).
func _draw_swamp_v2() -> bool:
	var data := _get_swamp_kit_data()
	if data.is_empty():
		return false
	var size_data: Array = data.get("world_size", [6400, 5760])
	current_map_size = Vector2(float(size_data[0]), float(size_data[1]))
	var grid_data: Array = data.get("chunk_grid", [8, 9])
	var chunk_px_data: Array = data.get("chunk_px", [400, 320])
	var ground_scale := float(data.get("ground_scale", 2.0))
	var chunks_root := Node2D.new()
	chunks_root.name = "SwampChunks"
	world.add_child(chunks_root)
	for grid_y in range(int(grid_data[1])):
		for grid_x in range(int(grid_data[0])):
			var path := "%s/%s_%02d_%02d.png" % [str(data.get("chunks_dir", "")), str(data.get("chunk_prefix", "")), grid_x, grid_y]
			if not ResourceLoader.exists(path):
				continue
			chunks_root.add_child(_stream_chunk(path, Vector2(grid_x * float(chunk_px_data[0]), grid_y * float(chunk_px_data[1])) * ground_scale, ground_scale, Vector2(float(chunk_px_data[0]), float(chunk_px_data[1]))))
	forest_walk_image = null
	_spawn_map_kit(data)
	_load_terrain_slow_mask(data)
	return true

func _load_terrain_slow_mask(data: Dictionary) -> void:
	var info: Dictionary = data.get("slow_mask", {})
	var path := str(info.get("path", ""))
	var tex := load(path) as Texture2D if not path.is_empty() and ResourceLoader.exists(path) else null
	if tex == null:
		return
	terrain_slow_image = tex.get_image()
	if terrain_slow_image != null and terrain_slow_image.is_compressed():
		terrain_slow_image.decompress()
	terrain_slow_cell = maxf(1.0, float(info.get("cell", 16.0)))
	terrain_slow_factor = clampf(float(info.get("fator", 0.72)), 0.3, 1.0)

# Velocidade do chao embaixo do heroi (1.0 fora da lama/agua rasa).
func _terrain_speed_at(pos: Vector2) -> float:
	if terrain_slow_image == null:
		return 1.0
	var x := int(pos.x / terrain_slow_cell)
	var y := int((pos.y + 18.0) / terrain_slow_cell)
	if x < 0 or y < 0 or x >= terrain_slow_image.get_width() or y >= terrain_slow_image.get_height():
		return 1.0
	return terrain_slow_factor if terrain_slow_image.get_pixel(x, y).r > 0.5 else 1.0

# Valdoria v2: mesmo formato de kit da caverna (chunks com mar transparente sobre a agua animada).
func _draw_valdoria_v2() -> bool:
	var data := _get_valdoria_kit_data()
	if data.is_empty():
		return false
	var size_data: Array = data.get("world_size", [6400, 5760])
	current_map_size = Vector2(float(size_data[0]), float(size_data[1]))
	var grid_data: Array = data.get("chunk_grid", [8, 9])
	var chunk_px_data: Array = data.get("chunk_px", [400, 320])
	var ground_scale := float(data.get("ground_scale", 2.0))
	var chunks_root := Node2D.new()
	chunks_root.name = "ValdoriaV2Chunks"
	world.add_child(chunks_root)
	for grid_y in range(int(grid_data[1])):
		for grid_x in range(int(grid_data[0])):
			var path := "%s/%s_%02d_%02d.png" % [str(data.get("chunks_dir", "")), str(data.get("chunk_prefix", "")), grid_x, grid_y]
			if not ResourceLoader.exists(path):
				continue
			chunks_root.add_child(_stream_chunk(path, Vector2(grid_x * float(chunk_px_data[0]), grid_y * float(chunk_px_data[1])) * ground_scale, ground_scale, Vector2(float(chunk_px_data[0]), float(chunk_px_data[1]))))
	forest_walk_image = null
	_spawn_map_kit(data)
	for rect_data in data.get("solids", []):
		if typeof(rect_data) == TYPE_ARRAY and rect_data.size() >= 4:
			_register_solid_rect(Rect2(float(rect_data[0]), float(rect_data[1]), float(rect_data[2]), float(rect_data[3])))
	_spawn_kit_vehicles(data.get("vehicles", []))
	return true

# Veiculo do kit: AnimatedSprite2D com animacoes move_<dir>/idle_<lado>, cada uma com seu offset
# (pes do veiculo no ponto da rota). Anda de ponto em ponto, espera "wait" segundos parado
# (idle respirando) e volta ao inicio. Nao tem colisao: so da vida a cidade.
func _spawn_kit_vehicles(vehicle_list: Array) -> void:
	for vehicle_data in vehicle_list:
		if typeof(vehicle_data) != TYPE_DICTIONARY:
			continue
		var route: Array = vehicle_data.get("route", [])
		if route.size() < 2:
			continue
		var frames := SpriteFrames.new()
		frames.remove_animation("default")
		var offsets := {}
		var anims: Dictionary = vehicle_data.get("anims", {})
		for anim_name in anims.keys():
			var anim: Dictionary = anims[anim_name]
			frames.add_animation(anim_name)
			frames.set_animation_speed(anim_name, float(anim.get("fps", 8.0)))
			for frame_path in anim.get("frames", []):
				var frame_texture := load(str(frame_path)) as Texture2D
				if frame_texture != null:
					frames.add_frame(anim_name, frame_texture)
			var offset_data: Array = anim.get("offset", [0.0, 0.0])
			offsets[anim_name] = Vector2(float(offset_data[0]), float(offset_data[1]))
		if frames.get_animation_names().is_empty():
			continue
		var sprite := AnimatedSprite2D.new()
		sprite.sprite_frames = frames
		sprite.centered = false
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		# "scale": regra de tamanhos (game_rules.json -> tamanhos); o offset e em px da textura,
		# entao os pes continuam no ponto da rota
		sprite.scale = Vector2.ONE * float(vehicle_data.get("scale", 1.0))
		var start: Array = route[0]
		sprite.position = Vector2(float(start[0]), float(start[1]))
		world.add_child(sprite)
		var flying := bool(vehicle_data.get("flying", false))
		var state := {"node": sprite, "route": route, "index": 0, "wait": float(start[2]) if start.size() > 2 else 0.0,
			"speed": float(vehicle_data.get("speed", 100.0)), "offsets": offsets, "pe_largura": float(vehicle_data.get("pe_largura", 0.0)), "facing": "left", "flying": flying, "anim": ""}
		kit_vehicles.append(state)
		_set_kit_vehicle_anim(state, "idle_left" if frames.has_animation("idle_left") else frames.get_animation_names()[0])

func _set_kit_vehicle_anim(state: Dictionary, anim_name: String) -> void:
	var sprite := state.get("node") as AnimatedSprite2D
	if sprite == null or not sprite.sprite_frames.has_animation(anim_name) or str(state.get("anim", "")) == anim_name:
		return
	state["anim"] = anim_name
	sprite.offset = state["offsets"].get(anim_name, Vector2.ZERO)
	sprite.play(anim_name)

# Caverna v2: mesmo formato de kit das Ruinas v2 (chunks, mascara andavel, lago e props).
func _draw_cave_v2() -> bool:
	var data := _get_cave_kit_data()
	if data.is_empty():
		return false
	var size_data: Array = data.get("world_size", [4800, 3840])
	current_map_size = Vector2(float(size_data[0]), float(size_data[1]))
	var grid_data: Array = data.get("chunk_grid", [6, 6])
	var chunk_px_data: Array = data.get("chunk_px", [800, 640])
	var ground_scale := float(data.get("ground_scale", 1.0))
	var chunks_root := Node2D.new()
	chunks_root.name = "CaveV2Chunks"
	world.add_child(chunks_root)
	for grid_y in range(int(grid_data[1])):
		for grid_x in range(int(grid_data[0])):
			var path := "%s/%s_%02d_%02d.png" % [str(data.get("chunks_dir", "")), str(data.get("chunk_prefix", "")), grid_x, grid_y]
			if not ResourceLoader.exists(path):
				continue
			chunks_root.add_child(_stream_chunk(path, Vector2(grid_x * float(chunk_px_data[0]), grid_y * float(chunk_px_data[1])) * ground_scale, ground_scale, Vector2(float(chunk_px_data[0]), float(chunk_px_data[1]))))
	forest_walk_image = null
	_spawn_map_kit(data)
	for rect_data in data.get("solids", []):
		if typeof(rect_data) == TYPE_ARRAY and rect_data.size() >= 4:
			_register_solid_rect(Rect2(float(rect_data[0]), float(rect_data[1]), float(rect_data[2]), float(rect_data[3])))
	return true

func _draw_eldoria_background() -> bool:
	if not _eldoria_background_available():
		return false
	var texture := load(ELDORIA_BACKGROUND_PATH) as Texture2D
	if texture == null:
		return false
	assert(texture.get_width() == 5016)
	assert(texture.get_height() == 5016)
	current_map_size = Vector2(texture.get_width(), texture.get_height())
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.centered = false
	sprite.position = Vector2.ZERO
	sprite.scale = Vector2.ONE
	sprite.z_index = -100
	world.add_child(sprite)
	return true

func _draw_eldoria_chunked_background() -> bool:
	if not _eldoria_chunks_available():
		return false
	current_map_size = ELDORIA_WORLD_SIZE
	var chunks_root := Node2D.new()
	chunks_root.name = "EldoriaChunks9x9"
	chunks_root.set_meta("grid", ELDORIA_CHUNK_GRID)
	chunks_root.set_meta("chunk_count", ELDORIA_CHUNK_GRID.x * ELDORIA_CHUNK_GRID.y)
	chunks_root.set_meta("future_npc_locations", ELDORIA_FUTURE_NPC_LOCATIONS)
	world.add_child(chunks_root)
	for grid_y in range(ELDORIA_CHUNK_GRID.y):
		for grid_x in range(ELDORIA_CHUNK_GRID.x):
			var chunk_path := _eldoria_chunk_path(grid_x, grid_y)
			var chunk_texture := load(chunk_path) as Texture2D
			if chunk_texture == null:
				return false
			var chunk_sprite: Sprite2D = null
			var animated_chunk: AnimatedSprite2D = null
			var first_water_frame := _eldoria_water_frame_path(grid_x, grid_y, 0)
			if ResourceLoader.exists(first_water_frame):
				var frames := SpriteFrames.new()
				frames.add_animation("flow")
				frames.set_animation_speed("flow", 5.0)
				for frame_index in range(ELDORIA_WATER_FRAME_COUNT):
					var water_frame := load(_eldoria_water_frame_path(grid_x, grid_y, frame_index)) as Texture2D
					if water_frame == null:
						break
					frames.add_frame("flow", water_frame)
				if frames.get_frame_count("flow") == ELDORIA_WATER_FRAME_COUNT:
					animated_chunk = AnimatedSprite2D.new()
					animated_chunk.sprite_frames = frames
					animated_chunk.animation = "flow"
					animated_chunk.name = "EldoriaWater_%02d_%02d" % [grid_x, grid_y]
			if animated_chunk == null:
				chunk_sprite = Sprite2D.new()
				chunk_sprite.texture = chunk_texture
				chunk_sprite.name = "EldoriaChunk_%02d_%02d" % [grid_x, grid_y]
			var visual: Node2D = animated_chunk if animated_chunk != null else chunk_sprite
			visual.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			if animated_chunk != null:
				animated_chunk.centered = false
			else:
				chunk_sprite.centered = false
			visual.position = Vector2(
				grid_x * ELDORIA_CHUNK_SIZE.x * ELDORIA_WORLD_SCALE,
				grid_y * ELDORIA_CHUNK_SIZE.y * ELDORIA_WORLD_SCALE
			)
			visual.scale = Vector2.ONE * ELDORIA_WORLD_SCALE
			visual.z_index = -100
			chunks_root.add_child(visual)
			if animated_chunk != null:
				animated_chunk.play("flow")
	_spawn_eldoria_house_kit()
	_register_eldoria_water_collisions()
	_register_eldoria_wall_collisions()
	_register_eldoria_building_collisions()
	return true

func _get_eldoria_kit_data() -> Dictionary:
	if not eldoria_kit_data.is_empty():
		return eldoria_kit_data
	if not FileAccess.file_exists(ELDORIA_V2_KIT_DATA_PATH):
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(ELDORIA_V2_KIT_DATA_PATH))
	if typeof(parsed) == TYPE_DICTIONARY:
		eldoria_kit_data = parsed
	return eldoria_kit_data

# Chao do mapa em pedacos que so carregam perto da camera (main.gd -> _update_map_stream).
# O pedaco nasce sem textura; quando a camera chega perto, a textura e carregada (em segundo plano)
# e, quando a camera vai para longe, a textura e solta da memoria.
func _stream_chunk(path: String, pos: Vector2, ground_scale: float, size_px: Vector2) -> Sprite2D:
	var chunk := Sprite2D.new()
	chunk.centered = false
	chunk.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	chunk.scale = Vector2.ONE * ground_scale
	chunk.position = pos
	chunk.z_index = -100
	chunk.set_meta("stream_path", path)
	chunk.set_meta("stream_rect", Rect2(pos, size_px * ground_scale))
	chunk.add_to_group("map_stream")
	return chunk

func _eldoria_v2_chunk_path(data: Dictionary, grid_x: int, grid_y: int) -> String:
	return "%s/eldoria_v2_chunk_%02d_%02d.png" % [str(data.get("chunks_dir", "")), grid_x, grid_y]

func _draw_eldoria_v2() -> bool:
	var data := _get_eldoria_kit_data()
	if data.is_empty() or not ResourceLoader.exists(_eldoria_v2_chunk_path(data, 0, 0)):
		return false
	var size_data: Array = data.get("world_size", [ELDORIA_WORLD_SIZE.x, ELDORIA_WORLD_SIZE.y])
	current_map_size = Vector2(float(size_data[0]), float(size_data[1]))
	# Agua: um sprite repetido no mapa todo, trocando os 4 quadros (fica por baixo do chao).
	_spawn_water_layer("EldoriaWater", Rect2(Vector2.ZERO, current_map_size), data.get("water_frames", []), -101)
	var grid_data: Array = data.get("chunk_grid", [9, 9])
	var chunk_px_data: Array = data.get("chunk_px", [400, 320])
	var ground_scale := float(data.get("ground_scale", 2.0))
	var chunks_root := Node2D.new()
	chunks_root.name = "EldoriaV2Chunks"
	world.add_child(chunks_root)
	for grid_y in range(int(grid_data[1])):
		for grid_x in range(int(grid_data[0])):
			var chunk_path := _eldoria_v2_chunk_path(data, grid_x, grid_y)
			if not ResourceLoader.exists(chunk_path):
				continue
			chunks_root.add_child(_stream_chunk(chunk_path, Vector2(grid_x * float(chunk_px_data[0]), grid_y * float(chunk_px_data[1])) * ground_scale, ground_scale, Vector2(float(chunk_px_data[0]), float(chunk_px_data[1]))))
	for prop in data.get("props", []):
		if typeof(prop) == TYPE_DICTIONARY:
			_spawn_kit_prop(prop)
	for rect_data in data.get("solids", []):
		if typeof(rect_data) == TYPE_ARRAY and rect_data.size() >= 4:
			_register_solid_rect(Rect2(float(rect_data[0]), float(rect_data[1]), float(rect_data[2]), float(rect_data[3])))
	return true

# Agua animada: textura repetida no retangulo, trocando os quadros a cada 0.2 s.
# Fica por baixo dos chunks de chao, que sao transparentes onde ha agua.
func _spawn_water_layer(node_name: String, rect: Rect2, frame_paths: Array, z: int) -> Sprite2D:
	var water_frames: Array[Texture2D] = []
	for path in frame_paths:
		var water_texture := load(str(path)) as Texture2D
		if water_texture != null:
			water_frames.append(water_texture)
	if water_frames.is_empty():
		return null
	var water := Sprite2D.new()
	water.name = node_name
	water.texture = water_frames[0]
	water.centered = false
	water.position = rect.position
	water.region_enabled = true
	water.region_rect = Rect2(rect.position, rect.size)
	water.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	water.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	water.z_index = z
	world.add_child(water)
	if water_frames.size() > 1:
		var timer := Timer.new()
		timer.wait_time = 0.2
		timer.autostart = true
		water.add_child(timer)
		timer.timeout.connect(func() -> void:
			var next := (int(water.get_meta("frame", 0)) + 1) % water_frames.size()
			water.set_meta("frame", next)
			water.texture = water_frames[next]
		)
	return water

func _get_eldoria_house_kit_data() -> Dictionary:
	if not eldoria_house_kit_data.is_empty():
		return eldoria_house_kit_data
	if not FileAccess.file_exists(ELDORIA_HOUSE_KIT_DATA_PATH):
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(ELDORIA_HOUSE_KIT_DATA_PATH))
	if typeof(parsed) == TYPE_DICTIONARY:
		eldoria_house_kit_data = parsed
	return eldoria_house_kit_data

func _spawn_eldoria_house_kit() -> void:
	var data := _get_eldoria_house_kit_data()
	for house_data in data.get("houses", []):
		if typeof(house_data) != TYPE_DICTIONARY:
			continue
		var texture_path := str(house_data.get("texture_path", ""))
		var texture := load(texture_path) as Texture2D
		if texture == null:
			push_error("Casa de Eldoria indisponivel: %s" % texture_path)
			continue
		var position_data: Array = house_data.get("world_position", [0.0, 0.0])
		var anchor_data: Array = house_data.get("anchor", [texture.get_width() * 0.5, texture.get_height() * 0.5])
		var house_scale := float(house_data.get("visual_scale", 1.0))
		var anchor := Vector2(float(anchor_data[0]), float(anchor_data[1]))
		var house_root := Node2D.new()
		house_root.name = "EldoriaHouse_%s" % str(house_data.get("id", "house"))
		house_root.position = Vector2(float(position_data[0]), float(position_data[1]))
		house_root.z_index = clampi(int(house_root.position.y), -1024, 1024)
		house_root.set_meta("house_id", str(house_data.get("id", "")))
		house_root.set_meta("house_name", str(house_data.get("name", "")))
		world.add_child(house_root)

		var sprite := Sprite2D.new()
		sprite.name = "Sprite2D"
		sprite.texture = texture
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.scale = Vector2.ONE * house_scale
		sprite.position = (Vector2(texture.get_width(), texture.get_height()) * 0.5 - anchor) * house_scale
		house_root.add_child(sprite)

		var static_body := StaticBody2D.new()
		static_body.name = "CollisionBase"
		static_body.collision_layer = 1
		static_body.collision_mask = 0
		house_root.add_child(static_body)
		for collision_data in house_data.get("collision_rects", []):
			if typeof(collision_data) != TYPE_DICTIONARY:
				continue
			var local_position := (Vector2(
				float(collision_data.get("x", 0.0)),
				float(collision_data.get("y", 0.0))
			) - anchor) * house_scale
			var collision_size := Vector2(
				float(collision_data.get("w", 0.0)),
				float(collision_data.get("h", 0.0))
			) * house_scale
			if collision_size.x <= 0.0 or collision_size.y <= 0.0:
				continue
			var shape := RectangleShape2D.new()
			shape.size = collision_size
			var collision_shape := CollisionShape2D.new()
			collision_shape.shape = shape
			collision_shape.position = local_position + collision_size * 0.5
			static_body.add_child(collision_shape)
			_register_solid_rect(Rect2(house_root.position + local_position, collision_size))

func _register_eldoria_water_collisions() -> void:
	var scale := ELDORIA_WORLD_SCALE
	var source_width := ELDORIA_SOURCE_SIZE.x
	var source_height := ELDORIA_SOURCE_SIZE.y
	var city_offset := ELDORIA_CITY_OFFSET
	var city_size := ELDORIA_CITY_SOURCE_SIZE
	var deck_left := ELDORIA_BOTTOM_DECK_LEFT
	var deck_right := ELDORIA_BOTTOM_DECK_RIGHT
	var water_rects := [
		Rect2(0, 0, source_width, city_offset.y),
		Rect2(0, city_offset.y, city_offset.x, city_size.y),
		Rect2(city_offset.x + city_size.x, city_offset.y, city_offset.x, city_size.y),
		Rect2(0, city_offset.y + city_size.y, deck_left, source_height - city_offset.y - city_size.y),
		Rect2(deck_right, city_offset.y + city_size.y, source_width - deck_right, source_height - city_offset.y - city_size.y)
	]
	for water_rect in water_rects:
		_register_solid_rect(Rect2(water_rect.position * scale, water_rect.size * scale))

func _register_eldoria_wall_collisions() -> void:
	var scale := ELDORIA_WORLD_SCALE
	var city_offset := ELDORIA_CITY_OFFSET
	var source_width := ELDORIA_CITY_SOURCE_SIZE.x
	var source_height := ELDORIA_CITY_SOURCE_SIZE.y
	var wall := ELDORIA_WALL_THICKNESS
	var gate_left := ELDORIA_BOTTOM_GATE_LEFT
	var gate_right := ELDORIA_BOTTOM_GATE_RIGHT
	var walls := [
		Rect2(city_offset.x, city_offset.y, source_width, wall),
		Rect2(city_offset.x, city_offset.y, wall, source_height),
		Rect2(city_offset.x + source_width - wall, city_offset.y, wall, source_height),
		Rect2(city_offset.x, city_offset.y + source_height - wall, gate_left - city_offset.x, wall),
		Rect2(gate_right, city_offset.y + source_height - wall, city_offset.x + source_width - gate_right, wall),
		Rect2(gate_left - 32.0, city_offset.y + source_height - 96.0, 32.0, 96.0),
		Rect2(gate_right, city_offset.y + source_height - 96.0, 32.0, 96.0)
	]
	for wall_rect in walls:
		_register_solid_rect(Rect2(wall_rect.position * scale, wall_rect.size * scale))

func _register_eldoria_building_collisions() -> void:
	var scale := ELDORIA_WORLD_SCALE
	for building_rect in ELDORIA_BUILDING_COLLISION_RECTS:
		_register_solid_rect(Rect2(
			Vector2(building_rect["x"], building_rect["y"]) * scale,
			Vector2(building_rect["w"], building_rect["h"]) * scale
		))

func _draw_valdoria_background() -> bool:
	if not _valdoria_background_available():
		return false
	var texture := load(VALDORIA_BACKGROUND_PATH) as Texture2D
	if texture == null:
		return false
	current_map_size = Vector2(texture.get_width(), texture.get_height())
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.centered = false
	sprite.position = Vector2.ZERO
	sprite.scale = Vector2.ONE
	sprite.z_index = -100
	world.add_child(sprite)
	return true

func _draw_forest_background() -> bool:
	if _forest_chunks_available():
		current_map_size = FOREST_WORLD_SIZE
		var chunks_root := Node2D.new()
		chunks_root.name = "ForestChunksV2"
		chunks_root.set_meta("grid", FOREST_CHUNK_GRID)
		chunks_root.set_meta("chunk_count", FOREST_CHUNK_GRID.x * FOREST_CHUNK_GRID.y)
		world.add_child(chunks_root)
		for grid_y in range(FOREST_CHUNK_GRID.y):
			for grid_x in range(FOREST_CHUNK_GRID.x):
				var chunk_path := _forest_chunk_path(grid_x, grid_y)
				if not ResourceLoader.exists(chunk_path):
					return false
				var chunk_sprite := _stream_chunk(chunk_path, Vector2(
					grid_x * FOREST_CHUNK_SIZE.x * FOREST_WORLD_SCALE,
					grid_y * FOREST_CHUNK_SIZE.y * FOREST_WORLD_SCALE
				), FOREST_GROUND_SCALE, FOREST_CHUNK_SIZE * FOREST_WORLD_SCALE / FOREST_GROUND_SCALE)
				chunk_sprite.name = "ForestChunk_%02d_%02d" % [grid_x, grid_y]
				chunks_root.add_child(chunk_sprite)
		return true
	return false

func _forest_base_background_available() -> bool:
	return ResourceLoader.exists(FOREST_BASE_BACKGROUND_PATH)

func _is_forest_base_map() -> bool:
	return _is_forest_runtime_map() and _forest_base_background_available()

func _resolve_map_id(map_id: String) -> String:
	var requested := map_id.strip_edges()
	if requested.is_empty():
		requested = FOREST_PRIMARY_MAP_ID
	if requested == FOREST_COMPAT_MAP_ID and maps.has(FOREST_PRIMARY_MAP_ID):
		return FOREST_PRIMARY_MAP_ID
	if maps.has(requested):
		return requested
	if maps.has(FOREST_PRIMARY_MAP_ID):
		return FOREST_PRIMARY_MAP_ID
	if maps.has(FOREST_COMPAT_MAP_ID):
		return FOREST_COMPAT_MAP_ID
	return requested

func _is_forest_runtime_map(map_id: String = current_map) -> bool:
	return map_id == FOREST_PRIMARY_MAP_ID or map_id == FOREST_COMPAT_MAP_ID

func _draw_forest_base_background() -> bool:
	if not _forest_base_background_available():
		return false
	var texture := load(FOREST_BASE_BACKGROUND_PATH) as Texture2D
	if texture == null:
		return false
	current_map_size = Vector2(texture.get_width(), texture.get_height())
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.centered = false
	sprite.position = Vector2.ZERO
	sprite.scale = Vector2.ONE
	sprite.z_index = -100
	world.add_child(sprite)
	return true

func _draw_cave_background() -> bool:
	if _cave_chunks_available():
		current_map_size = CAVE_SOURCE_SIZE
		for grid_y in range(4):
			for grid_x in range(5):
				var chunk_path := _cave_chunk_path(grid_x, grid_y)
				var chunk_texture := load(chunk_path) as Texture2D
				if chunk_texture == null:
					return false
				var chunk_sprite := Sprite2D.new()
				chunk_sprite.texture = chunk_texture
				chunk_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
				chunk_sprite.centered = false
				chunk_sprite.position = Vector2(grid_x * CAVE_CHUNK_SIZE.x, grid_y * CAVE_CHUNK_SIZE.y)
				chunk_sprite.scale = Vector2.ONE
				chunk_sprite.z_index = -100
				world.add_child(chunk_sprite)
		return true
	if not _cave_background_available():
		return false
	var texture := load(CAVE_BACKGROUND_PATH) as Texture2D
	if texture == null:
		return false
	current_map_size = Vector2(texture.get_width(), texture.get_height())
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.centered = false
	sprite.position = Vector2.ZERO
	sprite.scale = Vector2.ONE
	sprite.z_index = -100
	world.add_child(sprite)
	return true

func _get_eldoria_collision_data() -> Dictionary:
	if not eldoria_collision_data.is_empty():
		return eldoria_collision_data
	if not FileAccess.file_exists(ELDORIA_COLLISION_DATA_PATH):
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(ELDORIA_COLLISION_DATA_PATH))
	if typeof(parsed) == TYPE_DICTIONARY:
		eldoria_collision_data = parsed
	return eldoria_collision_data

func _get_arcane_ruins_collision_data() -> Dictionary:
	if not arcane_ruins_collision_data.is_empty():
		return arcane_ruins_collision_data
	if not FileAccess.file_exists(ARCANE_RUINS_COLLISION_DATA_PATH):
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(ARCANE_RUINS_COLLISION_DATA_PATH))
	if typeof(parsed) == TYPE_DICTIONARY:
		arcane_ruins_collision_data = parsed
	return arcane_ruins_collision_data

func _register_eldoria_background_collision() -> void:
	_clear_eldoria_collision_root()
	var data := _get_eldoria_collision_data()
	if data.is_empty():
		return
	var root := Node2D.new()
	root.name = "EldoriaCollisions"
	world.add_child(root)
	for item in data.get("collisions", []):
		var group_name := str(item.get("group", "Misc"))
		var group_node := root.get_node_or_null(group_name) as Node2D
		if group_node == null:
			group_node = Node2D.new()
			group_node.name = group_name
			root.add_child(group_node)
		_register_eldoria_collision_item(group_node, item)
	var portal_data: Variant = data.get("portal", {})
	if typeof(portal_data) == TYPE_DICTIONARY:
		var portal_pos := Vector2(float(portal_data.get("x", 0.0)), float(portal_data.get("y", 0.0)))
		var portal_size := Vector2(float(portal_data.get("w", 0.0)), float(portal_data.get("h", 0.0)))
		if portal_size.x > 0.0 and portal_size.y > 0.0:
			portal_passage_rects.append(Rect2(portal_pos, portal_size))

func _clear_eldoria_collision_root() -> void:
	if world == null:
		return
	var old_root := world.get_node_or_null("EldoriaCollisions")
	if old_root != null:
		old_root.queue_free()

func _clear_arcane_ruins_collision_root() -> void:
	if world == null:
		return
	var old_root := world.get_node_or_null("ArcaneRuinsCollisions")
	if old_root != null:
		old_root.queue_free()

func _register_eldoria_collision_item(parent: Node2D, item: Dictionary) -> void:
	var kind := str(item.get("type", "rect"))
	var body := StaticBody2D.new()
	body.name = str(item.get("name", "Collision"))
	body.collision_layer = 1
	body.collision_mask = 0
	body.input_pickable = false
	var shape_node := CollisionShape2D.new()
	shape_node.name = body.name + "_Shape"
	if kind == "circle":
		var circle := CircleShape2D.new()
		circle.radius = float(item.get("r", 0.0))
		shape_node.shape = circle
		shape_node.position = Vector2(float(item.get("cx", 0.0)), float(item.get("cy", 0.0)))
		_register_solid_circle(Vector2(float(item.get("cx", 0.0)), float(item.get("cy", 0.0))), float(item.get("r", 0.0)))
	else:
		var rect := Rect2(
			Vector2(float(item.get("x", 0.0)), float(item.get("y", 0.0))),
			Vector2(float(item.get("w", 0.0)), float(item.get("h", 0.0)))
		)
		var rect_shape := RectangleShape2D.new()
		rect_shape.size = rect.size
		shape_node.shape = rect_shape
		shape_node.position = rect.position + rect.size * 0.5
		_register_solid_rect(rect)
	body.add_child(shape_node)
	parent.add_child(body)

func _register_arcane_ruins_background_collision() -> void:
	_clear_arcane_ruins_collision_root()
	var data := _get_arcane_ruins_collision_data()
	if data.is_empty():
		return
	var root := Node2D.new()
	root.name = "ArcaneRuinsCollisions"
	world.add_child(root)
	for item in data.get("collisions", []):
		var group_name := str(item.get("group", "Ruins"))
		var group_node := root.get_node_or_null(group_name) as Node2D
		if group_node == null:
			group_node = Node2D.new()
			group_node.name = group_name
			root.add_child(group_node)
		_register_eldoria_collision_item(group_node, item)

func _register_solid_rect(rect: Rect2) -> void:
	if rect.size.x <= 0 or rect.size.y <= 0:
		return
	solid_obstacles.append({"type": "rect", "rect": rect})

func _register_solid_circle(center: Vector2, radius: float) -> void:
	if radius <= 0.0:
		return
	solid_obstacles.append({"type": "circle", "center": center, "radius": radius})

func _obstacle_contains_point(obstacle: Dictionary, pos: Vector2) -> bool:
	var kind := str(obstacle.get("type", "rect"))
	if kind == "circle":
		var center: Vector2 = obstacle.get("center", Vector2.ZERO)
		var radius: float = float(obstacle.get("radius", 0.0))
		return pos.distance_to(center) <= radius
	var rect: Rect2 = obstacle.get("rect", Rect2())
	return rect.has_point(pos)

func _obstacle_world_rect(obstacle: Dictionary) -> Rect2:
	var kind := str(obstacle.get("type", "rect"))
	if kind == "circle":
		var center: Vector2 = obstacle.get("center", Vector2.ZERO)
		var radius: float = float(obstacle.get("radius", 0.0))
		return Rect2(center - Vector2.ONE * radius, Vector2.ONE * radius * 2.0)
	return obstacle.get("rect", Rect2())

func _get_cave_collision_data() -> Dictionary:
	if not cave_collision_data.is_empty():
		return cave_collision_data
	if not FileAccess.file_exists(CAVE_COLLISION_DATA_PATH):
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(CAVE_COLLISION_DATA_PATH))
	if typeof(parsed) == TYPE_DICTIONARY:
		cave_collision_data = parsed
	return cave_collision_data

func _cave_array_point(value: Variant) -> Vector2:
	if typeof(value) == TYPE_ARRAY and value.size() >= 2:
		return Vector2(float(value[0]), float(value[1]))
	return Vector2.ZERO

func _cave_point_in_polygon(point: Vector2, polygon: Array) -> bool:
	var inside := false
	var count := polygon.size()
	if count < 3:
		return false
	var j := count - 1
	for i in range(count):
		var pi := _cave_array_point(polygon[i])
		var pj := _cave_array_point(polygon[j])
		if ((pi.y > point.y) != (pj.y > point.y)):
			var dy := pj.y - pi.y
			if absf(dy) < 0.001:
				dy = 0.001
			var x_intersect := (pj.x - pi.x) * (point.y - pi.y) / dy + pi.x
			if point.x < x_intersect:
				inside = not inside
		j = i
	return inside

func _cave_distance_to_polyline(point: Vector2, points: Array) -> float:
	if points.size() < 2:
		return INF
	var best := INF
	for i in range(1, points.size()):
		var a := _cave_array_point(points[i - 1])
		var b := _cave_array_point(points[i])
		var ab := b - a
		var denom := maxf(1.0, ab.length_squared())
		var t := clampf((point - a).dot(ab) / denom, 0.0, 1.0)
		best = minf(best, point.distance_to(a + ab * t))
	return best

func _is_point_in_cave_blocked_feature(pos: Vector2) -> bool:
	var data := _get_cave_collision_data()
	for polygon in data.get("water_blocked_polygons", []):
		if _cave_point_in_polygon(pos, polygon):
			return true
	for object_data in data.get("solid_objects_examples", []):
		var shape := str(object_data.get("shape", "polygon"))
		if shape == "ellipse":
			var bbox: Array = object_data.get("bbox", [])
			if bbox.size() >= 4:
				var min_pos := Vector2(float(bbox[0]), float(bbox[1]))
				var max_pos := Vector2(float(bbox[2]), float(bbox[3]))
				var center := (min_pos + max_pos) * 0.5
				var radius := (max_pos - min_pos) * 0.5
				if radius.x > 0.0 and radius.y > 0.0:
					var normalized := Vector2((pos.x - center.x) / radius.x, (pos.y - center.y) / radius.y)
					if normalized.length_squared() <= 1.0:
						return true
		elif shape == "polygon":
			if _cave_point_in_polygon(pos, object_data.get("points", [])):
				return true
	return false

func _is_cave_walkable(pos: Vector2) -> bool:
	if _is_point_in_cave_blocked_feature(pos):
		return false
	var data := _get_cave_collision_data()
	for polygon in data.get("walkable_polygons", []):
		if _cave_point_in_polygon(pos, polygon):
			return true
	for corridor in data.get("walkable_corridor_lines", []):
		var width := float(corridor.get("recommended_width_px", 80.0))
		if _cave_distance_to_polyline(pos, corridor.get("points", [])) <= width * 0.5:
			return true
	return false

func _register_cave_background_collision() -> void:
	_get_cave_collision_data()

func _register_valdoria_background_collision() -> void:
	for rect in [
		Rect2(0, 0, 1254, 44),
		Rect2(0, 1210, 1254, 44),
		Rect2(0, 0, 44, 1254),
		Rect2(1210, 0, 44, 1254),
		Rect2(60, 58, 442, 54),
		Rect2(752, 58, 442, 54),
		Rect2(60, 1140, 382, 54),
		Rect2(812, 1140, 382, 54),
		Rect2(58, 118, 48, 1000),
		Rect2(1148, 118, 48, 1000),
		Rect2(442, 230, 372, 424),
		Rect2(116, 170, 278, 188),
		Rect2(118, 430, 290, 220),
		Rect2(118, 760, 286, 238),
		Rect2(862, 176, 286, 196),
		Rect2(848, 448, 320, 210),
		Rect2(842, 782, 300, 248),
		Rect2(565, 748, 118, 114),
		Rect2(904, 482, 86, 96),
		Rect2(104, 1060, 172, 98),
		Rect2(972, 1048, 172, 102)
	]:
		_register_solid_rect(rect)

func _register_forest_background_collision() -> void:
	for rect in [
		_forest_rect(0, 0, 36, FOREST_SOURCE_SIZE.y),
		_forest_rect(0, 0, FOREST_SOURCE_SIZE.x, 34),
		_forest_rect(0, FOREST_SOURCE_SIZE.y - 34, FOREST_SOURCE_SIZE.x, 34),
		_forest_rect(FOREST_SOURCE_SIZE.x - 34, 0, 34, FOREST_SOURCE_SIZE.y)
	]:
		_register_solid_rect(rect)
	# Mata fechada/lago sao bloqueados pela mascara; arvores e pedras soltas
	# tem colisao so no pe (a copa deixa passar por tras via y-sort).
	_spawn_forest_kit()

func _get_forest_kit_data() -> Dictionary:
	if not forest_kit_data.is_empty():
		return forest_kit_data
	if not FileAccess.file_exists(FOREST_KIT_DATA_PATH):
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(FOREST_KIT_DATA_PATH))
	if typeof(parsed) == TYPE_DICTIONARY:
		forest_kit_data = parsed
	return forest_kit_data

func _spawn_forest_kit() -> void:
	forest_walk_image = null
	var data := _get_forest_kit_data()
	if data.is_empty():
		push_error("Floresta v2 indisponivel: %s" % FOREST_KIT_DATA_PATH)
		return
	_spawn_map_kit(data)

func _get_ruins_kit_data() -> Dictionary:
	if not ruins_kit_data.is_empty():
		return ruins_kit_data
	if not FileAccess.file_exists(RUINS_KIT_DATA_PATH):
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(RUINS_KIT_DATA_PATH))
	if typeof(parsed) == TYPE_DICTIONARY:
		ruins_kit_data = parsed
	return ruins_kit_data

func _ruins_v2_active() -> bool:
	return current_map == "arcane_ruins" and not _get_ruins_kit_data().is_empty()

# Ruinas Arcanas v2 (tools/ruins_v2): chunks de chao + mascara + lago magico + props.
func _draw_ruins_v2() -> bool:
	var data := _get_ruins_kit_data()
	if data.is_empty():
		return false
	var size_data: Array = data.get("world_size", [7200, 5760])
	current_map_size = Vector2(float(size_data[0]), float(size_data[1]))
	var grid_data: Array = data.get("chunk_grid", [9, 9])
	var chunk_px_data: Array = data.get("chunk_px", [400, 320])
	var ground_scale := float(data.get("ground_scale", 2.0))
	var chunks_root := Node2D.new()
	chunks_root.name = "RuinsV2Chunks"
	world.add_child(chunks_root)
	for grid_y in range(int(grid_data[1])):
		for grid_x in range(int(grid_data[0])):
			var path := "%s/%s_%02d_%02d.png" % [str(data.get("chunks_dir", "")), str(data.get("chunk_prefix", "")), grid_x, grid_y]
			if not ResourceLoader.exists(path):
				continue
			chunks_root.add_child(_stream_chunk(path, Vector2(grid_x * float(chunk_px_data[0]), grid_y * float(chunk_px_data[1])) * ground_scale, ground_scale, Vector2(float(chunk_px_data[0]), float(chunk_px_data[1]))))
	forest_walk_image = null
	_spawn_map_kit(data)
	for rect_data in data.get("solids", []):
		if typeof(rect_data) == TYPE_ARRAY and rect_data.size() >= 4:
			_register_solid_rect(Rect2(float(rect_data[0]), float(rect_data[1]), float(rect_data[2]), float(rect_data[3])))
	return true

# Mascara andavel (reaproveita forest_walk_image), lago animado e props de um kit.
func _spawn_map_kit(data: Dictionary) -> void:
	var mask_info: Dictionary = data.get("walkable_mask", {})
	var mask_path := str(mask_info.get("path", ""))
	var mask_texture := load(mask_path) as Texture2D if not mask_path.is_empty() else null
	if mask_texture != null:
		forest_walk_image = mask_texture.get_image()
		if forest_walk_image != null and forest_walk_image.is_compressed():
			forest_walk_image.decompress()
		forest_walk_cell = maxf(1.0, float(mask_info.get("cell", 16.0)))
	# Lago: agua animada por baixo do chao + camada de profundidade/espuma/vitorias-regias.
	var lake: Dictionary = data.get("lake", {})
	var lake_rect_data: Array = lake.get("rect", [])
	if lake_rect_data.size() >= 4:
		var lake_rect := Rect2(float(lake_rect_data[0]), float(lake_rect_data[1]), float(lake_rect_data[2]), float(lake_rect_data[3]))
		_spawn_water_layer("ForestLakeWater", lake_rect, lake.get("water_frames", []), -102)
		var overlay_path := str(lake.get("overlay", ""))
		var overlay_texture := load(overlay_path) as Texture2D if not overlay_path.is_empty() else null
		if overlay_texture != null:
			var overlay := Sprite2D.new()
			overlay.name = "ForestLakeOverlay"
			overlay.texture = overlay_texture
			overlay.centered = false
			overlay.position = lake_rect.position
			overlay.scale = Vector2.ONE * float(lake.get("overlay_scale", 2.0))
			overlay.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			overlay.z_index = -101
			world.add_child(overlay)
	for prop in data.get("props", []):
		if typeof(prop) == TYPE_DICTIONARY:
			_spawn_kit_prop(prop)

# Prop de kit de mapa (floresta v2, Eldoria v2): sprite com pe em "pos",
# "offset" em px da textura, colisao no pe ("collision" ou lista "collisions"),
# "layer": "ground" para pecas pisaveis (ponte) e "frames"/"fps" para animacao (fonte).
func _spawn_kit_prop(prop: Dictionary) -> void:
	var texture := load(str(prop.get("texture", ""))) as Texture2D
	if texture == null:
		return
	var pos_data: Array = prop.get("pos", [0.0, 0.0])
	var offset_data: Array = prop.get("offset", [0.0, 0.0])
	var pos := Vector2(float(pos_data[0]), float(pos_data[1]))
	var offset := Vector2(float(offset_data[0]), float(offset_data[1]))
	var visual: Node2D
	var frame_paths: Array = prop.get("frames", [])
	if frame_paths.size() > 1:
		var frames := SpriteFrames.new()
		frames.add_animation("loop")
		frames.set_animation_speed("loop", float(prop.get("fps", 6.0)))
		for frame_path in frame_paths:
			var frame_texture := load(str(frame_path)) as Texture2D
			if frame_texture != null:
				frames.add_frame("loop", frame_texture)
		var animated := AnimatedSprite2D.new()
		animated.sprite_frames = frames
		animated.animation = "loop"
		animated.centered = false
		animated.offset = offset
		animated.flip_h = bool(prop.get("flip_h", false))
		animated.play("loop")
		visual = animated
	else:
		var sprite := Sprite2D.new()
		sprite.texture = texture
		sprite.centered = false
		sprite.offset = offset
		sprite.flip_h = bool(prop.get("flip_h", false))
		visual = sprite
	visual.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var prop_scale := float(prop.get("scale", 1.0))
	visual.scale = Vector2.ONE * prop_scale
	visual.position = pos
	# Casa (tools/casas/gerar_corpo_casas.py): a ordem de desenho vem da linha da base (pe da casa).
	# Quem esta na frente (pes abaixo da base) fica por cima; o desenho continua no mesmo lugar.
	var sort_y := pos.y
	if prop.has("base"):
		sort_y = pos.y + float(prop["base"])
		visual.position.y = sort_y
		var shift := Vector2(0.0, float(prop["base"]) / maxf(0.001, prop_scale))
		if visual is Sprite2D:
			(visual as Sprite2D).offset -= shift
		elif visual is AnimatedSprite2D:
			(visual as AnimatedSprite2D).offset -= shift
	if str(prop.get("layer", "")) == "ground":
		visual.z_index = -99  # logo acima dos chunks (-100), abaixo de tudo que anda
	else:
		visual.z_index = clampi(int(sort_y), -1024, 1024)
	world.add_child(visual)
	var collisions: Array = prop.get("collisions", [])
	var single: Array = prop.get("collision", [])
	if single.size() >= 4:
		collisions = collisions + [single]
	# corpo inteiro da casa e solido: nao da para entrar atras dela (nem pelos cantos)
	var corpo: Array = prop.get("corpo", [])
	if corpo.size() >= 4:
		collisions = collisions + [corpo]
	for collision in collisions:
		if typeof(collision) == TYPE_ARRAY and collision.size() >= 4:
			_register_solid_rect(Rect2(
				pos + Vector2(float(collision[0]), float(collision[1])),
				Vector2(float(collision[2]), float(collision[3]))
			))

func _is_forest_walkable(pos: Vector2) -> bool:
	if forest_walk_image == null:
		return true
	var cell_x := int(pos.x / forest_walk_cell)
	var cell_y := int(pos.y / forest_walk_cell)
	if cell_x < 0 or cell_y < 0 or cell_x >= forest_walk_image.get_width() or cell_y >= forest_walk_image.get_height():
		return false
	return forest_walk_image.get_pixel(cell_x, cell_y).r > 0.5

func _draw_valdoria_terrain() -> void:
	if _draw_valdoria_background():
		_register_valdoria_background_collision()
		return
	_draw_tiled_rect("res://assets/sprites/tile_water.png", Rect2(0, 0, current_map_size.x, current_map_size.y), 64, -100)
	_draw_tiled_rect("res://assets/sprites/tile_stone.png", Rect2(260, 160, current_map_size.x - 520, current_map_size.y - 300), 64, -96)
	_draw_tiled_rect("res://assets/sprites/tile_ruin.png", Rect2(520, 310, 1160, 620), 64, -94)
	_draw_tiled_rect("res://assets/sprites/tile_path.png", Rect2(980, 260, 210, 930), 64, -93)
	_draw_tiled_rect("res://assets/sprites/tile_path.png", Rect2(520, 710, 1180, 130), 64, -93)
	for wall in [
		Rect2(235, 135, 1730, 42), Rect2(235, 1110, 730, 42), Rect2(1235, 1110, 730, 42),
		Rect2(235, 135, 42, 1015), Rect2(1925, 135, 42, 1015)
	]:
		_add_world_rect(wall, Color("#273347"), -91)
		_register_solid_rect(wall)
	for gate_post in [Rect2(965, 1090, 36, 66), Rect2(1199, 1090, 36, 66)]:
		_add_world_rect(gate_post, Color("#34415c"), -90)
		_register_solid_rect(gate_post)
	_add_world_label("Pets", Vector2(570, 525), Color("#9effb0"))
	_add_world_label("Montarias", Vector2(1300, 525), Color("#ffe0a3"))
	_add_world_label("Forja Rara", Vector2(1490, 805), Color("#ffd06b"))

func _forest_main_path_points() -> Array[Vector2]:
	return [
		_forest_point(120, 105),
		_forest_point(175, 155),
		_forest_point(260, 205),
		_forest_point(380, 235),
		_forest_point(520, 255),
		_forest_point(680, 300),
		_forest_point(820, 380),
		_forest_point(930, 500),
		_forest_point(1010, 620),
		_forest_point(1070, 760),
		_forest_point(1130, 860),
		_forest_point(1185, 940),
		_forest_point(1235, 1000)
	]

func _draw_forest_terrain() -> void:
	_draw_tiled_rect("res://assets/sprites/tile_grass.png", Rect2(0, 0, current_map_size.x, current_map_size.y), 64, -100)
	_draw_tiled_rect("res://assets/sprites/tile_water.png", Rect2(0, 0, 255, current_map_size.y), 64, -99)
	_draw_tiled_rect("res://assets/sprites/tile_sand.png", Rect2(235, 0, 70, current_map_size.y), 64, -98)
	_draw_tiled_blob("res://assets/sprites/tile_water.png", Vector2(81.25, 190), 42.5, 105, -99)
	_draw_tiled_blob("res://assets/sprites/tile_water.png", Vector2(75, 537.5), 35, 130, -99)
	_draw_path_points("res://assets/sprites/tile_path.png", _forest_main_path_points(), 175, -96)
	_draw_tiled_blob("res://assets/sprites/tile_path.png", Vector2(155, 715), 77.5, 47.5, -95)
	_draw_tiled_blob("res://assets/sprites/tile_path.png", Vector2(312.5, 550), 67.5, 42.5, -95)
	_draw_tiled_blob("res://assets/sprites/tile_path.png", Vector2(497.5, 395), 82.5, 47.5, -95)
	_draw_tiled_blob("res://assets/sprites/tile_path.png", Vector2(797.5, 227.5), 77.5, 47.5, -95)
	_draw_tiled_blob("res://assets/sprites/tile_path.png", Vector2(1095, 107.5), 85, 51.25, -95)
	_draw_tiled_blob("res://assets/sprites/tile_grass.png", Vector2(225, 625), 90, 55, -97, 64, Color("#5d8b42"))
	_draw_tiled_blob("res://assets/sprites/tile_grass.png", Vector2(675, 355), 100, 65, -97, 64, Color("#4c7b3a"))
	_draw_tiled_blob("res://assets/sprites/tile_grass.png", Vector2(1057.5, 130), 105, 65, -97, 64, Color("#466d35"))
	_register_solid_rect(Rect2(0, 0, 210, current_map_size.y))
	_register_solid_rect(Rect2(235, 360, 250, 820))
	_register_solid_rect(Rect2(55, 395, 58.75, 265))
	_register_solid_rect(Rect2(0, 0, current_map_size.x, 34))
	_register_solid_rect(Rect2(0, current_map_size.y - 34, current_map_size.x, 34))

func _draw_arcane_terrain() -> void:
	_draw_tiled_rect("res://assets/sprites/tile_arcane.png", Rect2(0, 0, current_map_size.x, current_map_size.y), 64, -100)
	_draw_tiled_blob("res://assets/sprites/tile_ruin.png", Vector2(1070, 760), 760, 500, -96)
	_draw_path_points("res://assets/sprites/tile_path.png", [Vector2(1080, 1300), Vector2(980, 1040), Vector2(1220, 810), Vector2(980, 620), Vector2(1420, 430), Vector2(1900, 240)], 135, -95)
	_draw_tiled_blob("res://assets/sprites/tile_ruin.png", Vector2(1900, 255), 260, 160, -94)
	_register_arcane_ruins_background_collision()

func _draw_cave_terrain() -> void:
	_draw_tiled_rect("res://assets/sprites/tile_cave.png", Rect2(0, 0, current_map_size.x, current_map_size.y), 64, -100)
	_draw_path_points("res://assets/sprites/tile_cave_floor.png", [Vector2(1080, 1300), Vector2(930, 1080), Vector2(590, 900), Vector2(850, 700), Vector2(1230, 690), Vector2(1510, 500), Vector2(1900, 240)], 260, -97)
	_draw_tiled_blob("res://assets/sprites/tile_cave_floor.png", Vector2(590, 900), 330, 210, -96)
	_draw_tiled_blob("res://assets/sprites/tile_cave_floor.png", Vector2(1260, 690), 390, 240, -96)
	_draw_tiled_blob("res://assets/sprites/tile_cave_floor.png", Vector2(1900, 240), 260, 180, -96)
	for dark_pool in [Rect2(360, 250, 230, 130), Rect2(1510, 210, 280, 150), Rect2(420, 960, 210, 120), Rect2(1330, 980, 260, 110)]:
		_add_world_rect(dark_pool, Color("#151923"), -95)
		_register_solid_rect(dark_pool.grow(-18))

func _draw_highland_terrain() -> void:
	_draw_tiled_rect("res://assets/sprites/tile_grass.png", Rect2(0, 0, current_map_size.x, current_map_size.y), 64, -100)
	_draw_path_points("res://assets/sprites/tile_path.png", [Vector2(1080, 1300), Vector2(740, 1110), Vector2(980, 900), Vector2(760, 690), Vector2(1180, 540), Vector2(1450, 410), Vector2(1900, 240)], 155, -96)
	for ridge in [Rect2(140, 160, 480, 150), Rect2(1500, 180, 520, 160), Rect2(210, 760, 380, 150), Rect2(1520, 810, 430, 150)]:
		_add_world_rect(ridge, Color("#405945"), -95)
		_register_solid_rect(ridge.grow(-22))
	for clearing in [Rect2(680, 430, 250, 130), Rect2(1220, 560, 280, 150), Rect2(720, 900, 240, 130)]:
		_add_world_rect(clearing, Color("#c7b783"), -94)

func _draw_crystal_mines_terrain() -> void:
	_draw_tiled_rect("res://assets/sprites/tile_cave.png", Rect2(0, 0, current_map_size.x, current_map_size.y), 64, -100)
	_draw_path_points("res://assets/sprites/tile_cave_floor.png", [Vector2(1080, 1300), Vector2(880, 1020), Vector2(1160, 780), Vector2(850, 560), Vector2(1370, 430), Vector2(1900, 240)], 230, -97)
	_draw_tiled_blob("res://assets/sprites/tile_ruin.png", Vector2(1120, 760), 610, 380, -96)
	for seam in [Rect2(380, 260, 150, 760), Rect2(1690, 240, 160, 790), Rect2(830, 360, 470, 110)]:
		_add_world_rect(seam, Color("#26385d"), -95)
		_register_solid_rect(seam.grow(-20))
	for glow in [Rect2(650, 650, 180, 110), Rect2(1330, 670, 180, 110)]:
		_add_world_rect(glow, Color("#345a80"), -94)

func _draw_ember_fortress_terrain() -> void:
	_draw_tiled_rect("res://assets/sprites/tile_ruin.png", Rect2(0, 0, current_map_size.x, current_map_size.y), 64, -100)
	_draw_tiled_blob("res://assets/sprites/tile_stone.png", Vector2(1100, 720), 820, 520, -97)
	_draw_path_points("res://assets/sprites/tile_path.png", [Vector2(1080, 1300), Vector2(900, 1030), Vector2(1210, 820), Vector2(970, 640), Vector2(1360, 470), Vector2(1900, 240)], 150, -96)
	for lava in [Rect2(140, 280, 230, 680), Rect2(1840, 260, 230, 700), Rect2(650, 250, 840, 80)]:
		_add_world_rect(lava, Color("#7a2d19"), -95)
		_register_solid_rect(lava.grow(-12))
	for wall in [Rect2(350, 250, 1500, 44), Rect2(350, 1010, 1500, 44), Rect2(350, 250, 44, 804), Rect2(1806, 250, 44, 804)]:
		_add_world_rect(wall, Color("#2b2424"), -94)
		_register_solid_rect(wall)

func _spawn_map_decor() -> void:
	if current_map == "city_eldoria":
		if _eldoria_background_available():
			return
		var center := current_map_size * 0.5
		_add_world_sprite("res://assets/sprites/decor_fountain.png", center, 1.28, -10)
		_add_world_sprite("res://assets/sprites/decor_house_guild_hall.png", Vector2(890, 555), 0.72, -8)
		_add_world_sprite("res://assets/sprites/decor_house_cottage_blue.png", Vector2(650, 1350), 0.70, -8)
		_add_world_sprite("res://assets/sprites/decor_house_market_reference.png", Vector2(2190, 650), 0.72, -8)
		_add_world_sprite("res://assets/sprites/decor_house_forge_reference.png", Vector2(2200, 1410), 0.74, -8)
		_add_world_sprite("res://assets/sprites/decor_house_noble_blue.png", Vector2(1035, 820), 0.58, -8)
		_add_world_sprite("res://assets/sprites/decor_house_cottage_blue.png", Vector2(2450, 1120), 0.58, -8)
		_add_world_sprite("res://assets/sprites/decor_house_noble_blue.png", Vector2(880, 1750), 0.60, -8)
		for p in [Vector2(430, 390), Vector2(510, 1810), Vector2(2750, 390), Vector2(2620, 1770), Vector2(430, 890), Vector2(2750, 940), Vector2(1220, 1830), Vector2(1880, 610)]:
			_add_world_sprite("res://assets/sprites/decor_tree.png", p, 1.55, -12)
		for p in [Vector2(2110, 820), Vector2(2300, 830), Vector2(2050, 1540), Vector2(2330, 1570), Vector2(1030, 690), Vector2(845, 700)]:
			_add_world_sprite("res://assets/sprites/decor_crate.png", p, 1.15, -6)
		for p in [Vector2(710, 1470), Vector2(780, 1475), Vector2(2145, 1525), Vector2(2250, 1520)]:
			_add_world_sprite("res://assets/sprites/decor_barrel.png", p, 1.1, -6)
		for p in [Vector2(1308, 968), Vector2(1710, 968), Vector2(1308, 1315), Vector2(1710, 1315)]:
			_add_world_sprite("res://assets/sprites/decor_torch.png", p, 1.0, -6)
	elif current_map == "city_valdoria":
		_add_world_sprite("res://assets/sprites/decor_fountain.png", Vector2(1080, 560), 2.0, -10)
		_add_world_sprite("res://assets/sprites/decor_house_guild_hall.png", Vector2(500, 360), 0.64, -8)
		_add_world_sprite("res://assets/sprites/decor_house_cottage_blue.png", Vector2(760, 365), 0.64, -8)
		_add_world_sprite("res://assets/sprites/decor_house_noble_blue.png", Vector2(1410, 360), 0.64, -8)
		_add_world_sprite("res://assets/sprites/decor_house_guild_hall.png", Vector2(1660, 365), 0.64, -8)
		_add_world_sprite("res://assets/sprites/decor_house_market_reference.png", Vector2(525, 590), 0.66, -8)
		_add_world_sprite("res://assets/sprites/decor_house_cottage_blue.png", Vector2(1255, 570), 0.66, -8)
		_add_world_sprite("res://assets/sprites/decor_house_forge_reference.png", Vector2(1625, 765), 0.72, -8)
		_add_world_sprite("res://assets/sprites/decor_house_noble_blue.png", Vector2(570, 980), 0.64, -8)
		_add_world_sprite("res://assets/sprites/decor_house_market_reference.png", Vector2(1390, 990), 0.64, -8)
		for p in [Vector2(330, 250), Vector2(1840, 250), Vector2(390, 1030), Vector2(1830, 1010), Vector2(1030, 960), Vector2(1185, 955)]:
			_add_world_sprite("res://assets/sprites/decor_crystal.png", p, 1.7, -12)
		for p in [Vector2(350, 500), Vector2(1850, 520), Vector2(360, 880), Vector2(1850, 900)]:
			_add_world_sprite("res://assets/sprites/decor_tree_dark.png", p, 1.6, -12)
		for p in [Vector2(1495, 795), Vector2(1690, 850), Vector2(565, 620), Vector2(1300, 625)]:
			_add_world_sprite("res://assets/sprites/decor_crate.png", p, 1.25, -6)
	elif current_map == "forest_boars":
		return
	elif current_map == "arcane_ruins":
		for p in [Vector2(180, 170), Vector2(1010, 165), Vector2(300, 475), Vector2(890, 430)]:
			_add_world_sprite("res://assets/sprites/decor_crystal.png", p, 2.0, -12)
		for p in [Vector2(420, 250), Vector2(760, 180), Vector2(1100, 510)]:
			_add_world_sprite("res://assets/sprites/decor_rock.png", p, 1.8, -12)
	elif current_map == "bat_cave":
		if _cave_background_available():
			return
		for p in [Vector2(160, 160), Vector2(340, 460), Vector2(720, 180), Vector2(950, 470), Vector2(1120, 240)]:
			_add_world_sprite("res://assets/sprites/decor_stalagmite.png", p, 2.0, -12)
		for p in [Vector2(250, 270), Vector2(825, 350), Vector2(1060, 570)]:
			_add_world_sprite("res://assets/sprites/decor_rock.png", p, 1.8, -12)
	elif current_map == "highland_pass":
		for p in [Vector2(260, 220), Vector2(520, 340), Vector2(1540, 280), Vector2(1800, 440), Vector2(420, 860), Vector2(1640, 930)]:
			_add_world_sprite("res://assets/sprites/decor_tree.png", p, 1.9, -12)
		for p in [Vector2(720, 230), Vector2(1240, 420), Vector2(880, 860), Vector2(1510, 720)]:
			_add_world_sprite("res://assets/sprites/decor_rock.png", p, 2.0, -12)
	elif current_map == "crystal_mines":
		for p in [Vector2(410, 260), Vector2(700, 670), Vector2(1180, 420), Vector2(1510, 760), Vector2(1760, 1030)]:
			_add_world_sprite("res://assets/sprites/decor_crystal.png", p, 2.2, -12)
		for p in [Vector2(300, 560), Vector2(1010, 910), Vector2(1620, 350)]:
			_add_world_sprite("res://assets/sprites/decor_stalagmite.png", p, 2.0, -12)
	elif current_map == "ember_fortress":
		for p in [Vector2(460, 300), Vector2(1560, 300), Vector2(470, 980), Vector2(1570, 980)]:
			_add_world_sprite("res://assets/sprites/decor_forge.png", p, 1.8, -12)
		for p in [Vector2(680, 430), Vector2(1320, 460), Vector2(790, 910), Vector2(1390, 900)]:
			_add_world_sprite("res://assets/sprites/decor_rock.png", p, 2.0, -12)

func _spawn_forest_decor() -> void:
	var path_points := _forest_main_path_points()
	_add_world_sprite("res://assets/sprites/decor_sign.png", Vector2(790, 2630), 1.1, -8)
	_add_world_sprite("res://assets/sprites/decor_torch.png", Vector2(510, 2775), 0.95, -8)
	_add_world_sprite("res://assets/sprites/decor_torch.png", Vector2(745, 2795), 0.95, -8)
	_add_world_sprite("res://assets/sprites/decor_stump.png", Vector2(910, 2540), 1.15, -11)
	_add_world_sprite("res://assets/sprites/decor_rock.png", Vector2(1090, 2320), 1.45, -11)
	_add_world_sprite("res://assets/sprites/decor_rock.png", Vector2(4160, 600), 1.9, -11)
	_add_world_sprite("res://assets/sprites/decor_rock.png", Vector2(4530, 360), 1.85, -11)
	for p in [Vector2(4210, 300), Vector2(4280, 690), Vector2(4590, 575), Vector2(4680, 430)]:
		_add_world_sprite("res://assets/sprites/decor_tree_dark.png", p, 1.75, -12)
	for region in [
		Rect2(330, 120, 1260, 700),
		Rect2(320, 850, 780, 920),
		Rect2(370, 1800, 850, 690),
		Rect2(1280, 210, 1040, 850),
		Rect2(1450, 1900, 1260, 760),
		Rect2(2450, 220, 1180, 680),
		Rect2(2780, 1540, 1160, 780),
		Rect2(3740, 850, 840, 1020),
		Rect2(3980, 1740, 740, 760)
	]:
		_scatter_forest_prop("res://assets/sprites/decor_tree.png", region, 12, 1.45, 2.05, 150.0, -12, path_points)
		_scatter_forest_prop("res://assets/sprites/decor_tree_dark.png", region, 8, 1.35, 1.95, 155.0, -12, path_points)
	for region in [
		Rect2(520, 2320, 780, 430),
		Rect2(1080, 1720, 780, 420),
		Rect2(1760, 1260, 900, 430),
		Rect2(2720, 820, 760, 420),
		Rect2(3560, 480, 780, 430)
	]:
		_scatter_forest_prop("res://assets/sprites/decor_rock.png", region, 10, 1.2, 1.75, 95.0, -11, path_points)
		_scatter_forest_prop("res://assets/sprites/decor_stump.png", region, 7, 1.05, 1.35, 105.0, -11, path_points)
		_scatter_forest_prop("res://assets/sprites/decor_bush.png", region, 12, 0.85, 1.15, 55.0, -10, path_points)
	for p in [Vector2(710, 2220), Vector2(980, 2090), Vector2(1350, 1835), Vector2(2260, 1460), Vector2(2920, 1030), Vector2(3850, 650)]:
		_add_world_sprite("res://assets/sprites/decor_bush.png", p, 1.05, -10)
	for p in [Vector2(560, 2460), Vector2(1195, 2115), Vector2(1710, 1650), Vector2(2480, 1265), Vector2(3330, 820), Vector2(4430, 510)]:
		_add_world_sprite("res://assets/sprites/decor_flower_patch.png", p, 0.82, -10)

func _scatter_forest_prop(path: String, region: Rect2, count: int, min_scale: float, max_scale: float, min_path_distance: float, z: int, path_points: Array[Vector2]) -> void:
	var placed := 0
	var attempts := count * 9
	for i in range(attempts):
		if placed >= count:
			return
		var roll_x := _forest_noise01(float(i) + region.position.x * 0.013, float(placed) + 11.0)
		var roll_y := _forest_noise01(float(i) + region.position.y * 0.017, float(placed) + 23.0)
		var pos := Vector2(region.position.x + roll_x * region.size.x, region.position.y + roll_y * region.size.y)
		if _distance_to_path_points(pos, path_points) < min_path_distance:
			continue
		if _is_forest_reserved_clear(pos):
			continue
		if _is_point_blocked(pos):
			continue
		var scale := lerpf(min_scale, max_scale, _forest_noise01(float(i) + 7.0, float(placed) + 31.0))
		_add_world_sprite(path, pos, scale, z)
		placed += 1

func _is_forest_road_walkable(pos: Vector2) -> bool:
	# Trilha antiga (7x7); a Floresta v2 usa a mascara andavel do kit.
	if current_map != "forest_boars" or forest_walk_image != null:
		return false
	var path_points := _forest_main_path_points()
	if path_points.size() < 2:
		return false
	return _distance_to_path_points(pos, path_points) <= 170.0

func _is_forest_reserved_clear(pos: Vector2) -> bool:
	for entry in [
		{"center": _forest_point(120, 105), "radius": 125.0 * FOREST_WORLD_SCALE},
		{"center": _forest_point(280, 210), "radius": 110.0 * FOREST_WORLD_SCALE},
		{"center": _forest_point(1235, 1000), "radius": 155.0 * FOREST_WORLD_SCALE},
		{"center": _forest_point(1120, 900), "radius": 135.0 * FOREST_WORLD_SCALE}
	]:
		var center: Vector2 = entry.get("center", Vector2.ZERO)
		var radius: float = float(entry.get("radius", 0.0))
		if pos.distance_to(center) <= radius:
			return true
	return false

func _add_world_sprite(path: String, pos: Vector2, sprite_scale: float, z: int) -> Sprite2D:
	if _should_cast_world_shadow(path):
		var shadow_texture := load("res://assets/sprites/decor_shadow_soft.png") as Texture2D
		if shadow_texture != null:
			var shadow := Sprite2D.new()
			shadow.texture = shadow_texture
			shadow.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			shadow.position = pos + Vector2(0, 34 * sprite_scale)
			shadow.scale = Vector2(sprite_scale, sprite_scale) * 0.75
			shadow.z_index = z - 1
			shadow.modulate = Color(1, 1, 1, 0.72)
			world.add_child(shadow)
	var sprite := Sprite2D.new()
	sprite.texture = load(path)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.position = pos
	sprite.scale = Vector2(sprite_scale, sprite_scale)
	sprite.z_index = z
	world.add_child(sprite)
	_register_sprite_obstacle(path, pos, sprite_scale)
	return sprite

func _should_cast_world_shadow(path: String) -> bool:
	for token in ["decor_tree", "decor_house", "decor_forge", "decor_portal", "decor_crystal", "decor_rock", "decor_stalagmite", "decor_barrel", "decor_crate", "decor_fountain", "decor_well", "decor_healer_shrine", "decor_stump", "decor_sign", "decor_torch"]:
		if path.find(token) >= 0:
			return true
	return false

func _register_sprite_obstacle(path: String, pos: Vector2, sprite_scale: float) -> void:
	var rect := Rect2()
	if path.find("decor_tree") >= 0:
		rect = Rect2(pos + Vector2(-28, -20) * sprite_scale, Vector2(56, 58) * sprite_scale)
	elif path.find("decor_fountain") >= 0:
		rect = Rect2(pos + Vector2(-34, -28) * sprite_scale, Vector2(68, 58) * sprite_scale)
	elif path.find("decor_house") >= 0:
		var texture := load(path) as Texture2D
		if texture != null:
			var size := Vector2(texture.get_width(), texture.get_height()) * sprite_scale
			rect = Rect2(pos + Vector2(-size.x * 0.43, -size.y * 0.36), Vector2(size.x * 0.86, size.y * 0.74))
	elif path.find("decor_forge") >= 0:
		rect = Rect2(pos + Vector2(-40, -26) * sprite_scale, Vector2(80, 74) * sprite_scale)
	elif path.find("decor_rock") >= 0 and sprite_scale >= 1.35:
		rect = Rect2(pos + Vector2(-18, -12) * sprite_scale, Vector2(36, 28) * sprite_scale)
	elif path.find("decor_stalagmite") >= 0 and sprite_scale >= 1.35:
		rect = Rect2(pos + Vector2(-18, -26) * sprite_scale, Vector2(36, 52) * sprite_scale)
	elif path.find("decor_crystal") >= 0 and sprite_scale >= 1.45:
		rect = Rect2(pos + Vector2(-18, -26) * sprite_scale, Vector2(36, 52) * sprite_scale)
	elif path.find("decor_stump") >= 0 and sprite_scale >= 1.05:
		rect = Rect2(pos + Vector2(-16, -12) * sprite_scale, Vector2(32, 26) * sprite_scale)
	elif path.find("decor_sign") >= 0 and sprite_scale >= 1.0:
		rect = Rect2(pos + Vector2(-10, -18) * sprite_scale, Vector2(20, 36) * sprite_scale)
	elif path.find("decor_barrel") >= 0 or path.find("decor_crate") >= 0:
		rect = Rect2(pos + Vector2(-16, -16) * sprite_scale, Vector2(32, 32) * sprite_scale)
	elif path.find("decor_well") >= 0 or path.find("decor_healer_shrine") >= 0:
		rect = Rect2(pos + Vector2(-24, -22) * sprite_scale, Vector2(48, 44) * sprite_scale)
	if rect.size != Vector2.ZERO:
		_register_solid_rect(rect)

func _is_point_blocked(pos: Vector2) -> bool:
	if pos.x < 18 or pos.y < 18 or pos.x > current_map_size.x - 18 or pos.y > current_map_size.y - 18:
		return true
	if _is_forest_road_walkable(pos):
		return false
	for portal_rect in portal_passage_rects:
		for probe in [Vector2.ZERO, Vector2(0, -10), Vector2(0, 10), Vector2(-12, 0), Vector2(12, 0)]:
			if portal_rect.has_point(pos + probe):
				return false
	if current_map == "bat_cave" and not _cave_v2_active() and _cave_background_available() and not _is_cave_walkable(pos):
		return true
	if (_is_forest_runtime_map() or _ruins_v2_active() or _cave_v2_active() or _valdoria_v2_active() or _swamp_v2_active()) and forest_walk_image != null:
		for probe in [Vector2.ZERO, Vector2(0, -10), Vector2(0, 10), Vector2(-12, 0), Vector2(12, 0)]:
			if not _is_forest_walkable(pos + probe):
				return true
	for obstacle in solid_obstacles:
		for probe in [Vector2.ZERO, Vector2(0, -10), Vector2(0, 10), Vector2(-12, 0), Vector2(12, 0)]:
			if _obstacle_contains_point(obstacle, pos + probe):
				return true
	return false

func _resolve_unblocked_spawn(pos: Vector2, avoid_safe_zone: bool = false) -> Vector2:
	if not _is_point_blocked(pos) and (not avoid_safe_zone or not _is_point_in_safe_zone(pos)):
		return pos
	var directions: Array[Vector2] = [Vector2.DOWN, Vector2.UP, Vector2.LEFT, Vector2.RIGHT, Vector2(1, 1).normalized(), Vector2(-1, 1).normalized(), Vector2(1, -1).normalized(), Vector2(-1, -1).normalized()]
	for radius in range(32, 321, 32):
		for direction in directions:
			var candidate: Vector2 = pos + direction * float(radius)
			if not _is_point_blocked(candidate) and (not avoid_safe_zone or not _is_point_in_safe_zone(candidate)):
				return candidate
	return Vector2(clamp(pos.x, 48.0, current_map_size.x - 48.0), clamp(pos.y, 48.0, current_map_size.y - 48.0))

# NPCs e pedestres/carrocas (o que anda no chao) como retangulos na linha dos pes
func _world_actor_rects() -> Array:
	var rects: Array = []
	for actor in _world_actors():
		rects.append(actor["rect"])
	return rects

# o mesmo, com quem e cada um (para o NPC/pedestre reagir ao esbarrao)
func _world_actors() -> Array:
	var actors: Array = []
	for npc in get_tree().get_nodes_in_group("npcs"):
		if npc is Node2D and is_instance_valid(npc) and (npc as Node2D).is_visible_in_tree():
			var p: Vector2 = (npc as Node2D).global_position + Vector2(0, 14)
			actors.append({"rect": Rect2(p.x - 22.0, p.y - 12.0, 44.0, 24.0), "node": npc, "name": str(npc.get("npc_name"))})
	for state in kit_vehicles:
		if bool(state.get("flying", false)):
			continue
		var sprite := state.get("node") as AnimatedSprite2D
		if sprite == null or not is_instance_valid(sprite):
			continue
		actors.append({"rect": _kit_vehicle_rect(state, sprite.position), "node": sprite, "name": ""})
	return actors

func _kit_vehicle_rect(state: Dictionary, feet: Vector2) -> Rect2:
	if not state.has("foot_rx"):
		var sprite := state.get("node") as AnimatedSprite2D
		var w := 80.0
		if sprite != null and sprite.sprite_frames != null:
			var names := sprite.sprite_frames.get_animation_names()
			if not names.is_empty() and sprite.sprite_frames.get_frame_count(names[0]) > 0:
				w = float(sprite.sprite_frames.get_frame_texture(names[0], 0).get_width())
		w *= absf(sprite.scale.x) if sprite != null else 1.0
		if float(state.get("pe_largura", 0.0)) > 0.0:
			w = float(state["pe_largura"])  # largura do quadro antes do recorte (tools/kits/otimizar_texturas_kit.py)
		# pedestre (quadro ~118 px) vira ~30 px de pe; carroca larga ocupa bem mais
		state["foot_rx"] = clampf(w * 0.14, 14.0, 130.0) if w < 200.0 else clampf(w * 0.32, 40.0, 150.0)
		state["foot_ry"] = 12.0 if w < 200.0 else 26.0
	var rx := float(state["foot_rx"])
	var ry := float(state["foot_ry"])
	return Rect2(feet.x - rx, feet.y - ry, rx * 2.0, ry * 2.0)

func _add_world_rect(rect: Rect2, color: Color, z: int) -> ColorRect:
	var node := ColorRect.new()
	node.position = rect.position
	node.size = rect.size
	node.color = color
	node.z_index = z
	world.add_child(node)
	return node

func _draw_tiled_blob(path: String, center: Vector2, radius_x: float, radius_y: float, z: int, tile_size: int = 64, tint: Color = Color.WHITE) -> void:
	var textures := _tile_textures_for(path)
	if textures.is_empty():
		return
	var min_x := int(floor((center.x - radius_x) / tile_size)) * tile_size
	var max_x := int(ceil((center.x + radius_x) / tile_size)) * tile_size
	var min_y := int(floor((center.y - radius_y) / tile_size)) * tile_size
	var max_y := int(ceil((center.y + radius_y) / tile_size)) * tile_size
	for y in range(min_y, max_y + tile_size, tile_size):
		for x in range(min_x, max_x + tile_size, tile_size):
			var p := Vector2(x + tile_size * 0.5, y + tile_size * 0.5)
			var nx: float = (p.x - center.x) / maxf(1.0, radius_x)
			var ny: float = (p.y - center.y) / maxf(1.0, radius_y)
			var jitter := sin(float(x) * 0.021 + float(y) * 0.017) * 0.18
			if nx * nx + ny * ny <= 1.0 + jitter:
				var texture := textures[abs((x * 92821 + y * 68917)) % textures.size()] as Texture2D
				var sprite := Sprite2D.new()
				sprite.texture = texture
				sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
				sprite.position = p
				sprite.scale = Vector2(float(tile_size) / float(texture.get_width()), float(tile_size) / float(texture.get_height()))
				sprite.modulate = tint
				sprite.z_index = z
				world.add_child(sprite)

func _draw_path_points(path: String, points: Array, width: float, z: int) -> void:
	for i in range(points.size()):
		var point: Vector2 = points[i]
		_draw_tiled_blob(path, point, width * 0.62, width * 0.48, z)
		if i <= 0:
			continue
		var previous: Vector2 = points[i - 1]
		var distance := previous.distance_to(point)
		var steps: int = maxi(1, int(distance / 74.0))
		for s in range(1, steps + 1):
			var t := float(s) / float(steps + 1)
			var middle := previous.lerp(point, t)
			_draw_tiled_blob(path, middle, width * 0.50, width * 0.40, z)

func _draw_tiled_rect(path: String, rect: Rect2, tile_size: int, z: int) -> void:
	var textures := _tile_textures_for(path)
	if textures.is_empty():
		_add_world_rect(rect, Color("#303030"), z)
		return
	var cols := int(ceil(rect.size.x / float(tile_size)))
	var rows := int(ceil(rect.size.y / float(tile_size)))
	for y in range(rows):
		for x in range(cols):
			var texture := textures[abs((x * 92821 + y * 68917 + int(rect.position.x) + int(rect.position.y))) % textures.size()] as Texture2D
			var sprite := Sprite2D.new()
			sprite.texture = texture
			sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			sprite.position = rect.position + Vector2(x * tile_size + tile_size * 0.5, y * tile_size + tile_size * 0.5)
			sprite.scale = Vector2(float(tile_size) / float(texture.get_width()), float(tile_size) / float(texture.get_height()))
			sprite.z_index = z
			world.add_child(sprite)

func _tile_textures_for(path: String) -> Array:
	var variants := []
	match path:
		"res://assets/sprites/tile_grass.png":
			variants = ["res://assets/sprites/tile_grass_01.png", "res://assets/sprites/tile_grass_02.png", "res://assets/sprites/tile_grass_03.png", "res://assets/sprites/tile_grass_04.png"]
		"res://assets/sprites/tile_path.png":
			variants = ["res://assets/sprites/tile_path_01.png", "res://assets/sprites/tile_path_02.png", "res://assets/sprites/tile_path_03.png"]
		"res://assets/sprites/tile_water.png":
			variants = ["res://assets/sprites/tile_water_01.png", "res://assets/sprites/tile_water_02.png"]
		"res://assets/sprites/tile_stone.png":
			variants = ["res://assets/sprites/tile_stone_01.png", "res://assets/sprites/tile_stone_02.png"]
		"res://assets/sprites/tile_ruin.png":
			variants = ["res://assets/sprites/tile_ruin_01.png", "res://assets/sprites/tile_ruin_02.png"]
		"res://assets/sprites/tile_cave_floor.png":
			variants = ["res://assets/sprites/tile_cave_floor_01.png", "res://assets/sprites/tile_cave_floor_02.png"]
		"res://assets/sprites/tile_arcane.png":
			variants = ["res://assets/sprites/tile_arcane_01.png", "res://assets/sprites/tile_arcane_02.png"]
		"res://assets/sprites/tile_sand.png":
			variants = ["res://assets/sprites/tile_sand_01.png"]
		_:
			variants = [path]
	var result := []
	for variant_path in variants:
		var texture := load(str(variant_path)) as Texture2D
		if texture != null:
			result.append(texture)
	return result

func _spawn_ground_details() -> void:
	match current_map:
		"city_eldoria":
			if _eldoria_background_available():
				return
			_scatter_detail(["res://assets/sprites/decor_flower_patch.png", "res://assets/sprites/decor_grass_tuft.png", "res://assets/sprites/decor_leaf_patch.png"], 42, 0.62)
			_spawn_city_visual_props()
		"city_valdoria":
			if _valdoria_background_available():
				return
			_scatter_detail(["res://assets/sprites/decor_flower_patch.png", "res://assets/sprites/decor_grass_tuft.png", "res://assets/sprites/decor_leaf_patch.png"], 42, 0.62)
			_spawn_city_visual_props()
		"forest_boars":
			# Floresta v2: decoracao vem pronta de data/forest_kit.json.
			return
		"highland_pass":
			_scatter_detail(["res://assets/sprites/decor_bush.png", "res://assets/sprites/decor_flower_patch.png", "res://assets/sprites/decor_grass_tuft.png", "res://assets/sprites/decor_rock.png", "res://assets/sprites/decor_leaf_patch.png", "res://assets/sprites/decor_stump.png"], 92, 0.78)
			_scatter_detail(["res://assets/sprites/decor_dirt_blend.png", "res://assets/sprites/decor_path_edge_grass.png"], 26, 0.9)
		"bat_cave", "crystal_mines":
			_scatter_detail(["res://assets/sprites/decor_rock.png", "res://assets/sprites/decor_stalagmite.png", "res://assets/sprites/decor_crystal.png"], 42, 0.72)
		"arcane_ruins":
			_scatter_detail(["res://assets/sprites/decor_crystal.png", "res://assets/sprites/decor_rock.png", "res://assets/sprites/decor_grass_tuft.png"], 46, 0.72)
		"ember_fortress":
			_scatter_detail(["res://assets/sprites/decor_rock.png", "res://assets/sprites/decor_fence.png"], 36, 0.74)

func _scatter_detail(paths: Array, count: int, scale_base: float) -> void:
	if paths.is_empty():
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = abs(current_map.hash()) + count * 97
	for i in range(count):
		var pos := Vector2(rng.randf_range(120, current_map_size.x - 120), rng.randf_range(140, current_map_size.y - 120))
		if _is_point_in_safe_zone(pos):
			continue
		var path := str(paths[rng.randi_range(0, paths.size() - 1)])
		var sprite := _add_world_sprite(path, pos, scale_base * rng.randf_range(0.82, 1.18), -89)
		sprite.modulate = Color(1, 1, 1, rng.randf_range(0.88, 1.0))

func _spawn_city_visual_props() -> void:
	if current_map == "city_eldoria":
		return
	elif current_map == "city_valdoria":
		if _valdoria_background_available():
			return
		for p in [Vector2(590, 695), Vector2(660, 690), Vector2(1350, 700), Vector2(1430, 700)]:
			_add_world_sprite("res://assets/sprites/decor_crate.png", p, 0.95, -8)
		for p in [Vector2(1520, 965), Vector2(1610, 965), Vector2(1690, 960)]:
			_add_world_sprite("res://assets/sprites/decor_barrel.png", p, 0.9, -8)
		for p in [Vector2(735, 915), Vector2(840, 920)]:
			_add_world_sprite("res://assets/sprites/decor_healer_shrine.png", p, 0.9, -8)
		for p in [Vector2(520, 480), Vector2(1260, 500), Vector2(1540, 760), Vector2(1700, 760)]:
			_add_world_sprite("res://assets/sprites/decor_torch.png", p, 0.9, -8)

func _add_world_label(text: String, pos: Vector2, color: Color = Color.WHITE) -> Label:
	var label := Label.new()
	label.text = text
	label.position = pos
	label.z_index = 60
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color.BLACK)
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	world.add_child(label)
	return label

func _eldoria_active_npc_list() -> Array:
	var result: Array = []
	for npc_id in ELDORIA_ACTIVE_NPCS:
		var location: Dictionary = ELDORIA_FUTURE_NPC_LOCATIONS.get(npc_id, {})
		if location.is_empty():
			continue
		var active: Dictionary = ELDORIA_ACTIVE_NPCS[npc_id]
		var world_pos: Vector2 = Vector2(location.get("source_pos", Vector2.ZERO)) * ELDORIA_WORLD_SCALE
		world_pos += Vector2(active.get("world_offset", Vector2.ZERO))
		# Eldoria v2: posicao vem do kit (na frente da casa de cada NPC).
		var kit_pos: Array = _get_eldoria_kit_data().get("npcs", {}).get(npc_id, [])
		if kit_pos.size() >= 2:
			world_pos = Vector2(float(kit_pos[0]), float(kit_pos[1]))
		result.append({
			"id": npc_id,
			"name": str(location.get("name", "NPC")),
			"role": str(active.get("role", "")),
			"sprite": str(active.get("sprite", "")),
			"greeting": str(active.get("greeting", "")),
			"pos": [world_pos.x, world_pos.y]
		})
	return result

# Liberacoes do mundo (ex.: rota de barco Eldoria <-> Valdoria) ficam em quest_system.completed
# como "flag:<id>", assim entram no save local sem mudar o formato do arquivo.
func _has_world_flag(flag: String) -> bool:
	return flag.is_empty() or (quest_system != null and quest_system.completed.has("flag:" + flag))

func _set_world_flag(flag: String) -> void:
	if quest_system == null or flag.is_empty() or _has_world_flag(flag):
		return
	quest_system.completed.append("flag:" + flag)
	if player != null and not online_mode:
		SaveSystem.save_game(player, quest_system, current_map, exploration_by_map, mmo_cache)

# Portal com "requires_flag" so aparece depois da liberacao; only_flag cria so os dessa liberacao.
func _spawn_portals(map_data: Dictionary, only_flag: String = "") -> void:
	# Eldoria antiga (base em reconstrucao) ficava sem portal; a v2 tem o da ilhota.
	if current_map == "city_eldoria" and _get_eldoria_kit_data().is_empty():
		return
	for portal_data in map_data.get("portals", []):
		var portal_flag := str(portal_data.get("requires_flag", ""))
		if not only_flag.is_empty() and portal_flag != only_flag:
			continue
		# Fase de testes (PORTALS_FREE_ACCESS): portais de rota (ex.: Eldoria <-> Valdoria) ja aparecem.
		if not PORTALS_FREE_ACCESS and not _has_world_flag(portal_flag):
			continue
		var portal_label_text := str(portal_data.get("label", "Portal"))
		var requires_boss := bool(portal_data.get("requires_boss_clear", false)) and not PORTALS_FREE_ACCESS
		if requires_boss:
			portal_label_text += " *"
		var portal := Area2D.new()
		var portal_ref := portal
		portal.add_to_group("portals")
		portal_nodes.append(portal)
		portal.collision_layer = 0
		portal.collision_mask = 1
		portal.monitoring = true
		portal.monitorable = false
		portal.set_meta("target", _resolve_map_id(str(portal_data.get("target", FOREST_PRIMARY_MAP_ID))))
		portal.set_meta("label", portal_label_text)
		portal.set_meta("requires_boss_clear", requires_boss)
		portal.set_meta("boss_enemy", str(portal_data.get("boss_enemy", "")))
		portal.set_meta("target_spawn", portal_data.get("spawn", []))
		portal.add_to_group("portals")
		var shape := CollisionShape2D.new()
		var rect_shape := RectangleShape2D.new()
		var is_eldoria_premium_portal := current_map == "city_eldoria" and _eldoria_background_available()
		var is_forest_portal := current_map == "forest_boars"
		rect_shape.size = Vector2(150, 230) if is_eldoria_premium_portal else Vector2(130, 200)
		shape.shape = rect_shape
		portal.add_child(shape)
		var pos: Array = portal_data.get("pos", [100, 100])
		portal.global_position = _map_data_point(pos)
		_spawn_portal_v2_visual(portal.global_position, str(portal.get_meta("target")))
		var passage_rect := Rect2(portal.global_position - Vector2(90, 120), Vector2(180, 240))
		if is_eldoria_premium_portal:
			passage_rect = Rect2(portal.global_position - Vector2(110, 145), Vector2(220, 290))
		elif is_forest_portal:
			passage_rect = Rect2(portal.global_position - Vector2(120, 150), Vector2(240, 300))
		portal_passage_rects.append(passage_rect)
		world.add_child(portal)
		portal.body_entered.connect(func(body: Node) -> void:
			if body == player:
				selected_portal = portal_ref
				_flash("OK: entrar em " + str(portal_ref.get_meta("label", "Portal")))
		)
		portal.body_exited.connect(func(body: Node) -> void:
			if body == player and selected_portal == portal_ref:
				selected_portal = null
		)

func _portal_v2_theme(target: String) -> String:
	match target:
		FOREST_PRIMARY_MAP_ID, FOREST_COMPAT_MAP_ID:
			return "floresta"
		"bat_cave", "crystal_mines":
			return "caverna"
	return "ruina"

# Camadas soltas no world (y-sort): base e magia no chao, aura de tras logo atras
# dos pes de quem pisa no circulo e aura da frente logo a frente.
func _spawn_portal_v2_visual(feet: Vector2, target: String) -> void:
	var theme := _portal_v2_theme(target)
	for layer in [["base", -98, 0.0], ["magia", -97, 0.0], ["aura_tras", 1, -2.0], ["aura_frente", 1, 110.0]]:
		var texture := load("%s/%s/%s.png" % [PORTAL_V2_ROOT, theme, str(layer[0])]) as Texture2D
		if texture == null:
			continue
		var sprite := Sprite2D.new()
		sprite.name = "Portal_%s_%s" % [theme, str(layer[0])]
		sprite.texture = texture
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.centered = false
		sprite.scale = Vector2.ONE * PORTAL_V2_SCALE
		var sort_dy := float(layer[2])
		sprite.position = feet + Vector2(0, sort_dy)
		sprite.offset = -PORTAL_V2_ANCHOR - Vector2(0, sort_dy / PORTAL_V2_SCALE)
		if int(layer[1]) < 0:
			sprite.z_index = int(layer[1])
		else:
			sprite.z_index = clampi(int(sprite.position.y), -1024, 1024)
		world.add_child(sprite)
		# Animacao so por opacidade (nao girar: o circulo e um chao em perspectiva).
		var low := 0.7 if layer[0] == "magia" else 0.55
		var period := 1.5 if layer[0] == "magia" else 2.0
		if layer[0] != "base":
			sprite.modulate.a = low
			var tween := sprite.create_tween().set_loops()
			tween.tween_property(sprite, "modulate:a", 1.0, period * 0.5).set_trans(Tween.TRANS_SINE)
			tween.tween_property(sprite, "modulate:a", low, period * 0.5).set_trans(Tween.TRANS_SINE)

func _spawn_safe_zones(map_data: Dictionary) -> void:
	if bool(map_data.get("safe", false)):
		return
	for zone_data in map_data.get("safe_zones", []):
		var pos_arr: Array = zone_data.get("pos", [0, 0])
		var radius: float = _map_data_radius(float(zone_data.get("radius", 120)))
		var center := _map_data_point(pos_arr)
		safe_zone_nodes.append({"center": center, "radius": radius})
		if current_map == "bat_cave":
			continue
		var ring := Line2D.new()
		ring.width = 3.0
		ring.default_color = Color(0.24, 0.95, 0.42, 0.52)
		ring.closed = true
		ring.z_index = -20
		for i in range(56):
			var angle := TAU * float(i) / 56.0
			ring.add_point(Vector2(cos(angle), sin(angle)) * radius)
		ring.global_position = center
		world.add_child(ring)
		_add_world_label("Zona Segura", center + Vector2(-48, -radius - 18), Color("#8dff9f"))

func _is_point_in_safe_zone(pos: Vector2) -> bool:
	for zone in safe_zone_nodes:
		var center: Vector2 = zone.get("center", Vector2.ZERO)
		var radius: float = float(zone.get("radius", 0.0))
		if pos.distance_to(center) <= radius:
			return true
	return false

func _draw_world_map_preview(canvas: Control, map_id: String, map_size: Vector2, canvas_size: Vector2) -> void:
	var origin := Vector2(5, 5)
	match map_id:
		"city_eldoria":
			var eldoria_preview_path := ELDORIA_CHUNKED_MINIMAP_PATH if ELDORIA_REBUILD_BASE_ONLY else ELDORIA_MINIMAP_PATH
			if ResourceLoader.exists(eldoria_preview_path):
				var texture := load(eldoria_preview_path) as Texture2D
				if texture != null:
					var preview := TextureRect.new()
					preview.texture = texture
					preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
					preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
					preview.stretch_mode = TextureRect.STRETCH_SCALE
					preview.position = origin
					preview.size = canvas_size
					preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
					canvas.add_child(preview)
					return
			_map_preview_rect(canvas, map_size, canvas_size, Rect2(0, 0, map_size.x, map_size.y), Color("#4a7d4f"), origin)
		"forest_boars":
			if _use_forest_image_minimap():
				var texture := load(FOREST_MINIMAP_PATH) as Texture2D
				if texture != null:
					var preview := TextureRect.new()
					preview.texture = texture
					preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
					preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
					preview.stretch_mode = TextureRect.STRETCH_SCALE
					preview.position = origin
					preview.size = canvas_size
					preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
					canvas.add_child(preview)
					return
			_map_preview_rect(canvas, map_size, canvas_size, Rect2(0, 0, map_size.x, map_size.y), Color("#3f6f3e"), origin)
			_map_preview_rect(canvas, map_size, canvas_size, Rect2(0, 0, 255, map_size.y), Color("#2d5f9c"), origin)
			for point in _forest_main_path_points():
				_map_preview_rect(canvas, map_size, canvas_size, Rect2(point - Vector2(82, 64), Vector2(164, 128)), Color("#8a7a5d"), origin)
			_map_preview_rect(canvas, map_size, canvas_size, Rect2(980, 0, 420, 366), Color("#2d5030"), origin)
		"arcane_ruins":
			_map_preview_rect(canvas, map_size, canvas_size, Rect2(0, 0, map_size.x, map_size.y), Color("#474a76"), origin)
			_map_preview_rect(canvas, map_size, canvas_size, Rect2(350, 170, 1500, 920), Color("#6a6d93"), origin)
		"bat_cave":
			var cave_preview_path := str(_get_cave_kit_data().get("minimap", CAVE_MINIMAP_PATH))
			if ResourceLoader.exists(cave_preview_path):
				var texture := load(cave_preview_path) as Texture2D
				if texture != null:
					var preview := TextureRect.new()
					preview.texture = texture
					preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
					preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
					preview.stretch_mode = TextureRect.STRETCH_SCALE
					preview.position = origin
					preview.size = canvas_size
					preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
					canvas.add_child(preview)
					return
			_map_preview_rect(canvas, map_size, canvas_size, Rect2(0, 0, map_size.x, map_size.y), Color("#2b2f3f"), origin)
			_map_preview_rect(canvas, map_size, canvas_size, Rect2(240, 130, map_size.x - 480, map_size.y - 220), Color("#3c4152"), origin)
		"city_valdoria":
			var valdoria_preview_path := str(_get_valdoria_kit_data().get("minimap", ""))
			if not valdoria_preview_path.is_empty() and ResourceLoader.exists(valdoria_preview_path):
				var texture := load(valdoria_preview_path) as Texture2D
				if texture != null:
					var preview := TextureRect.new()
					preview.texture = texture
					preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
					preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
					preview.stretch_mode = TextureRect.STRETCH_SCALE
					preview.position = origin
					preview.size = canvas_size
					preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
					canvas.add_child(preview)
					return

func _map_preview_rect(canvas: Control, map_size: Vector2, canvas_size: Vector2, world_rect: Rect2, color: Color, origin: Vector2) -> void:
	var p := _map_canvas_pos(map_size, canvas_size, world_rect.position) + origin
	var sz := Vector2(world_rect.size.x * canvas_size.x / map_size.x, world_rect.size.y * canvas_size.y / map_size.y)
	var rect := ColorRect.new()
	rect.position = p
	rect.size = sz
	rect.color = color
	canvas.add_child(rect)

func _map_canvas_pos(map_size: Vector2, canvas_size: Vector2, world_pos: Vector2) -> Vector2:
	var x: float = clamp(world_pos.x / max(1.0, map_size.x), 0.0, 1.0)
	var y: float = clamp(world_pos.y / max(1.0, map_size.y), 0.0, 1.0)
	return Vector2(x * canvas_size.x, y * canvas_size.y)

func _ensure_map_exploration(map_id: String) -> Dictionary:
	if exploration_by_map.has(map_id):
		return exploration_by_map[map_id]
	var map_data: Dictionary = maps.get(map_id, {})
	var map_size_arr: Array = map_data.get("size", [2200, 1400])
	var w: int = int(ceil(float(map_size_arr[0]) / float(EXPLORATION_CELL)))
	var h: int = int(ceil(float(map_size_arr[1]) / float(EXPLORATION_CELL)))
	var data: Array = []
	data.resize(w * h)
	for i in range(data.size()):
		data[i] = 0
	var entry := {"w": w, "h": h, "data": data}
	exploration_by_map[map_id] = entry
	return entry

func _update_map_exploration() -> void:
	if player == null:
		return
	var last_pos: Vector2 = exploration_last_pos_by_map.get(current_map, Vector2.INF)
	if last_pos != Vector2.INF and player.global_position.distance_to(last_pos) < 18.0:
		return
	exploration_last_pos_by_map[current_map] = player.global_position
	if last_pos == Vector2.INF:
		return
	var exp: Dictionary = _ensure_map_exploration(current_map)
	var w: int = int(exp.get("w", 1))
	var h: int = int(exp.get("h", 1))
	var data: Array = exp.get("data", [])
	var cx: int = int(floor(player.global_position.x / float(EXPLORATION_CELL)))
	var cy: int = int(floor(player.global_position.y / float(EXPLORATION_CELL)))
	var reveal_radius := 2
	for y in range(cy - reveal_radius, cy + reveal_radius + 1):
		if y < 0 or y >= h:
			continue
		for x in range(cx - reveal_radius, cx + reveal_radius + 1):
			if x < 0 or x >= w:
				continue
			var idx := y * w + x
			if idx >= 0 and idx < data.size():
				data[idx] = 1
	exp["data"] = data
	exploration_by_map[current_map] = exp

func _apply_map_regen() -> void:
	var map_data: Dictionary = maps.get(current_map, {})
	if bool(map_data.get("safe", false)):
		var near_fountain: bool = player.global_position.distance_to(Vector2(2508, 2205)) < 110.0
		var amount := 8 if near_fountain else 3
		player.heal(amount)
		player.recover_mana(int(amount * (1.0 + player.mana_regen_pct)))
	elif player.in_safe_zone:
		player.heal(SAFE_ZONE_REGEN)
		player.recover_mana(int(SAFE_ZONE_REGEN * (1.0 + player.mana_regen_pct)))

func _update_safe_zone_state() -> void:
	if player == null:
		return
	var map_data: Dictionary = maps.get(current_map, {})
	player.in_safe_zone = bool(map_data.get("safe", false)) or _is_point_in_safe_zone(player.global_position)

func _ensure_player_camera() -> void:
	if player == null:
		return
	player_camera = player.get_node_or_null("PlayerCamera")
	if player_camera == null:
		player_camera = Camera2D.new()
		player_camera.name = "PlayerCamera"
		player.add_child(player_camera)
	player_camera.enabled = true
	player_camera.position_smoothing_enabled = false
	player_camera.position_smoothing_speed = 0.0
	player_camera.anchor_mode = Camera2D.ANCHOR_MODE_DRAG_CENTER
	_apply_camera_zoom()
	player_camera.make_current()

func _update_camera_limits() -> void:
	if player_camera == null:
		return
	player_camera.limit_left = 0
	player_camera.limit_top = 0
	player_camera.limit_right = int(current_map_size.x)
	player_camera.limit_bottom = int(current_map_size.y)

func _apply_camera_zoom() -> void:
	if player_camera == null:
		return
	var index := clampi(hud_zoom_index, 0, CAMERA_ZOOMS.size() - 1)
	var zoom_value := float(CAMERA_ZOOMS[index])
	player_camera.zoom = Vector2.ONE * zoom_value

func _minimap_pos(world_pos: Vector2) -> Vector2:
	return _minimap_local_pos(world_pos, true)

func _minimap_local_pos(world_pos: Vector2, clamp_edges: bool) -> Vector2:
	if minimap_canvas == null or player == null:
		return Vector2.ZERO
	if _uses_image_minimap():
		var map_rect := _active_image_minimap_rect()
		var pos := map_rect.position + Vector2(
			world_pos.x / maxf(current_map_size.x, 1.0) * map_rect.size.x,
			world_pos.y / maxf(current_map_size.y, 1.0) * map_rect.size.y
		)
		if clamp_edges:
			pos.x = clampf(pos.x, map_rect.position.x + 2.0, map_rect.end.x - 2.0)
			pos.y = clampf(pos.y, map_rect.position.y + 2.0, map_rect.end.y - 2.0)
		return pos
	var center := minimap_canvas.size * 0.5
	var view_scale: float = minf(minimap_canvas.size.x, minimap_canvas.size.y) / (MINIMAP_WORLD_RADIUS * 2.0)
	var delta := (world_pos - player.global_position) * view_scale
	var pos := center + delta
	if clamp_edges:
		pos.x = clampf(pos.x, 2.0, maxf(2.0, minimap_canvas.size.x - 2.0))
		pos.y = clampf(pos.y, 2.0, maxf(2.0, minimap_canvas.size.y - 2.0))
	return pos

func _is_world_pos_in_minimap(world_pos: Vector2) -> bool:
	if player == null:
		return false
	if _uses_image_minimap():
		return Rect2(Vector2.ZERO, current_map_size).has_point(world_pos)
	var delta := world_pos - player.global_position
	return absf(delta.x) <= MINIMAP_WORLD_RADIUS and absf(delta.y) <= MINIMAP_WORLD_RADIUS

func _add_minimap_dot(pos: Vector2, color: Color, size: float) -> void:
	var dot := Panel.new()
	var dot_size: float = maxf(2.0, size * hud_minimap_scale)
	dot.position = pos - Vector2(dot_size, dot_size)
	dot.size = Vector2(dot_size * 2.0, dot_size * 2.0)
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(int(dot_size))
	dot.add_theme_stylebox_override("panel", style)
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dot.z_index = 8
	minimap_canvas.add_child(dot)

func _add_minimap_player_marker() -> void:
	if minimap_canvas == null or player == null:
		return
	var center := _minimap_pos(player.global_position) if _uses_image_minimap() else minimap_canvas.size * 0.5
	var marker := Polygon2D.new()
	marker.polygon = PackedVector2Array([
		Vector2(0, -7),
		Vector2(6, 7),
		Vector2(0, 4),
		Vector2(-6, 7)
	])
	marker.color = Color("#9cff43")
	marker.position = center
	if player.velocity.length() > 5.0:
		marker.rotation = player.velocity.angle() + PI * 0.5
	marker.z_index = 5
	minimap_canvas.add_child(marker)
	_add_minimap_dot(center, Color("#e6ffd1"), 2.0)

func _use_eldoria_image_minimap() -> bool:
	if current_map != "city_eldoria":
		return false
	if ResourceLoader.exists(_eldoria_v2_minimap_path()):
		return true
	if ELDORIA_REBUILD_BASE_ONLY:
		return ResourceLoader.exists(ELDORIA_CHUNKED_MINIMAP_PATH)
	return ResourceLoader.exists(ELDORIA_MINIMAP_PATH)

func _use_valdoria_image_minimap() -> bool:
	if _valdoria_v2_active():
		return false
	return current_map == "city_valdoria" and ResourceLoader.exists(VALDORIA_MINIMAP_PATH)

func _use_forest_image_minimap() -> bool:
	var path := _kit_minimap_path()
	return not path.is_empty() and ResourceLoader.exists(path)

func _use_cave_image_minimap() -> bool:
	return current_map == "bat_cave" and ResourceLoader.exists(_cave_minimap_path())

func _uses_image_minimap() -> bool:
	return _use_eldoria_image_minimap() or _use_valdoria_image_minimap() or _use_forest_image_minimap() or _use_cave_image_minimap()

func _active_image_minimap_rect() -> Rect2:
	if _use_eldoria_image_minimap():
		return _eldoria_minimap_rect()
	if _use_valdoria_image_minimap():
		return _valdoria_minimap_rect()
	if _use_forest_image_minimap():
		if minimap_canvas == null:
			return Rect2()
		return Rect2(Vector2.ZERO, minimap_canvas.size)
	if _use_cave_image_minimap():
		if minimap_canvas == null:
			return Rect2()
		return Rect2(Vector2.ZERO, minimap_canvas.size)
	return Rect2()

func _eldoria_minimap_rect() -> Rect2:
	if minimap_canvas == null:
		return Rect2()
	var side := minf(minimap_canvas.size.x, minimap_canvas.size.y)
	var offset := (minimap_canvas.size - Vector2(side, side)) * 0.5
	return Rect2(offset, Vector2(side, side))

func _valdoria_minimap_rect() -> Rect2:
	if minimap_canvas == null:
		return Rect2()
	var side := minf(minimap_canvas.size.x, minimap_canvas.size.y)
	var offset := (minimap_canvas.size - Vector2(side, side)) * 0.5
	return Rect2(offset, Vector2(side, side))

func _eldoria_v2_minimap_path() -> String:
	return str(_get_eldoria_kit_data().get("minimap", ""))

func _add_eldoria_minimap_background() -> void:
	var minimap_path := ELDORIA_CHUNKED_MINIMAP_PATH if ELDORIA_REBUILD_BASE_ONLY else ELDORIA_MINIMAP_PATH
	if ResourceLoader.exists(_eldoria_v2_minimap_path()):
		minimap_path = _eldoria_v2_minimap_path()
	var texture := load(minimap_path) as Texture2D
	if texture == null:
		return
	var map_rect := _eldoria_minimap_rect()
	var preview := TextureRect.new()
	preview.texture = texture
	preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_SCALE
	preview.position = map_rect.position
	preview.size = map_rect.size
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview.z_index = 1
	minimap_canvas.add_child(preview)

func _add_valdoria_minimap_background() -> void:
	var texture := load(VALDORIA_MINIMAP_PATH) as Texture2D
	if texture == null:
		return
	var map_rect := _valdoria_minimap_rect()
	var preview := TextureRect.new()
	preview.texture = texture
	preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_SCALE
	preview.position = map_rect.position
	preview.size = map_rect.size
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview.z_index = 1
	minimap_canvas.add_child(preview)

# Minimapa em imagem dos mapas montados por kit (floresta v2, ruinas v2).
func _kit_minimap_path() -> String:
	if _is_forest_runtime_map():
		return FOREST_MINIMAP_PATH
	if current_map == "arcane_ruins":
		return str(_get_ruins_kit_data().get("minimap", ""))
	if _valdoria_v2_active():
		return str(_get_valdoria_kit_data().get("minimap", ""))
	if _swamp_v2_active():
		return str(_get_swamp_kit_data().get("minimap", ""))
	return ""

func _add_forest_minimap_background() -> void:
	var texture := load(_kit_minimap_path()) as Texture2D
	if texture == null:
		return
	var map_rect := Rect2(Vector2.ZERO, minimap_canvas.size)
	var preview := TextureRect.new()
	preview.texture = texture
	preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_SCALE
	preview.position = map_rect.position
	preview.size = map_rect.size
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview.z_index = 1
	minimap_canvas.add_child(preview)

func _add_cave_minimap_background() -> void:
	var texture := load(_cave_minimap_path()) as Texture2D
	if texture == null:
		return
	var map_rect := Rect2(Vector2.ZERO, minimap_canvas.size)
	var preview := TextureRect.new()
	preview.texture = texture
	preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_SCALE
	preview.position = map_rect.position
	preview.size = map_rect.size
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview.z_index = 1
	minimap_canvas.add_child(preview)

func _minimap_base_color() -> Color:
	match current_map:
		"city_eldoria", "city_valdoria":
			return Color("#3f6d49")
		"forest_boars", "highland_pass":
			return Color("#315f35")
		"bat_cave", "crystal_depths":
			return Color("#202638")
		"arcane_ruins", "ancient_library":
			return Color("#393c62")
		"obsidian_keep":
			return Color("#272329")
	return Color("#182028")

func _add_minimap_terrain() -> void:
	match current_map:
		"city_eldoria":
			if _use_eldoria_image_minimap():
				return
			var center := current_map_size * 0.5
			_add_minimap_rect(Rect2(center.x - 164, 260, 328, current_map_size.y - 410), Color("#766d60"))
			_add_minimap_rect(Rect2(390, center.y - 132, current_map_size.x - 780, 264), Color("#766d60"))
			_add_minimap_rect(Rect2(310, 230, current_map_size.x - 620, current_map_size.y - 430), Color(0.38, 0.43, 0.47, 0.45))
		"city_valdoria":
			if _use_valdoria_image_minimap():
				return
			var center := current_map_size * 0.5
			_add_minimap_rect(Rect2(center.x - 164, 260, 328, current_map_size.y - 410), Color("#766d60"))
			_add_minimap_rect(Rect2(390, center.y - 132, current_map_size.x - 780, 264), Color("#766d60"))
			_add_minimap_rect(Rect2(310, 230, current_map_size.x - 620, current_map_size.y - 430), Color(0.38, 0.43, 0.47, 0.45))
		"forest_boars", "highland_pass":
			_add_minimap_rect(Rect2(0, 0, 255, current_map_size.y), Color("#25578a"))
			_add_minimap_rect(Rect2(235, 0, 70, current_map_size.y), Color("#9a865f"))
			for point in _forest_main_path_points():
				_add_minimap_rect(Rect2(point - Vector2(90, 70), Vector2(180, 140)), Color("#7e6e55"))
		"bat_cave", "crystal_depths":
			if _use_cave_image_minimap():
				return
			_add_minimap_rect(Rect2(240, 130, current_map_size.x - 480, current_map_size.y - 220), Color("#383d4d"))
		"arcane_ruins", "ancient_library":
			_add_minimap_rect(Rect2(320, 160, current_map_size.x - 640, current_map_size.y - 280), Color("#5b5e86"))
		"obsidian_keep":
			_add_minimap_rect(Rect2(250, 150, current_map_size.x - 500, current_map_size.y - 260), Color("#3b3038"))

func _add_minimap_obstacles() -> void:
	if player == null:
		return
	var view_rect := Rect2(player.global_position - Vector2.ONE * MINIMAP_WORLD_RADIUS, Vector2.ONE * MINIMAP_WORLD_RADIUS * 2.0)
	var drawn := 0
	for obstacle in solid_obstacles:
		if drawn >= 150:
			break
		var world_rect := _obstacle_world_rect(obstacle)
		if world_rect.size.x <= 0.0 or world_rect.size.y <= 0.0:
			continue
		if not world_rect.intersects(view_rect):
			continue
		_add_minimap_rect(world_rect, Color(0.02, 0.025, 0.02, 0.58))
		drawn += 1

func _add_minimap_rect(world_rect: Rect2, color: Color) -> void:
	if minimap_canvas == null:
		return
	var p := _minimap_local_pos(world_rect.position, false)
	var bottom_right := _minimap_local_pos(world_rect.position + world_rect.size, false)
	var rect := ColorRect.new()
	rect.position = p
	rect.size = (bottom_right - p).abs()
	if rect.size.x < 1.0:
		rect.size.x = 1.0
	if rect.size.y < 1.0:
		rect.size.y = 1.0
	rect.color = color
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.z_index = 2
	minimap_canvas.add_child(rect)
