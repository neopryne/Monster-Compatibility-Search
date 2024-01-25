extends "res://menus/bestiary/BestiaryMenu.gd"


var MONSTER_SEARCH_move_filter = ""
var MONSTER_SEARCH_move_array = Array()
var MONSTER_SEARCH_query_tag_array = Array()

# Replace setup func
func setup() -> void:
	# Call parent's setup func first
	.setup()
	# Add custom stuff here to extend it

func MONSTER_SEARCH_generate_move_array():
	var MONSTER_SEARCH_move_name_array = MONSTER_SEARCH_move_filter.split(",", false, 0)
	#clear old values
	MONSTER_SEARCH_move_array = Array()
	MONSTER_SEARCH_query_tag_array = Array()
	for MONSTER_SEARCH_move_name in MONSTER_SEARCH_move_name_array:
		var MONSTER_SEARCH_cleaned_move_name = MONSTER_SEARCH_move_name.strip_edges()
		print(MONSTER_SEARCH_cleaned_move_name)
		#if it starts with a :, that's a :tag, not a move.
		if (MONSTER_SEARCH_cleaned_move_name.substr(0, 1) == ":"):
			MONSTER_SEARCH_query_tag_array.append(MONSTER_SEARCH_cleaned_move_name.substr(1))
		else:
			#find matching move data
			#I don't know how to get moves by name so brute force it
			for MONSTER_SEARCH_move in BattleMoves.all_valid:
				if (Strings.strip_diacritics(tr(MONSTER_SEARCH_move.name).to_lower()) == (MONSTER_SEARCH_cleaned_move_name)):
					print(MONSTER_SEARCH_move.name)
					MONSTER_SEARCH_move_array.append(MONSTER_SEARCH_move)
					break


#gotta figure out if this counts bootlegs or w/e.  Maybe in v2.
func MONSTER_SEARCH_species_is_compatible(MONSTER_SEARCH_monster_form:BaseForm):
	var MONSTER_SEARCH_is_compatible = true
	#must have all listed moves
	for MONSTER_SEARCH_move in MONSTER_SEARCH_move_array:
		var MONSTER_SEARCH_tag_array = MONSTER_SEARCH_move.tags
		#each move tag set must match a tag on the monster
		#the "any" tag is a special case, monsters don't have it, it's implicit.
		var MONSTER_SEARCH_tag_array_match = false
		for MONSTER_SEARCH_move_tag in MONSTER_SEARCH_tag_array:
			if (MONSTER_SEARCH_move_tag == "any"):
				MONSTER_SEARCH_tag_array_match = true
				break
			var MONSTER_SEARCH_tag_match = false
			for MONSTER_SEARCH_monster_tag in MONSTER_SEARCH_monster_form.move_tags:
				if (MONSTER_SEARCH_monster_tag == MONSTER_SEARCH_move_tag):
					MONSTER_SEARCH_tag_match = true
			if (MONSTER_SEARCH_tag_match):
				MONSTER_SEARCH_tag_array_match = true
		if (!MONSTER_SEARCH_tag_array_match):
			MONSTER_SEARCH_is_compatible = false
	#must match all listed tags
	for MONSTER_SEARCH_query_tag in MONSTER_SEARCH_query_tag_array:
		#I don't know why you'd search for this but ok...
		if (MONSTER_SEARCH_query_tag == "any"):
			continue
		var MONSTER_SEARCH_tag_match = false
		for MONSTER_SEARCH_monster_tag in MONSTER_SEARCH_monster_form.move_tags:
			if (MONSTER_SEARCH_monster_tag == MONSTER_SEARCH_query_tag):
				MONSTER_SEARCH_tag_match = true
		if (!MONSTER_SEARCH_tag_match):
			MONSTER_SEARCH_is_compatible = false
	return MONSTER_SEARCH_is_compatible

func load_monsters():
	if sort_mode == SortMode.SORT_BY_NAME:
		for species in MonsterForms.by_name:
			assert (species != null)
			if SaveState.species_collection.has_seen_species(species):
				if (MONSTER_SEARCH_species_is_compatible(species)):
					_add_list_button(species)#first comment to make patcher work
	else :
		assert (sort_mode == SortMode.SORT_BY_NUMBER)
		for species in MonsterForms.by_index:
			var index = species.bestiary_index
			if (species.bestiary_category == MonsterForm.BestiaryCategory.MONSTER and is_regular_index(index)) or SaveState.species_collection.has_seen_species(species):
				if (MONSTER_SEARCH_species_is_compatible(species)):
					_add_list_button(species)#second comment to make patcher work
	
	obtained_max = MonsterForms.official_count
	
	obtained_label.text = Loc.trf("UI_BESTIARY_RECORDED_COUNT", {
		"num":obtained_count, 
		"total":obtained_max
	})

func MONSTER_SEARCH__on_FilterPromptButton_pressed():
	var MONSTER_SEARCH_menu = preload("res://mods/compatibility_search/monster_search/MonsterSearchMenu.tscn").instance()
	MONSTER_SEARCH_menu.filter.name = MONSTER_SEARCH_move_filter
	MenuHelper.add_child(MONSTER_SEARCH_menu)
	var MONSTER_SEARCH_result = yield (MONSTER_SEARCH_menu.run_menu(), "completed")
	if MONSTER_SEARCH_result != null:
		MONSTER_SEARCH_move_filter = MONSTER_SEARCH_result.name
		MONSTER_SEARCH_generate_move_array()
		reload()
	MONSTER_SEARCH_menu.queue_free()
