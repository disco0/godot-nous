# Notes on initialization/lifecycle

## Logged lifecycle functions calls

Open Godot / Close Godot:
   - init
   - enter-tree
   - ready
   - exit-tree

Open Godot / Open + Save Base EditorPlugin Script / Close Godot
   - init
   - enter-tree
   - ready
   - init
   - exit-tree

Open Godot / Refresh plugin via Plugin Refresher / Close Godot
   - init
   - enter-tree
   - ready
   - plugin-disabled
   - exit-tree
   - init
   - enter-tree
   - ready
   - plugin-enabled
   - exit-tree

## Summary

**`_init`**
   - Editor Start
   - Saving plugin's EditorPlugin script
   - Enabling plugin via Settings panel

**`_enter_tree`**
   - Editor Start
   - Enabling plugin via Settings panel

**`_ready`**
   - Editor Start
   - Enabling plugin via Settings panel

**`_exit_tree`**
   - Editor Close
   - Disabling plugin via Settings panel

**`enable_plugin`**
   - Enabling plugin via Settings panel

**`disable_plugin`**
   - Disabling plugin via Settings panel
