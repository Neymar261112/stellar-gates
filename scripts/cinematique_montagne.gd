extends Node3D
## Cinématique « montagne » (30 s) : rejoue l'animation exportée de Blender (assets/cinematique/montagne.json,
## tools/exporter_cinematique_montagne.py) avec le Solaris du jeu (aegis_rig.glb, peinture de l'Atelier).
## Jouer : double-cliquer sur scenes/cinematique_montagne.tscn puis F6. Espace : rejouer, Échap : quitter.
## Vidéo : godot --path . --write-movie out.avi --fixed-fps 24 res://scenes/cinematique_montagne.tscn

const DATA := "res://assets/cinematique/montagne.json"

var fps := 24.0
var frames: Array = []
var t := 0.0
var movie := false
var skeleton: Skeleton3D
var model := Node3D.new()          # repère du Solaris (-Z devant, pieds à 0) attendu par SolarisLook
var root_local := Transform3D()    # glb dans ce repère, comme dans player.gd
var look: SolarisLook
var bone_idx := {}
var cam := Camera3D.new()
var acc := {}                      # nom Blender -> Node3D
var fade := ColorRect.new()
var onde_mat: BaseMaterial3D
var canon_light := OmniLight3D.new()
var prop_light := OmniLight3D.new()
var _onde_on := false
var _eclair_on := false
var _sensor := 36.0
var _aspect := 16.0 / 9.0


func _ready() -> void:
	movie = Engine.get_write_movie_path() != ""
	Appearance.persist = false
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DATA))
	frames = data["frames"]
	fps = float(data["fps"])
	_sensor = float(data["sensor"])
	_aspect = float(data["aspect"][0]) / float(data["aspect"][1])
	_build_environment(data["soleil"])
	_build_decor(data["vegetation"])
	_build_solaris()
	_build_accessories()
	cam.near = 0.1
	cam.far = 3000.0
	add_child(cam)
	cam.current = true
	var layer := CanvasLayer.new()
	add_child(layer)
	fade.color = Color.BLACK
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(fade)
	_apply(0.0)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and movie:
		print("[cinematique] fenêtre fermée à %.2f s" % t)


func _unhandled_input(e: InputEvent) -> void:
	if movie:
		return
	if e is InputEventKey and e.pressed:
		print("[cinematique] touche ", e.as_text())
		if e.keycode == KEY_SPACE:
			t = 0.0
			_onde_on = false
			_eclair_on = false
		elif e.keycode == KEY_ESCAPE:
			get_tree().quit()


func _process(delta: float) -> void:
	t += 1.0 / fps if movie else delta    # vidéo : exactement une image exportée par image enregistrée
	var last := (frames.size() - 1) / fps
	if t > last:
		if movie:
			print("[cinematique] fin : %.2f s" % t)
			get_tree().quit()
			return
		t = last
	_apply(t * fps)


# ------------------------------------------------------------------ lecture d'une image
static func _xf(a: Array) -> Transform3D:
	return Transform3D(Basis(Vector3(a[0], a[1], a[2]), Vector3(a[3], a[4], a[5]), Vector3(a[6], a[7], a[8])), Vector3(a[9], a[10], a[11]))


func _apply(f: float) -> void:
	var i := clampi(int(floor(f)), 0, frames.size() - 1)
	var j := mini(i + 1, frames.size() - 1)
	var k := f - i
	var a: Dictionary = frames[i]
	var b: Dictionary = frames[j]
	# une coupe (la caméra saute) : pas de fondu entre les deux images
	if _xf(a["cam"]).origin.distance_to(_xf(b["cam"]).origin) > 3.0:
		k = 0.0
	# Solaris : repère du squelette, puis pose locale de chaque os
	var skel := _xf(a["skel"]).interpolate_with(_xf(b["skel"]), k)
	model.global_transform = skel * root_local.affine_inverse()
	for bn in bone_idx:
		var pa: Array = a["bones"][bn]
		var pb: Array = b["bones"][bn]
		var id: int = bone_idx[bn]
		skeleton.set_bone_pose_position(id, Vector3(pa[0], pa[1], pa[2]).lerp(Vector3(pb[0], pb[1], pb[2]), k))
		skeleton.set_bone_pose_rotation(id, Quaternion(pa[3], pa[4], pa[5], pa[6]).slerp(Quaternion(pb[3], pb[4], pb[5], pb[6]), k))
	# caméra
	cam.global_transform = _xf(a["cam"]).interpolate_with(_xf(b["cam"]), k)
	var lens := lerpf(a["lens"], b["lens"], k)
	cam.fov = rad_to_deg(2.0 * atan(_sensor * 0.5 / lens / _aspect))
	# accessoires
	for n in acc:
		var oa: Array = a["obj"][n]
		var ob: Array = b["obj"][n]
		var node: Node3D = acc[n]
		node.visible = oa[12] > 0.5
		if node.visible:
			node.global_transform = _xf(oa).interpolate_with(_xf(ob), k)
	var eclair: bool = int(a["eclair"]) == 1 and acc["TwinVipers"].visible
	var ec: Node3D = acc["TwinVipers"].find_child("EclairCanon", true, false)
	if ec:
		ec.visible = eclair
		if eclair and not _eclair_on:
			Fx.flash(ec.global_position, Color(1.0, 0.8, 0.45), 4.0, 8.0, 0.08)
	_eclair_on = eclair
	canon_light.light_energy = 3.0 if float(a["lum_canon"]) > 0.0 and eclair else 0.0
	prop_light.light_energy = clampf(float(a["lum_prop"]) / 40.0, 0.0, 3.0)
	# onde de choc : maillage de Blender + poussière du jeu à l'impact
	var onde: Node3D = acc["OndeChoc"]
	var on: bool = onde.visible and onde.global_transform.basis.get_scale().x > 0.05
	if onde_mat:
		onde_mat.emission_energy_multiplier = float(a["onde_em"])
	if on and not _onde_on:
		var p := onde.global_position
		Fx.smoke(p + Vector3(0, 0.2, 0), 14, 2.2, 2.4, Color(0.8, 0.77, 0.7, 0.45), 0.6, 1.5, 4.0)
		Fx.debris(p + Vector3(0, 0.1, 0), Color(0.35, 0.3, 0.25), 18, 8.0)
		Fx.shake(0.4)
	_onde_on = on
	# fondu : exposition Blender (en diaphragmes) -> voile noir
	fade.color.a = clampf(1.0 - pow(2.0, float(a["expo"])), 0.0, 1.0)


# ------------------------------------------------------------------ construction
func _build_environment(sun: Dictionary) -> void:
	var env := Environment.new()
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color(0.33, 0.52, 0.82)
	sm.sky_horizon_color = Color(0.72, 0.8, 0.9)
	sm.ground_horizon_color = Color(0.6, 0.66, 0.6)
	sm.ground_bottom_color = Color(0.25, 0.3, 0.22)
	sky.sky_material = sm
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.8
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_intensity = 0.6
	env.fog_enabled = true
	env.fog_light_color = Color(0.7, 0.78, 0.88)
	env.fog_density = 0.0008
	env.fog_aerial_perspective = 0.4
	env.ssao_enabled = true
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var light := DirectionalLight3D.new()
	add_child(light)
	light.global_transform = _xf(sun["xf"])
	var c: Array = sun["couleur"]
	light.light_color = Color(c[0], c[1], c[2])
	light.light_energy = 1.3
	light.shadow_enabled = true
	light.directional_shadow_max_distance = 160.0


func _build_decor(veg: Dictionary) -> void:
	var decor: Node3D = load("res://assets/cinematique/decor_montagne.glb").instantiate()
	add_child(decor)
	for mi in decor.find_children("*", "MeshInstance3D", true, false):
		if mi.name.begins_with("Terrain"):
			var m := ShaderMaterial.new()
			m.shader = load("res://shaders/terrain_montagne.gdshader")
			mi.material_override = m
		elif mi.name.begins_with("Lac"):
			var w := StandardMaterial3D.new()
			w.albedo_color = Color(0.02, 0.12, 0.3)
			w.roughness = 0.12
			w.metallic_specular = 0.35
			mi.material_override = w
	# arbres et rochers : un MultiMesh par famille
	var protos: Node3D = load("res://assets/cinematique/vegetation.glb").instantiate()
	for fam in veg:
		var src: MeshInstance3D = protos.find_child("proto_" + fam, true, false)
		if src == null:
			continue
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = src.mesh
		var list: Array = veg[fam]
		mm.instance_count = list.size()
		for n in list.size():
			mm.set_instance_transform(n, _xf(list[n]))
		var mmi := MultiMeshInstance3D.new()
		mmi.name = fam
		mmi.multimesh = mm
		add_child(mmi)
	protos.free()


func _build_solaris() -> void:
	add_child(model)
	var root: Node3D = load("res://assets/solaris/aegis_rig.glb").instantiate()
	# même pose du glb dans son repère que dans player.gd : retourné vers -Z, pieds au sol
	var aabb := AABB()
	var first := true
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		var bb: AABB = mi.transform * mi.get_aabb()
		aabb = bb if first else aabb.merge(bb)
		first = false
	root.position.y = -aabb.position.y
	root.rotation.y = PI
	root_local = root.transform
	model.add_child(root)
	skeleton = root.find_children("*", "Skeleton3D")[0]
	for n in skeleton.get_bone_count():
		bone_idx[skeleton.get_bone_name(n)] = n
	look = SolarisLook.new()
	look.name = "Look"
	add_child(look)
	look.setup(model, skeleton, root.find_children("*", "MeshInstance3D"))


func _build_accessories() -> void:
	var src: Node3D = load("res://assets/cinematique/accessoires.glb").instantiate()
	for n in ["TwinVipers", "Flamme_dos_L", "Flamme_dos_R", "Flamme_pied_L", "Flamme_pied_R", "OndeChoc"]:
		var node: Node3D = src.find_child(n, true, false)
		if node == null:
			continue
		node.owner = null
		node.get_parent().remove_child(node)
		add_child(node)
		acc[n] = node
	src.free()
	# fusil dans le dos : même modèle, sans l'éclair
	var dos: Node3D = acc["TwinVipers"].duplicate()
	var e := dos.find_child("EclairCanon", true, false)
	if e:
		e.queue_free()
	add_child(dos)
	acc["TwinVipers_dos"] = dos
	# flammes et onde : matériaux lumineux, sans ombre
	for n in acc:
		for mi in acc[n].find_children("*", "MeshInstance3D", true, false) + [acc[n]]:
			if mi is MeshInstance3D and (n.begins_with("Flamme") or n == "OndeChoc"):
				mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				var m: Material = mi.get_active_material(0)
				if m is BaseMaterial3D:
					m = m.duplicate()
					m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
					m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
					m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
					mi.material_override = m
					if n == "OndeChoc":
						onde_mat = m
						m.emission_enabled = true
	var ec := acc["TwinVipers"].find_child("EclairCanon", true, false) as Node3D
	canon_light.light_color = Color(1.0, 0.8, 0.45)
	canon_light.omni_range = 7.0
	canon_light.light_energy = 0.0
	if ec:
		ec.add_child(canon_light)
	prop_light.light_color = Color(1.0, 0.7, 0.35)
	prop_light.omni_range = 6.0
	prop_light.light_energy = 0.0
	acc["Flamme_dos_L"].add_child(prop_light)
