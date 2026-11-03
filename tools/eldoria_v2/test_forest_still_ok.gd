extends SceneTree

# Confere que a floresta v2 continua carregando props e colisoes depois de
# _spawn_kit_prop ter virado funcao compartilhada com Eldoria v2.

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
	var sprites := 0
	for child in main.world.get_children():
		if child is Sprite2D:
			sprites += 1
	for portal in main.get_tree().get_nodes_in_group("portals"):
		print("portal ", portal.get_meta("label"), " -> ", portal.get_meta("target"), " chefe=", portal.get_meta("requires_boss_clear"))
	var layers := 0
	var torches := 0
	for child in main.world.get_children():
		if str(child.name).begins_with("Portal_"):
			layers += 1
		if child is AnimatedSprite2D:
			torches += 1
	print("camadas de portal=", layers, " props animados=", torches)
	for child in main.world.get_children():
		if child is Sprite2D and child.texture != null and child.texture.resource_path.find("portals_v2") >= 0:
			print("  camada ", child.name, " z=", child.z_index, " pos=", child.position)
	print("floresta spawn=", main.player.global_position, " bloqueado=", main._is_point_blocked(main.player.global_position), " solidos=", main.solid_obstacles.size(), " sprites=", sprites, " inimigos=", main.get_tree().get_nodes_in_group("enemies").size())
	quit()
