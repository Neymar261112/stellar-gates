extends Node
## Vidéo des attaques du Ranger : fusil d'assaut, changement d'arme (Twin Vipers), esquive propulsée,
## pas de tir en vol mais en stationnaire, grenades et lanceurs (combos), batterie de missiles.
## Lancer : xvfb-run godot --path . --rendering-driver opengl3 --write-movie out/f.png --fixed-fps 24 tests/showcase_attaques.tscn

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


func tap_fire(time: float, key: String) -> void:
	at(time, key, func(): Input.action_press("fire"))
	at(time + 0.08, key + "_r", func(): Input.action_release("fire"))


func power(time: float, key: String, slot: int, idx: int, label: String) -> void:
	at(time, key, func():
		player.combat.equip(slot, idx)
		player.combat.power_cd = [0.0, 0.0]
		title(label)
		player.combat.use_power(slot))


func _physics_process(delta: float) -> void:
	t += delta
	if _hold_yaw != INF:
		_hold_yaw += _yaw_spin * delta
		player.cam_yaw = lerp_angle(player.cam_yaw, _hold_yaw, minf(1.0, delta * 5.0))
	if _hold_pitch != INF:
		player.cam_pitch = lerpf(player.cam_pitch, _hold_pitch, minf(1.0, delta * 4.0))
	var c = player.combat
	c.health = c.max_health                  # pas de mort pendant la démo
	c.shield = c.max_shield
	var start := Vector3(16.25, 0.2, 77.5)
	var t0 := Vector3(16.25, 1.3, 63.75)
	var t1 := Vector3(23.75, 1.3, 68.75)
	var t2 := Vector3(8.75, 1.3, 68.75)
	# --- 0. Solaris complet : vol, grenade + lanceur, ultime
	at(0.05, "setup", func():
		for sl in Loadout.SLOTS:
			Loadout.set_tier(sl, 2)
		c.equip(0, 0)
		c.equip(1, 3)
		tp(start, yaw_to(start, t0), 0.3))
	# --- 1. Fusil d'assaut
	at(0.6, "f0", func(): fade(0.0, 0.8); title("Fusil d'assaut  (RT)"))
	at(1.2, "aim1", func(): Input.action_press("aim"))
	at(1.6, "fire1", func(): Input.action_press("fire"))
	at(3.6, "fire1_end", func(): Input.action_release("fire"); Input.action_release("aim"))
	# --- 2. Changement d'arme : Twin Vipers
	at(4.2, "switch1", func(): title("Changer d'arme  (Y au sol)"); c.switch_weapon())
	at(5.2, "aim2", func(): title("Twin Vipers : fusil de précision"); Input.action_press("aim"))
	tap_fire(5.9, "v1")
	tap_fire(6.5, "v2")
	tap_fire(7.1, "v3")
	at(7.6, "aim2_end", func(): Input.action_release("aim"))
	# --- 3. Esquive propulsée
	at(8.2, "dodge_r", func(): title("Esquive propulsée  (B + direction)"); Input.action_press("move_right"); player._do_dash())
	at(8.4, "dodge_r_end", func(): Input.action_release("move_right"))
	at(9.8, "dodge_l", func(): player.dash_cd = 0.0; Input.action_press("move_left"); player._do_dash())
	at(10.0, "dodge_l_end", func(): Input.action_release("move_left"))
	at(11.3, "dodge_b", func(): player.dash_cd = 0.0; player._do_dash())
	at(12.3, "switch2", func(): c.switch_weapon())
	# --- 4. Pas de tir en vol : on vise, on passe en stationnaire, on tire
	cut(13.0, "fly_go", func():
		tp(start + Vector3(0, 0, 14), yaw_to(start, t0), 0.3)
		title("En vol : pas de tir"))
	at(13.8, "fly_jump", func(): player._fly_press())
	at(14.15, "fly_ignite", func(): player._fly_press())
	at(14.6, "fly_level", func(): _hold_pitch = 0.36)
	at(15.2, "fly_fire", func(): Input.action_press("fire"))
	at(16.8, "hover", func(): title("LT : vol stationnaire, et là on tire"); Input.action_press("aim"); _hold_pitch = 0.5)
	at(18.6, "hover_end", func(): Input.action_release("fire"))
	at(19.2, "hover_rel", func(): Input.action_release("aim"); player._land_press())
	# --- 5. Kit du Ranger : grenades et lanceurs, amorce + détonateur = COMBO
	cut(20.5, "kit_go", func():
		tp(start, yaw_to(start, t1), 0.22)
		Input.action_press("aim"))
	power(21.4, "lance", 1, 4, "Rayon d'étincelles  (RB) : amorce")
	power(22.6, "frag", 0, 0, "Grenade à fragmentation  (LB) : détonateur")
	at(24.4, "aim_t0", func(): _hold_yaw = yaw_to(start, t0))
	power(25.0, "givre", 0, 1, "Grenade de givre  (LB) : gèle")
	power(26.6, "missile", 1, 3, "Missile au poignet  (RB) : tête chercheuse")
	at(28.4, "aim_t2", func(): _hold_yaw = yaw_to(start, t2))
	power(29.0, "brasier", 0, 2, "Grenade incendiaire  (LB)")
	power(30.8, "pulse", 1, 5, "Salve d'impulsion  (RB)")
	at(32.4, "kit_end", func(): Input.action_release("aim"))
	# --- 6. Batterie de missiles, depuis le vol stationnaire
	cut(33.0, "ult_go", func():
		tp(start + Vector3(0, 0, 4), yaw_to(start, Vector3(17.0, 3.0, 64.0)), 0.3)
		title("Ultime : batterie de missiles  (LB + RB)"))
	at(33.8, "ult_jump", func(): player._fly_press())
	at(34.15, "ult_ignite", func(): player._fly_press())
	at(34.9, "ult_hover", func(): Input.action_press("aim"); _hold_pitch = 0.4)
	at(35.6, "ult", func(): Input.action_release("aim"); c.ult_charge = 100.0; c.use_ultimate())
	at(36.2, "ult_wide", func(): _hold_pitch = 0.35)
	tap_fire(37.0, "s1")
	tap_fire(38.4, "s2")
	tap_fire(39.8, "s3")
	at(42.0, "end", func(): fade(1.0, 0.8))
	at(43.0, "quit", func(): get_tree().quit())
