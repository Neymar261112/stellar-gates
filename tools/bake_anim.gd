extends Node
## Transfert des animations capturées (Xbot de three.js, rig Mixamo : idle, walk, run) sur les 17 os du Solaris.
## Buste, tête et jambes : même rotation que le modèle source par rapport à sa pose de repos.
## Bras : la source est en T, le Solaris bras le long du corps ; on aligne donc la DIRECTION de chaque segment.
## Sortie : assets/anim/locomotion.json (rotations locales par os, 30 images/s, + balancement du bassin).
## Lancer : godot --headless --path . tools/bake_anim.tscn

const SRC := "res://assets/anim/src/Xbot.glb"
const FPS := 30.0
const MAP := { "hips": "Hips", "spine": "Spine", "chest": "Spine2", "neck": "Neck", "head": "Head",
	"thigh_L": "LeftUpLeg", "shin_L": "LeftLeg", "foot_L": "LeftFoot",
	"thigh_R": "RightUpLeg", "shin_R": "RightLeg", "foot_R": "RightFoot" }
const ARMS := { "upper_arm_L": ["LeftArm", "LeftForeArm"], "forearm_L": ["LeftForeArm", "LeftHand"],
	"upper_arm_R": ["RightArm", "RightForeArm"], "forearm_R": ["RightForeArm", "RightHand"] }


func _ready() -> void:
	var src: Node = load(SRC).instantiate()
	add_child(src)
	var sk: Skeleton3D = src.find_children("*", "Skeleton3D")[0]
	var ap: AnimationPlayer = src.find_children("*", "AnimationPlayer")[0]
	var ours: Node = load("res://assets/solaris/aegis_rig.glb").instantiate()
	var osk: Skeleton3D = ours.find_children("*", "Skeleton3D")[0]
	var names := []
	for i in osk.get_bone_count():
		names.append(osk.get_bone_name(i))
	var rest_pos := {}
	for nm in names:
		rest_pos[nm] = osk.get_bone_global_rest(osk.find_bone(nm)).origin
	var child_of := { "upper_arm_L": "forearm_L", "forearm_L": "hand_L", "upper_arm_R": "forearm_R", "forearm_R": "hand_R" }
	var sb := func(n: String) -> int: return sk.find_bone("mixamorig_" + n)
	var hips_h: float = sk.get_bone_global_rest(sb.call("Hips")).origin.y - sk.get_bone_global_rest(sb.call("LeftFoot")).origin.y
	var our_h: float = rest_pos["hips"].y - rest_pos["foot_L"].y
	var out := { "bones": names, "fps": FPS, "clips": {} }
	for clip in ["idle", "walk", "run"]:
		var len_s: float = ap.get_animation(clip).length
		var n_frames := int(round(len_s * FPS))
		var frames := []
		ap.play(clip)
		for f in n_frames:
			ap.seek(f / FPS, true)
			var glob := {}
			for nm in MAP:
				var i: int = sb.call(MAP[nm])
				var d: Basis = sk.get_bone_global_pose(i).basis.orthonormalized() * sk.get_bone_global_rest(i).basis.orthonormalized().inverse()
				glob[nm] = d.get_rotation_quaternion()
			for nm in ARMS:
				var a: Vector3 = sk.get_bone_global_pose(sb.call(ARMS[nm][0])).origin
				var b: Vector3 = sk.get_bone_global_pose(sb.call(ARMS[nm][1])).origin
				var r: Vector3 = (rest_pos[child_of[nm]] - rest_pos[nm]).normalized()
				glob[nm] = Quaternion(r, (b - a).normalized())
			glob["hand_L"] = glob["forearm_L"]
			glob["hand_R"] = glob["forearm_R"]
			var parent := { "spine": "hips", "chest": "spine", "neck": "chest", "head": "neck",
				"upper_arm_L": "chest", "forearm_L": "upper_arm_L", "hand_L": "forearm_L",
				"upper_arm_R": "chest", "forearm_R": "upper_arm_R", "hand_R": "forearm_R",
				"thigh_L": "hips", "shin_L": "thigh_L", "foot_L": "shin_L",
				"thigh_R": "hips", "shin_R": "thigh_R", "foot_R": "shin_R" }
			var row := []
			for nm in names:
				var q: Quaternion = glob[nm]
				if parent.has(nm):
					q = glob[parent[nm]].inverse() * q
				q = q.normalized()
				row.append([snappedf(q.x, 0.0001), snappedf(q.y, 0.0001), snappedf(q.z, 0.0001), snappedf(q.w, 0.0001)])
			var hp: Vector3 = sk.get_bone_global_pose(sb.call("Hips")).origin - sk.get_bone_global_rest(sb.call("Hips")).origin
			hp *= our_h / hips_h
			frames.append({ "q": row, "hips": [snappedf(hp.x, 0.0001), snappedf(hp.y, 0.0001)] })
		out["clips"][clip] = { "length": len_s, "frames": frames }
		print("[bake] ", clip, " ", n_frames, " images")
	var fa := FileAccess.open("res://assets/anim/locomotion.json", FileAccess.WRITE)
	fa.store_string(JSON.stringify(out))
	fa.close()
	print("[bake] OK")
	get_tree().quit()
