extends Node
# Mede o peso de cada mapa: tempo para carregar, nos na cena, sprites desenhados, chamadas de
# desenho, memoria de textura e FPS com o heroi andando.
#
# uso (com tela; no PC basta rodar a cena):
#   godot --path . res://tests/medir_desempenho.tscn -- --offline-test
# Saida: linhas "DESEMPENHO <mapa> carga_ms=... nos=... draw=... tex_mb=... fps=..."

const MAPAS := ["city_eldoria", "forest_boars", "bat_cave", "arcane_ruins", "city_valdoria", "swamp_almas", "ember_fortress"]
var main: Node = null


func _ready() -> void:
	var tree := get_tree()
	tree.set_meta("launcher_auto_start_offline", true)
	tree.set_meta("launcher_auto_class", "Guerreiro")
	Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var t0 := Time.get_ticks_msec()
	main = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child.call_deferred(main)
	while not is_instance_valid(main) or main.get("player") == null:
		await tree.process_frame
	print("DESEMPENHO inicio carga_ms=%d" % (Time.get_ticks_msec() - t0))
	await tree.create_timer(1.0).timeout
	for map_id in MAPAS:
		var t := Time.get_ticks_usec()
		main.call("_load_map", map_id, Vector2.ZERO)
		var carga := (Time.get_ticks_usec() - t) / 1000.0
		# primeiro quadro desenhado (texturas sobem para a placa aqui)
		t = Time.get_ticks_usec()
		await tree.process_frame
		await tree.process_frame
		var primeiro := (Time.get_ticks_usec() - t) / 1000.0
		await tree.create_timer(1.0).timeout
		# anda em circulo por 4 s e mede o FPS
		var frames := 0
		var pior := 0.0
		var inicio := Time.get_ticks_usec()
		var ultimo := inicio
		Input.action_press("move_right")
		while Time.get_ticks_usec() - inicio < 4000000:
			await tree.process_frame
			var agora := Time.get_ticks_usec()
			pior = maxf(pior, (agora - ultimo) / 1000.0)
			ultimo = agora
			frames += 1
			var fase := int((agora - inicio) / 1000000)
			_dir(["move_right", "move_down", "move_left", "move_up"][fase % 4])
		_dir("")
		var fps := frames / ((Time.get_ticks_usec() - inicio) / 1000000.0)
		var visiveis := 0
		for n in main.find_children("*", "CanvasItem", true, false):
			if (n is Sprite2D or n is AnimatedSprite2D) and (n as CanvasItem).is_visible_in_tree():
				visiveis += 1
		print("DESEMPENHO %s carga_ms=%.0f primeiro_quadro_ms=%.0f nos=%d sprites_visiveis=%d draw=%d tex_mb=%.0f fps=%.0f pior_quadro_ms=%.0f" % [
			map_id, carga, primeiro,
			Performance.get_monitor(Performance.OBJECT_NODE_COUNT), visiveis,
			Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
			Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / 1048576.0,
			fps, pior])
	tree.quit(0)


func _dir(acao: String) -> void:
	for a in ["move_right", "move_down", "move_left", "move_up"]:
		if a == acao:
			Input.action_press(a)
		else:
			Input.action_release(a)
