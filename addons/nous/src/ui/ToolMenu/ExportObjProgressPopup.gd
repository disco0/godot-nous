tool
class_name ExportObjProgressPanel
extends PopupPanel

onready var bar: ProgressBar = $VBoxContainer/ProgressBar
onready var label: Label = $VBoxContainer/Label

var dprint = Nous.dprint_for(self, Colorful.CYAN)

func _update_progress(m_idx, s_idx, vert_idx, vert_total, mesh_total):
	if not is_inside_tree():
		dprint.error('Not in tree', 'on:update_progress')
	# dprint.write('%02d %02d %02.2f' % [ m_idx, s_idx, vert_pct ], '_update_progress')

	bar.value = float(vert_idx) / float(vert_total)
	bar.update()
	label.text = "Mesh %2d/%2d" % [ m_idx + 1, mesh_total ]
	label.update()

	dprint.write('Progress: %2.2f%%' % [ bar.get_value() * 100.0 ], '_update_progress')

func _ready():
	dprint.write('','on:ready')

func _init():
	dprint.write('','on:init')
