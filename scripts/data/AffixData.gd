## AffixData.gd
## 單一詞綴的靜態定義（不需要存檔，由 AffixLibrary 統一管理）

class_name AffixData

var name: String
## 適用的 slot keys（對應 ItemSlots.TYPES 的 key）
var applicable_slots: Array
## 對應 CharacterData 的欄位（空字串 = 純被動/主動，不影響數值）
## 多個 key 時，mod.value 會同時加到所有欄位（例如 堅韌 同時加 phys_resist + magic_resist）
var stat_keys: Array
## 各階段定義：[{ cost: int, value: int, effect: String }, ...]
## cost   = 所需加值兌換點數
## value  = 實際套用到 stat_keys 的數值（0 = 純效果描述）
## effect = 效果說明文字
var tiers: Array

func _init(n: String, slots: Array, sk: Array, t: Array) -> void:
	name = n
	applicable_slots = slots
	stat_keys = sk
	tiers = t

## 根據 stat_value 找最接近的 tier index
func tier_index_for_value(val: int) -> int:
	var best := 0
	for i in tiers.size():
		if tiers[i].get("value", 0) <= val:
			best = i
	return best
