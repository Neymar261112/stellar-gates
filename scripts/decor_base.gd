class_name DecorBase
extends Node3D
## Boîte à outils commune aux décors construits par code : matériaux, primitives, terrain par
## fonction de hauteur (maillage + collision + anneau lointain), eau, Arche. Les scènes
## (clairiere.gd, terre.gd) héritent de cette classe et définissent height_at().

const TEAL := Color(0.25, 0.9, 0.75)
const GOLD := Color(1.0, 0.8, 0.4)

var SIZE := 260.0            # côté du terrain jouable (m)
var RES := 1.6               # pas de la grille (m)
var terrain_colors := {}     # surcharge des couleurs du shader de terrain (moss, moss_light, rock, glow, glow_strength, wet)
var _heights: PackedFloat32Array
var _grid := 0
var _rng := RandomNumberGenerator.new()
var _glyph_mat: ShaderMaterial


func height_at(_x: float, _z: float) -> float:
	return 0.0


func _terrain_shader() -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform sampler2D noise_nrm : hint_normal, filter_linear_mipmap, repeat_enable;
uniform vec3 moss_color : source_color = vec3(0.10, 0.30, 0.20);
uniform vec3 moss_light : source_color = vec3(0.30, 0.52, 0.28);
uniform vec3 rock_color : source_color = vec3(0.30, 0.33, 0.40);
uniform vec3 glow_color : source_color = vec3(0.25, 0.95, 0.75);
uniform float glow_radius = 60.0;
uniform float glow_strength = 0.7;
uniform float wet = 0.0;
varying vec3 wpos;
varying vec3 wnrm;
void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}
void fragment() {
	vec3 bw = abs(wnrm); bw /= (bw.x + bw.y + bw.z);
	vec2 uvx = wpos.zy * 0.08; vec2 uvy = wpos.xz * 0.08; vec2 uvz = wpos.xy * 0.08;
	float n = texture(noise_tex, uvx).r * bw.x + texture(noise_tex, uvy).r * bw.y + texture(noise_tex, uvz).r * bw.z;
	float n2 = texture(noise_tex, uvy * 0.17 + 0.3).r;
	float slope = 1.0 - clamp(wnrm.y, 0.0, 1.0);
	float rock = smoothstep(0.28, 0.55, slope + (n - 0.5) * 0.25);
	vec3 moss = mix(moss_color, moss_light, smoothstep(0.35, 0.75, n2) * 0.8 + n * 0.3);
	vec3 col = mix(moss, rock_color * (0.7 + n * 0.6), rock);
	ALBEDO = col;
	ROUGHNESS = mix(mix(0.95, 0.75, rock), 0.3, wet * (1.0 - rock * 0.5));
	SPECULAR = 0.5 + wet * 0.3;
	vec3 nm = texture(noise_nrm, uvy).rgb;
	NORMAL_MAP = nm;
	NORMAL_MAP_DEPTH = 0.8;
	// Veines bioluminescentes dans la mousse, plus fortes près de la clairière
	float d = length(wpos.xz);
	float veins = smoothstep(0.70, 0.80, texture(noise_tex, uvy * 0.9 + 0.5).r) * (1.0 - rock);
	float near = 1.0 - smoothstep(glow_radius * 0.5, glow_radius, d);
	EMISSION = glow_color * veins * (0.3 + 0.7 * near) * glow_strength;
}
"""
	var m := ShaderMaterial.new()
	m.shader = sh
	for k in terrain_colors:
		m.set_shader_parameter(k, terrain_colors[k])
	var n := FastNoiseLite.new()
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.frequency = 0.03
	n.fractal_octaves = 4
	var tex := NoiseTexture2D.new()
	tex.noise = n
	tex.seamless = true
	tex.width = 512
	tex.height = 512
	m.set_shader_parameter("noise_tex", tex)
	var n2 := FastNoiseLite.new()
	n2.noise_type = FastNoiseLite.TYPE_CELLULAR
	n2.frequency = 0.05
	var nrm := NoiseTexture2D.new()
	nrm.noise = n2
	nrm.seamless = true
	nrm.as_normal_map = true
	nrm.bump_strength = 8.0
	nrm.width = 512
	nrm.height = 512
	m.set_shader_parameter("noise_nrm", nrm)
	return m


func _build_terrain() -> void:
	_grid = int(SIZE / RES) + 1
	_heights.resize(_grid * _grid)
	var half := SIZE * 0.5
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for j in _grid:
		for i in _grid:
			var x := -half + i * RES
			var z := -half + j * RES
			var h := height_at(x, z)
			_heights[j * _grid + i] = h
	for j in _grid - 1:
		for i in _grid - 1:
			var p00 := Vector3(-half + i * RES, _heights[j * _grid + i], -half + j * RES)
			var p10 := Vector3(-half + (i + 1) * RES, _heights[j * _grid + i + 1], -half + j * RES)
			var p01 := Vector3(-half + i * RES, _heights[(j + 1) * _grid + i], -half + (j + 1) * RES)
			var p11 := Vector3(-half + (i + 1) * RES, _heights[(j + 1) * _grid + i + 1], -half + (j + 1) * RES)
			st.add_vertex(p00); st.add_vertex(p10); st.add_vertex(p01)
			st.add_vertex(p10); st.add_vertex(p11); st.add_vertex(p01)
	st.generate_normals()
	var mesh := st.commit()
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _terrain_shader()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(mi)
	# Collision par carte de hauteur
	var body := StaticBody3D.new()
	body.name = "Terrain"
	var cs := CollisionShape3D.new()
	var shape := HeightMapShape3D.new()
	shape.map_width = _grid
	shape.map_depth = _grid
	shape.map_data = _heights
	cs.shape = shape
	cs.scale = Vector3(RES, 1.0, RES)
	body.add_child(cs)
	add_child(body)
	_build_far_terrain(mi.material_override)


func _build_far_terrain(mat: Material) -> void:
	var far_size := 1100.0
	var res := 9.0
	var n := int(far_size / res) + 1
	var half := far_size * 0.5
	var inner := SIZE * 0.5 - 1.0
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for j in n - 1:
		for i in n - 1:
			var x0 := -half + i * res
			var z0 := -half + j * res
			var x1 := x0 + res
			var z1 := z0 + res
			if absf(x0) < inner and absf(x1) < inner and absf(z0) < inner and absf(z1) < inner:
				continue
			var p00 := Vector3(x0, height_at(x0, z0) - 0.3, z0)
			var p10 := Vector3(x1, height_at(x1, z0) - 0.3, z0)
			var p01 := Vector3(x0, height_at(x0, z1) - 0.3, z1)
			var p11 := Vector3(x1, height_at(x1, z1) - 0.3, z1)
			st.add_vertex(p00); st.add_vertex(p10); st.add_vertex(p01)
			st.add_vertex(p10); st.add_vertex(p11); st.add_vertex(p01)
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


func _flat(c: Color, rough := 0.8, metal := 0.0, glow := Color(0, 0, 0), energy := 1.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	if glow.r + glow.g + glow.b > 0.0:
		m.emission_enabled = true
		m.emission = glow
		m.emission_energy_multiplier = energy
	return m


func _mesh(mesh: Mesh, pos: Vector3, mat: Material, rot := Vector3.ZERO, scale := Vector3.ONE, parent: Node = self) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	mi.rotation = rot
	mi.scale = scale
	mi.material_override = mat
	parent.add_child(mi)
	return mi


func _cyl(r_top: float, r_bot: float, h: float) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = r_top
	c.bottom_radius = r_bot
	c.height = h
	return c


func _sph(r: float) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	return s


func _water_shader() -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_disabled;
uniform sampler2D nrm1 : hint_normal, filter_linear_mipmap, repeat_enable;
uniform vec3 deep : source_color = vec3(0.02, 0.12, 0.14);
uniform vec3 shallow : source_color = vec3(0.15, 0.55, 0.55);
void fragment() {
	vec2 uv = UV * 14.0;
	vec3 n1 = texture(nrm1, uv + vec2(TIME * 0.02, TIME * 0.015)).rgb;
	vec3 n2 = texture(nrm1, uv * 1.7 - vec2(TIME * 0.017, -TIME * 0.02)).rgb;
	NORMAL_MAP = normalize(n1 + n2 - 1.0) * 0.5 + 0.5;
	NORMAL_MAP_DEPTH = 0.6;
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	ALBEDO = mix(deep, shallow, fres * 0.8);
	ALPHA = 0.82 + fres * 0.15;
	ROUGHNESS = 0.08;
	METALLIC = 0.2;
	SPECULAR = 0.7;
	EMISSION = shallow * 0.08;
}
"""
	var m := ShaderMaterial.new()
	m.shader = sh
	var n := FastNoiseLite.new()
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX
	n.frequency = 0.08
	var nrm := NoiseTexture2D.new()
	nrm.noise = n
	nrm.seamless = true
	nrm.as_normal_map = true
	nrm.bump_strength = 4.0
	nrm.width = 256
	nrm.height = 256
	m.set_shader_parameter("nrm1", nrm)
	return m


func _glyph_shader() -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
uniform float time = 0.0;
uniform vec3 stone : source_color = vec3(0.55, 0.5, 0.42);
uniform vec3 gold : source_color = vec3(1.0, 0.75, 0.3);
void fragment() {
	// bandes de glyphes le long de l'anneau (UV.x = autour), qui pulsent
	float seg = fract(UV.x * 36.0);
	float glyph = step(0.25, seg) * step(seg, 0.7) * step(0.3, fract(UV.y * 3.0)) * step(fract(UV.y * 3.0), 0.75);
	float pulse = 0.55 + 0.45 * sin(time * 1.5 + UV.x * 25.0);
	ALBEDO = stone * (0.8 + 0.2 * sin(UV.x * 200.0));
	ROUGHNESS = 0.6;
	METALLIC = 0.25;
	EMISSION = gold * glyph * pulse * 2.2;
}
"""
	var m := ShaderMaterial.new()
	m.shader = sh
	return m


func _build_arche(pos: Vector3) -> void:
	var root := Node3D.new()
	root.position = pos
	add_child(root)
	var stone := _flat(Color(0.45, 0.42, 0.38), 0.85, 0.1)
	# Socle et marches
	_mesh(_cyl(9.0, 10.0, 0.8), Vector3(0, 0.4, 0), stone, Vector3.ZERO, Vector3.ONE, root)
	_mesh(_cyl(7.2, 8.0, 0.8), Vector3(0, 1.2, 0), stone, Vector3.ZERO, Vector3.ONE, root)
	# L'anneau (12 m de haut) : pierre + anneau de glyphes
	var tm := TorusMesh.new()
	tm.inner_radius = 5.0
	tm.outer_radius = 6.4
	tm.rings = 96
	tm.ring_segments = 24
	_mesh(tm, Vector3(0, 6.9, 0), stone, Vector3(PI / 2.0, 0, 0), Vector3.ONE, root)
	var tg := TorusMesh.new()
	tg.inner_radius = 5.55
	tg.outer_radius = 5.85
	tg.rings = 96
	tg.ring_segments = 12
	_glyph_mat = _glyph_shader()
	_mesh(tg, Vector3(0, 6.9, 0.55), _glyph_mat, Vector3(PI / 2.0, 0, 0), Vector3.ONE, root)
	_mesh(tg, Vector3(0, 6.9, -0.55), _glyph_mat, Vector3(PI / 2.0, 0, 0), Vector3.ONE, root)
	# Deux piliers gardiens
	for sx in [-1.0, 1.0]:
		_mesh(_cyl(0.7, 1.0, 9.0), Vector3(sx * 9.5, 5.3, 0), stone, Vector3.ZERO, Vector3.ONE, root)
		_mesh(_sph(0.5), Vector3(sx * 9.5, 10.2, 0), _flat(GOLD, 0.3, 0.8, GOLD, 2.0), Vector3.ZERO, Vector3.ONE, root)
	# Le miroir d'énergie : disque transparent qui ondule
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode blend_add, cull_disabled, unshaded, depth_draw_never;
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
void fragment() {
	vec2 c = UV - 0.5;
	float r = length(c) * 2.0;
	float n = texture(noise_tex, UV * 2.0 + vec2(TIME * 0.05, -TIME * 0.03)).r;
	float ring = smoothstep(0.75, 0.98, r) * (1.0 - smoothstep(0.98, 1.0, r));
	float body = (1.0 - smoothstep(0.2, 1.0, r)) * (0.18 + 0.25 * n);
	ALBEDO = vec3(1.0, 0.8, 0.45) * (body + ring * 1.6);
}
"""
	var m := ShaderMaterial.new()
	m.shader = sh
	var n := FastNoiseLite.new()
	n.frequency = 0.04
	var tex := NoiseTexture2D.new()
	tex.noise = n
	tex.seamless = true
	tex.width = 256
	tex.height = 256
	m.set_shader_parameter("noise_tex", tex)
	var q := QuadMesh.new()
	q.size = Vector2(10.4, 10.4)
	_mesh(q, Vector3(0, 6.9, 0), m, Vector3.ZERO, Vector3.ONE, root)
	var l := OmniLight3D.new()
	l.light_color = GOLD
	l.light_energy = 4.0
	l.omni_range = 40.0
	l.position = Vector3(0, 7, 0)
	l.light_volumetric_fog_energy = 3.0
	root.add_child(l)
	# Étincelles dorées qui montent
	var p := GPUParticles3D.new()
	p.amount = 120
	p.lifetime = 4.0
	p.position = Vector3(0, 2, 0)
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 5.0
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 20.0
	pm.initial_velocity_min = 0.6
	pm.initial_velocity_max = 1.8
	pm.gravity = Vector3.ZERO
	pm.scale_min = 0.08
	pm.scale_max = 0.2
	pm.color = GOLD
	pm.color_ramp = Fx._fade_ramp(GOLD)
	p.process_material = pm
	var qm := QuadMesh.new()
	qm.size = Vector2(0.5, 0.5)
	qm.material = Fx._spark_mat(GOLD)
	p.draw_pass_1 = qm
	root.add_child(p)
