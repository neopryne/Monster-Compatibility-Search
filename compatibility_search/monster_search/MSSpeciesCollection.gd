extends Node

signal new_species_registered(monster_form)
signal max_tape_grade_changed(monster_form)
signal ability_unlocked(ability)

const DATA_LEVEL_2_TAPE_GRADE_REQUIREMENT:int = 5

var obtained:Dictionary = {}
var max_tape_grades:Dictionary = {}

var seen_fusions_by_name:Array = []
var seen_fusions_by_index:Array = []
var seen_fusion_keys:Dictionary = {}

func _init():
	start_new_file()

func _ready():
	start_new_file()
	
	get_parent().tape_collection.connect("tape_added", self, "register")
	get_parent().party.connect("tapes_changed", self, "_scan_party")
	get_parent().stats.get_stat("fusions_encountered").connect("count_changed", self, "register_fusion")
	get_parent().stats.get_stat("fusions_formed").connect("count_changed", self, "register_fusion")

func _scan_party():
	for tape in get_parent().party.player.tapes:
		register(tape)
	
	for id in get_parent().party.unlocked_partners:
		var partner = get_parent().party.get_partner_by_id(id)
		for tape in partner.tapes:
			register(tape)

func _scan_save_state():
	if get_parent() == null:
		return 
	_scan_party()
	
	for tape in get_parent().tape_collection.tapes_by_name:
		register(tape)
	
	for key in get_parent().stats.get_stat("fusions_encountered").get_keys():
		var parts = _parse_fusion_key(key)
		if parts:
			register_fusion(parts)
	for key in get_parent().stats.get_stat("fusions_formed").get_keys():
		var parts = _parse_fusion_key(key)
		if parts:
			register_fusion(parts)

func _parse_fusion_key(key:String):
	if seen_fusion_keys.has(key):
		return null
	var part_keys = key.split(",")
	if part_keys.size() != 2:
		return null
	var parts = []
	for key in part_keys:
		var part = MonsterForms.get_from_key(key, false)
		if part == null:
			return 
		parts.push_back(part)
	assert (parts.size() == 2)
	return parts

func register_fusion(parts:Array, _count:int = 0):
	var str_key = StatUtil.stringify_key(parts)
	if seen_fusion_keys.has(str_key):
		return 
	seen_fusion_keys[str_key] = true
	assert (parts.size() == 2)
	assert (parts[0] is MonsterForm)
	assert (parts[1] is MonsterForm)
	if parts.size() != 2:
		return 
	
	var i = seen_fusions_by_name.bsearch_custom(parts, self, "_sort_fusion_by_name")
	seen_fusions_by_name.insert(i, parts)
	i = seen_fusions_by_index.bsearch_custom(parts, self, "_sort_fusion_by_index")
	seen_fusions_by_index.insert(i, parts)

func _sort_fusion_by_name(a:Array, b:Array):
	assert (a.size() == 2)
	assert (b.size() == 2)
	return Fusions.fuse_names(a[0], a[1]) < Fusions.fuse_names(b[0], b[1])

func _sort_fusion_by_index(a:Array, b:Array):
	assert (a.size() == 2)
	assert (b.size() == 2)
	var ia = Fusions.fuse_bestiary_index(a[0], a[1])
	var ib = Fusions.fuse_bestiary_index(b[0], b[1])
	return MonsterForms._sort_indices(ia, ib)

func register(tape:MonsterTape):
	var new_species:bool = false
	var species = tape.form
	var species_key = Datatables.get_db_key(tape.form)
	if not obtained.has(species_key):
		obtained[species_key] = {}
		new_species = true
	
	var type_id = tape.type_override[0].id if tape.type_override.size() > 0 else ""
	obtained[species_key][type_id] = true
	
	if tape.grade > max_tape_grades.get(species_key, 0):
		if tape.grade >= MonsterTape.MAX_TAPE_GRADE and max_tape_grades.get(species_key, 0) < MonsterTape.MAX_TAPE_GRADE:
			get_parent().stats.get_stat("maxed_tape_species").report_event(species)
		max_tape_grades[species_key] = tape.grade
		emit_signal("max_tape_grade_changed", species)
	
	if new_species:
		get_parent().stats.get_stat("observed_species").report_event(species)
		get_parent().stats.get_stat("registered_species").report_event(species)
		emit_signal("new_species_registered", species)
	
	if tape.type_override.size() > 0:
		var bootleg_type = tape.type_override[0]
		if get_parent().stats.get_stat("registered_bootleg_types").get_count(bootleg_type) == 0:
			get_parent().stats.get_stat("registered_bootleg_types").report_event(bootleg_type)
	
	if tape.form.unlock_ability != "" and get_parent().has_flag("encounter_aa_oldgante"):
		emit_signal("ability_unlocked", tape.form.unlock_ability)

func unlock_abilities()->Array:
	if not get_parent().has_flag("encounter_aa_oldgante"):
		return []
	var unlocked = []
	for id in obtained.keys():
		var species = MonsterForms.get_from_key(id, false)
		if species:
			if species.unlock_ability != "" and not get_parent().has_ability(species.unlock_ability):
				emit_signal("ability_unlocked", species.unlock_ability)
				unlocked.push_back(species.unlock_ability)
	return unlocked

func get_num_encountered(species:BaseForm)->int:
	if species is FusionForm:
		return get_num_fusions_encountered(species.base_form_1, species.base_form_2)
	return get_parent().stats.get_stat("encounters_species").get_count(species)

func get_num_defeated(species:BaseForm)->int:
	if species is FusionForm:
		return get_num_fusions_defeated(species.base_form_1, species.base_form_2)
	return get_parent().stats.get_stat("kills_species").get_count(species)

func get_num_recorded(species:MonsterForm)->int:
	return get_parent().stats.get_stat("recorded_species").get_count(species)

func get_max_tape_grade(species:MonsterForm)->int:
	var species_key = Datatables.get_db_key(species)
	return max_tape_grades.get(species_key, 0)








func has_obtained_species(species:BaseForm)->bool:
	return true
	if species is FusionForm:
		return has_formed_fusion(species.base_form_1, species.base_form_2)
	return obtained.has(Datatables.get_db_key(species))

func has_obtained_bootleg(species:MonsterForm, type:ElementalType)->bool:
	return true
	var species_key = Datatables.get_db_key(species)
	return obtained.has(species_key) and obtained[species_key].has(type.id if type != null else "")

func has_seen_species(species:BaseForm)->bool:
	if species is FusionForm:
		return has_seen_fusion(species.base_form_1, species.base_form_2)
	if has_obtained_species(species) or get_num_encountered(species) > 0 or get_num_defeated(species) > 0:
		return true
	if species.bestiary_data_requirement == 3 and get_parent().has_flag(species.bestiary_data_requirement_flag):
		return true
	if Debug.seen_all_species_cheat and not MonsterForms.secret_forms.values().has(species):
		return true
	return false

func has_bestiary_data_requirement(species:BaseForm, data_level:int)->bool:
	return true
	if species.bestiary_data_requirement == 1 and get_num_defeated(species) > 0:
		return get_num_defeated(species) > 0
	if species.bestiary_data_requirement == 2 and has_seen_species(species):
		return true
	if species.bestiary_data_requirement == 3 and get_parent().has_flag(species.bestiary_data_requirement_flag):
		return true
	if data_level == 0:
		return has_obtained_species(species)
	elif data_level == 1:
		return get_max_tape_grade(species) >= DATA_LEVEL_2_TAPE_GRADE_REQUIREMENT
	return false

func get_num_fusions_formed(a:MonsterForm, b:MonsterForm)->int:
	return get_parent().stats.get_stat("fusions_formed").get_count([a, b])

func get_num_fusions_encountered(a:MonsterForm, b:MonsterForm)->int:
	return get_parent().stats.get_stat("fusions_encountered").get_count([a, b])

func get_num_fusions_defeated(a:MonsterForm, b:MonsterForm)->int:
	return get_parent().stats.get_stat("kills_fusions").get_count([a, b])

func has_seen_fusion(a:MonsterForm, b:MonsterForm)->bool:
	return get_num_fusions_formed(a, b) > 0 or get_num_fusions_encountered(a, b) > 0

func has_formed_fusion(a:MonsterForm, b:MonsterForm)->bool:
	return get_num_fusions_formed(a, b) > 0

func get_random_seen_spawnable_species(rand:Random)->MonsterForm:
	var seen_species = []
	for species in MonsterForms.basic_forms.values():
		if species.require_dlc != "" and not DLC.has_dlc(species.require_dlc):
			continue
		if has_seen_species(species):
			seen_species.push_back(species)
	return rand.choice(seen_species)

func start_new_file():
	obtained = {}
	max_tape_grades = {}
	seen_fusions_by_name = []
	seen_fusions_by_index = []
	seen_fusion_keys = {}
	_scan_save_state()

func get_snapshot():
	return {
		"obtained":obtained.duplicate(), 
		"max_tape_grades":max_tape_grades.duplicate()
	}

func set_snapshot(snap, version:int)->bool:
	seen_fusions_by_name = []
	seen_fusions_by_index = []
	seen_fusion_keys = {}
	
	if version < 3:
		obtained = {}
		max_tape_grades = {}
	else :
		obtained = snap.obtained.duplicate()
		max_tape_grades = snap.max_tape_grades.duplicate()
	
	_scan_save_state()
	unlock_abilities()
	return true
