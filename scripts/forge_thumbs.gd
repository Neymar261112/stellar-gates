class_name ForgeThumbs
extends Node
## Vignettes de la Forge rendues en 3D, hors écran : pièces d'armure seules, Solaris entier avec un
## preset, sphères de matériaux et d'usure. Un petit studio (SubViewport avec son propre monde) rend
## une vignette toutes les deux images ; chaque vignette est gardée en cache selon sa clé.

signal ready_thumb(key: String)

const SIZE := 192
const SHADER := preload("res://shaders/exosuit.gdshader")

var _vp: SubViewport
var _cam: Camera3D
var _stage: Node3D                 # ce qui est rendu (vidé entre deux vignettes)
var _body_scene: PackedScene
var _cache := {}                   # clé -> ImageTexture
var _last := {}                    # nom de base -> dernière texture (affichée pendant le rendu suivant)
var _queue: Array = []             # { key, base, kind, look, id, zone, mat, wear }
var _busy := 0


func _ready() -> void:
	_vp = SubViewport.new()
	_vp.size = Vector2i(SIZE, SIZE)
	_vp.own_world_3d = true
	_vp.transparent_bg = true
	_vp.msaa_3d = Viewport.MSAA_4X
	_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_vp)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_CLEAR_COLOR
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.55, 0.6, 0.7)
	e.ambient_light_energy = 0.7
	e.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.environment = e
	_vp.add_child(env)
	var key := DirectionalLight3D.new()
	key.light_color = Color(1.0, 0.93, 0.85)
	key.light_energy = 1.6
	key.rotation = Vector3(-0.6, -0.5, 0)
	_vp.add_child(key)
	var rim := DirectionalLight3D.new()
	rim.light_color = Color(0.45, 0.7, 1.0)
	rim.light_energy = 1.4
	rim.rotation = Vector3(-0.3, PI - 0.7, 0)
	_vp.add_child(rim)
	_cam = Camera3D.new()
	_cam.fov = 30.0
	_vp.add_child(_cam)
	_stage = Node3D.new()
	_vp.add_child(_stage)
	_body_scene = load("res://assets/solaris/aegis_rig.glb")


## Texture d'une vignette : celle du cache, sinon la dernière de la même famille, et le rendu est lancé.
func get_thumb(job: Dictionary) -> Texture2D:
	var k: String = job["key"]
	if _cache.has(k):
		return _cache[k]
	var pending := false
	for q in _queue:
		if q["key"] == k:
			pending = true
	if not pending:
		_queue.append(job)
	return _last.get(job["base"], null)


static func look_key(look: Dictionary) -> String:
	return JSON.stringify([look["color_slots"], look["material_slots"], look.get("wear_state", ""), look.get("wear_amount", 1.0)]).md5_text()


## Une pièce seule, peinte avec le look donné.
func piece(id: String, look: Dictionary) -> Texture2D:
	return get_thumb({ "key": "p:%s:%s" % [id, look_key(look)], "base": "p:" + id, "kind": "piece", "id": id, "look": look.duplicate(true) })


## Le Solaris entier avec un preset (pièces, peinture, usure).
func preset(look: Dictionary, tag: String) -> Texture2D:
	var k := JSON.stringify(look).md5_text()
	return get_thumb({ "key": "s:" + k, "base": "s:" + tag, "kind": "suit", "look": look.duplicate(true) })


## Une sphère d'un matériau, dans la couleur de la zone.
func material_ball(mat_id: String, look: Dictionary, zone: int) -> Texture2D:
	var l := look.duplicate(true)
	l["material_slots"][zone] = mat_id
	l["wear_amount"] = 0.0
	var k := "m:%s:%s:%d" % [mat_id, l["color_slots"][zone], zone]
	return get_thumb({ "key": k, "base": "m:" + mat_id, "kind": "ball", "look": l, "zone": zone })


## Une sphère d'un type d'usure, à fond, sur la zone principale.
func wear_ball(wear_id: String, look: Dictionary) -> Texture2D:
	var l := look.duplicate(true)
	l["wear_state"] = wear_id
	l["wear_amount"] = 1.0
	var k := "w:%s:%s:%s" % [wear_id, l["color_slots"][0], l["material_slots"][0]]
	return get_thumb({ "key": k, "base": "w:" + wear_id, "kind": "ball", "look": l, "zone": 0 })


func _process(_delta: float) -> void:
	if _busy > 0:
		_busy -= 1
		if _busy == 0:
			var job: Dictionary = _queue.pop_front()
			var img := _vp.get_texture().get_image()
			var tex := ImageTexture.create_from_image(img)
			_cache[job["key"]] = tex
			_last[job["base"]] = tex
			ready_thumb.emit(job["key"])
		return
	if _queue.is_empty():
		return
	_build(_queue[0])
	_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	_busy = 1


# ---------------------------------------------------------------- mise en scène
func _zone_mats(look: Dictionary) -> Array:
	var w := Catalog.look_wear(look)
	var mats := []
	for z in 6:
		var m := ShaderMaterial.new()
		m.shader = SHADER
		m.set_shader_parameter("noise_scale", 4.0)
		SolarisLook.zone_params(m, look, z, w)
		mats.append(m)
	return mats


func _add_piece(id: String, look: Dictionary, mats: Array) -> void:
	var def := Catalog.piece(id)
	for f in def["shapes"]:
		var mi := MeshInstance3D.new()
		mi.mesh = SolarisLook.mesh_for(f)
		mi.material_override = mats[int(f["z"]) - 1]
		mi.transform = Transform3D(Basis.from_euler(f["r"]), f["p"])
		_stage.add_child(mi)
	if def.has("mesh"):
		var d: Dictionary = def["mesh"]
		var pmats := {}
		var base: String = Catalog.skinned(id)
		if base != "" and ResourceLoader.exists(base + ".res"):
			# pièce habillée : le maillage soudé, au repos (comme sur le Solaris immobile)
			var mesh: Mesh = load(base + ".res")
			var smi := MeshInstance3D.new()
			smi.mesh = mesh
			smi.transform = mesh.get_meta("model_from_skel", Transform3D.IDENTITY)
			for s in mesh.get_surface_count():
				var tex: String = mesh.surface_get_name(s)
				if not pmats.has(tex):
					pmats[tex] = SolarisLook.meshy_material({ "tex": tex })
					SolarisLook.meshy_params(pmats[tex], look, Catalog.look_wear(look))
				smi.set_surface_override_material(s, pmats[tex])
			_stage.add_child(smi)
			return
		for part in d["parts"]:
			var tex: String = part.get("tex", d["tex"])
			if not pmats.has(tex):
				pmats[tex] = SolarisLook.meshy_material({ "tex": tex })
				SolarisLook.meshy_params(pmats[tex], look, Catalog.look_wear(look))
			var mi := MeshInstance3D.new()
			mi.mesh = load(part["res"])
			mi.material_override = pmats[tex]
			mi.transform = part["xf"]
			_stage.add_child(mi)


func _add_body(look: Dictionary) -> void:
	if _body_scene == null:
		return
	var root := _body_scene.instantiate()
	var m := SolarisLook.body_material()
	SolarisLook.meshy_params(m, look, Catalog.look_wear(look))
	var low := INF
	for mi in root.find_children("*", "MeshInstance3D"):
		mi.material_override = m
		var a: AABB = mi.mesh.get_aabb()
		low = minf(low, (mi.transform * a).position.y)
	# même pose que le Solaris du jeu : retourné face à -Z, pieds au sol
	root.position.y = -low if low != INF else 0.0
	root.rotation.y = PI
	_stage.add_child(root)
	# les pièces Meshy cachent les parties du corps qu'elles recouvrent (comme dans le jeu)
	var n := 0
	for s in Catalog.SLOTS:
		var pid: String = look.get(s + "_piece_id", "")
		SolarisLook.body_mask(m, s, pid)
		if Catalog.skinned(pid) != "":
			continue     # pièce habillée : masque sommet par sommet au lieu des ellipsoïdes
		var md := Catalog.mesh_def(pid)
		for h in md.get("hide", []):
			if n < 20:
				m.set_shader_parameter("hide%d" % n, (h["xf"] as Transform3D).affine_inverse())
				n += 1
	m.set_shader_parameter("hide_count", n)


func _frame(focus: Vector3, dist: float, yaw := 0.45, pitch := 0.12) -> void:
	var dir := Vector3(sin(yaw) * cos(pitch), sin(pitch), -cos(yaw) * cos(pitch))
	_cam.look_at_from_position(focus + dir * dist, focus)


func _build(job: Dictionary) -> void:
	for c in _stage.get_children():
		_stage.remove_child(c)
		c.queue_free()
	var look: Dictionary = job["look"]
	match job["kind"]:
		"piece":
			var id: String = job["id"]
			_add_piece(id, look, _zone_mats(look))
			match Catalog.slot_of(id):
				"helmet":
					_frame(Vector3(0, 1.82, 0), 1.05, 0.55)
				"chest":
					_frame(Vector3(0, 1.36, 0.05), 1.9, 0.6)
				"arms":
					_frame(Vector3(0, 1.38, 0), 2.6, 0.35)
				_:
					_frame(Vector3(0, 0.5, 0), 2.2, 0.4)
		"suit":
			var mats := _zone_mats(look)
			_add_body(look)
			for s in Catalog.SLOTS:
				var id: String = look.get(s + "_piece_id", "ranger.default." + s)
				if not Catalog.has_piece(id):
					id = "ranger.default." + s
				_add_piece(id, look, mats)
			_frame(Vector3(0, 1.0, 0), 4.3, 0.35, 0.08)
		"ball":
			var mats := _zone_mats(look)
			var mi := MeshInstance3D.new()
			var sm := SphereMesh.new()
			sm.radius = 0.5
			sm.height = 1.0
			sm.radial_segments = 48
			sm.rings = 24
			mi.mesh = sm
			mi.material_override = mats[job["zone"]]
			_stage.add_child(mi)
			_frame(Vector3.ZERO, 3.4, 0.3, 0.2)
