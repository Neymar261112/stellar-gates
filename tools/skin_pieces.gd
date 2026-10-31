extends Node
## Habille les pièces Meshy sur le squelette du Solaris (à relancer quand une pièce change ou qu'on en ajoute une).
## godot --headless --path . res://tools/skin_pieces.tscn   (certaines pièces : PIECE=ranger.mech.legs,ranger.exo.arms)
##
## Pour chaque pièce de Catalog.skinned_ids() :
## 1. ses morceaux (Catalog.mesh_def : posés sur les os gauche/droit au repos) sont soudés en un seul maillage
##    dans le repère du squelette ;
## 2. chaque sommet reprend les poids du corps Aegis juste en dessous (point le plus proche sur la surface du
##    corps, poids interpolés sur le triangle), limités aux os du membre : l'armure plie aux articulations
##    exactement comme le corps ;
## 3. le corps n'est caché que sommet par sommet, là où l'armure est vraiment devant lui (voir _hide_mask) :
##    il y a toujours un corps ailleurs, et le masque suit l'animation puisqu'il est attaché aux sommets.
## Sorties : <Catalog.skinned(id)>.res (maillage avec os et poids) et <...>_corps.res (masque du corps).

const CELL := 0.04             # m : taille d'une case de la grille de recherche
const HIDE_REACH := 0.12       # m : armure jusqu'à cette distance au-dessus du corps -> corps caché
const HIDE_DEPTH := 0.12       # m : corps qui dépasse de l'armure jusqu'à cette distance -> caché aussi

## Os qu'un morceau accroché à l'os X peut suivre (voisins dans la chaîne ; le côté est ajouté).
const ALLOWED := {
	"head": ["head", "neck"],
	"chest": ["hips", "spine", "chest", "neck", "shoulder_L", "shoulder_R"],
	"upper_arm": ["shoulder", "upper_arm", "forearm"],
	"forearm": ["upper_arm", "forearm", "hand"],
	"hand": ["forearm", "hand"],
	"thigh": ["hips", "thigh", "shin"],
	"shin": ["thigh", "shin", "foot"],
	"foot": ["shin", "foot"],
}

var sk: Skeleton3D
var skin: Skin
var body_mi: MeshInstance3D
var bv: PackedVector3Array      # corps : sommets au repos (repère du squelette)
var bn: PackedVector3Array
var bb: PackedInt32Array        # 4 os (index de bind) par sommet
var bw: PackedFloat32Array
var bi: PackedInt32Array
var vtris := []                 # sommet -> triangles qui le touchent
var dominant: PackedInt32Array  # sommet -> bind le plus lourd
var grids := {}                 # clé d'os permis -> grille
var bind_of := {}               # nom d'os -> index de bind
var groups := []                # sommets du corps soudés par position
var group_of := PackedInt32Array()
var gpos := PackedVector3Array()
var gnor := PackedVector3Array()


func _ready() -> void:
	var p = load("res://scenes/player.tscn").instantiate()
	add_child(p)
	await get_tree().process_frame
	sk = p.look.skeleton
	for mi in p.model.find_children("*", "MeshInstance3D", true, false):
		if mi.skin != null:
			body_mi = mi
	skin = body_mi.skin
	for i in skin.get_bind_count():
		bind_of[skin.get_bind_name(i)] = i
	var a: Array = body_mi.mesh.surface_get_arrays(0)
	bv = a[Mesh.ARRAY_VERTEX]
	bn = a[Mesh.ARRAY_NORMAL]
	bb = a[Mesh.ARRAY_BONES]
	bw = a[Mesh.ARRAY_WEIGHTS]
	bi = a[Mesh.ARRAY_INDEX]
	dominant.resize(bv.size())
	for v in bv.size():
		var best := 0
		for k in 4:
			if bw[v * 4 + k] > bw[v * 4 + best]:
				best = k
		dominant[v] = bb[v * 4 + best]
	vtris.resize(bv.size())
	for v in bv.size():
		vtris[v] = PackedInt32Array()
	for t in bi.size() / 3:
		for k in 3:
			vtris[bi[t * 3 + k]].append(t)
	# repère du modèle (pieds à 0, -Z devant) -> repère du squelette, comme SolarisLook._local_to_bone
	var skel_from_model: Transform3D = sk.global_transform.affine_inverse() * p.model.global_transform
	_weld()
	var only := OS.get_environment("PIECE")
	for id in Catalog.skinned_ids():
		if only != "" and not id in only.split(","):
			continue
		var base: String = Catalog.skinned(id)
		var t0 := Time.get_ticks_msec()
		var mesh := _skin_piece(id, skel_from_model)
		mesh.set_meta("model_from_skel", skel_from_model.affine_inverse())
		ResourceSaver.save(mesh, base + ".res")
		print("%s : %d sommets, %d ms -> %s.res" % [id, _vcount(mesh), Time.get_ticks_msec() - t0, base])
		_save_mask(await _hide_mask(mesh, id), base + "_corps.res")
	get_tree().quit()


func _vcount(m: ArrayMesh) -> int:
	var n := 0
	for s in m.get_surface_count():
		n += m.surface_get_array_len(s)
	return n


# ---------------------------------------------------------------- 1 + 2 : morceaux soudés et poids du corps
func _skin_piece(id: String, skel_from_model: Transform3D) -> ArrayMesh:
	var d := Catalog.mesh_def(id)
	var surfaces := {}           # texture -> tableaux en cours
	for part in d["parts"]:
		var tex: String = part.get("tex", d["tex"])
		if not surfaces.has(tex):
			surfaces[tex] = { "v": PackedVector3Array(), "n": PackedVector3Array(), "t": PackedFloat32Array(), "uv": PackedVector2Array(),
				"b": PackedInt32Array(), "w": PackedFloat32Array(), "i": PackedInt32Array() }
		var s: Dictionary = surfaces[tex]
		# pièce préparée par tools/meshy_pieces.py : <dossier>/src/<nom>.glb -> <dossier>/<nom>.res
		var glb: String = part.get("src", part["res"].get_base_dir() + "/src/" + part["res"].get_file().get_basename() + ".glb")
		if ResourceLoader.exists(glb) and (not ResourceLoader.exists(part["res"]) or OS.get_environment("RECONVERT") != ""):
			_mesh_from_glb(glb, part["res"])
		var src: Mesh = load(part["res"])
		var a: Array = src.surface_get_arrays(0)
		var xf: Transform3D = skel_from_model * part["xf"]
		var nb := xf.basis.inverse().transposed()
		var flip := xf.basis.determinant() < 0.0
		var allowed := _allowed(part["b"])
		var base: int = s["v"].size()
		var pv: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
		var pn: PackedVector3Array = a[Mesh.ARRAY_NORMAL]
		var pt: PackedFloat32Array = a[Mesh.ARRAY_TANGENT] if a[Mesh.ARRAY_TANGENT] != null else PackedFloat32Array()
		var cache := {}          # sommets Meshy dupliqués (coutures d'UV) : même position, mêmes poids
		for v in pv.size():
			var q := xf * pv[v]
			s["v"].append(q)
			s["n"].append((nb * pn[v]).normalized())
			if pt.size() > 0:
				var tg := (xf.basis * Vector3(pt[v * 4], pt[v * 4 + 1], pt[v * 4 + 2])).normalized()
				s["t"].append_array([tg.x, tg.y, tg.z, pt[v * 4 + 3] * (-1.0 if flip else 1.0)])
			s["uv"].append(a[Mesh.ARRAY_TEX_UV][v])
			var key := Vector3i((q * 2000.0).round())
			if not cache.has(key):
				cache[key] = _weights_at(q, allowed)
			var bw4: Array = cache[key]
			s["b"].append_array(bw4[0])
			s["w"].append_array(bw4[1])
		var pi: PackedInt32Array = a[Mesh.ARRAY_INDEX]
		for t in pi.size() / 3:
			if flip:
				s["i"].append_array([base + pi[t * 3], base + pi[t * 3 + 2], base + pi[t * 3 + 1]])
			else:
				s["i"].append_array([base + pi[t * 3], base + pi[t * 3 + 1], base + pi[t * 3 + 2]])
	var mesh := ArrayMesh.new()
	for tex in surfaces:
		var s: Dictionary = surfaces[tex]
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = s["v"]
		arr[Mesh.ARRAY_NORMAL] = s["n"]
		if s["t"].size() > 0:
			arr[Mesh.ARRAY_TANGENT] = s["t"]
		arr[Mesh.ARRAY_TEX_UV] = s["uv"]
		arr[Mesh.ARRAY_BONES] = s["b"]
		arr[Mesh.ARRAY_WEIGHTS] = s["w"]
		arr[Mesh.ARRAY_INDEX] = s["i"]
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		mesh.surface_set_name(mesh.get_surface_count() - 1, tex)    # texture de la surface (SolarisLook)
	return mesh


## Pièce préparée par tools/meshy_pieces.py : le maillage du .glb importé, enregistré seul en .res
## (comme les autres pièces : c'est aussi ce que charge le repli rigide de SolarisLook).
func _mesh_from_glb(glb: String, out: String) -> void:
	var root: Node = (load(glb) as PackedScene).instantiate()
	var mi: MeshInstance3D = root.find_children("*", "MeshInstance3D", true, false)[0]
	ResourceSaver.save(mi.mesh, out)
	root.free()
	print("  ", glb, " -> ", out)


## Index de bind des os qu'un morceau accroché à « bone » peut suivre.
func _allowed(bone: String) -> PackedInt32Array:
	var side := ""
	var base := bone
	if bone.ends_with("_L") or bone.ends_with("_R"):
		side = bone.right(2)
		base = bone.left(-2)
	var out := PackedInt32Array()
	for b in ALLOWED.get(base, [base]):
		var name: String = b if b.ends_with("_L") or b.ends_with("_R") or b in ["hips", "spine", "chest", "neck", "head"] else b + side
		if bind_of.has(name):
			out.append(bind_of[name])
	return out


func _grid(allowed: PackedInt32Array) -> Dictionary:
	var key := str(allowed)
	if grids.has(key):
		return grids[key]
	var g := {}
	for v in bv.size():
		if dominant[v] in allowed:
			var c := Vector3i((bv[v] / CELL).floor())
			if not g.has(c):
				g[c] = PackedInt32Array()
			g[c].append(v)
	grids[key] = g
	return g


## Poids du corps au point le plus proche de q (sur les sommets dont l'os principal est permis).
func _weights_at(q: Vector3, allowed: PackedInt32Array) -> Array:
	var g := _grid(allowed)
	var c := Vector3i((q / CELL).floor())
	var best := -1
	var best_d := INF
	for r in 16:
		for x in range(-r, r + 1):
			for y in range(-r, r + 1):
				for z in range(-r, r + 1):
					if maxi(absi(x), maxi(absi(y), absi(z))) != r:
						continue
					var cell = g.get(c + Vector3i(x, y, z))
					if cell == null:
						continue
					for v in cell:
						var dd := q.distance_squared_to(bv[v])
						if dd < best_d:
							best_d = dd
							best = v
		if best >= 0 and sqrt(best_d) < r * CELL:
			break
	var acc := {}
	if best < 0:
		acc[allowed[0]] = 1.0
	else:
		# point le plus proche sur les triangles autour du sommet trouvé, poids interpolés
		var tri_best := -1
		var tri_d := INF
		var bary := Vector3.ZERO
		for t in vtris[best]:
			var A := bv[bi[t * 3]]
			var B := bv[bi[t * 3 + 1]]
			var C := bv[bi[t * 3 + 2]]
			var cp := _closest_on_tri(q, A, B, C)
			var dd := q.distance_squared_to(cp)
			if dd < tri_d:
				tri_d = dd
				tri_best = t
				bary = Geometry3D.get_triangle_barycentric_coords(cp, A, B, C)
		if tri_best < 0:
			for k in 4:
				acc[bb[best * 4 + k]] = acc.get(bb[best * 4 + k], 0.0) + bw[best * 4 + k]
		else:
			for j in 3:
				var v := bi[tri_best * 3 + j]
				for k in 4:
					var w := bw[v * 4 + k] * clampf(bary[j], 0.0, 1.0)
					if w > 0.0:
						acc[bb[v * 4 + k]] = acc.get(bb[v * 4 + k], 0.0) + w
	var keys := acc.keys()
	keys.sort_custom(func(x, y): return acc[x] > acc[y])
	var bones := PackedInt32Array([0, 0, 0, 0])
	var ws := PackedFloat32Array([0.0, 0.0, 0.0, 0.0])
	var total := 0.0
	for k in mini(4, keys.size()):
		bones[k] = keys[k]
		ws[k] = acc[keys[k]]
		total += ws[k]
	if total <= 0.0:
		bones[0] = allowed[0]
		ws[0] = 1.0
		total = 1.0
	for k in 4:
		ws[k] /= total
	return [bones, ws]


static func _closest_on_tri(p: Vector3, a: Vector3, b: Vector3, c: Vector3) -> Vector3:
	var ab := b - a
	var ac := c - a
	var ap := p - a
	var d1 := ab.dot(ap)
	var d2 := ac.dot(ap)
	if d1 <= 0.0 and d2 <= 0.0:
		return a
	var bp := p - b
	var d3 := ab.dot(bp)
	var d4 := ac.dot(bp)
	if d3 >= 0.0 and d4 <= d3:
		return b
	var vc := d1 * d4 - d3 * d2
	if vc <= 0.0 and d1 >= 0.0 and d3 <= 0.0:
		return a + ab * (d1 / (d1 - d3))
	var cp := p - c
	var d5 := ab.dot(cp)
	var d6 := ac.dot(cp)
	if d6 >= 0.0 and d5 <= d6:
		return c
	var vb := d5 * d2 - d1 * d6
	if vb <= 0.0 and d2 >= 0.0 and d6 <= 0.0:
		return a + ac * (d2 / (d2 - d6))
	var va := d3 * d6 - d5 * d4
	if va <= 0.0 and (d4 - d3) >= 0.0 and (d5 - d6) >= 0.0:
		return b + (c - b) * ((d4 - d3) / ((d4 - d3) + (d5 - d6)))
	var denom := 1.0 / (va + vb + vc)
	return a + ab * (vb * denom) + ac * (vc * denom)


# ---------------------------------------------------------------- 3 : le corps caché sous la pièce
## Pour chaque sommet du corps (des os que la pièce remplace) : un rayon le long de sa normale, de
## HIDE_REACH au-dessus jusqu'à HIDE_DEPTH en dessous. S'il touche une face extérieure de l'armure, le
## sommet est soit recouvert (armure au-dessus), soit il dépasse de l'armure (armure juste dessous) : dans
## les deux cas on le cache, et c'est l'armure qu'on voit à sa place. Ailleurs le corps reste : pas de trou.
func _hide_mask(mesh: ArrayMesh, id: String) -> PackedFloat32Array:
	# seuls les sommets du corps des os que la pièce remplace (la main près de la cuisse reste visible)
	var own := {}
	for part in Catalog.mesh_def(id)["parts"]:
		for b in _allowed(part["b"]):
			own[b] = true
	var faces := PackedVector3Array()
	var normals := PackedVector3Array()
	for s in mesh.get_surface_count():
		var a := mesh.surface_get_arrays(s)
		var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
		var vn: PackedVector3Array = a[Mesh.ARRAY_NORMAL]
		var idx: PackedInt32Array = a[Mesh.ARRAY_INDEX]
		for t in idx.size() / 3:
			var A := v[idx[t * 3]]
			var B := v[idx[t * 3 + 1]]
			var C := v[idx[t * 3 + 2]]
			faces.append_array([A, B, C])
			# normale extérieure de la face : du côté des normales de ses sommets
			var fn := (B - A).cross(C - A).normalized()
			if fn.dot(vn[idx[t * 3]] + vn[idx[t * 3 + 1]] + vn[idx[t * 3 + 2]]) < 0.0:
				fn = -fn
			normals.append(fn)
	var shape := ConcavePolygonShape3D.new()
	shape.backface_collision = true
	shape.set_faces(faces)
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	cs.shape = shape
	body.add_child(cs)
	body.collision_layer = 1 << 19
	add_child(body)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var space := body.get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.new()
	q.collision_mask = 1 << 19
	q.hit_back_faces = true
	var gk := PackedFloat32Array()
	gk.resize(groups.size())
	var n_own := 0
	for g in groups.size():
		if not own.has(dominant[groups[g][0]]):
			continue
		n_own += groups[g].size()
		var v: Vector3 = gpos[g]
		var n: Vector3 = gnor[g]
		var from := v + n * HIDE_REACH
		var to := v - n * HIDE_DEPTH
		for tries in 12:
			q.from = from
			q.to = to
			var hit := space.intersect_ray(q)
			if hit.is_empty():
				break
			var fi: int = hit.get("face_index", -1)
			var h: Vector3 = hit["position"]
			if fi >= 0 and normals[fi].dot(n) > 0.0:
				gk[g] = 1.0      # face extérieure de l'armure, au-dessus ou juste sous le corps
				break
			from = h - n * 0.001     # face intérieure (l'autre jambe, le dessous d'une plaque) : on continue
	var k := PackedFloat32Array()
	k.resize(bv.size())
	var n_in := 0
	for v in bv.size():
		k[v] = gk[group_of[v]]     # sommets soudés (coutures d'UV) : même valeur
		if k[v] > 0.0:
			n_in += 1
	print("  corps caché : %d sommets sur %d (os de la pièce : %d)" % [n_in, bv.size(), n_own])
	body.queue_free()
	return k


## Une texture par pièce : texel (i % 256, i / 256) = 1 si le sommet i du corps est caché (shader : VERTEX_ID).
func _save_mask(k: PackedFloat32Array, path: String) -> void:
	var w := 256
	var h := (k.size() + w - 1) / w
	var data := PackedFloat32Array()
	data.resize(w * h)
	for i in k.size():
		data[i] = k[i]
	var img := Image.create_from_data(w, h, false, Image.FORMAT_RF, data.to_byte_array())
	ResourceSaver.save(ImageTexture.create_from_image(img), path)


## Sommets du corps soudés par position (le maillage Meshy est coupé aux coutures d'UV), normale moyenne.
func _weld() -> void:
	var by_pos := {}
	group_of.resize(bv.size())
	for v in bv.size():
		var key := Vector3i((bv[v] * 20000.0).round())
		if not by_pos.has(key):
			by_pos[key] = groups.size()
			groups.append(PackedInt32Array())
			gpos.append(bv[v])
			gnor.append(Vector3.ZERO)
		var g: int = by_pos[key]
		groups[g].append(v)
		group_of[v] = g
		gnor[g] += bn[v]
	for g in groups.size():
		gnor[g] = gnor[g].normalized()