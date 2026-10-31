extends Node3D
## Poste de travail de la Forge : établi en acier, trois écrans holographiques bleus et un bandeau au-dessus,
## pupitre incliné, petite projection holographique. L'opérateur se tient côté -Z. Origine au sol.

const K := preload("res://scripts/forge/forge_kit.gd")

@export var light_energy := 0.7


func _ready() -> void:
	var steel := K.mat("acier")
	var dark := K.mat("acier_sombre")
	var screen := K.mat("ecran")
	K.box(self, Vector3(2.6, 0.07, 1.0), Vector3(0, 0.92, 0), steel)
	K.box(self, Vector3(2.5, 0.86, 0.75), Vector3(0, 0.45, 0.08), dark)
	K.box(self, Vector3(2.52, 0.1, 0.04), Vector3(0, 0.78, -0.3), K.mat("orange"))
	for k in 3:
		K.box(self, Vector3(0.6, 0.5, 0.03), Vector3(-0.8 + 0.8 * k, 0.45, -0.3), steel)
	for e in [[-0.86, 0.38], [0.0, 0.0], [0.86, -0.38]]:
		var holder := Node3D.new()
		add_child(holder)
		holder.position = Vector3(e[0], 1.45, 0.32)
		holder.rotation.y = e[1]
		K.box(holder, Vector3(0.82, 0.52, 0.06), Vector3.ZERO, dark)
		_quad(holder, Vector2(0.76, 0.46), Vector3(0, 0, -0.035), Vector3.ZERO, screen)
		K.box(self, Vector3(0.05, 0.32, 0.05), Vector3(e[0], 1.08, 0.36), steel)
	var top := Node3D.new()
	add_child(top)
	top.position = Vector3(0, 2.02, 0.4)
	top.rotation.x = 0.25
	K.box(top, Vector3(1.7, 0.5, 0.06), Vector3.ZERO, dark)
	_quad(top, Vector2(1.62, 0.44), Vector3(0, 0, -0.04), Vector3.ZERO, screen)
	K.box(self, Vector3(0.05, 0.7, 0.05), Vector3(0, 1.6, 0.44), steel)
	_quad(self, Vector2(0.9, 0.32), Vector3(-0.1, 0.962, -0.15), Vector3(-PI / 2 + 0.25, 0, 0), screen)
	K.cyl(self, 0.13, 0.03, Vector3(0.95, 0.97, -0.15), K.mat("holo"), -1.0, Vector3.ZERO, 24)
	var hb := K.cyl(self, 0.15, 0.45, Vector3(0.95, 1.2, -0.15), K.mat("faisceau"), 0.05, Vector3.ZERO, 24)
	hb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	K.box(self, Vector3(0.35, 0.16, 0.25), Vector3(0.55, 1.03, 0.1), K.mat("orange"))
	K.cyl(self, 0.04, 0.7, Vector3(0.2, 0.35, -0.85), dark, -1.0, Vector3.ZERO, 8)
	K.cyl(self, 0.22, 0.06, Vector3(0.2, 0.72, -0.85), dark, -1.0, Vector3.ZERO, 16)
	var l := OmniLight3D.new()
	l.light_color = K.HOLO
	l.light_energy = light_energy
	l.omni_range = 2.6
	l.light_volumetric_fog_energy = 0.3
	l.position = Vector3(0, 1.5, -0.45)
	add_child(l)


func _quad(parent: Node3D, size: Vector2, pos: Vector3, rot: Vector3, m: Material) -> void:
	var q := QuadMesh.new()
	q.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = q
	mi.material_override = m
	mi.position = pos
	mi.rotation = rot + Vector3(0, PI, 0)     # le quad regarde +Z : on le tourne vers l'opérateur (-Z)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
