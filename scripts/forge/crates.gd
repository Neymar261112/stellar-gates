extends Node3D
## Pile de caisses de la Forge : caisses en bois cerclées, mallettes orange, un tonneau. Origine au sol.

const K := preload("res://scripts/forge/forge_kit.gd")

@export var seed_value := 1
@export var count := 3


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var wood := K.mat("bois")
	var dark := K.mat("acier_sombre")
	for k in count:
		var sz := rng.randf_range(0.5, 0.75)
		var p := Vector3(rng.randf_range(-0.6, 0.6), 0, rng.randf_range(-0.5, 0.5))
		var rot := rng.randf_range(-0.5, 0.5)
		match rng.randi() % 3:
			0:
				_crate(p, sz, rot)
				if rng.randf() < 0.6:
					_crate(p + Vector3(0.03, sz, -0.03), sz * 0.72, rot + rng.randf_range(-0.4, 0.4))
			1:
				K.box(self, Vector3(1.0, 0.5, 0.6), p + Vector3(0, 0.25, 0), K.mat("orange"), Vector3(0, rot, 0))
				K.box(self, Vector3(1.03, 0.06, 0.63), p + Vector3(0, 0.31, 0), dark, Vector3(0, rot, 0))
				K.box(self, Vector3(0.8, 0.35, 0.5), p + Vector3(0, 0.68, 0), dark, Vector3(0, rot + 0.15, 0))
			_:
				K.cyl(self, 0.32, 0.85, p + Vector3(0, 0.425, 0), wood, -1.0, Vector3.ZERO, 16)
				for dy in [0.12, 0.73]:
					K.cyl(self, 0.335, 0.05, p + Vector3(0, dy, 0), dark, -1.0, Vector3.ZERO, 16)


func _crate(p: Vector3, sz: float, rot: float) -> void:
	K.box(self, Vector3.ONE * sz, p + Vector3(0, sz / 2, 0), K.mat("bois"), Vector3(0, rot, 0))
	for dy in [0.05, sz - 0.05]:
		K.box(self, Vector3(sz + 0.02, 0.06, sz + 0.02), p + Vector3(0, dy, 0), K.mat("acier_sombre"), Vector3(0, rot, 0))
