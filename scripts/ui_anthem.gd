extends RefCounted
## Habillage façon Anthem de la Forge : polices Barlow (OFL, assets/fonts), panneaux sans boîte (dégradé sombre
## qui s'efface vers le centre de l'écran, liserés de 1 px, crochets d'angle), lueur des vignettes choisies.
## Utilisé par preload (pas de class_name) : const AnthemUI := preload("res://scripts/ui_anthem.gd").

const WHITE := Color(1, 1, 1)
const ACCENT := Color(0.66, 0.84, 1.0)            # bleu pâle des liserés et des valeurs
const LINE := Color(0.78, 0.9, 1.0, 0.22)         # liserés fins
const DIM := Color(0.56, 0.63, 0.72)              # texte discret gris-bleu
const SHADE := Color(0.01, 0.025, 0.045)          # base des dégradés

static var _fonts := {}


static func _font(file: String, spacing: int, weight := 0.0) -> Font:
	var key := "%s:%d:%f" % [file, spacing, weight]
	if not _fonts.has(key):
		var base: Font = load("res://assets/fonts/" + file) if ResourceLoader.exists("res://assets/fonts/" + file) else ThemeDB.fallback_font
		var v := FontVariation.new()
		v.base_font = base
		v.spacing_glyph = spacing
		v.variation_embolden = weight
		_fonts[key] = v
	return _fonts[key]


## Titres : condensée, capitales espacées.
static func title_font() -> Font:
	return _font("BarlowCondensed-SemiBold.ttf", 2)


## Petits intitulés (onglets, catégories) : condensée moyenne, très espacée.
static func label_font() -> Font:
	return _font("BarlowCondensed-Medium.ttf", 2)


## Noms sous les vignettes : condensée sans espacement, pour tenir sur deux lignes sans couper les mots.
static func caption_font() -> Font:
	return _font("BarlowCondensed-Medium.ttf", 0)


## Texte courant : Barlow normale, plus fine.
static func body_font() -> Font:
	return _font("Barlow-Regular.ttf", 0)


static func body_medium() -> Font:
	return _font("Barlow-Medium.ttf", 0)


## Crochets aux quatre coins d'un rectangle.
static func brackets(ci: CanvasItem, r: Rect2, ln: float, c: Color, w := 1.0) -> void:
	var a := r.position
	var b := r.end
	for p in [[a, Vector2(1, 1)], [Vector2(b.x, a.y), Vector2(-1, 1)], [Vector2(a.x, b.y), Vector2(1, -1)], [b, Vector2(-1, -1)]]:
		var o: Vector2 = p[0]
		var s: Vector2 = p[1]
		ci.draw_line(o, o + Vector2(ln * s.x, 0), c, w)
		ci.draw_line(o, o + Vector2(0, ln * s.y), c, w)


## Dégradé linéaire sur un rectangle : c0 du côté `from` (-1 gauche, 1 droite, 2 bas, -2 haut), transparent à l'opposé.
static func gradient(ci: CanvasItem, r: Rect2, c0: Color, c1: Color, from: int) -> void:
	var p := PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])
	var cols: PackedColorArray
	match from:
		-1:
			cols = PackedColorArray([c0, c1, c1, c0])
		1:
			cols = PackedColorArray([c1, c0, c0, c1])
		2:
			cols = PackedColorArray([c1, c1, c0, c0])
		_:
			cols = PackedColorArray([c0, c0, c1, c1])
	ci.draw_polygon(p, cols)


## Lueur douce autour d'un rectangle (quelques contours de plus en plus larges et transparents).
static func glow(ci: CanvasItem, r: Rect2, c: Color, strength: float, spread := 7) -> void:
	if strength <= 0.01:
		return
	for i in range(spread, 0, -1):
		var k := float(i) / spread
		ci.draw_rect(r.grow(i), Color(c.r, c.g, c.b, c.a * strength * (1.0 - k) * 0.22), false, 2.0)


## Panneau sans boîte : `side` = côté de l'écran où il est collé (-1 gauche, 1 droite, 2 bas) ; le fond
## s'efface vers le centre. Liseré fin en haut et crochets d'angle.
static func panel(c: Control, side: int, strength := 0.62) -> void:
	c.draw.connect(func():
		var r := Rect2(Vector2.ZERO, c.size)
		var dark := Color(SHADE.r, SHADE.g, SHADE.b, strength)
		var clear := Color(SHADE.r, SHADE.g, SHADE.b, strength * (0.55 if side == 2 else 0.08))
		gradient(c, r, dark, clear, side)
		c.draw_line(Vector2(0, 0), Vector2(c.size.x, 0), LINE, 1.0)
		brackets(c, r, 10.0, Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.55), 1.0))


## Boîte de style vide qui ne garde que les marges intérieures.
static func pad(l: float, t: float, r: float, b: float) -> StyleBoxEmpty:
	var sb := StyleBoxEmpty.new()
	sb.content_margin_left = l
	sb.content_margin_top = t
	sb.content_margin_right = r
	sb.content_margin_bottom = b
	return sb


## Icône vectorielle de l'interface (assets/ui/icons/<id>.svg), null si absente.
static func icon(id: String) -> Texture2D:
	var p := "res://assets/ui/icons/%s.svg" % id
	return load(p) if ResourceLoader.exists(p) else null
