extends Node
## Captures du kit du Ranger sur le Solaris : fusil en main et Twin Vipers dans le dos, changement d'arme,
## tir des Twin Vipers, vol stationnaire en visée, batterie de missiles sur les épaules.
## Lancer avec rendu : xvfb-run godot --rendering-driver opengl3 --path . tests/weapon_shots.tscn
var p
var cam: Camera3D


func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://out/weapon_%s.png" % name)


func frame(dist: float, side_k: float, back_k: float, h := 1.2) -> void:
	var c: Vector3 = p.global_position + Vector3(0, h, 0)
	var fwd: Vector3 = -p.model.global_basis.z
	var side: Vector3 = p.model.global_basis.x
	cam.look_at_from_position(c + fwd * dist * (1.0 - back_k) - fwd * dist * back_k + side * dist * side_k + Vector3(0, 0.25, 0), c)


func _ready() -> void:
	Appearance.persist = false
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://out"))
	var terre: Node3D = load("res://scenes/terre.tscn").instantiate()
	add_child(terre)
	p = terre.get_node("Player")
	await get_tree().create_timer(1.5).timeout
	cam = Camera3D.new()
	add_child(cam)
	cam.fov = 45.0
	cam.current = true
	frame(2.6, 0.6, 0.0)
	await get_tree().create_timer(0.5).timeout
	await shot("face")
	frame(2.6, 0.5, 1.0)
	await shot("dos")
	frame(2.4, 1.0, 0.5)
	await shot("cote")
	# Changement d'arme : à mi-geste, puis Twin Vipers en main
	p.combat.switch_weapon()
	await get_tree().create_timer(0.22).timeout
	frame(2.6, 0.9, 0.3)
	await shot("degaine")
	await get_tree().create_timer(0.6).timeout
	Input.action_press("aim")
	await get_tree().create_timer(0.8).timeout
	frame(2.6, 0.8, 0.0)
	await shot("vipers_visee")
	p.combat.fire()
	await get_tree().create_timer(0.03).timeout
	await shot("vipers_tir")
	Input.action_release("aim")
	# Vol stationnaire en visée
	p.can_fly = true
	p.global_position += Vector3(0, 5, 0)
	p.state = p.State.HOVER
	Input.action_press("aim")
	await get_tree().create_timer(0.8).timeout
	frame(3.2, 0.8, 0.2, 1.0)
	await shot("stationnaire")
	Input.action_release("aim")
	# Batterie de missiles
	p.combat.ult_charge = 100.0
	p.combat.use_ultimate()
	await get_tree().create_timer(0.8).timeout
	frame(2.6, 0.6, 0.85, 1.4)
	await shot("batterie_dos")
	frame(2.8, 0.8, 0.0, 1.4)
	await shot("batterie_face")
	get_tree().quit()
