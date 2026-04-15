## EquipTabPanel.gd
## 裝備 tab 的完整 UI（四欄：裝備槽 | 道具清單 | 道具編輯 | 道具檢視）
## 從 CharacterSheet 抽出，透過 signal 通知數值變動

class_name EquipTabPanel
extends Control

signal equip_changed  # 裝備變動時通知 CharacterSheet 重新計算

var _data: CharacterData = null

# ── UI refs ───────────────────────────────────────
var _equip_slot_opts: Dictionary = {}   # equip_slot -> OptionButton
var _item_list_vb: VBoxContainer
var _item_search_edit: LineEdit
var _item_filter_slot_opt: OptionButton
var _selected_item_index: int = -1
var _item_name_edit: LineEdit
var _item_slot_opt: OptionButton        # slot key OptionButton
var _item_mods_vb: VBoxContainer
var _item_mod_rows: Array = []          # [{affix_opt, tier_opt, row}]
var _item_viewer_label: RichTextLabel
var _main_hbox: HBoxContainer
var _max_bonus_slider: HSlider
var _max_bonus_val_lbl: Label
var _budget_label: Label

# ── 初始化 ────────────────────────────────────────
func _ready() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical   = Control.SIZE_EXPAND_FILL
	_build_ui()

func set_data(data: CharacterData) -> void:
	_data = data
	_refresh_equip_slots()
	_refresh_item_list()

# ── 建立 UI ───────────────────────────────────────
func _build_ui() -> void:
	_main_hbox = HBoxContainer.new()
	_main_hbox.add_theme_constant_override("separation", 12)
	_main_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_main_hbox.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	add_child(_main_hbox)
	_build_slots_panel(_main_hbox)
	_build_list_panel(_main_hbox)
	_build_editor_panel(_main_hbox)
	_build_viewer_panel(_main_hbox)

# ── 左側：裝備槽 ──────────────────────────────────
func _build_slots_panel(parent: HBoxContainer) -> void:
	var panel = _make_panel()
	panel.custom_minimum_size.x = 280
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(panel)
	var vb = _panel_vbox(panel)

	var title = _make_title("裝備槽")
	vb.add_child(title)

	# 直接放 VBoxContainer，不用 ScrollContainer
	var slots_vb = VBoxContainer.new()
	slots_vb.add_theme_constant_override("separation", 6)
	slots_vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slots_vb.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(slots_vb)

	for equip_slot in CharacterData.EQUIP_SLOTS:
		_build_slot_row(slots_vb, equip_slot)

func _build_slot_row(parent: VBoxContainer, equip_slot: String) -> void:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(row)

	var lbl = Label.new()
	lbl.text = equip_slot
	lbl.custom_minimum_size.x = 100
	lbl.add_theme_font_size_override("font_size", 13)
	row.add_child(lbl)

	var opt = OptionButton.new()
	opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	opt.add_theme_font_size_override("font_size", 12)
	opt.add_item("（空）")
	_equip_slot_opts[equip_slot] = opt
	opt.item_selected.connect(func(idx: int):
		if _data == null: return
		_data.equipment[equip_slot] = "" if idx == 0 else str(opt.get_item_metadata(idx))
		equip_changed.emit()
	)
	row.add_child(opt)

# ── 中間：道具清單 ────────────────────────────────
func _build_list_panel(parent: HBoxContainer) -> void:
	var panel = _make_panel()
	panel.custom_minimum_size.x = 320
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	parent.add_child(panel)
	var vb = _panel_vbox(panel)

	vb.add_child(_make_title("道具清單"))

	var search_hb = HBoxContainer.new()
	search_hb.add_theme_constant_override("separation", 6)
	search_hb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_child(search_hb)
	var slbl = Label.new(); slbl.text = "搜尋"
	slbl.add_theme_font_size_override("font_size", 12)
	search_hb.add_child(slbl)
	_item_search_edit = LineEdit.new()
	_item_search_edit.placeholder_text = "名稱..."
	_item_search_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_item_search_edit.add_theme_font_size_override("font_size", 12)
	_item_search_edit.text_changed.connect(func(_t): _refresh_item_list())
	search_hb.add_child(_item_search_edit)

	var filter_hb = HBoxContainer.new()
	filter_hb.add_theme_constant_override("separation", 6)
	filter_hb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_child(filter_hb)
	var flbl = Label.new(); flbl.text = "類型"
	flbl.add_theme_font_size_override("font_size", 12)
	filter_hb.add_child(flbl)
	_item_filter_slot_opt = OptionButton.new()
	_item_filter_slot_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_item_filter_slot_opt.add_theme_font_size_override("font_size", 12)
	_item_filter_slot_opt.add_item("全部")
	for key in ItemSlots.all_keys():
		_item_filter_slot_opt.add_item(ItemSlots.label(key))
	_item_filter_slot_opt.item_selected.connect(func(_i): _refresh_item_list())
	filter_hb.add_child(_item_filter_slot_opt)

	var scroll = ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vb.add_child(scroll)
	_item_list_vb = VBoxContainer.new()
	_item_list_vb.add_theme_constant_override("separation", 2)
	_item_list_vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_item_list_vb)

# ── 右側：道具編輯 ────────────────────────────────
func _build_editor_panel(parent: HBoxContainer) -> void:
	var panel = _make_panel()
	panel.custom_minimum_size.x = 320
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(panel)
	var vb = _panel_vbox(panel)

	vb.add_child(_make_title("道具編輯"))

	vb.add_child(_small_label("名稱"))
	_item_name_edit = LineEdit.new()
	_item_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_item_name_edit.add_theme_font_size_override("font_size", 12)
	vb.add_child(_item_name_edit)

	vb.add_child(_small_label("類型（slot）"))
	_item_slot_opt = OptionButton.new()
	_item_slot_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_item_slot_opt.add_theme_font_size_override("font_size", 12)
	for key in ItemSlots.all_keys():
		_item_slot_opt.add_item(ItemSlots.label(key) + "  [%s]" % key)
	# 預設選擇第一個（武器）
	_item_slot_opt.selected = 0
	# slot 改變時：清空已有 mod 欄位（affix 可選清單會跟著變）
	_item_slot_opt.item_selected.connect(func(_i): _clear_mod_rows())
	vb.add_child(_item_slot_opt)

	# 上限加值
	var mb_row = HBoxContainer.new()
	mb_row.add_theme_constant_override("separation", 6)
	mb_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_child(mb_row)
	var mb_lbl = _small_label("上限加值")
	mb_lbl.custom_minimum_size.x = 58
	mb_row.add_child(mb_lbl)
	_max_bonus_slider = HSlider.new()
	_max_bonus_slider.min_value = 0
	_max_bonus_slider.max_value = 18
	_max_bonus_slider.step = 1
	_max_bonus_slider.value = 0
	_max_bonus_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_max_bonus_slider.value_changed.connect(func(v: float):
		_max_bonus_val_lbl.text = str(int(v))
		_rebuild_all_mod_row_opts()
		_update_viewer()
	)
	mb_row.add_child(_max_bonus_slider)
	_max_bonus_val_lbl = Label.new()
	_max_bonus_val_lbl.text = "0"
	_max_bonus_val_lbl.custom_minimum_size.x = 18
	_max_bonus_val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_max_bonus_val_lbl.add_theme_font_size_override("font_size", 12)
	mb_row.add_child(_max_bonus_val_lbl)

	_budget_label = Label.new()
	_budget_label.text = "已用 0 / 0"
	_budget_label.add_theme_font_size_override("font_size", 11)
	vb.add_child(_budget_label)

	# Mods
	var mods_header = HBoxContainer.new()
	mods_header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_child(mods_header)
	var ml = Label.new(); ml.text = "詞條"
	ml.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ml.add_theme_font_size_override("font_size", 12)
	mods_header.add_child(ml)
	var add_mod_btn = Button.new()
	add_mod_btn.text = "+"
	add_mod_btn.custom_minimum_size.x = 24
	add_mod_btn.add_theme_font_size_override("font_size", 13)
	add_mod_btn.pressed.connect(func(): _add_mod_row(null))
	mods_header.add_child(add_mod_btn)

	var scroll = ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vb.add_child(scroll)

	_item_mods_vb = VBoxContainer.new()
	_item_mods_vb.add_theme_constant_override("separation", 4)
	_item_mods_vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_item_mods_vb)

	# 按鈕列：並排
	var btn_row = HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 6)
	btn_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_child(btn_row)

	var new_btn = Button.new()
	new_btn.text = "新增"
	new_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	new_btn.add_theme_font_size_override("font_size", 13)
	new_btn.pressed.connect(_create_new_item)
	btn_row.add_child(new_btn)

	var save_btn = Button.new()
	save_btn.text = "修改"
	save_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	save_btn.add_theme_font_size_override("font_size", 13)
	save_btn.pressed.connect(_save_item)
	btn_row.add_child(save_btn)

	var del_btn = Button.new()
	del_btn.text = "刪除"
	del_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	del_btn.add_theme_font_size_override("font_size", 13)
	del_btn.pressed.connect(_delete_item)
	btn_row.add_child(del_btn)

# ── 最右側：道具檢視（垂直顯示所有 stat）────────────
func _build_viewer_panel(parent: HBoxContainer) -> void:
	var panel = _make_panel()
	panel.custom_minimum_size.x = 280
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(panel)
	var vb = _panel_vbox(panel)

	vb.add_child(_make_title("道具詳情"))

	var scroll = ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vb.add_child(scroll)

	_item_viewer_label = RichTextLabel.new()
	_item_viewer_label.bbcode_enabled = true
	_item_viewer_label.fit_content = true
	_item_viewer_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_item_viewer_label.add_theme_font_size_override("normal_font_size", 12)
	scroll.add_child(_item_viewer_label)

# ── Mod 列（affix OptionButton + tier OptionButton + ✕）──

## 建立一個新 mod 列；existing_mod = null 時為空白列
func _add_mod_row(existing_mod) -> void:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 3)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_item_mods_vb.add_child(row)

	var affix_opt = OptionButton.new()
	affix_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	affix_opt.add_theme_font_size_override("font_size", 12)
	row.add_child(affix_opt)

	var tier_opt = OptionButton.new()
	tier_opt.custom_minimum_size.x = 60
	tier_opt.add_theme_font_size_override("font_size", 11)
	row.add_child(tier_opt)

	var row_entry = { "affix_opt": affix_opt, "tier_opt": tier_opt, "row": row }
	_item_mod_rows.append(row_entry)

	# affix 變更 → 重算所有列的可選清單（以排除其他列已選的）
	affix_opt.item_selected.connect(func(_i):
		_rebuild_all_mod_row_opts()
		_update_viewer()
	)
	tier_opt.item_selected.connect(func(_i): _update_viewer())

	# 先把所有列（含這列）更新一次，再套用 existing_mod
	_rebuild_all_mod_row_opts()

	if existing_mod != null:
		# 新格式：{affix_id, cost}
		var target_id: String = existing_mod.get("affix_id", "")
		var target_cost: int  = existing_mod.get("cost", 0)

		# 找到對應的 affix
		var target_affix := AffixLibrary.get_affix(target_id)
		if target_affix != null:
			# 選 affix（使用 affix_name）
			for i in affix_opt.item_count:
				if affix_opt.get_item_text(i) == target_affix.affix_name:
					affix_opt.selected = i
					break

			# 重建 tier
			tier_opt.clear()
			var costs := target_affix.get_all_costs()
			for cost in costs:
				tier_opt.add_item("+%d" % cost)
			# 選中對應的 cost
			for j in costs.size():
				if costs[j] == target_cost:
					tier_opt.selected = j
					break

	var del_btn = Button.new()
	del_btn.text = "✕"
	del_btn.custom_minimum_size.x = 22
	del_btn.add_theme_font_size_override("font_size", 10)
	del_btn.pressed.connect(func():
		_item_mod_rows.erase(row_entry)
		row.queue_free()
		_rebuild_all_mod_row_opts()
		_update_viewer()
	)
	row.add_child(del_btn)

	_update_viewer()

## 重算每個 mod 列的 affix 可選清單，排除其他列已選的 + 超出預算的；保留各列當前選擇
func _rebuild_all_mod_row_opts() -> void:
	var slot_key := _current_slot_key()
	var pool: Array = AffixLibrary.for_slot(slot_key) if slot_key != "" else AffixLibrary.all_affixes()

	# 快照所有列目前選中的 affix 名稱
	var sel_names: Array = []
	for entry in _item_mod_rows:
		var opt: OptionButton = entry["affix_opt"]
		sel_names.append(opt.get_item_text(opt.selected) if opt.selected >= 0 and opt.selected < opt.item_count else "")

	for i in _item_mod_rows.size():
		var entry    = _item_mod_rows[i]
		var affix_opt: OptionButton = entry["affix_opt"]
		var tier_opt:  OptionButton = entry["tier_opt"]
		var my_name: String = sel_names[i]

		# 過濾：只排除其他列已選的 affix
		var filtered: Array = pool.filter(func(a: AffixDef) -> bool:
			for j in sel_names.size():
				if j != i and sel_names[j] == a.affix_name:
					return false
			return true
		)

		# 重建 affix_opt，盡量保留原本選擇
		affix_opt.clear()
		var new_sel := 0
		for k in filtered.size():
			affix_opt.add_item(filtered[k].affix_name)
			if filtered[k].affix_name == my_name:
				new_sel = k
		affix_opt.selected = new_sel if filtered.size() > 0 else -1

		# 重建 tier_opt，顯示所有 tier；盡量保留原本的 index
		var prev_tier := tier_opt.selected
		tier_opt.clear()
		var affix := _affix_from_entry(entry)
		if affix != null:
			for c in affix.get_all_costs():
				tier_opt.add_item("+%d" % c)
			if prev_tier >= 0 and prev_tier < tier_opt.item_count:
				tier_opt.selected = prev_tier

## 以名稱 lookup 取得 affix（不依賴 index 對齊）
func _affix_from_entry(entry: Dictionary) -> AffixDef:
	var opt: OptionButton = entry["affix_opt"]
	if opt.selected < 0 or opt.selected >= opt.item_count: return null
	# 需要從 affix_name 轉為 id
	var affix_name := opt.get_item_text(opt.selected)
	# 遍歷找到匹配的 affix
	for affix: AffixDef in AffixLibrary.all_affixes():
		if affix.affix_name == affix_name:
			return affix
	return null

## 從當前編輯器狀態更新道具檢視 + 預算狀態列
func _update_viewer() -> void:
	# 更新預算狀態列
	if _budget_label != null:
		var max_b := _get_max_bonus()
		var used  := _get_used_cost()
		var budget_text := "已用 %d / %d" % [used, max_b]
		if used > max_b:
			budget_text += "  ⚠ 超出上限！"
		_budget_label.text = budget_text

	if _item_viewer_label == null: return
	var name_text := _item_name_edit.text.strip_edges() if _item_name_edit else ""
	var slot_key := _current_slot_key()
	var slot_text := ItemSlots.label(slot_key) if slot_key != "" else "（未指定）"
	var lines: Array = []
	if name_text != "":
		lines.append("[b]%s[/b]" % name_text)
	lines.append("[i]%s[/i]" % slot_text)
	if not _item_mod_rows.is_empty():
		lines.append("")
		for entry in _item_mod_rows:
			var tier_opt: OptionButton = entry["tier_opt"]
			var affix := _affix_from_entry(entry)
			if affix == null: continue
			var tier_idx := tier_opt.selected
			if tier_idx < 0 or tier_idx >= tier_opt.item_count: continue
			var cost: int = affix.get_all_costs()[tier_idx]
			var description: String = affix.get_description(cost)
			lines.append("%s" % description)
	_item_viewer_label.text = "\n\n".join(lines)

## 從已儲存的 item dict 更新道具檢視（inventory 選取時使用）
func _show_item_in_viewer(item: Dictionary) -> void:
	if _item_viewer_label == null: return
	var display_name: String = _item_display_name(item)
	var slot_key: String = item.get("slot", "")
	var slot_text := ItemSlots.label(slot_key) if slot_key != "" else "（未指定）"
	var lines: Array = []
	lines.append("[b]%s[/b]" % display_name)
	lines.append("[i]%s[/i]" % slot_text)
	var mods: Array = item.get("mods", [])
	if not mods.is_empty():
		lines.append("")
		for mod in mods:
			# 新格式：{affix_id, cost}
			var affix_id: String = mod.get("affix_id", "")
			var cost: int = mod.get("cost", 0)
			var affix := AffixLibrary.get_affix(affix_id)
			if affix == null:
				lines.append(affix_id + "（未知）")
				continue
			var description: String = affix.get_description(cost)
			lines.append("%s" % description)
	_item_viewer_label.text = "\n\n".join(lines)

func _get_max_bonus() -> int:
	if _max_bonus_slider == null: return 18
	return int(_max_bonus_slider.value)

## 計算所有 mod 列的 cost 加總
func _get_used_cost() -> int:
	var total := 0
	for entry in _item_mod_rows:
		var affix: AffixDef = _affix_from_entry(entry)
		if affix == null: continue
		var tier_opt: OptionButton = entry["tier_opt"]
		var tier_idx := tier_opt.selected
		if tier_idx >= 0 and tier_idx < tier_opt.item_count:
			total += affix.get_all_costs()[tier_idx]
	return total

func _current_slot_key() -> String:
	if _item_slot_opt == null or _item_slot_opt.selected < 0: return ""
	var label_with_key = _item_slot_opt.get_item_text(_item_slot_opt.selected)
	# 格式 "武器  [weapon]"，取括號內的 key
	var re = RegEx.new()
	re.compile("\\[(.+)\\]")
	var m = re.search(label_with_key)
	return m.get_string(1) if m else ""

func _clear_mod_rows() -> void:
	for entry in _item_mod_rows:
		entry["row"].queue_free()
	_item_mod_rows.clear()
	_update_viewer()

# ── 邏輯 ──────────────────────────────────────────
func _refresh_equip_slots() -> void:
	if _data == null: return

	# 收集所有已裝備的 item_id（用於排除重複裝備）
	var equipped_ids: Array = []
	for slot in CharacterData.EQUIP_SLOTS:
		var item_id: String = _data.equipment.get(slot, "")
		if item_id != "":
			equipped_ids.append(item_id)

	for equip_slot in CharacterData.EQUIP_SLOTS:
		if not _equip_slot_opts.has(equip_slot): continue
		var opt: OptionButton = _equip_slot_opts[equip_slot]
		opt.clear()
		opt.add_item("（空）")
		opt.set_item_metadata(0, "")

		# 取得當前槽位已裝備的 item_id
		var current_equipped_id: String = _data.equipment.get(equip_slot, "")

		for item in _data.item_library:
			var item_id: String = item.get("id", "")
			var item_slot: String = item.get("slot", "")

			# 檢查 1: 物品的 slot 必須與裝備槽位匹配
			if not _slot_matches(item_slot, equip_slot):
				continue

			# 檢查 2: 物品不能已經裝在其他槽位（除非是當前槽位）
			if item_id in equipped_ids and item_id != current_equipped_id:
				continue

			var idx := opt.item_count
			opt.add_item(_item_display_name(item))
			opt.set_item_metadata(idx, item_id)

		# 以 id 對齊目前裝備
		opt.selected = 0
		if current_equipped_id != "":
			for i in range(1, opt.item_count):
				if str(opt.get_item_metadata(i)) == current_equipped_id:
					opt.selected = i
					break

## 檢查物品 slot 是否能裝在指定的裝備槽位
func _slot_matches(item_slot: String, equip_slot: String) -> bool:
	# 使用 ItemSlots 查詢：item_slot（如 "weapon"）對應的 equip_slots（如 ["主手武器"]）
	# 是否包含 equip_slot（如 "主手武器"）
	var valid_equip_slots: Array = ItemSlots.equip_slots(item_slot)
	return equip_slot in valid_equip_slots

func _refresh_item_list() -> void:
	if _data == null or _item_list_vb == null: return
	for child in _item_list_vb.get_children():
		child.queue_free()

	var search := _item_search_edit.text.to_lower() if _item_search_edit else ""
	var filter_idx := _item_filter_slot_opt.selected if _item_filter_slot_opt else 0
	var slot_filter_label := "" if filter_idx == 0 else _item_filter_slot_opt.get_item_text(filter_idx)

	for i in _data.item_library.size():
		var item: Dictionary = _data.item_library[i]
		var display_name: String = _item_display_name(item)
		if search != "" and not display_name.to_lower().contains(search): continue
		if slot_filter_label != "":
			var ikey: String = item.get("slot", "")
			if ItemSlots.label(ikey) != slot_filter_label: continue

		var btn = Button.new()
		var slot_lbl := ItemSlots.label(item.get("slot","")) if item.get("slot","") != "" else "?"
		btn.text = "[%s]  %s" % [slot_lbl, display_name]
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.add_theme_font_size_override("font_size", 12)
		btn.pressed.connect(func(): _select_item(i))
		_item_list_vb.add_child(btn)

func _select_item(idx: int) -> void:
	if _data == null or idx < 0 or idx >= _data.item_library.size(): return
	_selected_item_index = idx
	var item: Dictionary = _data.item_library[idx]

	_item_name_edit.text = item.get("name", "")

	# slot opt（沒有「未指定」了，從 0 開始搜尋）
	var slot_key: String = item.get("slot", "")
	_item_slot_opt.selected = 0
	for i in range(_item_slot_opt.item_count):
		if ("  [%s]" % slot_key) in _item_slot_opt.get_item_text(i):
			_item_slot_opt.selected = i
			break

	if _max_bonus_slider != null:
		_max_bonus_slider.value = item.get("max_bonus", 0)
		if _max_bonus_val_lbl != null:
			_max_bonus_val_lbl.text = str(int(_max_bonus_slider.value))
	_clear_mod_rows()
	for mod in item.get("mods", []):
		_add_mod_row(mod)
	_show_item_in_viewer(item)

func _generate_id() -> String:
	return "item_%d_%d" % [Time.get_ticks_usec(), randi()]

## 計算道具的顯示名稱：name (+加值上限)
func _item_display_name(item: Dictionary) -> String:
	var base_name: String = item.get("name", "（未命名）")
	var max_bonus: int = item.get("max_bonus", 0)
	if max_bonus > 0:
		return "%s (+%d)" % [base_name, max_bonus]
	return base_name

## 新增道具：從編輯器建立新道具並加入 item_library
func _create_new_item() -> void:
	if _data == null: return

	var slot_key := _current_slot_key()
	var mods: Array = []
	for entry in _item_mod_rows:
		var tier_opt: OptionButton = entry["tier_opt"]
		var affix := _affix_from_entry(entry)
		if affix == null: continue
		var tier_idx := tier_opt.selected
		if tier_idx >= 0 and tier_idx < tier_opt.item_count:
			var cost: int = affix.get_all_costs()[tier_idx]
			mods.append({"affix_id": affix.id, "cost": cost})

	# 名稱：只儲存使用者輸入的部分，不帶 +N
	var iname := _item_name_edit.text.strip_edges()
	if iname == "":
		var type_label := ItemSlots.label(slot_key) if slot_key != "" else "道具"
		iname = type_label

	var item_id := _generate_id()
	var item := { "id": item_id, "name": iname, "slot": slot_key, "max_bonus": _get_max_bonus(), "mods": mods }
	_data.item_library.append(item)
	_selected_item_index = _data.item_library.size() - 1

	# 新增完成後重置編輯器
	_clear_editor()

	_refresh_item_list()
	_refresh_equip_slots()
	equip_changed.emit()

## 儲存修改：更新當前選中道具的 mods
func _save_item() -> void:
	if _data == null or _selected_item_index < 0 or _selected_item_index >= _data.item_library.size():
		return

	var slot_key := _current_slot_key()
	var mods: Array = []
	for entry in _item_mod_rows:
		var tier_opt: OptionButton = entry["tier_opt"]
		var affix := _affix_from_entry(entry)
		if affix == null: continue
		var tier_idx := tier_opt.selected
		if tier_idx >= 0 and tier_idx < tier_opt.item_count:
			var cost: int = affix.get_all_costs()[tier_idx]
			mods.append({"affix_id": affix.id, "cost": cost})

	# 名稱：只儲存使用者輸入的部分，不帶 +N
	var iname := _item_name_edit.text.strip_edges()
	if iname == "":
		var type_label := ItemSlots.label(slot_key) if slot_key != "" else "道具"
		iname = type_label

	# 保留既有 id
	var existing_id: String = _data.item_library[_selected_item_index].get("id", "")
	var item := { "id": existing_id, "name": iname, "slot": slot_key, "max_bonus": _get_max_bonus(), "mods": mods }
	_data.item_library[_selected_item_index] = item

	_refresh_item_list()
	_refresh_equip_slots()
	equip_changed.emit()

## 重置編輯器到初始狀態
func _clear_editor() -> void:
	_selected_item_index = -1
	if _item_name_edit:      _item_name_edit.text = ""
	if _item_slot_opt:       _item_slot_opt.selected = 0
	if _max_bonus_slider != null:
		_max_bonus_slider.value = 0
		if _max_bonus_val_lbl != null: _max_bonus_val_lbl.text = "0"
	_clear_mod_rows()
	_update_viewer()

func _delete_item() -> void:
	if _data == null or _selected_item_index < 0: return
	_data.item_library.remove_at(_selected_item_index)
	_clear_editor()
	_refresh_item_list()
	_refresh_equip_slots()
	equip_changed.emit()

# ── 輔助 ──────────────────────────────────────────
func _make_panel() -> PanelContainer:
	return PanelContainer.new()

func _panel_vbox(panel: PanelContainer) -> VBoxContainer:
	var vb = VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	panel.add_child(vb)
	return vb

func _make_title(text: String) -> Label:
	var lbl = Label.new()
	lbl.text = text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 13)
	return lbl

func _small_label(text: String) -> Label:
	var lbl = Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 11)
	return lbl
