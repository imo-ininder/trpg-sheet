## StatEngine.gd
## 核心數值計算引擎（純函式，無狀態）
##
## 收集所有 StatModifier 來源，按 ADD → MULTIPLY → OVERRIDE 順序解析，
## 輸出 Dictionary: stat_key -> int
##
## 鍵值對照表：
##   屬性         "STR","DEX","SKI","CON","RES","INT","WIS","CHA","SPI"
##   屬性加減值   "STR_modifier" ... (唯讀，由 base 推算)
##   HP/MP        "hp_max","hp_base","mp_max","mp_base"
##   複合數值     "compound_戰鬥" ...
##   抗性         "resist_抗毒素" ...
##   靈魂         "fortitude","spirit","soul"
##   戰鬥         "combat_attack","combat_dodge","combat_move"
##   物理/法術抗  "phys_resist","magic_resist"
##   元素抗性     "res_fire","res_ice","res_lightning","res_acid","res_sound",
##                "res_psychic","res_light","res_dark"

class_name StatEngine

# ── 主入口 ────────────────────────────────────────
## 傳入 CharacterData，回傳所有最終數值（int）
static func compute(data: CharacterData) -> Dictionary:
	var mods: Array = []
	_collect_base(data, mods)
	_collect_equipment(data, mods)
	# _collect_skills(data, mods)  # TODO: 技能系統
	return _resolve(data, mods)

# ── 收集 Base Stats ───────────────────────────────
static func _collect_base(data: CharacterData, mods: Array) -> void:
	# 屬性 base + temp（加減值由 _resolve 根據 base 推算，不作為獨立 mod）
	for attr in CharacterData.ATTR_NAMES:
		_add(mods, attr, data.attr_base.get(attr, 13), "attr_base")
		_add(mods, attr, data.attr_temp.get(attr, 0),  "attr_temp")

	# HP/MP 使用者設定的 bonus 與 cp（base = CON/RES total，在 _resolve 計算）
	_add(mods, "_hp_bonus_user", data.hp_bonus, "hp_bonus")
	_add(mods, "_hp_cp",         data.hp_cp,    "hp_cp")
	_add(mods, "_mp_bonus_user", data.mp_bonus, "mp_bonus")
	_add(mods, "_mp_cp",         data.mp_cp,    "mp_cp")

	# 複合數值調整（adj / temp）
	for name in CharacterData.COMPOUND_NAMES:
		_add(mods, "_compound_adj_"  + name, data.compound_adj.get(name, 0),  "compound_adj")
		_add(mods, "_compound_temp_" + name, data.compound_temp.get(name, 0), "compound_temp")

	# 抗性調整（adj / temp）
	for name in CharacterData.RESIST_NAMES:
		_add(mods, "_resist_adj_"  + name, data.resist_adj.get(name, 0),  "resist_adj")
		_add(mods, "_resist_temp_" + name, data.resist_temp.get(name, 0), "resist_temp")

	# 戰鬥數值 base
	_add(mods, "combat_attack", data.combat_attack, "combat_base")
	_add(mods, "combat_dodge",  data.combat_dodge,  "combat_base")
	_add(mods, "combat_move",   data.combat_move,   "combat_base")
	_add(mods, "phys_resist",   data.phys_resist,   "combat_base")
	_add(mods, "magic_resist",  data.magic_resist,  "combat_base")

	# 元素抗性 base（CharacterData 保證這些欄位存在）
	_add(mods, "res_fire",      data.res_fire,      "elem_base")
	_add(mods, "res_ice",       data.res_ice,       "elem_base")
	_add(mods, "res_lightning", data.res_lightning, "elem_base")
	_add(mods, "res_acid",      data.res_acid,      "elem_base")
	_add(mods, "res_sound",     data.res_sound,     "elem_base")
	_add(mods, "res_psychic",   data.res_psychic,   "elem_base")
	_add(mods, "res_light",     data.res_light,     "elem_base")
	_add(mods, "res_dark",      data.res_dark,      "elem_base")

# ── 收集裝備加成 ──────────────────────────────────
static func _collect_equipment(data: CharacterData, mods: Array) -> void:
	var bonuses: Dictionary = AffixLibrary.calc_bonuses(data.item_library, data.equipment)
	for sk in bonuses:
		# 判定抗性：resist_抗毒素 → _resist_equip_抗毒素
		if sk.begins_with("resist_"):
			var resist_name: String = sk.trim_prefix("resist_")
			_add(mods, "_resist_equip_" + resist_name, bonuses[sk], "equip")
		else:
			_add(mods, sk, bonuses[sk], "equip")

# ── 解析所有 Modifier → 最終數值 ─────────────────
static func _resolve(data: CharacterData, mods: Array) -> Dictionary:
	var adds:      Dictionary = {}
	var multiplies: Dictionary = {}
	var overrides: Dictionary = {}

	for mod: StatModifier in mods:
		match mod.op:
			StatModifier.Op.ADD:
				adds[mod.stat_key] = adds.get(mod.stat_key, 0.0) + mod.value
			StatModifier.Op.MULTIPLY:
				multiplies[mod.stat_key] = multiplies.get(mod.stat_key, 1.0) * mod.value
			StatModifier.Op.OVERRIDE:
				if not overrides.has(mod.stat_key) or mod.value > overrides[mod.stat_key]:
					overrides[mod.stat_key] = mod.value

	var result: Dictionary = {}

	# ── Step 1：屬性 total（base + temp + equip → modifier → multiply/override）
	for attr in CharacterData.ATTR_NAMES:
		var raw_base: int = data.attr_base.get(attr, 13)
		var attr_sum: int = int(adds.get(attr, float(raw_base)))  # base + temp + equip
		var modifier: int = int(ceil((attr_sum - 13) / 2.0))
		var total: int    = attr_sum + modifier
		# 套用 multiply / override
		if overrides.has(attr):
			total = int(overrides[attr])
		elif multiplies.has(attr):
			total = int(float(total) * float(multiplies[attr]))
		result[attr] = total
		result[attr + "_modifier"] = modifier

	# ── Step 2：衍生值（需要 attr totals）
	var con: int = result.get("CON", 13)
	var res: int = result.get("RES", 13)

	# 強韌 / 精神 / 靈魂 = attr_base * 5（不含裝備加成）
	result["fortitude"] = data.attr_base.get("CON", 13) * 5
	result["spirit"]    = data.attr_base.get("RES", 13) * 5
	result["soul"]      = data.attr_base.get("SPI", 13) * 5

	# HP / MP
	result["hp_base"] = con
	result["mp_base"] = res
	result["hp_max"]  = con \
		+ int(adds.get("_hp_bonus_user", 0.0)) \
		+ int(adds.get("_hp_cp",         0.0)) \
		+ int(adds.get("hp_bonus",       0.0))
	result["mp_max"]  = res \
		+ int(adds.get("_mp_bonus_user", 0.0)) \
		+ int(adds.get("_mp_cp",         0.0)) \
		+ int(adds.get("mp_bonus",       0.0))

	# ── Step 3：複合數值
	for name in CharacterData.COMPOUND_NAMES:
		var base_val: int  = _compound_base(name, result)
		var adj: int       = int(adds.get("_compound_adj_"  + name, 0.0))
		var temp: int      = int(adds.get("_compound_temp_" + name, 0.0))
		var total_val: int = base_val + adj + temp
		if multiplies.has("compound_" + name):
			total_val = int(float(total_val) * float(multiplies["compound_" + name]))
		if overrides.has("compound_" + name):
			total_val = int(overrides["compound_" + name])
		result["compound_" + name] = total_val

	# ── Step 4：判定抗性
	for name in CharacterData.RESIST_NAMES:
		var base_val: int  = _resist_base(name, result)
		var adj: int       = int(adds.get("_resist_adj_"   + name, 0.0))
		var temp: int      = int(adds.get("_resist_temp_"  + name, 0.0))
		var equip: int     = int(adds.get("_resist_equip_" + name, 0.0))
		var total_val: int = base_val + adj + temp + equip
		if overrides.has("resist_" + name):
			total_val = int(overrides["resist_" + name])
		result["resist_" + name] = total_val

	# ── Step 5：戰鬥數值 + 元素抗性（ADD → MULTIPLY → OVERRIDE）
	var flat_keys: Array = [
		"combat_attack", "combat_dodge", "combat_move",
		"phys_resist", "magic_resist",
		"res_fire", "res_ice", "res_lightning", "res_acid",
		"res_sound", "res_psychic", "res_light", "res_dark",
	]
	for k in flat_keys:
		if overrides.has(k):
			result[k] = int(overrides[k])
		else:
			result[k] = int(float(adds.get(k, 0.0)) * float(multiplies.get(k, 1.0)))

	return result

# ── 複合數值基礎公式（使用已計算的 attr totals）────
static func _compound_base(name: String, stats: Dictionary) -> int:
	match name:
		"戰鬥": return stats.get("STR",0) + stats.get("DEX",0) + stats.get("SKI",0)
		"運動": return stats.get("DEX",0) + stats.get("SKI",0) + stats.get("CON",0)
		"操作": return stats.get("SKI",0) + stats.get("INT",0) + stats.get("WIS",0)
		"感知": return stats.get("RES",0) + stats.get("INT",0) + stats.get("SPI",0)
		"知識": return int(floor((stats.get("INT",0) + stats.get("WIS",0)) * 1.5))
		"交涉": return stats.get("WIS",0) + stats.get("CHA",0) + stats.get("SPI",0)
	return 0

# ── 判定抗性基礎公式（使用已計算的 attr totals）────
static func _resist_base(name: String, stats: Dictionary) -> int:
	match name:
		"抗毒素": return stats.get("CON",0) + stats.get("RES",0)
		"抗控制": return stats.get("RES",0) + stats.get("WIS",0)
		"抗轉化": return stats.get("RES",0) * 2
		"抗噴吐": return stats.get("RES",0) + stats.get("DEX",0)
		"抗魔法": return stats.get("RES",0) + stats.get("INT",0)
	return 0

# ── 工具 ──────────────────────────────────────────
static func _add(mods: Array, k: String, v, src: String = "") -> void:
	mods.append(StatModifier.new(k, StatModifier.Op.ADD, float(v), src))
