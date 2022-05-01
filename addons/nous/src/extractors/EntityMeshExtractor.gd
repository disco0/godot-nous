tool
class_name EntityMeshExtractor
#
# Pseudo-abstract base class for defining an extractor. Implemenation clases should
# define an Instance static method to properly set details (see PlayerMeshExtractor as an
# example)
#


var dprint = Nous.dprint_for(self)

const ANIMATION_SEARCH_OVERRIDE_DISABLED := true
# Development flag: When enabled AABBs will be generated for each mesh, and used to calculate a
# vertical offset to place object at origin
const AABB_NORMALIZATION_ENABLED := true

# Top level node of a scene to process (not 100% on using this yet)
var target: Node
# List of node names able to be processed by extractor definition
var target_node_names: Array # Array<String>
var extractor_type: String setget , _get_extractor_type
# Phase this out with extractor type (class_name)
var extractor_name setget , _get_name
var name: String = get_class() setget set_name, _get_name


func _init():
	set_name(get_class())


func get_class() -> String:
	return '@EntityMeshExtractor'


func _get_name() -> String:
	return name


# Should be used by implementation classes to set extractor label/info
func set_name(value: String):
	name = value
	dprint.base_context = name


func _get_extractor_type() -> String:
	return name.trim_suffix('MeshExtractor')


# Main implementation for each resolver's scene form. Effectively a virtual function that
# _must_ be defined by extended class
func resolve_meshes(node: Node = target) -> Array: # Array<Mesh>
	dprint.error('Method must be overridden.', 'resolve_meshes')
	return [ ]


func can_target(node: Node) -> bool:
	dprint.error('Method must be overridden.', 'can_target')
	dprint.write('Method must be overridden.', 'can_target')
	return false

# Basic helper methods
