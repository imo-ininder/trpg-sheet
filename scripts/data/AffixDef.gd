## AffixDef.gd
## 詞綴定義（從 JSON 加載）
## 取代原本的 AffixData，使用 compact 格式

class_name AffixDef

var id: String                    # 唯一識別碼（如 "str_增加"）
var affix_name: String            # 顯示名稱（如 "STR 增加"）
var slots: Array                  # 適用槽位 ["weapon", "armor", ...]
var variants: Array               # [{cost, modifier, description}, ...]

func _init(data: Dictionary) -> void:
	id = data.get("id", "")
	affix_name = data.get("affix_name", "")
	slots = data.get("slots", [])
	variants = data.get("variants", [])

## 根據 cost 查找對應的 variant
func get_variant_by_cost(cost: int) -> Dictionary:
	for v in variants:
		if v.get("cost", 0) == cost:
			return v
	# 找不到時回傳第一個（fallback）
	return variants[0] if not variants.is_empty() else {}

## 取得所有可用的 cost 值
func get_all_costs() -> Array:
	var costs: Array = []
	for v in variants:
		costs.append(v.get("cost", 0))
	return costs

## 檢查是否適用於指定槽位
func is_applicable_to(slot_key: String) -> bool:
	return slot_key in slots

## 取得 modifier（可能是 dict 或 array）
func get_modifier(cost: int):
	var variant := get_variant_by_cost(cost)
	return variant.get("modifier", null)

## 取得描述
func get_description(cost: int) -> String:
	var variant := get_variant_by_cost(cost)
	return variant.get("description", "")

## 判斷是否為 special type
func is_special(cost: int) -> bool:
	var mod = get_modifier(cost)
	if mod is Dictionary:
		return mod.get("type", "") == "special"
	return false
