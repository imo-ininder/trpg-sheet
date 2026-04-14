## CharacterManager.gd
## 全域 Autoload — 管理多角色的存讀檔
## 在 Project Settings > Autoload 加入這個腳本，命名為 CharacterManager

extends Node

const SAVE_DIR = "user://characters/"

var current_character: CharacterData = null

signal character_loaded(data: CharacterData)
signal character_list_changed

# ── 取得所有已儲存的角色名稱清單 ─────────────────
func get_character_list() -> Array[String]:
	var list: Array[String] = []
	var dir = DirAccess.open(SAVE_DIR)
	if dir == null:
		DirAccess.make_dir_recursive_absolute(SAVE_DIR)
		return list
	dir.list_dir_begin()
	var fname = dir.get_next()
	while fname != "":
		if fname.ends_with(".tres"):
			list.append(fname.trim_suffix(".tres"))
		fname = dir.get_next()
	return list

# ── 新增角色 ──────────────────────────────────────
func new_character(char_name: String) -> CharacterData:
	var data = CharacterData.new()
	data.char_name = char_name
	current_character = data
	save_character(data)
	character_list_changed.emit()
	return data

# ── 儲存角色 ──────────────────────────────────────
func save_character(data: CharacterData) -> void:
	if data.char_name == "":
		push_warning("CharacterManager: 無法儲存沒有名字的角色")
		return
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	var path = SAVE_DIR + data.char_name + ".tres"
	ResourceSaver.save(data, path)

# ── 讀取角色 ──────────────────────────────────────
func load_character(char_name: String) -> CharacterData:
	var path = SAVE_DIR + char_name + ".tres"
	if not ResourceLoader.exists(path):
		push_error("CharacterManager: 找不到角色 " + char_name)
		return null
	var data = ResourceLoader.load(path) as CharacterData
	current_character = data
	character_loaded.emit(data)
	return data

# ── 刪除角色 ──────────────────────────────────────
func delete_character(char_name: String) -> void:
	var path = SAVE_DIR + char_name + ".tres"
	if ResourceLoader.exists(path):
		DirAccess.remove_absolute(path)
	if current_character and current_character.char_name == char_name:
		current_character = null
	character_list_changed.emit()
