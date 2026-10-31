extends Node3D
## Anneau de maintenance du berceau (au-dessus du Solaris) : carters arrondis en acier, bandes émettrices
## bleues, rayon de lumière douce jusqu'au socle et projecteur bleu. Origine = centre de l'anneau.
## À remplacer plus tard par un modèle Meshy (garder la lumière « Projecteur » et le « Faisceau »).

const K := preload("res://scripts/forge/forge_kit.gd")

@export var radius := 1.55
@export var beam_height := 2.9          # du dessous de l'anneau jusqu'au plateau du socle
@export var ceiling := 3.4              # hauteur des suspentes au-dessus de l'anneau
@export var spot_energy := 5.0
@export var segments := 12

var spot: SpotLight3D


func _ready() -> void:
	var R := radius
	var steel := K.mat("acier")
	var dark := K.mat("acier_sombre")
	var holo := K.mat("holo")
	# âme de l'anneau et joncs haut / bas
	K.torus(self, R - 0.16, R + 0.16, Vector3.ZERO, dark, 96)
	K.torus(self, R - 0.02, R + 0.1, Vector3(0, 0.27, 0), steel, 96)
	K.torus(self, R - 0.1, R + 0.0, Vector3(0, -0.26, 0), steel, 96)
	K.torus(self, R - 0.24, R - 0.2, Vector3(0, -0.3, 0), holo, 128)
	K.torus(self, R + 0.36, R + 0.39, Vector3(0, -0.02, 0), holo, 128)
	# carters : tronçons au profil arrondi, séparés par un petit jour
	var gap := 0.05
	var housing := K.rounded_rect(R + 0.06, 0.0, 0.56, 0.62, 0.14)
	var inner_strip := K.rounded_rect(R - 0.235, -0.1, 0.03, 0.3, 0.012, 1)
	var outer_strip := K.rounded_rect(R + 0.345, 0.1, 0.03, 0.1, 0.012, 1)
	var plate := K.rounded_rect(R + 0.35, 0.16, 0.04, 0.3, 0.015, 1)
	for i in segments:
		var a0 := TAU * i / segments + gap
		var a1 := TAU * (i + 1) / segments - gap
		_piece(K.arc_sweep(housing, a0, a1, 6), dark)
		var am := (a0 + a1) * 0.5
		_piece(K.arc_sweep(inner_strip, am - 0.12, am + 0.12, 3), holo)
		if i % 2 == 0:
			_piece(K.arc_sweep(plate, am - 0.15, am + 0.15, 3), K.mat("orange"))
		else:
			_piece(K.arc_sweep(outer_strip, am - 0.14, am + 0.14, 3), holo)
	# suspentes vers la charpente
	for k in 4:
		var a := PI / 4 + k * PI / 2
		var p := Vector3(cos(a) * R, 0.32, sin(a) * R)
		K.rod(self, p, p * Vector3(0.8, 1, 0.8) + Vector3(0, ceiling, 0), 0.04, steel, 8)
		K.cyl(self, 0.1, 0.2, p + Vector3(0, 0.08, 0), dark, -1.0, Vector3.ZERO, 12)
	var spans := []
	var rng := RandomNumberGenerator.new()
	rng.seed = int(radius * 1000.0) + segments
	for k in 8:
		var a := rng.randf() * TAU
		var p := Vector3(cos(a) * R, 0.3, sin(a) * R)
		spans.append([p, Vector3(rng.randf_range(-3.0, 3.0), ceiling, rng.randf_range(-3.0, 3.0)), rng.randf_range(0.3, 1.2)])
	add_child(K.cables(spans, 0.022))
	# rayon de lumière et projecteur
	var beam := K.cyl(self, R - 0.35, beam_height, Vector3(0, -0.3 - beam_height / 2, 0), K.mat("faisceau"), R - 0.35, Vector3.ZERO, 48)
	(beam.mesh as CylinderMesh).bottom_radius = R * 0.72
	(beam.mesh as CylinderMesh).cap_top = false
	(beam.mesh as CylinderMesh).cap_bottom = false
	beam.name = "Faisceau"
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	spot = SpotLight3D.new()
	spot.name = "Projecteur"
	spot.light_color = Color(0.4, 0.66, 1.0)
	spot.light_energy = spot_energy
	spot.spot_range = beam_height + 2.0
	spot.spot_angle = 34.0
	spot.spot_attenuation = 0.6
	spot.light_volumetric_fog_energy = 0.6
	spot.position = Vector3(0, -0.2, 0)
	spot.rotation.x = -PI / 2
	add_child(spot)
	var glow := OmniLight3D.new()           # les bandes émettrices éclairent un peu l'anneau
	glow.light_color = K.HOLO
	glow.light_energy = 0.8
	glow.omni_range = R + 1.2
	glow.light_volumetric_fog_energy = 0.0
	add_child(glow)


func _piece(mesh: Mesh, m: Material) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = m
	add_child(mi)
