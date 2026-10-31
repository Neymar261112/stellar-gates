extends "res://tests/showcase_armes.gd"
## Comparaison de cadrage (« le Solaris est trop petit et trop loin ») : la même séquence trois fois,
## A = cadrage actuel, B = caméra rapprochée, C = caméra rapprochée + Solaris 15 % plus grand.
## Lancer : xvfb-run godot --path . --rendering-driver opengl3 --write-movie out/f.png --fixed-fps 24 tests/showcase_cadrage.tscn

const VARIANTS := [
	{"name": "A · Cadrage actuel (caméra à 4,6 m)", "dist": 1.0, "fov": 0.0, "y": 0.0, "size": 1.0},
	{"name": "B · Caméra rapprochée (3,2 m)", "dist": 0.7, "fov": -4.0, "y": -0.1, "size": 1.0},
	{"name": "C · Caméra rapprochée + Solaris 15 % plus grand", "dist": 0.7, "fov": -4.0, "y": -0.1, "size": 1.15},
]
const LEN := 9.0


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
	var east := Vector3(45.0, 0.2, 58.0)
	at(0.05, "setup", func():
		for sl in Loadout.SLOTS:
			Loadout.set_tier(sl, 2)
		view(0, 0, 0))
	for i in VARIANTS.size():
		var v: Dictionary = VARIANTS[i]
		var b := 0.1 + i * LEN
		var k := str(i)
		cut(b, "tp" + k, func():
			player.cam_dist_mult = v.dist
			player.cam_fov_add = v.fov
			player.cam_y_add = v.y
			player.size_scale = v.size
			tp(start, yaw_to(start, t0), 0.25))
		at(b + 0.5, "f" + k, func(): title(v.name))
		at(b + 1.8, "aim" + k, func(): Input.action_press("aim"))
		at(b + 2.2, "fire" + k, func(): Input.action_press("fire"))
		at(b + 3.6, "fire_end" + k, func(): Input.action_release("fire"); Input.action_release("aim"))
		at(b + 3.9, "turn" + k, func(): _hold_yaw = yaw_to(start, east); _hold_pitch = 0.2)
		at(b + 4.4, "walk" + k, func(): Input.action_press("move_forward"))
		at(b + 5.8, "run" + k, func(): player.sprinting = true)
		at(b + 7.6, "stop" + k, func(): player.sprinting = false; Input.action_release("move_forward"))
		at(b + 8.2, "out" + k, func(): fade(1.0, 0.6))
	at(VARIANTS.size() * LEN + 0.3, "quit", func(): get_tree().quit())
