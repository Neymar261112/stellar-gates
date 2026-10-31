extends Node3D
## Râtelier à outils de la Forge : panneau perforé, montants orange, tablette en bois, outils suspendus,
## tiroirs. Face côté -Z, origine au sol.

const K := preload("res://scripts/forge/forge_kit.gd")

@export var seed_value := 1


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var steel := K.mat("acier")
	var dark := K.mat("acier_sombre")
	var paint := K.mat("orange")
	var wood := K.mat("bois")
	K.box(self, Vector3(2.3, 1.7, 0.08), Vector3(0, 1.55, 0), dark)
	for dx in [-1.15, 1.15]:
		K.box(self, Vector3(0.1, 2.5, 0.12), Vector3(dx, 1.25, 0), paint)
	K.box(self, Vector3(2.3, 0.06, 0.45), Vector3(0, 0.9, -0.2), wood)
	for k in 11:
		var dx := -1.0 + 0.2 * k
		var zz := rng.randf_range(1.6, 2.0)
		match k % 3:
			0:   # clé
				K.box(self, Vector3(0.045, 0.42, 0.02), Vector3(dx, zz, -0.07), steel)
				K.torus(self, 0.035, 0.07, Vector3(dx, zz + 0.24, -0.07), steel, 12).rotation.x = PI / 2
			1:   # marteau
				K.rod(self, Vector3(dx, zz - 0.25, -0.07), Vector3(dx, zz + 0.12, -0.07), 0.022, wood, 8)
				K.box(self, Vector3(0.16, 0.06, 0.05), Vector3(dx, zz + 0.15, -0.07), steel)
			_:   # tournevis
				K.rod(self, Vector3(dx, zz - 0.2, -0.08), Vector3(dx, zz + 0.08, -0.08), 0.04, paint, 8)
				K.rod(self, Vector3(dx, zz + 0.08, -0.08), Vector3(dx, zz + 0.2, -0.08), 0.015, steel, 6)
	for k in 4:
		var h := rng.randf_range(0.15, 0.3)
		K.box(self, Vector3(0.36, h, 0.3), Vector3(-0.8 + 0.5 * k, 0.93 + h / 2, -0.22), [paint, dark, steel][rng.randi() % 3])
	for k in 3:
		K.box(self, Vector3(0.6, 0.75, 0.42), Vector3(-0.7 + 0.7 * k, 0.42, -0.2), dark)
		K.box(self, Vector3(0.5, 0.04, 0.02), Vector3(-0.7 + 0.7 * k, 0.6, -0.42), paint)
