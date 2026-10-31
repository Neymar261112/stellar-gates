class_name Maps
## Définitions des cartes. Une carte = une grille de caractères + une palette + des points d'intérêt.
## Légende : . sol  # plateau  = rampe  ~ gouffre (ou lave)  o rocher  X paroi  h zone cachée  w eau

const T := 2.5


static func _blank(w: int, h: int) -> Array:
	var g := []
	for j in h:
		var row := []
		row.resize(w)
		row.fill(".")
		g.append(row)
	return g


static func _rect(g: Array, x: int, y: int, w: int, h: int, c: String) -> void:
	for j in range(y, y + h):
		for i in range(x, x + w):
			if j >= 0 and j < g.size() and i >= 0 and i < g[0].size():
				g[j][i] = c


static func elyra() -> Dictionary:
	var W := 50
	var H := 36
	var g := _blank(W, H)
	_rect(g, 0, 0, W, 1, "X"); _rect(g, 0, H - 1, W, 1, "X"); _rect(g, 0, 0, 1, H, "X"); _rect(g, W - 1, 0, 1, H, "X")
	_rect(g, 22, 5, 4, 31, "~"); _rect(g, 24, 27, 2, 4, ".")
	_rect(g, 28, 1, 21, 17, "#"); _rect(g, 30, 17, 2, 1, "="); _rect(g, 30, 18, 2, 1, "=")
	_rect(g, 40, 3, 6, 5, "~")
	_rect(g, 2, 2, 12, 9, "X"); _rect(g, 3, 3, 10, 7, "h"); _rect(g, 7, 10, 2, 1, "h")
	_rect(g, 33, 27, 9, 6, "w")
	_rect(g, 35, 18, 4, 2, "w")   # bassin au pied de la cascade
	_rect(g, 14, 14, 1, 8, "X"); _rect(g, 14, 14, 6, 1, "X")
	for r in [[5,17],[9,21],[17,27],[11,28],[8,13],[18,8],[20,16],[36,22],[44,24],[30,31],[46,31],[33,12],[37,15],[44,12],[47,20],[27,25],[12,33],[3,25],[19,3],[16,5]]:
		g[r[1]][r[0]] = "o"
	return {
		"id": "elyra",
		"name": "Élyra",
		"grid": g,
		"start": Vector2i(6, 30),
		"ramp": { "cells": Rect2i(30, 17, 2, 2), "top_z": 17 },   # rampe : rangée haute = côté plateau
		"roof": Rect2i(2, 2, 12, 9),
		"arche": { "cell": Vector2i(12, 24), "to": "varda", "facing": Vector3(0, 0, 1) },
		"beacons": [
			{ "cell": Vector2i(18, 19), "label": "Plaine" },
			{ "cell": Vector2i(44, 9), "label": "Plateau" },
			{ "cell": Vector2i(8, 5), "label": "Zone cachée" },
		],
		"palette": {
			".": Color(0.46, 0.44, 0.30), "=": Color(0.50, 0.45, 0.33), "#": Color(0.58, 0.52, 0.40),
			"h": Color(0.40, 0.46, 0.36), "X": Color(0.30, 0.32, 0.37), "~": Color(0.06, 0.07, 0.09),
			"w": Color(0.18, 0.42, 0.52), "o": Color(0.47, 0.45, 0.43), "roof": Color(0.25, 0.27, 0.31),
		},
		"pit_glow": Color(0, 0, 0),
		"sky": { "top": Color(0.33, 0.47, 0.68), "horizon": Color(0.72, 0.78, 0.85), "ground": Color(0.62, 0.60, 0.55), "sun": Color(1, 0.95, 0.86), "energy": 1.3, "fog": 0.004 },
		"props": { "mounds": 60, "pillars": 10, "seed": 7 },
		"cascades": [ { "cell": Vector2i(37, 18), "width": 3, "height": 3.6 } ],   # tombe du plateau dans le bassin
		"targets": [   # champ de tir devant le point de départ
			{ "cell": Vector2i(6, 25), "kind": "ground" },
			{ "cell": Vector2i(9, 27), "kind": "ground" },
			{ "cell": Vector2i(3, 27), "kind": "ground" },
			{ "cell": Vector2i(4, 23), "kind": "drone", "height": 8.0 },
			{ "cell": Vector2i(10, 22), "kind": "drone", "height": 10.0 },
			{ "cell": Vector2i(14, 30), "kind": "turret" },
		],
		"crates": [   # pièces du Solaris : Horizon près du départ, d'origine loin ou cachées
			{ "cell": Vector2i(17, 33), "slot": "propulseurs", "tier": 1 },
			{ "cell": Vector2i(19, 27), "slot": "jambes", "tier": 1 },
			{ "cell": Vector2i(12, 17), "slot": "carapace", "tier": 1 },
			{ "cell": Vector2i(18, 13), "slot": "noyau", "tier": 1 },
			{ "cell": Vector2i(5, 15), "slot": "finition", "tier": 1 },
			{ "cell": Vector2i(36, 8), "slot": "propulseurs", "tier": 2 },    # plateau : Ailes solaires
			{ "cell": Vector2i(5, 6), "slot": "jambes", "tier": 2 },          # zone cachée
			{ "cell": Vector2i(44, 30), "slot": "carapace", "tier": 2 },     # au bord du lac
			{ "cell": Vector2i(40, 22), "slot": "noyau", "tier": 2 },
			{ "cell": Vector2i(28, 33), "slot": "finition", "tier": 2 },
		],
		"covers": [   # cachettes du champ de tir (coordonnées en cases, rotation en radians)
			{ "x": 8.6, "z": 28.0, "low": true, "rot": 0.0 },
			{ "x": 12.0, "z": 26.0, "low": true, "rot": 0.35 },
			{ "x": 11.5, "z": 31.6, "low": false, "rot": 1.57, "len": 3.0 },
			{ "x": 16.5, "z": 28.0, "low": true, "rot": -0.4 },
			{ "x": 6.0, "z": 22.0, "low": false, "rot": 0.2, "len": 3.0 },
			{ "x": 14.5, "z": 22.4, "low": true, "rot": 0.0 },
		],
		"arena": {   # vagues d'ennemis quand on entre dans le champ de tir
			"rect": Rect2i(2, 20, 18, 14),
			"console": Vector2i(3, 30),   # borne : s'en approcher lance les vagues
			"spawns": [Vector2i(3, 20), Vector2i(9, 19), Vector2i(16, 24), Vector2i(18, 31), Vector2i(10, 33), Vector2i(4, 33)],
			"waves": [["soldier", "soldier", "soldier"], ["soldier", "soldier", "drone", "drone"], ["brute", "soldier", "soldier", "drone"]],
		},
	}


static func varda() -> Dictionary:
	var W := 32
	var H := 26
	var g := _blank(W, H)
	_rect(g, 0, 0, W, 1, "X"); _rect(g, 0, H - 1, W, 1, "X"); _rect(g, 0, 0, 1, H, "X"); _rect(g, W - 1, 0, 1, H, "X")
	# Rivière de lave en diagonale par paliers
	_rect(g, 10, 1, 3, 9, "~"); _rect(g, 12, 9, 3, 6, "~"); _rect(g, 14, 14, 3, 11, "~")
	_rect(g, 12, 6, 1, 3, "."); # pont étroit
	# Promontoire de basalte à droite, rampe
	_rect(g, 20, 2, 11, 10, "#"); _rect(g, 22, 11, 2, 1, "="); _rect(g, 22, 12, 2, 1, "=")
	_rect(g, 26, 4, 3, 3, "~")
	# Grotte
	_rect(g, 2, 14, 7, 8, "X"); _rect(g, 3, 15, 5, 6, "h"); _rect(g, 5, 21, 1, 1, "h")
	for r in [[4,5],[7,9],[3,11],[18,20],[22,20],[27,18],[29,22],[24,16],[6,3],[17,4],[20,15]]:
		g[r[1]][r[0]] = "o"
	return {
		"id": "varda",
		"name": "Varda",
		"grid": g,
		"start": Vector2i(5, 23),
		"ramp": { "cells": Rect2i(22, 11, 2, 2), "top_z": 11 },
		"roof": Rect2i(2, 14, 7, 8),
		"arche": { "cell": Vector2i(10, 22), "to": "elyra", "facing": Vector3(0, 0, -1) },
		"beacons": [
			{ "cell": Vector2i(26, 8), "label": "Promontoire" },
			{ "cell": Vector2i(5, 17), "label": "Grotte" },
			{ "cell": Vector2i(20, 22), "label": "Rive de lave" },
		],
		"palette": {
			".": Color(0.24, 0.20, 0.19), "=": Color(0.28, 0.24, 0.22), "#": Color(0.32, 0.27, 0.25),
			"h": Color(0.22, 0.19, 0.20), "X": Color(0.16, 0.14, 0.15), "~": Color(0.95, 0.35, 0.08),
			"w": Color(0.18, 0.42, 0.52), "o": Color(0.20, 0.18, 0.18), "roof": Color(0.14, 0.12, 0.13),
		},
		"pit_glow": Color(1.0, 0.45, 0.12),
		"sky": { "top": Color(0.16, 0.08, 0.10), "horizon": Color(0.75, 0.38, 0.22), "ground": Color(0.2, 0.1, 0.08), "sun": Color(1, 0.6, 0.4), "energy": 0.9, "fog": 0.008 },
		"props": { "mounds": 30, "pillars": 14, "seed": 21 },
		"cascades": [],
		"targets": [
			{ "cell": Vector2i(12, 21), "kind": "ground" },
			{ "cell": Vector2i(9, 18), "kind": "drone", "height": 7.0 },
			{ "cell": Vector2i(18, 17), "kind": "turret" },
		],
		"arena": {
			"rect": Rect2i(1, 10, 13, 15),
			"console": Vector2i(7, 22),
			"spawns": [Vector2i(12, 19), Vector2i(9, 12), Vector2i(12, 23), Vector2i(5, 11)],
			"waves": [["soldier", "drone"], ["soldier", "soldier", "drone"], ["brute", "drone", "drone"]],
		},
	}


static func by_id(id: String) -> Dictionary:
	match id:
		"varda": return varda()
		_: return elyra()
