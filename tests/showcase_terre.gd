extends Node
## Vidéo d'une minute : la carte de la Terre (vallée d'Horizon) et l'équipage.
## Lancer : xvfb-run godot --path . --rendering-driver opengl3 --write-movie out/f.png --fixed-fps 24 tests/showcase_terre.tscn

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
var _orbit_c := Vector3.ZERO
var _orbit_r := 50.0
var _orbit_h := 15.0
var _orbit_speed := 0.3
var _orbit_a0 := 0.0
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
	cam.far = 1500.0
	world.add_child(cam)
	player.camera.current = false
	cam.current = true
	# Pour re-rendre un morceau : SHOWCASE_START=40 godot ...
	var st := OS.get_environment("SHOWCASE_START")
	if st != "":
		t = float(st)


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


func cut_orbit(c: Vector3, r: float, h: float, speed: float, a0: float) -> void:
	fade(1.0, 0.4)
	get_tree().create_timer(0.45).timeout.connect(func():
		_seg_on = false; _orbit = true; _orbit_t0 = t
		_orbit_c = c; _orbit_r = r; _orbit_h = h; _orbit_speed = speed; _orbit_a0 = a0
		fade(0.0, 0.7))


func _physics_process(delta: float) -> void:
	t += delta
	if _seg_on:
		var k := clampf((t - _seg_t0) / _seg_dur, 0.0, 1.0)
		var e := k * k * (3.0 - 2.0 * k) * 0.6 + k * 0.4
		cam.global_position = _seg_a.lerp(_seg_b, e)
		cam.look_at(_seg_look.lerp(_seg_look_b, e))
	if _orbit:
		var a := (t - _orbit_t0) * _orbit_speed + _orbit_a0
		cam.global_position = _orbit_c + Vector3(cos(a) * _orbit_r, _orbit_h + sin(a * 0.7) * 2.0, sin(a) * _orbit_r)
		cam.look_at(_orbit_c)
	var zx: float = world.PLAZA.x
	var zz: float = world.PLAZA.y - 6.0
	# --- 1. La vallée sous la pluie, vue du lac vers le fond
	at(0.1, "s1", func(): seg(Vector3(60.0, 110.0, 300.0), Vector3(20.0, 55.0, 150.0), Vector3(0.0, 10.0, -40.0), 10.0, Vector3(0.0, 20.0, -150.0)); fade(0.0, 1.6))
	# --- 2. La base Horizon
	at(10.0, "s2", func(): cut_seg(Vector3(world.BASE.x - 80.0, 22.0, world.BASE.y + 75.0), Vector3(world.BASE.x - 40.0, 19.0, world.BASE.y + 4.0), Vector3(world.BASE.x + 10.0, 6.0, world.BASE.y - 10.0), 7.0, Vector3(world.BASE.x + 44.0, 14.0, world.BASE.y - 12.0)))
	# --- 3. L'Aster posé sur son aire
	at(17.0, "s3", func(): cut_orbit(Vector3(world.PAD.x, 10.0, world.PAD.y), 58.0, 20.0, 0.22, 0.9))
	# --- 4. La mine
	at(25.0, "s4", func(): cut_seg(Vector3(world.MINE.x + 95.0, 34.0, world.MINE.y + 70.0), Vector3(world.MINE.x + 30.0, 16.0, world.MINE.y + 42.0), Vector3(world.MINE.x + 10.0, 2.0, world.MINE.y), 7.0, Vector3(world.MINE.x + 50.0, 20.0, world.MINE.y)))
	# --- 5. L'Arche au fond de la vallée
	at(32.0, "s5", func(): cut_seg(Vector3(10.0, 34.0, -50.0), Vector3(-14.0, 12.0, -112.0), Vector3(0.0, 12.0, -150.0), 8.0))
	# --- 6. L'équipage : travelling le long de la ligne, puis le Solaris
	at(40.0, "s6", func(): cut_seg(Vector3(zx - 16.0, 4.0, zz + 7.5), Vector3(zx + 16.0, 4.0, zz + 7.5), Vector3(zx - 14.0, 1.6, zz), 11.0, Vector3(zx + 14.0, 1.6, zz)))
	at(51.0, "s7", func(): cut_seg(Vector3(zx + 7.0, 4.8, zz + 20.0), Vector3(zx + 2.0, 3.8, zz + 15.5), Vector3(zx, 2.2, zz + 10.0), 3.5))
	# --- 7. Décollage et vol vers le fond de la vallée, caméra du jeu
	at(54.5, "s8", func():
		fade(1.0, 0.4)
		get_tree().create_timer(0.45).timeout.connect(func():
			_seg_on = false; _orbit = false
			cam.current = false
			player.camera.current = true
			tp(Vector3(zx, 3.3, zz + 10.0), 0.0, 0.3)
			fade(0.0, 0.6)))
	at(55.3, "walk", func(): Input.action_press("move_forward"))
	at(55.9, "jump", func(): player._fly_press())
	at(56.25, "fly", func(): player._fly_press(); player.cam_pitch = 0.05)
	at(58.0, "boost", func(): player._dash_press(); player.cam_pitch = 0.25)
	at(60.0, "level", func(): player.cam_pitch = 0.35)
	at(61.5, "end", func(): fade(1.0, 1.0))
	at(62.6, "quit", func(): Input.action_release("move_forward"); get_tree().quit())
