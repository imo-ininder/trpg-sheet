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

# ── 裝備 StatModifier 收集 ────────────────────────
## 傳入 item_library 和 equipment，回傳所有 StatModifier
## 支援 ADD / MULTIPLY / OVERRIDE / EXTRA_SKILL 全類型
func collect_modifiers(item_library: Array, equipment: Dictionary) -> Array:
	var result: Array = []
	for slot in equipment:
		var item_id: String = equipment[slot]
		if item_id == "": continue
		var item := _find_item_by_id(item_library, item_id)
		if item.is_empty(): continue
		for mod_entry in item.get("mods", []):
			var affix_id: String = mod_entry.get("affix_id", "")
			var cost: int = mod_entry.get("cost", 0)
			var affix := get_affix(affix_id)
			if affix == null:
				push_warning("AffixLibrary: unknown affix '%s'" % affix_id)
				continue
			var modifier = affix.get_modifier(cost)
			if modifier == null: continue
			_collect_from_modifier(modifier, result, "equip")
	return result

func _collect_from_modifier(modifier, result: Array, source: String) -> void:
	if modifier is Array:
		for m in modifier:
			_collect_single_mod(m, result, source)
	elif modifier is Dictionary:
		_collect_single_mod(modifier, result, source)

func _collect_single_mod(mod: Dictionary, result: Array, source: String) -> void:
	var mod_type: String = mod.get("type", "add")
	match mod_type:
		"add":
			var stat: String = mod.get("stat", "")
			if stat != "":
				result.append(StatModifier.new(stat, StatModifier.Op.ADD, float(mod.get("value", 0)), source))
		"multiply":
			var stat: String = mod.get("stat", "")
			if stat != "":
				result.append(StatModifier.new(stat, StatModifier.Op.MULTIPLY, float(mod.get("value", 1)), source))
		"override":
			var stat: String = mod.get("stat", "")
			if stat != "":
				result.append(StatModifier.new(stat, StatModifier.Op.OVERRIDE, float(mod.get("value", 0)), source))
		"extra_skill":
			var key: String = mod.get("key", "")
			if key != "":
				result.append(StatModifier.new(key, StatModifier.Op.EXTRA_SKILL, float(mod.get("count", 1)), source))
		"special":
			pass  # 純效果，不影響數值，略過

func _find_item_by_id(library: Array, id: String) -> Dictionary:
	for item in library:
		if item.get("id", "") == id:
			return item
	return {}
