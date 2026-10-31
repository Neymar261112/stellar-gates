extends DecorBase
## Test de décor : la clairière de l'Arche sur Élyra. Terrain sculpté par fonction de hauteur,
## arbres géants, sanctuaire, cascade, bassin, Arche, ambiance (ciel de crépuscule, brume, lueurs).
## Scène autonome : scenes/elyra_clairiere.tscn. Le joueur vole avec le Solaris complet.

signal message(text: String, seconds: float)

const PLATEAU := 0.0
const PIT := -20.0
var def := { "name": "Élyra · clairière de l'Arche", "id": "elyra_test" }

var _n: FastNoiseLite
var _n2: FastNoiseLite
var _t := 0.0
var player: CharacterBody3D


# ---------------------------------------------------------------- hauteur du terrain
func height_at(x: float, z: float) -> float:
	var d := Vector2(x, z).length()
	# Clairière plate au centre, qui monte en cuvette douce
	var h := 0.0
	var base := _n.get_noise_2d(x, z) * 2.2 + _n2.get_noise_2d(x * 3.0, z * 3.0) * 0.5
	var clearing := smoothstep(22.0, 70.0, d)
	h += base * (0.25 + 0.75 * clearing)
	h += clearing * 6.0
	# Falaises : au nord (z < 0) et à l'est, un plateau à +34 m. Ouverture au sud-ouest.
	var ang := atan2(z, x)                    # -PI..PI, nord = -PI/2
	var open_dir := 2.2                       # direction de la vallée qui s'ouvre (sud-ouest)
	var da := absf(wrapf(ang - open_dir, -PI, PI))
	var cliff_r := 78.0 + _n.get_noise_2d(x * 0.7 + 300.0, z * 0.7) * 14.0 + (1.0 - smoothstep(0.0, 1.3, da)) * 90.0
	var wall := smoothstep(cliff_r, cliff_r + 22.0, d)
	h += wall * 34.0
	# Entaille de la cascade dans la falaise nord
	var notch := Vector2(x - 8.0, z + cliff_r - 4.0).length()
	h -= smoothstep(14.0, 4.0, notch) * 10.0 * wall
	# Bassin au pied de la cascade
	var basin := Vector2(x - 8.0, z + 58.0).length()
	h -= smoothstep(26.0, 6.0, basin) * 4.5
	# Collines et montagnes lointaines, au-delà du terrain jouable
	var far := smoothstep(140.0, 320.0, d)
	h += far * (40.0 + (_n.get_noise_2d(x * 0.35 + 900.0, z * 0.35) + 0.6) * 90.0)
	return h


func tile_at(pos: Vector3) -> String:
	if Vector2(pos.x - 8.0, pos.z + 58.0).length() < 16.0 and pos.y < -1.0:
		return "w"
	return "."


func is_walkable(_t: String) -> bool:
	return true


func cell_center(c: Vector2i) -> Vector3:
	return Vector3(c.x, 0, c.y)


func _ready() -> void:
	SIZE = 260.0
	RES = 1.6
	_rng.seed = 42
	_n = FastNoiseLite.new()
	_n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_n.frequency = 0.012
	_n.fractal_octaves = 4
	_n2 = FastNoiseLite.new()
	_n2.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_n2.frequency = 0.05
	_build_environment()
	_build_terrain()
	_build_water()
	_build_arche(Vector3(0, 0, -18))
	_build_sanctuary(Vector3(-46, 0, -30))
	_build_trees()
	_build_undergrowth()
	_build_waterfall()
	_build_atmosphere()
	player = get_node_or_null("Player")
	if player:
		Loadout.set_all(2)
		player.set_world(self, Vector3(6, height_at(6, 40) + 0.5, 40), Vector3(-0.15, 0, -1))


func _process(delta: float) -> void:
	_t += delta
	if _glyph_mat:
		_glyph_mat.set_shader_parameter("time", _t)


# ---------------------------------------------------------------- ambiance
func _build_environment() -> void:
	var env := Environment.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.09, 0.08, 0.22)
	sky_mat.sky_horizon_color = Color(0.85, 0.45, 0.35)
	sky_mat.ground_bottom_color = Color(0.12, 0.2, 0.2)
	sky_mat.ground_horizon_color = Color(0.35, 0.3, 0.3)
	sky_mat.sun_angle_max = 25.0
	sky_mat.sun_curve = 0.12
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_sky_contribution = 0.7
	env.ambient_light_energy = 1.1
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.0
	env.tonemap_white = 6.0
	env.ssao_enabled = true
	env.ssao_intensity = 2.5
	env.glow_enabled = true
	env.glow_intensity = 0.9
	env.glow_bloom = 0.12
	env.glow_hdr_threshold = 0.9
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	env.fog_enabled = true
	env.fog_light_color = Color(0.35, 0.55, 0.6)
	env.fog_density = 0.0045
	env.fog_sky_affect = 0.5
	env.fog_aerial_perspective = 0.6
	env.fog_height = -5.0
	env.fog_height_density = 0.08
	env.volumetric_fog_enabled = true          # pris en compte en Forward+ (PC de cyril), ignoré ailleurs
	env.volumetric_fog_density = 0.035
	env.volumetric_fog_albedo = Color(0.6, 0.85, 0.85)
	env.volumetric_fog_emission = Color(0.02, 0.06, 0.06)
	env.volumetric_fog_length = 120.0
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.15
	env.adjustment_contrast = 1.05
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	# Soleil bas, chaud, rasant à travers les arbres
	var sun := DirectionalLight3D.new()
	sun.light_color = Color(1.0, 0.72, 0.45)
	sun.light_energy = 1.6
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = 220.0
	sun.light_volumetric_fog_energy = 2.0
	sun.rotation_degrees = Vector3(-14.0, -140.0, 0.0)
	add_child(sun)
	# Contre-jour froid venu du ciel
	var fill := DirectionalLight3D.new()
	fill.light_color = Color(0.4, 0.6, 0.8)
	fill.light_energy = 0.35
	fill.rotation_degrees = Vector3(-60.0, 40.0, 0.0)
	add_child(fill)


# ---------------------------------------------------------------- terrain


## Anneau de terrain lointain (collines), sans collision, autour du terrain jouable


# ---------------------------------------------------------------- eau et cascade


func _build_water() -> void:
	var pm := PlaneMesh.new()
	pm.size = Vector2(60, 60)
	pm.subdivide_depth = 20
	pm.subdivide_width = 20
	_mesh(pm, Vector3(8, -1.2, -58), _water_shader())


func _build_waterfall() -> void:
	var cliff_z := -78.0 - 8.0
	var top := Vector3(8, 24.0, cliff_z - 2.0)
	# Rideau d'eau : plan vertical avec un shader qui défile
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode blend_add, cull_disabled, unshaded, depth_draw_never;
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
void fragment() {
	vec2 uv = UV;
	float a = texture(noise_tex, vec2(uv.x * 2.0, uv.y * 0.6 - TIME * 0.55)).r;
	float b = texture(noise_tex, vec2(uv.x * 3.1 + 0.4, uv.y * 0.35 - TIME * 0.8)).r;
	float streak = smoothstep(0.42, 0.75, a * 0.6 + b * 0.5);
	float edge = smoothstep(0.0, 0.18, uv.x) * smoothstep(1.0, 0.82, uv.x);
	float fade = smoothstep(0.0, 0.12, uv.y) * (0.6 + 0.4 * uv.y);
	ALBEDO = vec3(0.75, 0.92, 1.0) * streak * edge * fade * 1.1;
}
"""
	var m := ShaderMaterial.new()
	m.shader = sh
	var n := FastNoiseLite.new()
	n.frequency = 0.05
	n.fractal_octaves = 3
	var tex := NoiseTexture2D.new()
	tex.noise = n
	tex.seamless = true
	tex.width = 256
	tex.height = 256
	m.set_shader_parameter("noise_tex", tex)
	var q := QuadMesh.new()
	q.size = Vector2(7.0, 26.0)
	_mesh(q, Vector3(top.x, 11.5, top.z + 1.5), m)
	_mesh(q, Vector3(top.x + 0.6, 11.0, top.z + 2.4), m, Vector3.ZERO, Vector3(0.8, 1.0, 1.0))
	# Brume au pied
	var p := GPUParticles3D.new()
	p.amount = 160
	p.lifetime = 2.6
	p.position = Vector3(top.x, -0.5, top.z + 4.0)
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(5.0, 0.5, 2.5)
	pm.direction = Vector3(0, 1, 0.4)
	pm.spread = 40.0
	pm.initial_velocity_min = 1.0
	pm.initial_velocity_max = 2.5
	pm.gravity = Vector3(0, 0.3, 0)
	pm.scale_min = 2.5
	pm.scale_max = 5.0
	pm.color = Color(0.8, 0.95, 1.0, 0.18)
	pm.color_ramp = Fx._fade_ramp(Color(0.8, 0.95, 1.0, 0.2))
	p.process_material = pm
	var qm := QuadMesh.new()
	qm.size = Vector2(3, 3)
	qm.material = Fx._spark_mat(Color(0.85, 0.95, 1.0, 0.5))
	p.draw_pass_1 = qm
	add_child(p)
	# Lumière froide de la cascade
	var l := OmniLight3D.new()
	l.light_color = Color(0.6, 0.85, 1.0)
	l.light_energy = 2.0
	l.omni_range = 30.0
	l.position = Vector3(top.x, 6.0, top.z + 8.0)
	add_child(l)


# ---------------------------------------------------------------- l'Arche


# ---------------------------------------------------------------- le sanctuaire
func _build_sanctuary(pos: Vector3) -> void:
	var root := Node3D.new()
	root.position = Vector3(pos.x, height_at(pos.x, pos.z) - 0.6, pos.z)
	root.rotation.y = 0.5
	add_child(root)
	var white := _flat(Color(0.85, 0.84, 0.78), 0.7, 0.05)
	var moss := _flat(Color(0.12, 0.4, 0.3), 0.95, 0.0, TEAL * 0.6, 0.8)
	# Plateforme et dôme à moitié enfoui
	_mesh(_cyl(13.0, 14.0, 1.2), Vector3(0, 0.6, 0), white, Vector3.ZERO, Vector3.ONE, root)
	var dome := _sph(9.0)
	_mesh(dome, Vector3(0, 1.0, 0), white, Vector3.ZERO, Vector3(1.0, 0.75, 1.0), root)
	_mesh(_sph(9.3), Vector3(0.5, 0.2, -0.5), moss, Vector3.ZERO, Vector3(1.0, 0.55, 1.0), root)
	# Colonnes, certaines brisées
	for k in 10:
		var a := k * TAU / 10.0
		var h := 9.0 if k % 3 != 0 else 4.0 + _rng.randf() * 3.0
		var p := Vector3(cos(a) * 12.0, h * 0.5 + 1.2, sin(a) * 12.0)
		_mesh(_cyl(0.6, 0.75, h), p, white, Vector3(0, 0, _rng.randf_range(-0.06, 0.06)), Vector3.ONE, root)
		if k % 3 != 0:
			_mesh(_cyl(1.0, 0.7, 0.7), Vector3(p.x, h + 1.5, p.z), white, Vector3.ZERO, Vector3.ONE, root)
	# Anneau de linteau partiel
	var tm := TorusMesh.new()
	tm.inner_radius = 11.4
	tm.outer_radius = 12.7
	tm.rings = 64
	var lintel := _mesh(tm, Vector3(0, 10.6, 0), white, Vector3(0, 0, 0), Vector3.ONE, root)
	lintel.scale = Vector3(1, 0.6, 1)
	# Racines qui enserrent le dôme : chaînes de cylindres courbés
	var root_mat := _flat(Color(0.2, 0.16, 0.12), 0.95)
	for k in 9:
		var a := k * TAU / 9.0 + 0.3
		var pnt := Vector3(cos(a) * 16.0, 0.3, sin(a) * 16.0)
		var dir := (Vector3(0, 7.0, 0) - pnt).normalized()
		for s in 7:
			var seg_len := 2.4
			var nxt := pnt + dir * seg_len
			var mid := (pnt + nxt) * 0.5
			var mi := _mesh(_cyl(0.45 - s * 0.04, 0.5 - s * 0.04, seg_len), mid, root_mat, Vector3.ZERO, Vector3.ONE, root)
			mi.look_at_from_position(mid, nxt, Vector3.UP)
			mi.rotate_object_local(Vector3.RIGHT, PI / 2.0)
			pnt = nxt
			dir = (dir + Vector3(_rng.randf_range(-0.3, 0.3), -0.25, _rng.randf_range(-0.3, 0.3))).normalized()
	# Lueur dans le sanctuaire
	var l := OmniLight3D.new()
	l.light_color = TEAL
	l.light_energy = 2.5
	l.omni_range = 36.0
	l.position = Vector3(0, 6, 0)
	root.add_child(l)
	for k in 12:
		var a := _rng.randf() * TAU
		var r := _rng.randf_range(3.0, 13.0)
		_mesh(_sph(0.25 + _rng.randf() * 0.3), Vector3(cos(a) * r, 1.4, sin(a) * r), _flat(TEAL, 0.4, 0.0, TEAL, 3.0), Vector3.ZERO, Vector3.ONE, root)


# ---------------------------------------------------------------- arbres
func _leaf_mat(dark := false) -> StandardMaterial3D:
	var m := _flat(Color(0.06, 0.22, 0.2) if dark else Color(0.1, 0.3, 0.26), 0.95)
	m.emission_enabled = true
	m.emission = Color(0.1, 0.5, 0.42)
	m.emission_energy_multiplier = 0.12
	return m


func _giant_tree(pos: Vector3, scale := 1.0) -> void:
	var root := Node3D.new()
	root.position = Vector3(pos.x, height_at(pos.x, pos.z) - 1.0, pos.z)
	root.rotation.y = _rng.randf() * TAU
	root.scale = Vector3.ONE * scale
	add_child(root)
	var bark := _flat(Color(0.5, 0.46, 0.42), 0.9)
	var h := 42.0
	_mesh(_cyl(1.4, 3.2, h), Vector3(0, h * 0.5, 0), bark, Vector3.ZERO, Vector3.ONE, root)
	# Contreforts à la base
	for k in 6:
		var a := k * TAU / 6.0
		var mi := _mesh(_cyl(0.5, 1.4, 9.0), Vector3(cos(a) * 3.4, 2.0, sin(a) * 3.4), bark, Vector3(0, 0, 0), Vector3.ONE, root)
		mi.rotation = Vector3(sin(a) * 0.9, 0, -cos(a) * 0.9)
	# Branches et houppier : grappes de sphères aplaties
	var leaf := _leaf_mat(_rng.randf() < 0.4)
	for k in 7:
		var a := k * TAU / 7.0 + _rng.randf() * 0.5
		var r := _rng.randf_range(4.0, 12.0)
		var y := h - 4.0 + _rng.randf_range(-6.0, 5.0)
		var sz := _rng.randf_range(7.0, 11.0)
		var mi := _mesh(_cyl(0.35, 0.8, r), Vector3(cos(a) * r * 0.5, y - 2.0, sin(a) * r * 0.5), bark, Vector3.ZERO, Vector3.ONE, root)
		mi.rotation = Vector3(sin(a) * 1.35, 0, -cos(a) * 1.35)
		_mesh(_sph(sz), Vector3(cos(a) * r, y, sin(a) * r), leaf, Vector3.ZERO, Vector3(1.0, 0.45, 1.0), root)
	_mesh(_sph(9.0), Vector3(0, h + 2.0, 0), leaf, Vector3.ZERO, Vector3(1.0, 0.5, 1.0), root)
	# Lianes lumineuses qui pendent
	var vine := _flat(Color(0.15, 0.5, 0.4), 0.8, 0.0, TEAL, 1.2)
	for k in 5:
		var a := _rng.randf() * TAU
		var r := _rng.randf_range(5.0, 11.0)
		var ln := _rng.randf_range(6.0, 16.0)
		_mesh(_cyl(0.05, 0.09, ln), Vector3(cos(a) * r, h - 8.0 - ln * 0.5, sin(a) * r), vine, Vector3.ZERO, Vector3.ONE, root)


func _build_trees() -> void:
	# Arbres géants en couronne autour de la clairière, et quelques-uns sur le plateau
	for k in 13:
		var a := k * TAU / 13.0 + 0.2
		if absf(wrapf(a - 2.2, -PI, PI)) < 0.45:   # on laisse l'ouverture de la vallée
			continue
		var r := _rng.randf_range(44.0, 66.0)
		_giant_tree(Vector3(cos(a) * r, 0, sin(a) * r), _rng.randf_range(0.8, 1.25))
	for k in 6:
		var a := _rng.randf_range(-2.6, -0.6)
		var r := _rng.randf_range(100.0, 118.0)
		_giant_tree(Vector3(cos(a) * r, 0, sin(a) * r), _rng.randf_range(0.9, 1.3))
	# Arbres moyens par MultiMesh
	var st := SurfaceTool.new()
	var trunk := _cyl(0.25, 0.6, 9.0)
	st.append_from(trunk, 0, Transform3D(Basis(), Vector3(0, 4.5, 0)))
	var crown := _sph(3.6)
	st.append_from(crown, 0, Transform3D(Basis().scaled(Vector3(1, 0.7, 1)), Vector3(0, 9.5, 0)))
	st.append_from(_sph(2.6), 0, Transform3D(Basis().scaled(Vector3(1, 0.7, 1)), Vector3(1.8, 7.5, 0.6)))
	var mesh := st.commit()
	mesh.surface_set_material(0, _leaf_mat(true))
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	var placed := []
	for k in 300:
		var x := _rng.randf_range(-125.0, 125.0)
		var z := _rng.randf_range(-125.0, 125.0)
		var d := Vector2(x, z).length()
		if d < 40.0 or Vector2(x - 8.0, z + 58.0).length() < 20.0 or Vector2(x + 46, z + 30).length() < 20.0:
			continue
		var h := height_at(x, z)
		if h > 28.0 and d < 100.0:
			continue
		placed.append(Transform3D(Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3.ONE * _rng.randf_range(0.7, 1.6)), Vector3(x, h - 0.3, z)))
	mm.instance_count = placed.size()
	for i in placed.size():
		mm.set_instance_transform(i, placed[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(mmi)


func _build_undergrowth() -> void:
	# Fougères / buissons : grappes de sphères basses
	var st := SurfaceTool.new()
	for k in 4:
		st.append_from(_sph(0.55), 0, Transform3D(Basis().scaled(Vector3(1.0, 0.55, 1.0)), Vector3(cos(k * 1.57) * 0.45, 0.22, sin(k * 1.57) * 0.45)))
	var bush := st.commit()
	bush.surface_set_material(0, _leaf_mat())
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = bush
	var placed := []
	for k in 1100:
		var x := _rng.randf_range(-120.0, 120.0)
		var z := _rng.randf_range(-120.0, 120.0)
		var h := height_at(x, z)
		if h > 30.0 or Vector2(x, z + 18).length() < 12.0 or Vector2(x - 8.0, z + 58.0).length() < 17.0:
			continue
		placed.append(Transform3D(Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3.ONE * _rng.randf_range(0.5, 1.3)), Vector3(x, h, z)))
	mm.instance_count = placed.size()
	for i in placed.size():
		mm.set_instance_transform(i, placed[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	add_child(mmi)
	# Champignons et mousses lumineuses
	var mm2 := MultiMesh.new()
	mm2.transform_format = MultiMesh.TRANSFORM_3D
	mm2.use_colors = true
	var glow := _sph(0.22)
	glow.material = _flat(TEAL, 0.5, 0.0, TEAL, 2.5)
	mm2.mesh = glow
	var placed2 := []
	for k in 320:
		var x := _rng.randf_range(-110.0, 110.0)
		var z := _rng.randf_range(-110.0, 110.0)
		var h := height_at(x, z)
		if h > 30.0:
			continue
		placed2.append(Transform3D(Basis().scaled(Vector3.ONE * _rng.randf_range(0.4, 1.4)), Vector3(x, h + 0.1, z)))
	mm2.instance_count = placed2.size()
	for i in placed2.size():
		mm2.set_instance_transform(i, placed2[i])
		mm2.set_instance_color(i, TEAL if _rng.randf() < 0.75 else Color(0.5, 0.9, 1.0))
	var mmi2 := MultiMeshInstance3D.new()
	mmi2.multimesh = mm2
	add_child(mmi2)


# ---------------------------------------------------------------- spores, rayons, lucioles
func _build_atmosphere() -> void:
	# Spores lumineuses en suspension
	var p := GPUParticles3D.new()
	p.amount = 900
	p.lifetime = 14.0
	p.preprocess = 14.0
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(120, 22, 120)
	pm.direction = Vector3(0.3, 0.2, 0.1)
	pm.spread = 180.0
	pm.initial_velocity_min = 0.2
	pm.initial_velocity_max = 0.7
	pm.gravity = Vector3(0, 0.05, 0)
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 0.6
	pm.turbulence_noise_scale = 4.0
	pm.scale_min = 0.08
	pm.scale_max = 0.3
	pm.color = TEAL
	pm.color_ramp = Fx._fade_ramp(TEAL)
	p.process_material = pm
	p.position = Vector3(0, 20, 0)
	var qm := QuadMesh.new()
	qm.size = Vector2(0.6, 0.6)
	qm.material = Fx._spark_mat(TEAL)
	p.draw_pass_1 = qm
	add_child(p)
	# Lucioles dorées près du sol
	var f := GPUParticles3D.new()
	f.amount = 250
	f.lifetime = 8.0
	f.preprocess = 8.0
	var fm := ParticleProcessMaterial.new()
	fm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	fm.emission_box_extents = Vector3(70, 3, 70)
	fm.spread = 180.0
	fm.initial_velocity_min = 0.3
	fm.initial_velocity_max = 1.0
	fm.gravity = Vector3.ZERO
	fm.turbulence_enabled = true
	fm.turbulence_noise_strength = 1.5
	fm.scale_min = 0.05
	fm.scale_max = 0.12
	fm.color = GOLD
	fm.color_ramp = Fx._fade_ramp(GOLD)
	f.process_material = fm
	f.position = Vector3(0, 3, 0)
	var fq := QuadMesh.new()
	fq.size = Vector2(0.4, 0.4)
	fq.material = Fx._spark_mat(GOLD)
	f.draw_pass_1 = fq
	add_child(f)
	# Rayons de lumière : longs plans additifs alignés sur le soleil
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode blend_add, cull_disabled, unshaded, depth_draw_never;
uniform float strength = 0.1;
void fragment() {
	float x = smoothstep(0.0, 0.4, UV.x) * smoothstep(1.0, 0.6, UV.x);
	float y = smoothstep(0.0, 0.25, UV.y) * smoothstep(1.0, 0.5, UV.y);
	ALBEDO = vec3(1.0, 0.8, 0.55) * x * y * strength;
}
"""
	var m := ShaderMaterial.new()
	m.shader = sh
	for k in 0:   # rayons désactivés : trop durs en plans additifs, à refaire en brume volumétrique
		var q := QuadMesh.new()
		q.size = Vector2(_rng.randf_range(2.0, 5.0), 60.0)
		var x := _rng.randf_range(-70.0, 70.0)
		var z := _rng.randf_range(-70.0, 40.0)
		var mi := _mesh(q, Vector3(x, 30.0, z), m)
		mi.rotation = Vector3(deg_to_rad(-40.0), deg_to_rad(40.0), 0.0)
		mi.scale = Vector3(1, 1, 1)
