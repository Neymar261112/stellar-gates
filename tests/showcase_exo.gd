extends Node
## Vidéo du gameplay de l'exo : marche, course, saut, cachette, décollage, vol rapide, vrilles,
## stationnaire, réception de super-héros et poses de combat. Caméra du jeu, commandes simulées.
## Lancer : xvfb-run godot --path . --rendering-driver opengl3 --write-movie out/f.png --fixed-fps 24 tests/showcase_exo.tscn

var t := 0.0
var _done := {}
var _fade: ColorRect
var _title: Label
var _yaw_spin := 0.0            # rotation continue de la caméra (rad/s) pendant le vol en cercle
var _hold_yaw := INF            # cap imposé à la caméra (INF = libre)
var _hold_pitch := INF
@onready var main: Node = $Main
@onready var player: CharacterBody3D = $Main/Player


func _ready() -> void:
	Appearance.persist = false
	Appearance.reset()
	var layer := CanvasLayer.new()
	layer.layer = 50
	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 1)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_fade)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 34)
	_title.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_title.add_theme_constant_override("outline_size", 8)
	_title.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_title.position = Vector2(-300, 90)
	_title.size = Vector2(600, 50)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layer.add_child(_title)
	add_child(layer)
	var st := OS.get_environment("SHOWCASE_START")
	if st != "":
		t = float(st)


func at(time: float, key: String, f: Callable) -> void:
	if t >= time and not _done.has(key):
		_done[key] = true
		f.call()


func fade(to_alpha: float, dur: float) -> void:
	create_tween().tween_property(_fade, "color:a", to_alpha, dur)


func title(text: String) -> void:
	_title.text = text
	_title.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(2.2)
	tw.tween_property(_title, "modulate:a", 0.0, 0.6)


func tp(pos: Vector3, yaw: float, pitch := 0.3) -> void:
	for a in ["move_forward", "move_back", "move_left", "move_right", "aim", "fire", "dash"]:
		Input.action_release(a)
	player.in_cover = false
	player.sprinting = false
	player.global_position = pos
	player.velocity = Vector3.ZERO
	player.state = player.State.GROUND
	player.cam_yaw = yaw
	player.cam_pitch = pitch
	player.model.rotation.y = yaw
	player.pivot.rotation.y = yaw
	player.heat = 0.0
	_hold_yaw = yaw
	_hold_pitch = pitch


func cut(time: float, key: String, f: Callable) -> void:
	at(time, key, func():
		fade(1.0, 0.35)
		get_tree().create_timer(0.4).timeout.connect(func():
			f.call()
			fade(0.0, 0.5)))


func yaw_to(from: Vector3, to: Vector3) -> float:
	var d := to - from
	return atan2(-d.x, -d.z)


func _physics_process(delta: float) -> void:
	t += delta
	if _hold_yaw != INF:
		_hold_yaw += _yaw_spin * delta
		player.cam_yaw = lerp_angle(player.cam_yaw, _hold_yaw, minf(1.0, delta * 5.0))
	if _hold_pitch != INF:
		player.cam_pitch = lerpf(player.cam_pitch, _hold_pitch, minf(1.0, delta * 4.0))
	var c = player.combat
	c.health = c.max_health                  # pas de mort pendant la démo
	# --- 0. Préparation : Solaris complet (vol, dash, Éveil)
	at(0.05, "setup", func():
		for sl in Loadout.SLOTS:
			Loadout.set_tier(sl, 2)
		tp(Vector3(53.5, 0.2, 86.0), 0.0, 0.32))
	# --- 1. Marche, course, saut
	at(0.6, "f0", func(): fade(0.0, 0.8); title("Marche"))
	at(1.0, "walk_slow", func(): Input.action_press("move_forward", 0.5))
	at(3.2, "walk", func(): Input.action_press("move_forward", 1.0))
	at(5.0, "sprint", func(): player._sprint_press(); title("Course  (clic du stick gauche)"))
	at(7.4, "jump", func(): player._fly_press())
	at(8.8, "stop", func(): Input.action_release("move_forward"))
	at(9.6, "quit_walk", func():
		if OS.get_environment("WALK_ONLY") != "":
			Input.action_release("move_forward")
			get_tree().quit())
	# --- 2. Cachette derrière un muret
	cut(10.0, "cover_go", func():
		tp(Vector3(21.5, 0.2, 73.2), 0.0, 0.22)
		title("Se cacher  (B maintenu)")
		Input.action_press("move_forward", 0.6))
	at(11.4, "cover_in", func():
		Input.action_release("move_forward")
		Input.action_press("dash")
		player._dash_press())
	at(11.8, "cover_rel", func(): Input.action_release("dash"))
	at(12.6, "slide_r", func(): Input.action_press("move_right"))
	at(13.6, "slide_r2", func(): Input.action_release("move_right"); Input.action_press("move_left"))
	at(15.0, "slide_l2", func(): Input.action_release("move_left"))
	at(15.4, "peek", func():
		_hold_yaw = yaw_to(player.global_position, Vector3(16.25, 1.0, 63.75))
		_hold_pitch = 0.18
		title("Sortir pour tirer  (LT)")
		Input.action_press("aim"))
	at(16.2, "peek_fire", func(): Input.action_press("fire"))
	at(17.8, "hide", func(): Input.action_release("fire"); Input.action_release("aim"); _hold_yaw = 0.0; _hold_pitch = 0.22)
	at(19.0, "vault", func(): title("Sauter par-dessus  (A)"); player._fly_press())
	at(19.3, "vault_fwd", func(): Input.action_press("move_forward"))
	at(20.6, "vault_end", func(): Input.action_release("move_forward"))
	# --- 3. Décollage, vol rapide en cercle, boost, vrilles
	cut(21.5, "fly_go", func():
		tp(Vector3(22.0, 0.2, 47.0), 0.0, 0.3)
		title("Décollage  (A puis A)"))
	at(22.6, "fly_jump", func(): player._fly_press())
	at(22.95, "fly_ignite", func(): player._fly_press())
	at(23.4, "fly_up", func(): _hold_pitch = 0.1)
	at(24.6, "fly_level", func(): _hold_pitch = 0.42; _yaw_spin = -0.7; title("Vol"))
	at(26.6, "boost", func(): player._dash_press(); title("Boost  (B)"))
	at(29.0, "roll_r", func():
		title("Vrilles  (B + stick gauche / droite)")
		Input.action_press("move_right"); player._dash_press())
	at(29.25, "roll_r_end", func(): Input.action_release("move_right"))
	at(30.4, "roll_l", func(): Input.action_press("move_left"); player._dash_press())
	at(30.65, "roll_l_end", func(): Input.action_release("move_left"))
	at(31.6, "dive", func(): _hold_pitch = 0.75; title("Piqué : refroidit"))
	at(32.6, "level2", func(): _hold_pitch = 0.42)
	at(33.4, "boost2", func(): player._dash_press())
	# --- 4. Vol stationnaire, tir en l'air, vrille de côté
	at(35.0, "hover", func():
		_yaw_spin = 0.0
		player._fly_press()
		_hold_pitch = 0.55
		title("Vol stationnaire  (A en vol)"))
	at(36.6, "hover_aim", func(): Input.action_press("aim"))
	at(37.0, "hover_fire", func(): Input.action_press("fire"))
	at(38.6, "hover_stop", func(): Input.action_release("fire"); Input.action_release("aim"))
	at(39.0, "hover_roll", func(): Input.action_press("move_left"); player._dash_press())
	at(39.25, "hover_roll_end", func(): Input.action_release("move_left"))
	# --- 5. Propulseurs coupés : réception de super-héros
	at(40.4, "cut_thrust", func():
		if player.global_position.y < 14.0:
			player.global_position.y = 16.0
		player._land_press()
		_hold_pitch = 0.5
		title("Réception  (Y)"))
	# --- 6. Poses de combat : tir à la hanche, posture de tir, pas chassés
	cut(44.5, "combat_go", func():
		tp(Vector3(16.25, 0.2, 73.5), 0.0, 0.25)
		title("Tir à la hanche  (RT)"))
	at(45.3, "hip", func(): Input.action_press("fire"))
	at(46.8, "hip_end", func(): Input.action_release("fire"))
	at(47.2, "aim", func(): Input.action_press("aim"); title("Posture de tir  (LT + RT)"))
	at(47.7, "aim_fire", func(): Input.action_press("fire"))
	at(49.4, "strafe", func(): Input.action_press("move_right", 0.6))
	at(50.6, "strafe2", func(): Input.action_release("move_right"); Input.action_press("move_left", 0.6))
	at(51.8, "strafe_end", func(): Input.action_release("move_left"); Input.action_release("fire"))
	at(52.4, "aim_end", func(): Input.action_release("aim"))
	at(52.8, "end", func(): fade(1.0, 1.2))
	at(54.2, "quit", func():
		for a in ["move_forward", "move_left", "move_right", "aim", "fire", "dash"]:
			Input.action_release(a)
		get_tree().quit())
