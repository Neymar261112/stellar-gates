extends CharacterBody3D
## Le Solaris, vol façon Anthem : saut, double saut = décollage, vol libre dirigé par la caméra
## (monter / piquer), vol stationnaire, chaleur qui refroidit en piquant ou dans l'eau,
## atterrissage en glissade, dash au sol et boost en vol.

signal message(text: String, seconds: float)

enum State { GROUND, AIR, FLY, HOVER, LANDING, FALL }

@export var walk_speed := 8.0
@export var jump_speed := 9.0
@export var fly_speed := 16.0          # vitesse de croisière
@export var fly_boost := 1.45          # stick avant / dash en vol
@export var fly_seconds := 8.0         # vol en palier avant surchauffe
@export var hover_seconds := 20.0      # vol stationnaire avant surchauffe
@export var overheat_seconds := 3.0
@export var dash_time := 0.25
@export var dash_cooldown := 1.4
@export var ceiling := 45.0

const GRAVITY := 22.0
const PITCH_NEUTRAL := 0.42            # angle caméra par défaut = vol en palier ; stick vers le haut = montée, vers le bas = piqué

var state := State.GROUND
var heat := 0.0
var overheat := 0.0
var cooling := false                   # piqué, eau ou cascade en cours
var cooling_zones := 0                 # cascades traversées (compteur d'Area3D)
var dash_t := 0.0
var dash_cd := 0.0
var dash_dir := Vector3.ZERO
var boost_t := 0.0
var landing_t := 0.0
var takeoff_t := 0.0
var safe_pos := Vector3.ZERO
var destination = null                 # Vector3 quand une destination est fixée en pause tactique
var cam_yaw := 0.0
var cam_pitch := 0.42
var _lean := 0.0
var _roll := 0.0
var melee_lunge := Vector3.ZERO
var dead := false
var combat: Combat
var _trails: Array = []
var _dust_t := 0.0
var _was_cooling_msg := false
var _bob := 0.0
var look: SolarisLook                  # apparence (pièces, peinture, usure, vinyle) : ne touche aucune stat
var anim: SolarisAnim                  # animation procédurale du squelette
var _boost_used := false               # tuyère de récup : un seul bond propulsé par saut
var can_fly := false
var can_dash := false
# Déplacements (gameplay de l'exo) : course, cachette, vrilles, réceptions lourdes
@export var sprint_mult := 1.3          # course : ×1,3 la vitesse des servos
const JOG := 0.72                        # au pas normal, l'exo trottine à 72 % de la vitesse des servos
var sprinting := false
var in_cover := false
var cover_normal := Vector3.ZERO       # normale de l'obstacle (vers le Solaris)
var cover_low := true                  # muret : accroupi ; mur haut : debout, on sort sur le côté pour tirer
var cover_peek := 0.0                  # 0 caché, 1 sorti pour tirer (lissé)
var _cover_leave_t := 0.0
var _b_hold_t := -1.0                  # B maintenu près d'un obstacle : court = dash, long = cachette
var roll_t := 0.0                      # vrille en vol (B + stick à gauche ou à droite)
var roll_dir := 0.0
var _roll_cd := 0.0
var _vault_t := 0.0
var _vault_dir := Vector3.ZERO
var _last_vy := 0.0                    # vitesse verticale avant le dernier déplacement (force des réceptions)
var _prev_cam_yaw := 0.0
var _yaw_rate := 0.0
var _yaw := 0.0
var _takeoff_cam := 0.0
var _downwash_t := 0.0
var _speed_lines: GPUParticles3D
var _blur_mat: ShaderMaterial          # flou radial de vitesse (bords de l'image)
var _blur: MeshInstance3D
var _blur_amt := 0.0
var _hand_trails: Array = []
var _prev_pos := Vector3.ZERO
var _cur_pos := Vector3.ZERO
var _model_base := Vector3.ZERO
var _yaw_target := 0.0
var _lean_target := 0.0
var _roll_target := 0.0
var _prev_hv := Vector2.ZERO
var _acc_lean := 0.0
var _turn_roll := 0.0
const PIVOT_BASE := Vector3(0, 1.3, 0)
## Cadrage (choisi par cyril le 2026-10-28 : variante B, caméra rapprochée façon Anthem).
## 1.0 / 0 redonnerait l'ancien cadrage (caméra à 4,6 m).
var cam_dist_mult := 0.7               # distance caméra au sol (le vol garde la sienne) : 3,2 m en marche
var cam_fov_add := -4.0
var cam_x_add := 0.0                   # décalage latéral : Solaris plus ou moins à gauche de l'image
var cam_y_add := -0.1
var size_scale := 1.0                  # taille affichée du Solaris
const ROLL_TIME := 0.5
const B_HOLD := 0.22
const COVER_SPEED := 3.2
const DODGE_TIME := 0.34
const DODGE_SPEED := 21.0

var world: Node3D
@onready var pivot: Node3D = $CameraPivot
@onready var arm: SpringArm3D = $CameraPivot/SpringArm3D
@onready var camera: Camera3D = $CameraPivot/SpringArm3D/Camera3D
@onready var model: Node3D = $Model
@onready var flames: Node3D = $Model/Flames
@onready var flame_light: OmniLight3D = $Model/Flames/Light


func _ready() -> void:
	add_to_group("player")
	arm.add_excluded_object(get_rid())
	_load_solaris()
	flames.visible = false
	combat = Combat.new()
	combat.name = "Combat"
	add_child(combat)
	_build_thruster_trails()
	_build_speed_fx()
	if look:
		look.energy_color_changed.connect(_on_energy_color)
		look.flames_moved.connect(_on_flames_moved)
		look.refresh_all()
		for n in combat.paint_nodes():     # armes et lanceurs reprennent le schéma de couleurs du preset
			look.paint(n)
	apply_loadout()
	Loadout.changed.connect(func(_slot): apply_loadout())


## Appelé par game.gd à chaque changement de carte.
func set_world(w: Node3D, pos: Vector3, facing: Vector3 = Vector3(0, 0, -1)) -> void:
	world = w
	global_position = pos
	safe_pos = pos
	velocity = Vector3.ZERO
	_prev_pos = pos
	_cur_pos = pos
	state = State.GROUND
	destination = null
	heat = minf(heat, 0.3)
	overheat = 0.0
	cooling_zones = 0
	in_cover = false
	sprinting = false
	roll_t = 0.0
	cam_yaw = atan2(-facing.x, -facing.z)
	_prev_cam_yaw = cam_yaw
	cam_pitch = 0.42
	model.rotation = Vector3(0, cam_yaw, 0)
	pivot.rotation.y = cam_yaw
	play_arrival.call_deferred()


func enter_cooling_zone() -> void:
	cooling_zones += 1


func exit_cooling_zone() -> void:
	cooling_zones = maxi(0, cooling_zones - 1)


# ---------------------------------------------------------------- modèle
func _load_solaris() -> void:
	var scene: PackedScene = load("res://assets/solaris/aegis_rig.glb")
	if scene == null:
		scene = load("res://assets/solaris/solaris.glb")
	if scene == null:
		push_warning("Modèle solaris.glb introuvable : une capsule le remplace.")
		var mi := MeshInstance3D.new()
		var cm := CapsuleMesh.new()
		cm.radius = 0.4
		cm.height = 1.9
		mi.mesh = cm
		mi.position.y = 0.95
		model.add_child(mi)
		return
	var root := scene.instantiate()
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = load("res://assets/solaris/solaris.jpg")
	mat.normal_enabled = true
	mat.normal_texture = load("res://assets/solaris/normal.jpg")
	var mr: Texture2D = load("res://assets/solaris/metal-rough.jpg")
	mat.metallic = 1.0
	mat.metallic_texture = mr
	mat.metallic_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_BLUE
	mat.roughness = 1.0
	mat.roughness_texture = mr
	mat.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GREEN
	_apply_material(root, mat)
	# Le modèle fait face à -Z (l'avant Godot) mais il est centré sur son milieu : on pose les pieds au sol.
	var aabb := _merged_aabb(root)
	root.position.y = -aabb.position.y
	root.rotation.y = PI  # le GLB regarde vers +Z : on le retourne pour qu'il regarde devant (-Z)
	model.add_child(root)
	var sks := root.find_children("*", "Skeleton3D")
	if sks.size() > 0:
		anim = SolarisAnim.new()
		anim.name = "Anim"
		add_child(anim)
		anim.setup(sks[0], self)
		look = SolarisLook.new()
		look.name = "Look"
		add_child(look)
		look.setup(model, sks[0], root.find_children("*", "MeshInstance3D"))


## Traînées de particules derrière les propulseurs (visibles en vol, dash, mêlée).
func _build_thruster_trails() -> void:
	for x in [-0.22, 0.22]:
		var p := GPUParticles3D.new()
		p.amount = 90
		p.lifetime = 0.45
		p.emitting = false
		var m := ParticleProcessMaterial.new()
		m.direction = Vector3(0, -1, 0.35)
		m.spread = 8.0
		m.initial_velocity_min = 9.0
		m.initial_velocity_max = 14.0
		m.gravity = Vector3.ZERO
		m.scale_min = 0.6
		m.scale_max = 1.3
		m.color = Color(1.0, 0.75, 0.35)
		m.color_ramp = Fx._fade_ramp(Color(1.0, 0.6, 0.2))
		p.process_material = m
		var q := QuadMesh.new()
		q.size = Vector2(0.28, 0.28)
		q.material = Fx._spark_mat(Color(1.0, 0.75, 0.35))
		p.draw_pass_1 = q
		p.position = Vector3(x, -0.25, 0)
		flames.add_child(p)
		_trails.append(p)


## Impression de vitesse : lignes de vent devant la caméra et traînées blanches aux mains en vol rapide.
func _build_speed_fx() -> void:
	_speed_lines = GPUParticles3D.new()
	_speed_lines.amount = 70
	_speed_lines.lifetime = 0.35
	_speed_lines.local_coords = true
	_speed_lines.emitting = false
	_speed_lines.visibility_aabb = AABB(Vector3(-30, -30, -60), Vector3(60, 60, 80))
	var m := ParticleProcessMaterial.new()
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	m.emission_ring_axis = Vector3(0, 0, 1)
	m.emission_ring_radius = 9.0
	m.emission_ring_inner_radius = 3.2
	m.emission_ring_height = 14.0
	m.direction = Vector3(0, 0, 1)
	m.spread = 0.0
	m.initial_velocity_min = 55.0
	m.initial_velocity_max = 80.0
	m.gravity = Vector3.ZERO
	m.color_ramp = Fx._fade_ramp(Color(1, 1, 1, 0.5))
	_speed_lines.process_material = m
	var line := BoxMesh.new()
	line.size = Vector3(0.025, 0.025, 2.8)
	var lm := StandardMaterial3D.new()
	lm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	lm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	lm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	lm.vertex_color_use_as_albedo = true
	lm.albedo_color = Color(0.9, 0.95, 1.0, 0.35)
	line.material = lm
	_speed_lines.draw_pass_1 = line
	_speed_lines.position = Vector3(0, 0, -24)
	camera.add_child(_speed_lines)
	_blur_mat = ShaderMaterial.new()
	_blur_mat.shader = load("res://shaders/speed_blur.gdshader")
	_blur_mat.render_priority = -100        # avant les particules : flammes et fumées restent nettes par-dessus
	var bq := QuadMesh.new()
	bq.material = _blur_mat
	_blur = MeshInstance3D.new()
	_blur.mesh = bq
	_blur.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_blur.extra_cull_margin = 16384.0
	_blur.position = Vector3(0, 0, -0.5)
	_blur.visible = false
	camera.add_child(_blur)
	for i in 2:
		var p := GPUParticles3D.new()
		p.amount = 50
		p.lifetime = 0.4
		p.emitting = false
		p.local_coords = false
		var pm := ParticleProcessMaterial.new()
		pm.gravity = Vector3.ZERO
		pm.initial_velocity_min = 0.0
		pm.initial_velocity_max = 0.2
		pm.scale_min = 0.8
		pm.scale_max = 1.0
		pm.color_ramp = Fx._fade_ramp(Color(0.95, 0.97, 1.0, 0.7))
		p.process_material = pm
		var q := QuadMesh.new()
		q.size = Vector2(0.09, 0.09)
		q.material = Fx._spark_mat(Color(0.95, 0.97, 1.0))
		p.draw_pass_1 = q
		add_child(p)
		_hand_trails.append(p)


## Le flou lit l'image déjà rendue. En mode Compatibilité (OpenGL), cette copie est vide quand le
## halo lumineux (glow) est actif : on s'en passe alors plutôt que d'assombrir l'écran.
func _blur_ok() -> bool:
	if RenderingServer.get_rendering_device() != null:     # Forward+ / Mobile (Vulkan) : toujours bon
		return true
	var we := get_viewport().find_world_3d()
	var e: Environment = we.environment if we else null
	return e == null or not e.glow_enabled


func _merged_aabb(n: Node) -> AABB:
	var result := AABB()
	var first := true
	for mi in n.find_children("*", "MeshInstance3D"):
		var a: AABB = mi.transform * mi.get_aabb()
		result = a if first else result.merge(a)
		first = false
	return result


func _apply_material(n: Node, mat: Material) -> void:
	if n is MeshInstance3D:
		n.material_override = mat
		n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	for c in n.get_children():
		_apply_material(c, mat)


# ---------------------------------------------------------------- entrées
func _emote_pressed(event: InputEvent) -> int:
	for i in 3:
		if event.is_action_pressed("emote%d" % (i + 1)):
			return i
	return -1


## Animation d'arrivée du preset (début de carte, sortie de l'Atelier) et pose de victoire.
func play_arrival() -> void:
	for i in 90:                       # on attend d'avoir touché le sol
		if is_on_floor() or not is_inside_tree():
			break
		await get_tree().physics_frame
	if anim and is_inside_tree():
		anim.play(Appearance.current["animation_arrival"])


func play_victory() -> void:
	if anim and is_on_floor():
		anim.play(Appearance.current["animation_victory"])


func _unhandled_input(event: InputEvent) -> void:
	if dead:
		return
	if event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED   # premier clic : la souris pilote la caméra (Échap la libère)
		get_viewport().set_input_as_handled()
	elif anim and not get_tree().paused and is_on_floor() and _emote_pressed(event) >= 0:
		anim.play(Appearance.current["emotes"][_emote_pressed(event)])
	elif event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not get_tree().paused:
		_turn_camera(-event.relative.x * 0.0035, event.relative.y * 0.0025)
	elif event.is_action_pressed("fly"):
		_fly_press()
	elif event.is_action_pressed("land"):
		if _airborne():
			_land_press()                 # Y en vol : couper les propulseurs
		elif not get_tree().paused:
			combat.switch_weapon()        # Y au sol : changer d'arme
	elif event.is_action_pressed("dash"):
		_dash_press()
	elif event.is_action_pressed("sprint"):
		_sprint_press()
	elif event.is_action_pressed("cover"):
		if in_cover:
			_leave_cover()
		else:
			_try_cover(true)


func _turn_camera(dyaw: float, dpitch: float) -> void:
	cam_yaw += dyaw
	var lo := -0.55 if _airborne() else 0.1
	cam_pitch = clampf(cam_pitch + dpitch, lo, 1.2)


func _airborne() -> bool:
	return state == State.FLY or state == State.HOVER


func _fly_press() -> void:
	if dead:
		return
	match state:
		State.GROUND, State.LANDING:
			if in_cover and cover_low:
				_vault()
			elif is_on_floor():
				_leave_cover(false)
				velocity.y = jump_speed
				state = State.AIR
				destination = null
				Fx.ring(global_position + Vector3(0, 0.1, 0), 1.6, Color(0.8, 0.75, 0.6, 0.5), 0.3, Vector3.UP, 0.15)
				Fx.sparks(global_position + Vector3(0, 0.1, 0), Vector3.UP, Color(0.75, 0.7, 0.55), 10, 3.0, 0.5, 0.3, 100.0, -2.0)
				Fx.kick(1.5)
		State.AIR:
			if can_fly:
				_ignite()
			else:
				_scrap_boost()
		State.FLY:
			state = State.HOVER
			message.emit("Vol stationnaire", 1.0)
		State.HOVER:
			state = State.FLY
			message.emit("Vol", 1.0)
		State.FALL:
			if can_fly:
				_ignite()
			else:
				_scrap_boost()


## Tuyère de récup : pas de vol, juste un bond propulsé (une fois par saut) qui amortit la chute.
func _scrap_boost() -> void:
	if _boost_used:
		return
	_boost_used = true
	if overheat > 0.0:
		return
	velocity.y = maxf(velocity.y, 0.0) + 7.0
	heat = minf(1.0, heat + 0.25)
	Fx.sparks(global_position + Vector3(0, 0.4, 0), Vector3.DOWN, Color(1.0, 0.55, 0.2), 18, 6.0, 0.4, 0.2, 100.0, 0.0)
	Fx.kick(2.0)
	message.emit("Tuyère de récup : pas de vol. Il faut de vrais propulseurs.", 1.6)


func _ignite() -> void:
	if overheat > 0.0:
		message.emit("Surchauffe : propulseurs coupés", 1.5)
		return
	_leave_cover(false)
	sprinting = false
	state = State.FLY
	destination = null
	takeoff_t = 0.7
	_takeoff_cam = 1.0                       # la caméra recule pendant la poussée
	var c: Color = flame_light.light_color
	var low := _height_above_ground() < 4.0
	Fx.ring(global_position + Vector3(0, 0.3, 0), 2.6, Color(c.r, c.g, c.b, 0.9), 0.35, Vector3.UP, 0.3)
	Fx.ring(global_position + Vector3(0, 0.15, 0), 5.0, Color(0.85, 0.8, 0.65, 0.6), 0.6, Vector3.UP, 0.4)
	Fx.sparks(global_position + Vector3(0, 0.4, 0), Vector3.DOWN, c, 40, 11.0, 0.55, 0.22, 140.0, 0.0)
	Fx.flash(global_position + Vector3(0, 0.6, 0), c, 7.0, 10.0, 0.35)
	if low:                                  # souffle au sol : poussière et cailloux
		Fx.sparks(global_position + Vector3(0, 0.1, 0), Vector3.UP, Color(0.75, 0.7, 0.55), 36, 7.0, 0.9, 0.45, 160.0, -3.0)
		Fx.debris(global_position + Vector3(0, 0.2, 0), Color(0.5, 0.45, 0.4), 8, 7.0)
	Fx.kick(7.0)
	Fx.shake(0.35)
	velocity.y = maxf(velocity.y, 9.0)
	cam_pitch = minf(cam_pitch, PITCH_NEUTRAL)
	message.emit("Propulseurs allumés", 1.0)


## Viser ou lancer un pouvoir en plein vol : le Solaris se cale en vol stationnaire (seul état où l'on tire).
func enter_hover() -> void:
	if state == State.FLY:
		state = State.HOVER
		boost_t = 0.0
		velocity *= 0.45
		Fx.ring(global_position + Vector3(0, 0.6, 0), 2.2, Color(1, 1, 1, 0.35), 0.3, Vector3.UP, 0.15)
		Fx.kick(2.0)
		message.emit("Vol stationnaire", 0.8)


func _land_press() -> void:
	if _airborne():
		state = State.AIR
		message.emit("Propulseurs coupés", 1.0)


## B : en vol, vrille si le stick est poussé sur le côté, sinon boost. Au sol : dash, ou cachette
## si on le garde enfoncé près d'un obstacle (on attend B_HOLD pour savoir lequel des deux).
func _dash_press() -> void:
	if dead:
		return
	if in_cover:
		_leave_cover()
		return
	if _airborne():
		var sx := _stick().x
		if absf(sx) > 0.45:
			_barrel_roll(signf(sx))
			return
		if dash_cd > 0.0 or not can_dash:
			return
		_start_boost()
		return
	if state == State.GROUND and is_on_floor() and not _find_cover().is_empty():
		_b_hold_t = 0.0
		return
	_do_dash()


## Esquive au sol : vrai bond propulsé dans la direction du stick (ou en arrière sans stick), propulseurs
## allumés, on est intouchable pendant la poussée.
func _do_dash() -> void:
	if dash_cd > 0.0 or dash_t > 0.0 or dead:
		return
	if not can_dash:
		message.emit("Jambières de Bastion : trop lourdes pour une esquive.", 1.2)
		dash_cd = 1.0
		return
	if state != State.GROUND:
		return
	_leave_cover(false)
	sprinting = false
	var d := _input_dir()
	if d.length() < 0.1:
		d = model.global_transform.basis.z           # sans direction : bond en arrière
		d.y = 0.0
	dash_dir = d.normalized()
	dash_t = DODGE_TIME
	dash_cd = dash_cooldown
	velocity.y = 3.2                                 # petit décollage : les pieds quittent le sol
	velocity.x = dash_dir.x * DODGE_SPEED
	velocity.z = dash_dir.z * DODGE_SPEED
	var c: Color = flame_light.light_color
	var p := global_position + Vector3(0, 0.9, 0)
	Fx.ring(p - dash_dir * 0.6, 1.4, Color(c.r, c.g, c.b, 0.8), 0.22, -dash_dir, 0.25)
	Fx.sparks(p, -dash_dir, c, 22, 9.0, 0.3, 0.14, 25.0, 0.0)
	Fx.sparks(global_position + Vector3(0, 0.15, 0), -dash_dir + Vector3.UP * 0.3, Color(0.75, 0.7, 0.55), 18, 6.0, 0.5, 0.3, 60.0, -3.0)
	Fx.flash(p, c, 3.0, 5.0, 0.2)
	Fx.kick(4.0)
	Fx.shake(0.12)


## Boost en vol : poussée de 0,8 s avec un anneau de choc derrière le Solaris.
func _start_boost() -> void:
	boost_t = 0.8
	dash_cd = dash_cooldown
	heat = minf(1.0, heat + 0.08)
	var c: Color = flame_light.light_color
	var back := -_fly_forward()
	Fx.ring(global_position + Vector3(0, 1.0, 0) + back * 1.5, 2.2, Color(c.r, c.g, c.b, 0.8), 0.3, back, 0.25)
	Fx.ring(global_position + Vector3(0, 1.0, 0) + back * 3.0, 3.4, Color(1, 1, 1, 0.35), 0.4, back, 0.15)
	Fx.kick(6.0)
	Fx.shake(0.15)


## Vrille : tonneau rapide sur le côté, on esquive tout pendant la rotation.
func _barrel_roll(side: float) -> void:
	if roll_t > 0.0 or _roll_cd > 0.0 or overheat > 0.0:
		return
	roll_t = ROLL_TIME
	roll_dir = side
	_roll_cd = 0.75
	heat = minf(1.0, heat + 0.05)
	var c: Color = flame_light.light_color
	Fx.sparks(global_position + Vector3(0, 1.0, 0), Basis(Vector3.UP, cam_yaw) * Vector3(-side, 0, 0.5), c, 20, 9.0, 0.4, 0.16, 50.0, 0.0)
	Fx.kick(4.0)
	Fx.shake(0.12)


func _sprint_press() -> void:
	if _airborne():
		if dash_cd <= 0.0 and can_dash:
			_start_boost()                  # en vol, le clic du stick gauche garde le boost
		return
	if in_cover:
		_leave_cover(false)
	sprinting = not sprinting


# ---------------------------------------------------------------- cachette
## Cherche un obstacle (mur, rocher, muret) à moins de 1,8 m autour du Solaris.
## Renvoie { point, normal, low } ou {} ; on préfère la direction du stick, puis celle de la caméra.
func _find_cover() -> Dictionary:
	if world == null or not is_inside_tree():
		return {}
	var space := get_world_3d().direct_space_state
	var origin := global_position + Vector3(0, 0.6, 0)
	var dirs: Array = []
	var st := _stick()
	if st.length() > 0.3:
		dirs.append(Basis(Vector3.UP, cam_yaw) * Vector3(st.x, 0, st.y).normalized())
	dirs.append(Basis(Vector3.UP, cam_yaw) * Vector3(0, 0, -1))
	for i in 12:
		var a := TAU * i / 12.0
		dirs.append(Vector3(sin(a), 0, cos(a)))
	var best := {}
	var best_d := 99.0
	for k in dirs.size():
		var d: Vector3 = dirs[k]
		var r := _ray(space, origin, origin + d * 1.8)
		if r.is_empty():
			continue
		var n: Vector3 = r["normal"]
		if absf(n.y) > 0.5:
			continue
		var dist := origin.distance_to(r["position"]) - (0.4 if k < 2 else 0.0)   # bonus à la direction voulue
		if dist < best_d:
			best_d = dist
			n.y = 0.0
			best = { "point": r["position"], "normal": n.normalized() }
	if best.is_empty():
		return {}
	var top := global_position + Vector3(0, 1.55, 0)
	best["low"] = _ray(space, top, top - best["normal"] * 2.2).is_empty()
	return best


func _ray(space: PhysicsDirectSpaceState3D, a: Vector3, b: Vector3) -> Dictionary:
	var q := PhysicsRayQueryParameters3D.create(a, b)
	q.exclude = [get_rid()]
	var r := space.intersect_ray(q)
	if r.is_empty() or r["collider"] == null or r["collider"].has_method("take_damage"):
		return {}                           # ennemis et cibles ne servent pas de cachette
	return r


func _try_cover(announce: bool) -> bool:
	if dead or state != State.GROUND or not is_on_floor() or combat.melee_t > 0.0:
		return false
	var c := _find_cover()
	if c.is_empty():
		if announce:
			message.emit("Pas d'obstacle à portée", 0.8)
		return false
	in_cover = true
	sprinting = false
	destination = null
	cover_normal = c["normal"]
	cover_low = c["low"]
	cover_peek = 0.0
	_cover_leave_t = 0.0
	Fx.sparks(c["point"] + Vector3(0, 0.3, 0), cover_normal, Color(0.75, 0.7, 0.55), 10, 3.0, 0.4, 0.25, 70.0, -4.0)
	Fx.shake(0.1)
	message.emit("À couvert (muret)" if cover_low else "À couvert (mur)", 0.8)
	return true


func _leave_cover(announce := true) -> void:
	if not in_cover:
		return
	in_cover = false
	cover_peek = 0.0
	if announce:
		message.emit("Sortie de la cachette", 0.6)


## Saut par-dessus le muret (A à couvert derrière un muret).
func _vault() -> void:
	var over := -cover_normal
	_leave_cover(false)
	velocity = Vector3(0, 9.0, 0)            # d'abord on monte, puis on passe par-dessus (_ground_step)
	_vault_dir = over
	_vault_t = 0.55
	state = State.AIR
	model.rotation.y = atan2(-over.x, -over.z)
	Fx.sparks(global_position + Vector3(0, 0.9, 0) + over * 0.6, Vector3.UP, Color(0.75, 0.7, 0.55), 12, 4.0, 0.4, 0.25, 80.0, -4.0)
	Fx.kick(2.0)


## Déplacement à couvert : on glisse le long de l'obstacle, on s'arrête au bord, on s'en écarte pour sortir.
func _cover_step(delta: float) -> void:
	var space := get_world_3d().direct_space_state
	var origin := global_position + Vector3(0, 0.6, 0)
	var r := _ray(space, origin, origin - cover_normal * 1.6)
	if r.is_empty():
		_leave_cover(false)
		return
	var n: Vector3 = r["normal"]
	n.y = 0.0
	if n.length() > 0.1:
		cover_normal = cover_normal.slerp(n.normalized(), minf(1.0, delta * 8.0)).normalized()
	var aim_out := combat.aiming or Input.is_action_pressed("fire")
	cover_peek = move_toward(cover_peek, 1.0 if aim_out else 0.0, delta * 6.0)
	var st := _stick()
	var dir := Basis(Vector3.UP, cam_yaw) * Vector3(st.x, 0, st.y)
	var tangent := cover_normal.cross(Vector3.UP).normalized()
	var along := dir.dot(tangent)
	var away := dir.dot(cover_normal)
	if away > 0.75 and absf(along) < 0.45:
		_cover_leave_t += delta
		if _cover_leave_t > 0.3:
			_leave_cover()
			return
	else:
		_cover_leave_t = 0.0
	var move := Vector3.ZERO
	if absf(along) > 0.2 and cover_peek < 0.5:
		var side := tangent * signf(along)
		var probe := origin + side * 0.7
		if not _ray(space, probe, probe - cover_normal * 1.6).is_empty():   # pas de mur plus loin : bord
			move = side * absf(along) * COVER_SPEED
	var want: Vector3 = r["position"] + cover_normal * 0.55
	var pull := Vector3(want.x - global_position.x, 0, want.z - global_position.z) * 8.0
	velocity.x = move.x + pull.x
	velocity.z = move.z + pull.z
	velocity.y = -0.5 if is_on_floor() else velocity.y - GRAVITY * delta
	if not is_on_floor() and velocity.y < -4.0:
		_leave_cover(false)


## Appelé par Combat : ruée de mêlée vers l'avant.
func begin_melee() -> void:
	if anim:
		anim.punch()
	var fwd := Basis(Vector3.UP, cam_yaw) * Vector3(0, 0, -1)
	var st := _stick()
	if st.length() > 0.2:
		fwd = (Basis(Vector3.UP, cam_yaw) * Vector3(st.x, 0.0, st.y)).normalized()
	_leave_cover(false)
	sprinting = false
	melee_lunge = fwd * 17.0
	model.rotation.y = atan2(-fwd.x, -fwd.z)
	if _airborne():
		state = State.AIR
	destination = null


func begin_death() -> void:
	dead = true
	destination = null
	_leave_cover(false)
	sprinting = false
	if _airborne():
		state = State.AIR


func end_death() -> void:
	dead = false
	global_position = safe_pos + Vector3(0, 0.3, 0)
	velocity = Vector3.ZERO
	state = State.GROUND
	heat = 0.0
	overheat = 0.0


func _stick() -> Vector2:
	return Input.get_vector("move_left", "move_right", "move_forward", "move_back")


func _input_dir() -> Vector3:
	var v := _stick()
	if v.length() > 0.05:
		destination = null
		return Basis(Vector3.UP, cam_yaw) * Vector3(v.x, 0.0, v.y)
	if destination != null:
		var to: Vector3 = destination - global_position
		to.y = 0.0
		if to.length() < 0.8:
			destination = null
			message.emit("Destination atteinte", 1.2)
			return Vector3.ZERO
		return to.normalized()
	return Vector3.ZERO


# ---------------------------------------------------------------- simulation
func _physics_process(delta: float) -> void:
	if world == null:
		return
	dash_cd = maxf(0.0, dash_cd - delta)
	boost_t = maxf(0.0, boost_t - delta)
	roll_t = maxf(0.0, roll_t - delta)
	_roll_cd = maxf(0.0, _roll_cd - delta)
	_takeoff_cam = maxf(0.0, _takeoff_cam - delta * 1.4)
	_yaw_rate = lerpf(_yaw_rate, wrapf(cam_yaw - _prev_cam_yaw, -PI, PI) / maxf(delta, 0.001), minf(1.0, delta * 6.0))
	_prev_cam_yaw = cam_yaw
	if _b_hold_t >= 0.0:                     # B près d'un obstacle : maintenu = cachette, relâché = dash
		if Input.is_action_pressed("dash"):
			_b_hold_t += delta
			if _b_hold_t >= B_HOLD:
				_b_hold_t = -1.0
				_try_cover(false)
		else:
			_b_hold_t = -1.0
			_do_dash()
	if in_cover and (state != State.GROUND or dead):
		_leave_cover(false)
	var tile: String = world.tile_at(global_position)
	var in_water := tile == "w" and global_position.y < 0.4
	match state:
		State.GROUND, State.AIR, State.LANDING, State.FALL:
			_ground_step(delta, tile, in_water)
		State.FLY:
			_fly_step(delta)
		State.HOVER:
			_hover_step(delta)
	_heat_step(delta, in_water)
	_last_vy = velocity.y
	move_and_slide()
	_after_move(tile)
	_animate(delta)
	_prev_pos = _cur_pos
	_cur_pos = global_position
	if _cur_pos.distance_to(_prev_pos) > 6.0:   # téléportation : pas d'interpolation
		_prev_pos = _cur_pos


## Rendu fluide : la physique tourne à 60 Hz, l'écran souvent plus vite (144 Hz sur un portable).
## On place l'armure et la caméra entre les deux dernières positions physiques, et la caméra tourne à chaque image.
func _process(delta: float) -> void:
	if world == null:
		return
	_pose_model(delta)
	var f := Engine.get_physics_interpolation_fraction()
	var offset := _prev_pos.lerp(_cur_pos, f) - global_position
	model.position = _model_base + offset
	pivot.position = PIVOT_BASE * size_scale + Vector3(0, cam_y_add, 0) + offset
	_camera_step(delta)


func _ground_step(delta: float, tile: String, in_water: bool) -> void:
	var dir := _input_dir()
	var speed := walk_speed * JOG
	if dead:
		dir = Vector3.ZERO
	if combat.melee_t > 0.0:
		velocity.x = melee_lunge.x
		velocity.z = melee_lunge.z
		if not is_on_floor():
			velocity.y -= GRAVITY * delta * 0.3
		else:
			velocity.y = -0.5
		return
	if in_cover and dash_t <= 0.0:
		_cover_step(delta)
		return
	if _vault_t > 0.0:
		_vault_t -= delta
		var push := 7.0 if _vault_t < 0.45 else 0.0
		velocity.x = _vault_dir.x * push
		velocity.z = _vault_dir.z * push
		velocity.y -= GRAVITY * delta
		if is_on_floor() and velocity.y <= 0.0 and _vault_t < 0.4:
			_vault_t = 0.0
		return
	if sprinting:
		var aim_out: bool = combat.aiming or Input.is_action_pressed("fire")
		if aim_out or (_stick().length() < 0.2 and destination == null) or dead:
			sprinting = false
		else:
			speed = walk_speed * sprint_mult
	if dash_t > 0.0:
		# Esquive : poussée franche qui retombe vite (le poids de l'exo reprend le dessus)
		dash_t -= delta
		var k := clampf(dash_t / DODGE_TIME, 0.0, 1.0)
		var v := lerpf(walk_speed * JOG, DODGE_SPEED, k * k)
		velocity.x = dash_dir.x * v
		velocity.z = dash_dir.z * v
		velocity.y -= GRAVITY * 0.8 * delta
		if is_on_floor() and velocity.y <= 0.0:
			velocity.y = -0.5
		return
	if in_water:
		speed *= 0.55
	if state == State.LANDING:
		landing_t -= delta
		# On enchaîne : viser, tirer ou repartir coupe la réception (comme dans Anthem)
		var act: bool = combat.aiming or Input.is_action_pressed("fire") or sprinting
		if landing_t <= 0.0 or act or (landing_t < 0.2 and dir.length() > 0.3):
			state = State.GROUND
		else:
			dir = Vector3.ZERO
	var control := (5.0 if sprinting else 8.0) if is_on_floor() else 3.0   # un exo lourd : il lui faut un instant pour lancer sa masse
	if state == State.LANDING:
		control = 2.5
	var k := minf(1.0, delta * control)
	velocity.x = lerpf(velocity.x, dir.x * speed, k)
	velocity.z = lerpf(velocity.z, dir.z * speed, k)
	if is_on_floor() and velocity.y <= 0.0:
		if state == State.AIR or state == State.FALL:
			state = State.GROUND
			_ground_impact(-_last_vy)
		velocity.y = -0.5
	else:
		velocity.y -= GRAVITY * delta
		if state == State.GROUND and velocity.y < -3.0:
			state = State.AIR


func _fly_forward() -> Vector3:
	# Direction de vol : là où regarde la caméra, le palier étant un peu au-dessus de l'horizontale
	var pitch := (cam_pitch - PITCH_NEUTRAL) * 1.3
	var flat := Basis(Vector3.UP, cam_yaw) * Vector3(0, 0, -1)
	return Vector3(flat.x * cos(pitch), -sin(pitch), flat.z * cos(pitch)).normalized()


func _fly_step(delta: float) -> void:
	var st := _stick()
	var fwd := _fly_forward()
	var right := Basis(Vector3.UP, cam_yaw) * Vector3(1, 0, 0)
	var speed := fly_speed
	if st.y < -0.3 or boost_t > 0.0:
		speed *= fly_boost
	elif st.y > 0.3:
		speed *= 0.6
	var target := fwd * speed + right * st.x * speed * 0.45
	if roll_t > 0.0:
		target += right * roll_dir * 20.0 * sin(roll_t / ROLL_TIME * PI)   # vrille : écart latéral franc
	if takeoff_t > 0.0:
		takeoff_t -= delta
		target.y += 7.0          # décollage : on prend de la hauteur avant le palier
	if global_position.y > ceiling and target.y > 0.0:
		target.y = 0.0
	# Vol rasant : près du sol, l'exo glisse au-dessus (eau, herbe) au lieu de se poser,
	# sauf si l'on pique franchement vers le bas.
	var h := _height_above_ground()
	if h < 2.2 and cam_pitch < PITCH_NEUTRAL + 0.45 and target.y < 1.0:
		target.y = maxf(target.y, (2.2 - h) * 5.0)
	if h < 3.5 and velocity.length() > 10.0:
		_downwash_t -= delta
		if _downwash_t <= 0.0:
			_downwash_t = 0.05
			var g := global_position - Vector3(0, h - 0.05, 0) - velocity.normalized() * 1.2
			var wet: bool = world.tile_at(global_position) == "w"
			var col := Color(0.85, 0.93, 1.0) if wet else Color(0.75, 0.7, 0.55)
			Fx.sparks(g, Vector3.UP, col, 10 if wet else 5, 5.0 if wet else 3.0, 0.6, 0.35, 70.0, -6.0)
			if wet:
				Fx.ring(g, 1.6, Color(0.9, 0.95, 1.0, 0.4), 0.35, Vector3.UP, 0.12)
	velocity = velocity.lerp(target, minf(1.0, delta * (8.0 if roll_t > 0.0 else 3.0)))
	if is_on_floor() and velocity.y <= 0.0:
		_touch_down()


func _hover_step(delta: float) -> void:
	var st := _stick()
	var dir := Basis(Vector3.UP, cam_yaw) * Vector3(st.x, 0.0, st.y)
	var target := dir * walk_speed * 0.8
	# Monter / descendre doucement avec la caméra
	target.y = -(cam_pitch - PITCH_NEUTRAL) * 4.0
	if roll_t > 0.0:
		target += Basis(Vector3.UP, cam_yaw) * Vector3(roll_dir * 14.0 * sin(roll_t / ROLL_TIME * PI), 0, 0)
	velocity = velocity.lerp(target, minf(1.0, delta * (8.0 if roll_t > 0.0 else 4.0)))
	# Souffle des propulseurs au sol quand on plane bas
	_downwash_t -= delta
	var h := _height_above_ground()
	if h < 7.0 and _downwash_t <= 0.0:
		_downwash_t = 0.18
		var g := global_position - Vector3(0, h - 0.05, 0)
		Fx.ring(g, 1.5 + h * 0.25, Color(0.85, 0.8, 0.65, 0.35 * (1.0 - h / 7.0)), 0.5, Vector3.UP, 0.12)
		Fx.sparks(g, Vector3.UP, Color(0.75, 0.7, 0.55), 5, 3.5, 0.6, 0.35, 170.0, -1.0)
	if is_on_floor() and velocity.y <= 0.0:
		_touch_down()


## Hauteur au-dessus du sol réel (rayon vers le bas), 99 si rien dans les 40 m.
func _height_above_ground() -> float:
	if not is_inside_tree():
		return 99.0
	var a := global_position + Vector3(0, 0.2, 0)
	var q := PhysicsRayQueryParameters3D.create(a, a - Vector3(0, 40, 0))
	q.exclude = [get_rid()]
	var r := get_world_3d().direct_space_state.intersect_ray(q)
	return 99.0 if r.is_empty() else a.y - 0.2 - r["position"].y


## Réception d'un saut ou d'une chute : plus on tombe vite, plus c'est lourd.
func _ground_impact(fall_speed: float) -> void:
	_boost_used = false
	if fall_speed > 13.0:
		_hero_landing(fall_speed)
	elif fall_speed > 6.0:
		Fx.ring(global_position + Vector3(0, 0.08, 0), 1.8, Color(0.85, 0.8, 0.6, 0.45), 0.3, Vector3.UP, 0.15)
		Fx.sparks(global_position + Vector3(0, 0.1, 0), Vector3.UP, Color(0.75, 0.7, 0.55), 12, 3.0, 0.6, 0.3, 100.0, -2.0)
		Fx.shake(0.08 + fall_speed * 0.01)
		if anim:
			anim.land(0.5)


## Réception de super-héros : genou et poing au sol, onde de choc, cailloux, la caméra encaisse.
func _hero_landing(force: float) -> void:
	var k := clampf((force - 10.0) / 20.0, 0.3, 1.0)
	state = State.LANDING
	landing_t = 0.45
	velocity.x *= 0.2
	velocity.z *= 0.2
	var p := global_position + Vector3(0, 0.08, 0)
	Fx.ring(p, 3.5 + 3.0 * k, Color(0.9, 0.85, 0.7, 0.7), 0.45, Vector3.UP, 0.35)
	Fx.ring(p, 1.8 + 1.5 * k, Color(1.0, 0.8, 0.5, 0.8), 0.25, Vector3.UP, 0.25)
	Fx.sparks(p, Vector3.UP, Color(0.75, 0.7, 0.55), int(24 + 30 * k), 6.0, 0.9, 0.45, 150.0, -3.0)
	Fx.debris(p + Vector3(0, 0.2, 0), Color(0.5, 0.45, 0.4), int(6 + 8 * k), 8.0)
	Fx.shake(0.3 + 0.35 * k)
	Fx.kick(4.0 + 4.0 * k)
	if k > 0.7:
		Fx.hitstop(0.35, 0.06)
	if anim:
		anim.land(1.0)
	message.emit("Réception", 0.8)


func _touch_down() -> void:
	_boost_used = false
	var hv := Vector2(velocity.x, velocity.z).length()
	if _last_vy < -9.0 and hv < 14.0:          # on arrive en piqué : réception héroïque
		_hero_landing(-_last_vy + hv * 0.3)
		return
	Fx.ring(global_position + Vector3(0, 0.1, 0), 2.5 + hv * 0.15, Color(0.85, 0.8, 0.6, 0.6), 0.4, Vector3.UP, 0.2)
	Fx.sparks(global_position + Vector3(0, 0.1, 0), Vector3.UP, Color(0.75, 0.7, 0.55), 24, 4.0, 0.8, 0.4, 100.0, -2.0)
	Fx.shake(0.15 + hv * 0.02)
	if anim:
		anim.land()
	if hv > 5.0:
		state = State.LANDING
		landing_t = 0.35
		message.emit("Atterrissage en glissade", 1.0)
	else:
		state = State.GROUND
		message.emit("Atterrissage", 1.0)


func _heat_step(delta: float, in_water: bool) -> void:
	cooling = false
	if overheat > 0.0:
		overheat -= delta
		heat = maxf(0.0, overheat / overheat_seconds)
		return
	if in_water or cooling_zones > 0:
		heat = maxf(0.0, heat - delta * 1.2)
		cooling = true
		if not _was_cooling_msg and heat > 0.05:
			message.emit("Refroidissement !", 1.2)
		_was_cooling_msg = true
		return
	_was_cooling_msg = false
	match state:
		State.FLY:
			if velocity.y < -4.0:
				heat = maxf(0.0, heat - delta * 0.25)      # piqué : refroidit
				cooling = true
			elif velocity.y > 2.5:
				heat += delta / fly_seconds * 1.6          # montée : chauffe vite
			else:
				heat += delta / fly_seconds
		State.HOVER:
			heat += delta / hover_seconds
		_:
			heat = maxf(0.0, heat - delta * 0.35)
	if heat >= 1.0:
		heat = 1.0
		overheat = overheat_seconds
		if _airborne():
			state = State.AIR
		message.emit("Surchauffe ! Propulseurs coupés (3 s)", 2.5)


func _after_move(tile: String) -> void:
	if tile == "~" and global_position.y < -7.0 and not _airborne():
		_respawn()
		return
	if is_on_floor() and state == State.GROUND and world.is_walkable(tile) and tile != "w":
		safe_pos = global_position


func _respawn() -> void:
	message.emit("Chute dans le gouffre !", 2.0)
	global_position = safe_pos + Vector3(0, 0.3, 0)
	velocity = Vector3.ZERO
	state = State.GROUND
	heat = minf(heat, 0.5)


# ---------------------------------------------------------------- animation procédurale et caméra
func _animate(delta: float) -> void:
	var hv := Vector2(velocity.x, velocity.z)
	var hspeed := hv.length()
	var lean_target := 0.0
	var roll_target := 0.0
	var yaw_target := _yaw
	var aim_out: bool = combat.aiming or Input.is_action_pressed("fire")
	match state:
		State.FLY:
			yaw_target = cam_yaw
			lean_target = clampf(1.25 - (velocity.y / fly_speed) * 0.8, 0.4, 1.5)
			if takeoff_t > 0.0:
				lean_target = 0.15             # décollage : poussée verticale, corps droit
			# Inclinaison dans les virages : stick et vitesse de rotation de la caméra
			roll_target = -_stick().x * 0.5 + clampf(_yaw_rate * 0.35, -0.9, 0.9)
		State.HOVER:
			yaw_target = cam_yaw              # en stationnaire on fait face à la visée, comme dans Anthem
			var local := Basis(Vector3.UP, -cam_yaw) * velocity
			lean_target = clampf(-local.z * 0.05, -0.3, 0.35) + 0.05
			roll_target = clampf(-local.x * 0.05, -0.35, 0.35)
		State.LANDING:
			lean_target = -0.1
		_:
			if in_cover:
				yaw_target = atan2(cover_normal.x, cover_normal.z)   # face à l'obstacle
			elif hspeed > 0.5:
				yaw_target = atan2(-velocity.x, -velocity.z)
			if state == State.AIR and velocity.y < -2.0:
				lean_target = 0.2
			if sprinting and is_on_floor():
				lean_target = 0.12
			if is_on_floor() and state == State.GROUND and not in_cover:
				# Le poids de l'armure : on se penche en accélérant, on se redresse en freinant,
				# on s'incline dans les virages
				var acc := (hv - _prev_hv) / maxf(delta, 0.001)
				var fwd := Vector2(-sin(_yaw), -cos(_yaw))
				_acc_lean = lerpf(_acc_lean, clampf(acc.dot(fwd) * 0.012, -0.12, 0.15), minf(1.0, delta * 6.0))
				lean_target += _acc_lean
				var heading := atan2(-velocity.x, -velocity.z)
				if hspeed > 2.0 and _prev_hv.length() > 2.0:
					var turn := wrapf(heading - atan2(-_prev_hv.x, -_prev_hv.y), -PI, PI) / maxf(delta, 0.001)
					_turn_roll = lerpf(_turn_roll, clampf(turn * hspeed * 0.012, -0.22, 0.22), minf(1.0, delta * 5.0))
				else:
					_turn_roll = lerpf(_turn_roll, 0.0, minf(1.0, delta * 5.0))
				roll_target += _turn_roll
	if aim_out and (not in_cover or cover_peek > 0.3):
		yaw_target = cam_yaw            # on fait face à la visée, on se déplace en pas chassés
	if combat.melee_t > 0.0:
		yaw_target = _yaw
		lean_target = 0.55
	if dash_t > 0.0:
		# Esquive : penché dans le sens de la poussée (de face, de côté ou à reculons)
		var local := Basis(Vector3.UP, -yaw_target) * dash_dir
		lean_target = -local.z * 0.35
		roll_target = -local.x * 0.45
	if dead:
		lean_target = -1.3
		roll_target = 0.4
	_prev_hv = hv
	_yaw_target = yaw_target
	_lean_target = lean_target
	_roll_target = roll_target
	var thrust := (_airborne() or dash_t > 0.0 or combat.melee_t > 0.0) and not dead
	flames.visible = thrust
	for p in _trails:
		p.emitting = thrust
		p.amount_ratio = 1.0 if state == State.FLY else 0.5
	# Impression de vitesse : lignes de vent et traînées aux mains en vol rapide (et en course)
	var speed := velocity.length()
	var fast := 0.0
	if state == State.FLY:
		fast = clampf((speed - 12.0) / 14.0, 0.0, 1.0)
	elif sprinting and is_on_floor():
		fast = 0.25
	_speed_lines.emitting = fast > 0.05
	var want_blur := fast
	if sprinting and is_on_floor():
		want_blur = 0.45
	if dash_t > 0.0 or roll_t > 0.0:
		want_blur = maxf(want_blur, 0.8)
	if boost_t > 0.0 or takeoff_t > 0.0:
		want_blur = maxf(want_blur, 1.0)
	_blur_amt = lerpf(_blur_amt, want_blur, minf(1.0, delta * (10.0 if want_blur > _blur_amt else 4.0)))
	_blur.visible = _blur_amt > 0.02 and _blur_ok()
	_blur_mat.set_shader_parameter("amount", _blur_amt)
	_speed_lines.amount_ratio = maxf(0.05, fast)
	var trails_on := state == State.FLY and (speed > 17.0 or roll_t > 0.0) and not dead
	for i in _hand_trails.size():
		var p: GPUParticles3D = _hand_trails[i]
		p.emitting = trails_on
		if look:
			var h: Node3D = look.hand_node("hand_L" if i == 0 else "hand_R")
			if h:
				p.global_position = h.global_position
	# Poussière soulevée en glissade, dash et atterrissage
	_dust_t -= delta
	if is_on_floor() and (dash_t > 0.0 or state == State.LANDING) and _dust_t <= 0.0:
		_dust_t = 0.06
		Fx.sparks(global_position + Vector3(0, 0.1, 0), Vector3.UP, Color(0.75, 0.7, 0.55), 6, 3.0, 0.6, 0.35, 90.0, -2.0)
	flame_light.light_energy = (3.0 if state == State.FLY else 1.5) if thrust else 0.0
	if thrust:
		flames.scale.y = (1.6 if state == State.FLY else 0.8) + randf() * 0.4
		if boost_t > 0.0 or takeoff_t > 0.0:
			flames.scale.y *= 1.5


## Orientation de l'armure (cap, penché, roulis, vrille) lissée à chaque image et non à chaque pas de physique.
func _pose_model(delta: float) -> void:
	if roll_t <= 0.0:
		_yaw = model.rotation.y               # on reprend le cap si un autre script l'a changé
	_yaw = lerp_angle(_yaw, _yaw_target, minf(1.0, delta * (12.0 if state == State.FLY else 9.0)))
	_lean = lerpf(_lean, _lean_target, minf(1.0, delta * 4.0))
	_roll = lerpf(_roll, _roll_target, minf(1.0, delta * 3.0))
	var base_pos := Vector3.ZERO
	match state:
		State.FLY:
			_bob += delta * 3.0
			base_pos.y = 0.3 + sin(_bob) * 0.05
		State.HOVER:
			_bob += delta * 2.0
			base_pos.y = 0.2 + sin(_bob) * 0.12
	# Mur haut : pour tirer on sort sur le côté
	if in_cover and not cover_low and cover_peek > 0.0:
		base_pos += cover_normal.cross(Vector3.UP).normalized() * -0.8 * cover_peek
	var b := Basis.from_euler(Vector3(-_lean, _yaw, _roll))
	if roll_t > 0.0:
		# Vrille : un tour complet autour de l'axe de vol, centré sur le torse
		var k := 1.0 - roll_t / ROLL_TIME
		var spin := -roll_dir * TAU * (k * k * (3.0 - 2.0 * k))
		var axis := Basis(Vector3.UP, _yaw) * Vector3(0, 0, -1)
		var r := Basis(axis, spin)
		var c := b * Vector3(0, 1.0, 0)
		base_pos += c - r * c
		b = r * b
	model.basis = b.scaled(Vector3.ONE * size_scale)
	_model_base = base_pos


## Appelé par l'animation à chaque pas : un exo de plusieurs tonnes, ça se sent.
func footstep(run: float) -> void:
	if not is_on_floor() or in_cover:
		return
	if run > 0.3:
		Fx.sparks(global_position + Vector3(0, 0.05, 0), Vector3.UP, Color(0.75, 0.7, 0.55), 4, 2.0, 0.45, 0.25, 80.0, -2.0)


func _camera_step(delta: float) -> void:
	var look := Input.get_vector("look_left", "look_right", "look_up", "look_down")
	if look.length() > 0.05:
		_turn_camera(-look.x * 2.6 * delta, look.y * 1.6 * delta)
	elif Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and state != State.FLY and not combat.aiming and not Input.is_action_pressed("fire") and not in_cover:
		var hv := Vector2(velocity.x, velocity.z)
		if hv.length() > 1.0:
			cam_yaw = lerp_angle(cam_yaw, model.rotation.y, minf(1.0, delta * 1.6))
		cam_pitch = clampf(cam_pitch, 0.1, 1.2) if not _airborne() else cam_pitch
	pivot.rotation.y = cam_yaw
	arm.rotation.x = -cam_pitch
	# Caméra à l'épaule façon Anthem : près du dos, le Solaris sur le tiers gauche de l'image.
	# Elle ne se recentre (et recule) qu'en vol, où l'on a besoin de voir loin.
	var want_len := 4.6
	var want_x := 0.85
	var want_y := 0.3
	var want_fov := 62.0
	if state == State.FLY:
		want_len = 7.0
		want_x = 0.25
		want_y = 0.4
		want_fov = 68.0 + clampf((velocity.length() - 14.0) * 0.6, 0.0, 12.0)   # plus on va vite, plus l'image s'ouvre
		if boost_t > 0.0:
			want_fov += 6.0
	elif state == State.HOVER:
		want_len = 5.4
	elif sprinting:
		want_len = 5.3
		want_x = 0.7
		want_fov = 72.0
	elif dash_t > 0.0:
		want_fov = 68.0
	want_len += _takeoff_cam * 3.0
	if in_cover:
		want_len = 4.0
		want_x = 1.0
		if cover_low and cover_peek < 0.5:
			want_y = -0.2                    # accroupi derrière le muret
	if combat.aiming:
		want_len = 2.5
		want_fov = 50.0
		want_x = 0.85                     # visée : on se colle à l'épaule droite
		want_y = 0.25
		if in_cover and not cover_low:
			want_x = 1.4
	if state != State.FLY:
		want_len *= cam_dist_mult
		want_x += cam_x_add
		if combat.aiming:
			want_len = maxf(want_len, minf(2.5, 2.0 * size_scale))   # en visée on garde l'épaule et le fusil dans l'image
	want_fov += cam_fov_add
	var cs := minf(1.0, delta * (9.0 if combat.aiming else 6.0))
	arm.spring_length = lerpf(arm.spring_length, want_len, cs)
	arm.position.x = lerpf(arm.position.x, want_x, cs)
	arm.position.y = lerpf(arm.position.y, want_y, cs)
	camera.fov = lerpf(camera.fov, want_fov, minf(1.0, delta * 4.0)) + Fx.fov_kick
	var s: float = Fx.shake_amount
	if state == State.FLY and boost_t > 0.0:
		s = maxf(s, 0.06)                     # le boost fait vibrer la caméra
	camera.h_offset = randf_range(-s, s) * 0.35
	camera.v_offset = randf_range(-s, s) * 0.35


# ---------------------------------------------------------------- HUD
func _ground_below() -> float:
	match world.tile_at(global_position):
		"#", "=": return world.PLATEAU
		"~": return world.PIT
		_: return 0.0


func altitude() -> float:
	return maxf(0.0, global_position.y - _ground_below())


func flying() -> bool:
	return _airborne()


func state_label() -> String:
	if dead:
		return "Hors service"
	if combat.melee_t > 0.0:
		return "Mêlée"
	match state:
		State.FLY:
			var mode := "piqué" if velocity.y < -4.0 else ("montée" if velocity.y > 2.5 else "palier")
			if roll_t > 0.0:
				return "Vrille"
			return "En vol · %s · %.0f m" % [mode, altitude()]
		State.HOVER: return ("Vrille" if roll_t > 0.0 else "Vol stationnaire · %.0f m" % altitude())
		State.AIR: return "En l'air"
		State.LANDING: return "Atterrissage"
		_:
			if in_cover:
				return "À couvert · " + ("tir" if cover_peek > 0.5 else ("muret" if cover_low else "mur"))
			if dash_t > 0.0:
				return "Dash"
			return "Course" if sprinting else "Au sol"


func zone_label() -> String:
	match world.tile_at(global_position):
		"h": return "Zone cachée"
		"w": return "Eau (refroidit)"
		"=": return "Rampe"
		"#": return "Plateau (étage 1)"
		_: return "Plaine"


# ---------------------------------------------------------------- pièces montées (Loadout)
## Applique les pièces : capacités (vol, dash, vitesse…) et forme (pièces visibles, peinture).
func apply_loadout() -> void:
	var pr: Dictionary = Loadout.part("propulseurs")
	can_fly = pr["fly"]
	fly_seconds = maxf(0.1, pr["fly_seconds"])
	hover_seconds = maxf(0.1, pr["hover_seconds"])
	fly_speed = maxf(1.0, pr["fly_speed"])
	fly_boost = pr["boost"]
	var jb: Dictionary = Loadout.part("jambes")
	can_dash = jb["dash"]
	walk_speed = jb["walk_speed"]
	jump_speed = jb["jump_speed"]
	dash_cooldown = jb["dash_cooldown"]
	if combat:
		combat.apply_loadout()
	if _airborne() and not can_fly:
		state = State.AIR


## Couleur d'énergie du preset (zone 6) : flammes, traînées, traçantes, aura.
func _on_energy_color(c: Color) -> void:
	for p in _trails:
		var m: ParticleProcessMaterial = p.process_material
		m.color = c
		m.color_ramp = Fx._fade_ramp(c.darkened(0.3))
		(p.draw_pass_1 as QuadMesh).material = Fx._spark_mat(c)
	for f in [flames.get_node_or_null("Left"), flames.get_node_or_null("Right")]:
		if f:
			var fm := StandardMaterial3D.new()
			fm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			fm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
			fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			fm.albedo_color = Color(c.r, c.g, c.b, 0.9)
			f.material_override = fm
	flame_light.light_color = c
	if combat:
		combat.apply_energy_color(c)


## Les flammes sortent des tuyères du torse porté (points d'attache du torse).
func _on_flames_moved(pos: Vector3, spacing: float) -> void:
	flames.position = pos
	for n in ["Left", "Right"]:
		var f: Node3D = flames.get_node_or_null(n)
		if f:
			f.position.x = -spacing if n == "Left" else spacing
	for i in _trails.size():
		_trails[i].position.x = -spacing if i == 0 else spacing
