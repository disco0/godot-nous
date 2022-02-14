class_name ObjEntityDockItem
extends HBoxContainer
tool

onready var ent_name: ToolButton = $EntityName
onready var extractor_label := $Extractor

var ent:       FGDEntitySceneSearch.EntInfo
var extractor: EntityMeshExtractor

var unknown_extractor_color := Color(0.9, 0.9, 0.9, 0.4)

# @TODO If this is really inefficient grab this from somewhere up the tree instead of pulling this
#       in every instance?
var editor_interface: EditorInterface = EditorScript.new().get_editor_interface()

func _ready() -> void:
	style()
	register()
	pass

var monospace_font: Font
func style() -> void:
	var editor_theme: Theme = editor_interface.get_base_control().get_theme().duplicate()
	
	var override_font = ent_name.get_node_and_resource('.:custom_fonts/font')[1]
	if override_font and override_font is Font:
		editor_theme.set_font("font", "ToolBox", override_font)
		
	theme = editor_theme
	

func _on_ent_name_pressed():
	editor_interface.set_main_screen_editor('3D')
	editor_interface.open_scene_from_path(ent.scene_file.resource_path)
	editor_interface.set_main_screen_editor('3D')


func register() -> void:
	if not is_inside_tree():
		push_error('ObjEntityDockItem >> register called outside of tree.')
		return

	if ent is FGDEntitySceneSearch.EntInfo:
		ent_name.text = ent.classname
		ent_name.set_tooltip(ent.scene_file.resource_path)
		ent_name.connect("pressed", self, "_on_ent_name_pressed")
	else:
		push_error('ObjEntityDockItem >> Missing entity info member.')
		if extractor:
			push_error('                  >> Defined extractor: %s' % [ extractor.extractor_name ])
			self.get_parent().remove_child(self)
			self.queue_free()


	if extractor is EntityMeshExtractor:
		extractor_label.text = EntityMeshExtractors.TrimSuffix((extractor as EntityMeshExtractor).extractor_name)
		extractor_label.add_color_override("font_color", get_color('font_color', 'Label'))
	else:
		extractor_label.text = 'Unknown'
		extractor_label.add_color_override("font_color", unknown_extractor_color)

	set_visible(true)
