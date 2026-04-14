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
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	add_child(hbox)
	_build_slots_panel(hbox)
	_build_list_panel(hbox)
	_build_editor_panel(hbox)
	_build_viewer_panel(hbox)

# ── 左側：裝備槽 ──────────────────────────────────
func _build_slots_panel(parent: HBoxContainer) -> void:
	var panel = _make_panel()
	panel.custom_minimum_size.x = 240
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(panel)
	var vb = _panel_vbox(panel)

	var title = _make_title("裝備槽")
	vb.add_child(title)

	var scroll = ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vb.add_child(scroll)

	var slots_vb = VBoxContainer.new()
	slots_vb.add_theme_constant_override("separation", 4)
	slots_vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(slots_vb)

	for equip_slot in CharacterData.EQUIP_SLOTS:
		_build_slot_row(slots_vb, equip_slot)

func _build_slot_row(parent: VBoxContainer, equip_slot: String) -> void:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(row)

	var lbl = Label.new()
	lbl.text = equip_slot
	lbl.custom_minimum_size.x = 90
	lbl.add_theme_font_size_override("font_size", 11)
	row.add_child(lbl)

	var opt = OptionButton.new()
	opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	opt.add_theme_font_size_override("font_size", 11)
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
	slbl.add_theme_font_size_override("font_size", 11)
	search_hb.add_child(slbl)
	_item_search_edit = LineEdit.new()
	_item_search_edit.placeholder_text = "名稱..."
	_item_search_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_item_search_edit.add_theme_font_size_override("font_size", 11)
	_item_search_edit.text_changed.connect(func(_t): _refresh_item_list())
	search_hb.add_child(_item_search_edit)

	var filter_hb = HBoxContainer.new()
	filter_hb.add_theme_constant_override("separation", 6)
	filter_hb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_child(filter_hb)
	var flbl = Label.new(); flbl.text = "類型"
	flbl.add_theme_font_size_override("font_size", 11)
	filter_hb.add_child(flbl)
	_item_filter_slot_opt = OptionButton.new()
	_item_filter_slot_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_item_filter_slot_opt.add_theme_font_size_override("font_size", 11)
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

	var new_btn = Button.new()
	new_btn.text = "+ 新增道具"
	new_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	new_btn.add_theme_font_size_override("font_size", 12)
	new_btn.pressed.connect(_new_item)
	vb.add_child(new_btn)

# ── 右側：道具編輯 ────────────────────────────────
func _build_editor_panel(parent: HBoxContainer) -> void:
	var panel = _make_panel()
	panel.custom_minimum_size.x = 280
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
	_item_slot_opt.add_theme_font_size_override("font_size", 11)
	_item_slot_opt.add_item("（未指定）")
	for key in ItemSlots.all_keys():
		_item_slot_opt.add_item(ItemSlots.label(key) + "  [%s]" % key)
	# slot 改變時：清空已有 mod 欄位（affix 可選清單會跟著變）
	_item_slot_opt.item_selected.connect(func(_i): _clear_mod_rows())
	vb.add_child(_item_slot_opt)

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

	_item_mods_vb = VBoxContainer.new()
	_item_mods_vb.add_theme_constant_override("separation", 3)
	_item_mods_vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_child(_item_mods_vb)

	var spacer = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(spacer)

	var save_btn = Button.new()
	save_btn.text = "儲存"
	save_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	save_btn.pressed.connect(_save_item)
	vb.add_child(save_btn)

	var del_btn = Button.new()
	del_btn.text = "刪除道具"
	del_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	del_btn.pressed.connect(_delete_item)
	vb.add_child(del_btn)

# ── 右側：道具檢視 ────────────────────────────────
func _build_viewer_panel(parent: HBoxContainer) -> void:
	var panel = _make_panel()
	panel.custom_minimum_size.x = 240
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(panel)
	var vb = _panel_vbox(panel)

	vb.add_child(_make_title("道具檢視"))

	var scroll = ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vb.add_child(scroll)

	_item_viewer_label = RichTextLabel.new()
	_item_viewer_label.bbcode_enabled = true
	_item_viewer_label.fit_content = true
	_item_viewer_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_item_viewer_label.add_theme_font_size_override("normal_font_size", 11)
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
	affix_opt.add_theme_font_size_override("font_size", 11)
	row.add_child(affix_opt)

	var tier_opt = OptionButton.new()
	tier_opt.custom_minimum_size.x = 60
	tier_opt.add_theme_font_size_override("font_size", 10)
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
		var target_name: String = existing_mod.get("type", "")
		var target_value: int   = existing_mod.get("value", 0)
		# 選 affix
		for i in affix_opt.item_count:
			if affix_opt.get_item_text(i) == target_name:
				affix_opt.selected = i
				break
		# 重建 tier（_rebuild_all_mod_row_opts 已建，但 selection 剛改，需再 rebuild 此列 tier）
		var affix_def := _affix_from_entry(row_entry)
		tier_opt.clear()
		if affix_def != null:
			for t in affix_def.tiers:
				tier_opt.add_item("+%d" % t.get("cost", 0))
			for j in affix_def.tiers.size():
				if affix_def.tiers[j].get("value", 0) == target_value:
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

## 重算每個 mod 列的 affix 可選清單，排除其他列已選的；保留各列當前選擇
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

		# 排除其他列已選的名稱
		var filtered: Array = pool.filter(func(a: AffixData) -> bool:
			for j in sel_names.size():
				if j != i and sel_names[j] == a.name:
					return false
			return true
		)

		# 重建 affix_opt，盡量保留原本選擇
		affix_opt.clear()
		var new_sel := 0
		for k in filtered.size():
			affix_opt.add_item(filtered[k].name)
			if filtered[k].name == my_name:
				new_sel = k
		affix_opt.selected = new_sel if filtered.size() > 0 else -1

		# 保留 tier 選擇並重建
		var prev_tier := tier_opt.selected
		tier_opt.clear()
		var affix := _affix_from_entry(entry)
		if affix != null:
			for t in affix.tiers:
				tier_opt.add_item("+%d" % t.get("cost", 0))
			if prev_tier >= 0 and prev_tier < tier_opt.item_count:
				tier_opt.selected = prev_tier

## 以名稱 lookup 取得 affix（不依賴 index 對齊）
func _affix_from_entry(entry: Dictionary) -> AffixData:
	var opt: OptionButton = entry["affix_opt"]
	if opt.selected < 0 or opt.selected >= opt.item_count: return null
	return AffixLibrary.get_affix(opt.get_item_text(opt.selected))

## 從當前編輯器狀態更新道具檢視
func _update_viewer() -> void:
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
			if tier_idx < 0 or tier_idx >= affix.tiers.size(): continue
			var tier_data: Dictionary = affix.tiers[tier_idx]
			var cost: int = tier_data.get("cost", 0)
			var effect: String = tier_data.get("effect", "")
			lines.append("[b]+%d %s[/b]\n%s" % [cost, affix.name, effect])
	_item_viewer_label.text = "\n".join(lines)

## 從已儲存的 item dict 更新道具檢視（inventory 選取時使用）
func _show_item_in_viewer(item: Dictionary) -> void:
	if _item_viewer_label == null: return
	var iname: String = item.get("name", "（未命名）")
	var slot_key: String = item.get("slot", "")
	var slot_text := ItemSlots.label(slot_key) if slot_key != "" else "（未指定）"
	var lines: Array = []
	lines.append("[b]%s[/b]" % iname)
	lines.append("[i]%s[/i]" % slot_text)
	var mods: Array = item.get("mods", [])
	if not mods.is_empty():
		lines.append("")
		for mod in mods:
			var affix := AffixLibrary.get_affix(mod.get("type", ""))
			if affix == null:
				lines.append(mod.get("type", "（未知）"))
				continue
			var val: int = mod.get("value", 0)
			var tier_idx := affix.tier_index_for_value(val)
			var tier_data: Dictionary = affix.tiers[tier_idx] if tier_idx < affix.tiers.size() else {}
			var cost: int = tier_data.get("cost", 0)
			var effect: String = tier_data.get("effect", "")
			lines.append("[b]+%d %s[/b]\n%s" % [cost, affix.name, effect])
	_item_viewer_label.text = "\n".join(lines)

func _current_slot_key() -> String:
	if _item_slot_opt == null or _item_slot_opt.selected <= 0: return ""
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
	for equip_slot in CharacterData.EQUIP_SLOTS:
		if not _equip_slot_opts.has(equip_slot): continue
		var opt: OptionButton = _equip_slot_opts[equip_slot]
		opt.clear()
		opt.add_item("（空）")
		opt.set_item_metadata(0, "")
		for item in _data.item_library:
			var idx := opt.item_count
			opt.add_item(item.get("name", "（無名）"))
			opt.set_item_metadata(idx, item.get("id", ""))
		# 以 id 對齊目前裝備
		var equipped_id: String = _data.equipment.get(equip_slot, "")
		opt.selected = 0
		if equipped_id != "":
			for i in range(1, opt.item_count):
				if str(opt.get_item_metadata(i)) == equipped_id:
					opt.selected = i
					break

func _refresh_item_list() -> void:
	if _data == null or _item_list_vb == null: return
	for child in _item_list_vb.get_children():
		child.queue_free()

	var search := _item_search_edit.text.to_lower() if _item_search_edit else ""
	var filter_idx := _item_filter_slot_opt.selected if _item_filter_slot_opt else 0
	var slot_filter_label := "" if filter_idx == 0 else _item_filter_slot_opt.get_item_text(filter_idx)

	for i in _data.item_library.size():
		var item: Dictionary = _data.item_library[i]
		var iname: String = item.get("name", "")
		if search != "" and not iname.to_lower().contains(search): continue
		if slot_filter_label != "":
			var ikey: String = item.get("slot", "")
			if ItemSlots.label(ikey) != slot_filter_label: continue

		var btn = Button.new()
		var slot_lbl := ItemSlots.label(item.get("slot","")) if item.get("slot","") != "" else "?"
		btn.text = "[%s]  %s" % [slot_lbl, iname if iname != "" else "（未命名）"]
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.add_theme_font_size_override("font_size", 11)
		btn.pressed.connect(func(): _select_item(i))
		_item_list_vb.add_child(btn)

func _select_item(idx: int) -> void:
	if _data == null or idx < 0 or idx >= _data.item_library.size(): return
	_selected_item_index = idx
	var item: Dictionary = _data.item_library[idx]

	_item_name_edit.text = item.get("name", "")

	# slot opt
	var slot_key: String = item.get("slot", "")
	_item_slot_opt.selected = 0
	for i in range(1, _item_slot_opt.item_count):
		if ("  [%s]" % slot_key) in _item_slot_opt.get_item_text(i):
			_item_slot_opt.selected = i
			break

	_clear_mod_rows()
	for mod in item.get("mods", []):
		_add_mod_row(mod)
	_show_item_in_viewer(item)

func _generate_id() -> String:
	return "item_%d_%d" % [Time.get_ticks_usec(), randi()]

func _save_item() -> void:
	if _data == null: return

	var slot_key := _current_slot_key()
	var mods: Array = []
	var total_cost := 0
	for entry in _item_mod_rows:
		var tier_opt: OptionButton = entry["tier_opt"]
		var affix := _affix_from_entry(entry)
		if affix == null: continue
		var tier_idx := tier_opt.selected
		var tier_data: Dictionary = affix.tiers[tier_idx] if tier_idx < affix.tiers.size() else {}
		var val: int = tier_data.get("value", 0)
		total_cost += tier_data.get("cost", 0)
		mods.append({ "type": affix.name, "value": val })

	# 名稱為空時自動產生：+{total cost} {slot label}
	var iname := _item_name_edit.text.strip_edges()
	if iname == "":
		var type_label := ItemSlots.label(slot_key) if slot_key != "" else "Item"
		iname = "+%d %s" % [total_cost, type_label]

	# 保留既有 id，新道具才產生
	var existing_id := ""
	if _selected_item_index >= 0 and _selected_item_index < _data.item_library.size():
		existing_id = _data.item_library[_selected_item_index].get("id", "")
	var item_id := existing_id if existing_id != "" else _generate_id()

	var item := { "id": item_id, "name": iname, "slot": slot_key, "mods": mods }
	if _selected_item_index >= 0 and _selected_item_index < _data.item_library.size():
		_data.item_library[_selected_item_index] = item
	else:
		_data.item_library.append(item)
		_selected_item_index = _data.item_library.size() - 1

	_refresh_item_list()
	_refresh_equip_slots()
	equip_changed.emit()

func _new_item() -> void:
	_selected_item_index = -1
	if _item_name_edit: _item_name_edit.text = ""
	if _item_slot_opt:  _item_slot_opt.selected = 0
	_clear_mod_rows()

func _delete_item() -> void:
	if _data == null or _selected_item_index < 0: return
	_data.item_library.remove_at(_selected_item_index)
	_selected_item_index = -1
	_new_item()
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
