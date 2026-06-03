extends RefCounted
class_name InventorySystem

# Inventario baseado em pilhas por nome de item. O banco de itens define se algo
# e consumivel, equipamento, joia, material ou item de missao.
const MAX_SLOTS := 20
const EQUIPMENT_SLOTS := ["amulet", "helmet", "backpack", "shield", "armor", "weapon", "ring", "pants", "gloves", "jewel", "boots"]

var items: Dictionary = {}
var equipment: Dictionary = {}

func _init() -> void:
	equipment = EquipmentSystem.empty_equipment()

func add_item(item_name: String, amount: int = 1) -> bool:
	if item_name.is_empty():
		return false
	if not items.has(item_name) and items.size() >= MAX_SLOTS:
		return false
	items[item_name] = int(items.get(item_name, 0)) + amount
	return true

func remove_item(item_name: String, amount: int = 1) -> bool:
	if int(items.get(item_name, 0)) < amount:
		return false
	items[item_name] -= amount
	if items[item_name] <= 0:
		items.erase(item_name)
	return true

func equip(item_name: String, item_data: Dictionary) -> String:
	return EquipmentSystem.equip_item(self, item_name, item_data)

func remove_equipment(slot: String) -> String:
	return EquipmentSystem.remove_item(self, slot)

func first_free_jewel_slot() -> String:
	return "jewel"

func to_save() -> Dictionary:
	return {"items": items, "equipment": equipment}

func from_save(data: Dictionary) -> void:
	items = data.get("items", {})
	var saved_equipment: Dictionary = data.get("equipment", equipment)
	equipment = EquipmentSystem.empty_equipment()
	for slot in saved_equipment.keys():
		var normalized := EquipmentSystem.normalize_slot(str(slot))
		if equipment.has(normalized) and str(equipment[normalized]).is_empty():
			equipment[normalized] = str(saved_equipment[slot])
		elif equipment.has(normalized) and not str(saved_equipment[slot]).is_empty():
			add_item(str(saved_equipment[slot]), 1)
