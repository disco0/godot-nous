tool
class_name NavMeshBuilderContainer
extends HBoxContainer

var dprint := Nous.dprint_for(self)

signal build_navmesh()
signal save_navmesh()
signal load_navmesh()

signal clear_navmesh_grouping()

# Emits change information for any build related interfaces. Currently only used for parsed
# geometry, but adding setting_name in case for later
signal gen_setting_change(value, setting)

enum GEN_SETTING {
	PARSED_GEOMETRY,
	WORLDSPAWN_ONLY,
}

func _ready():
	# Copied from Godot Plugin Refresher (good or?)
	if get_tree().edited_scene_root == self:
		return # This is the scene opened in the editor!

var builder_instance # : NavMeshBuilder
func register_builder(builder) -> void:
	builder_instance = builder

	# Connect for config changes
	connect('gen_setting_change', builder_instance, 'on_UI_build_setting_update', [ ])

	# Set initial values
	var init_gen_mode = builder_instance.gen_mode as int
	match init_gen_mode:
		0b01:
			$ParsedGeo/ParsedGeoOption.select(0)
		0b10:
			$ParsedGeo/ParsedGeoOption.select(1)
		0b11:
			$ParsedGeo/ParsedGeoOption.select(2)

	$WorldspawnOnlyCheckbox.pressed = builder_instance.target_mode == 1

	# On navmesh manip command
	connect('build_navmesh', builder_instance, 'on_UI_build_navmesh')
	connect('save_navmesh',  builder_instance, 'on_UI_save_navmesh')
	connect('load_navmesh',  builder_instance, 'on_UI_load_navmesh')

func _on_BuildButton_pressed() -> void:
	emit_signal("build_navmesh")


func _on_SaveButton_pressed() -> void:
	emit_signal("save_navmesh")


func _on_LoadButton_pressed() -> void:
	emit_signal("load_navmesh")


func _on_ClearGroupsButton_pressed() -> void:
	emit_signal("clear_navmesh_grouping")


func _on_ParsedGeoOption_item_selected(value: int) -> void:
	dprint.write('Selected option index %s' % [ value ], 'on:ParsedGeoOption_item_selected')
	emit_signal("gen_setting_change", value, GEN_SETTING.PARSED_GEOMETRY)


func _on_WorldspawnOnlyCheckbox_toggled(button_pressed: bool) -> void:
	dprint.write('Set worldspawn only: %s' % [ button_pressed ], 'on:WorldspawnOnlyCheckbox_toggled')
	emit_signal("gen_setting_change", button_pressed, GEN_SETTING.WORLDSPAWN_ONLY)
