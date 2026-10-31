extends Node3D
## Lampe de la Forge : suspension industrielle (abat-jour en fonte, ampoule chaude) ou applique murale.
## Origine = point d'accroche (plafond pour la suspension, mur pour l'applique, qui éclaire vers -Z).

const K := preload("res://scripts/forge/forge_kit.gd")

@export var pendant := true
@export var drop := 1.8                 # longueur de la tige de la suspension
@export var energy := 1.4
@export var light_range := 6.0


func _ready() -> void:
	var iron := K.mat("fonte")
	var bulb_pos: Vector3
	if pendant:
		K.rod(self, Vector3.ZERO, Vector3(0, -drop, 0), 0.015, iron, 6)
		K.cyl(self, 0.35, 0.25, Vector3(0, -drop - 0.1, 0), iron, 0.12, Vector3.ZERO, 24)
		bulb_pos = Vector3(0, -drop - 0.25, 0)
	else:
		K.beam(self, Vector3.ZERO, Vector3(0, 0, -0.3), 0.05, iron)
		K.cyl(self, 0.1, 0.06, Vector3(0, -0.12, -0.3), iron, -1.0, Vector3.ZERO, 12)
		K.cyl(self, 0.12, 0.06, Vector3(0, 0.2, -0.3), iron, 0.06, Vector3.ZERO, 12)
		for k in 4:
			var a := TAU * k / 4 + PI / 4
			K.rod(self, Vector3(cos(a) * 0.1, -0.1, -0.3 + sin(a) * 0.1), Vector3(cos(a) * 0.11, 0.18, -0.3 + sin(a) * 0.11), 0.01, iron, 4)
		bulb_pos = Vector3(0, 0.03, -0.3)
	K.sphere(self, 0.09, bulb_pos, K.mat("ampoule")).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.66, 0.36)
	l.light_energy = energy
	l.omni_range = light_range
	l.omni_attenuation = 1.4
	l.light_volumetric_fog_energy = 0.8
	l.position = bulb_pos + Vector3(0, -0.12, 0)
	add_child(l)
