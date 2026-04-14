## ItemSlots.gd
## 道具槽位類型定義
## slot key（英文）↔ 顯示名稱（中文）↔ 實際 EQUIP_SLOTS

class_name ItemSlots

const TYPES: Dictionary = {
	"weapon":   { "label": "武器",     "equip_slots": ["主手武器"] },
	"armor":    { "label": "鎧甲",     "equip_slots": ["身體（盔甲）"] },
	"shield":   { "label": "盾牌",     "equip_slots": ["副手/法杖"] },
	"staff":    { "label": "法杖",     "equip_slots": ["副手/法杖"] },
	"gun":      { "label": "魔導槍械", "equip_slots": ["主手武器", "副手/法杖"] },
	"headband": { "label": "頭環",     "equip_slots": ["頭環"] },
	"gloves":   { "label": "手套",     "equip_slots": ["手套"] },
	"bracelet": { "label": "手環",     "equip_slots": ["手環"] },
	"cloak":    { "label": "披風",     "equip_slots": ["披風"] },
	"belt":     { "label": "腰帶",     "equip_slots": ["腰帶"] },
	"boots":    { "label": "鞋子",     "equip_slots": ["鞋子"] },
	"necklace": { "label": "項鍊",     "equip_slots": ["項鍊"] },
	"ring":     { "label": "戒指",     "equip_slots": ["戒指 1", "戒指 2"] },
}

static func label(slot_key: String) -> String:
	return TYPES.get(slot_key, {}).get("label", slot_key)

static func equip_slots(slot_key: String) -> Array:
	return TYPES.get(slot_key, {}).get("equip_slots", [])

static func all_keys() -> Array:
	return TYPES.keys()

## 給定 EQUIP_SLOTS 的槽名（如 "主手武器"），反查可能的 slot keys
static func from_equip_slot(equip_slot: String) -> Array:
	var result: Array = []
	for key in TYPES:
		if equip_slot in TYPES[key]["equip_slots"]:
			result.append(key)
	return result
