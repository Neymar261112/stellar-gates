extends Node
## Démo scriptée pour enregistrer une vidéo : Élyra (marche, saut, vol, piqué), cascade, Arche, Varda (vol au-dessus de la lave, hover, atterrissage).
## Lancer : xvfb-run godot --path . --rendering-driver opengl3 --write-movie out/showcase.png --fixed-fps 24 tests/showcase.tscn

var t := 0.0
var _done := {}
var _yaw_rate := 0.0
var _pitch_target := -1.0
@onready var main: Node = $Main
@onready var player: CharacterBody3D = $Main/Player


func at(time: float, key: String, f: Callable) -> void:
	if t >= time and not _done.has(key):
		_done[key] = true
		f.call()


func fade(to_alpha: float, dur: float) -> void:
	var tw := create_tween()
	tw.tween_property(main._fade, "color:a", to_alpha, dur)


func _physics_process(delta: float) -> void:
	t += delta
	if _yaw_rate != 0.0:
		player.cam_yaw += _yaw_rate * delta
	if _pitch_target >= -0.6:
		player.cam_pitch = lerpf(player.cam_pitch, _pitch_target, minf(1.0, delta * 3.0))
	# ---- Scène 1 : Élyra, marche, saut, décollage, vol en cercle au-dessus de la plaine, piqué
	at(0.2, "fadein", func(): main._fade.color.a = 1.0; fade(0.0, 1.0))
	at(1.0, "walk", func(): Input.action_press("move_forward"))
	at(2.0, "turn1", func(): _yaw_rate = 0.35)
	at(3.5, "turn1end", func(): _yaw_rate = 0.0)
	at(4.0, "jump", func(): player._fly_press())
	at(4.35, "fly", func(): player._fly_press(); _pitch_target = 0.2)
	at(6.0, "circle", func(): _pitch_target = 0.42; _yaw_rate = -0.55)
	at(10.5, "dive", func(): _yaw_rate = -0.2; _pitch_target = 0.8)
	at(12.0, "pullup", func(): _pitch_target = 0.3)
	# ---- Scène 2 : la cascade refroidit
	at(13.0, "cut2", func(): fade(1.0, 0.4))
	at(13.5, "scene2", func():
		Input.action_release("move_forward")
		player.heat = 0.85
		player.global_position = Vector3(93.75, 1.3, 62.0)
		player.velocity = Vector3(0, 0, -12)
		player.state = player.State.FLY
		player.cam_yaw = 0.0
		player.cam_pitch = 0.42
		player.takeoff_t = 0.0
		_pitch_target = 0.42
		fade(0.0, 0.4))
	at(14.6, "climb2", func(): _pitch_target = 0.12)
	at(16.3, "hover2", func(): _pitch_target = 0.42; player._fly_press())
	# ---- Scène 3 : l'Arche vers Varda (le jeu fait lui-même le fondu et charge Varda)
	at(18.0, "cut3", func(): fade(1.0, 0.4))
	at(18.5, "scene3", func():
		player.state = player.State.GROUND
		player.velocity = Vector3.ZERO
		player.global_position = main.world.arrival_position()
		player.cam_yaw = 0.0
		player.cam_pitch = 0.3
		_pitch_target = 0.3
		fade(0.0, 0.4)
		Input.action_press("move_forward"))
	at(20.5, "stop3", func(): Input.action_release("move_forward"))
	# ---- Scène 4 : Varda, regard circulaire, vol au-dessus de la lave, hover, atterrissage
	at(23.0, "look", func(): _yaw_rate = 0.6)
	at(26.0, "lookend", func(): _yaw_rate = 0.0)
	at(26.5, "walk4", func(): Input.action_press("move_forward"))
	at(27.5, "jump4", func(): player._fly_press())
	at(27.85, "fly4", func(): player._fly_press(); _pitch_target = 0.15)
	at(30.0, "level4", func(): _pitch_target = 0.42; _yaw_rate = 0.45)
	at(33.5, "hover4", func(): _yaw_rate = 0.0; player._fly_press())
	at(35.5, "land4", func(): player._land_press(); Input.action_release("move_forward"))
	at(38.5, "cutend", func(): fade(1.0, 0.8))
	at(39.5, "quit", func(): get_tree().quit())
