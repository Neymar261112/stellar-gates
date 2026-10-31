extends Node
## Gros plans de la tenue des armes : repos, visée, tir à la hanche, changement d'arme (4 étapes), course.
## Lancer : xvfb-run godot --rendering-driver opengl3 --path . tests/hold_shots.tscn  (images out/hold_*.png)
@onready var main: Node = $Main
@onready var player: CharacterBody3D = $Main/Player
var cam: Camera3D


func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://out/hold_%s.png" % name)


func wait(s: float) -> void:
	await get_tree().create_timer(s).timeout


func frame(side_k: float, back_k: float, dist := 1.7, h := 1.25) -> void:
	var c: Vector3 = player.global_position + Vector3(0, h, 0)
	var fwd: Vector3 = -player.model.global_basis.z
	var right: Vector3 = player.model.global_basis.x
	cam.look_at_from_position(c + (fwd * (1.0 - back_k) - fwd * back_k + right * side_k).normalized() * dist + Vector3(0, 0.2, 0), c)


func _ready() -> void:
	Appearance.persist = false
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://out"))
	await wait(1.5)
	player.global_position = Vector3(23.75, 0.2, 76.25)
	player.cam_yaw = 0.0
	player.cam_pitch = 0.05
	cam = Camera3D.new()
	add_child(cam)
	cam.fov = 50.0
	await wait(0.8)
	cam.current = true
	var views := { "face": [0.5, 0.0], "cote": [1.0, 0.45], "dos": [0.5, 1.0] }
	for v in views:
		frame(views[v][0], views[v][1])
		await shot("repos_" + v)
	Input.action_press("aim")
	await wait(0.7)
	for v in views:
		frame(views[v][0], views[v][1])
		await shot("vise_" + v)
	Input.action_release("aim")
	await wait(0.5)
	# Changement d'arme, vu de côté-arrière
	frame(1.0, 0.7)
	player.combat.switch_weapon()
	for k in [0.15, 0.3, 0.45, 0.6, 0.8]:
		await wait(0.13 if k != 0.15 else 0.135)
		frame(1.0, 0.7)
		await shot("switch_%d" % int(k * 100))
	await wait(0.5)
	frame(0.5, 0.0)
	await shot("vipers_repos")
	Input.action_press("aim")
	await wait(0.7)
	frame(0.8, 0.1)
	await shot("vipers_vise")
	Input.action_release("aim")
	get_tree().quit()
