class_name VinylArt
## Les vinyles (grands décals) dessinés par code, en blanc sur transparent : la couleur vient de la zone Accent.
## Pour en ajouter un : une entrée dans Catalog.VINYLS et un cas dans _alpha().

const SIZE := 128
static var _cache := {}


static func texture(id: String) -> Texture2D:
	if _cache.has(id):
		return _cache[id]
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	for y in SIZE:
		for x in SIZE:
			var u := (x + 0.5) / SIZE * 2.0 - 1.0     # -1..1
			var v := 1.0 - (y + 0.5) / SIZE * 2.0     # -1..1, vers le haut
			var a := clampf(_alpha(id, u, v), 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, a))
	img.generate_mipmaps()
	var tex := ImageTexture.create_from_image(img)
	_cache[id] = tex
	return tex


static func _aa(d: float) -> float:
	# d < 0 à l'intérieur : bord adouci sur ~1 pixel
	return clampf(0.5 - d * SIZE * 0.5, 0.0, 1.0)


static func _seg(u: float, v: float, a: Vector2, b: Vector2) -> float:
	var p := Vector2(u, v)
	var ab := b - a
	var t := clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
	return (p - (a + ab * t)).length()


static func _alpha(id: String, u: float, v: float) -> float:
	var r := Vector2(u, v).length()
	match id:
		"horizon":
			# Disque cerclé, soleil levant (demi-disque) et horizon
			var ring := absf(r - 0.86) - 0.06
			var sun := maxf(Vector2(u, v + 0.15).length() - 0.42, -(v + 0.15))
			var line := maxf(absf(v + 0.22) - 0.035, absf(u) - 0.7)
			return maxf(_aa(ring), maxf(_aa(sun), _aa(line)))
		"chevrons":
			# Trois chevrons de rang empilés
			var best := 0.0
			for i in 3:
				var cy := 0.45 - i * 0.42
				var d := absf(v - cy + absf(u) * 0.55) - 0.09
				d = maxf(d, absf(u) - 0.8)
				best = maxf(best, _aa(d))
			return best
		"glyphes":
			# Anneau de l'Arche avec ses glyphes et ses chevrons
			var ring := absf(r - 0.78) - 0.12
			var ang := atan2(v, u)
			var k := fposmod(ang / TAU * 9.0, 1.0)
			var notch := 1.0 - _aa(absf(k - 0.5) - 0.18) * _aa(absf(r - 0.78) - 0.05)
			var inner := absf(r - 0.52) - 0.025
			var chev := 0.0
			for i in 9:
				var a := float(i) / 9.0 * TAU + PI / 2.0
				var c := Vector2(cos(a), sin(a)) * 0.97
				chev = maxf(chev, _aa(Vector2(u, v).distance_to(c) - 0.075))
			return maxf(_aa(ring) * notch, maxf(_aa(inner), chev))
		"flottilles":
			# Trois voiles triangulaires en éventail
			var best := 0.0
			for i in 3:
				var a := (i - 1) * 0.55
				var p := Vector2(u, v + 0.6).rotated(-a)
				var d := maxf(maxf(-p.y, p.y - 1.25), absf(p.x) - (1.25 - p.y) * 0.22)
				best = maxf(best, _aa(d))
			return best * (1.0 - _aa(r - 0.12) * 0.0)
		"danger":
			# Bandes de danger en diagonale dans un cartouche
			var box := maxf(absf(u) - 0.9, absf(v) - 0.5)
			var stripe := absf(fposmod(u + v, 0.5) - 0.25) - 0.11
			var frame := absf(box + 0.05) - 0.05
			return maxf(_aa(maxf(box, stripe)), _aa(frame))
	return 0.0
