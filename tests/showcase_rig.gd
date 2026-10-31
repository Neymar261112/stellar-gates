extends Node
## Démo du Solaris riggé sur la Terre : repos, marche, dash, saut, réception, mêlée, visée et tir,
## pouvoirs, vol, dash en vol, stationnaire, chute, puis survol de la vallée jusqu'à l'Arche.
## Lancer : xvfb-run godot --path . --rendering-driver opengl3 --write-movie out/f.png --fixed-fps 24 tests/showcase_rig.tscn

var t := 0.0
var _done := {}
var _fade: ColorRect
var cam: Camera3D
var _follow := false
var _follow_off := Vector3(4.0, 1.6, 3.0)
var _follow_local := true          # décalage tourné avec le Solaris
var _look_up := 1.0
var _label: Label
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
	_label = Label.new()
	_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_label.offset_top = -90
	_label.offset_bottom = -30
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 34)
	_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_label.add_theme_constant_override("outline_size", 8)
	layer.add_child(_label)
	add_child(layer)
	cam = Camera3D.new()
	cam.fov = 50.0
	cam.far = 1500.0
	world.add_child(cam)
	player.camera.current = false
	cam.current = true
	var st := OS.get_environment("SHOWCASE_START")
	if st != "":
		t = float(st)
	tp(Vector3(24.0, 3.3, 70.0), 0.0, 0.3)


func say(text: String) -> void:
	_label.text = text


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


func follow(off: Vector3, local := true, look_up := 1.0) -> void:
	_follow = true
	_follow_off = off
	_follow_local = local
	_look_up = look_up
	cam.current = true
	player.camera.current = false


func game_cam() -> void:
	_follow = false
	cam.current = false
	player.camera.current = true


func _physics_process(delta: float) -> void:
	t += delta
	if _follow:
		var off := _follow_off
		if _follow_local:
			off = Basis(Vector3.UP, player.model.rotation.y) * _follow_off
		var want := player.global_position + off
		cam.global_position = cam.global_position.lerp(want, minf(1.0, delta * 6.0))
		cam.look_at(player.global_position + Vector3(0, _look_up, 0))
	# --- Au sol
	at(0.1, "s0", func(): follow(Vector3(3.2, 1.3, 2.6), true, 1.0); cam.global_position = player.global_position + Vector3(3.2, 1.3, 2.6); fade(0.0, 1.2); say("Repos"))
	at(2.5, "walk", func(): Input.action_press("move_forward"); say("Course"))
	at(5.0, "dash", func(): player._dash_press(); say("Dash"))
	at(6.6, "jump", func(): player._fly_press(); say("Saut"))
	at(7.4, "stop1", func(): Input.action_release("move_forward"))
	at(8.6, "recept", func(): say("Réception"))
	at(10.8, "melee1", func(): follow(Vector3(-3.0, 1.4, 3.2), true, 1.0); player.combat._melee_press(); say("Mêlée"))
	at(12.0, "melee2", func(): player.combat._melee_press())
	at(13.6, "aim", func(): follow(Vector3(2.2, 1.5, 3.4), true, 1.1); Input.action_press("aim"); Input.action_press("fire"); say("Visée et tir"))
	at(16.4, "stopfire", func(): Input.action_release("fire"); Input.action_release("aim"))
	at(17.0, "power1", func(): player.combat.power_cd = [0.0, 0.0]; player.combat.use_power(0); say("Pouvoir : Lance de noyau"))
	at(19.0, "power2", func(): player.combat.use_power(1); say("Pouvoir : Résonance"))
	# --- En l'air
	at(21.0, "takeoff", func(): follow(Vector3(5.5, 1.0, 4.5), true, 0.8); Input.action_press("move_forward"); player._fly_press(); say("Décollage"))
	at(21.4, "ignite", func(): player._fly_press(); player.cam_pitch = 0.05)
	at(23.0, "flycam", func(): follow(Vector3(6.0, 0.5, -1.0), true, 0.6); say("Vol"))
	at(25.5, "flydash", func(): player._dash_press(); say("Dash en vol"))
	at(26.5, "hover", func(): player._fly_press(); Input.action_release("move_forward"); follow(Vector3(4.5, 1.2, 4.0), true, 0.8); say("Vol stationnaire"))
	at(29.5, "drop", func(): player._land_press(); say("Chute"))
	at(32.5, "landed", func(): follow(Vector3(3.5, 2.2, 3.5), false, 0.9); say("Atterrissage"))
	# --- Caméra du jeu : traversée de la vallée jusqu'à l'Arche
	at(35.0, "gamecam", func():
		fade(1.0, 0.4)
		get_tree().create_timer(0.45).timeout.connect(func():
			game_cam()
			tp(Vector3(24.0, 3.3, 10.0), 0.0, 0.3)
			say("")
			fade(0.0, 0.6)))
	at(36.2, "walk2", func(): Input.action_press("move_forward"))
	at(37.0, "jump2", func(): player._fly_press())
	at(37.35, "fly2", func(): player._fly_press(); player.cam_pitch = 0.0)
	at(39.5, "boost2", func(): player._dash_press(); player.cam_pitch = 0.22)
	at(45.0, "hover2", func(): player._fly_press(); Input.action_release("move_forward"))
	at(47.0, "drop2", func(): player._land_press())
	at(49.5, "walk3", func(): Input.action_press("move_forward"))
	at(52.5, "stop3", func(): Input.action_release("move_forward"))
	at(54.5, "end", func(): fade(1.0, 1.0))
	at(55.6, "quit", func(): get_tree().quit())
