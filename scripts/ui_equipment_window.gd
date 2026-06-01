extends RefCounted
class_name UIEquipmentWindow

static func slot_icon(item_db: ItemDatabase, item_name: String, fallback_icon: String) -> Texture2D:
	if item_name.is_empty():
		return load(fallback_icon) as Texture2D
	var data := item_db.get_item(item_name)
	return load(str(data.get("icon", fallback_icon))) as Texture2D

static func slot_tooltip(slot: String, item_name: String) -> String:
	if item_name.is_empty():
		return EquipmentSystem.slot_label(slot)
	return "%s: %s" % [EquipmentSystem.slot_label(slot), item_name]
