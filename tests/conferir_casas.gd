extends Node
# Confere o esbarrao das casas (Eldoria e Valdoria): procura lugares onde o heroi consegue ficar
#  - ATRAS da casa: pes acima da linha da base (desenhado por tras) com o corpo em cima do desenho;
#  - DENTRO da base: pes encostados na linha da base (a casa ainda nao bloqueou).
# Acima do telhado (atras de chamine/fumaca) nao conta.
# So conta lugares alcancaveis a partir de fora (preenchimento a partir da borda da regiao).
#
# uso: godot --headless --path . res://tests/conferir_casas.tscn -- --offline-test
# Saida: "CASA <mapa> <nome> atras=N cima=M exemplo=(x,y)" e "CASAS_PROBLEMAS total".

const KITS := {"city_eldoria": "res://data/eldoria_kit.json", "city_valdoria": "res://data/valdoria_kit.json"}
const PASSO := 8.0
const CORPO := Vector2(36, 90)  # largura e altura do heroi acima dos pes
var main: Node = null
var total := 0


func _ready() -> void:
	var tree := get_tree()
	tree.set_meta("launcher_auto_start_offline", true)
	tree.set_meta("launcher_auto_class", "Guerreiro")
	main = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child.call_deferred(main)
	while not is_instance_valid(main) or main.get("player") == null:
		await tree.create_timer(0.25).timeout
	await tree.create_timer(1.0).timeout
	for map_id in KITS.keys():
		main.call("_load_map", map_id, Vector2.ZERO)
		await tree.create_timer(1.5).timeout
		var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(KITS[map_id]))
		for prop in data.get("props", []):
			var t := str(prop.get("texture", ""))
			if "/houses/" in t or "/buildings/" in t:
				_conferir(map_id, prop)
		_alcance(map_id)
	print("CASAS_PROBLEMAS %d" % total)
	tree.quit(0)


func _conferir(map_id: String, prop: Dictionary) -> void:
	var tex := load(str(prop["texture"])) as Texture2D
	var img := tex.get_image()
	if img.is_compressed():
		img.decompress()
	var s := float(prop.get("scale", 1.0))
	var pos := Vector2(float(prop["pos"][0]), float(prop["pos"][1]))
	var off := Vector2(float(prop["offset"][0]), float(prop["offset"][1]))
	var flip := bool(prop.get("flip_h", false))
	var used := Rect2(img.get_used_rect())
	# retangulo do desenho no mundo
	var a := pos + (off + used.position) * s
	var b := pos + (off + used.end) * s
	if flip:
		var ax := pos.x - (off.x + used.end.x) * s
		var bx := pos.x - (off.x + used.position.x) * s
		a.x = ax
		b.x = bx
	var regiao := Rect2(a, b - a).grow(120.0)
	var linha := pos.y + float(prop.get("base", 0.0))  # linha de ordem de desenho da casa
	var cols := int(regiao.size.x / PASSO)
	var rows := int(regiao.size.y / PASSO)
	var livre := PackedByteArray()
	livre.resize(cols * rows)
	for r in rows:
		for c in cols:
			var p := regiao.position + Vector2(c, r) * PASSO
			livre[r * cols + c] = 0 if bool(main.call("_is_point_blocked", p)) else 1
	# alcancavel a partir da borda
	var visto := PackedByteArray()
	visto.resize(cols * rows)
	var fila: Array = []
	for c in cols:
		for r in [0, rows - 1]:
			if livre[r * cols + c] == 1:
				fila.append(r * cols + c)
	for r in rows:
		for c in [0, cols - 1]:
			if livre[r * cols + c] == 1:
				fila.append(r * cols + c)
	for i in fila:
		visto[i] = 1
	var k := 0
	while k < fila.size():
		var i: int = fila[k]
		k += 1
		var r := i / cols
		var c := i % cols
		for d in [[1, 0], [-1, 0], [0, 1], [0, -1]]:
			var rr: int = r + d[1]
			var cc: int = c + d[0]
			if rr < 0 or cc < 0 or rr >= rows or cc >= cols:
				continue
			var j := rr * cols + cc
			if livre[j] == 1 and visto[j] == 0:
				visto[j] = 1
				fila.append(j)
	var atras := 0
	var cima := 0
	var exemplo := Vector2.ZERO
	for i in fila:
		var p := regiao.position + Vector2(i % cols, i / cols) * PASSO
		var corpo: Array = prop.get("corpo", [])
		if corpo.size() >= 4 and p.y < pos.y + float(corpo[1]):
			continue  # acima do telhado: so passa atras de chamine/fumaca, tudo bem
		if p.y < linha:
			# corpo do heroi coberto pelo desenho?
			var cobre := 0
			var amostras := 0
			for yy in range(0, int(CORPO.y), 15):
				for xx in range(-int(CORPO.x / 2), int(CORPO.x / 2) + 1, 12):
					amostras += 1
					if _opaco(img, p + Vector2(xx, -yy), pos, off, s, flip):
						cobre += 1
			if cobre * 2 > amostras:
				atras += 1
				exemplo = p
		elif p.y < pos.y + float(prop.get("base", 0.0)) + 4.0 and corpo.size() >= 4 and p.x > pos.x + float(corpo[0]) and p.x < pos.x + float(corpo[0]) + float(corpo[2]):
			cima += 1  # pes na faixa da base: nao deveria dar para ficar aqui
			if exemplo == Vector2.ZERO:
				exemplo = p
	if atras + cima > 0:
		total += 1
	print("CASA %s %s atras=%d cima=%d exemplo=(%d,%d)" % [map_id, str(prop.get("name", "")), atras, cima, exemplo.x, exemplo.y])


func _opaco(img: Image, p: Vector2, pos: Vector2, off: Vector2, s: float, flip: bool) -> bool:
	var local := (p - pos) / s
	if flip:
		local.x = -local.x
	var t := local - off
	var x := int(t.x)
	var y := int(t.y)
	if x < 0 or y < 0 or x >= img.get_width() or y >= img.get_height():
		return false
	return img.get_pixel(x, y).a > 0.5


# Tudo que importa (NPCs, portais, saida do mapa) continua alcancavel a partir do ponto de chegada?
func _alcance(map_id: String) -> void:
	var size: Vector2 = main.get("current_map_size")
	var passo := 24.0
	var cols := int(size.x / passo)
	var rows := int(size.y / passo)
	var visto := PackedByteArray()
	visto.resize(cols * rows)
	var inicio: Vector2 = (main.get("player") as Node2D).global_position
	var i0 := int(inicio.y / passo) * cols + int(inicio.x / passo)
	var fila: Array = [i0]
	visto[i0] = 1
	var k := 0
	while k < fila.size():
		var i: int = fila[k]
		k += 1
		var r := i / cols
		var c := i % cols
		for d in [[1, 0], [-1, 0], [0, 1], [0, -1]]:
			var rr: int = r + d[1]
			var cc: int = c + d[0]
			if rr < 0 or cc < 0 or rr >= rows or cc >= cols:
				continue
			var j := rr * cols + cc
			if visto[j] == 0:
				visto[j] = 2
				if not bool(main.call("_is_point_blocked", Vector2(cc, rr) * passo)):
					visto[j] = 1
					fila.append(j)
	var alvos: Array = []
	for n in get_tree().get_nodes_in_group("npcs"):
		alvos.append([str(n.get("npc_name")), (n as Node2D).global_position + Vector2(0, 40)])
	for pr in main.get("portal_passage_rects"):
		alvos.append(["portal", (pr as Rect2).get_center()])
	for alvo in alvos:
		var p: Vector2 = alvo[1]
		var ok := false
		for dy in range(-4, 5):
			for dx in range(-4, 5):
				var c := int(p.x / passo) + dx
				var r := int(p.y / passo) + dy
				if c >= 0 and r >= 0 and c < cols and r < rows and visto[r * cols + c] == 1:
					ok = true
		if not ok:
			total += 1
		print("ALCANCE %s %s %s (%d,%d)" % [map_id, "ok" if ok else "FALHOU", alvo[0], p.x, p.y])
