extends RefCounted
class_name EquipmentSystem

const SLOT_ORDER := ["amulet", "helmet", "backpack", "shield", "armor", "weapon", "ring", "pants", "gloves", "jewel", "boots"]
const SLOT_GRID := [
	["amulet", "helmet", "backpack"],
	["shield", "armor", "weapon"],
	["ring", "pants", "jewel"],
	["gloves"],
	["boots"]
]
const SLOT_LABELS := {
	"amulet": "Amuleto",
	"helmet": "Capacete",
	"backpack": "Mochila",
	"shield": "Escudo",
	"armor": "Armadura",
	"weapon": "Arma",
	"ring": "Anel",
	"pants": "Calca",
	"gloves": "Luvas",
	"jewel": "Joia",
	"boots": "Bota"
}
const SLOT_ALIASES := {
	"cabeca": "helmet",
	"peitoral": "armor",
	"luvas": "gloves",
	"calca": "pants",
	"botas": "boots",
	"arma": "weapon",
	"joia": "jewel",
	"joia_1": "jewel",
	"joia_2": "jewel",
	"joia_3": "jewel",
	"shield": "shield",
	"helmet": "helmet",
	"armor": "armor",
	"weapon": "weapon",
	"ring": "ring",
	"pants": "pants",
	"gloves": "gloves",
	"jewel": "jewel",
	"boots": "boots",
	"amulet": "amulet",
	"backpack": "backpack"
}

static func empty_equipment() -> Dictionary:
	var result := {}
	for slot in SLOT_ORDER:
		result[slot] = ""
	return result

static func normalize_slot(slot: String) -> String:
	return str(SLOT_ALIASES.get(slot, slot))

static func slot_label(slot: String) -> String:
	return str(SLOT_LABELS.get(normalize_slot(slot), slot))

static func can_equip(item_data: Dictionary) -> bool:
	var item_type := str(item_data.get("type", ""))
	var slot := normalize_slot(str(item_data.get("slot", "")))
	return item_type in ["equipment", "equipamento", "joia"] and SLOT_ORDER.has(slot)

static func equip_item(inventory, item_name: String, item_data: Dictionary) -> String:
	if not can_equip(item_data) or not inventory.items.has(item_name):
		return ""
	var slot := normalize_slot(str(item_data.get("slot", "")))
	var previous := str(inventory.equipment.get(slot, ""))
	inventory.equipment[slot] = item_name
	inventory.remove_item(item_name, 1)
	if not previous.is_empty():
		inventory.add_item(previous, 1)
	return slot

static func remove_item(inventory, slot: String) -> String:
	var normalized := normalize_slot(slot)
	var item_name := str(inventory.equipment.get(normalized, ""))
	if item_name.is_empty():
		return ""
	if not inventory.add_item(item_name, 1):
		return ""
	inventory.equipment[normalized] = ""
	return item_name
