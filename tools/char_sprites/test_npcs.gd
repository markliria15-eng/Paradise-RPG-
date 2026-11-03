extends SceneTree

# Teste headless dos NPCs com a arte nova (tira _idle_4f_256).
# Uso: Godot --headless -s res://tools/char_sprites/test_npcs.gd

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var scene := load("res://scenes/npc.tscn") as PackedScene
	for role in ["healer", "class_master", "forge", "shop", "quest"]:
		var npc = scene.instantiate()
		root.add_child(npc)
		npc.setup({"name": role, "role": role})
		var frames := []
		for i in 7:
			npc._process(0.23)
			frames.append(npc.sprite.frame)
		print(role, " tex=", npc.sprite.texture.resource_path.get_file(), " hd=", npc._hd, " scale=", npc.sprite.scale, " pos=", npc.sprite.position, " offset=", npc.sprite.offset, " frames=", frames)
		npc.queue_free()
	quit()
