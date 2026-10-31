class_name StatusFx
extends Node3D
## Amorces visibles sur une cible (mannequin ou ennemi), comme dans Anthem : on voit d'un coup d'œil
## qui est prêt pour un combo. Gel = carapace de glace + brume, brûlure = flammes + braises,
## étourdi = arcs électriques. Le texte au-dessus de la barre de vie dit l'amorce.

const ICE := Color(0.62, 0.88, 1.0)
const FIRE := Color(1.0, 0.55, 0.15)
const SHOCK := Color(0.75, 0.85, 1.0)

var size := 1.0                  # taille de la cible (1 = soldat)
var _owner_node: Node3D
var _meshes: Array = []
var _ice_mat: StandardMaterial3D
var _fire: GPUParticles3D
var _embers: GPUParticles3D
var _mist: GPUParticles3D
var _light: OmniLight3D
var _arc_t := 0.0
var _iced := false
var _t := 0.0


## À appeler une fois les maillages de la cible construits.
func setup(owner_node: Node3D, visual: Node3D, s: float) -> void:
	_owner_node = owner_node
	size = s
	_meshes.clear()
	_collect(visual)
	_ice_mat = StandardMaterial3D.new()
	_ice_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ice_mat.albedo_color = Color(0.78, 0.94, 1.0, 0.75)
	_ice_mat.metallic = 0.2
	_ice_mat.roughness = 0.08
	_ice_mat.rim_enabled = true
	_ice_mat.rim = 1.0
	_ice_mat.rim_tint = 0.2
	_ice_mat.emission_enabled = true
	_ice_mat.emission = Color(0.35, 0.65, 0.9)
	_ice_mat.emission_energy_multiplier = 0.9
	_ice_mat.grow = true
	_ice_mat.grow_amount = 0.06
	_fire = _particles(26, 0.7, Fx._flip_mat("fire_sheet", true), 0.75 * s, Color(1.0, 0.9, 0.8))
	(_fire.process_material as ParticleProcessMaterial).gravity = Vector3(0, 3.0, 0)
	_embers = _particles(24, 1.0, Fx._spark_mat(FIRE), 0.07 * s, FIRE)
	var em: ParticleProcessMaterial = _embers.process_material
	em.initial_velocity_min = 1.5
	em.initial_velocity_max = 3.5
	em.gravity = Vector3(0, 2.0, 0)
	_mist = _particles(14, 1.6, Fx._flip_mat("smoke_sheet", false), 1.0 * s, Color(0.85, 0.95, 1.0, 0.35))
	(_mist.process_material as ParticleProcessMaterial).gravity = Vector3(0, -0.6, 0)
	_light = OmniLight3D.new()
	_light.omni_range = 4.0 * s
	_light.light_energy = 0.0
	add_child(_light)


func _collect(n: Node) -> void:
	if n is MeshInstance3D:
		_meshes.append(n)
	for c in n.get_children():
		if not (c is Label3D):
			_collect(c)


func _particles(amount: int, life: float, mat: Material, quad: float, color: Color) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = amount
	p.lifetime = life
	p.emitting = false
	p.local_coords = false
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.visibility_aabb = AABB(Vector3(-6, -3, -6), Vector3(12, 12, 12))
	var m := ParticleProcessMaterial.new()
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	m.emission_sphere_radius = 0.45 * size
	m.direction = Vector3.UP
	m.spread = 25.0
	m.initial_velocity_min = 0.4
	m.initial_velocity_max = 1.2
	m.angle_min = -180.0
	m.angle_max = 180.0
	m.scale_min = 0.6
	m.scale_max = 1.2
	m.scale_curve = Fx._curve(0.7, 1.0)
	m.anim_speed_min = 1.0
	m.anim_speed_max = 1.0
	m.color = color
	m.color_ramp = Fx._fade_ramp(color)
	p.process_material = m
	var q := QuadMesh.new()
	q.size = Vector2(quad, quad)
	q.material = mat
	p.draw_pass_1 = q
	add_child(p)
	return p


## Chaque image : burning / frozen / stunned en secondes restantes, center = centre de la cible.
func update(delta: float, burning: float, frozen: float, stunned: float, center: Vector3) -> void:
	_t += delta
	global_position = center
	var fire_on := burning > 0.0
	var ice_on := frozen > 0.0
	var shock_on := stunned > 0.0 and not ice_on
	_fire.emitting = fire_on
	_embers.emitting = fire_on
	_mist.emitting = ice_on
	if ice_on != _iced:
		_iced = ice_on
		for m in _meshes:
			if is_instance_valid(m):
				(m as MeshInstance3D).material_overlay = _ice_mat if ice_on else null
		if not ice_on:
			# Le dégel : quelques éclats tombent
			Fx.chips(center, Vector3.UP, ICE, 8, 3.0, 0.06 * size, 1.0, true)
	if ice_on:
		_ice_mat.emission_energy_multiplier = 0.8 + 0.3 * sin(_t * 3.0)
	if shock_on:
		_arc_t -= delta
		if _arc_t <= 0.0:
			_arc_t = randf_range(0.08, 0.2)
			var dir := Vector3(randf_range(-1, 1), randf_range(-0.3, 1), randf_range(-1, 1)).normalized()
			Fx.streaks(center + dir * 0.4 * size, dir, SHOCK, 4, 6.0, 0.12, 0.3 * size, 80.0, 0.0, 0.025)
	var e := 0.0
	var c := FIRE
	if fire_on:
		e = 1.6 + 0.8 * absf(sin(_t * 11.0) * sin(_t * 7.3))
	elif ice_on:
		e = 0.8
		c = ICE
	elif shock_on:
		e = 1.0 if randf() < 0.4 else 0.2
		c = SHOCK
	_light.light_color = c
	_light.light_energy = lerpf(_light.light_energy, e, minf(1.0, delta * 12.0))


## Le texte et la couleur de l'amorce, pour l'étiquette au-dessus de la cible.
static func label(burning: float, frozen: float, stunned: float) -> Array:
	if frozen > 0.0:
		return ["AMORCÉ · GEL", ICE]
	if burning > 0.0:
		return ["AMORCÉ · FEU", FIRE]
	if stunned > 0.0:
		return ["AMORCÉ · CHOC", SHOCK]
	return ["", Color.WHITE]
