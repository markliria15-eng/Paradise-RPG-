extends RefCounted
class_name CraftingSystem

static func load_recipes() -> Dictionary:
	return ItemDatabase.load_json("res://data/recipes.json")

static func material_text(recipe: Dictionary, inventory: InventorySystem) -> String:
	var parts: Array[String] = []
	var materials: Dictionary = recipe.get("materials", {})
	for material in materials.keys():
		var need := int(materials[material])
		var have := int(inventory.items.get(str(material), 0))
		parts.append("%s %d/%d" % [str(material), have, need])
	return ", ".join(parts)

static func can_craft(player, recipe: Dictionary) -> bool:
	if player.ouro < int(recipe.get("gold", 0)):
		return false
	var result := str(recipe.get("result", ""))
	if result.is_empty():
		return false
	if not player.inventory.items.has(result) and player.inventory.items.size() >= InventorySystem.MAX_SLOTS:
		return false
	var materials: Dictionary = recipe.get("materials", {})
	for material in materials.keys():
		if int(player.inventory.items.get(str(material), 0)) < int(materials[material]):
			return false
	return true

static func craft(player, recipe: Dictionary) -> bool:
	if not can_craft(player, recipe):
		return false
	var result := str(recipe.get("result", ""))
	if result.is_empty():
		return false
	var materials: Dictionary = recipe.get("materials", {})
	for material in materials.keys():
		player.inventory.remove_item(str(material), int(materials[material]))
	player.ouro -= int(recipe.get("gold", 0))
	return player.inventory.add_item(result, 1)
