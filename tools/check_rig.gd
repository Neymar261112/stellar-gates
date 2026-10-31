extends SceneTree
func _init() -> void:
	var scene: PackedScene = load("res://assets/solaris/solaris_rig.glb")
	if scene == null:
		print("PAS DE SCENE"); quit(); return
	var root := scene.instantiate()
	_dump(root, 0)
	for sk in root.find_children("*", "Skeleton3D"):
		print("bones ", sk.get_bone_count())
		for i in sk.get_bone_count():
			print("  ", i, " ", sk.get_bone_name(i), " parent ", sk.get_bone_parent(i), " rest ", sk.get_bone_rest(i).origin)
	for mi in root.find_children("*", "MeshInstance3D"):
		print("mesh ", mi.name, " skeleton ", mi.skeleton, " skin ", mi.skin != null, " aabb ", mi.get_aabb())
	quit()
func _dump(n: Node, d: int) -> void:
	print("  ".repeat(d), n.name, " (", n.get_class(), ")")
	for c in n.get_children(): _dump(c, d + 1)
