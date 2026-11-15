extends Node
# Teste automatico do Paradise RPG (Godot 4.6.3, sem janela).
#
# 1. Dados: missoes, NPCs, inimigos, itens, portais e sprites apontam para coisas que existem.
# 2. Jogo: entra no modo offline, abre os 5 mapas ativos e testa missao, montaria, pet e menus.
#    Qualquer erro de script ou de carregamento durante o teste conta como falha.
#
# uso (notebook): RODAR_TESTES.bat
#     godot --headless --path . res://tests/teste_automatico.tscn -- --offline-test [--so-dados]
# Saida: lista OK/FALHOU e codigo de saida 0 (tudo certo) ou 1 (algo falhou).
# O save do jogador (user://) e copiado antes e devolvido no fim, mesmo se o teste anterior caiu.

const MAPAS := ["city_eldoria", "forest_boars", "bat_cave", "arcane_ruins", "city_valdoria"]
const ARQUIVOS_DO_JOGADOR := ["user://arcadia_realms_save.json", "user://hud_layout.json"]
const PASTA_BACKUP := "user://_backup_teste_automatico"
const TEMPO_MAXIMO_S := 240.0

var falhas: Array = []
var avisos: Array = []
var oks := 0
var logger: Object = null
var main: Node = null
var terminou := false


class CapturaDeErros extends Logger:
	var trava := Mutex.new()
	var erros: Array = []
	var ignorar_ate_msec := 0

	func _log_error(function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		if error_type == ERROR_TYPE_WARNING:
			return
		var texto := "%s (%s:%d %s)" % [rationale if not rationale.is_empty() else code, file.get_file(), line, function]
		for bt in _script_backtraces:
			if bt != null and bt.get_frame_count() > 0:
				texto += " <- %s:%d %s" % [bt.get_frame_file(0).get_file(), bt.get_frame_line(0), bt.get_frame_function(0)]
				break
		trava.lock()
		erros.append(texto)
		trava.unlock()

	func _log_message(_message: String, _error: bool) -> void:
		pass

	func pegar() -> Array:
		trava.lock()
		var copia := erros.duplicate()
		erros.clear()
		trava.unlock()
		return copia


func _ready() -> void:
	print("\n================ TESTE AUTOMATICO DO PARADISE RPG ================")
	if ClassDB.class_exists("Logger"):
		logger = CapturaDeErros.new()
		OS.add_logger(logger)
	else:
		print("(aviso: esta versao do Godot nao deixa capturar erros; use a 4.6.3)")
	_devolver_backup_esquecido()
	_fazer_backup()
	get_tree().create_timer(TEMPO_MAXIMO_S).timeout.connect(func() -> void:
		_falha("o teste passou de %d s (travou?)" % int(TEMPO_MAXIMO_S))
		_terminar()
	)
	print("\n-- 1. Dados --")
	_testar_dados()
	_coletar_erros("dados")
	if OS.get_cmdline_user_args().has("--so-dados"):
		_terminar()
		return
	print("\n-- 2. Jogo (modo offline) --")
	await _testar_jogo()
	_terminar()


# ---------------------------------------------------------------- resultado
func _ok(texto: String) -> void:
	oks += 1
	print("  OK      ", texto)


func _falha(texto: String) -> void:
	falhas.append(texto)
	print("  FALHOU  ", texto)


func _aviso(texto: String) -> void:
	avisos.append(texto)
	print("  AVISO   ", texto)


func _checar(condicao: bool, texto: String) -> bool:
	if condicao:
		_ok(texto)
	else:
		_falha(texto)
	return condicao


func _coletar_erros(etapa: String) -> void:
	if logger == null:
		return
	var erros: Array = logger.pegar()
	if erros.is_empty():
		return
	var vistos := {}
	for e in erros:
		vistos[e] = int(vistos.get(e, 0)) + 1
	for e in vistos:
		_falha("erro em '%s': %s%s" % [etapa, e, "" if vistos[e] == 1 else " (x%d)" % vistos[e]])


func _terminar() -> void:
	if terminou:
		return
	terminou = true
	if main != null and is_instance_valid(main):
		main.queue_free()
		await get_tree().process_frame
		await get_tree().process_frame
	_devolver_backup()
	print("\n==================================================================")
	for a in avisos:
		print(" aviso (nao conta como falha): ", a)
	if falhas.is_empty():
		print(" RESULTADO: TUDO CERTO (%d verificacoes)" % oks)
	else:
		print(" RESULTADO: %d FALHA(S) de %d verificacoes" % [falhas.size(), oks + falhas.size()])
		for f in falhas:
			print("   - ", f)
	print("==================================================================\n")
	get_tree().quit(0 if falhas.is_empty() else 1)


# ---------------------------------------------------------------- save do jogador
func _fazer_backup() -> void:
	DirAccess.make_dir_recursive_absolute(PASTA_BACKUP)
	var lista := []
	for path in ARQUIVOS_DO_JOGADOR:
		if FileAccess.file_exists(path):
			DirAccess.copy_absolute(path, PASTA_BACKUP.path_join(path.get_file()))
			lista.append(path)
	var f := FileAccess.open(PASTA_BACKUP.path_join("lista.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(lista))
	f.close()


func _devolver_backup() -> void:
	var lista_path := PASTA_BACKUP.path_join("lista.json")
	if not FileAccess.file_exists(lista_path):
		return
	var lista: Variant = JSON.parse_string(FileAccess.get_file_as_string(lista_path))
	if typeof(lista) != TYPE_ARRAY:
		return
	for path in ARQUIVOS_DO_JOGADOR:
		var copia := PASTA_BACKUP.path_join(path.get_file())
		if (lista as Array).has(path) and FileAccess.file_exists(copia):
			DirAccess.copy_absolute(copia, path)
			DirAccess.remove_absolute(copia)
		elif FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)  # nao existia antes do teste
	DirAccess.remove_absolute(lista_path)
	DirAccess.remove_absolute(PASTA_BACKUP)
	print("(seu save foi devolvido como estava antes do teste)")


func _devolver_backup_esquecido() -> void:
	if FileAccess.file_exists(PASTA_BACKUP.path_join("lista.json")):
		print("(um teste anterior caiu no meio: devolvendo o save guardado)")
		_devolver_backup()


# ---------------------------------------------------------------- 1. dados
func _json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		_falha("arquivo nao existe: %s" % path)
		return null
	var text := FileAccess.get_file_as_string(path)
	if text.begins_with("﻿"):
		text = text.substr(1)
	var data: Variant = JSON.parse_string(text)
	if data == null:
		_falha("JSON invalido: %s" % path)
	return data


func _testar_dados() -> void:
	var maps: Dictionary = _json("res://data/maps.json")
	var quests: Dictionary = _json("res://data/quests.json")
	var enemies: Dictionary = _json("res://data/enemies.json")
	var items: Dictionary = _json("res://data/items.json")
	var rules: Variant = _json("res://data/game_rules.json")
	if maps == null or quests == null or enemies == null or items == null or rules == null:
		return
	_ok("JSONs principais abrem (maps, quests, enemies, items, game_rules)")

	var npc_names := {}
	var problemas: Array = []
	for map_id in MAPAS:
		if not maps.has(map_id):
			problemas.append("mapa %s sumiu do maps.json" % map_id)
			continue
		var m: Dictionary = maps[map_id]
		for npc in m.get("npcs", []):
			npc_names[str(npc.get("name", ""))] = map_id
			var sprite := str(npc.get("sprite", ""))
			if not sprite.is_empty() and not ResourceLoader.exists(sprite):
				problemas.append("sprite do NPC %s nao existe (%s)" % [npc.get("name"), sprite])
			if str(npc.get("role", "")) == "quest" and not quests.has(str(npc.get("quest", ""))):
				problemas.append("NPC %s da a missao %s, que nao existe" % [npc.get("name"), npc.get("quest")])
		for portal in m.get("portals", []):
			if not maps.has(str(portal.get("target", ""))):
				problemas.append("portal de %s leva para mapa inexistente %s" % [map_id, portal.get("target")])
		for spawn in m.get("spawns", []):
			if not enemies.has(str(spawn.get("enemy", ""))):
				problemas.append("%s cria inimigo inexistente %s" % [map_id, spawn.get("enemy")])
	_checar(problemas.is_empty(), "NPCs, portais e inimigos dos 5 mapas existem" + _resumo(problemas))

	problemas = []
	for enemy_name in enemies:
		for drop in enemies[enemy_name].get("drops", []):
			if not items.has(str(drop.get("item", ""))):
				problemas.append("%s solta item inexistente %s" % [enemy_name, drop.get("item")])
	_checar(problemas.is_empty(), "itens que os inimigos soltam existem" + _resumo(problemas))

	problemas = []
	for quest_id in quests:
		var q: Dictionary = quests[quest_id]
		if not npc_names.has(str(q.get("npc", ""))):
			_aviso("missao %s: o NPC %s nao esta em nenhum mapa (ninguem entrega essa missao)" % [quest_id, q.get("npc")])
		for o in q.get("objectives", []):
			var target := str(o.get("target", ""))
			var ok := true
			match str(o.get("type", "")):
				"kill": ok = enemies.has(target)
				"collect": ok = items.has(target)
				"visit": ok = maps.has(target)
				"talk": ok = npc_names.has(target)
				_: ok = false
			if not ok:
				problemas.append("%s: objetivo %s '%s' nao existe" % [quest_id, o.get("type"), target])
		for item_name in q.get("rewards", {}).get("items", []):
			if not items.has(str(item_name)):
				problemas.append("%s: recompensa %s nao existe" % [quest_id, item_name])
	_checar(problemas.is_empty(), "%d missoes apontam para NPCs, inimigos, itens e mapas reais" % quests.size() + _resumo(problemas))

	problemas = []
	for map_id in MAPAS:
		if not ResourceLoader.exists("res://assets/audio/ambiente/%s.ogg" % map_id):
			problemas.append("som ambiente de %s" % map_id)
	_checar(problemas.is_empty(), "som ambiente dos 5 mapas existe" + _resumo(problemas))

	problemas = []
	var bump: Dictionary = (rules as Dictionary).get("esbarrao", {})
	for npc_name in bump.get("npcs", {}):
		if not npc_names.has(str(npc_name)):
			problemas.append("falas de esbarrao para NPC inexistente %s" % npc_name)
	_checar(problemas.is_empty() and not bump.get("pedestres", []).is_empty(), "falas de esbarrao batem com os NPCs" + _resumo(problemas))


func _sim(v: bool) -> String:
	return "sim" if v else "NAO"


func _resumo(problemas: Array) -> String:
	if problemas.is_empty():
		return ""
	var txt := ": " + "; ".join(problemas.slice(0, 4))
	if problemas.size() > 4:
		txt += " (+%d)" % (problemas.size() - 4)
	return txt


# ---------------------------------------------------------------- 2. jogo
func _esperar(segundos: float) -> void:
	await get_tree().create_timer(segundos).timeout


func _testar_jogo() -> void:
	var tree := get_tree()
	tree.set_meta("launcher_auto_start_offline", true)
	tree.set_meta("launcher_auto_class", "Guerreiro")
	main = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child.call_deferred(main)
	var espera := 0.0
	while espera < 30.0 and (not is_instance_valid(main) or main.get("player") == null):
		await _esperar(0.25)
		espera += 0.25
	if not _checar(is_instance_valid(main) and main.get("player") != null, "o jogo abre e o heroi aparece (%.1f s)" % espera):
		return
	await _esperar(1.0)
	_coletar_erros("abrir o jogo")
	var player: Node2D = main.get("player")

	for map_id in MAPAS:
		main.call("_load_map", map_id, Vector2.ZERO)
		await _esperar(1.5)
		var pos := player.global_position
		var size: Vector2 = main.get("current_map_size")
		var dentro := pos.x > 0 and pos.y > 0 and pos.x < size.x and pos.y < size.y
		var livre := not bool(main.call("_is_point_blocked", pos))
		var npcs := 0
		for n in get_tree().get_nodes_in_group("npcs"):
			if n is Node2D and (n as Node2D).is_visible_in_tree():
				npcs += 1
		var esperado: int = (main.get("maps") as Dictionary).get(map_id, {}).get("npcs", []).size()
		_checar(str(main.get("current_map")) == map_id and dentro and livre and npcs >= esperado,
			"%s abre: heroi num lugar livre (%d, %d), %d/%d NPCs" % [map_id, pos.x, pos.y, npcs, esperado])
		# anda um pouco para a direita e para baixo (colisao e camera)
		Input.action_press("move_right")
		Input.action_press("move_down")
		await _esperar(0.8)
		Input.action_release("move_right")
		Input.action_release("move_down")
		await _esperar(0.2)
		_checar(not bool(main.call("_is_point_blocked", player.global_position)), "%s: andar nao deixa o heroi preso em parede" % map_id)
		_coletar_erros(map_id)

	# --- missao de Valdoria com recado (estamos em Valdoria) ---
	var qs: Object = main.get("quest_system")
	var qid := "valdoria_barco_danificado"
	qs.accept(qid)
	qs.register_collect("Madeira Bruta", 3)
	qs.register_collect("Carne Crua", 3)
	var antes: bool = qs.is_ready(qid)
	qs.register_talk("Varek, Mercador")
	_checar(not antes and qs.is_ready(qid), "missao com recado: so fica pronta depois de falar com o Varek")
	qs.complete(qid)
	_coletar_erros("missao")

	# --- montaria: compra, monta, anda e desce ao atacar (na Floresta: em cidade nao se ataca) ---
	main.call("_load_map", "forest_boars", Vector2.ZERO)
	await _esperar(1.5)
	player.set("ouro", 99999)
	main.call("_buy_local_mount", "brown_horse")
	if str(main.call("_current_equipped_mount_code")).is_empty():
		main.call("_toggle_mount")
	await _esperar(0.5)
	var montado := not str(main.call("_current_equipped_mount_code")).is_empty()
	var p0 := player.global_position
	Input.action_press("move_right")
	await _esperar(0.8)
	Input.action_release("move_right")
	var andou := player.global_position.distance_to(p0) > 20.0
	main.call("_player_attack", 1.0, 60.0, "")
	await _esperar(0.3)
	var desceu := str(main.call("_current_equipped_mount_code")).is_empty()
	_checar(montado and andou and desceu, "montaria: monta (%s), anda (%s) e desce ao atacar (%s)" % [_sim(montado), _sim(andou), _sim(desceu)])
	_coletar_erros("montaria")

	# --- pet ---
	main.call("_buy_local_pet", "mini_wolf")
	await _esperar(1.0)
	var pet: Variant = main.get("pet_follower")
	_checar(pet != null and is_instance_valid(pet) and (pet as Node2D).is_visible_in_tree(), "pet aparece seguindo o heroi (equipado: %s)" % str(main.call("_current_equipped_pet_code")))
	_coletar_erros("pet")

	# --- menus (Foto e Deslogar ficam de fora: escondem a tela / saem do jogo) ---
	var antes_menus := falhas.size()
	var itens := ["Habilidades", "Roupa", "Bolsa", "Mapa", "Missoes", "Pets", "Montarias", "Conquistas", "Diarias", "Colecao", "Eventos", "Configuracoes"]
	for item in itens:
		main.call("_handle_side_menu", item)
		await _esperar(0.3)
		main.call("_hide_panel")
		await _esperar(0.1)
	_coletar_erros("menus")
	if falhas.size() == antes_menus:
		_ok("%d menus abrem e fecham sem erro" % itens.size())

	# --- toque no botao MENU: um toque abre, outro fecha (sem abrir e fechar no mesmo toque) ---
	var botao: Control = main.get("side_menu_toggle_button")
	if botao != null and is_instance_valid(botao):
		if bool(main.get("side_menu_visible")):
			main.call("_toggle_side_menu")
		var espera_trava := 0.0
		while bool(main.call("_is_ui_locked")) and espera_trava < 3.0:  # trava curta depois de fechar painel
			await _esperar(0.1)
			espera_trava += 0.1
		var centro := botao.get_global_rect().get_center()
		await _tocar(centro)
		var abriu := bool(main.get("side_menu_visible"))
		await _tocar(centro)
		var fechou := not bool(main.get("side_menu_visible"))
		_checar(abriu and fechou, "toque no MENU: abre (%s) e fecha (%s) com um toque cada" % [_sim(abriu), _sim(fechou)])
		_coletar_erros("toque")


func _tocar(pos: Vector2) -> void:
	# o celular manda o toque e, logo atras, o clique de mouse "emulado" no mesmo lugar
	# (emulate_mouse_from_touch): os dois juntos devem contar como UM toque so
	for pressed in [true, false]:
		var touch := InputEventScreenTouch.new()
		touch.position = pos
		touch.pressed = pressed
		main.call("_input", touch)
		var mouse := InputEventMouseButton.new()
		mouse.button_index = MOUSE_BUTTON_LEFT
		mouse.position = pos
		mouse.pressed = pressed
		main.call("_input", mouse)
		await _esperar(0.1)
	await _esperar(0.4)
