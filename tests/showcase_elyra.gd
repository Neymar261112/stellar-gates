extends Node
## Survol cinématique du test de décor : la clairière de l'Arche sur Élyra.
## Caméra libre sur des trajets clés, puis vol du Solaris dans le décor.
## Lancer : xvfb-run godot --path . --rendering-driver opengl3 --write-movie out/f.png --fixed-fps 24 tests/showcase_elyra.tscn

var t := 0.0
var _done := {}
var _fade: ColorRect
var cam: Camera3D
var _seg_a := Vector3.ZERO
var _seg_b := Vector3.ZERO
var _seg_t0 := 0.0
var _seg_dur := 0.0
var _seg_look := Vector3.ZERO
var _seg_look_b := Vector3.ZERO
var _seg_on := false
var _orbit := false
var _orbit_t0 := 0.0
@onready var world: Node3D = $World
@onready var player: CharacterBody3D = $World/Player


func _ready() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 50
	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 1)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_fade)
	add_child(layer)
	cam = Camera3D.new()
	cam.fov = 62.0
	cam.far = 1200.0
	world.add_child(cam)
	player.camera.current = false
	cam.current = true
	# Le Solaris attend près de l'Arche, face à la porte
	var h: float = world.height_at(4.0, 6.0)
	tp(Vector3(4.0, h + 0.5, 6.0), 0.0)


func at(time: float, key: String, f: Callable) -> void:
	if t >= time and not _done.has(key):
		_done[key] = true
		f.call()


func fade(to_alpha: float, dur: float) -> void:
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", to_alpha, dur)


func tp(pos: Vector3, yaw: float, pitch := 0.25) -> void:
	player.global_position = pos
	player.velocity = Vector3.ZERO
	player.state = player.State.GROUND
	player.cam_yaw = yaw
	player.cam_pitch = pitch
	player.model.rotation.y = yaw
	player.pivot.rotation.y = yaw


## Trajet caméra de a vers b en dur secondes, regard glissant de look vers look_b
func seg(a: Vector3, b: Vector3, look: Vector3, dur: float, look_b := Vector3.INF) -> void:
	_seg_a = a; _seg_b = b; _seg_look = look
	_seg_look_b = look if look_b == Vector3.INF else look_b
	_seg_t0 = t; _seg_dur = dur; _seg_on = true; _orbit = false
	cam.global_position = a
	cam.look_at(look)


func cut_seg(a: Vector3, b: Vector3, look: Vector3, dur: float, look_b := Vector3.INF) -> void:
	fade(1.0, 0.4)
	get_tree().create_timer(0.45).timeout.connect(func():
		seg(a, b, look, dur, look_b)
		fade(0.0, 0.7))


func _physics_process(delta: float) -> void:
	t += delta
	if _seg_on:
		var k := clampf((t - _seg_t0) / _seg_dur, 0.0, 1.0)
		var e := k * k * (3.0 - 2.0 * k) * 0.6 + k * 0.4
		cam.global_position = _seg_a.lerp(_seg_b, e)
		cam.look_at(_seg_look.lerp(_seg_look_b, e))
	if _orbit:
		var a := (t - _orbit_t0) * 0.28 + 2.6
		cam.global_position = Vector3(cos(a) * 17.0, 5.5 + sin(a * 0.7) * 1.5, -18.0 + sin(a) * 17.0)
		cam.look_at(Vector3(0.0, 4.5, -18.0))
	# --- 1. Descente depuis la vallée ouverte vers la clairière
	at(0.1, "s1", func(): seg(Vector3(-105.0, 75.0, 120.0), Vector3(-22.0, 24.0, 44.0), Vector3(0.0, 6.0, -18.0), 9.0); fade(0.0, 1.4))
	# --- 2. Rase-mottes au-dessus de la clairière, le Solaris au premier plan
	at(9.0, "s2", func(): cut_seg(Vector3(34.0, 2.8, 26.0), Vector3(-6.0, 3.4, 2.0), Vector3(4.0, 2.5, 6.0), 7.0, Vector3(0.0, 6.0, -18.0)))
	# --- 3. Tour de l'Arche
	at(16.5, "s3", func():
		fade(1.0, 0.4)
		get_tree().create_timer(0.45).timeout.connect(func():
			_seg_on = false; _orbit = true; _orbit_t0 = t
			fade(0.0, 0.7)))
	# --- 4. Le sanctuaire enfoui sous les racines
	at(23.0, "s4", func(): cut_seg(Vector3(-16.0, 7.0, -6.0), Vector3(-36.0, 4.5, -20.0), Vector3(-46.0, 6.0, -30.0), 6.5))
	# --- 5. La cascade et le bassin
	at(29.5, "s5", func(): cut_seg(Vector3(34.0, 12.0, -34.0), Vector3(14.0, 5.0, -48.0), Vector3(8.0, 18.0, -74.0), 6.0, Vector3(8.0, 8.0, -66.0)))
	# --- 6. Le Solaris décolle et file vers la vallée
	at(35.5, "s6", func():
		fade(1.0, 0.4)
		get_tree().create_timer(0.45).timeout.connect(func():
			_seg_on = false; _orbit = false
			cam.current = false
			player.camera.current = true
			tp(Vector3(4.0, world.height_at(4.0, 6.0) + 0.5, 6.0), 2.5, 0.3)
			fade(0.0, 0.6)))
	at(36.6, "walk", func(): Input.action_press("move_forward"))
	at(37.4, "jump", func(): player._fly_press())
	at(37.75, "fly", func(): player._fly_press(); player.cam_pitch = 0.0)
	at(39.5, "boost", func(): player._dash_press(); player.cam_pitch = 0.3)
	at(41.0, "turn", func(): player.cam_yaw = 1.2; player.cam_pitch = 0.3)
	at(43.0, "turn2", func(): player.cam_yaw = 0.2; player.cam_pitch = 0.3)
	at(45.0, "end", func(): fade(1.0, 1.0))
	at(46.2, "quit", func(): Input.action_release("move_forward"); get_tree().quit())
