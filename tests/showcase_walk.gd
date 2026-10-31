extends Node
## Vidéo courte : repos, marche lente, trot, course, arrêt. Caméra de côté puis de 3/4 dos.
## Lancer : xvfb-run godot --path . --rendering-driver opengl3 --write-movie out/f.png --fixed-fps 30 tests/showcase_walk.tscn

var t := 0.0
var _done := {}
var cam: Camera3D
var _side := Vector3(5.5, 1.4, 0)
@onready var player: CharacterBody3D = $Main/Player


func _ready() -> void:
	Appearance.persist = false
	Appearance.reset()
	cam = Camera3D.new()
	cam.fov = 50
	$Main.add_child(cam)


func at(time: float, key: String, f: Callable) -> void:
	if t >= time and not _done.has(key):
		_done[key] = true
		f.call()


func _process(_d: float) -> void:
	if cam and player:
		var target: Vector3 = player.model.global_position + Vector3(0, 1.0, 0)
		cam.global_position = cam.global_position.lerp(target + _side, 0.12) if t > 0.3 else target + _side
		cam.look_at(target)


func _physics_process(delta: float) -> void:
	t += delta
	at(0.05, "setup", func():
		for sl in Loadout.SLOTS:
			Loadout.set_tier(sl, 2)
		player.global_position = Vector3(53.5, 0.2, 86.0)
		player.cam_yaw = 0.0
		player.model.rotation.y = 0.0
		player.camera.current = false
		cam.current = true)
	at(2.0, "walk", func(): Input.action_press("move_forward", 0.4))
	at(5.0, "jog", func(): Input.action_press("move_forward", 1.0))
	at(8.0, "sprint", func(): player._sprint_press())
	at(9.5, "cam34", func(): _side = Vector3(2.5, 1.6, 4.5))
	at(11.0, "stop", func(): Input.action_release("move_forward"))
	at(13.5, "quit", func(): get_tree().quit())
