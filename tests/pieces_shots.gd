extends Node
## Captures avant/après des pièces Meshy portées (Forge) : repos, marche et visée, de face et de 3/4.
## PREFIX=avant|apres (variable d'environnement) -> videos/pieces_avant_apres/<prefix>_<cas>_<pose>_<angle>.png
var f: Node3D

const CASES := [
	["jambes_mech", { "legs": "ranger.mech.legs" }],
	["torse_mech", { "chest": "ranger.mech.chest" }],
	["mech_complet", { "helmet": "ranger.mech.helmet", "chest": "ranger.mech.chest", "arms": "ranger.mech.arms", "legs": "ranger.mech.legs" }],
	["bras_exo", { "arms": "ranger.exo.arms" }],
]

const POSES := {
	"repos": {},
	"marche": { "thigh_L": Vector3(-0.6, 0, 0), "shin_L": Vector3(0.35, 0, 0), "thigh_R": Vector3(0.4, 0, 0), "shin_R": Vector3(0.8, 0, 0),
		"foot_R": Vector3(-0.3, 0, 0), "upper_arm_L": Vector3(0.4, 0, 0.1), "upper_arm_R": Vector3(-0.45, 0, -0.1),
		"forearm_L": Vector3(-0.35, 0, 0), "forearm_R": Vector3(-0.7, 0, 0), "spine": Vector3(0.08, 0.12, 0) },
	"visee": {},     # la vraie visée du jeu (fusil épaulé, IK des deux mains)
}


func _ready() -> void:
	var prefix := OS.get_environment("PREFIX") if OS.get_environment("PREFIX") != "" else "apres"
	var dir := ProjectSettings.globalize_path("res://videos/pieces_avant_apres")
	DirAccess.make_dir_recursive_absolute(dir)
	f = load("res://scenes/atelier.tscn").instantiate()
	add_child(f)
	await get_tree().create_timer(1.0).timeout
	f._ui.visible = false
	var base: Dictionary = {}
	for p in Appearance.presets["ranger"]:
		if p["name"] == "Aegis":
			base = p.duplicate(true)
	var sk: Skeleton3D = f.solaris.look.skeleton
	var anim = f.solaris.anim
	for c in CASES:
		var look: Dictionary = base.duplicate(true)
		for slot in c[1]:
			look[slot + "_piece_id"] = c[1][slot]
		Appearance.set_current(look)
		await get_tree().create_timer(0.5).timeout
		for pose in POSES:
			f.solaris.combat.aiming = pose == "visee"
			if pose == "visee":
				await get_tree().create_timer(1.2).timeout
			anim.set_process(false)
			for b in anim.BONES:
				if pose == "marche":
					sk.set_bone_pose_rotation(sk.find_bone(b), Quaternion.from_euler(POSES[pose].get(b, Vector3.ZERO)))
			for ang in [["face", 0.0], ["3q", 0.75]]:
				for k in 12:
					f._yaw = ang[1]
					f._idle = 0.0
					f._want_focus = Vector3(0, 0.95, 0)
					f._want_dist = 4.2
					f._focus = f._want_focus
					f._dist = f._want_dist
					await get_tree().process_frame
				await RenderingServer.frame_post_draw
				get_viewport().get_texture().get_image().save_png("%s/%s_%s_%s_%s.png" % [dir, prefix, c[0], pose, ang[0]])
			anim.set_process(true)
		f.solaris.combat.aiming = false
	print("pieces_shots ok ", prefix)
	get_tree().quit()
