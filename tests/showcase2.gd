extends Node
## Démo scriptée du combat : visée et tir sur un mannequin, mêlée, riposte de la tourelle, rechargement, drone abattu en vol stationnaire.
## Lancer : xvfb-run godot --path . --rendering-driver opengl3 --write-movie out/f.png --fixed-fps 24 tests/showcase2.tscn

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
	if _pitch_target >= -0.6 and not player.combat.aiming:
		player.cam_pitch = lerpf(player.cam_pitch, _pitch_target, minf(1.0, delta * 3.0))
	# ---- Mannequin : visée à l'épaule et rafale
	at(0.2, "fadein", func(): main._fade.color.a = 1.0; fade(0.0, 1.0); player.cam_pitch = 0.3; _pitch_target = 0.25)
	at(1.0, "walk", func(): Input.action_press("move_forward"))
	at(1.8, "stop", func(): Input.action_release("move_forward"))
	at(2.2, "aim", func(): Input.action_press("aim"))
	at(2.8, "fire", func(): Input.action_press("fire"))
	at(4.3, "firestop", func(): Input.action_release("fire"))
	at(4.5, "aimstop", func(): Input.action_release("aim"))
	# ---- Mêlée sur le deuxième mannequin
	at(4.6, "turn", func(): _yaw_rate = -1.41)
	at(5.6, "turnend", func(): _yaw_rate = 0.0; player.cam_yaw = -1.41)
	at(5.7, "walk2", func(): Input.action_press("move_forward"))
	at(6.1, "melee1", func(): player.combat._melee_press(); Input.action_release("move_forward"))
	at(7.3, "melee2", func(): player.combat._melee_press())
	at(7.9, "hip", func(): Input.action_press("fire"))
	at(8.7, "hipstop", func(): Input.action_release("fire"))
	# ---- La tourelle riposte : on la vise, on recharge au milieu
	at(9.0, "turn2", func(): _yaw_rate = -0.89)
	at(9.8, "turn2end", func(): _yaw_rate = 0.0; player.cam_yaw = -2.12)
	at(10.0, "aim2", func(): Input.action_press("aim"))
	at(10.4, "fire2", func(): Input.action_press("fire"))
	at(14.7, "fire2stop", func(): Input.action_release("fire"); Input.action_release("aim"))
	# ---- Vol stationnaire et drone
	at(15.0, "jump", func(): player._fly_press())
	at(15.35, "fly", func(): player._fly_press(); _pitch_target = 0.12)
	at(16.4, "hover", func(): player._fly_press(); _pitch_target = 0.42)
	at(16.6, "turn3", func(): _yaw_rate = 1.5)
	at(18.6, "turn3end", func(): _yaw_rate = 0.0; player.cam_yaw = 0.93)
	at(18.8, "aim3", func(): Input.action_press("aim"))
	at(19.4, "fire3", func(): Input.action_press("fire"))
	at(21.0, "fire3stop", func(): Input.action_release("fire"); Input.action_release("aim"))
	at(21.6, "land", func(): player._land_press())
	at(23.6, "cutend", func(): fade(1.0, 0.8))
	at(24.6, "quit", func(): get_tree().quit())
