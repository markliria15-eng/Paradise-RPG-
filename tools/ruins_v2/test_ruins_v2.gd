extends SceneTree

# Teste headless das Ruinas Arcanas v2: carrega o mapa, confere spawn, portal,
# mobs/chefe e se da para andar do spawn ate cada area (BFS com a colisao do jogo).
# Uso: Godot --headless -s res://tools/ruins_v2/test_ruins_v2.gd

const STEP := 32.0

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main._start_new_game("Guerreiro")
	await process_frame
	main._load_map("arcane_ruins")
	await process_frame
	var p = main.player
	print("mapa=", main.current_map, " tamanho=", main.current_map_size, " kit=", main._ruins_v2_active(), " mascara=", main.forest_walk_image != null)
	print("spawn=", p.global_position, " bloqueado=", main._is_point_blocked(p.global_position), " solidos=", main.solid_obstacles.size())
	var water_nodes := 0
	for child in main.world.get_children():
		if child is Sprite2D and child.texture != null and child.texture.resource_path.find("magic_water") >= 0:
			water_nodes += 1
	print("chunks=", main.world.get_node_or_null("RuinsV2Chunks") != null, " agua=", water_nodes, " minimapa=", main._use_forest_image_minimap())
	for portal in main.get_tree().get_nodes_in_group("portals"):
		print("portal ", portal.get_meta("label"), " -> ", portal.get_meta("target"), " em ", portal.global_position)
	var counts := {}
	for enemy in main.get_tree().get_nodes_in_group("enemies"):
		counts[enemy.enemy_name] = int(counts.get(enemy.enemy_name, 0)) + 1
	print("mobs=", counts)
	var targets := {
		"portal": Vector2(3600, 5230), "praca": Vector2(3600, 2700), "biblioteca": Vector2(1290, 2900),
		"cristais": Vector2(5900, 2650), "lago_margem": Vector2(2380, 1500), "santuario_selo": Vector2(3600, 1350),
		"trono": Vector2(3600, 760), "clareira_oeste": Vector2(1500, 4300), "clareira_leste": Vector2(5600, 4150),
	}
	var reach := _flood(main, p.global_position)
	for name in targets:
		var t: Vector2 = targets[name]
		var key := Vector2i(roundi(t.x / STEP), roundi(t.y / STEP))
		var ok := false
		for dx in range(-3, 4):
			for dy in range(-3, 4):
				if reach.has(key + Vector2i(dx, dy)):
					ok = true
		print("alcanca ", name, " ", t, ": ", ok)
	var water_hit: bool = main._is_point_blocked(Vector2(1750, 1150))
	print("lago bloqueia=", water_hit, " mata fechada bloqueia=", main._is_point_blocked(Vector2(400, 400)), " celulas=", reach.size())
	quit()

func _flood(main, start: Vector2) -> Dictionary:
	var seen := {}
	var s := Vector2i(roundi(start.x / STEP), roundi(start.y / STEP))
	var queue: Array[Vector2i] = [s]
	seen[s] = true
	while not queue.is_empty():
		var c: Vector2i = queue.pop_back()
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = c + d
			if seen.has(n) or main._is_point_blocked(Vector2(n) * STEP):
				continue
			seen[n] = true
			queue.append(n)
	return seen
