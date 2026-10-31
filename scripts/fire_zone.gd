extends Node3D
## Brasier : flaque de feu au sol, brûle (amorce) tout ce qui s'y trouve pendant quelques secondes.

var radius := 3.5
var life := 5.0
var combat: Node
var _tick := 0.0
var _fx_t := 0.0
var _light: OmniLight3D
var _flames: GPUParticles3D
var _smoke: GPUParticles3D


func _ready() -> void:
	add_to_group("fire_zones")
	_light = OmniLight3D.new()
	_light.light_color = Color(1.0, 0.5, 0.15)
	_light.light_energy = 3.0
	_light.omni_range = radius * 2.5
	_light.position.y = 0.8
	add_child(_light)
	_flames = GPUParticles3D.new()
	_flames.amount = 40
	_flames.lifetime = 0.8
	var m := ParticleProcessMaterial.new()
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	m.emission_sphere_radius = radius * 0.9
	m.direction = Vector3.UP
	m.spread = 15.0
	m.initial_velocity_min = 1.5
	m.initial_velocity_max = 3.5
	m.gravity = Vector3(0, 2.0, 0)
	m.scale_min = 0.6
	m.scale_max = 1.3
	m.scale_curve = Fx._curve(0.6, 1.1)
	m.angle_min = -180.0
	m.angle_max = 180.0
	m.anim_speed_min = 1.0
	m.anim_speed_max = 1.0
	m.color = Color(1.0, 0.9, 0.8)
	_flames.process_material = m
	_flames.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var q := QuadMesh.new()
	q.size = Vector2(1.1, 1.1)
	q.material = Fx._flip_mat("fire_sheet", true)
	_flames.draw_pass_1 = q
	_flames.position.y = 0.4
	add_child(_flames)
	# Fumée noire qui monte au-dessus des flammes
	_smoke = GPUParticles3D.new()
	_smoke.amount = 30
	_smoke.lifetime = 2.5
	_smoke.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_smoke.visibility_aabb = AABB(Vector3(-10, -2, -10), Vector3(20, 20, 20))
	var sm := ParticleProcessMaterial.new()
	sm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	sm.emission_sphere_radius = radius * 0.7
	sm.direction = Vector3.UP
	sm.spread = 10.0
	sm.initial_velocity_min = 1.0
	sm.initial_velocity_max = 2.0
	sm.gravity = Vector3(0, 1.2, 0)
	sm.angle_min = -180.0
	sm.angle_max = 180.0
	sm.angular_velocity_min = -20.0
	sm.angular_velocity_max = 20.0
	sm.scale_curve = Fx._curve(0.5, 1.8)
	sm.anim_speed_min = 1.0
	sm.anim_speed_max = 1.0
	sm.color = Color(0.16, 0.15, 0.14, 0.7)
	_smoke.process_material = sm
	var sq := QuadMesh.new()
	sq.size = Vector2(2.2, 2.2)
	sq.material = Fx._flip_mat("smoke_sheet", false)
	_smoke.draw_pass_1 = sq
	_smoke.position.y = 1.4
	add_child(_smoke)
	Fx.mark(global_position, Vector3.UP, "scorch", radius * 2.0, Color(1, 1, 1, 0.9), 20.0)
	Fx.ring(global_position + Vector3(0, 0.15, 0), radius, Color(1.0, 0.5, 0.15, 0.9), 0.4, Vector3.UP, 0.2)
	Fx.sparks(global_position, Vector3.UP, Color(1.0, 0.6, 0.2), 30, 7.0, 0.6, 0.25, 120.0, -8.0)
	# Sol qui rougeoie
	var disc := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = radius
	cm.bottom_radius = radius
	cm.height = 0.05
	disc.mesh = cm
	var dm := StandardMaterial3D.new()
	dm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	dm.albedo_color = Color(1.0, 0.35, 0.1, 0.35)
	disc.material_override = dm
	disc.position.y = 0.06
	add_child(disc)


func _process(delta: float) -> void:
	life -= delta
	_light.light_energy = 2.5 + sin(Time.get_ticks_msec() * 0.02) * 0.8
	if life <= 0.0:
		_flames.emitting = false
		_smoke.emitting = false
		_light.light_energy = 0.0
		get_tree().create_timer(2.6).timeout.connect(queue_free)
		set_process(false)
		return
	_tick -= delta
	if _tick <= 0.0:
		_tick = 0.5
		for t in get_tree().get_nodes_in_group("targets"):
			if not t.alive:
				continue
			var p: Vector3 = t.center()
			var d := Vector2(p.x - global_position.x, p.z - global_position.z).length()
			if d < radius and absf(p.y - global_position.y) < 4.0:
				t.take_damage(4.0 * combat.damage_mult(), p, false, false)
				t.prime(3.0)
