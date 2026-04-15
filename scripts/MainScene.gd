## MainScene.gd

extends Control

@onready var btn_new: Button = $VBox/TopBar/BtnNew
@onready var btn_open: Button = $VBox/TopBar/BtnOpen
@onready var btn_save: Button = $VBox/TopBar/BtnSave
@onready var top_bar: HBoxContainer = $VBox/TopBar
@onready var sheet: Control = $VBox/SheetContainer/CharacterSheet

var _tab_char: Button
var _tab_equip: Button

func _ready() -> void:
	btn_new.pressed.connect(_on_new)
	btn_open.pressed.connect(_on_open)
	btn_save.pressed.connect(_on_save)
	_build_tab_buttons()

func _build_tab_buttons() -> void:
	_tab_char = Button.new()
	_tab_char.text = "腳色"
	_tab_char.toggle_mode = true
	_tab_char.button_pressed = true
	_tab_char.custom_minimum_size.x = 72

	_tab_equip = Button.new()
	_tab_equip.text = "裝備"
	_tab_equip.toggle_mode = true
	_tab_equip.button_pressed = false
	_tab_equip.custom_minimum_size.x = 72

	# 插在 TopBar 最左邊（index 0 和 1）
	top_bar.add_child(_tab_char)
	top_bar.move_child(_tab_char, 0)
	top_bar.add_child(_tab_equip)
	top_bar.move_child(_tab_equip, 1)

	_tab_char.pressed.connect(func():
		_tab_char.button_pressed = true
		_tab_equip.button_pressed = false
		sheet.switch_tab("腳色")
	)
	_tab_equip.pressed.connect(func():
		_tab_equip.button_pressed = true
		_tab_char.button_pressed = false
		sheet.switch_tab("裝備")
	)

	# 啟動時若已有角色就載入，否則建一個預設空角色
	var list = CharacterManager.get_character_list()
	if list.size() > 0:
		var data = CharacterManager.load_character(list[0])
		sheet.load_data(data)
	else:
		var data = CharacterManager.new_character("新角色")
		sheet.load_data(data)

func _on_new() -> void:
	# TODO: 彈出輸入名字的對話框
	var data = CharacterManager.new_character("新角色 %d" % Time.get_unix_time_from_system())
	sheet.load_data(data)

func _on_open() -> void:
	# TODO: 彈出角色選擇清單
	var list = CharacterManager.get_character_list()
	if list.size() > 0:
		var data = CharacterManager.load_character(list[0])
		sheet.load_data(data)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		get_viewport().gui_release_focus()

func _on_save() -> void:
	sheet.flush_to_data()
	CharacterManager.save_character(CharacterManager.current_character)
	print("已儲存：", CharacterManager.current_character.char_name)
