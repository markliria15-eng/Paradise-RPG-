extends SceneTree

# Teste headless das animacoes do jogador (parado, andar, ataque, dano, morte).
# Uso: Godot --headless -s res://tools/char_sprites/test_player_anims.gd

var died_count := 0

func _init() -> void:
	_run.call_deferred()

func _tex(p) -> String:
	return p.sprite.texture.resource_path.get_file()

func _run() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	for cls in [OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "Guerreiro"]:
		main._start_new_game(cls)
		await process_frame
		var p = main.player
		died_count = 0
		if not p.died.is_connected(_on_died):
			p.died.connect(_on_died)
		print("== ", cls, " pack=", p._class_pack_base_path(cls), " scale=", p.sprite.scale, " pos=", p.sprite.position)
		var seen := []
		for i in 8:
			p._update_directional_sprite(Vector2.ZERO, 0.2)
			seen.append(_tex(p))
		print("idle: ", seen)
		seen = []
		for i in 4:
			p._update_directional_sprite(Vector2(1, 0), 0.11)
			seen.append(_tex(p))
		print("walk right: ", seen)
		p._play_action("attack")
		seen = []
		for i in 6:
			p._update_directional_sprite(Vector2.ZERO, 0.075)
			seen.append(_tex(p))
		print("attack: ", seen)
		p.receive_damage(3)
		seen = []
		for i in 5:
			p._update_directional_sprite(Vector2.ZERO, 0.07)
			seen.append(_tex(p))
		print("hurt: ", seen, " action=", p.action_anim)
		p.vida = 1
		p.shield_points = 0
		p.receive_damage(999)
		print("apos golpe fatal: dying=", p.is_dying, " died=", died_count, " tex=", _tex(p))
		var t := 0.0
		while died_count == 0 and t < 3.0:
			p._update_directional_sprite(Vector2.ZERO, 0.1)
			t += 0.1
		print("died apos %.1fs: died=%d dying=%s vida=%d tex=%s" % [t, died_count, p.is_dying, p.vida, _tex(p)])
	quit()

func _on_died() -> void:
	died_count += 1
