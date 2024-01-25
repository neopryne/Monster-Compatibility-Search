extends ContentInfo


#const MODUTILS: Dictionary = {
#	"class_patch": [
#		{
#			"patch": "res://mods/compatibility_search/monster_search/MSBestiaryMenu.gd",
#			"target": "res://menus/bestiary/BestiaryMenu.gd",
#		},
#	]
#}

#
#var BestiaryMenu = load("res://menus/bestiary/BestiaryMenu.tscn")
var bestiarymenu = preload("res://mods/compatibility_search/monster_search/MSBestiaryMenu.tscn")

func init_content() -> void:
	# Take over the resource path so the next mod that extends from this path gets our script instead of the original
	bestiarymenu.take_over_path("res://menus/bestiary/BestiaryMenu.tscn")
	# Here's where we actually change the global
	#ok this part isn't working.  But it doesn't do anything without it.
	#BestiaryMenu.set_script(script)

	# _ready MIGHT need to be called again because the script was reset, this depends on what the script actually does in _ready
	#for now don't because idk what this signal is.
	#BestiaryMenu.notification(NOTIFICATION_READY)
	#preload("res://mods/compatibility_search/monster_search/MSBestiaryMenu.tscn").take_over_path("res://menus/bestiary/BestiaryMenu.tscn")
tool
