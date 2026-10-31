class_name ForgeKit
extends RefCounted
## Briques du décor de la Forge (intérieur de l'Atelier, d'après la maquette v2 de maquette_forge/) :
## matériaux partagés et formes simples. Chaque accessoire (bras robot, anneau de berceau, poste de travail,
## râtelier, caisses, lanterne) est une scène à part dans scenes/forge/ : on pourra la remplacer par un
## modèle Meshy sans toucher au reste.

const TEX := "res://assets/forge/tex/"
const HOLO := Color(0.26, 0.6, 1.0)
const WARM := Color(1.0, 0.68, 0.36)

static var _mats := {}


## Matériau partagé par son nom : pierre, sol, dalles, bois, acier, acier_sombre, fonte, orange, holo, ampoule…
static func mat(name: String) -> Material:
	if _mats.has(name):
		return _mats[name]
	var m := StandardMaterial3D.new()
	match name:
		"pierre", "sol", "dalles", "bois":
			m.albedo_texture = load(TEX + name + "_albedo.jpg")
			m.normal_enabled = true
			m.normal_texture = load(TEX + name + "_normal.jpg")
			m.normal_scale = 0.8
			m.roughness_texture = load(TEX + name + "_roughness.jpg")
			m.uv1_triplanar = true
			m.uv1_world_triplanar = true
			m.uv1_scale = Vector3.ONE * { "pierre": 0.4, "sol": 0.3, "dalles": 0.5, "bois": 0.9 }[name]
			if name == "pierre":
				m.albedo_color = Color(1.0, 0.94, 0.84)
			elif name == "bois":
				m.albedo_color = Color(0.85, 0.72, 0.58)
		"pierre_claire":
			m.albedo_texture = load(TEX + "pierre_albedo.jpg")
			m.albedo_color = Color(1.15, 1.08, 0.98)
			m.uv1_triplanar = true
			m.uv1_world_triplanar = true
			m.uv1_scale = Vector3.ONE * 0.8
			m.roughness = 0.8
		"acier":                      # bras robots, structure des berceaux : acier gris propre
			m.albedo_color = Color(0.64, 0.66, 0.69)
			m.metallic = 0.5
			m.roughness = 0.38
		"acier_sombre":
			m.albedo_color = Color(0.27, 0.28, 0.3)
			m.metallic = 0.6
			m.roughness = 0.45
		"fonte":                      # fer forgé des fermes, lampes
			m.albedo_color = Color(0.09, 0.085, 0.08)
			m.metallic = 0.6
			m.roughness = 0.6
		"orange":                     # peinture des capots
			m.albedo_color = Color(0.95, 0.42, 0.1)
			m.metallic = 0.2
			m.roughness = 0.42
		"cable":
			m.albedo_color = Color(0.05, 0.05, 0.055)
			m.roughness = 0.55
		"holo":
			_glow(m, HOLO, 2.2)
		"faisceau":                   # rayon de lumière douce sous l'anneau
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
			m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
			m.albedo_color = Color(0.25, 0.5, 0.9, 0.06)
			m.albedo_texture = _beam_tex()
			m.disable_receive_shadows = true
		"ampoule":
			_glow(m, WARM, 5.0)
		"vitrail":                    # rosace et baie : le jour dehors
			_glow(m, Color(1.0, 0.85, 0.62), 2.4)
		"lierre":
			m.albedo_texture = _leaf_tex()
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
			m.alpha_scissor_threshold = 0.5
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
			m.albedo_color = Color(0.55, 0.75, 0.4)
			m.roughness = 0.7
			m.backlight_enabled = true
			m.backlight = Color(0.25, 0.4, 0.1)
		"ecran":
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			m.albedo_texture = _screen_tex()
		_:
			push_warning("ForgeKit : matériau inconnu " + name)
	_mats[name] = m
	return m


static func _glow(m: StandardMaterial3D, c: Color, energy: float) -> void:
	m.albedo_color = Color(0.02, 0.02, 0.02)
	m.roughness = 0.5
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = energy


static func banner_mat(color: String) -> Material:
	var k := "banniere_" + color
	if not _mats.has(k):
		var m := StandardMaterial3D.new()
		m.albedo_texture = load(TEX + k + ".png")
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		m.alpha_scissor_threshold = 0.5
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.roughness = 0.9
		_mats[k] = m
	return _mats[k]


# ---------------------------------------------------------------- formes
static func box(parent: Node, size: Vector3, pos: Vector3, m: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	var b := BoxMesh.new()
	b.size = size
	return _add(parent, b, pos, m, rot)


static func cyl(parent: Node, r: float, h: float, pos: Vector3, m: Material, top := -1.0, rot := Vector3.ZERO, seg := 32) -> MeshInstance3D:
	var c := CylinderMesh.new()
	c.top_radius = r if top < 0.0 else top
	c.bottom_radius = r
	c.height = h
	c.radial_segments = seg
	c.rings = 1
	return _add(parent, c, pos, m, rot)


static func sphere(parent: Node, r: float, pos: Vector3, m: Material) -> MeshInstance3D:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = 16
	s.rings = 8
	return _add(parent, s, pos, m)


static func torus(parent: Node, r_in: float, r_out: float, pos: Vector3, m: Material, rings := 64) -> MeshInstance3D:
	var t := TorusMesh.new()
	t.inner_radius = r_in
	t.outer_radius = r_out
	t.rings = rings
	t.ring_segments = 10
	return _add(parent, t, pos, m)


## Capot arrondi : une capsule aplatie (bout des bras robots, carters).
static func capsule(parent: Node, r: float, h: float, pos: Vector3, m: Material, rot := Vector3.ZERO, flat := 1.0) -> MeshInstance3D:
	var c := CapsuleMesh.new()
	c.radius = r
	c.height = maxf(h, r * 2.0)
	c.radial_segments = 20
	c.rings = 4
	var mi := _add(parent, c, pos, m, rot)
	mi.scale = Vector3(flat, 1.0, 1.0)
	return mi


## Barre entre deux points (section carrée w x d), alignée sur le segment.
static func beam(parent: Node, a: Vector3, b: Vector3, w: float, m: Material, d := -1.0) -> MeshInstance3D:
	var bm := BoxMesh.new()
	bm.size = Vector3(w, a.distance_to(b), w if d < 0.0 else d)
	var mi := MeshInstance3D.new()
	mi.mesh = bm
	mi.material_override = m
	parent.add_child(mi)
	mi.transform = Transform3D(_basis_y(b - a), (a + b) * 0.5)
	return mi


## Tige ronde entre deux points.
static func rod(parent: Node, a: Vector3, b: Vector3, r: float, m: Material, seg := 12) -> MeshInstance3D:
	var c := CylinderMesh.new()
	c.top_radius = r
	c.bottom_radius = r
	c.height = a.distance_to(b)
	c.radial_segments = seg
	c.rings = 1
	var mi := MeshInstance3D.new()
	mi.mesh = c
	mi.material_override = m
	parent.add_child(mi)
	mi.transform = Transform3D(_basis_y(b - a), (a + b) * 0.5)
	return mi


static func _basis_y(dir: Vector3) -> Basis:
	var y := dir.normalized()
	var x := Vector3.UP.cross(y)
	if x.length() < 0.01:
		x = Vector3.RIGHT.cross(y)
	x = x.normalized()
	return Basis(x, y, x.cross(y).normalized()).orthonormalized()


static func _add(parent: Node, mesh: Mesh, pos: Vector3, m: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = m
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)
	return mi


## Tronçon d'anneau au profil arrondi (rayon, hauteur) balayé de a0 à a1 autour de Y :
## les carters de l'anneau de maintenance, moins « boîte » que des cubes.
static func arc_sweep(profile: PackedVector2Array, a0: float, a1: float, steps: int, caps := true) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := profile.size()
	for i in steps:
		var t0 := a0 + (a1 - a0) * i / steps
		var t1 := a0 + (a1 - a0) * (i + 1) / steps
		for j in n:
			var p := profile[j]
			var q := profile[(j + 1) % n]
			var v := [_ring_pt(p, t0), _ring_pt(q, t0), _ring_pt(q, t1), _ring_pt(p, t1)]
			st.add_vertex(v[0]); st.add_vertex(v[2]); st.add_vertex(v[1])
			st.add_vertex(v[0]); st.add_vertex(v[3]); st.add_vertex(v[2])
	if caps:
		var c := Vector2.ZERO
		for p in profile:
			c += p
		c /= n
		for side in [0, 1]:
			var t := a0 if side == 0 else a1
			for j in n:
				var a := _ring_pt(profile[j], t)
				var b := _ring_pt(profile[(j + 1) % n], t)
				var o := _ring_pt(c, t)
				if side == 0:
					st.add_vertex(o); st.add_vertex(a); st.add_vertex(b)
				else:
					st.add_vertex(o); st.add_vertex(b); st.add_vertex(a)
	st.generate_normals()
	return st.commit()


static func _ring_pt(p: Vector2, t: float) -> Vector3:
	return Vector3(cos(t) * p.x, p.y, sin(t) * p.x)


## Profil de rectangle aux coins arrondis (largeur radiale w, hauteur h, rayon r) centré sur (cx, cy).
static func rounded_rect(cx: float, cy: float, w: float, h: float, r: float, seg := 3) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var corners := [Vector2(cx + w / 2 - r, cy + h / 2 - r), Vector2(cx - w / 2 + r, cy + h / 2 - r),
		Vector2(cx - w / 2 + r, cy - h / 2 + r), Vector2(cx + w / 2 - r, cy - h / 2 + r)]
	for k in 4:
		for s in seg + 1:
			var a := PI / 2 * k + PI / 2 * s / seg
			pts.append(corners[k] + Vector2(cos(a), sin(a)) * r)
	# sens horaire attendu par arc_sweep (normales vers l'extérieur)
	pts.reverse()
	return pts


## Câbles pendants (chaînettes) réunis dans un seul maillage : [[a, b, flèche], ...].
static func cables(spans: Array, r := 0.025, m: Material = null) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for sp in spans:
		var pts := []
		var a: Vector3 = sp[0]
		var b: Vector3 = sp[1]
		var n := 14
		for i in n + 1:
			var t := float(i) / n
			pts.append(a.lerp(b, t) + Vector3.DOWN * float(sp[2]) * 4.0 * t * (1.0 - t))
		_tube(st, pts, float(sp[3]) if sp.size() > 3 else r)
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = m if m else mat("cable")
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


static func _tube(st: SurfaceTool, pts: Array, r: float, sides := 6) -> void:
	var rings := []
	for i in pts.size():
		var d: Vector3 = (pts[mini(i + 1, pts.size() - 1)] - pts[maxi(i - 1, 0)]).normalized()
		var x := d.cross(Vector3.UP)
		if x.length() < 0.01:
			x = d.cross(Vector3.RIGHT)
		x = x.normalized()
		var y := x.cross(d).normalized()
		var ring := []
		for s in sides:
			var a := TAU * s / sides
			ring.append(pts[i] + (x * cos(a) + y * sin(a)) * r)
		rings.append(ring)
	for i in rings.size() - 1:
		for s in sides:
			var p0: Vector3 = rings[i][s]
			var p1: Vector3 = rings[i][(s + 1) % sides]
			var p2: Vector3 = rings[i + 1][(s + 1) % sides]
			var p3: Vector3 = rings[i + 1][s]
			st.add_vertex(p0); st.add_vertex(p1); st.add_vertex(p2)
			st.add_vertex(p0); st.add_vertex(p2); st.add_vertex(p3)


# ---------------------------------------------------------------- textures fabriquées
static func _leaf_tex() -> ImageTexture:
	var img := Image.create(128, 128, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for k in 26:
		var c := Vector2(rng.randf_range(16, 112), rng.randf_range(10, 118))
		var rad := rng.randf_range(7, 13)
		var col := Color(0.25, 0.45, 0.15).lerp(Color(0.45, 0.62, 0.22), rng.randf())
		for y in range(int(c.y - rad), int(c.y + rad)):
			for x in range(int(c.x - rad), int(c.x + rad)):
				if x < 0 or y < 0 or x >= 128 or y >= 128:
					continue
				var d := Vector2(x, y) - c
				if (d.x * d.x) / (rad * rad) + (d.y * d.y) / (rad * rad * 0.55) < 1.0:
					img.set_pixel(x, y, col * (0.8 + 0.2 * (1.0 - d.length() / rad)))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


static func _screen_tex() -> ImageTexture:
	var img := Image.create(256, 160, false, Image.FORMAT_RGB8)
	img.fill(Color(0.02, 0.06, 0.14))
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var line := Color(0.45, 0.8, 1.0)
	for x in 256:                                   # cadre
		img.set_pixel(x, 2, line * 0.6); img.set_pixel(x, 157, line * 0.6)
	for k in 12:                                    # histogramme
		var h := rng.randi_range(12, 60)
		img.fill_rect(Rect2i(14 + k * 9, 150 - h, 6, h), Color(0.25, 0.55, 0.95))
	var y := 70.0
	for x in range(130, 246):                       # courbe
		y = clampf(y + rng.randf_range(-3.5, 3.5), 20.0, 140.0)
		img.fill_rect(Rect2i(x, int(y), 2, 2), line)
	for k in 6:                                     # lignes de texte
		img.fill_rect(Rect2i(14, 12 + k * 7, rng.randi_range(30, 90), 2), line * 0.7)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


static func _beam_tex() -> GradientTexture2D:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 0.0))
	g.set_color(1, Color(1, 1, 1, 1.0))
	g.add_point(0.6, Color(1, 1, 1, 0.55))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill_from = Vector2(0, 1)       # V = 1 en bas du cylindre : plus dense vers le haut
	t.fill_to = Vector2(0, 0)
	t.width = 4
	t.height = 64
	return t
