class_name SolarisLook
extends Node
## L'apparence du Solaris à l'écran : les 4 pièces de silhouette accrochées aux os, les 6 zones
## (couleur + matériau), l'usure, le vinyle, et les effets qui reprennent la peinture.
## Lit l'autoload Appearance. N'écrit AUCUNE stat (règle de séparation apparence / gameplay).

signal energy_color_changed(c: Color)
signal flames_moved(pos: Vector3, spacing: float)

const SHADER := preload("res://shaders/exosuit.gdshader")
const MESHY_SHADER := preload("res://shaders/meshy_piece.gdshader")

var model: Node3D                  # repère du modèle (-Z devant, pieds à 0)
var skeleton: Skeleton3D
var pop_fx := false                # petite reconfiguration animée quand une pièce change (Forge)
var _zone_mats: Array = []         # 6 ShaderMaterial
var _body_mat: ShaderMaterial
var _attach := {}                  # os -> BoneAttachment3D
var _pieces := {}                  # slot -> Array de MeshInstance3D / lumières
var _built := {}                   # slot -> id de pièce construite
var _vinyl: MeshInstance3D
var _vinyl_mat: StandardMaterial3D
var _painted: Array = []           # nœuds extérieurs repeints (arme…)
var _core_light: OmniLight3D
var _meshy_mats := {}              # « slot:texture » -> ShaderMaterial des pièces Meshy portées
var _hide := {}                    # slot -> Array de [os, Transform3D local à l'os de l'ellipsoïde caché]
var _skin: Skin                    # skin du corps Aegis, partagée par les pièces habillées


func setup(model_node: Node3D, sk: Skeleton3D, body_meshes: Array) -> void:
	model = model_node
	skeleton = sk
	for i in 6:
		var m := ShaderMaterial.new()
		m.shader = SHADER
		m.set_shader_parameter("noise_scale", 4.0)
		_zone_mats.append(m)
	_body_mat = body_material()
	for mi in body_meshes:
		mi.material_override = _body_mat
		if mi.skin != null and _skin == null:
			_skin = mi.skin
	_vinyl_mat = StandardMaterial3D.new()
	_vinyl_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_vinyl_mat.roughness = 0.5
	_vinyl = MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.16, 0.16)
	_vinyl.mesh = q
	_vinyl.material_override = _vinyl_mat
	_vinyl.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	Appearance.changed.connect(_on_changed)
	refresh_all()


func zone_material(zone: int) -> Material:
	return _zone_mats[zone - 1]


## Repeint un nœud extérieur (lanceurs d'épaules…) : chaque MeshInstance3D qui porte la méta « zone ».
## Les armes Meshy gardent leurs textures d'origine (Combat.weapon_material), seules leurs lumières suivent l'Énergie.
func paint(node: Node) -> void:
	if not node in _painted:
		_painted.append(node)
	for mi in node.find_children("*", "MeshInstance3D", true, false) + [node]:
		if mi is MeshInstance3D and mi.has_meta("zone"):
			mi.material_override = _zone_mats[int(mi.get_meta("zone")) - 1]


## Nœud qui suit un os (la main pour l'arme).
func hand_node(bone: String) -> Node3D:
	if skeleton == null:
		return null
	return _bone_node(bone)


func _on_changed(what: String) -> void:
	match what:
		"pieces":
			_build_pieces()
			_place_vinyl()
		"paint", "wear":
			_refresh_materials()
		"vinyl":
			_place_vinyl()
		"anim":
			pass
		_:
			refresh_all()


func refresh_all() -> void:
	_built.clear()
	_refresh_materials()
	_build_pieces()
	_place_vinyl()


# ---------------------------------------------------------------- matériaux
func _refresh_materials() -> void:
	var w := Appearance.wear()
	for i in 6:
		var m: ShaderMaterial = _zone_mats[i]
		_apply_zone(m, i, w)
	_apply_meshy(_body_mat, w)
	for m in _meshy_mats.values():
		_apply_meshy(m, w)
	var energy := Appearance.color(5)
	_vinyl_mat.albedo_color = Appearance.color(2)
	_vinyl_mat.metallic = 0.2
	if _core_light:
		_core_light.light_color = energy
	energy_color_changed.emit(energy)


func _apply_zone(m: ShaderMaterial, zone: int, w: Dictionary) -> void:
	zone_params(m, Appearance.current, zone, w)


## Réglages d'un matériau de zone pour un look donné (sert aussi aux vignettes de la Forge).
static func zone_params(m: ShaderMaterial, look: Dictionary, zone: int, w: Dictionary) -> void:
	var mat := Catalog.look_material(look, zone)
	m.set_shader_parameter("base_color", Catalog.look_color(look, zone))
	m.set_shader_parameter("metallic", mat["metal"])
	m.set_shader_parameter("roughness", mat["rough"])
	m.set_shader_parameter("pattern", mat["pattern"])
	m.set_shader_parameter("glow", 2.6 if mat.get("glow", false) else 0.0)
	m.set_shader_parameter("dirt", w["dirt"])
	m.set_shader_parameter("scratches", w["scratches"])
	m.set_shader_parameter("chips", w["chips"])
	m.set_shader_parameter("fade", w["fade"])


func _apply_meshy(m: ShaderMaterial, w: Dictionary) -> void:
	meshy_params(m, Appearance.current, w)


static func meshy_params(m: ShaderMaterial, look: Dictionary, w: Dictionary) -> void:
	for z in [0, 1, 3, 5]:
		m.set_shader_parameter("z%d" % (z + 1), Catalog.look_color(look, z))
	var mats := [Catalog.look_material(look, 0), Catalog.look_material(look, 1), Catalog.look_material(look, 3)]
	m.set_shader_parameter("zone_metal", Vector3(mats[0]["metal"], mats[1]["metal"], mats[2]["metal"]))
	m.set_shader_parameter("zone_rough", Vector3(mats[0]["rough"], mats[1]["rough"], mats[2]["rough"]))
	m.set_shader_parameter("glow", 2.6 if Catalog.look_material(look, 5).get("glow", false) else 0.4)
	for k in ["dirt", "scratches", "chips", "fade"]:
		m.set_shader_parameter(k, w[k])


## Pièce Meshy : de vrais maillages texturés, repeints par les zones du preset.
## Pièce habillée (Catalog.SKINNED) : un seul maillage sur le squelette, qui plie avec le corps.
## Sinon (repli) : un maillage rigide par os, et le corps caché par des ellipsoïdes.
func _build_mesh_piece(slot: String, d: Dictionary, id: String) -> Array:
	var made := []
	var base: String = Catalog.skinned(id)
	if _skin != null and base != "" and ResourceLoader.exists(base + ".res"):
		var mesh: Mesh = load(base + ".res")
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		skeleton.add_child(mi)
		mi.skin = _skin
		mi.skeleton = NodePath("..")
		for s in mesh.get_surface_count():
			var tex: String = mesh.surface_get_name(s)    # chemin des textures de la surface
			if not _meshy_mats.has(slot + ":" + tex):
				_meshy_mats[slot + ":" + tex] = meshy_material({ "tex": tex })
			mi.set_surface_override_material(s, _meshy_mats[slot + ":" + tex])
		return [mi]
	for part in d["parts"]:
		var mesh: Mesh = load(part["res"])
		if mesh == null:
			continue
		# un morceau peut avoir sa propre texture (bras gauche et droit modélisés à part)
		var tex: String = part.get("tex", d["tex"])
		if not _meshy_mats.has(slot + ":" + tex):
			_meshy_mats[slot + ":" + tex] = meshy_material({ "tex": tex })
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.material_override = _meshy_mats[slot + ":" + tex]
		_bone_node(part["b"]).add_child(mi)
		mi.transform = _local_to_bone(part["b"], part["xf"])
		made.append(mi)
	var hides := []
	for h in d.get("hide", []):
		hides.append([h["b"], _local_to_bone(h["b"], h["xf"])])
	_hide[slot] = hides
	return made


## Corps Aegis sous une pièce habillée : caché sommet par sommet, seulement là où l'armure est devant lui.
static func body_mask(m: ShaderMaterial, slot: String, piece_id: String) -> void:
	var base: String = Catalog.skinned(piece_id)
	var tex: Texture2D = load(base + "_corps.res") if base != "" and ResourceLoader.exists(base + "_corps.res") else null
	if tex != null:
		m.set_shader_parameter("mask_" + slot, tex)
	var use: Vector4 = m.get_meta("mask_use", Vector4.ZERO)
	use[Catalog.SLOTS.find(slot)] = 1.0 if tex != null else 0.0
	m.set_meta("mask_use", use)
	m.set_shader_parameter("mask_use", use)


## Le corps Aegis (modèle Meshy de cyril, riggé) : repeint par le preset comme les pièces Meshy.
static func body_material() -> ShaderMaterial:
	var m := meshy_material({ "tex": "res://assets/solaris/aegis" })
	m.set_shader_parameter("noise_scale", 2.5)
	return m


static func meshy_material(d: Dictionary) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = MESHY_SHADER
	m.set_shader_parameter("albedo_tex", load(d["tex"] + "_albedo.png"))
	m.set_shader_parameter("normal_tex", load(d["tex"] + "_normal.png"))
	m.set_shader_parameter("rough_tex", load(d["tex"] + "_roughness.png"))
	m.set_shader_parameter("metal_tex", load(d["tex"] + "_metallic.png"))
	return m


## Transformation d'une pièce Meshy dans le repère du modèle.
## Met à jour les zones cachées du corps (elles suivent les os, donc l'animation).
func _process(_delta: float) -> void:
	if skeleton == null:
		return
	var n := 0
	for hides in _hide.values():
		for h in hides:
			if n >= 20:
				break
			var world: Transform3D = _bone_node(h[0]).global_transform * h[1]
			_body_mat.set_shader_parameter("hide%d" % n, world.affine_inverse())
			n += 1
	_body_mat.set_shader_parameter("hide_count", n)


# ---------------------------------------------------------------- pièces
func _bone_node(bone: String) -> Node3D:
	if _attach.has(bone):
		return _attach[bone]
	var a := BoneAttachment3D.new()
	a.name = "Att_" + bone
	a.bone_name = bone
	skeleton.add_child(a)
	_attach[bone] = a
	return a


## Transform d'une forme décrite dans le repère du modèle, exprimée dans le repère de l'os (pose de repos).
func _local_to_bone(bone: String, xf: Transform3D) -> Transform3D:
	var idx := skeleton.find_bone(bone)
	var skel_from_model := skeleton.global_transform.affine_inverse() * model.global_transform
	if idx < 0:
		return skel_from_model * xf
	return skeleton.get_bone_global_rest(idx).affine_inverse() * skel_from_model * xf


static func mesh_for(f: Dictionary) -> Mesh:
	var s: Vector3 = f["s"]
	match f["t"]:
		"cyl":
			var c := CylinderMesh.new()
			c.top_radius = s.x
			c.bottom_radius = s.x
			c.height = s.y
			c.radial_segments = 20
			return c
		"sph":
			var sp := SphereMesh.new()
			sp.radius = s.x
			sp.height = s.y
			return sp
		"torus":
			var t := TorusMesh.new()
			t.inner_radius = s.x
			t.outer_radius = s.y
			return t
		_:
			var b := BoxMesh.new()
			b.size = s
			return b


func _build_pieces() -> void:
	if skeleton == null:
		return
	for slot in Catalog.SLOTS:
		var id := Appearance.piece(slot)
		if _built.get(slot, "") == id:
			continue
		for n in _pieces.get(slot, []):
			if is_instance_valid(n):
				n.queue_free()
		var made := []
		var def := Catalog.piece(id)
		for k in _meshy_mats.keys():
			if k.begins_with(slot + ":"):
				_meshy_mats.erase(k)
		_hide.erase(slot)
		body_mask(_body_mat, slot, id)
		if def.has("mesh"):
			made.append_array(_build_mesh_piece(slot, def["mesh"], id))
		for f in def["shapes"]:
			var mi := MeshInstance3D.new()
			mi.mesh = mesh_for(f)
			mi.material_override = _zone_mats[int(f["z"]) - 1]
			mi.set_meta("zone", int(f["z"]))
			var xf := Transform3D(Basis.from_euler(f["r"]), f["p"])
			_bone_node(f["b"]).add_child(mi)
			mi.transform = _local_to_bone(f["b"], xf)
			made.append(mi)
		if slot == "chest":
			if def.has("light"):
				_core_light = OmniLight3D.new()
				_core_light.light_color = Appearance.color(5)
				_core_light.light_energy = 1.2
				_core_light.omni_range = 3.0
				_bone_node("chest").add_child(_core_light)
				_core_light.transform = _local_to_bone("chest", Transform3D(Basis(), def["light"]))
				made.append(_core_light)
			else:
				_core_light = null
			var fl: Vector3 = def.get("flames", Vector3(0.22, 1.2, 0.3))
			flames_moved.emit(Vector3(0, fl.y, fl.z), fl.x)
		_pieces[slot] = made
		var first_build := not _built.has(slot)
		_built[slot] = id
		if pop_fx and not first_build:
			_pop(made)
	_refresh_materials()


## Reconfiguration : les nouvelles formes grandissent depuis zéro avec une gerbe d'étincelles.
func _pop(nodes: Array) -> void:
	var c := Appearance.color(5)
	var center := Vector3.ZERO
	var n := 0
	for mi in nodes:
		if mi is MeshInstance3D:
			var target: Vector3 = mi.scale
			mi.scale = target * 0.05
			var tw: Tween = mi.create_tween()
			tw.tween_property(mi, "scale", target * 1.12, 0.22).set_delay(randf() * 0.12).set_trans(Tween.TRANS_BACK)
			tw.tween_property(mi, "scale", target, 0.12)
			center += mi.global_position
			n += 1
	if n > 0 and is_inside_tree():
		center /= n
		Fx.sparks(center, Vector3.UP, c, 26)
		Fx.ring(center, 0.9, c, 0.35, Vector3.UP, 0.05)


# ---------------------------------------------------------------- vinyle
func _place_vinyl() -> void:
	if _vinyl.get_parent():
		_vinyl.get_parent().remove_child(_vinyl)
	var vid: String = Appearance.current.get("vinyl_id", "none")
	if vid == "none":
		return
	var place: String = Appearance.current.get("vinyl_place", "chest")
	var slot := "chest" if place == "chest" or place == "back" else "arms"
	var def := Catalog.piece(Appearance.piece(slot))
	var key := "vinyl_" + place
	if not def["anchors"].has(key):
		return
	var a: Array = def["anchors"][key]
	_vinyl_mat.albedo_texture = VinylArt.texture(vid)
	(_vinyl.mesh as QuadMesh).size = Vector2(0.2, 0.2) if place == "back" else (Vector2(0.15, 0.15) if place == "chest" else Vector2(0.12, 0.12))
	var basis := Basis.from_euler(a[1]) * Basis(Vector3.UP, PI)   # le quad regarde +Z : on le tourne vers l'extérieur
	_bone_node(a[2]).add_child(_vinyl)
	_vinyl.transform = _local_to_bone(a[2], Transform3D(basis, a[0]))
