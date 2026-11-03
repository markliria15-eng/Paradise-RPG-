extends SceneTree

# Confere os status do Rei Javali carregado no jogo, a furia e os tempos de respawn.

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main._start_new_game("Guerreiro")
	await process_frame
	main._load_map("forest_boars")
	await process_frame
	for enemy in main.get_tree().get_nodes_in_group("enemies"):
		if enemy.boss:
			print("chefe ", enemy.enemy_name, " vida=", enemy.vida_max, " ataque=", enemy.ataque, " defesa=", enemy.defesa, " furioso=", enemy._is_enraged())
			enemy.vida = int(enemy.vida_max * 0.3)
			print("  com 30% de vida furioso=", enemy._is_enraged())
	var seen := {}
	for spawn in main.maps["forest_boars"].get("spawns", []):
		var name := str(spawn.get("enemy", ""))
		if not seen.has(name):
			seen[name] = main._enemy_respawn_delay(name, spawn)
	for name in seen:
		print("respawn ", name, ": ", seen[name], "s")
	quit()
