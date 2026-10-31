extends Node3D
## Bras robot industriel de la Forge (socle, tourelle, épaule, deux segments, poignet, outil), en acier gris
## avec des capots orange. La pointe de l'outil vise `target` (repère local) ; il oscille un peu au repos.
## À remplacer plus tard par un modèle Meshy : garder le nœud « Pointe » au bout de l'outil (étincelles de la Forge).

@export var target := Vector3(-2.0, 1.6, 0.6)
@export var size := 1.0
@export_enum("weld", "grip") var tool := "weld"
@export var sway := 0.04                 # amplitude de l'oscillation de la tourelle (rad)

const K := preload("res://scripts/forge/forge_kit.gd")

var tip: Node3D
var _turret: Node3D
var _t := 0.0


func _ready() -> void:
	_t = randf() * 10.0
	var s := size
	var steel := K.mat("acier")
	var dark := K.mat("acier_sombre")
	var paint := K.mat("orange")
	K.cyl(self, 0.62 * s, 0.24 * s, Vector3(0, 0.12 * s, 0), dark)
	for i in 8:
		var a := TAU * i / 8
		K.cyl(self, 0.035 * s, 0.05 * s, Vector3(cos(a), 0, sin(a)) * 0.55 * s + Vector3(0, 0.26 * s, 0), steel, -1.0, Vector3.ZERO, 8)
	_turret = Node3D.new()
	_turret.name = "Tourelle"
	add_child(_turret)
	var T := target
	var hd := Vector3(T.x, 0, T.z)
	hd = hd.normalized() if hd.length() > 0.001 else Vector3.RIGHT
	_turret.rotation.y = atan2(-hd.z, hd.x)
	# dans le repère de la tourelle, le bras travaille dans le plan (X, Y)
	var tl := Vector3(Vector2(T.x, T.z).length(), T.y, 0)
	var ax := Vector3(0, 0, 1)
	var tr := _turret
	K.cyl(tr, 0.5 * s, 0.32 * s, Vector3(0, 0.4 * s, 0), paint)
	K.cyl(tr, 0.44 * s, 0.1 * s, Vector3(0, 0.61 * s, 0), steel)
	K.capsule(tr, 0.3 * s, 0.78 * s, Vector3(-0.05 * s, 0.86 * s, 0), paint, Vector3(PI / 2, 0, 0), 1.25)
	K.capsule(tr, 0.24 * s, 0.6 * s, Vector3(-0.34 * s, 1.05 * s, 0), steel, Vector3(PI / 2, 0, 0))   # contrepoids
	var S := Vector3(0, 1.05 * s, 0)
	var L1 := 2.0 * s
	var L2 := 1.75 * s
	var W := tl + Vector3(0, 0.38 * s, 0) - Vector3(0.32 * s, 0, 0)
	var d := W - S
	var D := clampf(Vector2(d.x, d.y).length(), 0.4, L1 + L2 - 0.02)
	var a0 := atan2(d.y, d.x)
	var cb := (L1 * L1 + D * D - L2 * L2) / (2.0 * L1 * D)
	var th := a0 + acos(clampf(cb, -1.0, 1.0))
	var E := S + Vector3(cos(th), sin(th), 0) * L1
	W = E + (W - E).normalized() * L2
	_joint(tr, S, ax, 0.34 * s, 0.85 * s)
	_link(tr, S, E, 0.25 * s, steel, 1.0)
	for sg in [-1.0, 1.0]:
		K.beam(tr, S.lerp(E, 0.18) + ax * sg * 0.25 * s, S.lerp(E, 0.82) + ax * sg * 0.25 * s, 0.32 * s, paint, 0.04)
	_joint(tr, E, ax, 0.28 * s, 0.7 * s)
	_link(tr, E, W, 0.17 * s, steel, 1.0)
	K.rod(tr, E.lerp(W, 0.12), E.lerp(W, 0.45), 0.19 * s, paint, 16)
	_joint(tr, W, ax, 0.17 * s, 0.42 * s)
	var tdir := (tl - W).normalized()
	K.rod(tr, W, W + tdir * 0.18 * s, 0.14 * s, dark, 16)
	K.rod(tr, W + tdir * 0.18 * s, tl - tdir * 0.12 * s, 0.08 * s, steel, 12)
	tip = Node3D.new()
	tip.name = "Pointe"
	tr.add_child(tip)
	tip.position = tl
	if tool == "weld":
		K.rod(tr, tl - tdir * 0.14 * s, tl, 0.035 * s, dark, 8)
		K.sphere(tr, 0.03 * s, tl, K.mat("holo"))
	else:
		var side := tdir.cross(ax).normalized()
		for sg in [-1.0, 1.0]:
			K.beam(tr, tl - tdir * 0.12 * s + side * sg * 0.08 * s, tl + tdir * 0.1 * s + side * sg * 0.06 * s, 0.05 * s, dark, 0.1 * s)
	# faisceau de câbles le long du bras
	tr.add_child(K.cables([[Vector3(-0.3 * s, 0.6 * s, 0.25 * s), S + Vector3(-0.2 * s, 0.1, 0.3 * s), 0.08, 0.03 * s],
		[S + ax * -0.3 * s, E + ax * -0.3 * s, 0.18, 0.03 * s], [E + ax * -0.25 * s, W + ax * -0.16 * s, 0.12, 0.025 * s]]))


func _joint(parent: Node3D, c: Vector3, ax: Vector3, r: float, l: float) -> void:
	ForgeKit.rod(parent, c - ax * l / 2, c + ax * l / 2, r, ForgeKit.mat("acier_sombre"), 24)
	ForgeKit.rod(parent, c + ax * l / 2, c + ax * (l / 2 + 0.05), r * 0.75, ForgeKit.mat("orange"), 20)
	ForgeKit.rod(parent, c - ax * (l / 2 + 0.05), c - ax * l / 2, r * 0.75, ForgeKit.mat("orange"), 20)


## Segment du bras : une capsule (bouts arrondis) d'un axe à l'autre.
func _link(parent: Node3D, a: Vector3, b: Vector3, r: float, m: Material, flat: float) -> void:
	var c := CapsuleMesh.new()
	c.radius = r
	c.height = a.distance_to(b) + r * 2.0
	c.radial_segments = 20
	c.rings = 4
	var mi := MeshInstance3D.new()
	mi.mesh = c
	mi.material_override = m
	parent.add_child(mi)
	mi.transform = Transform3D(ForgeKit._basis_y(b - a) * Basis.from_scale(Vector3(flat, 1, 1.2)), (a + b) * 0.5)


func _process(delta: float) -> void:
	_t += delta
	if _turret and sway > 0.0:
		var hd := Vector3(target.x, 0, target.z)
		_turret.rotation.y = atan2(-hd.z, hd.x) + sin(_t * 0.35) * sway
