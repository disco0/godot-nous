tool
class_name EntityMeshExtractors

static func TrimSuffix(name: String) -> String:
	return name.trim_suffix('MeshExtractor')

func _init(immediate_register := true):
	if immediate_register:
		register_extractors()

func is_scene_extractable(scene) -> bool:
	var name = scene.name if scene is Node else scene
	for instance in instances:
		if instance.can_target(scene):
			return true

	return false

# Array of extractor implementation instances to search through
var instances: Array = [ ]

# Receives an implementation, and calls its static Instance method and checks if has been
# previously registered before adding it.
func register(extractor):
	var extractor_instance = extractor.new()
	#print('[EntityMeshExtractors:register] Instanitated extractor instance for %s' % [ extractor_instance.extractor_name ])

	# Check if already registered (this is overkill but idc lol)
	for instance in instances:
		if instance.extractor_name == extractor_instance.extractor_name:
			#print('[EntityMeshExtractors:register] [WARNING] Already registered extractor with name "%s"' % [ extractor_instance.extractor_name ])
			return

	instances.push_back(extractor_instance)

func get_extractor_for_node(node: Node) -> EntityMeshExtractor:
	var node_name = node.name if node is Node else node

	if typeof(node_name) != TYPE_STRING:
		#print('[EntityMeshExtractors:get_extractor_for_node] Cannot resolve extract for node without a name. (%s)' % [ node ])
		return null

	var idx = 0
	for instance in instances:
		#print('[EntityMeshExtractors:get_extractor_for_node] Checking extractor #%s' % [ idx ])
		idx += 1

		if instance.can_target(node):
			#print('[EntityMeshExtractors:get_extractor_for_node] Resolved extractor: %s' % [ instance.extractor_name ])
			return instance

	#print('[EntityMeshExtractors:get_extractor_for_node] Failed to resolve extractor for node out of %s defined extractor: %s' % [ instances.size(), node ])
	return null

func register_extractors() -> void:
	register(PlayerMeshExtractor)
	register(CivilianMeshExtractor)
	register(NemesisBasedMeshExtractor)
	register(WeaponMeshExtractor)
	register(PropMeshExtractor)
	register(CarMeshExtractor)
