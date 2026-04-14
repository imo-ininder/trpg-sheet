## CharacterSheet.gd
## 腳色卡的 UI，用 GDScript 動態建立所有欄位
## 對應 CharacterData 的資料結構

extends Control

var _data: CharacterData = null

# 用來追蹤每個 UI 元件，方便 flush_to_data 時回寫
var _attr_inputs: Dictionary = {}       # "STR_base", "STR_bonus" -> LineEdit（顯示）
var _attr_hidden: Dictionary = {}       # "STR_equip", "STR_temp" -> int（隱藏，留給裝備/技能連動）
var _attr_totals: Dictionary = {}       # "STR" -> Label
var _compound_hidden: Dictionary = {}   # "戰鬥_adj", "戰鬥_temp" -> int（隱藏）
var _compound_totals: Dictionary = {}
var _resist_hidden: Dictionary = {}     # "抗毒素_adj" ... -> int（隱藏）
var _resist_totals: Dictionary = {}
var _soul_labels: Dictionary = {}       # "強韌"/"精神"/"靈魂" -> Label（唯讀顯示）
var _elem_resist_inputs: Dictionary = {} # "法抗"/"物抗"/"火"... -> LineEdit
var _hp_inputs: Dictionary = {}
var _mp_inputs: Dictionary = {}
var _equip_inputs: Dictionary = {}      # slot_name -> OptionButton
var _skill_rows: Dictionary = {}        # cat -> Array of {name, diff, level LineEdit}
var _currency_display: Label            # 頂部貨幣顯示標籤（唯讀）
var _name_edit: LineEdit
var _race_edit: LineEdit
var _class_edit: LineEdit
var _age_edit: LineEdit
var _align_edit: LineEdit
var _cp_edit: LineEdit

# ── 建立 UI ──────────────────────────────────────
func _ready() -> void:
	_build_ui()

func _build_ui() -> void:
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left",  16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top",    8)
	margin.add_theme_constant_override("margin_bottom", 8)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(margin)

	var root = VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	margin.add_child(root)

	_build_topbar(root)
	_build_main_row(root)
	_build_skill_row(root)

# ── 頂部：基本資料 ────────────────────────────────
func _build_topbar(parent: VBoxContainer) -> void:
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	parent.add_child(hbox)

	# [欄位名, 變數名, 最小寬度]
	var fields = [
		["腳色名稱", "_name_edit", 150],
		["種族",     "_race_edit",  100],
		["職業",     "_class_edit", 100],
		["年齡",     "_age_edit",    60],
		["陣營",     "_align_edit",  80],
		["CP",       "_cp_edit",     60],
	]
	for f in fields:
		var vb = VBoxContainer.new()
		vb.custom_minimum_size.x = f[2]
		var lbl = Label.new()
		lbl.text = f[0]
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", 11)
		vb.add_child(lbl)
		var edit = LineEdit.new()
		edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
		vb.add_child(edit)
		set(f[1], edit)
		hbox.add_child(vb)

	# 彈性空白，把貨幣推到右側
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(spacer)

	# 貨幣顯示（靠右，唯讀）
	_currency_display = Label.new()
	_currency_display.text = "白金:0  金:0  銀:0  銅:0"
	_currency_display.add_theme_font_size_override("font_size", 12)
	_currency_display.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hbox.add_child(_currency_display)

# ── 主要區域（橫式四欄）────────────────────────────
func _build_main_row(parent: VBoxContainer) -> void:
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(hbox)

	# 欄 1：屬性（高度自適應，不撐滿整欄）
	var col1 = _make_panel()
	col1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col1.size_flags_vertical   = Control.SIZE_SHRINK_BEGIN
	_build_attrs(col1)
	hbox.add_child(col1)

	# 欄 2：複合/抗性/HP/MP
	var col2 = VBoxContainer.new()
	col2.add_theme_constant_override("separation", 8)
	col2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(col2)
	_build_compound(col2)
	_build_resists(col2)
	_build_resources(col2)

	# 欄 3：戰鬥數值 + 強韌/精神/靈魂
	var col3 = VBoxContainer.new()
	col3.add_theme_constant_override("separation", 8)
	col3.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(col3)
	_build_combat(col3)
	_build_phys_elem_resist(col3)
	_build_soul_stats(col3)

	# 欄 4：裝備（2 欄 × 10 行）
	var col4 = _make_panel()
	col4.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col4.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_build_equip(col4)
	hbox.add_child(col4)


# ── 屬性表（D&D 卡片式 3×3）────────────────────────
func _build_attrs(panel: PanelContainer) -> void:
	var vb = _panel_vbox(panel, "屬性")

	var grid = GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	vb.add_child(grid)

	for attr in CharacterData.ATTR_NAMES:
		# 隱藏值初始化（裝備/臨時，之後由裝備與技能系統寫入）
		_attr_hidden[attr + "_equip"] = 0
		_attr_hidden[attr + "_temp"]  = 0

		# 卡片外框
		var card = PanelContainer.new()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var card_vb = VBoxContainer.new()
		card_vb.add_theme_constant_override("separation", 2)
		card.add_child(card_vb)

		# 屬性名稱（小標題）
		var name_lbl = Label.new()
		name_lbl.text = attr
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.add_theme_font_size_override("font_size", 11)
		card_vb.add_child(name_lbl)

		# 總和（大數字，最顯眼）
		var total_lbl = Label.new()
		total_lbl.text = "13"
		total_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		total_lbl.add_theme_font_size_override("font_size", 26)
		_attr_totals[attr] = total_lbl
		card_vb.add_child(total_lbl)

		card_vb.add_child(HSeparator.new())

		# 基礎 / 加值 輸入格
		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		card_vb.add_child(row)

		for pair in [["base", "基礎"], ["bonus", "加值"]]:
			var suffix     = pair[0]
			var label_text = pair[1]
			var col = VBoxContainer.new()
			col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			col.add_theme_constant_override("separation", 1)
			var sub_lbl = Label.new()
			sub_lbl.text = label_text
			sub_lbl.add_theme_font_size_override("font_size", 9)
			sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			col.add_child(sub_lbl)
			var le = LineEdit.new()
			le.text = "13" if suffix == "base" else "0"
			le.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			le.alignment = HORIZONTAL_ALIGNMENT_CENTER
			le.add_theme_font_size_override("font_size", 11)
			_attr_inputs[attr + "_" + suffix] = le
			le.text_changed.connect(func(_v): _recalc_attr(attr))
			col.add_child(le)
			row.add_child(col)

		grid.add_child(card)

# ── 判定複合數值（卡片式 3×2）────────────────────────
func _build_compound(parent: VBoxContainer) -> void:
	var panel = _make_panel()
	panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	parent.add_child(panel)
	var vb = _panel_vbox(panel, "判定複合數值")

	var grid = GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	vb.add_child(grid)

	for name in CharacterData.COMPOUND_NAMES:
		_compound_hidden[name + "_adj"]  = 0
		_compound_hidden[name + "_temp"] = 0

		var card = PanelContainer.new()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var card_vb = VBoxContainer.new()
		card_vb.add_theme_constant_override("separation", 2)
		card.add_child(card_vb)

		var name_lbl = Label.new()
		name_lbl.text = name
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.add_theme_font_size_override("font_size", 10)
		card_vb.add_child(name_lbl)

		var total_lbl = Label.new()
		total_lbl.text = "39"
		total_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		total_lbl.add_theme_font_size_override("font_size", 22)
		_compound_totals[name] = total_lbl
		card_vb.add_child(total_lbl)

		grid.add_child(card)

# ── 抗性數值（卡片式 3×2）────────────────────────────
func _build_resists(parent: VBoxContainer) -> void:
	var panel = _make_panel()
	panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	parent.add_child(panel)
	var vb = _panel_vbox(panel, "抗性數值")

	var grid = GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	vb.add_child(grid)

	for name in CharacterData.RESIST_NAMES:
		_resist_hidden[name + "_adj"]  = 0
		_resist_hidden[name + "_temp"] = 0

		var card = PanelContainer.new()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var card_vb = VBoxContainer.new()
		card_vb.add_theme_constant_override("separation", 2)
		card.add_child(card_vb)

		var name_lbl = Label.new()
		name_lbl.text = name
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.add_theme_font_size_override("font_size", 10)
		card_vb.add_child(name_lbl)

		var total_lbl = Label.new()
		total_lbl.text = "26"
		total_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		total_lbl.add_theme_font_size_override("font_size", 22)
		_resist_totals[name] = total_lbl
		card_vb.add_child(total_lbl)

		grid.add_child(card)

# ── 生命 / 魔力（卡片式，current/max + 子欄位）──────────
func _build_resources(parent: VBoxContainer) -> void:
	var panel = _make_panel()
	panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	parent.add_child(panel)
	var vb = _panel_vbox(panel)

	var cards_hb = HBoxContainer.new()
	cards_hb.add_theme_constant_override("separation", 8)
	vb.add_child(cards_hb)

	for res in [["生命", "hp"], ["魔力", "mp"]]:
		var res_name = res[0]
		var key      = res[1]

		var card = PanelContainer.new()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var card_vb = VBoxContainer.new()
		card_vb.add_theme_constant_override("separation", 4)
		card.add_child(card_vb)

		# 名稱
		var name_lbl = Label.new()
		name_lbl.text = res_name
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.add_theme_font_size_override("font_size", 11)
		card_vb.add_child(name_lbl)

		# 現值 / 最大值 顯示列
		var cur_max_hb = HBoxContainer.new()
		cur_max_hb.alignment = BoxContainer.ALIGNMENT_CENTER
		cur_max_hb.add_theme_constant_override("separation", 4)
		card_vb.add_child(cur_max_hb)

		var cur_edit = LineEdit.new()
		cur_edit.text = "0"
		cur_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
		cur_edit.add_theme_font_size_override("font_size", 22)
		cur_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if key == "hp": _hp_inputs["current"] = cur_edit
		else:           _mp_inputs["current"] = cur_edit
		cur_max_hb.add_child(cur_edit)

		var slash = Label.new()
		slash.text = "/"
		slash.add_theme_font_size_override("font_size", 22)
		cur_max_hb.add_child(slash)

		var max_lbl = Label.new()
		max_lbl.text = "0"
		max_lbl.add_theme_font_size_override("font_size", 22)
		max_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if key == "hp": _hp_inputs["max_lbl"] = max_lbl
		else:           _mp_inputs["max_lbl"] = max_lbl
		cur_max_hb.add_child(max_lbl)

		card_vb.add_child(HSeparator.new())

		# 基礎 / 獎勵 / CP 子輸入（與屬性卡相同排版）
		var sub_row = HBoxContainer.new()
		sub_row.add_theme_constant_override("separation", 4)
		card_vb.add_child(sub_row)

		for pair in [["base", "基礎"], ["bonus", "獎勵"], ["cp", "CP"]]:
			var suffix     = pair[0]
			var label_text = pair[1]
			var col = VBoxContainer.new()
			col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			col.add_theme_constant_override("separation", 1)
			var sub_lbl = Label.new()
			sub_lbl.text = label_text
			sub_lbl.add_theme_font_size_override("font_size", 9)
			sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			col.add_child(sub_lbl)
			var le = LineEdit.new()
			le.text = "13" if suffix == "base" else "0"
			le.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			le.alignment = HORIZONTAL_ALIGNMENT_CENTER
			le.add_theme_font_size_override("font_size", 11)
			if key == "hp": _hp_inputs[suffix] = le
			else:           _mp_inputs[suffix] = le
			le.text_changed.connect(func(_v): _recalc_resource(key))
			col.add_child(le)
			sub_row.add_child(col)

		cards_hb.add_child(card)

# ── 戰鬥數值（攻擊/閃避/移動，卡片式 1×3）────────────
func _build_combat(parent: VBoxContainer) -> void:
	var panel = _make_panel()
	panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	parent.add_child(panel)
	var vb = _panel_vbox(panel)

	var grid = GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	vb.add_child(grid)

	for f in [["攻擊", "0"], ["閃避", "39"], ["移動", "1"]]:
		var card = PanelContainer.new()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var card_vb = VBoxContainer.new()
		card_vb.add_theme_constant_override("separation", 2)
		card.add_child(card_vb)

		var name_lbl = Label.new()
		name_lbl.text = f[0]
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.add_theme_font_size_override("font_size", 11)
		card_vb.add_child(name_lbl)

		var le = LineEdit.new()
		le.text = f[1]
		le.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		le.alignment = HORIZONTAL_ALIGNMENT_CENTER
		le.add_theme_font_size_override("font_size", 24)
		card_vb.add_child(le)

		grid.add_child(card)

# ── 物理 / 元素抗性（卡片式 4×2）────────────────────
func _build_phys_elem_resist(parent: VBoxContainer) -> void:
	var panel = _make_panel()
	panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	parent.add_child(panel)
	var vb = _panel_vbox(panel, "物理 / 元素抗性")

	var grid = GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	vb.add_child(grid)

	var items = [
		["法抗","0"],["物抗","0"],
		["火","0"],["冰","0"],["電","0"],["酸","0"],["音","0"],["心","0"],
	]
	for item in items:
		var name      = item[0]
		var default_v = item[1]

		var card = PanelContainer.new()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var card_vb = VBoxContainer.new()
		card_vb.add_theme_constant_override("separation", 2)
		card.add_child(card_vb)

		var name_lbl = Label.new()
		name_lbl.text = name
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.add_theme_font_size_override("font_size", 10)
		card_vb.add_child(name_lbl)

		var le = LineEdit.new()
		le.text = default_v
		le.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		le.alignment = HORIZONTAL_ALIGNMENT_CENTER
		le.add_theme_font_size_override("font_size", 20)
		_elem_resist_inputs[name] = le
		card_vb.add_child(le)

		grid.add_child(card)

# ── 強韌 / 精神 / 靈魂（卡片式 1×3）─────────────────
func _build_soul_stats(parent: VBoxContainer) -> void:
	var panel = _make_panel()
	panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	parent.add_child(panel)
	var vb = _panel_vbox(panel, "強韌 / 精神 / 靈魂")

	var grid = GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	vb.add_child(grid)

	for pair in [["強韌", "65"], ["精神", "65"], ["靈魂", "65"]]:
		var name      = pair[0]
		var default_v = pair[1]

		var card = PanelContainer.new()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var card_vb = VBoxContainer.new()
		card_vb.add_theme_constant_override("separation", 2)
		card.add_child(card_vb)

		var name_lbl = Label.new()
		name_lbl.text = name
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.add_theme_font_size_override("font_size", 11)
		card_vb.add_child(name_lbl)

		# 大數字唯讀顯示
		var lbl = Label.new()
		lbl.text = default_v
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", 24)
		_soul_labels[name] = lbl
		card_vb.add_child(lbl)

		grid.add_child(card)

# ── 裝備欄位（10×2 網格佈局，含 12 個主要 + 8 個擴充槽位）────
func _build_equip(panel: PanelContainer) -> void:
	var vb = _panel_vbox(panel, "裝備")

	# GridContainer：2 欄 × 10 行
	var grid = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 4)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(grid)

	# 合併所有槽位（12 個主要 + 8 個擴充）
	var all_slots = CharacterData.EQUIP_SLOTS + CharacterData.EQUIP_SLOTS_EXPANSION

	for slot in all_slots:
		var hbox = HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 6)
		hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL

		# 槽位名稱標籤（左側）
		var lbl = Label.new()
		lbl.text = slot
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", 10)
		lbl.custom_minimum_size.x = 90
		hbox.add_child(lbl)

		# 裝備選擇下拉選單（右側，文字置中）
		var opt = OptionButton.new()
		opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		opt.size_flags_vertical = Control.SIZE_EXPAND_FILL
		opt.add_item("（空）")
		opt.add_theme_font_size_override("font_size", 10)
		opt.alignment = HORIZONTAL_ALIGNMENT_CENTER
		_equip_inputs[slot] = opt
		hbox.add_child(opt)

		grid.add_child(hbox)

# ── 技能（六類各自獨立 panel，並排）────────────────────
func _build_skill_row(parent: VBoxContainer) -> void:
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	parent.add_child(hbox)

	for cat in CharacterData.SKILL_CATS:
		_build_one_skill_panel(hbox, cat)

# 獨立函式：確保每個 panel 的 cat / rows_vb 有各自獨立的 scope，
# 避免 GDScript for 迴圈的閉包捕獲問題（所有 lambda 會共用同一個迴圈變數）
func _build_one_skill_panel(hbox: HBoxContainer, cat: String) -> void:
	var panel = _make_panel()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	hbox.add_child(panel)
	var vb = _panel_vbox(panel)
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.size_flags_vertical = Control.SIZE_EXPAND_FILL

	# 類別標題列：左側文字，右側「+」按鈕（固定，不捲動）
	var title_row = HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 4)
	vb.add_child(title_row)

	var cat_lbl = Label.new()
	cat_lbl.text = cat
	cat_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cat_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cat_lbl.add_theme_font_size_override("font_size", 11)
	title_row.add_child(cat_lbl)

	var btn = Button.new()
	btn.text = "+"
	btn.custom_minimum_size.x = 24
	btn.add_theme_font_size_override("font_size", 13)
	title_row.add_child(btn)

	# 欄位標頭（固定，不捲動）
	var header = _make_hbox(["名稱", "難度", "等級", ""], [0, 36, 36, 22])
	vb.add_child(header)

	# ScrollContainer：標題/標頭固定，只有列在此捲動
	var scroll = ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	# 不設定固定高度，讓它根據視窗大小動態調整
	vb.add_child(scroll)

	var rows_vb = VBoxContainer.new()
	rows_vb.add_theme_constant_override("separation", 2)
	rows_vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# 重要：移除 vertical 的 expand flag，讓內容撐開 ScrollContainer
	rows_vb.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	scroll.add_child(rows_vb)

	# 初始化技能列表陣列
	_skill_rows[cat] = []

	# 預設 10 列
	for _i in range(10):
		_add_skill_row(cat, rows_vb)

	# 直接 lambda，cat / rows_vb 是函式參數，在各自 stack frame 中固定，不受閉包捕獲問題影響
	btn.pressed.connect(func(): _add_skill_row(cat, rows_vb))

func _add_skill_row(cat: String, container: VBoxContainer) -> void:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 3)

	var name_le = LineEdit.new()
	name_le.placeholder_text = "—"
	name_le.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_le.alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_le.add_theme_font_size_override("font_size", 11)
	name_le.custom_minimum_size.y = 28
	row.add_child(name_le)

	var diff_le = _make_number_edit(36)
	var lvl_le  = _make_number_edit(36)
	diff_le.custom_minimum_size.y = 28
	lvl_le.custom_minimum_size.y  = 28
	row.add_child(diff_le)
	row.add_child(lvl_le)

	var row_entry = {"name": name_le, "diff": diff_le, "level": lvl_le}

	# 刪除按鈕
	var del_btn = Button.new()
	del_btn.text = "✕"
	del_btn.custom_minimum_size.x = 22
	del_btn.add_theme_font_size_override("font_size", 10)
	del_btn.pressed.connect(func():
		_skill_rows[cat].erase(row_entry)
		row.queue_free()
	)
	row.add_child(del_btn)

	_skill_rows[cat].append(row_entry)
	container.add_child(row)

# ── 計算邏輯 ──────────────────────────────────────
func _recalc_attr(attr: String) -> void:
	var total = 0
	for suffix in ["base", "bonus"]:
		var le = _attr_inputs.get(attr + "_" + suffix)
		if le: total += int(le.text) if le.text.is_valid_int() else 0
	# 裝備與臨時修正（隱藏欄位，由外部系統寫入）
	total += _attr_hidden.get(attr + "_equip", 0)
	total += _attr_hidden.get(attr + "_temp",  0)
	if _attr_totals.has(attr):
		_attr_totals[attr].text = str(total)

func _recalc_compound(name: String) -> void:
	var adj  = _compound_hidden.get(name + "_adj",  0)
	var temp = _compound_hidden.get(name + "_temp", 0)
	if _compound_totals.has(name):
		_compound_totals[name].text = str(39 + adj + temp)

func _recalc_resist(name: String) -> void:
	var adj  = _resist_hidden.get(name + "_adj",  0)
	var temp = _resist_hidden.get(name + "_temp", 0)
	if _resist_totals.has(name):
		_resist_totals[name].text = str(26 + adj + temp)

func _recalc_resource(key: String) -> void:
	var inputs = _hp_inputs if key == "hp" else _mp_inputs
	var total = 0
	for s in ["base", "bonus", "cp"]:
		var le = inputs.get(s)
		if le: total += int(le.text) if le.text.is_valid_int() else 0
	inputs["max_lbl"].text = str(total)

# ── 資料載入 / 回寫 ───────────────────────────────
func load_data(data: CharacterData) -> void:
	_data = data
	_name_edit.text  = data.char_name
	_race_edit.text  = data.race
	_class_edit.text = data.char_class
	_age_edit.text   = data.age
	_align_edit.text = data.alignment
	_cp_edit.text    = str(data.cp)
	for attr in CharacterData.ATTR_NAMES:
		_attr_inputs[attr + "_base"].text  = str(data.attr_base.get(attr, 13))
		_attr_inputs[attr + "_bonus"].text = str(data.attr_bonus.get(attr, 0))
		# 裝備/臨時存入隱藏字典，之後系統連動時使用
		_attr_hidden[attr + "_equip"] = data.attr_equip.get(attr, 0)
		_attr_hidden[attr + "_temp"]  = data.attr_temp.get(attr, 0)
		_recalc_attr(attr)
	for name in CharacterData.COMPOUND_NAMES:
		_compound_hidden[name + "_adj"]  = data.compound_adj.get(name, 0)
		_compound_hidden[name + "_temp"] = data.compound_temp.get(name, 0)
		_recalc_compound(name)
	for name in CharacterData.RESIST_NAMES:
		_resist_hidden[name + "_adj"]  = data.resist_adj.get(name, 0)
		_resist_hidden[name + "_temp"] = data.resist_temp.get(name, 0)
		_recalc_resist(name)
	_soul_labels["強韌"].text = str(data.fortitude)
	_soul_labels["精神"].text = str(data.spirit)
	_soul_labels["靈魂"].text = str(data.soul)
	# 物理/元素抗性
	var elem_map = {
		"法抗": data.magic_resist, "物抗": data.phys_resist,
		"火": data.res_fire,  "冰": data.res_ice,  "電": data.res_lightning,
		"酸": data.res_acid,  "音": data.res_sound, "心": data.res_psychic,
	}
	for k in elem_map:
		if _elem_resist_inputs.has(k):
			_elem_resist_inputs[k].text = str(elem_map[k])
	# 貨幣顯示
	_currency_display.text = "白金:%d  金:%d  銀:%d  銅:%d" % [
		data.currency_platinum, data.currency_gold,
		data.currency_silver,   data.currency_copper
	]
	_hp_inputs["base"].text = str(data.hp_base)
	_hp_inputs["bonus"].text = str(data.hp_bonus)
	_hp_inputs["cp"].text = str(data.hp_cp)
	_hp_inputs["current"].text = str(data.hp_current)
	_recalc_resource("hp")
	_mp_inputs["base"].text = str(data.mp_base)
	_mp_inputs["bonus"].text = str(data.mp_bonus)
	_mp_inputs["cp"].text = str(data.mp_cp)
	_mp_inputs["current"].text = str(data.mp_current)
	_recalc_resource("mp")
	# 載入裝備（包含主要 + 擴充槽位）
	var all_slots = CharacterData.EQUIP_SLOTS + CharacterData.EQUIP_SLOTS_EXPANSION
	for slot in all_slots:
		if _equip_inputs.has(slot):
			var opt: OptionButton = _equip_inputs[slot]
			var item_name: String = data.equipment.get(slot, "")
			if item_name == "":
				opt.selected = 0
			else:
				var found := false
				for i in opt.item_count:
					if opt.get_item_text(i) == item_name:
						opt.selected = i
						found = true
						break
				if not found:
					opt.add_item(item_name)
					opt.selected = opt.item_count - 1

func flush_to_data() -> void:
	if _data == null: return
	_data.char_name  = _name_edit.text
	_data.race       = _race_edit.text
	_data.char_class = _class_edit.text
	_data.age        = _age_edit.text
	_data.alignment  = _align_edit.text
	_data.cp         = int(_cp_edit.text) if _cp_edit.text.is_valid_int() else 0
	for attr in CharacterData.ATTR_NAMES:
		_data.attr_base[attr]  = int(_attr_inputs[attr+"_base"].text)  if _attr_inputs[attr+"_base"].text.is_valid_int()  else 0
		_data.attr_bonus[attr] = int(_attr_inputs[attr+"_bonus"].text) if _attr_inputs[attr+"_bonus"].text.is_valid_int() else 0
		# 裝備/臨時從隱藏字典回寫，保留外部系統寫入的值
		_data.attr_equip[attr] = _attr_hidden.get(attr + "_equip", 0)
		_data.attr_temp[attr]  = _attr_hidden.get(attr + "_temp",  0)
	for name in CharacterData.COMPOUND_NAMES:
		_data.compound_adj[name]  = _compound_hidden.get(name + "_adj",  0)
		_data.compound_temp[name] = _compound_hidden.get(name + "_temp", 0)
	for name in CharacterData.RESIST_NAMES:
		_data.resist_adj[name]  = _resist_hidden.get(name + "_adj",  0)
		_data.resist_temp[name] = _resist_hidden.get(name + "_temp", 0)
	_data.fortitude = int(_soul_labels["強韌"].text) if _soul_labels["強韌"].text.is_valid_int() else 0
	_data.spirit    = int(_soul_labels["精神"].text) if _soul_labels["精神"].text.is_valid_int() else 0
	_data.soul      = int(_soul_labels["靈魂"].text) if _soul_labels["靈魂"].text.is_valid_int() else 0
	_data.magic_resist    = int(_elem_resist_inputs["法抗"].text) if _elem_resist_inputs["法抗"].text.is_valid_int() else 0
	_data.phys_resist     = int(_elem_resist_inputs["物抗"].text) if _elem_resist_inputs["物抗"].text.is_valid_int() else 0
	_data.res_fire        = int(_elem_resist_inputs["火"].text)   if _elem_resist_inputs["火"].text.is_valid_int()   else 0
	_data.res_ice         = int(_elem_resist_inputs["冰"].text)   if _elem_resist_inputs["冰"].text.is_valid_int()   else 0
	_data.res_lightning   = int(_elem_resist_inputs["電"].text)   if _elem_resist_inputs["電"].text.is_valid_int()   else 0
	_data.res_acid        = int(_elem_resist_inputs["酸"].text)   if _elem_resist_inputs["酸"].text.is_valid_int()   else 0
	_data.res_sound       = int(_elem_resist_inputs["音"].text)   if _elem_resist_inputs["音"].text.is_valid_int()   else 0
	_data.res_psychic     = int(_elem_resist_inputs["心"].text)   if _elem_resist_inputs["心"].text.is_valid_int()   else 0
	# 回寫裝備（包含主要 + 擴充槽位）
	var all_slots = CharacterData.EQUIP_SLOTS + CharacterData.EQUIP_SLOTS_EXPANSION
	for slot in all_slots:
		if _equip_inputs.has(slot):
			var opt: OptionButton = _equip_inputs[slot]
			var text := opt.get_item_text(opt.selected)
			_data.equipment[slot] = "" if text == "（空）" else text

# ── 輔助函式 ──────────────────────────────────────
func _make_panel() -> PanelContainer:
	var p = PanelContainer.new()
	return p

func _panel_vbox(panel: PanelContainer, _title: String = "") -> VBoxContainer:
	var vb = VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	panel.add_child(vb)
	return vb

func _make_label(text: String, min_width: int) -> Label:
	var lbl = Label.new()
	lbl.text = text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 12)
	if min_width > 0:
		lbl.custom_minimum_size.x = min_width
	return lbl

func _make_number_edit(min_width: int) -> LineEdit:
	var le = LineEdit.new()
	if min_width > 0:
		le.custom_minimum_size.x = min_width
	le.text = "0"
	le.alignment = HORIZONTAL_ALIGNMENT_CENTER
	le.add_theme_font_size_override("font_size", 11)
	return le

func _make_total_label(value: String, min_width: int) -> Label:
	var lbl = Label.new()
	lbl.text = value
	lbl.add_theme_font_size_override("font_size", 12)
	if min_width > 0:
		lbl.custom_minimum_size.x = min_width
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return lbl

func _make_hbox(labels: Array, widths: Array) -> HBoxContainer:
	var hb = HBoxContainer.new()
	hb.add_theme_constant_override("separation", 4)
	for i in labels.size():
		var lbl = Label.new()
		lbl.text = labels[i]
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", 10)
		if i < widths.size() and widths[i] > 0:
			lbl.custom_minimum_size.x = widths[i]
		elif i < widths.size() and widths[i] == 0:
			lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hb.add_child(lbl)
	return hb
