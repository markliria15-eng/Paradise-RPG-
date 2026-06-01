extends RefCounted
class_name UIInventoryWindow

static func is_equippable(data: Dictionary) -> bool:
	return EquipmentSystem.can_equip(data)
