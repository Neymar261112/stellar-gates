extends Node3D
## Construit une carte (voir maps.gd) : dalles fusionnées, rampe, toit de zone cachée, rochers, props, balises, Arche.

signal message(text: String, seconds: float)
signal beacons_changed(got: int, total: int)
signal arche_entered(to_id: String)
signal targets_changed(down: int, total: int)
signal wave_changed(wave: int, total: int, remaining: int)

const T := 2.5
const PLATEAU := 3.0
const PIT := -9.0

var def: Dictionary
var grid: Array = []
var W := 0
var H := 0
var hidden_found := false
var beacons_got := 0
var arche_ready := false
var _roof: MeshInstance3D
var _roof_mat: StandardMaterial3D
var _player: Node3D
var _mats := {}
var _rng := RandomNumberGenerator.new()
var _beacon_nodes: Array = []
var _arche: Node3D
var targets_down := 0
var arena: Node3D
var _targets: Array = []


func setup(map_def: Dictionary) -> void:
	def = map_def
	grid = def["grid"]
	H = grid.size()
	W = grid[0].size()
	_rng.seed = def["props"]["seed"]


func _ready() -> void:
	_make_materials()
	_build_terrain()
	_build_props()
	_build_beacons()
	_build_arche()
	_player = get_parent().get_node_or_null("Player")
	_build_targets()
	_build_arena()
	_build_cascades()
	_build_crates()
	_build_covers()
	get_tree().create_timer(2.0).timeout.connect(func(): arche_ready = true)


# ---------------------------------------------------------------- requêtes
func start_position() -> Vector3:
	return cell_center(def["start"]) + Vector3(0, 0.2, 0)


func arrival_position() -> Vector3:
	var a: Dictionary = def["arche"]
	return cell_center(a["cell"]) + a["facing"] * 4.0 + Vector3(0, 0.2, 0)


func cell_center(c: Vector2i) -> Vector3:
	return Vector3(c.x * T + T / 2.0, ground_height_cell(c), c.y * T + T / 2.0)


func tile_at(pos: Vector3) -> String:
	var i := int(floor(pos.x / T))
	var j := int(floor(pos.z / T))
	if j < 0 or j >= H or i < 0 or i >= W:
		return "X"
	return grid[j][i]


func ground_height_cell(c: Vector2i) -> float:
	match grid[c.y][c.x]:
		"#": return PLATEAU
		"~": return PIT
		"w": return -0.5
		"X": return 6.0
		_: return 0.0


func is_walkable(t: String) -> bool:
	return t in [".", "#", "=", "h", "w"]


# ---------------------------------------------------------------- matériaux
static var _noise_tex: NoiseTexture2D
static var _noise_nrm: NoiseTexture2D


static func _shared_noise() -> void:
	if _noise_tex != null:
		return
	var n := FastNoiseLite.new()
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.frequency = 0.03
	n.fractal_octaves = 4
	_noise_tex = NoiseTexture2D.new()
	_noise_tex.noise = n
	_noise_tex.seamless = true
	_noise_tex.width = 512
	_noise_tex.height = 512
	_noise_tex.color_ramp = Gradient.new()
	_noise_tex.color_ramp.set_color(0, Color(0.45, 0.45, 0.45))
	_noise_tex.color_ramp.set_color(1, Color(0.95, 0.95, 0.95))
	var n2 := FastNoiseLite.new()
	n2.noise_type = FastNoiseLite.TYPE_CELLULAR
	n2.frequency = 0.06
	_noise_nrm = NoiseTexture2D.new()
	_noise_nrm.noise = n2
	_noise_nrm.seamless = true
	_noise_nrm.as_normal_map = true
	_noise_nrm.bump_strength = 6.0
	_noise_nrm.width = 512
	_noise_nrm.height = 512


func _mat(color: Color, rough := 0.95, metal := 0.0, textured := true) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	m.metallic = metal
	if textured:
		_shared_noise()
		m.albedo_texture = _noise_tex
		m.normal_enabled = true
		m.normal_texture = _noise_nrm
		m.normal_scale = 0.6
		m.uv1_triplanar = true
		m.uv1_scale = Vector3(0.12, 0.12, 0.12)
	return m


func _make_materials() -> void:
	var p: Dictionary = def["palette"]
	_mats = {}
	for k in [".", "=", "#", "h", "X", "o"]:
		_mats[k] = _mat(p[k])
	_mats["w"] = _mat(p["w"], 0.2, 0.1, false)
	_mats["w"].transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mats["w"].albedo_color.a = 0.85
	_mats["~"] = _mat(p["~"], 0.9, 0.0, false)
	var glow: Color = def["pit_glow"]
	if glow.r + glow.g + glow.b > 0.1:
		_mats["~"].emission_enabled = true
		_mats["~"].emission = glow
		_mats["~"].emission_energy_multiplier = 2.5


# ---------------------------------------------------------------- terrain
func _box(parent: Node3D, body: StaticBody3D, center: Vector3, size: Vector3, mat: Material, collide := true, rot_x := 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = center
	mi.rotation.x = rot_x
	parent.add_child(mi)
	if collide:
		var cs := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		cs.shape = shape
		cs.position = center
		cs.rotation.x = rot_x
		body.add_child(cs)
	return mi


func _base_type(t: String) -> String:
	if t == "o" or t == "=":
		return "."
	return t


func _build_terrain() -> void:
	var visuals := Node3D.new()
	visuals.name = "Terrain"
	add_child(visuals)
	var body := StaticBody3D.new()
	body.name = "TerrainBody"
	add_child(body)
	for j in H:
		var i := 0
		while i < W:
			var base := _base_type(grid[j][i])
			var n := 1
			while i + n < W and _base_type(grid[j][i + n]) == base:
				n += 1
			var x := (i + n / 2.0) * T
			var z := j * T + T / 2.0
			match base:
				".": _box(visuals, body, Vector3(x, -0.5, z), Vector3(n * T, 1.0, T), _mats["."])
				"h": _box(visuals, body, Vector3(x, -0.5, z), Vector3(n * T, 1.0, T), _mats["h"])
				"#": _box(visuals, body, Vector3(x, PLATEAU / 2.0 - 0.5, z), Vector3(n * T, PLATEAU + 1.0, T), _mats["#"])
				"X": _box(visuals, body, Vector3(x, 2.5, z), Vector3(n * T, 7.0, T), _mats["X"])
				"~": _box(visuals, body, Vector3(x, PIT - 0.5, z), Vector3(n * T, 1.0, T), _mats["~"])
				"w": _box(visuals, body, Vector3(x, -1.0, z), Vector3(n * T, 1.0, T), _mats["w"])
			i += n
	# Rochers
	for j in H:
		for i in W:
			if grid[j][i] == "o":
				_rock(visuals, body, Vector3(i * T + T / 2.0, 0.55, j * T + T / 2.0), 1.0)
	# Rampe inclinée
	var ramp: Dictionary = def["ramp"]
	var rc: Rect2i = ramp["cells"]
	var len := sqrt(pow(rc.size.y * T, 2) + pow(PLATEAU, 2))
	var cx := (rc.position.x + rc.size.x / 2.0) * T
	var cz := (rc.position.y + rc.size.y / 2.0) * T
	_box(visuals, body, Vector3(cx, PLATEAU / 2.0 - 0.3, cz), Vector3(rc.size.x * T, 0.6, len), _mats["="], true, atan2(PLATEAU, rc.size.y * T))
	# Toit de la zone cachée
	var roof: Rect2i = def["roof"]
	_roof_mat = _mat(def["palette"]["roof"])
	_roof_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_roof = MeshInstance3D.new()
	var rm := BoxMesh.new()
	rm.size = Vector3(roof.size.x * T, 0.8, roof.size.y * T)
	_roof.mesh = rm
	_roof.material_override = _roof_mat
	_roof.position = Vector3((roof.position.x + roof.size.x / 2.0) * T, 6.2, (roof.position.y + roof.size.y / 2.0) * T)
	visuals.add_child(_roof)
	# Marque de départ
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 1.2
	tm.outer_radius = 1.4
	ring.mesh = tm
	var ringmat := _mat(Color(0.84, 0.65, 0.25), 0.5, 0.0, false)
	ringmat.emission_enabled = true
	ringmat.emission = Color(0.84, 0.65, 0.25)
	ring.material_override = ringmat
	ring.position = cell_center(def["start"]) + Vector3(0, 0.05, 0)
	visuals.add_child(ring)


func _rock(visuals: Node3D, body: StaticBody3D, c: Vector3, s: float) -> void:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 1.0
	sm.height = 1.6
	sm.radial_segments = 7
	sm.rings = 4
	mi.mesh = sm
	mi.material_override = _mats["o"]
	mi.position = c
	mi.rotation.y = _rng.randf() * TAU
	mi.scale = Vector3(1.1, 0.75, 0.95) * s
	visuals.add_child(mi)
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(1.8, 1.1, 1.6) * s
	cs.shape = sh
	cs.position = c
	body.add_child(cs)


# ---------------------------------------------------------------- props (décor sans collision)
func _build_props() -> void:
	var props: Dictionary = def["props"]
	var visuals: Node3D = get_node("Terrain")
	var body: StaticBody3D = get_node("TerrainBody")
	var free_cells: Array = []
	for j in range(1, H - 1):
		for i in range(1, W - 1):
			if grid[j][i] == "." and not _near(i, j, def["start"]) and not _near(i, j, def["arche"]["cell"]) and not _near_target(i, j):
				free_cells.append(Vector2i(i, j))
	free_cells.shuffle()
	# Monticules : demi-sphères enterrées, on marche dessus (pas de collision, trop bas)
	var mound_mat := _mat(def["palette"]["."].darkened(0.12))
	for k in mini(props["mounds"], free_cells.size()):
		var c: Vector2i = free_cells[k]
		var mi := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 1.0
		sm.height = 2.0
		sm.radial_segments = 12
		sm.rings = 6
		mi.mesh = sm
		mi.material_override = mound_mat
		var r := _rng.randf_range(1.5, 3.5)
		mi.scale = Vector3(r, r * 0.12, r * _rng.randf_range(0.7, 1.3))
		mi.position = Vector3(c.x * T + _rng.randf_range(0.5, 2.0), -0.02, c.y * T + _rng.randf_range(0.5, 2.0))
		mi.rotation.y = _rng.randf() * TAU
		visuals.add_child(mi)
	# Piliers / cristaux : hauts, avec collision
	var pillar_mat := _mat(def["palette"]["X"].lightened(0.15), 0.7)
	for k in range(props["mounds"], mini(props["mounds"] + props["pillars"], free_cells.size())):
		var c: Vector2i = free_cells[k]
		var mi := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		var h := _rng.randf_range(4.0, 9.0)
		cm.height = h
		cm.bottom_radius = _rng.randf_range(0.6, 1.1)
		cm.top_radius = cm.bottom_radius * _rng.randf_range(0.2, 0.6)
		cm.radial_segments = 6
		mi.mesh = cm
		mi.material_override = pillar_mat
		var pos := Vector3(c.x * T + T / 2.0, h / 2.0 - 0.3, c.y * T + T / 2.0)
		mi.position = pos
		mi.rotation = Vector3(_rng.randf_range(-0.12, 0.12), _rng.randf() * TAU, _rng.randf_range(-0.12, 0.12))
		visuals.add_child(mi)
		var cs := CollisionShape3D.new()
		var sh := CylinderShape3D.new()
		sh.height = h
		sh.radius = cm.bottom_radius
		cs.shape = sh
		cs.position = pos
		body.add_child(cs)


func _near(i: int, j: int, c: Vector2i) -> bool:
	return absi(i - c.x) <= 2 and absi(j - c.y) <= 2


func _near_target(i: int, j: int) -> bool:
	for t in def.get("targets", []):
		var c: Vector2i = t["cell"]
		if absi(i - c.x) <= 1 and absi(j - c.y) <= 1:
			return true
	return false


# ---------------------------------------------------------------- cibles d'entraînement
func _build_targets() -> void:
	_targets.clear()
	for t in def.get("targets", []):
		var tgt := TrainingTarget.new()
		tgt.name = "Cible_%s_%d" % [t["kind"], _targets.size()]
		tgt.setup(t["kind"], cell_center(t["cell"]) + Vector3(0, t.get("height", 0.0), 0))
		tgt.player = _player
		tgt.destroyed.connect(_on_target_destroyed)
		add_child(tgt)
		_targets.append(tgt)


func _on_target_destroyed(_t: TrainingTarget) -> void:
	targets_down += 1
	targets_changed.emit(targets_down, _targets.size())
	message.emit("Cible détruite !", 1.0)


func targets_total() -> int:
	return _targets.size()


func _build_arena() -> void:
	if not def.has("arena"):
		return
	arena = load("res://scripts/arena.gd").new()
	arena.name = "Arena"
	arena.setup(def["arena"], self, _player)
	arena.wave_changed.connect(func(w: int, t: int, r: int): wave_changed.emit(w, t, r))
	arena.arena_cleared.connect(func(): Expedition.on_arena_cleared(def["id"]))   # fin de mission : butin révélé
	add_child(arena)


# ---------------------------------------------------------------- cachettes
## Murets (on s'accroupit derrière) et murs hauts (on en sort sur le côté pour tirer) du champ de tir.
func _build_covers() -> void:
	if not def.has("covers"):
		return
	var body := StaticBody3D.new()
	body.name = "Couverts"
	add_child(body)
	var vis := Node3D.new()
	body.add_child(vis)
	var wall_mat := _mat(def["palette"]["X"].lightened(0.18), 0.8, 0.2)
	var band := StandardMaterial3D.new()
	band.albedo_color = Color(0.95, 0.55, 0.15)
	band.emission_enabled = true
	band.emission = Color(0.95, 0.5, 0.1)
	band.emission_energy_multiplier = 0.6
	for c in def["covers"]:
		var low: bool = c["low"]
		var length: float = c.get("len", 3.6)
		var h := 1.15 if low else 2.9
		var holder := Node3D.new()
		holder.position = Vector3(c["x"] * T, 0.0, c["z"] * T)
		holder.rotation.y = c.get("rot", 0.0)
		vis.add_child(holder)
		var sub := StaticBody3D.new()
		holder.add_child(sub)
		_box(holder, sub, Vector3(0, h / 2.0, 0), Vector3(length, h, 0.6), wall_mat)
		_box(holder, sub, Vector3(0, h - 0.12, 0), Vector3(length + 0.1, 0.12, 0.7), band, false)
		for x in [-length / 2.0 + 0.2, length / 2.0 - 0.2]:   # pieds renforcés
			_box(holder, sub, Vector3(x, 0.2, 0), Vector3(0.3, 0.4, 1.1), wall_mat, false)


# ---------------------------------------------------------------- balises
func _build_crates() -> void:
	for c in def.get("crates", []):
		var crate: Area3D = load("res://scripts/part_crate.gd").new()
		var pos := cell_center(c["cell"])
		pos.y = ground_height_cell(c["cell"])
		crate.setup(c["slot"], c["tier"], pos)
		add_child(crate)


func _build_beacons() -> void:
	_beacon_nodes.clear()
	for b in def["beacons"]:
		var area := Area3D.new()
		area.name = "Balise_" + b["label"]
		area.position = cell_center(b["cell"])
		var cs := CollisionShape3D.new()
		var sh := CylinderShape3D.new()
		sh.radius = 1.4
		sh.height = 4.0
		cs.shape = sh
		cs.position.y = 2.0
		area.add_child(cs)
		var mi := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.35
		cm.bottom_radius = 0.5
		cm.height = 2.2
		mi.mesh = cm
		var m := _mat(Color(0.35, 0.84, 0.54), 0.4, 0.0, false)
		m.emission_enabled = true
		m.emission = Color(0.16, 0.6, 0.33)
		m.emission_energy_multiplier = 1.5
		mi.material_override = m
		mi.position.y = 1.1
		area.add_child(mi)
		var light := OmniLight3D.new()
		light.light_color = Color(0.35, 0.84, 0.54)
		light.light_energy = 1.5
		light.omni_range = 8.0
		light.position.y = 1.5
		area.add_child(light)
		area.body_entered.connect(_on_beacon_entered.bind(area, b["label"]))
		add_child(area)
		_beacon_nodes.append(area)


func _on_beacon_entered(body: Node3D, area: Area3D, label: String) -> void:
	if not body.is_in_group("player") or not area.visible:
		return
	area.visible = false
	area.set_deferred("monitoring", false)
	beacons_got += 1
	beacons_changed.emit(beacons_got, def["beacons"].size())
	if beacons_got == def["beacons"].size():
		message.emit("Toutes les balises de %s sont récupérées !" % def["name"], 3.0)
	else:
		message.emit("Balise « %s » récupérée" % label, 2.5)


# ---------------------------------------------------------------- cascades (zones de refroidissement)
func _build_cascades() -> void:
	for c in def.get("cascades", []):
		var cell: Vector2i = c["cell"]
		var w: float = c["width"] * T
		var h: float = c["height"]
		var node := Node3D.new()
		node.name = "Cascade"
		node.position = Vector3(cell.x * T + T / 2.0, 0.0, cell.y * T)
		add_child(node)
		# Rideau d'eau : un plan vertical translucide animé par le bruit
		var sheet := MeshInstance3D.new()
		var pm := PlaneMesh.new()
		pm.size = Vector2(w, h)
		sheet.mesh = pm
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.7, 0.85, 1.0, 0.55)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.emission_enabled = true
		m.emission = Color(0.5, 0.7, 0.9)
		m.emission_energy_multiplier = 0.4
		_shared_noise()
		m.albedo_texture = _noise_tex
		m.uv1_scale = Vector3(1, 3, 1)
		sheet.material_override = m
		sheet.position.y = h / 2.0
		sheet.rotation.x = PI / 2.0
		node.add_child(sheet)
		var mist := OmniLight3D.new()
		mist.light_color = Color(0.6, 0.8, 1.0)
		mist.light_energy = 1.2
		mist.omni_range = 8.0
		mist.position.y = 1.0
		node.add_child(mist)
		# Zone : voler à travers refroidit les propulseurs
		var area := Area3D.new()
		var cs := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		sh.size = Vector3(w, h + 1.0, 1.6)
		cs.shape = sh
		cs.position.y = h / 2.0
		area.add_child(cs)
		area.body_entered.connect(func(b: Node3D): if b.has_method("enter_cooling_zone"): b.enter_cooling_zone())
		area.body_exited.connect(func(b: Node3D): if b.has_method("exit_cooling_zone"): b.exit_cooling_zone())
		node.add_child(area)


func _process_cascades(delta: float) -> void:
	for n in get_children():
		if n.name == "Cascade":
			var sheet: MeshInstance3D = n.get_child(0)
			sheet.material_override.uv1_offset.y -= delta * 0.8


# ---------------------------------------------------------------- Arche
func _build_arche() -> void:
	var a: Dictionary = def["arche"]
	_arche = Node3D.new()
	_arche.name = "Arche"
	_arche.position = cell_center(a["cell"])
	add_child(_arche)
	var stone := _mat(Color(0.35, 0.33, 0.30), 0.8)
	# Anneau vertical
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 2.6
	tm.outer_radius = 3.1
	tm.rings = 48
	ring.mesh = tm
	ring.material_override = stone
	ring.position.y = 3.0
	ring.rotation.x = PI / 2.0
	_arche.add_child(ring)
	# Socle
	var base := MeshInstance3D.new()
	var bm := CylinderMesh.new()
	bm.top_radius = 3.4
	bm.bottom_radius = 3.8
	bm.height = 0.1     # assez bas pour que le Solaris monte dessus sans sauter
	base.mesh = bm
	base.material_override = stone
	base.position.y = 0.05
	_arche.add_child(base)
	# Voile d'énergie (plan dans l'anneau)
	var veil := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(5.2, 5.2)
	veil.mesh = pm
	var vm := StandardMaterial3D.new()
	vm.albedo_color = Color(0.45, 0.75, 1.0, 0.35)
	vm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	vm.emission_enabled = true
	vm.emission = Color(0.4, 0.7, 1.0)
	vm.emission_energy_multiplier = 2.0
	vm.cull_mode = BaseMaterial3D.CULL_DISABLED
	vm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	veil.material_override = vm
	veil.position.y = 3.0
	veil.rotation.x = PI / 2.0
	_arche.add_child(veil)
	var light := OmniLight3D.new()
	light.light_color = Color(0.45, 0.75, 1.0)
	light.light_energy = 3.0
	light.omni_range = 14.0
	light.position.y = 3.0
	_arche.add_child(light)
	# Zone de passage
	var area := Area3D.new()
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(5.0, 6.0, 1.2)
	cs.shape = sh
	cs.position.y = 3.0
	area.add_child(cs)
	area.body_entered.connect(_on_arche_entered)
	_arche.add_child(area)
	# Socle de collision (on marche dessus)
	var body := StaticBody3D.new()
	var bcs := CollisionShape3D.new()
	var bsh := CylinderShape3D.new()
	bsh.radius = 3.6
	bsh.height = 0.1
	bcs.shape = bsh
	bcs.position.y = 0.05
	body.add_child(bcs)
	_arche.add_child(body)


func _on_arche_entered(body: Node3D) -> void:
	if not body.is_in_group("player") or not arche_ready:
		return
	arche_ready = false
	message.emit("L'Arche réagit au Solaris…", 2.0)
	arche_entered.emit(def["arche"]["to"])


# ---------------------------------------------------------------- vie de la zone
func _process(delta: float) -> void:
	if _player == null:
		return
	var t := tile_at(_player.global_position)
	if t == "h" and not hidden_found:
		hidden_found = true
		message.emit("Zone cachée découverte !", 3.0)
	var target_alpha := 0.0 if t == "h" else 1.0
	_roof_mat.albedo_color.a = lerp(_roof_mat.albedo_color.a, target_alpha, minf(1.0, delta * 3.0))
	_roof.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if _roof_mat.albedo_color.a > 0.5 else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for a in _beacon_nodes:
		if a.visible:
			a.rotation.y += delta
	if _arche:
		_arche.get_child(0).rotation.y += delta * 0.3
	_process_cascades(delta)
