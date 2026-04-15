## CharacterSheet.gd
## 腳色卡的 UI，用 GDScript 動態建立所有欄位
## 對應 CharacterData 的資料結構

extends Control

var _data: CharacterData = null

# 用來追蹤每個 UI 元件，方便 flush_to_data 時回寫
var _attr_inputs: Dictionary = {}       # "STR_base", "STR_modifier" -> LineEdit / Label
var _attr_totals: Dictionary = {}       # "STR" -> Label
var _compound_totals: Dictionary = {}
var _resist_totals: Dictionary = {}
var _soul_labels: Dictionary = {}       # "強韌"/"精神"/"靈魂" -> Label（唯讀顯示）
var _elem_resist_inputs: Dictionary = {} # "法抗"/"物抗"/"火"... -> LineEdit
var _hp_inputs: Dictionary = {}
var _mp_inputs: Dictionary = {}
# 裝備 tab UI 已移至 EquipTabPanel（scripts/ui/EquipTabPanel.gd）

var _skill_rows: Dictionary = {}        # cat -> Array of {name, diff, level LineEdit}
var _skill_scrolls: Dictionary = {}     # cat -> ScrollContainer（用於動態調整高度）
var _currency_display: Label            # 頂部貨幣顯示標籤（唯讀）
var _name_edit: LineEdit
var _race_edit: LineEdit
var _class_edit: LineEdit
var _age_edit: LineEdit
var _align_edit: LineEdit
var _cp_edit: LineEdit

# 技能列常數
const SKILL_ROW_HEIGHT = 30  # 每行高度（28px + 2px separation）
const SKILL_HEADER_HEIGHT = 70  # 標題 + 標頭 + spacing
const SKILL_DEFAULT_ROWS = 10  # 預設行數

# ── 建立 UI ──────────────────────────────────────
func _ready() -> void:
	# 讓 CharacterSheet 本身填滿父容器（SheetContainer）
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
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
	_build_pages(root)

var _page_char: VBoxContainer
var _page_equip: VBoxContainer
var _equip_tab_panel: EquipTabPanel
var _special_abilities_label: RichTextLabel

func _build_pages(parent: VBoxContainer) -> void:
	_page_char = VBoxContainer.new()
	_page_char.add_theme_constant_override("separation", 8)
	_page_char.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_page_char.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	parent.add_child(_page_char)

	_page_equip = VBoxContainer.new()
	_page_equip.add_theme_constant_override("separation", 8)
	_page_equip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_page_equip.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	_page_equip.visible = false
	parent.add_child(_page_equip)

	_build_main_row(_page_char)
	_build_skill_row(_page_char)

	_equip_tab_panel = EquipTabPanel.new()
	_equip_tab_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_page_equip.add_child(_equip_tab_panel)
	_equip_tab_panel.equip_changed.connect(_recompute)

	_build_special_abilities_section(_page_equip)

func switch_tab(tab: String) -> void:
	_page_char.visible  = (tab == "腳色")
	_page_equip.visible = (tab == "裝備")

# ── 頂部：基本資料 ────────────────────────────────
func _build_topbar(parent: VBoxContainer) -> void:
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	hbox.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
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
	hbox.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	parent.add_child(hbox)

	# 欄 1：屬性（填滿高度）
	var col1 = _make_panel()
	col1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col1.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	_build_attrs(col1)
	hbox.add_child(col1)

	# 欄 2：複合/抗性/強韌精神靈魂（包裝在 Panel 內並填滿高度）
	var col2_panel = _make_panel()
	col2_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col2_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hbox.add_child(col2_panel)

	var col2 = VBoxContainer.new()
	col2.add_theme_constant_override("separation", 8)
	col2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col2.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col2_panel.add_child(col2)

	_build_compound_section(col2)
	_build_resists_section(col2)
	_build_soul_stats_section(col2)

	# 欄 3：HP/MP + 物理/元素抗性 + 戰鬥數值
	var col3 = VBoxContainer.new()
	col3.add_theme_constant_override("separation", 8)
	col3.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(col3)
	_build_resources(col3)
	_build_phys_elem_resist(col3)
	_build_combat(col3)

	# 欄 4：職業專屬 stats placeholder
	var col4 = _make_panel()
	col4.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col4.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	hbox.add_child(col4)
	var col4_vb = _panel_vbox(col4, "職業 Stats")
	var placeholder_lbl = Label.new()
	placeholder_lbl.text = "（待實作）"
	placeholder_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	placeholder_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	placeholder_lbl.size_flags_vertical  = Control.SIZE_EXPAND_FILL
	placeholder_lbl.add_theme_font_size_override("font_size", 13)
	col4_vb.add_child(placeholder_lbl)


# ── 屬性表（D&D 卡片式 3×3）────────────────────────
func _build_attrs(panel: PanelContainer) -> void:
	var vb = _panel_vbox(panel, "屬性")
	vb.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var grid = GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(grid)

	for attr in CharacterData.ATTR_NAMES:
		# 卡片外框
		var card = PanelContainer.new()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.size_flags_vertical = Control.SIZE_EXPAND_FILL
		var card_vb = VBoxContainer.new()
		card_vb.add_theme_constant_override("separation", 2)
		card_vb.size_flags_vertical = Control.SIZE_EXPAND_FILL
		card.add_child(card_vb)

		# 屬性名稱（更大）
		var name_lbl = Label.new()
		name_lbl.text = attr
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		name_lbl.add_theme_font_size_override("font_size", 15)
		name_lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
		card_vb.add_child(name_lbl)

		# 總和（大數字，最顯眼，填滿垂直空間）
		var total_lbl = Label.new()
		total_lbl.text = "13"
		total_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		total_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		total_lbl.add_theme_font_size_override("font_size", 24)
		total_lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_attr_totals[attr] = total_lbl
		card_vb.add_child(total_lbl)

		card_vb.add_child(HSeparator.new())

		# 基礎 / 加減值（縮小）
		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 3)
		card_vb.add_child(row)

		# 基礎值（可編輯）
		var base_col = VBoxContainer.new()
		base_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		base_col.add_theme_constant_override("separation", 1)
		var base_lbl = Label.new()
		base_lbl.text = "基礎"
		base_lbl.add_theme_font_size_override("font_size", 9)
		base_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		base_col.add_child(base_lbl)
		var base_le = LineEdit.new()
		base_le.text = "13"
		base_le.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		base_le.alignment = HORIZONTAL_ALIGNMENT_CENTER
		base_le.add_theme_font_size_override("font_size", 10)
		base_le.custom_minimum_size.y = 22
		_attr_inputs[attr + "_base"] = base_le
		base_le.text_changed.connect(func(_v): _recompute())
		base_col.add_child(base_le)
		row.add_child(base_col)

		# 加減值（唯讀，自動計算）
		var mod_col = VBoxContainer.new()
		mod_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		mod_col.add_theme_constant_override("separation", 1)
		var mod_lbl = Label.new()
		mod_lbl.text = "加減值"
		mod_lbl.add_theme_font_size_override("font_size", 9)
		mod_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		mod_col.add_child(mod_lbl)
		var mod_label = Label.new()
		mod_label.text = "0"
		mod_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		mod_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		mod_label.add_theme_font_size_override("font_size", 10)
		mod_label.custom_minimum_size.y = 22
		_attr_inputs[attr + "_modifier"] = mod_label  # 儲存為 Label
		mod_col.add_child(mod_label)
		row.add_child(mod_col)

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

		var total_lbl = Label.new()
		total_lbl.text = "39"
		total_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		total_lbl.add_theme_font_size_override("font_size", 18)
		_compound_totals[name] = total_lbl
		card_vb.add_child(total_lbl)

		grid.add_child(card)

# ── 技能複合判定 Section（帶標題）────────────────────
func _build_compound_section(parent: VBoxContainer) -> void:
	var section_vb = VBoxContainer.new()
	section_vb.add_theme_constant_override("separation", 4)
	section_vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	section_vb.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(section_vb)

	# 標題
	var title_lbl = Label.new()
	title_lbl.text = "技能複合判定"
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.add_theme_font_size_override("font_size", 13)
	section_vb.add_child(title_lbl)

	# 分隔線
	var sep = HSeparator.new()
	section_vb.add_child(sep)

	# 內容：使用原本的 _build_compound，但不包 panel
	var grid = GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	section_vb.add_child(grid)

	for name in CharacterData.COMPOUND_NAMES:
		var card = PanelContainer.new()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.size_flags_vertical = Control.SIZE_EXPAND_FILL
		var card_vb = VBoxContainer.new()
		card_vb.add_theme_constant_override("separation", 2)
		card.add_child(card_vb)

		var name_lbl = Label.new()
		name_lbl.text = name
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.add_theme_font_size_override("font_size", 11)
		card_vb.add_child(name_lbl)

		var total_lbl = Label.new()
		total_lbl.text = "0"
		total_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		total_lbl.add_theme_font_size_override("font_size", 18)
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

		var total_lbl = Label.new()
		total_lbl.text = "0"
		total_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		total_lbl.add_theme_font_size_override("font_size", 18)
		_resist_totals[name] = total_lbl
		card_vb.add_child(total_lbl)

		grid.add_child(card)

# ── 主要抗性 Section（帶標題）────────────────────────
func _build_resists_section(parent: VBoxContainer) -> void:
	var section_vb = VBoxContainer.new()
	section_vb.add_theme_constant_override("separation", 4)
	section_vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	section_vb.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(section_vb)

	# 標題
	var title_lbl = Label.new()
	title_lbl.text = "主要抗性"
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.add_theme_font_size_override("font_size", 13)
	section_vb.add_child(title_lbl)

	# 分隔線
	var sep = HSeparator.new()
	section_vb.add_child(sep)

	# 內容
	var grid = GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	section_vb.add_child(grid)

	for name in CharacterData.RESIST_NAMES:
		var card = PanelContainer.new()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.size_flags_vertical = Control.SIZE_EXPAND_FILL
		var card_vb = VBoxContainer.new()
		card_vb.add_theme_constant_override("separation", 2)
		card.add_child(card_vb)

		var name_lbl = Label.new()
		name_lbl.text = name
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.add_theme_font_size_override("font_size", 11)
		card_vb.add_child(name_lbl)

		var total_lbl = Label.new()
		total_lbl.text = "26"
		total_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		total_lbl.add_theme_font_size_override("font_size", 18)
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
		name_lbl.add_theme_font_size_override("font_size", 12)
		card_vb.add_child(name_lbl)

		# 現值 / 最大值 顯示列
		var cur_max_hb = HBoxContainer.new()
		cur_max_hb.alignment = BoxContainer.ALIGNMENT_CENTER
		cur_max_hb.add_theme_constant_override("separation", 2)
		card_vb.add_child(cur_max_hb)

		var cur_edit = LineEdit.new()
		cur_edit.text = "0"
		cur_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
		cur_edit.add_theme_font_size_override("font_size", 18)
		cur_edit.custom_minimum_size.x = 60
		if key == "hp": _hp_inputs["current"] = cur_edit
		else:           _mp_inputs["current"] = cur_edit
		cur_max_hb.add_child(cur_edit)

		var slash = Label.new()
		slash.text = "/"
		slash.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		slash.add_theme_font_size_override("font_size", 18)
		cur_max_hb.add_child(slash)

		var max_lbl = Label.new()
		max_lbl.text = "0"
		max_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		max_lbl.add_theme_font_size_override("font_size", 18)
		max_lbl.custom_minimum_size.x = 60
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
			sub_lbl.add_theme_font_size_override("font_size", 10)
			sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			col.add_child(sub_lbl)

			if suffix == "base":
				# 基礎值唯讀，由 CON/RES 自動計算
				var value_lbl = Label.new()
				value_lbl.text = "13"
				value_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				value_lbl.add_theme_font_size_override("font_size", 12)
				if key == "hp": _hp_inputs[suffix] = value_lbl
				else:           _mp_inputs[suffix] = value_lbl
				col.add_child(value_lbl)
			else:
				# 獎勵和 CP 可編輯
				var le = LineEdit.new()
				le.text = "0"
				le.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				le.alignment = HORIZONTAL_ALIGNMENT_CENTER
				le.add_theme_font_size_override("font_size", 12)
				if key == "hp": _hp_inputs[suffix] = le
				else:           _mp_inputs[suffix] = le
				le.text_changed.connect(func(_v): _recompute())
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
		name_lbl.add_theme_font_size_override("font_size", 12)
		card_vb.add_child(name_lbl)

		var le = LineEdit.new()
		le.text = f[1]
		le.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		le.alignment = HORIZONTAL_ALIGNMENT_CENTER
		le.add_theme_font_size_override("font_size", 18)
		card_vb.add_child(le)

		grid.add_child(card)

# ── 物理 / 元素抗性（卡片式 5×2）────────────────────
func _build_phys_elem_resist(parent: VBoxContainer) -> void:
	var panel = _make_panel()
	panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	parent.add_child(panel)
	var vb = _panel_vbox(panel, "物理 / 元素抗性")

	var grid = GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	vb.add_child(grid)

	var items = [
		["法抗","0"],["物抗","0"],["火","0"],["冰","0"],["電","0"],
		["酸","0"],["音","0"],["心","0"],["光","0"],["暗","0"],
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
		name_lbl.add_theme_font_size_override("font_size", 11)
		card_vb.add_child(name_lbl)

		var le = LineEdit.new()
		le.text = default_v
		le.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		le.alignment = HORIZONTAL_ALIGNMENT_CENTER
		le.add_theme_font_size_override("font_size", 16)
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
		name_lbl.add_theme_font_size_override("font_size", 12)
		card_vb.add_child(name_lbl)

		# 大數字唯讀顯示
		var lbl = Label.new()
		lbl.text = default_v
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", 18)
		_soul_labels[name] = lbl
		card_vb.add_child(lbl)

		grid.add_child(card)

# ── 特殊抗性 Section（帶標題）────────────────────────
func _build_soul_stats_section(parent: VBoxContainer) -> void:
	var section_vb = VBoxContainer.new()
	section_vb.add_theme_constant_override("separation", 4)
	section_vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	section_vb.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(section_vb)

	# 標題
	var title_lbl = Label.new()
	title_lbl.text = "特殊抗性"
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.add_theme_font_size_override("font_size", 13)
	section_vb.add_child(title_lbl)

	# 分隔線
	var sep = HSeparator.new()
	section_vb.add_child(sep)

	# 內容
	var grid = GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	section_vb.add_child(grid)

	for pair in [["強韌", "65"], ["精神", "65"], ["靈魂", "65"]]:
		var name      = pair[0]
		var default_v = pair[1]

		var card = PanelContainer.new()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.size_flags_vertical = Control.SIZE_EXPAND_FILL
		var card_vb = VBoxContainer.new()
		card_vb.add_theme_constant_override("separation", 2)
		card.add_child(card_vb)

		var name_lbl = Label.new()
		name_lbl.text = name
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.add_theme_font_size_override("font_size", 12)
		card_vb.add_child(name_lbl)

		# 大數字唯讀顯示
		var lbl = Label.new()
		lbl.text = default_v
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", 18)
		_soul_labels[name] = lbl
		lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
		card_vb.add_child(lbl)

		grid.add_child(card)

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
	# 設定初始最小高度 = 預設 10 行
	scroll.custom_minimum_size.y = SKILL_DEFAULT_ROWS * SKILL_ROW_HEIGHT
	vb.add_child(scroll)

	# 儲存 scroll 參考，用於動態調整高度
	_skill_scrolls[cat] = scroll

	var rows_vb = VBoxContainer.new()
	rows_vb.add_theme_constant_override("separation", 2)
	rows_vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# 重要：移除 vertical 的 expand flag，讓內容撐開 ScrollContainer
	rows_vb.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	scroll.add_child(rows_vb)

	# 初始化技能列表陣列
	_skill_rows[cat] = []

	# 預設 10 列
	for _i in range(SKILL_DEFAULT_ROWS):
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
		# 刪除後也要更新高度
		_update_skill_scroll_height(cat)
	)
	row.add_child(del_btn)

	_skill_rows[cat].append(row_entry)
	container.add_child(row)

	# 動態調整 ScrollContainer 最小高度
	_update_skill_scroll_height(cat)

# ── 動態調整技能 ScrollContainer 高度 ─────────────
func _update_skill_scroll_height(cat: String) -> void:
	if not _skill_scrolls.has(cat):
		return

	var scroll = _skill_scrolls[cat]
	var row_count = _skill_rows[cat].size()
	var needed_height = row_count * SKILL_ROW_HEIGHT

	# 取得 skill_row 的可用高度
	# 因為 panel 的父容器是 skill_row 的 HBoxContainer，它設定了 SIZE_EXPAND_FILL
	# 在 _ready 之後才能取得實際高度，所以這裡使用 deferred call
	await get_tree().process_frame

	var panel = scroll.get_parent().get_parent()  # scroll -> vb -> panel
	var available_height = panel.size.y - SKILL_HEADER_HEIGHT

	# 如果需要的高度小於可用高度，就設定為需要的高度
	# 如果需要的高度大於可用高度，就設定為可用高度（會出現捲軸）
	if available_height > 0:
		scroll.custom_minimum_size.y = min(needed_height, available_height)
	else:
		# 初始化階段，先設定為需要的高度
		scroll.custom_minimum_size.y = needed_height

# ── Stat Engine 整合 ──────────────────────────────
## 單一計算入口：flush → StatEngine.compute → _apply_stats
func _recompute() -> void:
	if _data == null: return
	flush_to_data()
	var stats := StatEngine.compute(_data)
	_apply_stats(stats)

## 將 StatEngine 輸出寫入所有唯讀顯示元件
func _apply_stats(stats: Dictionary) -> void:
	# 屬性 total + modifier
	for attr in CharacterData.ATTR_NAMES:
		if _attr_totals.has(attr):
			_attr_totals[attr].text = str(stats.get(attr, 0))
		var mod_lbl = _attr_inputs.get(attr + "_modifier")
		if mod_lbl:
			mod_lbl.text = str(stats.get(attr + "_modifier", 0))
	# HP / MP readonly labels
	if _hp_inputs.has("base"):    _hp_inputs["base"].text    = str(stats.get("hp_base", 0))
	if _hp_inputs.has("max_lbl"): _hp_inputs["max_lbl"].text = str(stats.get("hp_max",  0))
	if _mp_inputs.has("base"):    _mp_inputs["base"].text    = str(stats.get("mp_base", 0))
	if _mp_inputs.has("max_lbl"): _mp_inputs["max_lbl"].text = str(stats.get("mp_max",  0))
	# 複合數值
	for name in CharacterData.COMPOUND_NAMES:
		if _compound_totals.has(name):
			_compound_totals[name].text = str(stats.get("compound_" + name, 0))
	# 判定抗性
	for name in CharacterData.RESIST_NAMES:
		if _resist_totals.has(name):
			_resist_totals[name].text = str(stats.get("resist_" + name, 0))
	# 靈魂數值
	if _soul_labels.has("強韌"): _soul_labels["強韌"].text = str(stats.get("fortitude", 0))
	if _soul_labels.has("精神"): _soul_labels["精神"].text = str(stats.get("spirit",    0))
	if _soul_labels.has("靈魂"): _soul_labels["靈魂"].text = str(stats.get("soul",      0))


# ── 資料載入 / 回寫 ───────────────────────────────
func load_data(data: CharacterData) -> void:
	_data = data
	_name_edit.text  = data.char_name
	_race_edit.text  = data.race
	_class_edit.text = data.char_class
	_age_edit.text   = data.age
	_align_edit.text = data.alignment
	_cp_edit.text    = str(data.cp)
	# 屬性 base（唯讀欄位由 _recompute → _apply_stats 更新）
	for attr in CharacterData.ATTR_NAMES:
		_attr_inputs[attr + "_base"].text = str(data.attr_base.get(attr, 13))

	# 物理/元素抗性（user-editable，由使用者直接輸入）
	var elem_keys := {
		"法抗": data.magic_resist, "物抗": data.phys_resist,
		"火": data.res_fire,  "冰": data.res_ice,  "電": data.res_lightning,
		"酸": data.res_acid,  "音": data.res_sound, "心": data.res_psychic,
		"光": data.res_light, "暗": data.res_dark,
	}
	for k in elem_keys:
		if _elem_resist_inputs.has(k):
			_elem_resist_inputs[k].text = str(elem_keys[k])

	# 貨幣顯示
	_currency_display.text = "白金:%d  金:%d  銀:%d  銅:%d" % [
		data.currency_platinum, data.currency_gold,
		data.currency_silver,   data.currency_copper
	]

	# HP/MP user-input 欄位
	_hp_inputs["bonus"].text = str(data.hp_bonus)
	_hp_inputs["cp"].text    = str(data.hp_cp)
	_hp_inputs["current"].text = str(data.hp_current)
	_mp_inputs["bonus"].text = str(data.mp_bonus)
	_mp_inputs["cp"].text    = str(data.mp_cp)
	_mp_inputs["current"].text = str(data.mp_current)

	# 裝備 tab
	if _equip_tab_panel:
		_equip_tab_panel.set_data(data)

	# 統一觸發全量計算，更新所有唯讀顯示
	_recompute()

func flush_to_data() -> void:
	if _data == null: return
	_data.char_name  = _name_edit.text
	_data.race       = _race_edit.text
	_data.char_class = _class_edit.text
	_data.age        = _age_edit.text
	_data.alignment  = _align_edit.text
	_data.cp         = int(_cp_edit.text) if _cp_edit.text.is_valid_int() else 0
	for attr in CharacterData.ATTR_NAMES:
		_data.attr_base[attr]  = int(_attr_inputs[attr+"_base"].text) if _attr_inputs[attr+"_base"].text.is_valid_int() else 13
		_data.attr_bonus[attr] = _data.attr_modifier(attr)  # modifier 由 base 推算
	# elem/phys/magic resists（user-editable base 值，StatEngine 會加上裝備加成）
	_data.magic_resist    = int(_elem_resist_inputs["法抗"].text) if _elem_resist_inputs["法抗"].text.is_valid_int() else 0
	_data.phys_resist     = int(_elem_resist_inputs["物抗"].text) if _elem_resist_inputs["物抗"].text.is_valid_int() else 0
	_data.res_fire        = int(_elem_resist_inputs["火"].text)   if _elem_resist_inputs["火"].text.is_valid_int()   else 0
	_data.res_ice         = int(_elem_resist_inputs["冰"].text)   if _elem_resist_inputs["冰"].text.is_valid_int()   else 0
	_data.res_lightning   = int(_elem_resist_inputs["電"].text)   if _elem_resist_inputs["電"].text.is_valid_int()   else 0
	_data.res_acid        = int(_elem_resist_inputs["酸"].text)   if _elem_resist_inputs["酸"].text.is_valid_int()   else 0
	_data.res_sound       = int(_elem_resist_inputs["音"].text)   if _elem_resist_inputs["音"].text.is_valid_int()   else 0
	_data.res_psychic     = int(_elem_resist_inputs["心"].text)   if _elem_resist_inputs["心"].text.is_valid_int()   else 0
	_data.res_light       = int(_elem_resist_inputs["光"].text)   if _elem_resist_inputs["光"].text.is_valid_int()   else 0
	_data.res_dark        = int(_elem_resist_inputs["暗"].text)   if _elem_resist_inputs["暗"].text.is_valid_int()   else 0
	# 裝備槽 / 道具庫：互動時已即時寫入 _data，無需額外回寫


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
