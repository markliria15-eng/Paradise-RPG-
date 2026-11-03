extends SceneTree

# Teste headless da Eldoria v2: carrega o mapa e confere spawn, NPCs, portal e
# se da para andar do spawn ate cada um (BFS com a colisao do jogo).
# Uso: Godot --headless -s res://tools/eldoria_v2/test_eldoria_v2.gd

const STEP := 24.0

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main._start_new_game("Guerreiro")
	await process_frame
	main._load_map("city_eldoria")
	await process_frame
	var p = main.player
	print("mapa=", main.current_map, " tamanho=", main.current_map_size, " spawn=", p.global_position, " bloqueado=", main._is_point_blocked(p.global_position))
	print("chunks=", main.world.get_node_or_null("EldoriaV2Chunks") != null, " agua=", main.world.get_node_or_null("EldoriaWater") != null, " solidos=", main.solid_obstacles.size())
	for portal in main.get_tree().get_nodes_in_group("portals"):
		print("portal ", portal.get_meta("label"), " -> ", portal.get_meta("target"), " em ", portal.global_position)
	for npc in main.get_tree().get_nodes_in_group("npcs"):
		print("npc ", npc.npc_name, " em ", npc.global_position)
	var targets := {}
	for npc in main.get_tree().get_nodes_in_group("npcs"):
		targets[str(npc.npc_name)] = npc.global_position + Vector2(0, 60)
	var kit: Dictionary = main._get_eldoria_kit_data()
	targets["portal"] = Vector2(kit["portal"][0], kit["portal"][1]) + Vector2(0, -60)
	targets["volta_floresta"] = Vector2(kit["forest_return_spawn"][0], kit["forest_return_spawn"][1])
	targets["portao_dentro"] = Vector2(3600, 4900)
	targets["ponte"] = Vector2(3600, 5250)
	var reach := _flood(main, p.global_position)
	for name in targets:
		var t: Vector2 = targets[name]
		var key := Vector2i(roundi(t.x / STEP), roundi(t.y / STEP))
		var ok := false
		for dx in range(-2, 3):
			for dy in range(-2, 3):
				if reach.has(key + Vector2i(dx, dy)):
					ok = true
		print("alcanca ", name, " ", t, ": ", ok, " bloqueado=", main._is_point_blocked(t))
	# nada fora da muralha deve ser alcancavel (exceto ponte/ilhota)
	var leaks := 0
	for cell in reach.keys():
		var w: Vector2 = Vector2(cell) * STEP
		var inside := w.x > 560 and w.x < 6640 and w.y > 480 and w.y < 5040
		var south := w.x > 2950 and w.x < 4250 and w.y >= 5040
		if not inside and not south:
			leaks += 1
	print("celulas alcancaveis=", reach.size(), " vazamentos fora da muralha=", leaks)
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
			if seen.has(n):
				continue
			if main._is_point_blocked(Vector2(n) * STEP):
				continue
			seen[n] = true
			queue.append(n)
	return seen
