class_name NodeUtils


static func FindNodeOutsideTree(node: Node, path: String) -> Node:
	if node.get_child_count() == 0:
		push_warning('[FindNodeOutsideTree] Node %s has no children.' % [ node ])
		return null

	var curr := node
	var npath := NodePath(path)
	var segment_count := npath.get_name_count()

	var resolved: Node

	for idx in segment_count:
		# Set target
		var node_name := npath.get_name(idx)

		var found := false

		# Search for target
		for child_idx in curr.get_child_count():
			var child := curr.get_child(child_idx)
			var child_name := child.name

			# Found
			if child.name == node_name:
				# Update depth (and returned value)
				curr = child
				resolved = child
				found = true
				break

		# Check flag
		if not found:
			return null

	return resolved
