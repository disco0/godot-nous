tool
class_name ExportObjProgressPanel
extends PopupPanel

onready var bar: ProgressBar = $VBoxContainer/ProgressBar
onready var label: Label = $VBoxContainer/Label

var dprint = CSquadUtil.dprint_for(self, Colorful.CYAN)

func _update_progress(m_idx, s_idx, vert_pct, mesh_total):
	if not is_inside_tree():
		dprint.error('Not in tree', 'on:update_progress')
	# dprint.write('%02d %02d %02.2f' % [ m_idx, s_idx, vert_pct ], '_update_progress')

	bar.value = vert_pct
	bar.update()
	label.text = "Mesh %2d/%2d" % [ m_idx + 1, mesh_total]
	label.update()

	dprint.write('Progress: %f -> %f%%' % [ vert_pct, vert_pct * 100.0 ], '_update_progress')

func _ready():
	dprint.write('','on:ready')

func _init():
	dprint.write('','on:init')
