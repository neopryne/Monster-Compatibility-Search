extends "res://menus/BaseMenu.gd"

const BestiaryListButton = preload("res://menus/bestiary/BestiaryListButton.tscn")
const BestiaryListButtonFusion = preload("res://menus/bestiary/BestiaryListButtonFusion.tscn")

enum SortMode{SORT_BY_NUMBER, SORT_BY_NAME}
enum ListMode{LIST_MONSTERS, LIST_FUSIONS}

export (bool) var show_list:bool = true
export (Resource) var species:Resource setget set_species
export (SortMode) var sort_mode = SortMode.SORT_BY_NUMBER
export (ListMode) var list_mode = ListMode.LIST_MONSTERS
export (int) var initial_info_page:int = 0 setget set_initial_info_page

onready var species_info_margin = find_node("BestiarySpeciesInfoMargin")
onready var species_info = find_node("BestiarySpeciesInfo")
onready var button_list_container = find_node("ButtonListContainer")
onready var button_list = find_node("ButtonList")
onready var seen_label = find_node("SeenLabel")
onready var obtained_label = find_node("ObtainedLabel")
onready var obtained_percent_label = find_node("ObtainedPercentLabel")
onready var sort_prompt_button = find_node("SortPromptButton")
onready var list_mode_prompt_button = find_node("ListModePromptButton")

var seen_count:int = 0
var seen_max:int = 0
var obtained_count:int = 0
var obtained_max:int = 0
var current_button:BaseButton = null
var MONSTER_SEARCH_move_filter = ""
var MONSTER_SEARCH_move_array = Array()
var MONSTER_SEARCH_query_tag_array = Array()

func _ready():
	reload()
	set_initial_info_page(initial_info_page)
	
	if not show_list:
		$BackButtonPanel.back_text_override = "UI_BUTTON_CLOSE"

func reload():
	var focus_owner = get_focus_owner()
	var had_focus = focus_owner != null and (button_list == focus_owner or button_list.is_a_parent_of(focus_owner))
	
	seen_count = 0
	seen_max = 0
	obtained_count = 0
	obtained_max = 0
	
	current_button = null
	for button in button_list.get_children():
		button_list.remove_child(button)
		button.queue_free()
	button_list.initial_focus = NodePath()
	
	if list_mode == ListMode.LIST_FUSIONS:
		load_fusions()
	else :
		assert (list_mode == ListMode.LIST_MONSTERS)
		load_monsters()
	
	button_list.setup_focus()
	if had_focus:
		button_list.grab_focus()
	else :
		var initial_button = button_list.get_focus_delegate()
		if initial_button:
			_on_list_button_focus_entered(initial_button)
	
	seen_label.text = Loc.trf("UI_BESTIARY_SEEN_COUNT", {
		"num":seen_count, 
		"total":seen_max
	})
	obtained_percent_label.text = Loc.trf("UI_BESTIARY_COMPLETION_PERCENT", {
		"percent":Loc.format_float("%03.1f", float(obtained_count) / max(obtained_max, 1) * 100.0)
	})
	
	var sort_prompt_key = "UI_BESTIARY_SORT_BY_NUMBER" if sort_mode == SortMode.SORT_BY_NAME else "UI_BESTIARY_SORT_BY_NAME"
	sort_prompt_button.set_text(sort_prompt_key)
	if show_list:
		sort_prompt_button.set_visible_override(null)
	else :
		sort_prompt_button.set_visible_override(false)
	
	var list_mode_prompt_key = "UI_BESTIARY_LIST_MODE_VIEW_MONSTERS" if list_mode == ListMode.LIST_FUSIONS else "UI_BESTIARY_LIST_MODE_VIEW_FUSIONS"
	list_mode_prompt_button.set_text(list_mode_prompt_key)
	if can_toggle_list_mode():
		list_mode_prompt_button.set_visible_override(null)
	else :
		list_mode_prompt_button.set_visible_override(false)

func set_initial_info_page(value:int):
	initial_info_page = value
	if species_info:
		species_info.set_page(value)

func can_toggle_list_mode()->bool:
	if not show_list:
		return false
	return list_mode == ListMode.LIST_FUSIONS or SaveState.species_collection.seen_fusions_by_name.size() > 0


func MONSTER_SEARCH_generate_move_array():
	var MONSTER_SEARCH_move_name_array = MONSTER_SEARCH_move_filter.split(",", false, 0)
	#clear old values
	MONSTER_SEARCH_move_array = Array()
	MONSTER_SEARCH_query_tag_array = Array()
	for MONSTER_SEARCH_move_name in MONSTER_SEARCH_move_name_array:
		var MONSTER_SEARCH_cleaned_move_name = MONSTER_SEARCH_move_name.strip_edges()
		#print(MONSTER_SEARCH_cleaned_move_name)
		#if it starts with a :, that's a :tag, not a move.
		if (MONSTER_SEARCH_cleaned_move_name.substr(0, 1) == ":"):
			MONSTER_SEARCH_query_tag_array.append(MONSTER_SEARCH_cleaned_move_name.substr(1))
		else:
			#find matching move data
			#I don't know how to get moves by name so brute force it
			for MONSTER_SEARCH_move in BattleMoves.all_valid:
				if (Strings.strip_diacritics(tr(MONSTER_SEARCH_move.name).to_lower()) == (MONSTER_SEARCH_cleaned_move_name)):
					#print(MONSTER_SEARCH_move.name)
					MONSTER_SEARCH_move_array.append(MONSTER_SEARCH_move)
					break

func tag_is_compatible(MONSTER_SEARCH_monster_form:BaseForm, tag:String):
	var MONSTER_SEARCH_tag_match = false
	var types = MONSTER_SEARCH_monster_form.elemental_types
	for etype in types:
		if (etype.id == tag):
			MONSTER_SEARCH_tag_match = true
			break
	for MONSTER_SEARCH_monster_tag in MONSTER_SEARCH_monster_form.move_tags:
		if (MONSTER_SEARCH_monster_tag == tag):
			MONSTER_SEARCH_tag_match = true
			break
	return MONSTER_SEARCH_tag_match

#gotta figure out if this counts bootlegs or w/e.  Maybe in v2.
func MONSTER_SEARCH_species_is_compatible(MONSTER_SEARCH_monster_form:BaseForm):
	var MONSTER_SEARCH_is_compatible = true
	#must have all listed moves
	for MONSTER_SEARCH_move in MONSTER_SEARCH_move_array:
		var MONSTER_SEARCH_tag_array = MONSTER_SEARCH_move.tags
		#each move tag set must match a tag on the monster
		#the "any" tag is a special case, monsters don't have it, it's implicit.
		#OR it must match the type of the monster.
		var MONSTER_SEARCH_tag_array_match = false
		for MONSTER_SEARCH_move_tag in MONSTER_SEARCH_tag_array:
			if (MONSTER_SEARCH_move_tag == "any"):
				MONSTER_SEARCH_tag_array_match = true
				break
			var MONSTER_SEARCH_tag_match = tag_is_compatible(MONSTER_SEARCH_monster_form, MONSTER_SEARCH_move_tag)
			if (MONSTER_SEARCH_tag_match):
				MONSTER_SEARCH_tag_array_match = true
				break
		if (!MONSTER_SEARCH_tag_array_match):
			MONSTER_SEARCH_is_compatible = false
			break
	#must match all listed tags
	for MONSTER_SEARCH_query_tag in MONSTER_SEARCH_query_tag_array:
		#I don't know why you'd search for this but ok...
		if (MONSTER_SEARCH_query_tag == "any"):
			continue
		var MONSTER_SEARCH_tag_match = tag_is_compatible(MONSTER_SEARCH_monster_form, MONSTER_SEARCH_query_tag)
		if (!MONSTER_SEARCH_tag_match):
			MONSTER_SEARCH_is_compatible = false
			break
	return MONSTER_SEARCH_is_compatible

func load_monsters():
	if sort_mode == SortMode.SORT_BY_NAME:
		for species in MonsterForms.by_name:
			assert (species != null)
			if SaveState.species_collection.has_seen_species(species):
				if (MONSTER_SEARCH_species_is_compatible(species)):
					_add_list_button(species)
	else :
		assert (sort_mode == SortMode.SORT_BY_NUMBER)
		for species in MonsterForms.by_index:
			var index = species.bestiary_index
			if (species.bestiary_category == MonsterForm.BestiaryCategory.MONSTER and is_regular_index(index)) or SaveState.species_collection.has_seen_species(species):
				if (MONSTER_SEARCH_species_is_compatible(species)):
					_add_list_button(species)
	
	obtained_max = MonsterForms.official_count
	
	obtained_label.text = Loc.trf("UI_BESTIARY_RECORDED_COUNT", {
		"num":obtained_count, 
		"total":obtained_max
	})

func _add_list_button(species:BaseForm):
	var button = BestiaryListButton.instance()
	button.species = species
	button_list.add_child(button)
	button.connect("focus_entered", self, "_on_list_button_focus_entered", [button])
	if species != null and button_list.initial_focus.is_empty():
		if _is_species_match(species, self.species):
			button_list.initial_focus = button_list.get_path_to(button)
	
	if species and SaveState.species_collection.has_obtained_species(species):
		obtained_count += 1
	if species and SaveState.species_collection.has_seen_species(species):
		seen_count += 1
	seen_max += 1

func _is_species_match(test:MonsterForm, current_species:BaseForm)->bool:
	if test == current_species:
		return true
	if current_species is FusionForm and current_species.base_form_1 == test:
		return true
	return false

func _add_list_button_fusion(species:Array):
	assert (species.size() == 2)
	if species.size() != 2:
		return 
	var button = BestiaryListButtonFusion.instance()
	button.species = species
	button_list.add_child(button)
	button.connect("focus_entered", self, "_on_list_button_focus_entered", [button])
	if species != null and button_list.initial_focus.is_empty():
		if _is_species_match_fusion(species, self.species):
			button_list.initial_focus = button_list.get_path_to(button)
	
	if species and SaveState.species_collection.has_formed_fusion(species[0], species[1]):
		obtained_count += 1
	if species and SaveState.species_collection.has_seen_fusion(species[0], species[1]):
		seen_count += 1
	seen_max += 1

func _is_species_match_fusion(test:Array, current_species:BaseForm)->bool:
	assert (test.size() == 2)
	if test.size() != 2:
		return false
	if current_species is FusionForm:
		return current_species.base_form_1 == test[0] and current_species.base_form_2 == test[1]
	else :
		assert (current_species is MonsterForm)
		return test[0] == current_species

func load_fusions():
	var species_list
	if sort_mode == SortMode.SORT_BY_NUMBER:
		species_list = SaveState.species_collection.seen_fusions_by_index
	else :
		species_list = SaveState.species_collection.seen_fusions_by_name
	
	for species in species_list:
		_add_list_button_fusion(species)
	
	seen_max = MonsterForms.official_count * MonsterForms.official_count
	obtained_max = seen_max
	
	obtained_label.text = Loc.trf("UI_BESTIARY_FORMED_COUNT", {
		"num":obtained_count, 
		"total":obtained_max
	})

func _on_list_button_focus_entered(button:BaseButton):
	current_button = button
	set_species(button.get_species_data())

func is_regular_index(index:int):
	return index > 0 and index <= MonsterForms.official_count

func set_species(value:Resource):
	species = value
	if species is FusionForm:
		list_mode = ListMode.LIST_FUSIONS
	else :
		list_mode = ListMode.LIST_MONSTERS
	if species_info:
		species_info.species = species

func get_show_hide_anim()->String:
	if show_list:
		return "show_with_list"
	else :
		return "show_without_list"

func grab_focus():
	if show_list:
		button_list.grab_focus()
	else :
		species_info.focus_mode = Control.FOCUS_CLICK
		species_info.grab_focus()

func _unhandled_input(event):
	if GlobalMessageDialog.message_dialog.visible or animation_player.is_playing() or not MenuHelper.is_in_top_menu(self):
		return 
	if event.is_action_pressed("ui_cancel"):
		cancel()
		accept_event()
	else :
		species_info._on_gui_input(event)
		if get_tree().is_input_handled():
			return 
		if not show_list and event.is_action_pressed("ui_accept"):
			cancel()
			accept_event()

func _on_SortPromptButton_pressed():
	sort_mode = (sort_mode + 1) % SortMode.size()
	reload()

func MONSTER_SEARCH__on_FilterPromptButton_pressed():
	var MONSTER_SEARCH_menu = preload("res://mods/compatibility_search/monster_search/MonsterSearchMenu.tscn").instance()
	MONSTER_SEARCH_menu.filter.name = MONSTER_SEARCH_move_filter
	MenuHelper.add_child(MONSTER_SEARCH_menu)
	var MONSTER_SEARCH_result = yield (MONSTER_SEARCH_menu.run_menu(), "completed")
	if MONSTER_SEARCH_result != null:
		if MONSTER_SEARCH_result.has('name'):
			MONSTER_SEARCH_move_filter = MONSTER_SEARCH_result.name
		else:
			MONSTER_SEARCH_move_filter = ""
		MONSTER_SEARCH_generate_move_array()
		reload()
	MONSTER_SEARCH_menu.queue_free()

func _on_ListModePromptButton_pressed():
	if can_toggle_list_mode():
		list_mode = (list_mode + 1) % ListMode.size()
		reload()

func _on_habitat_map_requested(species, habitat_map, habitat_chunks):
	var prev_focus = get_focus_owner()
	Controls.set_disabled(self, true)
	yield (Co.wait_frames(2), "completed")
	prev_focus.release_focus()
	var feature_name = Loc.trf("UI_BESTIARY_INFO_LOCATION_MAP_FEATURE", {
		"species_name":species.name
	})
	yield (MenuHelper.show_map_menu(false, habitat_chunks, feature_name, habitat_map), "completed")
	Controls.set_disabled(self, false)
	if prev_focus:
		prev_focus.grab_focus()



func _on_ButtonListContainer_resized():
	if show_list:
		species_info_margin.add_constant_override("margin_left", button_list_container.rect_size.x - button_list_container.rect_min_size.x)
