extends RefCounted
class_name EquipmentSystem

const SLOT_ORDER := [
	"amulet", "head", "backpack",
	"shoulder_left", "chest", "shoulder_right",
	"shield", "hand_left", "weapon",
	"ring", "belt", "jewel",
	"hand_right", "legs", "pants",
	"foot_left", "boots", "foot_right"
]
const SLOT_GRID := [
	["amulet", "head", "backpack"],
	["shoulder_left", "chest", "shoulder_right"],
	["shield", "hand_left", "weapon"],
	["ring", "belt", "jewel"],
	["hand_right", "legs", "pants"],
	["foot_left", "boots", "foot_right"]
]
const SLOT_LABELS := {
	"amulet": "Amuleto",
	"head": "Cabeca",
	"backpack": "Mochila",
	"shoulder_left": "Ombro Esq.",
	"shoulder_right": "Ombro Dir.",
	"shield": "Escudo",
	"chest": "Peitoral",
	"weapon": "Arma",
	"ring": "Anel",
	"belt": "Cinto",
	"hand_left": "Mao Esq.",
	"hand_right": "Mao Dir.",
	"legs": "Pernas",
	"pants": "Calca Extra",
	"jewel": "Joia",
	"foot_left": "Pe Esq.",
	"foot_right": "Pe Dir.",
	"boots": "Bota Extra"
}
const SLOT_ALIASES := {
	"cabeca": "head",
	"helmet": "head",
	"head": "head",
	"peitoral": "chest",
	"armor": "chest",
	"chest": "chest",
	"luvas": "hand_left",
	"gloves": "hand_left",
	"hand_left": "hand_left",
	"hand_right": "hand_right",
	"shoulder_left": "shoulder_left",
	"shoulder_right": "shoulder_right",
	"belt": "belt",
	"legs": "legs",
	"calca": "legs",
	"pants": "legs",
	"botas": "foot_left",
	"boots": "foot_left",
	"foot_left": "foot_left",
	"foot_right": "foot_right",
	"arma": "weapon",
	"joia": "jewel",
	"joia_1": "jewel",
	"joia_2": "jewel",
	"joia_3": "jewel",
	"shield": "shield",
	"weapon": "weapon",
	"ring": "ring",
	"jewel": "jewel",
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
