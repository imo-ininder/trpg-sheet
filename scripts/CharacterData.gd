## CharacterData.gd
## 角色的所有資料，負責儲存與計算

class_name CharacterData
extends Resource

# ── 基本資訊 ──────────────────────────────────────
@export var char_name: String = ""
@export var race: String = ""
@export var char_class: String = ""
@export var age: String = ""
@export var alignment: String = ""
@export var cp: int = 0

# ── 屬性（每項有 base / equip / temp / bonus，總和自動算）──
const ATTR_NAMES = ["STR", "DEX", "SKI", "CON", "RES", "INT", "WIS", "CHA", "SPI"]

@export var attr_base:  Dictionary = { "STR":13,"DEX":13,"SKI":13,"CON":13,"RES":13,"INT":13,"WIS":13,"CHA":13,"SPI":13 }
@export var attr_equip: Dictionary = { "STR":0,"DEX":0,"SKI":0,"CON":0,"RES":0,"INT":0,"WIS":0,"CHA":0,"SPI":0 }
@export var attr_temp:  Dictionary = { "STR":0,"DEX":0,"SKI":0,"CON":0,"RES":0,"INT":0,"WIS":0,"CHA":0,"SPI":0 }
@export var attr_bonus: Dictionary = { "STR":0,"DEX":0,"SKI":0,"CON":0,"RES":0,"INT":0,"WIS":0,"CHA":0,"SPI":0 }

func attr_total(attr: String) -> int:
	return attr_base.get(attr,0) + attr_equip.get(attr,0) + attr_temp.get(attr,0) + attr_bonus.get(attr,0)

# 加減值計算：(基礎值 - 13) / 2，無條件進位
func attr_modifier(attr: String) -> int:
	var base = attr_base.get(attr, 13)
	return int(ceil((base - 13) / 2.0))

# ── 判定複合數值 ──────────────────────────────────
const COMPOUND_NAMES = ["戰鬥", "運動", "操作", "感知", "知識", "交涉"]

@export var compound_adj:  Dictionary = { "戰鬥":0,"運動":0,"操作":0,"感知":0,"知識":0,"交涉":0 }
@export var compound_temp: Dictionary = { "戰鬥":0,"運動":0,"操作":0,"感知":0,"知識":0,"交涉":0 }

# 判定複合數值計算（使用總和，即最終數值）
func calc_compound(name: String) -> int:
	var base_value = 0
	match name:
		"戰鬥":
			base_value = attr_total("STR") + attr_total("DEX") + attr_total("SKI")
		"運動":
			base_value = attr_total("DEX") + attr_total("SKI") + attr_total("CON")
		"操作":
			base_value = attr_total("SKI") + attr_total("INT") + attr_total("WIS")
		"感知":
			base_value = attr_total("RES") + attr_total("INT") + attr_total("SPI")
		"知識":
			base_value = int(floor((attr_total("INT") + attr_total("WIS")) * 1.5))
		"交涉":
			base_value = attr_total("WIS") + attr_total("CHA") + attr_total("SPI")

	return base_value + compound_adj.get(name, 0) + compound_temp.get(name, 0)

func compound_total(name: String) -> int:
	return calc_compound(name)

# ── 抗性數值 ──────────────────────────────────────
const RESIST_NAMES = ["抗毒素", "抗控制", "抗轉化", "抗噴吐", "抗魔法"]

@export var resist_adj:  Dictionary = { "抗毒素":0,"抗控制":0,"抗轉化":0,"抗噴吐":0,"抗魔法":0 }
@export var resist_temp: Dictionary = { "抗毒素":0,"抗控制":0,"抗轉化":0,"抗噴吐":0,"抗魔法":0 }

# 抗性數值計算（使用屬性總和）
func calc_resist(name: String) -> int:
	var base_value = 0
	match name:
		"抗毒素":
			base_value = attr_total("CON") + attr_total("RES")
		"抗控制":
			base_value = attr_total("RES") + attr_total("WIS")
		"抗轉化":
			base_value = attr_total("RES") * 2
		"抗噴吐":
			base_value = attr_total("RES") + attr_total("DEX")
		"抗魔法":
			base_value = attr_total("RES") + attr_total("INT")

	return base_value + resist_adj.get(name, 0) + resist_temp.get(name, 0)

func resist_total(name: String) -> int:
	return calc_resist(name)

# ── 生命 / 魔力 ───────────────────────────────────
@export var hp_base: int = 13
@export var hp_bonus: int = 0
@export var hp_cp: int = 0
@export var hp_current: int = 0

@export var mp_base: int = 13
@export var mp_bonus: int = 0
@export var mp_cp: int = 0
@export var mp_current: int = 0

func hp_max() -> int: return hp_base + hp_bonus + hp_cp
func mp_max() -> int: return mp_base + mp_bonus + mp_cp

# ── 戰鬥數值 ──────────────────────────────────────
@export var combat_attack: int = 0
@export var combat_dodge: int = 39
@export var combat_move: int = 1
@export var magic_resist: int = 0
@export var phys_resist: int = 0
@export var fortitude: int = 65
@export var spirit: int = 65
@export var soul: int = 65

# 強韌/精神/靈魂自動計算
func calc_fortitude() -> int: return attr_base.get("CON", 13) * 5
func calc_spirit() -> int: return attr_base.get("RES", 13) * 5
func calc_soul() -> int: return attr_base.get("SPI", 13) * 5

# 元素抗性
@export var res_fire: int = 0
@export var res_ice: int = 0
@export var res_lightning: int = 0
@export var res_acid: int = 0
@export var res_sound: int = 0
@export var res_psychic: int = 0
@export var res_light: int = 0
@export var res_dark: int = 0

# ── 施法 ──────────────────────────────────────────
@export var caster_level: int = 0
@export var spell_slots: int = 0
@export var meditation_cp: String = "0hr/4"
@export var cast_base_rate: int = 39
@export var cast_cumulative_penalty: int = 0

func cast_success_rate(this_ring: int) -> int:
	return cast_base_rate - cast_cumulative_penalty - this_ring

# ── 裝備欄位 ──────────────────────────────────────
const EQUIP_SLOTS = ["頭環","手套","手環","身體（盔甲）","披風","腰帶","鞋子","項鍊","戒指 1","戒指 2","主手","副手"]
# 8 個保留擴充位（尚未顯示）
const EQUIP_SLOTS_EXPANSION = ["擴充 1","擴充 2","擴充 3","擴充 4","擴充 5","擴充 6","擴充 7","擴充 8"]

@export var equipment: Dictionary = {}  # slot_name -> item_name

# ── 技能 ──────────────────────────────────────────
const SKILL_CATS = ["戰鬥類","運動類","操作類","感知類","知識類","交涉類"]

# 格式：{ "戰鬥類": [ {name, difficulty, level}, ... ], ... }
@export var skills: Dictionary = {}

func _init():
	for cat in SKILL_CATS:
		skills[cat] = []
	# 初始化所有裝備槽位（主要 + 擴充）
	for slot in EQUIP_SLOTS:
		equipment[slot] = ""
	for slot in EQUIP_SLOTS_EXPANSION:
		equipment[slot] = ""

# ── 其他效果 ──────────────────────────────────────
# 格式：[ {name, effect, note}, ... ]
@export var other_effects: Array = []

# ── 貨幣 ──────────────────────────────────────────
@export var currency_platinum: int = 0
@export var currency_gold: int = 332
@export var currency_silver: int = 50
@export var currency_copper: int = 0

# ── 道具庫 ────────────────────────────────────────
# 每個 item：{ "name": String, "base_type": String, "slot": String, "mods": Array }
@export var item_library: Array = []

# ── 備註 ──────────────────────────────────────────
@export var notes: String = ""
