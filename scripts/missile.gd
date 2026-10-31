extends Node3D
class_name Missile
## Missile à tête chercheuse du Ranger : missile au poignet (pouvoir), salve d'impulsion (sans guidage)
## et batterie de missiles de l'ultime. Part dans une direction, vire vers sa cible, explose au contact.

var combat: Combat
var target: Node3D = null       # cible verrouillée (peut mourir en route : le missile file alors tout droit)
var velocity := Vector3.ZERO
var speed := 34.0
var turn_rate := 5.0            # rad/s : 0 = pas de guidage
var arm_time := 0.12            # pendant ce délai, il sort du lanceur sans virer
var damage := 45.0
var radius := 3.0
var detonator := true           # fait exploser les cibles amorcées (combo)
var color := Color(1.0, 0.6, 0.2)
var life := 4.0
var size := 1.0
var shake := 0.25
var label := ""                 # message de combo
var smoky := true               # vraie traînée de fumée (missiles) ; false = boule d'énergie (salve d'impulsion)
var _smoke: GPUParticles3D
var _flame: MeshInstance3D
var _t := 0.0
var _trail: GPUParticles3D
var _body: MeshInstance3D
var _exclude: Array[RID] = []


func launch(from: Vector3, dir: Vector3, shooter: RID) -> void:
	global_position = from
	velocity = dir.normalized() * speed
	_exclude = [shooter]
	_body = MeshInstance3D.new()
	var cm := CapsuleMesh.new()
	cm.radius = 0.07 * size
	cm.height = 0.42 * size
	_body.mesh = cm
	_body.rotation.x = PI / 2.0
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.85, 0.85, 0.82)
	m.metallic = 0.6
	m.roughness = 0.35
	_body.material_override = m
	add_child(_body)
	# Tuyère lumineuse à l'arrière
	var glow := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.1 * size
	sm.height = 0.2 * size
	glow.mesh = sm
	glow.position.z = 0.22 * size
	glow.material_override = Fx._spark_mat(color)
	add_child(glow)
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = 1.4
	light.omni_range = 3.5
	add_child(light)
	# Étincelles brûlantes juste derrière la tuyère
	_trail = GPUParticles3D.new()
	_trail.amount = 40
	_trail.lifetime = 0.25 if smoky else 0.5
	_trail.local_coords = false
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0, 0, 1)
	pm.spread = 10.0
	pm.initial_velocity_min = 2.0
	pm.initial_velocity_max = 5.0
	pm.scale_min = 0.6 * size
	pm.scale_max = 1.2 * size
	pm.color_ramp = Fx._fade_ramp(Color(color.r, color.g * 0.9, color.b * 0.7))
	_trail.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.18, 0.18)
	q.material = Fx._spark_mat(color)
	_trail.draw_pass_1 = q
	_trail.position.z = 0.25 * size
	add_child(_trail)
	if smoky:
		# Flamme de tuyère : la flamme de bouche vue de côté, tournée vers l'arrière, qui vacille
		_flame = MeshInstance3D.new()
		_flame.mesh = Fx._cross_mesh(true)
		var fm := StandardMaterial3D.new()
		fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		fm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		fm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		fm.disable_fog = true
		fm.cull_mode = BaseMaterial3D.CULL_DISABLED
		fm.albedo_texture = Fx.tex("muzzle_side")
		fm.uv1_scale = Vector3(1, 0.5, 1)
		fm.albedo_color = Color(1.0, 0.8, 0.55).lerp(color, 0.3)
		_flame.material_override = fm
		_flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_flame.basis = Basis(Vector3.RIGHT, PI / 2.0)      # Y du maillage vers +Z (l'arrière du missile)
		add_child(_flame)
		# Fumée blanche qui reste dans l'air derrière le missile
		_smoke = GPUParticles3D.new()
		_smoke.amount = 220
		_smoke.fixed_fps = 0
		_smoke.lifetime = 1.6
		_smoke.local_coords = false
		_smoke.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_smoke.visibility_aabb = AABB(Vector3(-40, -40, -40), Vector3(80, 80, 80))
		var sp := ParticleProcessMaterial.new()
		sp.direction = Vector3(0, 0, 1)
		sp.spread = 25.0
		sp.initial_velocity_min = 0.5
		sp.initial_velocity_max = 1.5
		sp.gravity = Vector3(0, 0.5, 0)
		sp.damping_min = 0.5
		sp.damping_max = 1.0
		sp.angle_min = -180.0
		sp.angle_max = 180.0
		sp.angular_velocity_min = -30.0
		sp.angular_velocity_max = 30.0
		sp.scale_min = 0.7
		sp.scale_max = 1.2
		sp.scale_curve = Fx._curve(0.3, 2.6)
		sp.anim_speed_min = 1.0
		sp.anim_speed_max = 1.0
		sp.color = Color(0.86, 0.85, 0.83, 0.38)
		_smoke.process_material = sp
		var sq := QuadMesh.new()
		sq.size = Vector2.ONE * 0.55 * size
		sq.material = Fx._flip_mat("smoke_sheet", false)
		_smoke.draw_pass_1 = sq
		_smoke.position.z = 0.3 * size
		add_child(_smoke)
		Fx.sound("missile_small", from, -4.0, 0.12, 10.0)
	_face()


func _face() -> void:
	if velocity.length() > 0.01:
		look_at(global_position + velocity, Vector3.UP if absf(velocity.normalized().y) < 0.98 else Vector3.RIGHT)


func _physics_process(delta: float) -> void:
	_t += delta
	life -= delta
	if target and (not is_instance_valid(target) or not target.alive):
		target = null
	if turn_rate > 0.0 and target and _t > arm_time:
		var want: Vector3 = (combat.aim_center(target) - global_position).normalized() * speed
		var ang := velocity.angle_to(want)
		var k := minf(1.0, turn_rate * delta / maxf(ang, 0.001))
		velocity = velocity.slerp(want, k) if ang > 0.001 else want
		speed = minf(speed + delta * 18.0, 60.0)
		velocity = velocity.normalized() * speed
	var step := velocity * delta
	var q := PhysicsRayQueryParameters3D.create(global_position, global_position + step * 1.2)
	q.exclude = _exclude
	var r := get_world_3d().direct_space_state.intersect_ray(q)
	if not r.is_empty():
		_explode(r["position"])
		return
	if target and _t > arm_time and global_position.distance_to(combat.aim_center(target)) < 0.9:
		_explode(global_position)
		return
	global_position += step
	_face()
	if _flame:
		var f := randf_range(0.8, 1.2)
		_flame.scale = Vector3(0.28 * size * f, 0.9 * size * f, 0.28 * size * f)
		_flame.position.z = 0.22 * size + 0.45 * size * f
	if life <= 0.0 or global_position.y < -10.0:
		_explode(global_position)


func _explode(pos: Vector3) -> void:
	if OS.has_feature("debug") and OS.get_environment("MISSILE_DEBUG") != "":
		print("[missile] boom ", pos, " t=", _t)
	Fx.explosion(pos, radius * 1.2, color, 0.6 + size * 0.4)
	Fx.ring(pos, radius, Color(color.r, color.g, color.b, 0.8), 0.3, Vector3.UP, 0.2)
	Fx.shake(shake)
	if combat and is_instance_valid(combat):
		combat.area_damage(pos, radius, damage, detonator, self)
	# La traînée de fumée reste dans l'air et se dissipe
	if _smoke:
		_smoke.emitting = false
		var sm := _smoke
		remove_child(sm)
		get_parent().add_child(sm)
		sm.global_position = pos
		get_tree().create_timer(1.8).timeout.connect(sm.queue_free)
	if _trail:
		_trail.emitting = false
		var t := _trail
		remove_child(t)
		get_parent().add_child(t)
		t.global_position = pos
		get_tree().create_timer(0.6).timeout.connect(t.queue_free)
	queue_free()
