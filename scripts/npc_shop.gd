extends RefCounted
class_name NpcShop
# Mercador NPC: vende consumiveis e equipamentos ate o Ouro (ValorItens.lista_npc, data/mercado.json)
# e compra itens do jogador por parte do valor. Itens melhores: forja ou mercado entre jogadores.

const GOODS := ["Pocao pequena de vida", "Pocao media de vida", "Pocao pequena de mana", "Pocao media de mana", "Bolsa de Ombro", "Mochila de Viajante"]

static func buy(player, item_db: ItemDatabase, item_name: String) -> bool:
	if not ValorItens.npc_vende(item_name, item_db):
		return false
	var price := ValorItens.valor(item_name, item_db)
	if price <= 0 or player.ouro < price:
		return false
	if not player.inventory.add_item(item_name, 1):
		return false  # bolsa cheia: nao cobra
	player.ouro -= price
	return true

static func sell(player, item_db: ItemDatabase, item_name: String, amount: int = 1) -> int:
	var have := int(player.inventory.items.get(item_name, 0))
	amount = mini(amount, have)
	if amount <= 0 or str(item_db.get_item(item_name).get("type", "")) == "quest":
		return 0
	if not player.inventory.remove_item(item_name, amount):
		return 0
	var total := ValorItens.preco_venda_npc(item_name, item_db) * amount
	player.ouro += total
	return total
