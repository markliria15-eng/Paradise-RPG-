extends Node
class_name Profissoes
# Profissoes de verdade (offline/local, 2026-11-22). Dados em data/profissoes.json.
#  - 6 profissoes: Minerador, Lenhador, Herbalista (coleta) e Ferreiro, Alquimista, Cozinheiro (criacao),
#    todas liberadas, nivel 1..nivel_max, XP pelo uso.
#  - Pontos de coleta no mapa (maps.json -> gather_nodes): chegar perto, apertar E/OK, barra enche
#    (andar cancela), o recurso esgota e renasce depois. Nivel minimo por recurso.
#  - Bancadas nas cidades (maps.json -> gather_stations): mesa de alquimia e fogao.
#  - Criacao pelo Menu > Profissoes: fora da cidade so receitas "simples" (+ comida "media" com
#    Cozinheiro alto); na cidade ou na bancada, tudo. Armas/armaduras so na forja da cidade
#    (main_interface._show_forge pede o nivel de Ferreiro e da XP).
#  - Comida: cura aos poucos e bonus por alguns minutos (main._apply_companion_bonuses -> aplicar_bonus).
# Estado salvo em main.mmo_cache["profissoes"] e ["comida"] (vai junto no save local).

const DADOS := "res://data/profissoes.json"
const ALCANCE := 78.0          # distancia do heroi ao ponto para coletar
const ORDEM := ["mining", "woodcutting", "herbalism", "blacksmithing", "alchemy", "cooking"]

var main: Node
var dados: Dictionary = {}
var pontos: Array = []          # [{tipo, def, node, sprite, rotulo, mapa, idx}]
var esgotados: Dictionary = {}  # "mapa#idx" -> unix ate renascer (sobrevive a troca de mapa)
var alvo: Dictionary = {}       # ponto/estacao mais perto do heroi
var coletando: Dictionary = {}  # {ponto, t, dur, golpe}
var barra: ProgressBar
var regen_acc := 0.0
var checar_acc := 0.0
var bonus_ativo := false
const CELULA := 256.0           # grade espacial: so os pontos em volta do heroi sao checados
var grade: Dictionary = {}      # Vector2i -> [ponto]


func setup(owner_main: Node) -> void:
	main = owner_main
	dados = ItemDatabase.load_json(DADOS)
	_estado()
	bonus_ativo = _bonus_comida_ativo()


# ======================= estado / nivel / XP =======================
func _estado() -> Dictionary:
	var cache: Dictionary = main.mmo_cache
	if typeof(cache.get("profissoes")) != TYPE_DICTIONARY:
		cache["profissoes"] = {}
	var est: Dictionary = cache["profissoes"]
	for p in ORDEM:
		if typeof(est.get(p)) != TYPE_DICTIONARY:
			est[p] = {"nivel": 1, "xp": 0}
	return est


func nivel(prof: String) -> int:
	return int(_estado().get(prof, {}).get("nivel", 1))


func nome(prof: String) -> String:
	return str(dados.get("profissoes", {}).get(prof, {}).get("nome", prof))


# "Aprendiz de Ferreiro", "Minerador Experiente", "Herbalista Grao-Mestre"... (data -> ranks)
func rank(prof: String) -> String:
	var lv := nivel(prof)
	var modelo := "{p}"
	for r in dados.get("ranks", []):
		if lv >= int(r[0]):
			modelo = str(r[1])
	return modelo.replace("{p}", nome(prof))


func xp_para(n: int) -> int:
	return int(round(float(dados.get("xp_base", 60)) * pow(float(n), float(dados.get("xp_expoente", 1.35)))))


func ganhar_xp(prof: String, quanto: int) -> void:
	var est: Dictionary = _estado()[prof]
	var maximo := int(dados.get("nivel_max", 50))
	if int(est["nivel"]) >= maximo:
		return
	est["xp"] = int(est["xp"]) + quanto
	var subiu := false
	while int(est["nivel"]) < maximo and int(est["xp"]) >= xp_para(int(est["nivel"])):
		est["xp"] = int(est["xp"]) - xp_para(int(est["nivel"]))
		est["nivel"] = int(est["nivel"]) + 1
		subiu = true
	if int(est["nivel"]) >= maximo:
		est["xp"] = 0
	if subiu:
		AudioManager.play_sfx("nivel")
		main._flash("%s subiu para o nivel %d: %s!" % [nome(prof), int(est["nivel"]), rank(prof)])
		if prof == "blacksmithing" and int(est["nivel"]) >= int(dados.get("encantamento", {}).get("nivel_ferreiro", 50)):
			main._flash("Encantamento liberado! Use na forja da cidade.")


# ======================= pontos de coleta e bancadas =======================
func limpar() -> void:
	_cancelar()
	for p in pontos:
		if is_instance_valid(p["node"]):
			p["node"].queue_free()
	pontos.clear()
	grade.clear()
	alvo = {}


func carregar_mapa(map_id: String, map_data: Dictionary) -> void:
	limpar()
	var defs: Dictionary = dados.get("pontos", {})
	var lista: Array = map_data.get("gather_nodes", [])
	for i in lista.size():
		var e = lista[i]
		if typeof(e) != TYPE_DICTIONARY or not defs.has(str(e.get("tipo", ""))):
			continue
		var pos_data: Array = e.get("pos", [])
		if pos_data.size() < 2:
			continue
		_criar(map_id, i, str(e["tipo"]), defs[str(e["tipo"])], main._resolve_unblocked_spawn(main._map_data_point(pos_data)), false)
	var est_defs: Dictionary = dados.get("estacoes", {})
	var estacoes: Array = map_data.get("gather_stations", [])
	for i in estacoes.size():
		var e = estacoes[i]
		if typeof(e) != TYPE_DICTIONARY or not est_defs.has(str(e.get("tipo", ""))):
			continue
		var pos := _pos_estacao(e)
		if pos == Vector2.INF:
			continue
		_criar(map_id, 1000 + i, str(e["tipo"]), est_defs[str(e["tipo"])], pos, true)
		pontos[-1]["extra"] = e
	# toda arvore do mapa (props dos kits) pode ser cortada
	var arvores: Array = main.get("arvores_kit") if main.get("arvores_kit") != null else []
	for i in arvores.size():
		var a: Dictionary = arvores[i]
		if defs.has(str(a.get("tipo", ""))) and is_instance_valid(a.get("no")):
			_criar_arvore_kit(map_id, 5000 + i, str(a["tipo"]), defs[str(a["tipo"])], a)


# Arvore que ja faz parte do mapa: o desenho do kit fica; esgotada, some e da lugar ao toco/muda.
func _criar_arvore_kit(map_id: String, idx: int, tipo: String, def: Dictionary, a: Dictionary) -> void:
	var decor: Sprite2D = a["no"]
	var raiz := Node2D.new()
	raiz.name = "ArvoreKit_%d" % idx
	raiz.position = a["pos"]
	raiz.z_index = decor.z_index
	raiz.z_as_relative = false
	var toco := Sprite2D.new()
	toco.centered = false
	toco.visible = false
	raiz.add_child(toco)
	var altura := clampf(float(a.get("altura", 150.0)), 60.0, 420.0)
	var rotulo := Label.new()
	rotulo.visible = false
	rotulo.z_index = 60
	rotulo.z_as_relative = false
	rotulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rotulo.add_theme_font_size_override("font_size", 14)
	rotulo.add_theme_color_override("font_color", Color("#ffe8a3"))
	rotulo.add_theme_color_override("font_outline_color", Color.BLACK)
	rotulo.add_theme_constant_override("outline_size", 5)
	rotulo.size = Vector2(240, 22)
	rotulo.position = Vector2(-120, -minf(altura, 180.0) - 30)
	raiz.add_child(rotulo)
	main.world.add_child(raiz)
	var ponto := {"tipo": tipo, "def": def, "node": raiz, "sprite": toco, "rotulo": rotulo, "decor": decor,
		"altura": altura, "alcance": 1.6, "chave": "%s#%d" % [map_id, idx], "estacao": false}
	_guardar(ponto)
	_atualizar_visual(ponto)


func _guardar(ponto: Dictionary) -> void:
	pontos.append(ponto)
	var c := Vector2i(floori(ponto["node"].position.x / CELULA), floori(ponto["node"].position.y / CELULA))
	if not grade.has(c):
		grade[c] = []
	grade[c].append(ponto)


func _altura(ponto: Dictionary) -> float:
	return float(ponto.get("altura", ponto["def"].get("altura", 60)))


# o que treme/pula: a arvore do mapa (enquanto inteira) ou o sprite do ponto
func _visual(ponto: Dictionary) -> Node2D:
	if ponto.has("decor") and is_instance_valid(ponto["decor"]) and ponto["decor"].visible:
		return ponto["decor"]
	return ponto["sprite"]


# bancada: "pos" fixa ou ao lado de um NPC ("perto_npc" = comeco do nome, "offset" em px)
func _pos_estacao(e: Dictionary) -> Vector2:
	var off: Array = e.get("offset", [0, 0])
	var papel := str(e.get("perto_papel", ""))  # ao lado do NPC com esse papel (forge, rare_forge...)
	if not papel.is_empty():
		for npc in main.get_tree().get_nodes_in_group("npcs"):
			if str(npc.get("role")) == papel:
				return main._resolve_unblocked_spawn(npc.global_position + Vector2(float(off[0]), float(off[1])))
	var perto := str(e.get("perto_npc", ""))
	if not perto.is_empty():
		for npc in main.get_tree().get_nodes_in_group("npcs"):
			var nome_npc := str(npc.get("npc_name")) if npc.get("npc_name") != null else str(npc.name)
			if nome_npc.begins_with(perto):
				return main._resolve_unblocked_spawn(npc.global_position + Vector2(float(off[0]), float(off[1])))
	var pos_data: Array = e.get("pos", [])
	if pos_data.size() >= 2:
		return main._resolve_unblocked_spawn(main._map_data_point(pos_data))
	return Vector2.INF


func _criar(map_id: String, idx: int, tipo: String, def: Dictionary, posicao: Vector2, estacao: bool) -> void:
	var tex: Texture2D = load(str(def.get("sprite", ""))) if ResourceLoader.exists(str(def.get("sprite", ""))) else null
	if tex == null:
		return
	var raiz := Node2D.new()
	raiz.name = "Coleta_%s_%d" % [tipo, idx]
	raiz.position = posicao
	var sprite := Sprite2D.new()
	sprite.centered = false
	_por_textura(sprite, tex, float(def.get("altura", 60)))
	raiz.add_child(sprite)
	var rotulo := Label.new()
	rotulo.visible = false
	rotulo.z_index = 60
	rotulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rotulo.add_theme_font_size_override("font_size", 14)
	rotulo.add_theme_color_override("font_color", Color("#ffe8a3"))
	rotulo.add_theme_color_override("font_outline_color", Color.BLACK)
	rotulo.add_theme_constant_override("outline_size", 5)
	rotulo.size = Vector2(240, 22)
	rotulo.position = Vector2(-120, -float(def.get("altura", 60)) - 30)
	raiz.add_child(rotulo)
	main.world.add_child(raiz)
	var ponto := {"tipo": tipo, "def": def, "node": raiz, "sprite": sprite, "rotulo": rotulo,
		"chave": "%s#%d" % [map_id, idx], "estacao": estacao}
	_guardar(ponto)
	_atualizar_visual(ponto)


func _por_textura(sprite: Sprite2D, tex: Texture2D, altura: float) -> void:
	sprite.texture = tex
	var s := altura / maxf(1.0, float(tex.get_height()))
	sprite.scale = Vector2(s, s)
	sprite.offset = Vector2(-tex.get_width() / 2.0, -float(tex.get_height()))
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR


func _disponivel(ponto: Dictionary) -> bool:
	return bool(ponto["estacao"]) or _agora() >= float(esgotados.get(ponto["chave"], 0.0))


const MUDA := "res://assets/sprites/coleta/muda.png"

func _atualizar_visual(ponto: Dictionary) -> void:
	var def: Dictionary = ponto["def"]
	var cheio := _disponivel(ponto)
	if ponto.has("decor"):
		if is_instance_valid(ponto["decor"]):
			ponto["decor"].visible = cheio
		ponto["sprite"].visible = not cheio
		if cheio:
			return
	var caminho := str(def.get("sprite" if cheio else "esgotado", def.get("sprite", "")))
	var altura := float(def.get("altura", 60)) if not ponto.has("decor") else maxf(150.0, _altura(ponto) * 0.8)
	var prof := str(def.get("profissao", ""))
	if not cheio:
		altura *= 0.5 if prof != "woodcutting" else 0.42
		# crescendo de novo: toco -> muda que cresce (arvore); broto que cresce (erva)
		var falta := float(esgotados.get(ponto["chave"], 0.0)) - _agora()
		var progresso := clampf(1.0 - falta / maxf(1.0, float(def.get("renasce_s", 90))), 0.0, 1.0)
		if prof == "woodcutting" and progresso > 0.35 and ResourceLoader.exists(MUDA):
			caminho = MUDA
			altura = float(def.get("altura", 150)) * lerpf(0.28, 0.7, (progresso - 0.35) / 0.65)
		elif prof == "herbalism":
			altura *= lerpf(0.7, 1.5, progresso)
	if ResourceLoader.exists(caminho):
		_por_textura(ponto["sprite"], load(caminho), altura)
	ponto["sprite"].modulate = Color.WHITE if cheio else Color(0.88, 0.88, 0.88, 0.95)


func _agora() -> float:
	return Time.get_unix_time_from_system()


func _process(delta: float) -> void:
	var player = main.player
	if player == null or not is_instance_valid(player):
		return
	_regen_comida(delta)
	_copiar_sprite()
	checar_acc -= delta
	if checar_acc <= 0.0:
		checar_acc = 0.5
		for p in pontos:
			if not p["estacao"] and is_instance_valid(p["node"]):
				var antes := bool(p.get("cheio", true))
				var agora := _disponivel(p)
				if antes != agora or not agora:  # esgotado: atualiza o crescimento
					p["cheio"] = agora
					_atualizar_visual(p)
					if agora and not antes:
						_pulo(_visual(p))  # renasceu
		_atualizar_aura()
		if bonus_ativo and not _bonus_comida_ativo():
			bonus_ativo = false
			main._flash("O efeito da comida acabou.")
			main._apply_companion_bonuses()
	_animar_fogueira(delta)
	if not criando.is_empty():
		_atualizar_criacao(delta)
		return
	if not coletando.is_empty():
		_atualizar_coleta(delta)
		return
	_escolher_alvo(player.global_position)


func _escolher_alvo(heroi: Vector2) -> void:
	var melhor: Dictionary = {}
	var dist := 1.0
	var cel := Vector2i(floori(heroi.x / CELULA), floori(heroi.y / CELULA))
	var perto: Array = []
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			perto.append_array(grade.get(cel + Vector2i(dx, dy), []))
	for p in perto:
		if not is_instance_valid(p["node"]) or not _disponivel(p):
			continue
		# bancada e arvore grande do mapa alcancam um pouco mais longe
		var d: float = p["node"].global_position.distance_to(heroi) / (ALCANCE * _fator_alcance(p))
		if d < dist:
			melhor = p
			dist = d
	if not alvo.is_empty() and str(alvo.get("chave")) != str(melhor.get("chave", "")) and is_instance_valid(alvo["node"]):
		alvo["rotulo"].visible = false
	alvo = melhor
	if alvo.is_empty():
		return
	var def: Dictionary = alvo["def"]
	var prof := str(def.get("profissao", ""))
	var texto := ""
	if alvo["estacao"]:
		texto = "OK: %s" % str(def.get("nome", ""))
	else:
		var precisa := int(def.get("nivel", 1))
		var verbo := str(dados.get("profissoes", {}).get(prof, {}).get("verbo", "Coletar"))
		texto = "OK: %s %s" % [verbo, str(def.get("nome", ""))]
		if nivel(prof) < precisa:
			texto = "%s nivel %d" % [nome(prof), precisa]
	alvo["rotulo"].text = texto
	alvo["rotulo"].visible = true


func _fator_alcance(p: Dictionary) -> float:
	return float(p.get("alcance", 1.5 if p["estacao"] else 1.0))


# chamado por main._interact antes dos NPCs: true = usou o E/OK
func interagir() -> bool:
	if alvo.is_empty() or not coletando.is_empty() or main.player == null:
		return false
	if not is_instance_valid(alvo["node"]):
		alvo = {}
		return false
	if alvo["node"].global_position.distance_to(main.player.global_position) > ALCANCE * _fator_alcance(alvo):
		return false
	var def: Dictionary = alvo["def"]
	var prof := str(def.get("profissao", ""))
	if alvo["estacao"]:
		if str(alvo["tipo"]) == "bigorna":
			main._show_forge(str(alvo.get("extra", {}).get("forja", "basic")))
		else:
			mostrar(prof, true)
		return true
	var precisa := int(def.get("nivel", 1))
	if nivel(prof) < precisa:
		main._flash_red("Precisa de %s nivel %d (voce: %d)." % [nome(prof), precisa, nivel(prof)])
		return true
	var item := str(def.get("item", ""))
	var inv = main.player.inventory
	if not inv.items.has(item) and inv.items.size() >= inv.capacity():
		main._flash_red("Bolsa cheia.")
		return true
	var lv := nivel(prof)
	var dur := float(def.get("tempo_s", 2.5)) * maxf(float(dados.get("coleta", {}).get("tempo_min_pct", 0.6)), 1.0 - 0.015 * (lv - 1))
	coletando = {"ponto": alvo, "t": 0.0, "dur": dur, "golpe": 0.0, "pos": main.player.global_position}
	alvo["rotulo"].visible = false
	_mostrar_barra(true)
	_ligar_golpes()
	main.player.trabalhar({"mining": "picareta", "woodcutting": "machado"}.get(prof, "colher"), alvo["node"].global_position)
	return true


func _mostrar_barra(ver: bool) -> void:
	if barra == null or not is_instance_valid(barra):
		barra = ProgressBar.new()
		barra.show_percentage = false
		barra.custom_minimum_size = Vector2(70, 9)
		barra.size = Vector2(70, 9)
		barra.z_index = 61
		var fundo := StyleBoxFlat.new()
		fundo.bg_color = Color(0, 0, 0, 0.7)
		fundo.set_corner_radius_all(3)
		var cheio := StyleBoxFlat.new()
		cheio.bg_color = Color("#f0c24b")
		cheio.set_corner_radius_all(3)
		barra.add_theme_stylebox_override("background", fundo)
		barra.add_theme_stylebox_override("fill", cheio)
		main.world.add_child(barra)
	barra.visible = ver


func _cancelar() -> void:
	coletando = {}
	if barra != null and is_instance_valid(barra):
		barra.visible = false
	_texto_barra("")
	if main.player != null and is_instance_valid(main.player) and criando.is_empty():
		main.player.parar_trabalho()


func _atualizar_coleta(delta: float) -> void:
	var player = main.player
	var ponto: Dictionary = coletando["ponto"]
	if not is_instance_valid(ponto["node"]) or player.global_position.distance_to(coletando["pos"]) > 14.0 or player.vida <= 0:
		_cancelar()
		main._flash("Coleta cancelada.")
		return
	coletando["t"] = float(coletando["t"]) + delta
	barra.max_value = float(coletando["dur"])
	barra.value = float(coletando["t"])
	barra.global_position = player.global_position + Vector2(-35, -118)
	if float(coletando["t"]) >= float(coletando["dur"]):
		_terminar_coleta(ponto)


func _terminar_coleta(ponto: Dictionary) -> void:
	_cancelar()
	var def: Dictionary = ponto["def"]
	var prof := str(def.get("profissao", ""))
	var lv := nivel(prof)
	var faixa: Array = def.get("qtd", [1, 1])
	var qtd := randi_range(int(faixa[0]), int(faixa[faixa.size() - 1]))
	if randf() < 0.015 * (lv - 1):
		qtd += 1
	var inv = main.player.inventory
	var ganhos: Array[String] = []
	var item := str(def.get("item", ""))
	if inv.add_item(item, qtd):
		ganhos.append("%s x%d" % [item, qtd])
	for extra in def.get("extra", []):
		if typeof(extra) == TYPE_DICTIONARY and randf() < float(extra.get("chance", 0.0)) * (1.0 + 0.02 * (lv - 1)):
			if inv.add_item(str(extra.get("item", "")), 1):
				ganhos.append("%s x1" % str(extra.get("item", "")))
	# achados raros: quanto maior o nivel do coletor, maior a chance
	var achados: Dictionary = dados.get("achados", {})
	for a in achados.get(prof, []):
		if randf() < float(a.get("chance", 0.0)) * (1.0 + float(achados.get("por_nivel", 0.05)) * lv):
			if inv.add_item(str(a.get("item", "")), 1):
				ganhos.append("RARO! %s" % str(a.get("item", "")))
	if ganhos.is_empty():
		main._flash_red("Bolsa cheia.")
		return
	_final_coleta(ponto)  # arvore tomba, rocha quebra, erva sai do chao
	esgotados[ponto["chave"]] = _agora() + float(def.get("renasce_s", 90))
	ponto["cheio"] = false
	_atualizar_visual(ponto)
	AudioManager.play_sfx("moeda", 0.8, 0.2)
	var xp := int(def.get("xp", 10))
	main._flash("+%s  (+%d XP %s)" % [", ".join(ganhos), xp, nome(prof)])
	ganhar_xp(prof, xp)
	if main.game_extras != null:
		main.game_extras.daily_progress("collect", 1, item)


# ======================= criacao (alquimia / culinaria) =======================
func na_cidade() -> bool:
	return str(main.current_map) in dados.get("cidades", [])


func _permitida(receita: Dictionary, na_bancada: bool) -> String:
	# "" = pode criar aqui; senao o motivo
	if na_bancada or na_cidade():
		return ""
	var tipo := str(receita.get("nivel_receita", "simples"))
	if tipo == "simples":
		return ""
	if tipo == "media" and str(receita.get("profissao", "")) == "cooking" \
			and nivel("cooking") >= int(dados.get("cozinha_media_fora_da_cidade_nivel", 15)):
		return ""
	return "so na cidade"


func _tem_materiais(materiais: Dictionary) -> bool:
	for m in materiais.keys():
		if int(main.player.inventory.items.get(str(m), 0)) < int(materiais[m]):
			return false
	return true


func _texto_materiais(materiais: Dictionary) -> String:
	var partes: Array[String] = []
	for m in materiais.keys():
		partes.append("%s %d/%d" % [str(m), int(main.player.inventory.items.get(str(m), 0)), int(materiais[m])])
	return ", ".join(partes)


func criar(nome_receita: String, na_bancada: bool) -> bool:
	var receita: Dictionary = dados.get("receitas", {}).get(nome_receita, {})
	if receita.is_empty():
		return false
	var prof := str(receita.get("profissao", ""))
	if nivel(prof) < int(receita.get("nivel", 1)):
		main._flash_red("Precisa de %s nivel %d." % [nome(prof), int(receita.get("nivel", 1))])
		return false
	var motivo := _permitida(receita, na_bancada)
	if not motivo.is_empty():
		main._flash_red("%s: %s (bancada da cidade)." % [nome_receita, motivo])
		return false
	var materiais: Dictionary = receita.get("materiais", {})
	if not _tem_materiais(materiais):
		main._flash_red("Faltam materiais.")
		return false
	var inv = main.player.inventory
	if not inv.items.has(nome_receita) and inv.items.size() >= inv.capacity():
		main._flash_red("Bolsa cheia.")
		return false
	var xp := int(receita.get("xp", 10))
	if not tentar(prof, int(receita.get("nivel", 1))):
		perder_metade(materiais)
		AudioManager.play_sfx("dano", 0.7, 0.1)
		main._flash_red("Falhou: %s (perdeu metade dos materiais). +%d XP" % [nome_receita, falha_xp(xp)])
		aviso_item(nome_receita, false, "Perdeu metade dos materiais  +%d XP %s" % [falha_xp(xp), nome(prof)])
		ganhar_xp(prof, falha_xp(xp))
		return true
	for m in materiais.keys():
		inv.remove_item(str(m), int(materiais[m]))
	inv.add_item(nome_receita, 1)
	AudioManager.play_sfx("moeda", 1.1, 0.2)
	main._flash("Criado: %s  (+%d XP %s)" % [nome_receita, xp, nome(prof)])
	aviso_item(nome_receita, true, "+%d XP %s" % [xp, nome(prof)])
	ganhar_xp(prof, xp)
	if main.has_method("_update_potion_buttons"):
		main._update_potion_buttons()
	return true


# ======================= cenas das profissoes =======================
# Coleta: o heroi trabalha (picareta / machado / agachado) e cada golpe faz o ponto tremer e soltar
# lascas; no fim a arvore tomba, a rocha quebra e a erva sai do chao. Criacao: Alquimista moe ervas
# no pilao, Cozinheiro gira a carne numa fogueira, Ferreiro martela a espada na bigorna da cidade.
const FOGUEIRA := "res://assets/sprites/coleta/fogueira_espeto_6f.png"
const BIGORNA := "res://assets/sprites/coleta/bigorna.png"
const TRONCO_CAIDO := "res://assets/sprites/coleta/tronco_caido.png"
const DURACAO_CRIACAO := {"alchemy": 2.6, "cooking": 3.2, "blacksmithing": 3.0}
var criando: Dictionary = {}   # {prof, t, dur, ao_fim, pos, props: [Node2D], alvo}
var barra_txt: Label            # "Carne Assada  72%" em cima da barra enquanto cria
var aviso_camada: CanvasLayer   # cartao "Criado!/Falhou" no fim da criacao
var fogueiras: Array = []


func _ligar_golpes() -> void:
	var p = main.player
	if p != null and not p.golpe_trabalho.is_connected(_no_golpe):
		p.golpe_trabalho.connect(_no_golpe)


func _no_golpe() -> void:
	if not coletando.is_empty():
		var ponto: Dictionary = coletando["ponto"]
		if not is_instance_valid(ponto["node"]):
			return
		var prof := str(ponto["def"].get("profissao", ""))
		var cor: Color = {"mining": Color("#9aa0a8"), "woodcutting": Color("#b07a44")}.get(prof, Color("#6fd35c"))
		var altura := minf(_altura(ponto), 160.0)
		var onde: Vector2 = ponto["node"].global_position + Vector2(0, -altura * (0.35 if prof == "woodcutting" else 0.4))
		_tremer(_visual(ponto), 4.0 if prof != "herbalism" else 2.0)
		_lascas(onde, cor, 10 if prof != "herbalism" else 6, 90.0)
		if prof == "mining":
			_lascas(onde, Color("#ffd27a"), 5, 140.0, 0.25)  # faisca da picareta
		AudioManager.play_sfx("golpe", 0.55 if prof != "herbalism" else 1.3, 0.15)
	elif not criando.is_empty():
		var prof2 := str(criando["prof"])
		var alvo: Vector2 = criando["alvo"]
		if prof2 == "blacksmithing":
			_lascas(alvo + Vector2(0, -46), Color("#ffb347"), 14, 170.0, 0.35)
			_lascas(alvo + Vector2(0, -46), Color("#fff1a8"), 6, 120.0, 0.2)
			AudioManager.play_sfx("golpe", 1.4, 0.1)
		elif prof2 == "alchemy":
			_lascas(alvo + Vector2(0, -12), Color("#7ee06a"), 5, 50.0, 0.5)
			_lascas(alvo + Vector2(0, -12), Color("#c98cff"), 2, 40.0, 0.6)


func _tremer(no: Node2D, forca: float) -> void:
	if no == null or not is_instance_valid(no):
		return
	var base_x := float(no.get_meta("x0", no.position.x))
	no.set_meta("x0", base_x)
	var tw := no.create_tween()
	tw.tween_property(no, "position:x", base_x + forca, 0.04)
	tw.tween_property(no, "position:x", base_x - forca, 0.06)
	tw.tween_property(no, "position:x", base_x, 0.05)


func _pulo(no: Node2D) -> void:
	if no == null or not is_instance_valid(no):
		return
	var esc: Vector2 = no.scale
	no.scale = esc * 0.6
	no.create_tween().tween_property(no, "scale", esc, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _lascas(onde: Vector2, cor: Color, quantos: int, vel: float, vida: float = 0.6) -> void:
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.emitting = false
	p.amount = maxi(1, quantos)
	p.lifetime = vida
	p.explosiveness = 0.95
	p.direction = Vector2(0, -1)
	p.spread = 70.0
	p.gravity = Vector2(0, 420)
	p.initial_velocity_min = vel * 0.5
	p.initial_velocity_max = vel
	p.scale_amount_min = 2.0
	p.scale_amount_max = 4.0
	p.color = cor
	p.z_index = 40
	p.global_position = onde
	main.world.add_child(p)
	p.emitting = true
	get_tree().create_timer(vida + 0.3).timeout.connect(p.queue_free)


func _final_coleta(ponto: Dictionary) -> void:
	var prof := str(ponto["def"].get("profissao", ""))
	var no: Node2D = ponto["node"]
	var altura := minf(_altura(ponto), 200.0)
	if prof == "woodcutting":
		# a arvore tomba para o lado contrario do heroi, bate no chao e vira tronco caido
		var arvore := Sprite2D.new()
		var spr: Sprite2D = _visual(ponto)
		arvore.texture = spr.texture
		arvore.centered = false
		arvore.offset = spr.offset
		arvore.scale = spr.scale
		arvore.flip_h = spr.flip_h
		arvore.texture_filter = spr.texture_filter
		arvore.global_position = no.global_position
		arvore.z_index = 2 if not ponto.has("decor") else no.z_index
		arvore.z_as_relative = not ponto.has("decor")
		main.world.add_child(arvore)
		var lado := 1.0 if main.player.global_position.x < no.global_position.x else -1.0
		var tw := arvore.create_tween()
		tw.tween_property(arvore, "rotation", lado * PI * 0.5, 0.75).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_callback(func() -> void:
			_lascas(no.global_position + Vector2(lado * altura * 0.6, -6), Color("#c9b48a"), 16, 110.0, 0.7)
			AudioManager.play_sfx("golpe", 0.35, 0.05)
			if ResourceLoader.exists(TRONCO_CAIDO):
				var tronco: Texture2D = load(TRONCO_CAIDO)
				arvore.rotation = 0.0
				arvore.texture = tronco
				var s := altura * 0.95 / float(tronco.get_width())
				arvore.scale = Vector2(s, s)
				arvore.flip_h = lado < 0.0
				arvore.offset = Vector2(-tronco.get_width() / 2.0 + lado * tronco.get_width() * 0.35, -float(tronco.get_height()))
		)
		tw.tween_interval(1.6)
		tw.tween_property(arvore, "modulate:a", 0.0, 0.6)
		tw.tween_callback(arvore.queue_free)
	elif prof == "mining":
		_lascas(no.global_position + Vector2(0, -altura * 0.4), Color("#9aa0a8"), 22, 200.0, 0.8)
		_lascas(no.global_position + Vector2(0, -altura * 0.4), Color(str(ponto["def"].get("cor", "#c9a27a"))), 8, 150.0, 0.7)
		AudioManager.play_sfx("golpe", 0.4, 0.05)
	else:
		_lascas(no.global_position + Vector2(0, -altura * 0.5), Color("#7ee06a"), 12, 120.0, 0.7)
	main.player.parar_trabalho()


# ----- criacao com cena -----
# item/pct: o que esta sendo feito e a chance de dar certo (aparece em cima da barra)
func animar_criacao(prof: String, ao_fim: Callable, item: String = "", pct: float = -1.0) -> void:
	var player = main.player
	if player == null or not criando.is_empty() or not coletando.is_empty():
		return
	main._hide_panel()
	var lado := -1.0 if player.current_sprite_direction == "left" else 1.0
	var props: Array = []
	var alvo: Vector2 = player.global_position + Vector2(lado * 34.0, 4.0)
	if prof == "blacksmithing":
		# vai ate a bigorna da cidade (ao lado do ferreiro); sem bigorna perto, uma aparece na frente
		var bigorna: Dictionary = {}
		for p in pontos:
			if str(p["tipo"]) == "bigorna" and is_instance_valid(p["node"]) and p["node"].global_position.distance_to(player.global_position) < 900.0:
				bigorna = p
		if bigorna.is_empty():
			alvo = player.global_position + Vector2(lado * 70.0, 0.0)
			props.append(_prop(BIGORNA, alvo, 80.0))
		else:
			alvo = bigorna["node"].global_position
			player.global_position = main._resolve_unblocked_spawn(alvo + Vector2(72.0, 2.0))
			player.velocity = Vector2.ZERO
	elif prof == "cooking":
		alvo = player.global_position + Vector2(lado * 72.0, 2.0)
		if _ocupado(alvo):  # toco/arvore/rocha na frente: a fogueira vai do outro lado
			lado = -lado
			alvo = player.global_position + Vector2(lado * 72.0, 2.0)
		var fogo := _prop(FOGUEIRA, alvo, 78.0, 6)
		props.append(fogo)
		fogueiras.append(fogo)
		var fumaca := CPUParticles2D.new()
		fumaca.amount = 10
		fumaca.lifetime = 1.6
		fumaca.direction = Vector2(0, -1)
		fumaca.spread = 15.0
		fumaca.gravity = Vector2(0, -25)
		fumaca.initial_velocity_min = 12.0
		fumaca.initial_velocity_max = 26.0
		fumaca.scale_amount_min = 4.0
		fumaca.scale_amount_max = 8.0
		fumaca.color = Color(0.8, 0.8, 0.8, 0.35)
		fumaca.position = Vector2(0, -70)
		fogo.add_child(fumaca)
	_mostrar_barra(true)
	_texto_barra("%s  %d%%" % [item, int(round(pct * 100))] if not item.is_empty() and pct >= 0.0 else item, pct)
	_ligar_golpes()
	criando = {"prof": prof, "t": 0.0, "dur": float(DURACAO_CRIACAO.get(prof, 2.5)), "ao_fim": ao_fim,
		"pos": player.global_position, "props": props, "alvo": alvo}
	player.trabalhar({"blacksmithing": "martelo", "alchemy": "moer"}.get(prof, "cozinhar"), alvo)


func _ocupado(onde: Vector2) -> bool:
	if main._is_point_blocked(onde):
		return true
	var cel := Vector2i(floori(onde.x / CELULA), floori(onde.y / CELULA))
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			for p in grade.get(cel + Vector2i(dx, dy), []):
				if is_instance_valid(p["node"]) and p["node"].global_position.distance_to(onde) < 70.0:
					return true
	return false


func _prop(caminho: String, onde: Vector2, altura: float, quadros: int = 1) -> Node2D:
	var no := Node2D.new()
	no.global_position = onde
	var spr := Sprite2D.new()
	spr.name = "Sprite"
	var tex: Texture2D = load(caminho)
	spr.texture = tex
	spr.hframes = quadros
	spr.centered = false
	var w := tex.get_width() / float(quadros)
	var s := altura / float(tex.get_height())
	spr.scale = Vector2(s, s)
	spr.offset = Vector2(-w / 2.0, -float(tex.get_height()))
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	no.add_child(spr)
	main.world.add_child(no)
	_pulo(no)
	return no


func _animar_fogueira(delta: float) -> void:
	for f in fogueiras.duplicate():
		if not is_instance_valid(f):
			fogueiras.erase(f)
			continue
		var spr: Sprite2D = f.get_node("Sprite")
		var t := float(f.get_meta("t", 0.0)) + delta
		f.set_meta("t", t)
		spr.frame = int(t / 0.14) % spr.hframes


func _atualizar_criacao(delta: float) -> void:
	var player = main.player
	if player.global_position.distance_to(criando["pos"]) > 14.0 or player.vida <= 0:
		_fim_criacao(false)
		main._flash("Criacao cancelada.")
		return
	criando["t"] = float(criando["t"]) + delta
	barra.max_value = float(criando["dur"])
	barra.value = float(criando["t"])
	barra.global_position = player.global_position + Vector2(-35, -118)
	if barra_txt != null and is_instance_valid(barra_txt):
		barra_txt.global_position = player.global_position + Vector2(-130, -146)
	if float(criando["t"]) >= float(criando["dur"]):
		_fim_criacao(true)


func _fim_criacao(concluiu: bool) -> void:
	var dados_cena := criando
	criando = {}
	if barra != null and is_instance_valid(barra):
		barra.visible = false
	_texto_barra("")
	main.player.parar_trabalho()
	if concluiu:
		var prof := str(dados_cena["prof"])
		var alvo: Vector2 = dados_cena["alvo"]
		_lascas(alvo + Vector2(0, -30), Color("#ffe27a") if prof != "alchemy" else Color("#c98cff"), 14, 120.0, 0.6)
		var ao_fim: Callable = dados_cena["ao_fim"]
		if ao_fim.is_valid():
			ao_fim.call()
	for no in dados_cena.get("props", []):
		if is_instance_valid(no):
			var tw: Tween = no.create_tween()
			tw.tween_interval(0.6 if concluiu else 0.0)
			tw.tween_property(no, "modulate:a", 0.0, 0.4)
			tw.tween_callback(no.queue_free)


func _texto_barra(texto: String, pct: float = -1.0) -> void:
	if barra_txt == null or not is_instance_valid(barra_txt):
		if texto.is_empty():
			return
		barra_txt = Label.new()
		barra_txt.z_index = 62
		barra_txt.size = Vector2(260, 24)
		barra_txt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		barra_txt.add_theme_font_size_override("font_size", 15)
		barra_txt.add_theme_color_override("font_outline_color", Color.BLACK)
		barra_txt.add_theme_constant_override("outline_size", 5)
		main.world.add_child(barra_txt)
	barra_txt.text = texto
	barra_txt.visible = not texto.is_empty()
	barra_txt.add_theme_color_override("font_color", cor_chance(pct) if pct >= 0.0 else Color("#ffe8a3"))
	if main.player != null:
		barra_txt.global_position = main.player.global_position + Vector2(-130, -146)


# verde = facil, amarelo = medio, vermelho = arriscado
func cor_chance(pct: float) -> Color:
	if pct >= 0.8:
		return Color("#7ee06a")
	if pct >= 0.55:
		return Color("#ffd35a")
	return Color("#ff7a6b")


# Cartao no topo da tela quando a criacao termina: icone do item + "Criado!" ou "Falhou".
func aviso_item(nome_item: String, ok: bool, detalhe: String = "") -> void:
	if aviso_camada == null or not is_instance_valid(aviso_camada):
		aviso_camada = CanvasLayer.new()
		aviso_camada.layer = 90
		main.add_child(aviso_camada)
	for velho in aviso_camada.get_children():
		velho.queue_free()
	var vp: Vector2 = main.get_viewport().get_visible_rect().size
	var cartao := PanelContainer.new()
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color(0.07, 0.06, 0.05, 0.93)
	estilo.border_color = Color("#e8c25a") if ok else Color("#d0503f")
	estilo.set_border_width_all(3)
	estilo.set_corner_radius_all(12)
	estilo.content_margin_left = 14
	estilo.content_margin_right = 20
	estilo.content_margin_top = 10
	estilo.content_margin_bottom = 10
	estilo.shadow_color = Color(0, 0, 0, 0.5)
	estilo.shadow_size = 8
	cartao.add_theme_stylebox_override("panel", estilo)
	var linha := HBoxContainer.new()
	linha.add_theme_constant_override("separation", 14)
	cartao.add_child(linha)
	var icone := TextureRect.new()
	var info: Dictionary = main.item_db.get_item(nome_item) if main.item_db != null else {}
	var caminho := str(info.get("icon", ""))
	if ResourceLoader.exists(caminho):
		icone.texture = load(caminho)
	icone.custom_minimum_size = Vector2(64, 64)
	icone.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icone.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if not ok:
		icone.modulate = Color(0.55, 0.45, 0.45)
	linha.add_child(icone)
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	linha.add_child(col)
	var t1 := Label.new()
	t1.text = "Criado!" if ok else "Falhou"
	t1.add_theme_font_size_override("font_size", 15)
	t1.add_theme_color_override("font_color", Color("#e8c25a") if ok else Color("#ff7a6b"))
	col.add_child(t1)
	var t2 := Label.new()
	t2.text = nome_item
	t2.add_theme_font_size_override("font_size", 22)
	t2.add_theme_color_override("font_color", Color.WHITE)
	col.add_child(t2)
	if not detalhe.is_empty():
		var t3 := Label.new()
		t3.text = detalhe
		t3.add_theme_font_size_override("font_size", 13)
		t3.add_theme_color_override("font_color", Color("#b8c3d1"))
		col.add_child(t3)
	aviso_camada.add_child(cartao)
	cartao.reset_size()
	var tam: Vector2 = cartao.get_combined_minimum_size()
	cartao.position = Vector2((vp.x - tam.x) / 2.0, 92.0)
	cartao.pivot_offset = tam / 2.0
	cartao.scale = Vector2(0.6, 0.6)
	cartao.modulate.a = 0.0
	var tw := cartao.create_tween()
	tw.set_parallel(true)
	tw.tween_property(cartao, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(cartao, "modulate:a", 1.0, 0.18)
	tw.chain().tween_interval(2.6)
	tw.chain().tween_property(cartao, "modulate:a", 0.0, 0.45)
	tw.chain().tween_callback(cartao.queue_free)


# chance de acertar a criacao: base + por_nivel * (nivel - exigido), entre min e max
func chance(prof: String, exigido: int) -> float:
	var c: Dictionary = dados.get("sucesso", {})
	var v := float(c.get("base", 0.6)) + float(c.get("por_nivel", 0.04)) * float(nivel(prof) - exigido)
	return clampf(v, float(c.get("min", 0.35)), float(c.get("max", 1.0)))


var ultima_tentativa_ok := true

func tentar(prof: String, exigido: int) -> bool:
	ultima_tentativa_ok = randf() < chance(prof, exigido)
	return ultima_tentativa_ok


func falha_xp(xp: int) -> int:
	return maxi(1, int(round(xp * float(dados.get("sucesso", {}).get("xp_na_falha", 0.3)))))


func perder_metade(materiais: Dictionary) -> void:
	for m in materiais.keys():
		main.player.inventory.remove_item(str(m), int(ceil(int(materiais[m]) / 2.0)))


# Menu > Profissoes (aba = profissao de criacao) ou bancada da cidade
func mostrar(aba: String = "alchemy", na_bancada: bool = false) -> void:
	var titulo := "Profissoes" if not na_bancada else str(dados.get("profissoes", {}).get(aba, {}).get("nome", "Bancada"))
	var box: VBoxContainer = main._start_modal(titulo, "professions")
	var grade := GridContainer.new()
	grade.columns = 3
	grade.add_theme_constant_override("h_separation", 14)
	grade.add_theme_constant_override("v_separation", 2)
	box.add_child(grade)
	for p in ORDEM:
		var est: Dictionary = _estado()[p]
		var lv := int(est["nivel"])
		var maximo := int(dados.get("nivel_max", 50))
		var cel := VBoxContainer.new()
		cel.custom_minimum_size = Vector2(278, 44)
		cel.add_child(main._panel_label("%s  Nv %d" % [rank(p), lv], 14, Color(str(dados["profissoes"][p].get("cor", "#ffffff")))))
		var req := xp_para(lv)
		cel.add_child(_barra_xp(int(est["xp"]) if lv < maximo else 1, req if lv < maximo else 1, "MAX" if lv >= maximo else "%d/%d XP" % [int(est["xp"]), req]))
		grade.add_child(cel)
	var abas := HBoxContainer.new()
	box.add_child(abas)
	for a in ["alchemy", "cooking"]:
		var b := Button.new()
		b.text = ("> " if a == aba else "") + nome(a)
		main._style_panel_button(b)
		var alvo_aba: String = a
		b.pressed.connect(func() -> void: mostrar(alvo_aba, na_bancada))
		abas.add_child(b)
	var bonus_txt := "Coletores: +%d%% de chance nos drops raros." % int(round((bonus_drop_raro() - 1.0) * 100))
	box.add_child(main._panel_label(bonus_txt + "  A chance de criar sobe com o nivel.", 12, Color("#b8c3d1")))
	var onde := "Bancada: pode criar tudo." if na_bancada else ("Na cidade: pode criar tudo." if na_cidade() else "Fora da cidade: so receitas simples (comida media com Cozinheiro nv %d)." % int(dados.get("cozinha_media_fora_da_cidade_nivel", 15)))
	abas.add_child(main._panel_label("   " + onde, 13, Color("#b8c3d1")))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(840, 300)
	box.add_child(scroll)
	var lista := VBoxContainer.new()
	lista.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(lista)
	var receitas: Dictionary = dados.get("receitas", {})
	for nome_receita in receitas.keys():
		var r: Dictionary = receitas[nome_receita]
		if str(r.get("profissao", "")) != aba:
			continue
		var linha := HBoxContainer.new()
		linha.custom_minimum_size = Vector2(820, 54)
		var info_item: Dictionary = main.item_db.get_item(str(nome_receita))
		var icone := TextureRect.new()
		var caminho := str(info_item.get("icon", ""))
		if ResourceLoader.exists(caminho):
			icone.texture = load(caminho)
		icone.custom_minimum_size = Vector2(44, 44)
		icone.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icone.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		linha.add_child(icone)
		var col := VBoxContainer.new()
		col.custom_minimum_size = Vector2(600, 52)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var precisa := int(r.get("nivel", 1))
		var motivo := _permitida(r, na_bancada)
		var cor := Color.WHITE if nivel(aba) >= precisa and motivo.is_empty() else Color("#9aa3ad")
		var tag := str(r.get("nivel_receita", "simples"))
		var topo := HBoxContainer.new()
		topo.add_theme_constant_override("separation", 12)
		topo.add_child(main._panel_label("%s   (%s Nv %d, %s)%s" % [nome_receita, nome(aba), precisa, tag, "  - " + motivo if not motivo.is_empty() else ""], 14, cor))
		topo.add_child(selo_chance(aba, precisa))
		col.add_child(topo)
		var desc: Label = main._panel_label(_texto_materiais(r.get("materiais", {})) + "   |   " + str(info_item.get("description", "")), 12, Color("#aeb8c3"))
		desc.clip_text = true  # texto longo nao empurra o botao Criar
		desc.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		desc.tooltip_text = desc.text
		col.add_child(desc)
		linha.add_child(col)
		var b := Button.new()
		b.text = "Criar"
		b.custom_minimum_size = Vector2(96, 42)
		b.disabled = nivel(aba) < precisa or not motivo.is_empty() or not _tem_materiais(r.get("materiais", {}))
		main._style_panel_button(b)
		var nr := str(nome_receita)
		b.pressed.connect(func() -> void:
			# a criacao aparece no mundo (pilao / fogueira) e o resultado sai no fim
			animar_criacao(aba, func() -> void:
				criar(nr, na_bancada)
				mostrar(aba, na_bancada)
			, nr, chance(aba, precisa))
		)
		linha.add_child(b)
		lista.add_child(linha)


# "Chance 72%" colorido (ou o nivel que falta) ao lado de cada receita
func selo_chance(prof: String, exigido: int) -> Control:
	var falta := nivel(prof) < exigido
	var pct := chance(prof, exigido)
	var selo := PanelContainer.new()
	var estilo := StyleBoxFlat.new()
	var cor := Color("#8a929c") if falta else cor_chance(pct)
	estilo.bg_color = Color(cor.r * 0.25, cor.g * 0.25, cor.b * 0.25, 0.9)
	estilo.border_color = cor
	estilo.set_border_width_all(2)
	estilo.set_corner_radius_all(8)
	estilo.content_margin_left = 8
	estilo.content_margin_right = 8
	selo.add_theme_stylebox_override("panel", estilo)
	var t := Label.new()
	t.text = ("Precisa Nv %d" % exigido) if falta else ("Chance %d%%" % int(round(pct * 100)))
	t.add_theme_font_size_override("font_size", 14)
	t.add_theme_color_override("font_color", cor)
	selo.add_child(t)
	return selo


func _barra_xp(valor: int, maximo: int, texto: String) -> Control:
	var caixa := Control.new()
	caixa.custom_minimum_size = Vector2(262, 16)
	var b := ProgressBar.new()
	b.show_percentage = false
	b.max_value = maxi(1, maximo)
	b.value = valor
	b.size = Vector2(262, 14)
	var fundo := StyleBoxFlat.new()
	fundo.bg_color = Color(0.1, 0.1, 0.12, 0.9)
	fundo.set_corner_radius_all(4)
	var cheio := StyleBoxFlat.new()
	cheio.bg_color = Color("#55d86a")
	cheio.set_corner_radius_all(4)
	b.add_theme_stylebox_override("background", fundo)
	b.add_theme_stylebox_override("fill", cheio)
	caixa.add_child(b)
	var rot := Label.new()
	rot.text = texto
	rot.size = Vector2(262, 14)
	rot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rot.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	rot.add_theme_font_size_override("font_size", 10)
	rot.add_theme_color_override("font_outline_color", Color.BLACK)
	rot.add_theme_constant_override("outline_size", 3)
	caixa.add_child(rot)
	return caixa


# ======================= ferreiro (forja da cidade) =======================
func nivel_ferreiro_receita(receita: Dictionary) -> int:
	var lv := int(receita.get("profession_level_required", 1)) if receita.get("profession_level_required") != null else 1
	var tabela: Dictionary = dados.get("ferreiro", {}).get("nivel_material", {})
	for m in receita.get("materials", {}).keys():
		lv = maxi(lv, int(tabela.get(str(m), 1)))
	# forja rara: a raridade do item manda (lendario 28, deus 44...)
	if str(receita.get("tier", "basic")) == "rare":
		var raridade := str(main.item_db.get_item(str(receita.get("result", ""))).get("rarity", ""))
		lv = maxi(lv, int(dados.get("ferreiro", {}).get("nivel_raridade_forja_rara", {}).get(raridade, 10)))
	return mini(lv, int(dados.get("nivel_max", 50)))


func xp_ferreiro(receita: Dictionary) -> int:
	var f: Dictionary = dados.get("ferreiro", {})
	return maxi(int(f.get("xp_minimo", 20)), nivel_ferreiro_receita(receita) * int(f.get("xp_por_nivel_receita", 18)))


# media dos 3 coletores: drop raro dos monstros (DropSystem.bonus_raro)
func bonus_drop_raro() -> float:
	var media := (nivel("mining") + nivel("woodcutting") + nivel("herbalism")) / 3.0
	return 1.0 + float(dados.get("drop_raro", {}).get("por_nivel_medio", 0.02)) * (media - 1.0)


# ======================= encantamento (Ferreiro no nivel maximo) =======================
func encantamento_liberado() -> bool:
	return nivel("blacksmithing") >= int(dados.get("encantamento", {}).get("nivel_ferreiro", 50))


func cor_encanto(n: int) -> Color:
	var cores: Array = dados.get("encantamento", {}).get("cores", [])
	if n <= 0 or cores.is_empty():
		return Color.WHITE
	return Color(str(cores[mini(n, cores.size()) - 1]))


func _equipaveis() -> Array:
	# [{nome, onde: "slot"|"bolsa", slot}]
	var lista: Array = []
	var inv = main.player.inventory
	for slot in inv.equipment.keys():
		var n := str(inv.equipment[slot])
		if not n.is_empty() and str(main.item_db.get_item(n).get("type", "")) == "equipment":
			lista.append({"nome": n, "onde": "slot", "slot": str(slot)})
	for n in inv.items.keys():
		if str(main.item_db.get_item(str(n)).get("type", "")) == "equipment":
			lista.append({"nome": str(n), "onde": "bolsa", "slot": ""})
	return lista


func mostrar_encantamento() -> void:
	var box: VBoxContainer = main._start_modal("Encantamento", "forge")
	var enc: Dictionary = dados.get("encantamento", {})
	if not encantamento_liberado():
		box.add_child(main._panel_label("Libera quando o Ferreiro chegar ao nivel %d (%s). Seu Ferreiro: nivel %d." % [int(enc.get("nivel_ferreiro", 50)), "Ferreiro Grao-Mestre", nivel("blacksmithing")], 15, Color("#ffd36b")))
		return
	box.add_child(main._panel_label("Ouro: %d   |   Cada +1 = +%d%% nos atributos e uma aura de cor nova. A partir de +%d, falhar volta 1 nivel." % [main.player.ouro, int(round(float(enc.get("bonus_por_nivel", 0.08)) * 100)), int(enc.get("falha_volta_nivel_a_partir", 7))], 13, Color("#ffd36b")))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(840, 420)
	box.add_child(scroll)
	var lista := VBoxContainer.new()
	lista.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(lista)
	var maximo := int(enc.get("max", 10))
	for e in _equipaveis():
		var nome_item := str(e["nome"])
		var atual := ItemDatabase.nivel_encanto(nome_item)
		var linha := HBoxContainer.new()
		linha.custom_minimum_size = Vector2(820, 54)
		var info: Dictionary = main.item_db.get_item(nome_item)
		var icone := TextureRect.new()
		if ResourceLoader.exists(str(info.get("icon", ""))):
			icone.texture = load(str(info.get("icon", "")))
		icone.custom_minimum_size = Vector2(44, 44)
		icone.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icone.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icone.modulate = Color.WHITE if atual == 0 else cor_encanto(atual).lerp(Color.WHITE, 0.5)
		linha.add_child(icone)
		var col := VBoxContainer.new()
		col.custom_minimum_size = Vector2(600, 52)
		var onde := "equipado" if e["onde"] == "slot" else "na bolsa"
		col.add_child(main._panel_label("%s  (%s)" % [nome_item, onde], 14, cor_encanto(atual) if atual > 0 else Color.WHITE))
		var b := Button.new()
		b.custom_minimum_size = Vector2(110, 42)
		main._style_panel_button(b)
		if atual >= maximo:
			col.add_child(main._panel_label("Encanto maximo.", 12, Color("#aeb8c3")))
			b.text = "Maximo"
			b.disabled = true
		else:
			var custo: Dictionary = enc.get("custos", [])[atual]
			var chance_enc := float(enc.get("chances", [])[atual])
			col.add_child(main._panel_label("+%d: %d%% de chance, %d ouro, %s" % [atual + 1, int(round(chance_enc * 100)), int(custo.get("ouro", 0)), _texto_materiais(custo.get("materiais", {}))], 12, Color("#aeb8c3")))
			b.text = "Encantar"
			b.disabled = main.player.ouro < int(custo.get("ouro", 0)) or not _tem_materiais(custo.get("materiais", {}))
			var dados_item: Dictionary = e
			b.pressed.connect(func() -> void:
				encantar(dados_item)
				mostrar_encantamento()
			)
		linha.add_child(col)
		linha.add_child(b)
		lista.add_child(linha)


func encantar(e: Dictionary) -> bool:
	var enc: Dictionary = dados.get("encantamento", {})
	var nome_item := str(e["nome"])
	var atual := ItemDatabase.nivel_encanto(nome_item)
	if not encantamento_liberado() or atual >= int(enc.get("max", 10)):
		return false
	var custo: Dictionary = enc.get("custos", [])[atual]
	var materiais: Dictionary = custo.get("materiais", {})
	if main.player.ouro < int(custo.get("ouro", 0)) or not _tem_materiais(materiais):
		main._flash_red("Faltam ouro ou materiais.")
		return false
	main.player.ouro -= int(custo.get("ouro", 0))
	for m in materiais.keys():
		main.player.inventory.remove_item(str(m), int(materiais[m]))
	var base := ItemDatabase.nome_base(nome_item)
	var novo_nivel := atual + 1
	var ok := randf() < float(enc.get("chances", [])[atual])
	if not ok:
		novo_nivel = atual - 1 if atual >= int(enc.get("falha_volta_nivel_a_partir", 7)) else atual
	var novo_nome := base if novo_nivel <= 0 else "%s +%d" % [base, novo_nivel]
	if novo_nome != nome_item:
		var inv = main.player.inventory
		if e["onde"] == "slot":
			inv.equipment[str(e["slot"])] = novo_nome
		else:
			inv.remove_item(nome_item, 1)
			inv.add_item(novo_nome, 1)
		main.player.recalculate_equipment()
	ganhar_xp("blacksmithing", 50 * (atual + 1))
	if ok:
		AudioManager.play_sfx("nivel")
		main._flash("Encantado! %s (aura %s)" % [novo_nome, str(enc.get("nomes_cor", [])[novo_nivel - 1])])
		aviso_item(novo_nome, true, "Encantamento +%d" % novo_nivel)
	else:
		AudioManager.play_sfx("dano", 0.7, 0.1)
		main._flash_red("O encanto falhou%s." % (": voltou para " + novo_nome if novo_nivel < atual else ""))
		aviso_item(novo_nome, false, "O encanto falhou" + (" e voltou 1 nivel" if novo_nivel < atual else ""))
	_atualizar_aura()
	return ok


# ======================= aura do encantamento =======================
var aura: Node2D
var aura_brilho: Sprite2D
var aura_nivel := -1


func _copiar_sprite() -> void:
	var player = main.player
	if aura_brilho == null or not is_instance_valid(aura_brilho) or player == null:
		return
	var spr: Sprite2D = player.sprite
	aura_brilho.texture = spr.texture
	aura_brilho.position = spr.position
	aura_brilho.scale = spr.scale
	aura_brilho.offset = spr.offset
	aura_brilho.centered = spr.centered
	aura_brilho.flip_h = spr.flip_h
	aura_brilho.region_enabled = spr.region_enabled
	aura_brilho.region_rect = spr.region_rect
	aura_brilho.hframes = spr.hframes
	aura_brilho.vframes = spr.vframes
	aura_brilho.frame = spr.frame


func _atualizar_aura() -> void:
	var player = main.player
	if player == null or not is_instance_valid(player):
		return
	var n := ItemDatabase.nivel_encanto(str(player.inventory.equipment.get("weapon", "")))
	if n == aura_nivel and aura != null and is_instance_valid(aura) and aura.get_parent() == player:
		return
	aura_nivel = n
	if aura != null and is_instance_valid(aura):
		aura.queue_free()
	aura = null
	aura_brilho = null
	if n <= 0:
		return
	var cor := cor_encanto(n)
	aura = Node2D.new()
	aura.name = "AuraEncanto"
	aura.z_index = 0
	# contorno brilhante do heroi na cor do encanto (shader), atras do sprite e acompanhando a animacao
	aura_brilho = Sprite2D.new()
	aura_brilho.z_index = -1
	var mat := ShaderMaterial.new()
	mat.shader = load("res://assets/shaders/aura_encanto.gdshader")
	mat.set_shader_parameter("cor", cor)
	mat.set_shader_parameter("raio", 3.0 + 0.7 * n)
	mat.set_shader_parameter("intensidade", 0.55 + 0.05 * n)
	aura_brilho.material = mat
	aura.add_child(aura_brilho)
	_copiar_sprite()
	# faiscas subindo da arma/corpo
	var faisca := CPUParticles2D.new()
	faisca.amount = 6 + n * 3
	faisca.lifetime = 0.9
	faisca.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	faisca.emission_rect_extents = Vector2(26, 34)
	faisca.position = Vector2(0, -40)
	faisca.direction = Vector2(0, -1)
	faisca.spread = 25.0
	faisca.gravity = Vector2(0, -30)
	faisca.initial_velocity_min = 12.0
	faisca.initial_velocity_max = 34.0
	faisca.scale_amount_min = 1.5
	faisca.scale_amount_max = 3.0 + n * 0.25
	var fade := Gradient.new()
	fade.set_color(0, Color(cor.r, cor.g, cor.b, 1.0))
	fade.set_color(1, Color(cor.r, cor.g, cor.b, 0.0))
	faisca.color_ramp = fade
	var mat2 := CanvasItemMaterial.new()
	mat2.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	faisca.material = mat2
	aura.add_child(faisca)
	player.add_child(aura)


# ======================= comida =======================
func comer(nome_item: String, info: Dictionary) -> void:
	var comida: Dictionary = info.get("comida", {})
	var agora := _agora()
	main.mmo_cache["comida"] = {
		"item": nome_item,
		"regen_ate": agora + float(comida.get("dura_s", 10)),
		"cura_por_s": float(comida.get("cura_por_s", 0)),
		"mana_por_s": float(comida.get("mana_por_s", 0)),
		"bonus_ate": agora + float(comida.get("bonus_s", 0)),
		"bonus": comida.get("bonus", {}),
	}
	bonus_ativo = _bonus_comida_ativo()
	main._apply_companion_bonuses()


func _bonus_comida_ativo() -> bool:
	var c = main.mmo_cache.get("comida", {})
	return typeof(c) == TYPE_DICTIONARY and not (c.get("bonus", {}) as Dictionary).is_empty() and _agora() < float(c.get("bonus_ate", 0))


func _regen_comida(delta: float) -> void:
	var c = main.mmo_cache.get("comida", {})
	if typeof(c) != TYPE_DICTIONARY or _agora() >= float(c.get("regen_ate", 0)):
		return
	regen_acc += delta
	if regen_acc < 1.0:
		return
	regen_acc -= 1.0
	var p = main.player
	if float(c.get("cura_por_s", 0)) > 0 and p.vida < p.vida_max and p.vida > 0:
		p.heal(int(c["cura_por_s"]))
	if float(c.get("mana_por_s", 0)) > 0 and p.mana < p.mana_max:
		p.recover_mana(int(c["mana_por_s"]))


# main._apply_companion_bonuses chama depois de zerar os bonus de companheiro
func aplicar_bonus(player) -> void:
	if not _bonus_comida_ativo():
		return
	var b: Dictionary = main.mmo_cache["comida"].get("bonus", {})
	player.companion_physical_damage_pct += float(b.get("dano_pct", 0.0))
	player.companion_defense_pct += float(b.get("defesa_pct", 0.0))
	player.companion_vida_max_pct += float(b.get("vida_max_pct", 0.0))


func texto_bonus() -> String:
	if not _bonus_comida_ativo():
		return ""
	var c: Dictionary = main.mmo_cache["comida"]
	return "%s: %d min" % [str(c.get("item", "Comida")), int(ceil((float(c["bonus_ate"]) - _agora()) / 60.0))]
