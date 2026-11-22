extends RefCounted
class_name ValorItens
# Valor de mercado dos itens e regras do mercador (data/mercado.json). O servidor usa a mesma
# conta em server/src/utils/itemValue.js para o preco recomendado do mercado entre jogadores.

const ORDEM_RARIDADE := ["common", "uncommon", "rare", "super_rare", "epic", "legendary", "mega_legendary", "god"]
static var _dados: Dictionary = {}


static func dados() -> Dictionary:
	if _dados.is_empty():
		_dados = ItemDatabase.load_json("res://data/mercado.json")
	return _dados


static func valor(item_name: String, item_db: ItemDatabase) -> int:
	var d := dados()
	var info: Dictionary = item_db.get_item(item_name)
	var base := ItemDatabase.nome_base(item_name)
	var base_info: Dictionary = item_db.get_item(base)
	var v := 0.0
	if base_info.get("price") != null and int(base_info.get("price", 0)) > 0:
		v = float(base_info["price"])
	elif str(base_info.get("type", "")) == "equipment":
		var r := float(d.get("valor_raridade", {}).get(str(base_info.get("rarity", "common")), 60))
		v = r * float(d.get("multiplicador_slot", {}).get(str(base_info.get("slot", "")), 1.0))
	else:
		v = float(d.get("valor_material", {}).get(base, d.get("material_padrao", 12)))
	var n := int(info.get("enchant", 0))
	v *= 1.0 + float(d.get("encanto_por_nivel", 0.6)) * n
	return maxi(1, int(round(v)))


static func preco_venda_npc(item_name: String, item_db: ItemDatabase) -> int:
	return maxi(1, int(floor(valor(item_name, item_db) * float(dados().get("npc_compra_pct", 0.35)))))


# o mercador NPC so vende ate o Ouro (raridade "rare" dos materiais comuns); o resto vem de forja/jogadores
static func npc_vende(item_name: String, item_db: ItemDatabase) -> bool:
	var d := dados()
	if item_name in d.get("npc_vende_consumiveis", []):
		return true
	var info: Dictionary = item_db.get_item(item_name)
	if str(info.get("type", "")) != "equipment" or ItemDatabase.nivel_encanto(item_name) > 0:
		return false
	var limite := ORDEM_RARIDADE.find(str(d.get("npc_raridade_max", "rare")))
	var rar := ORDEM_RARIDADE.find(str(info.get("rarity", "common")))
	if rar < 0 or rar > limite:
		return false
	for palavra in d.get("npc_materiais", []):
		if str(palavra) in item_name or str(palavra) in str(info.get("set", "")):
			return true
	return false


static func lista_npc(item_db: ItemDatabase) -> Array:
	var lista: Array = []
	for nome in dados().get("npc_vende_consumiveis", []):
		if item_db.has_item(str(nome)):
			lista.append(str(nome))
	var equipamentos: Array = []
	for nome in item_db.items.keys():
		if not str(nome) in lista and npc_vende(str(nome), item_db):
			equipamentos.append(str(nome))
	equipamentos.sort_custom(func(a, b) -> bool: return valor(a, item_db) < valor(b, item_db))
	return lista + equipamentos


# preco recomendado: mediana das vendas recentes (servidor manda em market_state) ou o valor
static func recomendado(item_name: String, item_db: ItemDatabase, vendas: Array = []) -> int:
	var d := dados()
	if vendas.size() >= int(d.get("recomendado_min_vendas", 3)):
		var precos: Array = vendas.duplicate()
		precos.sort()
		return int(precos[int(precos.size() / 2.0)])
	return valor(item_name, item_db)
