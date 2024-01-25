extends "res://menus/BaseMenu.gd"

const BestiaryListButton = preload("res://menus/bestiary/BestiaryListButton.tscn")

onready var input_container = find_node("InputContainer")
onready var name_input = find_node("NameInput")
onready var reset_button = find_node("ResetButton")
onready var output = find_node("OutputLabel")
onready var monster_list = find_node("MonsterList")

var current_button:BaseButton = null
var filter: = {} setget set_filter

func _ready():
	refresh()

func set_filter(value:Dictionary):
	filter = value
	if is_inside_tree():
		refresh()

func refresh():
	name_input.text = filter.get("name", "")

func grab_focus():
	input_container.grab_focus()

func _add_list_button(species:BaseForm):
	var button = BestiaryListButton.instance()
	button.species = species
	monster_list.add_child(button)
	button.connect("focus_entered", self, "_on_list_button_focus_entered", [button])
	if species != null and monster_list.initial_focus.is_empty():
		monster_list.initial_focus = monster_list.get_path_to(button)

func _on_list_button_focus_entered(button:BaseButton):
	current_button = button

func _on_SaveButton_pressed():
	filter = {}
	if name_input.text != "":
		filter.name = Strings.strip_diacritics(name_input.text.to_lower())
	choose_option(filter)
	return
	#the rest of this is in bestiarymenu.

func _on_NameInput_focus_entered():
	reset_button.disabled = true

func _on_NameInput_focus_exited():
	reset_button.disabled = false

func _on_ResetButton_pressed():
	name_input.text = ""
