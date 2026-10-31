extends Node
## Captures des nouvelles pièces Meshy (29 oct) portées dans la Forge : repos de face, 3/4, marche, visée
## et gros plan du casque de 3/4. -> videos/nouvelles_pieces/<cas>_<pose>.png  (un seul cas : CAS=<nom>)
var f: Node3D

const CASES := [
	["sentinelle_braise", { "chest": "ranger.sentinelle_braise.chest" }],
	["sentinelle_braise2", { "chest": "ranger.sentinelle_braise2.chest" }],
	["avantgarde_braise", { "chest": "ranger.avantgarde_braise.chest", "legs": "ranger.mech.legs" }],
	["sentinelle_orange", { "chest": "ranger.sentinelle_orange.chest" }],
	["titan_orange", { "chest": "ranger.titan_orange.chest", "helmet": "ranger.mech.helmet", "legs": "ranger.mech.legs" }],
	["avantgarde_titan", { "chest": "ranger.avantgarde_titan.chest", "arms": "ranger.exo.arms" }],
	["plastron_titan", { "chest": "ranger.plastron_titan.chest", "arms": "ranger.mech.arms" }],
	["gantelet_tigre", { "arms": "ranger.gantelet_tigre.arms" }],
	["griffe_braise", { "arms": "ranger.griffe_braise.arms", "chest": "ranger.sentinelle_braise.chest" }],
	# 2e lot : casques et bras
	["mech_casque", { "helmet": "ranger.mech.helmet" }],
	["aegis_precision", { "helmet": "ranger.casque_aegis.helmet", "arms": "ranger.bras_precision.arms" }],
	["guepe_limier", { "helmet": "ranger.casque_guepe.helmet", "arms": "ranger.bras_limier.arms", "chest": "ranger.sentinelle_orange.chest" }],
	["minuit_cyber", { "helmet": "ranger.casque_minuit.helmet", "arms": "ranger.bras_cyber.arms" }],
	["neon_cyber2", { "helmet": "ranger.casque_neon.helmet", "arms": "ranger.bras_cyber2.arms", "chest": "ranger.avantgarde_titan.chest" }],
	["masque_prothese", { "helmet": "ranger.masque_orange.helmet", "arms": "ranger.bras_prothese.arms" }],
	["vide_allonge", { "helmet": "ranger.casque_vide.helmet", "arms": "ranger.bras_allonge.arms", "chest": "ranger.titan_orange.chest" }],
	["serre", { "arms": "ranger.bras_serre.arms", "helmet": "ranger.casque_neon.helmet" }],
	["exocoque", { "arms": "ranger.bras_exocoque.arms", "chest": "ranger.avantgarde_braise.chest", "helmet": "ranger.casque_vide.helmet" }],
	["mech_braise", { "arms": "ranger.bras_mech_braise.arms", "chest": "ranger.sentinelle_braise.chest" }],
	["cobra", { "arms": "ranger.bras_cobra.arms", "helmet": "ranger.masque_orange.helmet" }],
	["servo", { "arms": "ranger.bras_servo.arms", "helmet": "ranger.casque_minuit.helmet", "chest": "ranger.plastron_titan.chest" }],
	["pince_titan", { "arms": "ranger.pince_titan.arms", "helmet": "ranger.casque_aegis.helmet", "chest": "ranger.titan_orange.chest", "legs": "ranger.mech.legs" }],
	["casque_braise", { "helmet": "ranger.casque_braise.helmet", "chest": "ranger.sentinelle_braise.chest", "arms": "ranger.griffe_braise.arms" }],
]

## Pose de marche figée (comme tests/pieces_shots.gd)
const MARCHE := { "thigh_L": Vector3(-0.6, 0, 0), "shin_L": Vector3(0.35, 0, 0), "thigh_R": Vector3(0.4, 0, 0), "shin_R": Vector3(0.8, 0, 0),
	"foot_R": Vector3(-0.3, 0, 0), "upper_arm_L": Vector3(0.4, 0, 0.1), "upper_arm_R": Vector3(-0.45, 0, -0.1),
	"forearm_L": Vector3(-0.35, 0, 0), "forearm_R": Vector3(-0.7, 0, 0), "spine": Vector3(0.08, 0.12, 0) }


func _ready() -> void:
	var dir := ProjectSettings.globalize_path("res://videos/nouvelles_pieces")
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
	var only := OS.get_environment("CAS")
	for c in CASES:
		if only != "" and not c[0] in only.split(","):
			continue
		var look: Dictionary = base.duplicate(true)
		for slot in c[1]:
			look[slot + "_piece_id"] = c[1][slot]
		Appearance.set_current(look)
		await get_tree().create_timer(0.5).timeout
		# [nom, angle, visée, marche, point visé, distance]
		for s in [["face", 0.0, false, false, Vector3(0, 1.15, 0), 3.0], ["3q", 0.75, false, false, Vector3(0, 1.15, 0), 3.0],
				["marche", 0.75, false, true, Vector3(0, 1.15, 0), 3.0], ["visee", 0.6, true, false, Vector3(0, 1.15, 0), 3.0],
				["tete", 0.8, false, false, Vector3(0, 1.72, 0), 1.1]]:
			f.solaris.combat.aiming = s[2]
			if s[3]:
				anim.set_process(false)
				for b in MARCHE:
					sk.set_bone_pose_rotation(sk.find_bone(b), Quaternion.from_euler(MARCHE[b]))
			for k in (70 if s[2] else 12):
				f._yaw = s[1]
				f._idle = 0.0
				f._want_focus = s[4]
				f._want_dist = s[5]
				f._focus = f._want_focus
				f._dist = f._want_dist
				await get_tree().process_frame
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png("%s/%s_%s.png" % [dir, c[0], s[0]])
			anim.set_process(true)
		f.solaris.combat.aiming = false
	print("nouvelles_pieces_shots ok")
	get_tree().quit()
