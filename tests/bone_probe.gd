extends SceneTree
func _init():
	await process_frame
	var p = load("res://scenes/player.tscn").instantiate()
	root.add_child(p)
	await process_frame
	var sk: Skeleton3D = p.look.skeleton
	var model: Node3D = p.model
	var m := model.global_transform.affine_inverse() * sk.global_transform
	for b in ["thigh_L", "shin_L", "foot_L", "hips", "spine", "chest"]:
		var i := sk.find_bone(b)
		print(b, " ", m * sk.get_bone_global_rest(i).origin)
	# extents of body vertices near left hand
	quit()
