extends DecorBase
## La Terre, monde semi-ouvert : la vallée minière sous la pluie. Base Horizon creusée dans le
## flanc est, l'Aster posé sur son aire, la mine à ciel ouvert et son chevalement, le lac au sud,
## la première Arche au fond de la vallée (nord) sous ses échafaudages, et l'équipage.
## Scène autonome : scenes/terre.tscn. Le Solaris y est complet pour explorer en vol.

signal message(text: String, seconds: float)

const PLATEAU := 0.0
const PIT := -20.0
const WATER_Y := -2.0
var def := { "name": "Terre · vallée d'Horizon", "id": "terre" }

var _n: FastNoiseLite
var _n2: FastNoiseLite
var _t := 0.0
var player: CharacterBody3D
var _rain: GPUParticles3D
var _beacons: Array = []            # lumières qui clignotent
var npcs: Array = []                # personnages placés (Node3D), pour la vidéo

# Points clés de la carte (x, z)
const BASE := Vector2(52.0, 30.0)        # base Horizon, contre le flanc est
const PAD := Vector2(-20.0, 70.0)        # aire de l'Aster
const PLAZA := Vector2(24.0, 14.0)       # l'esplanade de la base, face à la rampe de l'Aster (personnages)
const MINE := Vector2(-70.0, -50.0)      # fosse à ciel ouvert
const ARCHE := Vector2(0.0, -150.0)      # terrasse de l'Arche au fond de la vallée
const LAKE := Vector2(10.0, 175.0)       # le lac au sud
const SLAB := Vector2(96.0, 92.0)        # dalle de béton de la base (x, z)
const SLAB_TOP := 2.5                    # hauteur du dessus de la dalle


# ---------------------------------------------------------------- hauteur du terrain
func valley_center(z: float) -> float:
	return sin(z * 0.011) * 22.0 + sin(z * 0.031 + 1.3) * 6.0


func height_at(x: float, z: float) -> float:
	var xc := valley_center(z)
	var dx := absf(x - xc)
	var h := _n.get_noise_2d(x, z) * 3.0 + _n2.get_noise_2d(x * 2.0, z * 2.0) * 0.6
	# Flancs de la vallée : plateaux à +55 m de part et d'autre
	var wall := smoothstep(48.0, 125.0, dx)
	h += wall * 55.0 + wall * _n.get_noise_2d(x * 0.6 + 500.0, z * 0.6) * 10.0
	# Fond de vallée : le cirque au nord
	var north := smoothstep(-175.0, -235.0, z)
	h += north * 60.0
	# Replats sculptés
	h = _flatten(h, x, z, ARCHE, 34.0, 10.0, 6.0)
	h = _flatten(h, x, z, BASE, 46.0, 14.0, 2.5)
	h = _flatten(h, x, z, PAD, 40.0, 12.0, 3.0)
	h = _flatten(h, x, z, PLAZA, 30.0, 10.0, 2.3)
	# Sous la dalle de béton de la base : sol plat juste sous le dessus de la dalle (les pieds ne s'y enfoncent plus)
	var out := Vector2(maxf(absf(x - BASE.x) - SLAB.x * 0.5, 0.0), maxf(absf(z - BASE.y) - SLAB.y * 0.5, 0.0)).length()
	h = lerpf(h, SLAB_TOP - 0.02, 1.0 - smoothstep(0.0, 10.0, out))
	# La fosse de la mine : gradins
	var dm := Vector2(x, z).distance_to(MINE)
	if dm < 48.0:
		var depth := (1.0 - smoothstep(10.0, 46.0, dm)) * 16.0
		depth = floorf(depth / 4.0) * 4.0 + smoothstep(0.0, 1.0, fmod(depth, 4.0) / 4.0) * 0.6
		h -= depth
	# Le lac : cuvette sous le niveau de l'eau
	var dl := Vector2(x, z).distance_to(LAKE)
	h -= (1.0 - smoothstep(30.0, 75.0, dl)) * 7.0
	# Collines lointaines au-delà du terrain jouable
	var far := smoothstep(230.0, 420.0, Vector2(x, z).length())
	h += far * (50.0 + (_n.get_noise_2d(x * 0.3 + 900.0, z * 0.3) + 0.6) * 80.0)
	return h


func _flatten(h: float, x: float, z: float, c: Vector2, r: float, edge: float, level: float) -> float:
	var d := Vector2(x, z).distance_to(c)
	var k := 1.0 - smoothstep(r, r + edge, d)
	return lerpf(h, level, k)


func tile_at(pos: Vector3) -> String:
	if Vector2(pos.x, pos.z).distance_to(LAKE) < 60.0 and pos.y < WATER_Y + 0.6:
		return "w"
	return "."


func is_walkable(_t: String) -> bool:
	return true


func cell_center(c: Vector2i) -> Vector3:
	return Vector3(c.x, 0, c.y)


func _ready() -> void:
	SIZE = 480.0
	RES = 2.4
	_rng.seed = 7
	_n = FastNoiseLite.new()
	_n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_n.frequency = 0.014
	_n.fractal_octaves = 4
	_n2 = FastNoiseLite.new()
	_n2.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_n2.frequency = 0.06
	terrain_colors = {
		"moss_color": Color(0.13, 0.22, 0.11), "moss_light": Color(0.30, 0.42, 0.18),
		"rock_color": Color(0.30, 0.30, 0.32), "glow_color": Color(0, 0, 0), "glow_strength": 0.0, "wet": 0.8,
	}
	_build_environment()
	_build_terrain()
	_build_lake()
	_build_road()
	_build_base()
	_build_aster()
	_build_mine()
	_build_arche_site()
	_build_vegetation()
	_build_rain()
	_build_people()
	_build_atelier_door()
	player = get_node_or_null("Player")
	if player:
		Loadout.set_all(2)
		Appearance.unlock_all()
		if Appearance.came_from_atelier:
			Appearance.came_from_atelier = false
			var out := _aster_local(Vector3(25.0, 0, -4.0))
			var away := (_aster_local(Vector3(30.0, 0, -4.0)) - out).normalized()
			player.set_world(self, Vector3(out.x, height_at(out.x, out.z) + 0.5, out.z), away)
		else:
			player.set_world(self, Vector3(PLAZA.x, 3.3, PLAZA.y + 4.0), Vector3(0, 0, -1))


func _process(delta: float) -> void:
	_t += delta
	_door_ready_t -= delta
	if _glyph_mat:
		_glyph_mat.set_shader_parameter("time", _t)
	for b in _beacons:
		var l: OmniLight3D = b[0]
		var phase: float = b[1]
		l.light_energy = 3.0 if fmod(_t + phase, 1.6) < 0.12 else 0.0
		if l.get_child_count() > 0:
			l.get_child(0).visible = l.light_energy > 0.0
	# La pluie suit la caméra
	if _rain:
		var cam := get_viewport().get_camera_3d()
		if cam:
			_rain.global_position = cam.global_position + Vector3(0, 18, 0)


# ---------------------------------------------------------------- ambiance : ciel couvert, pluie
func _build_environment() -> void:
	var env := Environment.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.22, 0.25, 0.31)
	sky_mat.sky_horizon_color = Color(0.58, 0.60, 0.60)
	sky_mat.ground_bottom_color = Color(0.25, 0.27, 0.26)
	sky_mat.ground_horizon_color = Color(0.5, 0.52, 0.5)
	sky_mat.sun_angle_max = 0.0
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_sky_contribution = 0.9
	env.ambient_light_energy = 1.0
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.0
	env.tonemap_white = 5.0
	env.ssao_enabled = true
	env.ssao_intensity = 2.0
	env.glow_enabled = true
	env.glow_intensity = 0.7
	env.glow_bloom = 0.08
	env.glow_hdr_threshold = 1.0
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	env.fog_enabled = true
	env.fog_light_color = Color(0.52, 0.56, 0.58)
	env.fog_density = 0.0038
	env.fog_sky_affect = 0.6
	env.fog_aerial_perspective = 0.5
	env.fog_height = -2.0
	env.fog_height_density = 0.06
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.03
	env.volumetric_fog_albedo = Color(0.7, 0.72, 0.72)
	env.volumetric_fog_length = 160.0
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.05
	env.adjustment_contrast = 1.12
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	# Lumière grise de jour de pluie, ombres douces
	var sun := DirectionalLight3D.new()
	sun.light_color = Color(0.8, 0.85, 0.92)
	sun.light_energy = 0.9
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = 260.0
	sun.shadow_blur = 2.0
	sun.rotation_degrees = Vector3(-48.0, -35.0, 0.0)
	add_child(sun)


func _build_rain() -> void:
	_rain = GPUParticles3D.new()
	_rain.amount = 2600
	_rain.lifetime = 1.4
	_rain.preprocess = 1.4
	_rain.visibility_aabb = AABB(Vector3(-200, -200, -200), Vector3(400, 400, 400))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(45, 2, 45)
	pm.direction = Vector3(0.12, -1, 0.05)
	pm.spread = 2.0
	pm.initial_velocity_min = 22.0
	pm.initial_velocity_max = 28.0
	pm.gravity = Vector3(0, -6, 0)
	pm.scale_min = 1.0
	pm.scale_max = 1.0
	pm.color = Color(0.8, 0.88, 0.95, 0.6)
	_rain.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.04, 0.8)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.vertex_color_use_as_albedo = true
	m.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	m.albedo_color = Color(0.85, 0.9, 1.0, 0.4)
	q.material = m
	_rain.draw_pass_1 = q
	add_child(_rain)
	# Nappe de brume rasante dans le fond de la vallée
	var mist := GPUParticles3D.new()
	mist.amount = 90
	mist.lifetime = 12.0
	mist.preprocess = 12.0
	var mm := ParticleProcessMaterial.new()
	mm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mm.emission_box_extents = Vector3(60, 1.5, 150)
	mm.direction = Vector3(1, 0, 0)
	mm.spread = 30.0
	mm.initial_velocity_min = 0.4
	mm.initial_velocity_max = 1.0
	mm.gravity = Vector3.ZERO
	mm.scale_min = 10.0
	mm.scale_max = 22.0
	mm.color = Color(0.75, 0.8, 0.82, 0.08)
	mm.color_ramp = Fx._fade_ramp(Color(0.75, 0.8, 0.82, 0.09))
	mist.process_material = mm
	mist.position = Vector3(0, 2.5, -20)
	var mq := QuadMesh.new()
	mq.size = Vector2(3, 3)
	mq.material = Fx._spark_mat(Color(0.8, 0.84, 0.86, 0.5))
	mist.draw_pass_1 = mq
	add_child(mist)


# ---------------------------------------------------------------- lac, route
func _build_lake() -> void:
	var pm := PlaneMesh.new()
	pm.size = Vector2(170, 170)
	pm.subdivide_depth = 24
	pm.subdivide_width = 24
	var w := _water_shader()
	w.set_shader_parameter("deep", Color(0.08, 0.11, 0.12))
	w.set_shader_parameter("shallow", Color(0.35, 0.42, 0.44))
	_mesh(pm, Vector3(LAKE.x, WATER_Y, LAKE.y), w)
	# Un ponton et une épave de barge pour la couleur locale
	var wood := _flat(Color(0.32, 0.26, 0.2), 0.9)
	var rust := _flat(Color(0.38, 0.25, 0.18), 0.95, 0.4)
	var px := LAKE.x - 32.0
	var pz := LAKE.y - 38.0
	var b := BoxMesh.new()
	b.size = Vector3(3.0, 0.3, 22.0)
	_mesh(b, Vector3(px, WATER_Y + 0.9, pz + 10.0), wood)
	for k in 4:
		_mesh(_cyl(0.18, 0.18, 4.0), Vector3(px - 1.2, WATER_Y, pz + 2.0 + k * 6.0), wood)
		_mesh(_cyl(0.18, 0.18, 4.0), Vector3(px + 1.2, WATER_Y, pz + 2.0 + k * 6.0), wood)
	var hull := BoxMesh.new()
	hull.size = Vector3(9.0, 3.0, 22.0)
	_mesh(hull, Vector3(LAKE.x + 25.0, WATER_Y - 0.4, LAKE.y + 10.0), rust, Vector3(0.0, 0.6, 0.18))


func _build_road() -> void:
	# Piste sombre qui suit la vallée, de l'Arche au lac, avec des bornes lumineuses
	var asphalt := _flat(Color(0.12, 0.12, 0.13), 0.55, 0.1)
	var post := _flat(Color(0.3, 0.3, 0.32), 0.6, 0.6)
	var amber := _flat(Color(1.0, 0.6, 0.2), 0.4, 0.0, Color(1.0, 0.55, 0.15), 2.5)
	var z := -118.0
	var k := 0
	while z < 150.0:
		var x := valley_center(z) + 6.0
		var h := height_at(x, z)
		var seg := BoxMesh.new()
		seg.size = Vector3(7.0, 0.25, 11.0)
		var dz := valley_center(z + 5.0) - valley_center(z - 5.0)
		var dy := height_at(x, z + 5.0) - height_at(x, z - 5.0)
		_mesh(seg, Vector3(x, h + 0.08, z), asphalt, Vector3(-atan2(dy, 10.0), -atan2(dz, 10.0), 0.0))
		if k % 3 == 0:
			_mesh(_cyl(0.08, 0.1, 1.1), Vector3(x + 4.2, h + 0.55, z), post)
			_mesh(_sph(0.14), Vector3(x + 4.2, h + 1.15, z), amber)
		z += 10.0
		k += 1


# ---------------------------------------------------------------- la base Horizon
func _module(pos: Vector3, size: Vector3, yaw := 0.0, lit := true) -> Node3D:
	var root := Node3D.new()
	root.position = pos
	root.rotation.y = yaw
	add_child(root)
	var shell := _flat(Color(0.78, 0.8, 0.8), 0.6, 0.3)
	var band := _flat(Color(0.12, 0.3, 0.45), 0.5, 0.4)
	var win := _flat(Color(1.0, 0.85, 0.6), 0.3, 0.0, Color(1.0, 0.8, 0.5), 2.0)
	var b := BoxMesh.new()
	b.size = size
	_mesh(b, Vector3(0, size.y * 0.5, 0), shell, Vector3.ZERO, Vector3.ONE, root)
	var bb := BoxMesh.new()
	bb.size = Vector3(size.x + 0.08, 0.5, size.z + 0.08)
	_mesh(bb, Vector3(0, size.y - 0.6, 0), band, Vector3.ZERO, Vector3.ONE, root)
	# Pieds
	var leg := _flat(Color(0.25, 0.25, 0.27), 0.7, 0.5)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_mesh(_cyl(0.2, 0.25, 0.8), Vector3(sx * (size.x * 0.4), -0.3, sz * (size.z * 0.4)), leg, Vector3.ZERO, Vector3.ONE, root)
	if lit:
		var n := int(size.x / 2.5)
		for i in n:
			var wq := BoxMesh.new()
			wq.size = Vector3(1.2, 0.9, 0.06)
			_mesh(wq, Vector3(-size.x * 0.5 + 1.25 + i * 2.5, size.y * 0.6, size.z * 0.5 + 0.02), win, Vector3.ZERO, Vector3.ONE, root)
	return root


func _floodlight(pos: Vector3, yaw: float, energy := 6.0, range_m := 45.0) -> void:
	var mast := _flat(Color(0.3, 0.3, 0.32), 0.6, 0.6)
	_mesh(_cyl(0.12, 0.18, 11.0), pos + Vector3(0, 5.5, 0), mast)
	var head := BoxMesh.new()
	head.size = Vector3(1.6, 0.5, 0.5)
	_mesh(head, pos + Vector3(0, 11.2, 0), mast, Vector3(0, yaw, 0))
	var lamp := BoxMesh.new()
	lamp.size = Vector3(1.4, 0.3, 0.1)
	_mesh(lamp, pos + Vector3(sin(yaw) * 0.3, 11.1, cos(yaw) * 0.3), _flat(Color(1, 0.95, 0.85), 0.3, 0.0, Color(1.0, 0.95, 0.8), 6.0), Vector3(0, yaw, 0))
	var s := SpotLight3D.new()
	s.light_color = Color(1.0, 0.93, 0.8)
	s.light_energy = energy
	s.spot_range = range_m
	s.spot_angle = 40.0
	s.spot_angle_attenuation = 0.7
	s.shadow_enabled = false
	s.light_volumetric_fog_energy = 2.5
	s.position = pos + Vector3(0, 11.0, 0)
	s.rotation = Vector3(deg_to_rad(-38.0), yaw, 0.0)
	add_child(s)


func _beacon(pos: Vector3, color: Color, phase := 0.0) -> void:
	var l := OmniLight3D.new()
	l.light_color = color
	l.omni_range = 14.0
	l.position = pos
	add_child(l)
	_mesh(_sph(0.25), Vector3.ZERO, _flat(color, 0.3, 0.0, color, 4.0), Vector3.ZERO, Vector3.ONE, l)
	_beacons.append([l, phase])


func _container(pos: Vector3, color: Color, yaw := 0.0) -> void:
	var b := BoxMesh.new()
	b.size = Vector3(6.0, 2.6, 2.5)
	_mesh(b, pos + Vector3(0, 1.3, 0), _flat(color, 0.75, 0.3), Vector3(0, yaw, 0))


func _build_base() -> void:
	var cx := BASE.x
	var cz := BASE.y
	var level := 2.5
	# Dalle de béton
	var slab := BoxMesh.new()
	slab.size = Vector3(SLAB.x, 0.4, SLAB.y)
	_mesh(slab, Vector3(cx, SLAB_TOP - 0.2, cz), _flat(Color(0.42, 0.42, 0.43), 0.6, 0.0))
	# la dalle porte le Solaris (avant, elle n'avait pas de collision : on marchait 30 à 50 cm dedans)
	var sb := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(SLAB.x, 0.4, SLAB.y)
	cs.shape = bs
	sb.add_child(cs)
	sb.position = Vector3(cx, SLAB_TOP - 0.2, cz)
	add_child(sb)
	# L'entrée de la galerie minière creusée dans le flanc est : un portail bétonné
	var wall := _flat(Color(0.35, 0.35, 0.36), 0.8, 0.0)
	var gx := cx + 46.0
	var portal := BoxMesh.new()
	portal.size = Vector3(6.0, 18.0, 30.0)
	_mesh(portal, Vector3(gx + 2.0, level + 9.0, cz - 10.0), wall)
	var hole := BoxMesh.new()
	hole.size = Vector3(1.0, 12.0, 16.0)
	_mesh(hole, Vector3(gx - 1.2, level + 6.0, cz - 10.0), _flat(Color(0.02, 0.02, 0.03), 1.0))
	var sign := BoxMesh.new()
	sign.size = Vector3(0.3, 2.2, 18.0)
	_mesh(sign, Vector3(gx - 1.3, level + 14.0, cz - 10.0), _flat(Color(0.95, 0.95, 0.95), 0.5, 0.0, Color(0.9, 0.9, 0.9), 0.8))
	_label("INITIATIVE HORIZON\nSITE 1", Vector3(gx - 1.8, level + 14.0, cz - 10.0), Color(0.1, 0.3, 0.5), 32, -PI / 2.0, false)
	for k in 6:
		_mesh(_sph(0.2), Vector3(gx - 1.5, level + 12.6, cz - 17.0 + k * 2.8), _flat(Color(1, 0.9, 0.7), 0.3, 0.0, Color(1, 0.85, 0.6), 3.0))
	var gl := OmniLight3D.new()
	gl.light_color = Color(1.0, 0.9, 0.75)
	gl.light_energy = 3.0
	gl.omni_range = 30.0
	gl.position = Vector3(gx - 6.0, level + 8.0, cz - 10.0)
	add_child(gl)
	# Le hangar
	var hangar := Node3D.new()
	hangar.position = Vector3(cx + 10.0, level, cz + 26.0)
	add_child(hangar)
	var hm := _flat(Color(0.55, 0.57, 0.6), 0.65, 0.4)
	var roof := BoxMesh.new()
	roof.size = Vector3(30.0, 0.6, 24.0)
	_mesh(roof, Vector3(0, 11.0, 0), hm, Vector3.ZERO, Vector3.ONE, hangar)
	var side := BoxMesh.new()
	side.size = Vector3(0.5, 11.0, 24.0)
	_mesh(side, Vector3(-15.0, 5.5, 0), hm, Vector3.ZERO, Vector3.ONE, hangar)
	_mesh(side, Vector3(15.0, 5.5, 0), hm, Vector3.ZERO, Vector3.ONE, hangar)
	var back := BoxMesh.new()
	back.size = Vector3(30.0, 11.0, 0.5)
	_mesh(back, Vector3(0, 5.5, 12.0), hm, Vector3.ZERO, Vector3.ONE, hangar)
	var lintel := BoxMesh.new()
	lintel.size = Vector3(30.0, 2.0, 0.6)
	_mesh(lintel, Vector3(0, 10.0, -12.0), _flat(Color(0.9, 0.5, 0.1), 0.6, 0.2), Vector3.ZERO, Vector3.ONE, hangar)
	_label("HANGAR 1", Vector3(cx + 10.0, level + 10.0, cz + 26.0 - 12.5), Color(1, 1, 1), 40, PI, false)
	var hl := OmniLight3D.new()
	hl.light_color = Color(1.0, 0.95, 0.85)
	hl.light_energy = 4.0
	hl.omni_range = 34.0
	hl.position = Vector3(0, 8.0, 0)
	hangar.add_child(hl)
	# Modules d'habitation et labos
	_module(Vector3(cx - 28.0, level, cz - 54.0), Vector3(16.0, 4.0, 6.0), 0.0)
	_module(Vector3(cx - 28.0, level, cz - 46.0), Vector3(16.0, 4.0, 6.0), 0.0)
	_module(Vector3(cx - 28.0, level + 4.2, cz - 50.0), Vector3(16.0, 4.0, 6.0), 0.0)
	_module(Vector3(cx + 6.0, level, cz - 40.0), Vector3(22.0, 5.0, 8.0), 0.0)
	_module(Vector3(cx + 24.0, level, cz - 34.0), Vector3(12.0, 4.0, 6.0), 0.3)
	_module(Vector3(cx - 34.0, level, cz + 14.0), Vector3(12.0, 4.0, 6.0), PI / 2.0)
	# Tour de contrôle
	var tower := _flat(Color(0.7, 0.72, 0.74), 0.6, 0.3)
	_mesh(_cyl(2.2, 2.6, 16.0), Vector3(cx + 32.0, level + 8.0, cz + 2.0), tower)
	var cab := BoxMesh.new()
	cab.size = Vector3(8.0, 3.5, 8.0)
	_mesh(cab, Vector3(cx + 32.0, level + 17.5, cz + 2.0), _flat(Color(0.35, 0.55, 0.7), 0.2, 0.6, Color(0.6, 0.8, 1.0), 0.8))
	_mesh(_cyl(0.06, 0.08, 10.0), Vector3(cx + 32.0, level + 24.0, cz + 2.0), tower)
	_beacon(Vector3(cx + 32.0, level + 29.2, cz + 2.0), Color(1.0, 0.15, 0.1), 0.0)
	# Antennes, cuves, conteneurs
	var dish := _cyl(0.2, 3.2, 1.0)
	_mesh(dish, Vector3(cx - 40.0, level + 7.0, cz - 10.0), tower, Vector3(deg_to_rad(-50.0), 0.4, 0))
	_mesh(_cyl(0.15, 0.15, 7.0), Vector3(cx - 40.0, level + 3.5, cz - 10.0), tower)
	for k in 3:
		_mesh(_cyl(2.0, 2.0, 5.0), Vector3(cx + 30.0 + k * 5.0, level + 2.5, cz - 26.0), _flat(Color(0.8, 0.8, 0.78), 0.5, 0.5))
	var cols := [Color(0.75, 0.2, 0.15), Color(0.2, 0.35, 0.6), Color(0.85, 0.55, 0.1), Color(0.3, 0.5, 0.3), Color(0.6, 0.6, 0.62)]
	for k in 9:
		var px := cx - 20.0 + (k % 5) * 6.5
		var pz := cz + 40.0 - int(k / 5) * 3.0
		_container(Vector3(px, level + 0.2 + (2.6 if k >= 5 else 0.0), pz), cols[k % 5], 0.0)
	# Projecteurs et balises
	_floodlight(Vector3(cx - 46.0, level, cz - 44.0), 0.8)
	_floodlight(Vector3(cx + 44.0, level, cz + 44.0), -2.4)
	_floodlight(Vector3(cx - 46.0, level, cz + 44.0), 2.4)
	_floodlight(Vector3(PLAZA.x - 26.0, 2.8, PLAZA.y - 22.0), 0.9, 7.0, 50.0)
	_floodlight(Vector3(PLAZA.x + 4.0, 2.8, PLAZA.y + 26.0), -2.9, 7.0, 50.0)
	# Véhicules de chantier garés
	for k in 3:
		_truck(Vector3(cx - 10.0 + k * 9.0, level + 0.2, cz + 8.0), 0.2 * k, Color(0.85, 0.6, 0.1))


func _truck(pos: Vector3, yaw: float, color: Color) -> void:
	var root := Node3D.new()
	root.position = pos
	root.rotation.y = yaw
	add_child(root)
	var body := _flat(color, 0.7, 0.3)
	var dark := _flat(Color(0.1, 0.1, 0.1), 0.9)
	var bed := BoxMesh.new()
	bed.size = Vector3(3.0, 1.6, 6.5)
	_mesh(bed, Vector3(0, 1.6, 0.8), body, Vector3.ZERO, Vector3.ONE, root)
	var cab := BoxMesh.new()
	cab.size = Vector3(2.8, 2.2, 2.2)
	_mesh(cab, Vector3(0, 2.2, -3.0), body, Vector3.ZERO, Vector3.ONE, root)
	for sx in [-1.3, 1.3]:
		for z in [-2.6, 0.2, 2.2]:
			_mesh(_cyl(0.7, 0.7, 0.6), Vector3(sx, 0.7, z), dark, Vector3(0, 0, PI / 2.0), Vector3.ONE, root)


# ---------------------------------------------------------------- l'Atelier (dans l'Aster)
var _door_ready_t := 1.5


## Point du repère de l'Aster (posé en PAD, tourné de -0.35) exprimé dans le monde.
func _aster_local(p: Vector3) -> Vector3:
	return Vector3(PAD.x, 0, PAD.y) + p.rotated(Vector3.UP, -0.35)


## Au pied de la rampe : on y marche pour entrer dans l'Atelier (la Forge).
func _build_atelier_door() -> void:
	var p := _aster_local(Vector3(16.5, 0, -4.0))
	p.y = height_at(p.x, p.z)
	var area := Area3D.new()
	area.position = p
	var cs := CollisionShape3D.new()
	var sh := CylinderShape3D.new()
	sh.radius = 2.2
	sh.height = 4.0
	cs.shape = sh
	cs.position.y = 1.5
	area.add_child(cs)
	add_child(area)
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 2.0
	tm.outer_radius = 2.15
	ring.mesh = tm
	var rm := StandardMaterial3D.new()
	rm.albedo_color = Color(1.0, 0.8, 0.4)
	rm.emission_enabled = true
	rm.emission = Color(1.0, 0.8, 0.4)
	rm.emission_energy_multiplier = 2.5
	ring.material_override = rm
	ring.position.y = 0.15
	area.add_child(ring)
	var l := Label3D.new()
	l.text = "ATELIER\nmarche ici pour entrer dans la Forge"
	l.font_size = 48
	l.pixel_size = 0.005
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.modulate = Color(1.0, 0.85, 0.5)
	l.outline_size = 12
	l.position.y = 3.4
	area.add_child(l)
	area.body_entered.connect(_on_atelier_door)


func _on_atelier_door(body: Node3D) -> void:
	if not body.is_in_group("player") or _door_ready_t > 0.0:
		return
	_door_ready_t = 999.0
	Appearance.return_to = "res://scenes/terre.tscn"
	get_tree().change_scene_to_file.call_deferred("res://scenes/atelier.tscn")


# ---------------------------------------------------------------- l'Aster
func _build_aster() -> void:
	var root := Node3D.new()
	root.position = Vector3(PAD.x, 3.0, PAD.y)
	root.rotation.y = -0.35
	add_child(root)
	var pad := _cyl(38.0, 38.0, 0.5)
	_mesh(pad, Vector3(0, 0.15, 0), _flat(Color(0.36, 0.37, 0.38), 0.6, 0.0), Vector3.ZERO, Vector3.ONE, root)
	var ring := TorusMesh.new()
	ring.inner_radius = 33.0
	ring.outer_radius = 34.0
	_mesh(ring, Vector3(0, 0.42, 0), _flat(Color(1.0, 0.7, 0.2), 0.5, 0.0, Color(1.0, 0.6, 0.15), 1.2), Vector3.ZERO, Vector3.ONE, root)
	var hull := _flat(Color(0.72, 0.74, 0.76), 0.45, 0.7)
	var dark := _flat(Color(0.18, 0.2, 0.24), 0.6, 0.6)
	var stripe := _flat(Color(0.85, 0.35, 0.1), 0.5, 0.4)
	var win := _flat(Color(1.0, 0.85, 0.6), 0.2, 0.0, Color(1.0, 0.8, 0.5), 2.5)
	var ship := Node3D.new()
	ship.position = Vector3(0, 7.0, 0)
	root.add_child(ship)
	# Fuselage principal (48 m), nez vers -Z
	var fus := CapsuleMesh.new()
	fus.radius = 5.0
	fus.height = 44.0
	_mesh(fus, Vector3(0, 0, 0), hull, Vector3(PI / 2.0, 0, 0), Vector3(1.3, 1.0, 1.0), ship)
	var belly := BoxMesh.new()
	belly.size = Vector3(10.0, 4.0, 30.0)
	_mesh(belly, Vector3(0, -3.0, 2.0), dark, Vector3.ZERO, Vector3.ONE, ship)
	# Bandes de coque et aileron dorsal
	for zb in [-16.0, -4.0, 8.0, 16.0]:
		var band := TorusMesh.new()
		band.inner_radius = 5.1
		band.outer_radius = 5.5
		_mesh(band, Vector3(0, 0, zb), dark, Vector3(PI / 2.0, 0, 0), Vector3(1.3, 1.0, 1.0), ship)
	var fin := BoxMesh.new()
	fin.size = Vector3(0.6, 6.0, 10.0)
	_mesh(fin, Vector3(0, 6.5, 14.0), hull, Vector3(-0.35, 0, 0), Vector3.ONE, ship)
	var fs := BoxMesh.new()
	fs.size = Vector3(0.7, 1.2, 9.0)
	_mesh(fs, Vector3(0, 7.2, 14.0), stripe, Vector3(-0.35, 0, 0), Vector3.ONE, ship)
	_mesh(_cyl(0.06, 0.1, 6.0), Vector3(2.0, 8.0, -4.0), dark, Vector3.ZERO, Vector3.ONE, ship)
	# Passerelle (pont) dessus
	var bridge := BoxMesh.new()
	bridge.size = Vector3(7.0, 3.0, 9.0)
	_mesh(bridge, Vector3(0, 5.0, -8.0), hull, Vector3.ZERO, Vector3.ONE, ship)
	var bw := BoxMesh.new()
	bw.size = Vector3(6.0, 1.2, 0.2)
	_mesh(bw, Vector3(0, 5.4, -12.6), win, Vector3.ZERO, Vector3.ONE, ship)
	# Ailes courtes et nacelles
	for sx in [-1.0, 1.0]:
		var wing := BoxMesh.new()
		wing.size = Vector3(14.0, 0.9, 12.0)
		_mesh(wing, Vector3(sx * 11.0, -1.0, 6.0), hull, Vector3(0, 0, sx * -0.08), Vector3.ONE, ship)
		var ws := BoxMesh.new()
		ws.size = Vector3(14.2, 0.3, 1.5)
		_mesh(ws, Vector3(sx * 11.0, -0.4, 2.0), stripe, Vector3(0, 0, sx * -0.08), Vector3.ONE, ship)
		var nac := CapsuleMesh.new()
		nac.radius = 2.4
		nac.height = 18.0
		_mesh(nac, Vector3(sx * 18.0, -1.0, 7.0), dark, Vector3(PI / 2.0, 0, 0), Vector3.ONE, ship)
		_mesh(_cyl(1.6, 2.0, 1.0), Vector3(sx * 18.0, -1.0, 16.4), _flat(Color(0.3, 0.6, 1.0), 0.3, 0.0, Color(0.3, 0.6, 1.0), 2.0), Vector3(PI / 2.0, 0, 0), Vector3.ONE, ship)
		# Hublots
		for k in 7:
			_mesh(_sph(0.35), Vector3(sx * 6.3, 0.8, -14.0 + k * 4.0), win, Vector3.ZERO, Vector3.ONE, ship)
	# Pieds d'atterrissage
	for p in [Vector3(-7.0, 0, -12.0), Vector3(7.0, 0, -12.0), Vector3(-9.0, 0, 12.0), Vector3(9.0, 0, 12.0)]:
		_mesh(_cyl(0.5, 0.7, 5.5), Vector3(p.x, -3.0, p.z), dark, Vector3.ZERO, Vector3.ONE, ship)
		_mesh(_cyl(1.6, 1.8, 0.5), Vector3(p.x, -6.6, p.z), dark, Vector3.ZERO, Vector3.ONE, ship)
	# La rampe ouverte sur l'esplanade (côté +X après rotation)
	var ramp := BoxMesh.new()
	ramp.size = Vector3(5.0, 0.4, 16.0)
	_mesh(ramp, Vector3(8.5, 3.2, -4.0), hull, Vector3(0, PI / 2.0, 0.42), Vector3.ONE, root)
	var door := BoxMesh.new()
	door.size = Vector3(0.6, 4.5, 5.0)
	_mesh(door, Vector3(4.6, 7.2, -4.0), _flat(Color(1.0, 0.8, 0.5), 0.3, 0.0, Color(1.0, 0.75, 0.45), 2.2), Vector3.ZERO, Vector3.ONE, root)
	var dl := OmniLight3D.new()
	dl.light_color = Color(1.0, 0.85, 0.6)
	dl.light_energy = 4.0
	dl.omni_range = 26.0
	dl.position = Vector3(8.0, 6.0, -4.0)
	root.add_child(dl)
	# Lueur sous la coque et feux de position
	var ul := OmniLight3D.new()
	ul.light_color = Color(0.4, 0.7, 1.0)
	ul.light_energy = 3.0
	ul.omni_range = 40.0
	ul.position = Vector3(0, 3.0, 0)
	root.add_child(ul)
	_beacon(root.position + Vector3(-18.0, 10.0, 7.0).rotated(Vector3.UP, root.rotation.y), Color(1.0, 0.2, 0.15), 0.0)
	_beacon(root.position + Vector3(18.0, 10.0, 7.0).rotated(Vector3.UP, root.rotation.y), Color(0.2, 1.0, 0.3), 0.5)
	_beacon(root.position + Vector3(0.0, 13.5, -8.0).rotated(Vector3.UP, root.rotation.y), Color(1.0, 1.0, 1.0), 1.0)
	_label("L'ASTER\natelier · salle des cartes · quartiers", Vector3(PAD.x, 20.0, PAD.y), Color(1, 1, 1), 48)


# ---------------------------------------------------------------- la mine
func _build_mine() -> void:
	var steel := _flat(Color(0.35, 0.33, 0.3), 0.7, 0.6)
	var rust := _flat(Color(0.45, 0.28, 0.18), 0.95, 0.3)
	var cx := MINE.x
	var cz := MINE.y
	# Chevalement (tour de puits) au bord de la fosse
	var tx := cx + 52.0
	var tz := cz + 8.0
	var th := height_at(tx, tz)
	for sx in [-3.0, 3.0]:
		for sz in [-3.0, 3.0]:
			_mesh(_cyl(0.3, 0.4, 26.0), Vector3(tx + sx, th + 13.0, tz + sz), rust, Vector3(0, 0, sx * -0.03))
	for k in 5:
		var brace := BoxMesh.new()
		brace.size = Vector3(6.6, 0.3, 0.3)
		_mesh(brace, Vector3(tx, th + 3.0 + k * 5.5, tz - 3.0), rust)
		_mesh(brace, Vector3(tx, th + 3.0 + k * 5.5, tz + 3.0), rust)
		_mesh(brace, Vector3(tx - 3.0, th + 3.0 + k * 5.5, tz), rust, Vector3(0, PI / 2.0, 0))
		_mesh(brace, Vector3(tx + 3.0, th + 3.0 + k * 5.5, tz), rust, Vector3(0, PI / 2.0, 0))
	var wheel := TorusMesh.new()
	wheel.inner_radius = 2.2
	wheel.outer_radius = 2.8
	_mesh(wheel, Vector3(tx, th + 27.0, tz), steel, Vector3(0, 0, PI / 2.0))
	_mesh(wheel, Vector3(tx, th + 27.0, tz + 1.2), steel, Vector3(0, 0, PI / 2.0))
	var house := BoxMesh.new()
	house.size = Vector3(10.0, 6.0, 8.0)
	_mesh(house, Vector3(tx + 12.0, th + 3.0, tz), _flat(Color(0.5, 0.48, 0.45), 0.8, 0.2))
	# Convoyeur incliné qui monte de la fosse vers la base
	var belt := BoxMesh.new()
	belt.size = Vector3(2.2, 0.6, 70.0)
	var from := Vector3(cx + 10.0, height_at(cx + 10.0, cz + 10.0) - 6.0, cz + 10.0)
	var to := Vector3(cx + 70.0, height_at(cx + 70.0, cz + 30.0) + 10.0, cz + 30.0)
	var mid := (from + to) * 0.5
	var dir := to - from
	var yaw := atan2(-dir.x, -dir.z)
	var pitch := atan2(dir.y, Vector2(dir.x, dir.z).length())
	belt.size.z = dir.length()
	_mesh(belt, mid, steel, Vector3(pitch, yaw, 0))
	for k in 6:
		var p := from.lerp(to, (k + 0.5) / 6.0)
		var gh := height_at(p.x, p.z)
		_mesh(_cyl(0.25, 0.35, p.y - gh), Vector3(p.x, (p.y + gh) * 0.5, p.z), rust)
	# Tas de minerai et engins au fond
	var ore := _flat(Color(0.2, 0.2, 0.22), 1.0)
	for k in 7:
		var a := k * 0.9
		var r := _rng.randf_range(4.0, 14.0)
		var px := cx + cos(a) * r
		var pz := cz + sin(a) * r
		_mesh(_sph(_rng.randf_range(2.5, 4.5)), Vector3(px, height_at(px, pz) - 1.0, pz), ore, Vector3.ZERO, Vector3(1.0, 0.45, 1.0))
	_truck(Vector3(cx + 6.0, height_at(cx + 6.0, cz - 4.0) + 0.2, cz - 4.0), 1.2, Color(0.85, 0.6, 0.1))
	_truck(Vector3(cx - 30.0, height_at(cx - 30.0, cz + 20.0) + 0.2, cz + 20.0), -0.5, Color(0.4, 0.4, 0.42))
	# Ruines de l'ancienne mine (murs en pierre à moitié effondrés) sur le gradin ouest
	var stone := _flat(Color(0.4, 0.38, 0.35), 0.9)
	for k in 6:
		var wx := cx - 52.0 + k * 7.0
		var wz := cz - 20.0 + sin(k * 1.1) * 6.0
		var wh := height_at(wx, wz)
		var w := BoxMesh.new()
		w.size = Vector3(6.0, _rng.randf_range(2.0, 5.0), 1.2)
		_mesh(w, Vector3(wx, wh + w.size.y * 0.5 - 0.3, wz), stone, Vector3(0, k * 0.5, 0))
	# Éclairage de chantier au fond
	_floodlight(Vector3(cx + 18.0, height_at(cx + 18.0, cz + 18.0), cz + 18.0), 2.6, 5.0, 40.0)
	_beacon(Vector3(tx, th + 30.5, tz), Color(1.0, 0.15, 0.1), 0.8)
	_label("MINE DE SAINT-ÉLOI\n(ancienne galerie, site de la découverte)", Vector3(tx, th + 34.0, tz), Color(1, 1, 1), 40)


# ---------------------------------------------------------------- l'Arche et son chantier
func _build_arche_site() -> void:
	var ax := ARCHE.x
	var az := ARCHE.y
	_build_arche(Vector3(ax, 6.0, az))
	# Échafaudages d'Horizon autour de l'anneau
	var scaf := _flat(Color(0.75, 0.6, 0.2), 0.6, 0.5)
	for sx in [-1.0, 1.0]:
		for k in 4:
			_mesh(_cyl(0.1, 0.1, 14.0), Vector3(ax + sx * (12.0 + k * 1.5), 13.0, az + 3.0), scaf)
			_mesh(_cyl(0.1, 0.1, 14.0), Vector3(ax + sx * (12.0 + k * 1.5), 13.0, az - 3.0), scaf)
		for k in 4:
			var plank := BoxMesh.new()
			plank.size = Vector3(5.0, 0.2, 7.0)
			_mesh(plank, Vector3(ax + sx * 14.2, 8.5 + k * 3.2, az), _flat(Color(0.5, 0.42, 0.3), 0.9))
	# Passerelle et instruments
	var walk := BoxMesh.new()
	walk.size = Vector3(4.0, 0.3, 36.0)
	_mesh(walk, Vector3(ax, 6.3, az + 26.0), _flat(Color(0.35, 0.36, 0.38), 0.6, 0.3))
	for k in 3:
		_module(Vector3(ax - 24.0 + k * 14.0, 6.0, az + 30.0), Vector3(8.0, 3.5, 5.0), 0.0)
	for sx in [-1.0, 1.0]:
		_mesh(_cyl(0.15, 0.2, 5.0), Vector3(ax + sx * 10.0, 8.5, az + 14.0), scaf)
		_mesh(_sph(0.9), Vector3(ax + sx * 10.0, 11.4, az + 14.0), _flat(Color(0.2, 0.25, 0.3), 0.3, 0.8))
	_floodlight(Vector3(ax - 26.0, 6.0, az + 16.0), 0.9, 6.0, 50.0)
	_floodlight(Vector3(ax + 26.0, 6.0, az + 16.0), -0.9, 6.0, 50.0)
	_label("ARCHE 1 · première porte\n(site de recherche Horizon)", Vector3(ax, 22.0, az + 4.0), Color(1.0, 0.85, 0.5), 44)
	# Un Veilleur endormi, à demi enfoui dans la paroi
	var dark := _flat(Color(0.15, 0.15, 0.17), 0.5, 0.8)
	var vx := ax + 30.0
	var vz := az - 14.0
	var vh := height_at(vx, vz)
	_mesh(_sph(3.0), Vector3(vx, vh + 2.0, vz), dark, Vector3.ZERO, Vector3(1.0, 1.4, 1.0))
	_mesh(_cyl(0.8, 1.2, 6.0), Vector3(vx - 3.0, vh + 2.5, vz + 1.0), dark, Vector3(0, 0, 0.6))
	_mesh(_sph(0.5), Vector3(vx, vh + 3.2, vz + 2.6), _flat(Color(0.4, 0.3, 0.6), 0.3, 0.0, Color(0.5, 0.3, 0.9), 0.6))


# ---------------------------------------------------------------- végétation, rochers
func _build_vegetation() -> void:
	# Conifères sombres sur les pentes (MultiMesh)
	var st := SurfaceTool.new()
	st.append_from(_cyl(0.2, 0.4, 4.0), 0, Transform3D(Basis(), Vector3(0, 2.0, 0)))
	st.append_from(_cyl(0.0, 2.6, 5.0), 0, Transform3D(Basis(), Vector3(0, 5.5, 0)))
	st.append_from(_cyl(0.0, 2.0, 4.5), 0, Transform3D(Basis(), Vector3(0, 8.0, 0)))
	st.append_from(_cyl(0.0, 1.3, 4.0), 0, Transform3D(Basis(), Vector3(0, 10.5, 0)))
	var tree := st.commit()
	var tm := _flat(Color(0.12, 0.2, 0.14), 0.95)
	tree.surface_set_material(0, tm)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = tree
	var placed := []
	for k in 2200:
		var x := _rng.randf_range(-235.0, 235.0)
		var z := _rng.randf_range(-235.0, 235.0)
		var dx := absf(x - valley_center(z))
		var p := Vector2(x, z)
		if dx < 44.0 or p.distance_to(MINE) < 52.0 or p.distance_to(BASE) < 60.0 or p.distance_to(PAD) < 50.0 or p.distance_to(ARCHE) < 45.0 or p.distance_to(LAKE) < 70.0:
			continue
		var h := height_at(x, z)
		if h > 72.0:
			continue
		placed.append(Transform3D(Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3.ONE * _rng.randf_range(0.7, 1.5)), Vector3(x, h - 0.4, z)))
	mm.instance_count = placed.size()
	for i in placed.size():
		mm.set_instance_transform(i, placed[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(mmi)
	# Rochers gris
	var rock := _sph(1.0)
	rock.material = _flat(Color(0.33, 0.33, 0.35), 0.9)
	var mr := MultiMesh.new()
	mr.transform_format = MultiMesh.TRANSFORM_3D
	mr.mesh = rock
	var rocks := []
	for k in 500:
		var x := _rng.randf_range(-230.0, 230.0)
		var z := _rng.randf_range(-230.0, 230.0)
		var p := Vector2(x, z)
		if p.distance_to(BASE) < 50.0 or p.distance_to(PAD) < 42.0 or p.distance_to(PLAZA) < 32.0 or p.distance_to(LAKE) < 60.0:
			continue
		var h := height_at(x, z)
		var s := _rng.randf_range(0.8, 4.0)
		rocks.append(Transform3D(Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3(s, s * 0.6, s * 0.8)), Vector3(x, h - s * 0.2, z)))
	mr.instance_count = rocks.size()
	for i in rocks.size():
		mr.set_instance_transform(i, rocks[i])
	var mri := MultiMeshInstance3D.new()
	mri.multimesh = mr
	add_child(mri)


# ---------------------------------------------------------------- les personnages
func _label(text: String, pos: Vector3, color: Color, size := 40, yaw := 0.0, billboard := true) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font_size = size
	l.modulate = color
	l.outline_size = 10
	l.outline_modulate = Color(0, 0, 0, 0.8)
	l.position = pos
	l.rotation.y = yaw
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if billboard:
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = false
	add_child(l)
	return l


## Un humain : capsule + tête + veste colorée, avec son nom et son rôle
func _human(name_: String, role: String, pos: Vector3, yaw: float, jacket: Color, skin := Color(0.75, 0.6, 0.5), hair := Color(0.15, 0.1, 0.08)) -> Node3D:
	var root := Node3D.new()
	root.name = name_
	root.position = pos
	root.rotation.y = yaw
	add_child(root)
	var legs := BoxMesh.new()
	legs.size = Vector3(0.42, 0.85, 0.3)
	_mesh(legs, Vector3(0, 0.43, 0), _flat(Color(0.2, 0.2, 0.22), 0.9), Vector3.ZERO, Vector3.ONE, root)
	var torso := CapsuleMesh.new()
	torso.radius = 0.24
	torso.height = 0.95
	_mesh(torso, Vector3(0, 1.22, 0), _flat(jacket, 0.8), Vector3.ZERO, Vector3(1.1, 1.0, 0.8), root)
	for sx in [-0.3, 0.3]:
		var arm := CapsuleMesh.new()
		arm.radius = 0.08
		arm.height = 0.68
		_mesh(arm, Vector3(sx, 1.2, 0), _flat(jacket, 0.8), Vector3(0, 0, sx * -0.3), Vector3.ONE, root)
	_mesh(_sph(0.14), Vector3(0, 1.72, 0), _flat(skin, 0.7), Vector3.ZERO, Vector3.ONE, root)
	_mesh(_sph(0.145), Vector3(0, 1.76, -0.02), _flat(hair, 0.9), Vector3.ZERO, Vector3(1.0, 0.8, 1.0), root)
	var l := _label(name_ + "\n" + role, Vector3(0, 2.35, 0), Color(1, 1, 1), 44)
	l.reparent(root)
	l.position = Vector3(0, 2.35, 0)
	l.modulate = Color(1, 1, 1)
	npcs.append(root)
	return root


## Une armure portée par un PNJ : le modèle Solaris teinté (seul modèle 3D disponible)
func _armor(name_: String, role: String, pos: Vector3, yaw: float, tint: Color, scale := Vector3.ONE, glow := Color(0, 0, 0)) -> Node3D:
	var root := Node3D.new()
	root.name = name_
	root.position = pos
	root.rotation.y = yaw
	add_child(root)
	var scene: PackedScene = load("res://assets/solaris/solaris.glb")
	if scene:
		var model := scene.instantiate()
		var mat := StandardMaterial3D.new()
		mat.albedo_texture = load("res://assets/solaris/solaris.jpg")
		mat.albedo_color = tint
		mat.normal_enabled = true
		mat.normal_texture = load("res://assets/solaris/normal.jpg")
		var mr: Texture2D = load("res://assets/solaris/metal-rough.jpg")
		mat.metallic = 1.0
		mat.metallic_texture = mr
		mat.metallic_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_BLUE
		mat.roughness = 1.0
		mat.roughness_texture = mr
		mat.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GREEN
		if glow.r + glow.g + glow.b > 0.0:
			mat.emission_enabled = true
			mat.emission = glow
			mat.emission_energy_multiplier = 0.6
		_apply_material(model, mat)
		var aabb := _merged_aabb(model)
		model.position.y = -aabb.position.y * scale.y
		model.rotation.y = PI
		model.scale = scale
		root.add_child(model)
	var l := _label(name_ + "\n" + role, Vector3(0, 2.6 * scale.y, 0), Color(1, 1, 1), 44)
	l.reparent(root)
	l.position = Vector3(0, 2.6 * scale.y, 0)
	npcs.append(root)
	return root


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


func _build_people() -> void:
	# L'équipage de l'Aster aligné sur l'esplanade, face au sud (vers la caméra de présentation)
	var y := 2.8
	var zx := PLAZA.x
	var zz := PLAZA.y - 6.0
	_human("Ilse Varga", "commandante de l'Aster", Vector3(zx - 10.0, y, zz), PI, Color(0.12, 0.2, 0.35), Color(0.85, 0.7, 0.6), Color(0.75, 0.7, 0.6))
	_human("Teo Marchetti", "exo-archéologue", Vector3(zx - 6.0, y, zz + 0.4), PI, Color(0.55, 0.42, 0.28), Color(0.8, 0.62, 0.5), Color(0.2, 0.12, 0.08))
	_human("Nadia Okafor", "cheffe de l'Atelier", Vector3(zx - 2.0, y, zz), PI, Color(0.9, 0.5, 0.1), Color(0.45, 0.3, 0.22), Color(0.08, 0.06, 0.05))
	_human("Sann", "pilote, Flottilles libres", Vector3(zx + 2.0, y, zz + 0.4), PI, Color(0.2, 0.5, 0.5), Color(0.7, 0.6, 0.55), Color(0.5, 0.2, 0.4))
	_armor("Bastion", "escouade d'Horizon (copie humaine)", Vector3(zx + 7.0, y, zz), PI, Color(0.45, 0.5, 0.42), Vector3(1.25, 1.12, 1.25))
	_armor("Zéphyr", "escouade d'Horizon (copie humaine)", Vector3(zx + 11.5, y, zz + 0.4), PI, Color(0.6, 0.78, 0.95), Vector3(0.9, 1.0, 0.9), Color(0.3, 0.6, 1.0))
	# Techniciens d'Horizon qui s'affairent
	var grey := Color(0.55, 0.57, 0.6)
	_human("Technicien", "Horizon", Vector3(PAD.x + 30.0, 3.0, PAD.y + 8.0), 0.8, grey)
	_human("Technicienne", "Horizon", Vector3(BASE.x - 8.0, 2.5, BASE.y + 30.0), 2.4, grey, Color(0.6, 0.45, 0.35))
	_human("Technicien", "Horizon", Vector3(ARCHE.x - 6.0, 6.0, ARCHE.y + 24.0), 0.2, grey)
	# Le Solaris jouable : étiquette au-dessus du joueur, posée par la vidéo (voir showcase_terre)
	_label("SOLARIS\nl'armure jouable (toi)", Vector3(zx, y + 3.4, zz + 10.0), GOLD, 36)
