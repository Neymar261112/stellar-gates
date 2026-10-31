extends Node3D
## Intérieur de la Forge, décor 3D de l'écran Forge (d'après maquette_forge/maquette_forge_v2_2.png) :
## halle en pierre calcaire et charpente en fer, le Solaris sur un socle rond à gradins avec un anneau bleu
## au sol, le grand anneau de maintenance au-dessus et son rayon de lumière, deux bras robots (acier gris,
## capots orange), postes de travail aux écrans holographiques, câbles, suspensions chaudes, bannières
## rouge et blanc / bleu marine à l'emblème ailé, lierre, un second berceau sur le côté, air poussiéreux doré.
## Repère : Solaris au centre, pieds à y = 0.25 (plateau du socle), face à -Z (côté caméra par défaut).
## Les accessoires sont des scènes à part (scenes/forge/*.tscn), faciles à remplacer par des modèles Meshy.

const K := preload("res://scripts/forge/forge_kit.gd")
const ROBOT_ARM := preload("res://scenes/forge/robot_arm.tscn")
const CRADLE_RING := preload("res://scenes/forge/cradle_ring.tscn")
const WORKSTATION := preload("res://scenes/forge/workstation.tscn")
const TOOL_RACK := preload("res://scenes/forge/tool_rack.tscn")
const CRATES := preload("res://scenes/forge/crates.tscn")
const LANTERN := preload("res://scenes/forge/lantern.tscn")

const FY := -0.6          # sol de la halle
const DECK := 0.25        # plateau du socle (pieds du Solaris)
const HW := 8.6           # axe des piliers
const ZB := 8.75          # parement du mur du fond
const ZF := -9.6          # parement du mur de façade (derrière la caméra par défaut)
const ZT := 5.8           # entraits de la charpente
const ZR := 9.0           # faîtage
const ROWS := [-9.0, -3.0, 3.0, 8.2]

@export var with_environment := true

var weld_tip: Node3D       # pointe du bras soudeur (étincelles de l'Atelier)
var main_ring: Node3D
var _spans := []           # câbles, réunis en un seul maillage


func _ready() -> void:
	if with_environment:
		_environment()
	_hall()
	_roof()
	_pedestal(Vector3.ZERO, 1.0)
	_props()
	_banners()
	_ivy()
	_cables()


# ---------------------------------------------------------------- lumière et air
func _environment() -> void:
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.09, 0.07, 0.05)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.7, 0.58, 0.44)
	e.ambient_light_energy = 0.6
	e.tonemap_mode = Environment.TONE_MAPPER_ACES
	e.tonemap_exposure = 1.0
	e.glow_enabled = true
	e.glow_intensity = 0.7
	e.glow_bloom = 0.04
	e.glow_hdr_threshold = 1.0
	e.ssao_enabled = true
	e.ssao_intensity = 1.6
	e.ssr_enabled = true
	e.ssr_max_steps = 32
	e.volumetric_fog_enabled = true
	e.volumetric_fog_density = 0.03
	e.volumetric_fog_albedo = Color(1.0, 0.86, 0.66)
	e.volumetric_fog_emission = Color(0.05, 0.035, 0.02)
	e.volumetric_fog_emission_energy = 0.6
	e.volumetric_fog_anisotropy = 0.45
	e.volumetric_fog_length = 26.0
	e.volumetric_fog_gi_inject = 0.6
	e.adjustment_enabled = true
	e.adjustment_saturation = 1.05
	var we := WorldEnvironment.new()
	we.environment = e
	add_child(we)
	# soleil de fin d'après-midi : il entre par la verrière du toit et dessine des rais dans la poussière
	var sun := DirectionalLight3D.new()
	sun.name = "Soleil"
	sun.light_color = Color(1.0, 0.76, 0.48)
	sun.light_energy = 2.4
	sun.light_volumetric_fog_energy = 2.2
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 30.0
	add_child(sun)
	sun.look_at_from_position(Vector3.ZERO, Vector3(-0.62, -0.72, 0.3), Vector3.UP)
	# lumière dorée renvoyée par la pierre : les murs en calcaire restent clairs
	for p in [Vector3(-5.0, 4.6, 5.5), Vector3(5.0, 4.6, 5.5), Vector3(0.0, 4.8, -6.5)]:
		var fill := OmniLight3D.new()
		fill.light_color = Color(1.0, 0.78, 0.55)
		fill.light_energy = 1.6
		fill.omni_range = 11.0
		fill.omni_attenuation = 0.8
		fill.light_volumetric_fog_energy = 0.15
		fill.position = p
		add_child(fill)


# ---------------------------------------------------------------- halle
func _hall() -> void:
	var stone := K.mat("pierre")
	var trim := K.mat("pierre_claire")
	K.box(self, Vector3(20.0, 0.2, ZB - ZF + 1.0), Vector3(0, FY - 0.1, (ZB + ZF) / 2), K.mat("sol"))
	# mur du fond (jusqu'au faîtage), pilastres et rosace
	var h := ZR + 0.8 - FY
	K.box(self, Vector3(19.4, h, 0.5), Vector3(0, FY + h / 2, ZB + 0.25), stone)
	for x in [-6.0, -2.2, 2.2, 6.0]:
		K.box(self, Vector3(0.6, ZT - FY, 0.18), Vector3(x, FY + (ZT - FY) / 2, ZB - 0.08), trim)
	var rose := K.cyl(self, 1.1, 0.06, Vector3(0, 7.1, ZB - 0.02), K.mat("vitrail"), -1.0, Vector3(PI / 2, 0, 0), 48)
	rose.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var ring := K.torus(self, 1.08, 1.24, Vector3(0, 7.1, ZB - 0.08), K.mat("fonte"), 48)
	ring.rotation.x = PI / 2
	for i in 8:
		var a := TAU * i / 8
		K.beam(self, Vector3(0, 7.1, ZB - 0.07), Vector3(cos(a) * 1.1, 7.1 + sin(a) * 1.1, ZB - 0.07), 0.07, K.mat("fonte"))
	# murs latéraux
	for sx in [-1.0, 1.0]:
		K.box(self, Vector3(0.5, ZT + 0.4 - FY, ZB - ZF + 0.5), Vector3(sx * (HW + 0.85), FY + (ZT + 0.4 - FY) / 2, (ZB + ZF) / 2), stone)
	# façade : grande porte ouverte sur le jour
	var door_w := 4.4
	var door_h := 4.2
	var side_w := (19.4 - door_w) / 2
	for sx in [-1.0, 1.0]:
		K.box(self, Vector3(side_w, h, 0.5), Vector3(sx * (door_w + side_w) / 2, FY + h / 2, ZF - 0.25), stone)
	K.box(self, Vector3(door_w, h - door_h, 0.5), Vector3(0, FY + door_h + (h - door_h) / 2, ZF - 0.25), stone)
	K.box(self, Vector3(door_w + 0.6, 0.35, 0.6), Vector3(0, FY + door_h + 0.17, ZF - 0.2), trim)
	var day := K.box(self, Vector3(door_w, door_h, 0.05), Vector3(0, FY + door_h / 2, ZF - 1.2), K.mat("vitrail"))
	day.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# piliers
	for z in ROWS:
		for sx in [-1.0, 1.0]:
			_pillar(Vector3(sx * HW, FY, z))
	# appliques sur les piliers du milieu
	for z in [-3.0, 3.0]:
		for sx in [-1.0, 1.0]:
			var l: Node3D = LANTERN.instantiate()
			l.pendant = false
			l.energy = 0.9
			l.light_range = 4.5
			l.position = Vector3(sx * (HW - 0.4), 2.1, z)
			l.rotation.y = sx * PI / 2
			add_child(l)


func _pillar(p: Vector3) -> void:
	var stone := K.mat("pierre")
	var trim := K.mat("pierre_claire")
	var h := ZT - p.y
	K.box(self, Vector3(1.1, 0.45, 1.1), p + Vector3(0, 0.22, 0), stone)
	K.box(self, Vector3(0.92, 0.14, 0.92), p + Vector3(0, 0.52, 0), trim)
	K.box(self, Vector3(0.72, h - 1.0, 0.72), p + Vector3(0, 0.6 + (h - 1.0) / 2, 0), stone)
	for d in [Vector3(0.37, 0, 0), Vector3(-0.37, 0, 0), Vector3(0, 0, 0.37), Vector3(0, 0, -0.37)]:
		K.box(self, Vector3(0.06 if d.x != 0.0 else 0.46, h - 1.3, 0.06 if d.z != 0.0 else 0.46), p + d + Vector3(0, 0.6 + (h - 1.0) / 2, 0), trim)
	K.box(self, Vector3(0.95, 0.2, 0.95), p + Vector3(0, h - 0.32, 0), trim)
	K.box(self, Vector3(1.15, 0.3, 1.15), p + Vector3(0, h - 0.12, 0), stone)


# ---------------------------------------------------------------- charpente et toit
func _roof() -> void:
	var iron := K.mat("fonte")
	var wood := K.mat("bois")
	var hx := HW + 0.85
	for z in ROWS:
		K.box(self, Vector3(hx * 2.0, 0.3, 0.26), Vector3(0, ZT + 0.1, z), iron)
		for sx in [-1.0, 1.0]:
			K.beam(self, Vector3(sx * hx, ZT + 0.2, z), Vector3(0, ZR, z), 0.24, iron, 0.3)
			for k in range(1, 5):
				var x: float = sx * HW * k / 5.0
				var ztop := ZT + (ZR - ZT) * (1.0 - k / 5.0)
				K.beam(self, Vector3(x, ZT + 0.25, z), Vector3(x, ztop, z), 0.09, iron)
				var x2: float = sx * HW * (k + 1) / 5.0 if k < 4 else sx * HW
				K.beam(self, Vector3(x, ztop, z), Vector3(x2, ZT + 0.25, z), 0.07, iron)
			# jambe de force cintrée sous l'entrait
			var prev := Vector3(sx * (HW - 0.4), ZT - 1.4, z)
			for i in range(1, 9):
				var t := PI / 2 * i / 8
				var q := Vector3(sx * (HW - 0.4 - 2.3 * (1.0 - cos(t))), ZT - 1.4 + 1.35 * sin(t), z)
				K.beam(self, prev, q, 0.13, iron, 0.18)
				prev = q
		K.beam(self, Vector3(0, ZT + 0.25, z), Vector3(0, ZR, z), 0.14, iron)
	# pannes, voligeage et verrière (côté +X, par où entre le soleil)
	for sx in [-1.0, 1.0]:
		for k in 7:
			var t := k / 6.0
			K.box(self, Vector3(0.12, 0.14, ZB - ZF + 0.6), Vector3(sx * hx * (1.0 - t), ZT + 0.35 + (ZR - ZT) * t, (ZB + ZF) / 2), iron)
		var spans := [[0.0, 0.55], [0.72, 1.0]] if sx > 0.0 else [[0.0, 1.0]]
		for s in spans:
			var p0 := Vector3(sx * (hx + 0.5) * (1.0 - s[0]), ZT + 0.2 + (ZR - ZT + 0.3) * s[0], 0)
			var p1 := Vector3(sx * (hx + 0.5) * (1.0 - s[1]), ZT + 0.2 + (ZR - ZT + 0.3) * s[1], 0)
			var d := p1 - p0
			var panel := K.box(self, Vector3(d.length(), 0.1, ZB - ZF + 1.2), (p0 + p1) / 2 + Vector3(0, 0.3, (ZB + ZF) / 2), wood)
			panel.rotation.z = atan2(d.y, d.x)
		if sx > 0.0:
			for z in range(int(ZF), int(ZB) + 1, 2):
				var a := Vector3(hx * 0.45, ZT + 0.5 + (ZR - ZT) * 0.55, z)
				var b := Vector3(hx * 0.28, ZT + 0.5 + (ZR - ZT) * 0.72, z)
				K.beam(self, a, b, 0.05, iron)
	K.box(self, Vector3(0.26, 0.3, ZB - ZF + 0.6), Vector3(0, ZR + 0.15, (ZB + ZF) / 2), iron)
	# suspensions chaudes sous les entraits
	for z in [-3.0, 3.0]:
		for x in [-6.4, -3.2, 3.2, 6.4]:
			var l: Node3D = LANTERN.instantiate()
			l.drop = 1.7
			l.position = Vector3(x, ZT - 0.05, z)
			add_child(l)


# ---------------------------------------------------------------- berceaux
## Socle rond à gradins (s = échelle), anneau bleu au sol, anneau de maintenance au-dessus.
func _pedestal(c: Vector3, s: float) -> Node3D:
	var deck := DECK if s >= 1.0 else FY + 0.75 * s
	var t1 := FY + 0.3 * s
	var t2 := FY + 0.58 * s
	K.cyl(self, 2.15 * s, t1 - FY, c + Vector3(0, (FY + t1) / 2, 0), K.mat("pierre_claire"), -1.0, Vector3.ZERO, 64)
	K.cyl(self, 1.85 * s, t2 - t1, c + Vector3(0, (t1 + t2) / 2, 0), K.mat("acier"), -1.0, Vector3.ZERO, 64)
	K.cyl(self, 1.5 * s, deck - t2, c + Vector3(0, (t2 + deck) / 2, 0), K.mat("acier_sombre"), 1.46 * s, Vector3.ZERO, 64)
	K.torus(self, 1.56 * s, 1.62 * s, c + Vector3(0, t2 + 0.005, 0), K.mat("holo"), 96)
	K.torus(self, 1.98 * s, 2.03 * s, c + Vector3(0, t1 + 0.005, 0), K.mat("holo"), 96)
	for i in 12:
		var a := TAU * i / 12
		K.box(self, Vector3(0.05, 0.16 * s, 0.24 * s), c + Vector3(cos(a), 0, sin(a)) * 1.86 * s + Vector3(0, (t1 + t2) / 2, 0), K.mat("acier_sombre"), Vector3(0, -a, 0))
	var ring: Node3D = CRADLE_RING.instantiate()
	var ry := deck + 3.0 * s
	ring.radius = 1.55 * s
	ring.beam_height = ry - 0.3 - deck
	ring.ceiling = ZT - ry
	ring.spot_energy = 5.0 * s
	ring.position = c + Vector3(0, ry, 0)
	add_child(ring)
	if s >= 1.0:
		main_ring = ring
	return ring


# ---------------------------------------------------------------- accessoires
func _props() -> void:
	# bras robots de part et d'autre du Solaris (le gauche de l'écran soude de temps en temps)
	for sx in [-1.0, 1.0]:
		var arm: Node3D = ROBOT_ARM.instantiate()
		arm.size = 0.6
		arm.position = Vector3(sx * 2.65, FY, -0.7)
		arm.target = Vector3(sx * 1.05, 1.55, -0.15) - arm.position
		arm.tool = "weld"
		add_child(arm)
		if sx > 0.0:
			weld_tip = arm.get_node("Tourelle/Pointe")
	# second berceau, en partie visible sur le côté
	_pedestal(Vector3(-6.3, 0, 4.9), 0.85)
	# postes de travail (l'opérateur côté -Z de chaque poste)
	# (hors du cercle que parcourt la caméra, 7 m au plus)
	for w in [[Vector3(7.5, FY, 2.0), PI / 2], [Vector3(-7.5, FY, -3.8), -PI / 2], [Vector3(3.0, FY, 7.6), 0.0],
			[Vector3(-2.6, FY, 7.7), 0.1], [Vector3(6.7, FY, -5.2), PI / 2]]:
		var ws: Node3D = WORKSTATION.instantiate()
		ws.position = w[0]
		ws.rotation.y = w[1]
		add_child(ws)
	var k := 0
	for r in [[Vector3(HW + 0.45, FY, 5.6), PI / 2], [Vector3(HW + 0.45, FY, -1.2), PI / 2], [Vector3(-HW - 0.45, FY, -1.2), -PI / 2],
			[Vector3(-HW - 0.45, FY, -6.0), -PI / 2], [Vector3(0.0, FY, ZB - 0.15), 0.0], [Vector3(6.4, FY, ZB - 0.15), 0.0]]:
		var tr: Node3D = TOOL_RACK.instantiate()
		tr.seed_value = k
		tr.position = r[0]
		tr.rotation.y = r[1]
		add_child(tr)
		k += 1
	for p in [Vector3(6.9, FY, -2.6), Vector3(-6.6, FY, -6.6), Vector3(7.3, FY, 7.4), Vector3(-7.6, FY, 7.8), Vector3(1.5, FY, 8.0),
			Vector3(-5.4, FY, -8.1), Vector3(5.2, FY, -8.4), Vector3(-7.4, FY, 1.6)]:
		var cr: Node3D = CRATES.instantiate()
		cr.seed_value = k
		cr.position = p
		cr.rotation.y = k * 0.7
		add_child(cr)
		k += 1


# ---------------------------------------------------------------- bannières, lierre, câbles
func _banners() -> void:
	for sx in [-1.0, 1.0]:
		_banner("red", Vector3(sx * 4.1, ZT - 0.3, ZB - 0.05), Vector2(1.5, 4.9), PI)
		_banner("cream", Vector3(sx * 3.4, ZT - 0.4, ZF + 0.05), Vector2(1.3, 4.3), 0.0)
		for z in [-3.0, 3.0]:
			_banner("navy", Vector3(sx * (HW - 0.38), ZT - 0.6, z), Vector2(0.62, 2.6), -sx * PI / 2)


func _banner(color: String, top: Vector3, size: Vector2, yaw: float) -> void:
	var q := QuadMesh.new()
	q.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = q
	mi.material_override = K.banner_mat(color)
	mi.position = top + Vector3(0, -size.y / 2, 0)
	mi.rotation.y = yaw
	add_child(mi)
	K.rod(self, top + Vector3(0, 0.03, 0) + Basis(Vector3.UP, yaw) * Vector3(-size.x / 2 - 0.08, 0, 0),
		top + Vector3(0, 0.03, 0) + Basis(Vector3.UP, yaw) * Vector3(size.x / 2 + 0.08, 0, 0), 0.025, K.mat("fonte"), 8)


## Lierre qui retombe des entraits et du haut des murs : des feuilles en cartes croisées (un seul MultiMesh).
func _ivy() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var tops := []
	for z in ROWS:
		for i in 7:
			tops.append(Vector3(rng.randf_range(-HW + 0.6, HW - 0.6), ZT - 0.02, z + rng.randf_range(-0.12, 0.12)))
		for sx in [-1.0, 1.0]:
			for i in 3:
				tops.append(Vector3(sx * (HW + rng.randf_range(-0.4, 0.3)), ZT - 0.1, z + rng.randf_range(-0.6, 0.6)))
	for i in 10:
		tops.append(Vector3(rng.randf_range(-9.0, 9.0), ZT + 0.3, ZB - 0.3))
	var xfs := []
	for t in tops:
		var length := rng.randf_range(0.5, 2.6)
		var p: Vector3 = t
		var y := 0.0
		while y < length:
			var sc := rng.randf_range(0.22, 0.34) * (1.0 - 0.4 * y / length)
			var b := Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.RIGHT, rng.randf_range(-0.4, 0.4)) * Basis.from_scale(Vector3.ONE * sc)
			xfs.append(Transform3D(b, p + Vector3(rng.randf_range(-0.06, 0.06), -y, rng.randf_range(-0.06, 0.06))))
			y += rng.randf_range(0.08, 0.15)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var q := QuadMesh.new()
	q.size = Vector2.ONE
	mm.mesh = q
	mm.instance_count = xfs.size()
	for i in xfs.size():
		mm.set_instance_transform(i, xfs[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "Lierre"
	mmi.multimesh = mm
	mmi.material_override = K.mat("lierre")
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)


func _cables() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for k in 34:
		var i := rng.randi_range(0, ROWS.size() - 2)
		var x1 := rng.randf_range(-HW + 0.8, HW - 0.8)
		_spans.append([Vector3(x1, ZT - 0.05, ROWS[i]), Vector3(x1 + rng.randf_range(-2.5, 2.5), ZT - 0.05, ROWS[i + 1]), rng.randf_range(0.5, 2.0), rng.randf_range(0.018, 0.035)])
	for k in 16:
		var z: float = ROWS[rng.randi_range(0, ROWS.size() - 1)]
		var x1 := rng.randf_range(-HW + 0.8, HW - 0.8)
		_spans.append([Vector3(x1, ZT - 0.05, z), Vector3(x1 + rng.randf_range(-4.0, 4.0), ZT - 0.05, z + rng.randf_range(-0.2, 0.2)), rng.randf_range(0.6, 2.4), 0.025])
	add_child(K.cables(_spans))
