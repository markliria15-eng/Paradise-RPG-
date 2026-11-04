extends RefCounted
class_name NpcShop

const GOODS := ["Pocao pequena de vida", "Pocao media de vida", "Pocao pequena de mana", "Pocao media de mana", "Bolsa de Ombro", "Mochila de Viajante"]

static func buy(player, item_db: ItemDatabase, item_name: String) -> bool:
	var data := item_db.get_item(item_name)
	var price := int(data.get("price", 0))
	if price <= 0 or player.ouro < price:
		return false
	if not player.inventory.add_item(item_name, 1):
		return false  # bolsa cheia: nao cobra
	player.ouro -= price
	return true
