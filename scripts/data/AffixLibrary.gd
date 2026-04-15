## AffixLibrary.gd
## Autoload — 所有詞綴定義 + lookup
## 資料來源：data/affixes.json

extends Node

var _by_id: Dictionary = {}  # id -> AffixDef

func _ready() -> void:
	load_from_json("res://data/affixes.json")

# ── Lookup ────────────────────────────────────────
func get_affix(id: String) -> AffixDef:
	return _by_id.get(id, null)

func all_affixes() -> Array:
	return _by_id.values()

## 回傳適用於指定 slot key 的所有詞綴
func for_slot(slot_key: String) -> Array:
	var result: Array = []
	for affix: AffixDef in _by_id.values():
		if affix.is_applicable_to(slot_key):
			result.append(affix)
	return result

# ── 從 JSON 載入 ──────────────────────────────────
func load_from_json(path: String) -> void:
	if not FileAccess.file_exists(path):
		push_error("AffixLibrary: JSON file not found: " + path)
		return

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("AffixLibrary: Cannot open JSON file: " + path)
		return

	var json_str := file.get_as_text()
	file.close()

	var json := JSON.new()
	var error := json.parse(json_str)
	if error != OK:
		push_error("AffixLibrary: JSON parse error at line %d: %s" % [json.get_error_line(), json.get_error_message()])
		return

	var data: Array = json.data
	if not data is Array:
		push_error("AffixLibrary: JSON root must be an array")
		return

	_by_id.clear()
	for affix_data in data:
		if not affix_data is Dictionary:
			continue
		var affix := AffixDef.new(affix_data)
		_by_id[affix.id] = affix

	print("AffixLibrary: Loaded %d affixes from %s" % [_by_id.size(), path])

# ── 計算裝備加成 ──────────────────────────────────
## 傳入 item_library 和 equipment，回傳加總後的 stat bonuses
## 格式：{ stat_key: total_value, ... }
func calc_bonuses(item_library: Array, equipment: Dictionary) -> Dictionary:
	var bonuses: Dictionary = {}

	for slot in equipment:
		var item_id: String = equipment[slot]
		if item_id == "":
			continue

		var item := _find_item_by_id(item_library, item_id)
		if item.is_empty():
			continue

		for mod in item.get("mods", []):
			var affix_id: String = mod.get("affix_id", "")
			var cost: int = mod.get("cost", 0)

			var affix := get_affix(affix_id)
			if affix == null:
				push_warning("Unknown affix: " + affix_id)
				continue

			var modifier = affix.get_modifier(cost)
			if modifier == null:
				continue

			# 處理 modifier（可能是 dict 或 array）
			_apply_modifier(modifier, bonuses)

	return bonuses

func _apply_modifier(modifier, bonuses: Dictionary) -> void:
	if modifier is Array:
		# 多 stat（如 堅韌）
		for mod in modifier:
			_apply_single_modifier(mod, bonuses)
	elif modifier is Dictionary:
		_apply_single_modifier(modifier, bonuses)

func _apply_single_modifier(mod: Dictionary, bonuses: Dictionary) -> void:
	var mod_type: String = mod.get("type", "add")

	# Special type 不參與數值計算
	if mod_type == "special":
		return

	var stat: String = mod.get("stat", "")
	var value = mod.get("value", 0)

	if stat == "":
		return

	# 目前只處理 add type（multiply/override 留給 StatEngine）
	match mod_type:
		"add":
			bonuses[stat] = bonuses.get(stat, 0) + int(value)
		"multiply":
			# TODO: 乘算需要特殊處理
			pass
		"override":
			# TODO: 覆蓋需要特殊處理
			pass

func _find_item_by_id(library: Array, id: String) -> Dictionary:
	for item in library:
		if item.get("id", "") == id:
			return item
	return {}
