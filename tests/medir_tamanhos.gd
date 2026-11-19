extends Node
# Mede o tamanho NA TELA (px de mundo, sem a borda transparente) de tudo que aparece em cada mapa:
# heroi, NPCs, pedestres/carrocas, inimigos, casas e objetos. Serve para conferir a regra de
# tamanhos (game_rules.json -> "tamanhos").
#
# uso: godot --headless --path . res://tests/medir_tamanhos.tscn -- --offline-test
# Saida: linhas "TAM <mapa> <categoria> <altura> <largura> <nome>" e o resumo no fim.

const MAPAS := ["city_eldoria", "forest_boars", "bat_cave", "arcane_ruins", "city_valdoria", "swamp_almas"]
var main: Node = null
static var _rects := {}


func _ready() -> void:
	var tree := get_tree()
	tree.set_meta("launcher_auto_start_offline", true)
	tree.set_meta("launcher_auto_class", "Guerreiro")
	main = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child.call_deferred(main)
	while not is_instance_valid(main) or main.get("player") == null:
		await tree.create_timer(0.25).timeout
	await tree.create_timer(1.0).timeout
	for map_id in MAPAS:
		main.call("_load_map", map_id, Vector2.ZERO)
		await tree.create_timer(2.0).timeout
		_medir(map_id)
	tree.quit(0)


static func visible_rect(tex: Texture2D) -> Rect2:
	if tex == null:
		return Rect2()
	var key := tex.resource_path if not tex.resource_path.is_empty() else str(tex.get_instance_id())
	if _rects.has(key):
		return _rects[key]
	var r := Rect2(Vector2.ZERO, tex.get_size())
	var img := tex.get_image()
	if img != null:
		if img.is_compressed():
			img.decompress()
		var u := img.get_used_rect()
		if u.size.x > 0:
			r = Rect2(u)
	_rects[key] = r
	return r


func _tex_of(node: CanvasItem) -> Texture2D:
	if node is Sprite2D:
		return (node as Sprite2D).texture
	if node is AnimatedSprite2D:
		var a := node as AnimatedSprite2D
		if a.sprite_frames != null and a.sprite_frames.has_animation(a.animation) and a.sprite_frames.get_frame_count(a.animation) > 0:
			return a.sprite_frames.get_frame_texture(a.animation, 0)
	return null


func _categoria(node: Node, tex: Texture2D) -> String:
	var p := tex.resource_path
	var n: Node = node
	while n != null and n != main:
		if n == main.get("player"):
			return "heroi"
		if n.is_in_group("npcs"):
			return "npc"
		if n.is_in_group("enemies"):
			return "chefe" if bool(n.get("boss")) else "inimigo"
		n = n.get_parent()
	if "/houses/" in p or "/buildings/" in p or "house" in p.get_file():
		return "casa"
	if "/anim/" in p and ("walk" in p or "move" in p or "rowing" in p or "fly" in p):
		return "pedestre"
	if "/anim/" in p and ("horse" in p or "seagull" in p or "cat" in p or "dog" in p):
		return "animal"
	if "chunk" in p or "/tiles/" in p or "shadow" in p:
		return ""
	return "objeto"


func _medir(map_id: String) -> void:
	var vistos := {}
	for node in main.find_children("*", "CanvasItem", true, false):
		if not (node is Sprite2D or node is AnimatedSprite2D) or not (node as CanvasItem).is_visible_in_tree():
			continue
		var tex := _tex_of(node)
		if tex == null:
			continue
		var cat := _categoria(node, tex)
		if cat.is_empty():
			continue
		var r := visible_rect(tex)
		var s := (node as Node2D).global_scale.abs()
		if node is Sprite2D and (node as Sprite2D).hframes > 1:
			r.size.x = tex.get_width() / float((node as Sprite2D).hframes)
		var nome := tex.resource_path.get_file()
		var owner_name := ""
		var n: Node = node
		while n != null and n != main:
			if n.get("npc_name") != null:
				owner_name = str(n.get("npc_name"))
				break
			if n.get("enemy_name") != null:
				owner_name = str(n.get("enemy_name"))
				break
			n = n.get_parent()
		if not owner_name.is_empty():
			nome = owner_name
		elif "/anim/" in tex.resource_path:
			nome = tex.resource_path.get_base_dir().get_file()
		var chave := "%s|%s" % [cat, nome]
		if vistos.has(chave):
			continue
		vistos[chave] = true
		print("TAM %s %s %.0f %.0f %s" % [map_id, cat, r.size.y * s.y, r.size.x * s.x, nome])
