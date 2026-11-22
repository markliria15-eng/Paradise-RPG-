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


# bancada: "pos" fixa ou ao lado de um NPC ("perto_npc" = comeco do nome, "offset" em px)
func _pos_estacao(e: Dictionary) -> Vector2:
	var off: Array = e.get("offset", [0, 0])
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
	pontos.append(ponto)
	_atualizar_visual(ponto)


func _por_textura(sprite: Sprite2D, tex: Texture2D, altura: float) -> void:
	sprite.texture = tex
	var s := altura / maxf(1.0, float(tex.get_height()))
	sprite.scale = Vector2(s, s)
	sprite.offset = Vector2(-tex.get_width() / 2.0, -float(tex.get_height()))
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR


func _disponivel(ponto: Dictionary) -> bool:
	return bool(ponto["estacao"]) or _agora() >= float(esgotados.get(ponto["chave"], 0.0))


func _atualizar_visual(ponto: Dictionary) -> void:
	var def: Dictionary = ponto["def"]
	var cheio := _disponivel(ponto)
	var caminho := str(def.get("sprite" if cheio else "esgotado", def.get("sprite", "")))
	if ResourceLoader.exists(caminho):
		var altura := float(def.get("altura", 60))
		if not cheio:
			altura *= 0.5 if str(def.get("profissao", "")) != "woodcutting" else 0.42
		_por_textura(ponto["sprite"], load(caminho), altura)
	ponto["sprite"].modulate = Color.WHITE if cheio else Color(0.85, 0.85, 0.85, 0.9)


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
				if antes != agora:
					p["cheio"] = agora
					_atualizar_visual(p)
		_atualizar_aura()
		if bonus_ativo and not _bonus_comida_ativo():
			bonus_ativo = false
			main._flash("O efeito da comida acabou.")
			main._apply_companion_bonuses()
	if not coletando.is_empty():
		_atualizar_coleta(delta)
		return
	_escolher_alvo(player.global_position)


func _escolher_alvo(heroi: Vector2) -> void:
	var melhor: Dictionary = {}
	var dist := 1.0
	for p in pontos:
		if not is_instance_valid(p["node"]) or not _disponivel(p):
			continue
		# bancada alcanca um pouco mais longe (e maior)
		var d: float = p["node"].global_position.distance_to(heroi) / (ALCANCE * (1.5 if p["estacao"] else 1.0))
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


# chamado por main._interact antes dos NPCs: true = usou o E/OK
func interagir() -> bool:
	if alvo.is_empty() or not coletando.is_empty() or main.player == null:
		return false
	if not is_instance_valid(alvo["node"]):
		alvo = {}
		return false
	if alvo["node"].global_position.distance_to(main.player.global_position) > ALCANCE * (1.5 if alvo["estacao"] else 1.0):
		return false
	var def: Dictionary = alvo["def"]
	var prof := str(def.get("profissao", ""))
	if alvo["estacao"]:
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


func _atualizar_coleta(delta: float) -> void:
	var player = main.player
	var ponto: Dictionary = coletando["ponto"]
	if not is_instance_valid(ponto["node"]) or player.global_position.distance_to(coletando["pos"]) > 14.0 or player.vida <= 0:
		_cancelar()
		main._flash("Coleta cancelada.")
		return
	coletando["t"] = float(coletando["t"]) + delta
	coletando["golpe"] = float(coletando["golpe"]) - delta
	var prof := str(ponto["def"].get("profissao", ""))
	if coletando["golpe"] <= 0.0 and prof != "herbalism":
		coletando["golpe"] = 0.7
		if player.has_method("_play_action"):
			player._play_action("attack")
		AudioManager.play_sfx("golpe", 0.5, 0.15)
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
		ganhar_xp(prof, falha_xp(xp))
		return true
	for m in materiais.keys():
		inv.remove_item(str(m), int(materiais[m]))
	inv.add_item(nome_receita, 1)
	AudioManager.play_sfx("moeda", 1.1, 0.2)
	main._flash("Criado: %s  (+%d XP %s)" % [nome_receita, xp, nome(prof)])
	ganhar_xp(prof, xp)
	if main.has_method("_update_potion_buttons"):
		main._update_potion_buttons()
	return true


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
		var precisa := int(r.get("nivel", 1))
		var motivo := _permitida(r, na_bancada)
		var cor := Color.WHITE if nivel(aba) >= precisa and motivo.is_empty() else Color("#9aa3ad")
		var tag := str(r.get("nivel_receita", "simples"))
		var chance_txt := "" if nivel(aba) < precisa else "  %d%%" % int(round(chance(aba, precisa) * 100))
		col.add_child(main._panel_label("%s   (%s Nv %d, %s)%s%s" % [nome_receita, nome(aba), precisa, tag, chance_txt, "  - " + motivo if not motivo.is_empty() else ""], 14, cor))
		col.add_child(main._panel_label(_texto_materiais(r.get("materiais", {})) + "   |   " + str(info_item.get("description", "")), 12, Color("#aeb8c3")))
		linha.add_child(col)
		var b := Button.new()
		b.text = "Criar"
		b.custom_minimum_size = Vector2(96, 42)
		b.disabled = nivel(aba) < precisa or not motivo.is_empty() or not _tem_materiais(r.get("materiais", {}))
		main._style_panel_button(b)
		var nr := str(nome_receita)
		b.pressed.connect(func() -> void:
			if criar(nr, na_bancada):
				mostrar(aba, na_bancada)
		)
		linha.add_child(b)
		lista.add_child(linha)


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
	else:
		AudioManager.play_sfx("dano", 0.7, 0.1)
		main._flash_red("O encanto falhou%s." % (": voltou para " + novo_nome if novo_nivel < atual else ""))
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
