extends Node
## Boîte à effets (autoload « Fx ») : particules, flashs, anneaux de choc, secousses de caméra, ralenti.

var shake_amount := 0.0
var fov_kick := 0.0
var _hitstop_t := 0.0
var _mats := {}
var _dot: GradientTexture2D


## Texture ronde et douce pour toutes les particules (sinon elles sont carrées).
func _dot_texture() -> GradientTexture2D:
	if _dot:
		return _dot
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	g.add_point(0.35, Color(1, 1, 1, 0.9))
	_dot = GradientTexture2D.new()
	_dot.gradient = g
	_dot.fill = GradientTexture2D.FILL_RADIAL
	_dot.fill_from = Vector2(0.5, 0.5)
	_dot.fill_to = Vector2(0.5, 0.0)
	_dot.width = 64
	_dot.height = 64
	return _dot


func _process(delta: float) -> void:
	var real := delta / maxf(0.05, Engine.time_scale)
	shake_amount = maxf(0.0, shake_amount - real * 2.2)
	fov_kick = maxf(0.0, fov_kick - real * 30.0)
	if _hitstop_t > 0.0:
		_hitstop_t -= real
		if _hitstop_t <= 0.0:
			Engine.time_scale = 1.0


func root() -> Node:
	return get_tree().current_scene


## Secousse de caméra (0.1 léger, 0.6 explosion).
func shake(amount: float) -> void:
	shake_amount = maxf(shake_amount, amount)


## Coup de zoom (degrés de FOV ajoutés, retombe tout seul).
func kick(deg: float) -> void:
	fov_kick = maxf(fov_kick, deg)


## Ralenti bref (impact fort).
func hitstop(scale: float, seconds: float) -> void:
	Engine.time_scale = scale
	_hitstop_t = seconds


# ---------------------------------------------------------------- matériaux partagés
func _spark_mat(color: Color) -> StandardMaterial3D:
	var key := "spark_" + color.to_html()
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.disable_fog = true
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.albedo_color = color
	m.albedo_texture = _dot_texture()
	m.emission_enabled = true
	m.emission = Color(color.r, color.g, color.b)
	m.emission_energy_multiplier = 2.0
	m.no_depth_test = false
	_mats[key] = m
	return m


func _fade_ramp(color: Color) -> GradientTexture1D:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	g.add_point(0.6, Color(color.r * 0.6 + 0.4, color.g * 0.6 + 0.2, color.b * 0.6, 0.8))
	var t := GradientTexture1D.new()
	t.gradient = g
	return t


# ---------------------------------------------------------------- particules
## Jet de particules lumineuses (étincelles, flammes, poussière).
func sparks(pos: Vector3, dir: Vector3, color: Color, count := 16, speed := 9.0, life := 0.5, size := 0.12, spread := 60.0, gravity := -14.0) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = count
	p.lifetime = life
	p.one_shot = true
	p.explosiveness = 0.95
	p.emitting = true
	var mat := ParticleProcessMaterial.new()
	mat.direction = dir
	mat.spread = spread
	mat.initial_velocity_min = speed * 0.4
	mat.initial_velocity_max = speed
	mat.gravity = Vector3(0, gravity, 0)
	mat.damping_min = 2.0
	mat.damping_max = 5.0
	mat.scale_min = 0.5
	mat.scale_max = 1.4
	mat.color = color
	mat.color_ramp = _fade_ramp(color)
	p.process_material = mat
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	q.material = _spark_mat(color)
	p.draw_pass_1 = q
	root().add_child(p)
	p.global_position = pos
	_free_later(p, life * 1.6)
	return p


## Débris solides qui retombent (cubes).
func debris(pos: Vector3, color: Color, count := 10, speed := 9.0) -> void:
	var p := GPUParticles3D.new()
	p.amount = count
	p.lifetime = 1.6
	p.one_shot = true
	p.explosiveness = 1.0
	p.emitting = true
	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3.UP
	mat.spread = 70.0
	mat.initial_velocity_min = speed * 0.4
	mat.initial_velocity_max = speed
	mat.gravity = Vector3(0, -18.0, 0)
	mat.scale_min = 0.5
	mat.scale_max = 1.3
	mat.angular_velocity_min = -300.0
	mat.angular_velocity_max = 300.0
	p.process_material = mat
	var b := BoxMesh.new()
	b.size = Vector3(0.22, 0.22, 0.22)
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.metallic = 0.6
	m.roughness = 0.5
	b.material = m
	p.draw_pass_1 = b
	root().add_child(p)
	p.global_position = pos
	_free_later(p, 2.0)


## Lumière brève.
func flash(pos: Vector3, color: Color, energy := 4.0, range_m := 8.0, dur := 0.25) -> void:
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = energy
	light.omni_range = range_m
	root().add_child(light)
	light.global_position = pos
	var tw := light.create_tween()
	tw.tween_property(light, "light_energy", 0.0, dur)
	tw.tween_callback(light.queue_free)


## Sphère lumineuse qui enfle puis disparaît.
func sphere(center: Vector3, radius: float, color: Color, dur := 0.4) -> void:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 1.0
	sm.height = 2.0
	mi.mesh = sm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.disable_fog = true
	m.albedo_color = color
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = m
	root().add_child(mi)
	mi.global_position = center
	mi.scale = Vector3.ONE * 0.2
	var tw := mi.create_tween()
	tw.set_parallel(true)
	tw.tween_property(mi, "scale", Vector3.ONE * radius, dur).set_ease(Tween.EASE_OUT)
	tw.tween_property(mi, "material_override:albedo_color:a", 0.0, dur)
	tw.chain().tween_callback(mi.queue_free)


## Anneau de choc à plat (onde au sol) ou vertical (normal donnée).
func ring(center: Vector3, radius: float, color: Color, dur := 0.45, normal := Vector3.UP, thickness := 0.25) -> void:
	var mi := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 1.0 - thickness
	tm.outer_radius = 1.0
	tm.rings = 32
	mi.mesh = tm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.disable_fog = true
	m.albedo_color = color
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = m
	root().add_child(mi)
	mi.global_position = center
	if normal.normalized().dot(Vector3.UP) < 0.99:
		mi.look_at(center + normal, Vector3.UP)
		mi.rotate_object_local(Vector3.RIGHT, PI / 2.0)
	mi.scale = Vector3.ONE * 0.3
	var tw := mi.create_tween()
	tw.set_parallel(true)
	tw.tween_property(mi, "scale", Vector3.ONE * radius, dur).set_ease(Tween.EASE_OUT)
	tw.tween_property(mi, "material_override:albedo_color:a", 0.0, dur)
	tw.chain().tween_callback(mi.queue_free)


func _free_later(n: Node, seconds: float) -> void:
	get_tree().create_timer(seconds).timeout.connect(func(): if is_instance_valid(n): n.queue_free())


# ================================================================ effets « réalistes »
# Textures générées par tools/gen_fx.py (fumée et feu en planches 8x8, éclairs de bouche, traces).
const FX_DIR := "res://assets/fx/"
const SFX_DIR := "res://assets/sfx/"
const MAX_MARKS := 70
const MAX_VOICES := 40
var _tex := {}
var _sounds := {}
var _marks: Array[Node3D] = []
var _voices := 0
var _cross: ArrayMesh
var _cross_u: ArrayMesh


func tex(name: String) -> Texture2D:
	if not _tex.has(name):
		_tex[name] = load(FX_DIR + name + ".png")
	return _tex[name]


## Matériau de particules en planche animée 8x8 : fumée (mélange alpha, éclairée) ou feu (additif).
func _flip_mat(name: String, additive: bool) -> StandardMaterial3D:
	var key := "flip_%s_%s" % [name, additive]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED if additive else BaseMaterial3D.SHADING_MODE_PER_VERTEX
	if additive:
		# Feu : couleurs prémultipliées (cache le fond comme une vraie flamme), dessiné par-dessus la fumée
		m.blend_mode = BaseMaterial3D.BLEND_MODE_PREMULT_ALPHA
		m.disable_fog = true
		m.render_priority = 1
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.particles_anim_h_frames = 8
	m.particles_anim_v_frames = 8
	m.particles_anim_loop = false
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = tex(name)
	m.disable_receive_shadows = true
	_mats[key] = m
	return m


## Deux quads croisés le long de Y : balles traçantes (texture le long de V) et flammes vues de côté
## (texture le long de U : le départ de la flamme en bas, la pointe en haut).
func _cross_mesh(u_along_y := false) -> ArrayMesh:
	if not u_along_y and _cross:
		return _cross
	if u_along_y and _cross_u:
		return _cross_u
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in 2:
		var side := Vector3(0.5, 0, 0) if k == 0 else Vector3(0, 0, 0.5)
		var v := [-side + Vector3(0, -0.5, 0), side + Vector3(0, -0.5, 0), side + Vector3(0, 0.5, 0), -side + Vector3(0, 0.5, 0)]
		var uv := [Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)]
		if u_along_y:
			uv = [Vector2(0, 0), Vector2(0, 1), Vector2(1, 1), Vector2(1, 0)]
		for i in [0, 1, 2, 0, 2, 3]:
			st.set_uv(uv[i])
			st.add_vertex(v[i])
	var mesh := st.commit()
	if u_along_y:
		_cross_u = mesh
	else:
		_cross = mesh
	return mesh


func _streak_mat(color: Color) -> StandardMaterial3D:
	var key := "streak_" + color.to_html()
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.disable_fog = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.vertex_color_use_as_albedo = true
	m.albedo_color = color
	m.albedo_texture = tex("streak")
	_mats[key] = m
	return m


func _curve(a: float, b: float) -> CurveTexture:
	var c := Curve.new()
	c.max_value = maxf(1.0, maxf(a, b))
	c.add_point(Vector2(0, a), 0, 0)
	c.add_point(Vector2(1, b), 0, 0)
	var t := CurveTexture.new()
	t.curve = c
	return t


func _emit(pos: Vector3, p: GPUParticles3D, life: float, extent := 8.0) -> GPUParticles3D:
	p.lifetime = life
	p.one_shot = true
	p.emitting = true
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.visibility_aabb = AABB(Vector3.ONE * -extent, Vector3.ONE * extent * 2.0)
	root().add_child(p)
	p.global_position = pos
	_free_later(p, life * 1.3 + 0.2)
	return p


## Fumée en volutes : grossit, monte, se dissipe. color.a règle l'opacité.
func smoke(pos: Vector3, count := 6, size := 1.0, life := 2.0, color := Color(0.5, 0.48, 0.46, 0.7), rise := 1.0, radius := 0.3, speed := 1.0, dir := Vector3.UP, spread := 180.0) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = maxi(1, count)
	p.explosiveness = 0.9
	p.randomness = 0.5
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = maxf(radius, 0.01)
	pm.direction = dir
	pm.spread = spread
	pm.initial_velocity_min = speed * 0.4
	pm.initial_velocity_max = speed
	pm.gravity = Vector3(0, rise, 0)
	pm.damping_min = speed * 0.6
	pm.damping_max = speed * 1.2
	pm.angle_min = -180.0
	pm.angle_max = 180.0
	pm.angular_velocity_min = -25.0
	pm.angular_velocity_max = 25.0
	pm.scale_min = 0.7
	pm.scale_max = 1.3
	pm.scale_curve = _curve(0.45, 1.6)
	pm.anim_speed_min = 1.0
	pm.anim_speed_max = 1.0
	pm.anim_offset_max = 0.1
	pm.color = color
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	q.material = _flip_mat("smoke_sheet", false)
	p.draw_pass_1 = q
	return _emit(pos, p, life, maxf(8.0, size * 3.0 + rise * life))


## Boule de feu en volutes (additive) : le cœur d'une explosion.
func fireball(pos: Vector3, radius := 2.0, count := 10, life := 0.8, tint := Color(1, 1, 1)) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = maxi(1, count)
	p.explosiveness = 0.95
	p.randomness = 0.4
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = radius * 0.3
	pm.direction = Vector3.UP
	pm.spread = 180.0
	pm.initial_velocity_min = radius * 1.0
	pm.initial_velocity_max = radius * 2.6
	pm.damping_min = radius * 2.5
	pm.damping_max = radius * 4.0
	pm.gravity = Vector3(0, radius * 0.8, 0)
	pm.angle_min = -180.0
	pm.angle_max = 180.0
	pm.angular_velocity_min = -60.0
	pm.angular_velocity_max = 60.0
	pm.scale_min = 0.7
	pm.scale_max = 1.2
	pm.scale_curve = _curve(0.5, 1.25)
	pm.anim_speed_min = 1.0
	pm.anim_speed_max = 1.0
	pm.color = tint
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2.ONE * radius * 1.3
	q.material = _flip_mat("fire_sheet", true)
	p.draw_pass_1 = q
	return _emit(pos, p, life, radius * 3.0)


## Étincelles étirées dans le sens de leur vitesse (vraies gerbes, pas des points).
func streaks(pos: Vector3, dir: Vector3, color: Color, count := 12, speed := 14.0, life := 0.35, length := 0.35, spread := 50.0, gravity := -12.0, width := 0.035) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = maxi(1, count)
	p.explosiveness = 1.0
	p.randomness = 0.5
	p.transform_align = GPUParticles3D.TRANSFORM_ALIGN_Z_BILLBOARD_Y_TO_VELOCITY
	var pm := ParticleProcessMaterial.new()
	pm.direction = dir.normalized()
	pm.spread = spread
	pm.initial_velocity_min = speed * 0.35
	pm.initial_velocity_max = speed
	pm.gravity = Vector3(0, gravity, 0)
	pm.damping_min = 1.0
	pm.damping_max = 3.0
	pm.scale_min = 0.5
	pm.scale_max = 1.2
	pm.color = color
	pm.color_ramp = _fade_ramp(color)
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(width, length)
	q.material = _streak_mat(Color(1, 1, 1))
	p.draw_pass_1 = q
	return _emit(pos, p, life, 10.0)


## Éclats solides (cailloux, terre, métal) qui retombent en tournant.
## ice = éclats de glace : prismes longs, translucides et brillants (au lieu de petits cailloux).
func chips(pos: Vector3, normal: Vector3, color: Color, count := 6, speed := 6.0, size := 0.05, life := 1.0, ice := false) -> void:
	var p := GPUParticles3D.new()
	p.amount = maxi(1, count)
	p.explosiveness = 1.0
	var pm := ParticleProcessMaterial.new()
	pm.direction = normal
	pm.spread = 55.0
	pm.initial_velocity_min = speed * 0.4
	pm.initial_velocity_max = speed
	pm.gravity = Vector3(0, -16.0, 0)
	pm.scale_min = 0.4
	pm.scale_max = 1.4
	pm.angular_velocity_min = -500.0
	pm.angular_velocity_max = 500.0
	pm.angle_min = -180.0
	pm.angle_max = 180.0
	p.process_material = pm
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.9
	if ice:
		var pr := PrismMesh.new()
		pr.size = Vector3(size * 0.7, size * 2.6, size * 0.7)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_color = Color(color.r, color.g, color.b, 0.8)
		m.roughness = 0.05
		m.metallic = 0.3
		m.emission_enabled = true
		m.emission = color * 0.6
		m.rim_enabled = true
		pr.material = m
		p.draw_pass_1 = pr
	else:
		var b := BoxMesh.new()
		b.size = Vector3(size, size * 0.7, size * 1.2)
		b.material = m
		p.draw_pass_1 = b
	_emit(pos, p, life, 6.0)


## Trace qui reste sur une surface (trou de balle, brûlure). Les plus anciennes disparaissent.
func mark(pos: Vector3, normal: Vector3, tex_name: String, size := 0.25, tint := Color(1, 1, 1), stay := 12.0) -> void:
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	mi.mesh = q
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_texture = tex(tex_name)
	m.albedo_color = tint
	m.roughness = 1.0
	m.disable_receive_shadows = false
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root().add_child(mi)
	var n := normal.normalized()
	mi.global_position = pos + n * 0.015
	var ref := Vector3.UP if absf(n.y) < 0.95 else Vector3.FORWARD
	mi.look_at(mi.global_position - n, ref)
	mi.rotate_object_local(Vector3.FORWARD, randf() * TAU)
	_marks.append(mi)
	while _marks.size() > MAX_MARKS:
		var old: Node3D = _marks.pop_front()
		if is_instance_valid(old):
			old.queue_free()
	var tw := mi.create_tween()
	tw.tween_interval(stay)
	tw.tween_property(m, "albedo_color:a", 0.0, 2.0)
	tw.tween_callback(func():
		_marks.erase(mi)
		mi.queue_free())


## Onde de choc : anneau qui file vers l'extérieur, face caméra.
func shockwave(center: Vector3, radius: float, color := Color(1, 0.95, 0.85, 0.55), dur := 0.28) -> void:
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(2, 2)
	mi.mesh = q
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.disable_fog = true
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.billboard_keep_scale = true
	m.albedo_texture = tex("shock")
	m.albedo_color = color
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root().add_child(mi)
	mi.global_position = center
	mi.scale = Vector3.ONE * radius * 0.2
	var tw := mi.create_tween()
	tw.set_parallel(true)
	tw.tween_property(mi, "scale", Vector3.ONE * radius * 1.3, dur).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(m, "albedo_color:a", 0.0, dur)
	tw.chain().tween_callback(mi.queue_free)


## Matière touchée : métal (cibles, ennemis), terre (sol), pierre (le reste).
func surface_of(collider: Object) -> String:
	if collider == null:
		return "stone"
	if collider.has_method("take_damage"):
		return "metal"
	if collider is Node and (String(collider.name).contains("Terrain") or String(collider.name).contains("Ground")):
		return "dirt"
	return "stone"


## Impact de balle selon la surface : gerbe, poussière, éclats, trou, son.
func impact(pos: Vector3, normal: Vector3, surface := "stone", heavy := false) -> void:
	var k := 1.8 if heavy else 1.0
	match surface:
		"metal":
			streaks(pos, normal, Color(1.0, 0.75, 0.4), int(14 * k), 16.0, 0.3, 0.3 * k, 65.0, -14.0)
			streaks(pos, normal, Color(1.0, 0.95, 0.8), int(5 * k), 7.0, 0.12, 0.18, 80.0, 0.0, 0.06)
			flash(pos + normal * 0.2, Color(1.0, 0.75, 0.45), 2.5 * k, 3.0, 0.08)
			smoke(pos, 2, 0.5 * k, 0.8, Color(0.35, 0.33, 0.32, 0.45), 0.6, 0.05, 1.5, normal, 30.0)
			sound("hit_metal", pos, -6.0, 0.15, 8.0)
			if randf() < 0.3:
				sound("ricochet", pos, -10.0, 0.2, 8.0)
		"dirt":
			smoke(pos, 3, 0.7 * k, 1.4, Color(0.52, 0.45, 0.36, 0.75), 0.3, 0.05, 2.5, normal, 25.0)
			smoke(pos, 1, 0.35 * k, 0.5, Color(0.45, 0.38, 0.3, 0.9), 0.0, 0.0, 5.0, normal, 10.0)
			chips(pos, normal, Color(0.3, 0.25, 0.2), int(7 * k), 6.0 * k, 0.05)
			mark(pos, normal, "bullet_hole", 0.22 * k, Color(0.8, 0.7, 0.6))
			sound("hit_dirt", pos, -8.0, 0.15, 8.0)
		_:
			smoke(pos, 3, 0.6 * k, 1.2, Color(0.62, 0.62, 0.6, 0.65), 0.3, 0.05, 2.5, normal, 25.0)
			streaks(pos, normal, Color(1.0, 0.8, 0.5), int(5 * k), 10.0, 0.18, 0.2, 60.0, -10.0)
			chips(pos, normal, Color(0.5, 0.5, 0.48), int(6 * k), 7.0 * k, 0.045)
			mark(pos, normal, "bullet_hole", 0.2 * k)
			sound("hit_dirt", pos, -9.0, 0.2, 8.0)
			if randf() < 0.25:
				sound("ricochet", pos, -12.0, 0.2, 8.0)


## Balle : courte traînée lumineuse qui file à grande vitesse, puis l'impact à l'arrivée.
func bullet(from: Vector3, to: Vector3, color := Color(1.0, 0.8, 0.5), speed := 420.0, width := 0.035, on_arrive := Callable()) -> void:
	var dist := from.distance_to(to)
	if dist < 0.5:
		if on_arrive.is_valid():
			on_arrive.call()
		return
	var mi := MeshInstance3D.new()
	mi.mesh = _cross_mesh()
	mi.material_override = _streak_mat(color)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root().add_child(mi)
	var d := (to - from) / dist
	var length := clampf(dist * 0.25, 0.6, 4.0)
	var ref := Vector3.UP if absf(d.y) < 0.98 else Vector3.RIGHT
	mi.global_transform = Transform3D(Basis.looking_at(d, ref) * Basis(Vector3.RIGHT, -PI / 2.0), from)
	mi.scale = Vector3(width * 2.0, length, width * 2.0)
	var t := maxf(dist / speed, 0.03)
	var tw := mi.create_tween()
	tw.tween_method(func(k: float): mi.global_position = from.lerp(to - d * length * 0.5, k), 0.0, 1.0, t)
	tw.tween_callback(func():
		mi.queue_free()
		if on_arrive.is_valid():
			on_arrive.call())


## Éclair de bouche : étoile de face, flamme de côté, petite fumée, quelques étincelles, lumière.
func muzzle(pos: Vector3, dir: Vector3, color: Color, size := 0.5) -> void:
	var d := dir.normalized()
	var hot := Color(1.0, 0.85, 0.6).lerp(color, 0.25)
	# Étoile de face (une des 4 variantes de la planche)
	var star := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2.ONE * size * 1.1
	star.mesh = q
	var sm := StandardMaterial3D.new()
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	sm.disable_fog = true
	sm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	sm.albedo_texture = tex("muzzle_front")
	sm.uv1_scale = Vector3(0.5, 0.5, 1)
	sm.uv1_offset = Vector3(0.5 * (randi() % 2), 0.5 * (randi() % 2), 0)
	sm.albedo_color = hot
	star.material_override = sm
	star.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root().add_child(star)
	star.global_position = pos + d * size * 0.1
	star.rotate_object_local(Vector3.FORWARD, randf() * TAU)
	# Flamme de côté : deux plans croisés le long du canon
	var side := MeshInstance3D.new()
	side.mesh = _cross_mesh(true)
	var fm := StandardMaterial3D.new()
	fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	fm.disable_fog = true
	fm.cull_mode = BaseMaterial3D.CULL_DISABLED
	fm.albedo_texture = tex("muzzle_side")
	fm.uv1_scale = Vector3(1, 0.5, 1)
	fm.uv1_offset = Vector3(0, 0.5 * (randi() % 2), 0)
	fm.albedo_color = hot
	side.material_override = fm
	side.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root().add_child(side)
	var ref := Vector3.UP if absf(d.y) < 0.98 else Vector3.RIGHT
	var length := size * randf_range(1.6, 2.4)
	side.global_transform = Transform3D(Basis.looking_at(d, ref) * Basis(Vector3.RIGHT, -PI / 2.0), pos + d * length * 0.5)
	side.rotate_object_local(Vector3.UP, randf() * PI)
	side.scale = Vector3(size * 0.55, length, size * 0.55)
	for n in [star, side]:
		var tw: Tween = n.create_tween()
		tw.tween_interval(0.035)
		tw.tween_property(n, "scale", n.scale * 0.4, 0.03)
		tw.tween_callback(n.queue_free)
	flash(pos + d * 0.3, hot, 3.5, 6.0, 0.07)
	smoke(pos + d * 0.15, 2, size * 0.7, 0.7, Color(0.75, 0.73, 0.7, 0.35), 0.5, 0.02, 2.0, d, 20.0)
	streaks(pos, d, hot, 4, 18.0, 0.12, 0.2, 18.0, -2.0, 0.025)


## Explosion : flash, boule de feu en volutes, onde de choc, gerbe d'étincelles, débris,
## colonne de fumée qui monte, poussière au sol, trace de brûlure, son et secousse.
func explosion(center: Vector3, radius: float, color: Color, strength := 1.0) -> void:
	var tint := Color(1, 1, 1).lerp(Color(color.r * 1.3, color.g * 1.3, color.b * 1.3), 0.15)
	flash(center, Color(1.0, 0.7, 0.4).lerp(color, 0.3), 9.0 * strength, radius * 4.0, 0.45)
	sphere(center, radius * 0.45, Color(1.0, 0.95, 0.8, 0.9), 0.12)
	fireball(center, radius * 0.75, int(12 + 6 * strength), 0.8 + 0.25 * strength, tint)
	fireball(center + Vector3(0, radius * 0.25, 0), radius * 0.4, int(5 + 3 * strength), 1.1, Color(1.0, 0.85, 0.7))
	shockwave(center, radius * 1.6, Color(1, 0.95, 0.85, 0.22))
	streaks(center, Vector3.UP, Color(1.0, 0.7, 0.35), int(30 * strength), 22.0, 0.9, 0.5, 180.0, -12.0, 0.05)
	chips(center, Vector3.UP, Color(0.18, 0.16, 0.14), int(10 * strength), 12.0, 0.14, 1.6)
	# La fumée noire arrive quand la boule de feu retombe, et monte en colonne
	get_tree().create_timer(0.18, false).timeout.connect(func():
		smoke(center + Vector3(0, radius * 0.3, 0), int(10 + 8 * strength), radius * 0.95, 3.4, Color(0.24, 0.22, 0.21, 0.6), 2.4, radius * 0.4, radius * 0.9)
		smoke(center + Vector3(0, radius * 0.6, 0), int(4 + 4 * strength), radius * 0.8, 4.0, Color(0.4, 0.38, 0.36, 0.45), 3.2, radius * 0.3, radius * 0.6))
	smoke(center, int(4 + 3 * strength), radius * 0.7, 1.4, Color(0.5, 0.45, 0.4, 0.5), 0.6, radius * 0.25, radius * 2.5)
	# Au sol : poussière soufflée tout autour et trace de brûlure
	var space := root().get_viewport().world_3d.direct_space_state if root() else null
	if space:
		var q := PhysicsRayQueryParameters3D.create(center + Vector3(0, 0.5, 0), center - Vector3(0, radius * 0.8 + 1.0, 0))
		q.collide_with_areas = false
		var hit := space.intersect_ray(q)
		if not hit.is_empty() and not hit["collider"].has_method("take_damage"):
			var g: Vector3 = hit["position"]
			var dust := smoke(g + Vector3(0, 0.3, 0), int(10 * strength), radius * 0.8, 1.8, Color(0.55, 0.5, 0.42, 0.55), 0.3, 0.2, radius * 5.0, Vector3.UP, 90.0)
			var pm: ParticleProcessMaterial = dust.process_material
			pm.direction = Vector3(1, 0.05, 0)
			pm.spread = 180.0
			pm.flatness = 0.92
			mark(g, hit["normal"], "scorch", radius * 1.6, Color(1, 1, 1, 0.9), 25.0)
	sound("explosion" if strength >= 1.1 or radius >= 4.0 else "blast_small", center, -1.0 + 2.0 * strength, 0.12, 25.0)
	shake(0.35 * strength)


# ---------------------------------------------------------------- sons
func _variants(prefix: String) -> Array:
	if _sounds.has(prefix):
		return _sounds[prefix]
	var list: Array = []
	if ResourceLoader.exists(SFX_DIR + prefix + ".wav"):
		list.append(load(SFX_DIR + prefix + ".wav"))
	for i in 4:
		var path := SFX_DIR + "%s_%d.wav" % [prefix, i]
		if ResourceLoader.exists(path):
			list.append(load(path))
	_sounds[prefix] = list
	return list


## Joue un son dans l'espace (variante et hauteur au hasard pour ne jamais entendre deux fois le même tir).
func sound(prefix: String, pos: Vector3, volume_db := 0.0, pitch_var := 0.08, unit := 12.0) -> void:
	if _voices >= MAX_VOICES or root() == null:
		return
	var list := _variants(prefix)
	if list.is_empty():
		return
	var p := AudioStreamPlayer3D.new()
	p.stream = list.pick_random()
	p.volume_db = volume_db
	p.max_db = 6.0
	p.unit_size = unit
	p.max_distance = 500.0
	p.pitch_scale = randf_range(1.0 - pitch_var, 1.0 + pitch_var)
	p.doppler_tracking = AudioStreamPlayer3D.DOPPLER_TRACKING_DISABLED
	root().add_child(p)
	p.global_position = pos
	p.play()
	_voices += 1
	p.finished.connect(func():
		_voices -= 1
		p.queue_free())
