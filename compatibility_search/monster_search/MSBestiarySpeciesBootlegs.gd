extends PanelContainer

export (Resource) var species:Resource setget set_species
export (Array, Resource) var elemental_types:Array = []
export (Color) var unobtained_icon_modulate:Color = Color.gray

onready var heading = $VBoxContainer / HeadingLabel
onready var grid = $VBoxContainer / GridContainer
onready var no_data_label = $VBoxContainer / NoDataLabel

var icons:Dictionary = {}

func _ready():
	setup_grid()
	set_species(species)

func set_species(value:BaseForm):
	species = value
	
	if species is FusionForm:# or MonsterForms.is_archangel(species):
		grid.visible = false
		no_data_label.visible = true
		heading.text = "UI_BESTIARY_INFO_TAB_BOOTLEGS_NO_DATA"
		return 
	
	grid.visible = true
	no_data_label.visible = false
	
	var num_obtained:int = 0
	for type in elemental_types:
		var obtained = SaveState.species_collection.has_obtained_bootleg(species, type)
		assert (icons.has(type))
		if icons.has(type):
			icons[type].modulate = unobtained_icon_modulate if not obtained else Color.white
		if obtained:
			num_obtained += 1
	
	heading.text = Loc.trf("UI_BESTIARY_INFO_TAB_BOOTLEGS", {
		"num":num_obtained, 
		"total":elemental_types.size()
	})

func setup_grid():
	for type in elemental_types:
		var icon = TextureRect.new()
		icon.texture = type.icon
		icon.expand = true
		icon.rect_min_size = Vector2(48, 48)
		icon.size_flags_horizontal = Control.SIZE_EXPAND | Control.SIZE_SHRINK_CENTER
		icon.size_flags_vertical = Control.SIZE_EXPAND | Control.SIZE_SHRINK_CENTER
		grid.add_child(icon)
		icons[type] = icon
