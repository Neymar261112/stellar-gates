extends "res://tests/showcase_attaques.gd"
## Vidéo de la tenue des armes : repos, marche, course à deux mains, changement d'arme (ranger dans le dos,
## attraper l'autre), visée épaulée, changement en marchant, stationnaire.
## Lancer : xvfb-run godot --path . --rendering-driver opengl3 --write-movie out/f.png --fixed-fps 24 tests/showcase_armes.tscn

var close: Camera3D
var _cv := Vector4(0, 0, 0, 0)         # caméra de près : côté, arrière, distance, hauteur (distance 0 = caméra du jeu)
var _cam_pos := Vector3.ZERO


func view(side_k: float, back_k: float, dist := 2.6, h := 1.3) -> void:
	_cv = Vector4(side_k, back_k, dist, h)


func _process(delta: float) -> void:
	if close == null:
		close = Camera3D.new()
		close.fov = 50.0
		add_child(close)
	if _cv.z <= 0.0:
		player.camera.current = true
		return
	var c: Vector3 = player.global_position + Vector3(0, _cv.w, 0)
	var fwd: Vector3 = -player.model.global_basis.z
	var right: Vector3 = player.model.global_basis.x
	var want: Vector3 = c + (fwd * (1.0 - _cv.y) - fwd * _cv.y + right * _cv.x).normalized() * _cv.z + Vector3(0, 0.25, 0)
	_cam_pos = want if not close.current else _cam_pos.lerp(want, minf(1.0, delta * 4.0))
	close.current = true
	close.look_at_from_position(_cam_pos, c)


func _physics_process(delta: float) -> void:
	t += delta
	if _hold_yaw != INF:
		player.cam_yaw = lerp_angle(player.cam_yaw, _hold_yaw, minf(1.0, delta * 5.0))
	if _hold_pitch != INF:
		player.cam_pitch = lerpf(player.cam_pitch, _hold_pitch, minf(1.0, delta * 4.0))
	var c = player.combat
	c.health = c.max_health
	c.shield = c.max_shield
	var start := Vector3(16.25, 0.2, 86.0)
	var t0 := Vector3(16.25, 1.3, 63.75)
	at(0.05, "setup", func():
		for sl in Loadout.SLOTS:
			Loadout.set_tier(sl, 2)
		tp(start, yaw_to(start, t0), 0.25)
		view(0.75, 0.0, 2.8))
	at(0.6, "f0", func(): fade(0.0, 0.8); title("Au repos : l'arme tenue à deux mains"))
	at(2.6, "walk", func(): title("Marche"); _hold_yaw = player.cam_yaw + PI; view(0.6, 0.0, 3.4); Input.action_press("move_forward"))
	at(4.8, "run", func(): title("Course"); player.sprinting = true)
	at(6.6, "stop", func(): player.sprinting = false; Input.action_release("move_forward"))
	cut(6.9, "back", func(): tp(start, yaw_to(start, t0), 0.25))
	at(7.6, "sw_view", func(): title("Changer d'arme (Y) : il range le fusil dans le dos et prend l'autre"); view(0.8, 0.75, 2.6))
	at(8.2, "sw1", func(): c.switch_weapon())
	at(9.8, "sw_view2", func(): view(0.9, 0.3, 2.6))
	at(10.0, "sw2", func(): c.switch_weapon())
	at(11.6, "aim_view", func(): title("Visée (LT) : crosse à l'épaule"); view(0.9, 0.35, 2.4, 1.45))
	at(12.0, "aim", func(): Input.action_press("aim"))
	at(12.6, "fire", func(): Input.action_press("fire"))
	at(14.0, "fire_end", func(): Input.action_release("fire"))
	at(14.4, "aim_end", func(): Input.action_release("aim"))
	cut(14.6, "back2", func(): tp(start, yaw_to(start, t0), 0.25))
	at(15.0, "walk_sw", func(): title("Changement d'arme en marchant"); _hold_yaw = player.cam_yaw + PI; view(0.6, 0.1, 3.4); Input.action_press("move_forward"))
	at(15.6, "sw3", func(): c.switch_weapon())
	at(17.4, "sw4", func(): c.switch_weapon())
	at(19.0, "walk_sw_end", func(): Input.action_release("move_forward"))
	cut(19.0, "back3", func(): tp(start, yaw_to(start, t0), 0.2))
	at(19.4, "game_cam", func(): title("Vue du jeu"); view(0, 0, 0); _hold_pitch = 0.2)
	at(20.0, "aim3", func(): Input.action_press("aim"))
	at(20.4, "fire3", func(): Input.action_press("fire"))
	at(22.0, "fire3_end", func(): Input.action_release("fire"); Input.action_release("aim"))
	at(22.4, "hip", func(): title("Tir à la hanche"); Input.action_press("fire"))
	at(23.6, "hip_end", func(): Input.action_release("fire"))
	at(24.6, "end", func(): fade(1.0, 0.8))
	at(25.6, "quit", func(): get_tree().quit())
