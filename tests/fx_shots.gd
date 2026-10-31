extends Node
## Captures des effets d'attaque : éclair de bouche, balles, impacts, explosion, missile en vol, brasier.
## Lancer : xvfb-run godot --rendering-driver opengl3 --path . tests/fx_shots.tscn  (images dans out/fx_*.png)
@onready var main: Node = $Main
@onready var player: CharacterBody3D = $Main/Player


func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://out/fx_%s.png" % name)


func wait(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _ready() -> void:
	Appearance.persist = false
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://out"))
	await wait(1.5)
	player.global_position = Vector3(23.75, 0.2, 76.25)
	player.cam_yaw = 0.0
	player.cam_pitch = 0.05
	Input.action_press("aim")
	await wait(0.8)
	var c: Node = player.combat
	# Rafale au fusil : on capture juste après un tir
	for i in 4:
		c.fire_cd = 0.0
		c.fire()
		await get_tree().process_frame
		if i == 1:
			await shot("tir_bouche")
		await wait(0.1)
	await wait(0.05)
	await shot("tir_impacts")
	await wait(0.6)
	await shot("tir_poussiere")
	# Twin Vipers
	c.switch_weapon()
	await wait(0.8)
	c.fire_cd = 0.0
	c.fire()
	await get_tree().process_frame
	await shot("vipers_bouche")
	Input.action_release("aim")
	# Explosion au sol devant le joueur
	var fwd: Vector3 = -player.camera.global_basis.z
	fwd.y = 0
	fwd = fwd.normalized()
	var p: Vector3 = player.global_position + fwd * 12.0 + Vector3(0, 0.6, 0)
	Fx.explosion(p, 5.5, Color(1.0, 0.55, 0.2), 1.4)
	await get_tree().process_frame
	await get_tree().process_frame
	await shot("explo_0")
	await wait(0.2)
	await shot("explo_1")
	await wait(0.5)
	await shot("explo_2")
	await wait(1.5)
	await shot("explo_3")
	# Missile au poignet
	c.ult_charge = 100.0
	c.use_ultimate()
	await wait(0.7)
	c._salvo()
	await wait(0.35)
	await shot("missile_vol")
	await wait(0.4)
	await shot("missile_vol2")
	# Brasier
	c.equip(0, 2)
	c.power_cd = [0.0, 0.0]
	c.use_power(0)
	await wait(2.0)
	await shot("brasier")
	get_tree().quit()
