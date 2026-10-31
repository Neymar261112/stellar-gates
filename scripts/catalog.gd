class_name Catalog
## Données de la personnalisation (doc « Personnalisation des exosquelettes », 27 octobre).
## Tout ce qui est ici est de l'APPARENCE : aucune valeur de jeu (vitesse, bouclier, dégâts…).
## Les stats vivent uniquement dans scripts/loadout.gd.
##
## Repère des pièces = repère du modèle : -Z devant, +Z dans le dos, y vers le haut (pieds à 0),
## gauche du personnage = -X. Chaque forme est accrochée à un os et suit l'animation.

const SLOTS := ["helmet", "chest", "arms", "legs"]
const SLOT_NAMES := { "helmet": "Casque", "chest": "Torse", "arms": "Bras", "legs": "Jambes" }

## Les 4 modes du Solaris (ExosuitClass). Seul le Ranger est modélisé pour l'instant.
const MODES := [
	{ "id": "ranger", "name": "Ranger", "archetype": "Polyvalent", "npc": "", "unlock": "Au départ",
	  "desc": "Le Solaris tel qu'on l'a trouvé : vol moyen, armes variées, pouvoirs de zone." },
	{ "id": "colossus", "name": "Colossus", "archetype": "Lourd / tank / artillerie", "npc": "Bastion", "unlock": "Fragment d'origine du noyau (Kheled)",
	  "desc": "Plaques doublées, bouclier frontal, artillerie, vol court. Copie humaine : Bastion." },
	{ "id": "storm", "name": "Storm", "archetype": "Aérien / énergétique", "npc": "Zéphyr", "unlock": "Fragment d'origine du noyau (Namar)",
	  "desc": "Vol stationnaire long, pouvoirs élémentaires à distance. Copie humaine : Zéphyr." },
	{ "id": "interceptor", "name": "Interceptor", "archetype": "Léger / rapide / agressif", "npc": "Spectre, Fulgur", "unlock": "Fragment d'origine du noyau (Orphée)",
	  "desc": "Corps à corps, double saut, esquives rapides. Copies humaines : Spectre et Fulgur." },
]

## Les 6 zones de peinture / matériau.
const ZONES := ["Principale", "Secondaire", "Accent", "Structure", "Souple", "Énergie"]

## Types de matériau (Materials). pattern : 0 lisse, 1 brossé, 2 carbone, 3 tissu.
const MATERIALS := [
	{ "id": "paint_matte", "name": "Peinture mate", "metal": 0.05, "rough": 0.85, "pattern": 0 },
	{ "id": "paint_gloss", "name": "Peinture brillante", "metal": 0.1, "rough": 0.22, "pattern": 0 },
	{ "id": "metal_brushed", "name": "Métal brossé", "metal": 0.9, "rough": 0.42, "pattern": 1 },
	{ "id": "metal_polished", "name": "Métal poli", "metal": 1.0, "rough": 0.18, "pattern": 0 },
	{ "id": "chrome", "name": "Chrome", "metal": 1.0, "rough": 0.04, "pattern": 0 },
	{ "id": "anodized", "name": "Anodisé", "metal": 0.75, "rough": 0.32, "pattern": 1 },
	{ "id": "carbon", "name": "Fibre de carbone", "metal": 0.3, "rough": 0.35, "pattern": 2 },
	{ "id": "ceramic", "name": "Céramique", "metal": 0.0, "rough": 0.3, "pattern": 0 },
	{ "id": "fabric", "name": "Tissu / cuir", "metal": 0.0, "rough": 0.95, "pattern": 3 },
	{ "id": "rubber", "name": "Caoutchouc", "metal": 0.0, "rough": 0.9, "pattern": 0 },
	{ "id": "emissive", "name": "Lumineux", "metal": 0.0, "rough": 0.4, "pattern": 0, "glow": true },
]

## Usure (Wear State) : 5 types, et un curseur d'intensité 0-100 % (« wear_amount », décision du 27 octobre 12:11).
const WEAR := [
	{ "id": "clean", "name": "Propre", "dirt": 0.0, "scratches": 0.0, "chips": 0.0, "fade": 0.0 },
	{ "id": "dirty", "name": "Sale", "dirt": 0.85, "scratches": 0.0, "chips": 0.0, "fade": 0.1 },
	{ "id": "scratched", "name": "Rayé", "dirt": 0.15, "scratches": 1.0, "chips": 0.0, "fade": 0.0 },
	{ "id": "chipped", "name": "Peinture écaillée", "dirt": 0.2, "scratches": 0.3, "chips": 1.0, "fade": 0.0 },
	{ "id": "worn", "name": "Usé jusqu'à l'os", "dirt": 0.7, "scratches": 0.8, "chips": 0.8, "fade": 0.6 },
]

## Vinyles : grands décals dessinés par code (scripts/vinyl_art.gd). Couleur = zone Accent.
const VINYLS := [
	{ "id": "none", "name": "Aucun" },
	{ "id": "horizon", "name": "Insigne d'Horizon", "place": "chest" },
	{ "id": "chevrons", "name": "Chevrons de rang", "place": "shoulder_L" },
	{ "id": "glyphes", "name": "Anneau de glyphes de l'Arche", "place": "back" },
	{ "id": "flottilles", "name": "Marque des Flottilles libres", "place": "shoulder_R" },
	{ "id": "danger", "name": "Bandes de danger de Saint-Éloi", "place": "chest" },
]
const VINYL_PLACES := ["chest", "back", "shoulder_L", "shoulder_R"]
const VINYL_PLACE_NAMES := { "chest": "Poitrine", "back": "Dos", "shoulder_L": "Épaule gauche", "shoulder_R": "Épaule droite" }

## Animations (voir scripts/solaris_anim.gd, fonction play()).
const ARRIVALS := [
	{ "id": "drop", "name": "Chute orbitale (réception héroïque)" },
	{ "id": "scan", "name": "Sortie prudente (regard circulaire)" },
	{ "id": "ignite", "name": "Allumage (le noyau s'éveille)" },
]
const VICTORIES := [
	{ "id": "salute", "name": "Salut militaire" },
	{ "id": "fist", "name": "Poing levé" },
	{ "id": "crossed", "name": "Bras croisés" },
	{ "id": "kneel", "name": "Genou à terre" },
]
const EMOTES := [
	{ "id": "wave", "name": "Salut de la main" },
	{ "id": "point", "name": "Montrer du doigt" },
	{ "id": "kneel", "name": "Genou à terre" },
	{ "id": "scan", "name": "Balayage de visière" },
	{ "id": "stretch", "name": "Étirement" },
	{ "id": "salute", "name": "Salut militaire" },
]

## Nuancier : 8 colonnes × 6 lignes.
const PALETTE := [
	"#F2EEE4", "#E8E0CF", "#C9C6C0", "#8E9196", "#5A5E66", "#34373D", "#1E2024", "#0E0F11",
	"#D4A84A", "#B8862E", "#8C6A3F", "#6E4B2A", "#B87333", "#8A3B1E", "#5C2A18", "#3A2418",
	"#E0402E", "#B02020", "#7A1420", "#F07A2A", "#D85A10", "#F2C23A", "#E8E070", "#A8A040",
	"#6E7F3A", "#4A5A2C", "#2E3B24", "#3C8C5A", "#1E6A50", "#40B8A0", "#1A8A9A", "#1E5A6E",
	"#7EC8F0", "#3A8AD8", "#1E4E9A", "#162E5C", "#4A3AA8", "#7A50D0", "#A070F0", "#5A2A8A",
	"#C060C0", "#E070A0", "#8A2A5A", "#C8B490", "#A89670", "#7A6E58", "#FFC85A", "#9AF0FF",
]

## Les packs du mode Ranger réellement modélisés (16 pièces, décision Q9).
## Le reste du catalogue (77 packs) est lu dans data/catalogue-armures.json et affiché « à modéliser ».
const RANGER_PACKS := [
	{ "id": "ranger.default", "name": "Default", "tags": ["default", "military"], "source": "Au départ" },
	# Récup, Horizon, Originel : en attente de leurs pièces Meshy (les formes simples ont été retirées).
	{ "id": "ranger.recup", "name": "Récup (l'épave)", "tags": ["scavenged"], "source": "Au départ", "slots": [] },
	{ "id": "ranger.horizon", "name": "Horizon", "tags": ["military"], "source": "Caisses Horizon (Élyra)", "slots": [] },
	{ "id": "ranger.originel", "name": "Originel", "tags": ["ancient", "ceremonial"], "source": "Caisses d'origine (Élyra)", "slots": [] },
	# Pièces Meshy fournies par cyril : un pack peut n'avoir que certains emplacements.
	{ "id": "ranger.mech", "name": "Mech orange", "tags": ["military"], "source": "Modèle Meshy (essai)", "slots": ["helmet", "chest", "arms", "legs"] },
	{ "id": "ranger.exo", "name": "Exo Ranger", "tags": ["military"], "source": "Modèle Meshy (bras gauche et droit)", "slots": ["arms"] },
	# Pièces Meshy du 29 octobre (soir) : un emplacement chacune (voir MESHY_29OCT)
	{ "id": "ranger.sentinelle_braise", "name": "Sentinelle de braise", "tags": ["military"], "source": "Modèle Meshy (29 oct)", "slots": ["chest"] },
	{ "id": "ranger.sentinelle_braise2", "name": "Sentinelle de braise II", "tags": ["military"], "source": "Modèle Meshy (29 oct)", "slots": ["chest"] },
	{ "id": "ranger.avantgarde_braise", "name": "Avant-garde de braise", "tags": ["military"], "source": "Modèle Meshy (29 oct)", "slots": ["chest"] },
	{ "id": "ranger.sentinelle_orange", "name": "Sentinelle orange", "tags": ["military"], "source": "Modèle Meshy (29 oct)", "slots": ["chest"] },
	{ "id": "ranger.titan_orange", "name": "Titan orange", "tags": ["military"], "source": "Modèle Meshy (29 oct)", "slots": ["chest"] },
	{ "id": "ranger.avantgarde_titan", "name": "Avant-garde Titan", "tags": ["military"], "source": "Modèle Meshy (29 oct)", "slots": ["chest"] },
	{ "id": "ranger.plastron_titan", "name": "Plastron Titan", "tags": ["military"], "source": "Modèle Meshy (29 oct)", "slots": ["chest"] },
	{ "id": "ranger.gantelet_tigre", "name": "Gantelet du Tigre", "tags": ["military"], "source": "Modèle Meshy (29 oct)", "slots": ["arms"] },
	{ "id": "ranger.griffe_braise", "name": "Griffe de braise", "tags": ["military"], "source": "Modèle Meshy (29 oct)", "slots": ["arms"] },
	{ "id": "ranger.casque_aegis", "name": "Heaume Sentinelle Aegis", "tags": ["military"], "source": "Modèle Meshy (29 oct)", "slots": ["helmet"] },
	{ "id": "ranger.casque_guepe", "name": "Casque Guêpe", "tags": ["military"], "source": "Modèle Meshy (29 oct)", "slots": ["helmet"] },
	{ "id": "ranger.casque_minuit", "name": "Sentinelle de minuit", "tags": ["military"], "source": "Modèle Meshy (29 oct)", "slots": ["helmet"] },
	{ "id": "ranger.casque_neon", "name": "Avant-garde néon", "tags": ["military"], "source": "Modèle Meshy (29 oct)", "slots": ["helmet"] },
	{ "id": "ranger.masque_orange", "name": "Masque cybernétique orange", "tags": ["military"], "source": "Modèle Meshy (29 oct)", "slots": ["helmet"] },
	{ "id": "ranger.casque_vide", "name": "Casque du Vide", "tags": ["military"], "source": "Modèle Meshy (29 oct)", "slots": ["helmet"] },
	{ "id": "ranger.casque_braise", "name": "Sentinelle de braise", "tags": ["military"], "source": "Modèle Meshy (29 oct)", "slots": ["helmet"] },
	{ "id": "ranger.bras_precision", "name": "Précision articulée", "tags": ["military"], "source": "Modèle Meshy (29 oct)", "slots": ["arms"] },
	{ "id": "ranger.bras_limier", "name": "Limier cybernétique", "tags": ["military"], "source": "Modèle Meshy (29 oct)", "slots": ["arms"] },
	{ "id": "ranger.bras_cyber", "name": "Bras cybernétique", "tags": ["military"], "source": "Modèle Meshy (29 oct)", "slots": ["arms"] },
	{ "id": "ranger.bras_cyber2", "name": "Bras cybernétique II", "tags": ["military"], "source": "Modèle Meshy (29 oct)", "slots": ["arms"] },
	{ "id": "ranger.bras_prothese", "name": "Prothèse cybernétique", "tags": ["military"], "source": "Modèle Meshy (29 oct)", "slots": ["arms"] },
	{ "id": "ranger.bras_allonge", "name": "Allonge cybernétique", "tags": ["military"], "source": "Modèle Meshy (29 oct)", "slots": ["arms"] },
	{ "id": "ranger.bras_serre", "name": "Serre cybernétique", "tags": ["military"], "source": "Modèle Meshy (29 oct)", "slots": ["arms"] },
	{ "id": "ranger.bras_exocoque", "name": "Exocoque de braise", "tags": ["military"], "source": "Modèle Meshy (29 oct)", "slots": ["arms"] },
	{ "id": "ranger.bras_mech_braise", "name": "Bras Mech de braise", "tags": ["military"], "source": "Modèle Meshy (29 oct)", "slots": ["arms"] },
	{ "id": "ranger.bras_cobra", "name": "Cobra de braise", "tags": ["military"], "source": "Modèle Meshy (29 oct)", "slots": ["arms"] },
	{ "id": "ranger.bras_servo", "name": "Servo-bras d'obsidienne", "tags": ["military"], "source": "Modèle Meshy (29 oct)", "slots": ["arms"] },
	{ "id": "ranger.pince_titan", "name": "Pince Titan", "tags": ["military"], "source": "Modèle Meshy (29 oct)", "slots": ["arms"] },
]

## Torses Meshy du 29 octobre : préparés par tools/meshy_pieces.py (assets/pieces/torses/<fichier>), posés
## sur la poitrine comme le torse Mech : même échelle (0,36 : 0,68 m d'épaulière à épaulière), col à 1,68 m.
## id : [fichier, hauteur Meshy du modèle (taille Godot y affichée par meshy_pieces.py)]
const MESHY_29OCT := {
	"ranger.sentinelle_braise.chest": ["torse_ember_a", 1.687],
	"ranger.sentinelle_braise2.chest": ["torse_ember_b", 1.441],
	"ranger.avantgarde_braise.chest": ["torse_ember_vanguard", 1.569],
	"ranger.sentinelle_orange.chest": ["torse_orange_sentinel", 1.419],
	"ranger.titan_orange.chest": ["torse_orange_titan", 1.614],
	"ranger.avantgarde_titan.chest": ["torse_titan_vanguard", 1.414],
	"ranger.plastron_titan.chest": ["torse_titan_plastron", 1.572],
}

## Casques Meshy du 29 oct (assets/pieces/casques/<fichier>), portés par l'os de la tête.
## id : [fichier, échelle, hauteur du centre de la boîte, avance (z, -Z devant), inclinaison vers l'avant (rad)]
## Tête du corps Aegis au repos : x ±0,14, y 1,57 → 1,90, z ±0,18 ; le casque descend jusqu'au menton.
const MESHY_CASQUES := {
	"ranger.casque_aegis.helmet": ["casque_aegis", 0.245, 1.745, -0.01, 0.0],
	"ranger.casque_guepe.helmet": ["casque_guepe", 0.215, 1.75, -0.01, 0.0],
	"ranger.casque_minuit.helmet": ["casque_minuit", 0.215, 1.75, -0.01, 0.0],
	"ranger.casque_neon.helmet": ["casque_neon", 0.215, 1.75, -0.01, 0.0],
	"ranger.masque_orange.helmet": ["masque_orange", 0.225, 1.75, -0.01, 0.6],
	"ranger.casque_vide.helmet": ["casque_vide", 0.215, 1.75, -0.01, 0.0],
	"ranger.casque_braise.helmet": ["casque_ember", 0.215, 1.75, -0.01, 0.0],
}

## Bras Meshy du 29 oct, modélisés pliés : redressés et coupés en 3 par tools/meshy_pieces.py (BRAS), le
## gauche posé sur le bras gauche, le droit est son miroir (assets/pieces/bras/<fichier>_upper/_fore/_hand).
## id : [fichier, longueurs des 3 morceaux affichées par l'outil, échelles en largeur]
const MESHY_BRAS := {
	"ranger.gantelet_tigre.arms": ["bras_tigre", [0.731, 0.745, 0.462], [0.42, 0.40, 0.42]],
	"ranger.griffe_braise.arms": ["bras_emberclaw", [0.773, 0.874, 0.538], [0.40, 0.37, 0.39]],
	"ranger.bras_precision.arms": ["bras_precision", [0.778, 0.938, 0.516], [0.36, 0.40, 0.40]],
	"ranger.bras_limier.arms": ["bras_limier", [0.754, 1.002, 0.520], [0.36, 0.40, 0.40]],
	"ranger.bras_cyber.arms": ["bras_cyber_a", [0.782, 1.079, 0.515], [0.36, 0.40, 0.40]],
	"ranger.bras_cyber2.arms": ["bras_cyber_b", [0.791, 1.087, 0.504], [0.36, 0.40, 0.40]],
	"ranger.bras_prothese.arms": ["bras_prothese", [0.807, 0.855, 0.470], [0.36, 0.40, 0.40]],
	"ranger.bras_allonge.arms": ["bras_allonge", [0.771, 0.974, 0.398], [0.36, 0.40, 0.40]],
	"ranger.bras_serre.arms": ["bras_serre", [0.720, 1.042, 0.422], [0.36, 0.40, 0.40]],
	"ranger.bras_exocoque.arms": ["bras_exocoque", [0.866, 0.932, 0.424], [0.36, 0.40, 0.40]],
	"ranger.bras_mech_braise.arms": ["bras_mech_braise", [0.782, 1.020, 0.468], [0.36, 0.40, 0.40]],
	"ranger.bras_cobra.arms": ["bras_cobra", [0.862, 0.993, 0.503], [0.36, 0.40, 0.40]],
	"ranger.bras_servo.arms": ["bras_servo", [0.851, 0.814, 0.391], [0.36, 0.40, 0.40]],
	"ranger.pince_titan.arms": ["bras_titan", [0.744, 0.955, 0.435], [0.36, 0.40, 0.40]],
}

## Pièces Meshy fournies par cyril : maillages allégés (.res) + textures, posés dans le repère du modèle
## (-Z devant). Une pièce peut avoir plusieurs morceaux, chacun accroché à son os (le bras plie au coude
## et au poignet), et cache les parties du corps d'origine qu'elle remplace (ellipsoïdes).
## Os du Solaris au repos : épaule (∓0.27, 1.51), coude (∓0.40, 1.17), poignet (∓0.42, 0.95).
## Os gauches du corps Aegis au repos (repère du modèle, pieds à 0) ; voir tools/rig_aegis.py.
const BONES_L := { "upper_arm": Vector3(-0.27, 1.50, 0), "forearm": Vector3(-0.35, 1.24, 0), "hand": Vector3(-0.38, 0.96, 0),
	"thigh": Vector3(-0.12, 0.89, 0), "shin": Vector3(-0.20, 0.47, 0), "foot": Vector3(-0.24, 0.13, 0) }


## Un membre Meshy (côté gauche, vertical, recentré sur chaque articulation) posé sur les os gauche et droit.
## seg = [os, tête, queue, longueur Meshy du morceau, fichier, rayon caché, échelle en largeur, (zone cachée)]
## sided : un modèle par côté (fichiers et textures avec %s = L ou R) au lieu du miroir du gauche.
static func _limb(tex: String, segs: Array, sided := false, folder := "mech") -> Dictionary:
	var parts := []
	var hide := []
	for side in [-1.0, 1.0]:
		var mirror := Transform3D(Basis.from_scale(Vector3(-1, 1, 1)), Vector3.ZERO) if side > 0.0 else Transform3D.IDENTITY
		var suffix := "_L" if side < 0.0 else "_R"
		var flip := Vector3(-1, 1, 1) if side > 0.0 and sided else Vector3.ONE
		for sg in segs:
			var head: Vector3 = sg[1] * flip
			var tail: Vector3 = sg[2] * flip
			var dir := (tail - head).normalized()
			var len := (tail - head).length()
			var q := Basis(Quaternion(Vector3.DOWN, dir))
			var w: float = sg[6]
			var xf := Transform3D(q * Basis.from_scale(Vector3(w, len / sg[3], w)) * Basis(Vector3.UP, PI), head)
			if sided:
				parts.append({ "res": "res://assets/pieces/%s/%s.res" % [folder, sg[4] % suffix.substr(1)], "b": sg[0] + suffix, "xf": xf,
					"tex": "res://assets/pieces/%s/%s" % [folder, tex % suffix.substr(1)] })
			else:
				parts.append({ "res": "res://assets/pieces/%s/%s.res" % [folder, sg[4]], "b": sg[0] + suffix, "xf": mirror * xf })
			var hx := Transform3D(q * Basis.from_scale(Vector3(sg[5], len * 0.5 + 0.07, sg[5])), (head + tail) * 0.5)
			if sg.size() > 7:
				hx = sg[7]     # zone cachée sur mesure (le corps d'origine déborde de l'os)
			hide.append({ "b": sg[0] + suffix, "xf": hx if sided else mirror * hx })
	return { "tex": "res://assets/pieces/%s/%s" % [folder, tex % "L" if sided else tex], "parts": parts, "hide": hide }

## Pièces habillées sur le squelette (tools/skin_pieces.tscn) : <chemin>.res = maillage soudé qui plie avec
## les poids du corps ; <chemin>_corps.res = masque des sommets du corps cachés parce que l'armure est devant.
## mesh_def reste la mise en place de la pièce sur les os (l'outil s'en sert) et le repli si le .res manque.
const SKINNED := {
	"ranger.mech.helmet": "res://assets/pieces/mech/skin_helmet",
	"ranger.mech.chest": "res://assets/pieces/mech/skin_chest",
	"ranger.mech.arms": "res://assets/pieces/mech/skin_arms",
	"ranger.mech.legs": "res://assets/pieces/mech/skin_legs",
	"ranger.exo.arms": "res://assets/pieces/exo/skin_arms",
}


## Chemin (sans extension) de la pièce habillée, "" si la pièce n'en a pas.
static func skinned(piece_id: String) -> String:
	if MESHY_29OCT.has(piece_id):
		return "res://assets/pieces/torses/skin_" + MESHY_29OCT[piece_id][0]
	if MESHY_CASQUES.has(piece_id):
		return "res://assets/pieces/casques/skin_" + MESHY_CASQUES[piece_id][0]
	if MESHY_BRAS.has(piece_id):
		return "res://assets/pieces/bras/skin_" + MESHY_BRAS[piece_id][0]
	return SKINNED.get(piece_id, "")


## Toutes les pièces habillées (l'outil tools/skin_pieces.tscn les refait toutes).
static func skinned_ids() -> Array:
	return SKINNED.keys() + MESHY_29OCT.keys() + MESHY_CASQUES.keys() + MESHY_BRAS.keys()


static func mesh_def(piece_id: String) -> Dictionary:
	if MESHY_29OCT.has(piece_id):
		# torse Meshy du 29 oct : un seul maillage porté par la poitrine, col à 1,68 m
		var f: String = MESHY_29OCT[piece_id][0]
		var cy: float = 1.68 - float(MESHY_29OCT[piece_id][1]) * 0.36 * 0.5
		return {
			"tex": "res://assets/pieces/torses/" + f,
			"parts": [{ "res": "res://assets/pieces/torses/%s.res" % f, "src": "res://assets/pieces/torses/src/%s.glb" % f, "b": "chest",
				"xf": Transform3D(Basis(Vector3.UP, PI).scaled(Vector3(0.36, 0.36, 0.36)), Vector3(0, cy, 0.0)) }],
			"hide": [{ "b": "chest", "xf": Transform3D(Basis.from_scale(Vector3(0.22, 0.27, 0.17)), Vector3(0, 1.4, 0.0)) }],
		}
	if MESHY_CASQUES.has(piece_id):
		var c: Array = MESHY_CASQUES[piece_id]
		var f: String = c[0]
		var s: float = c[1]
		return {
			"tex": "res://assets/pieces/casques/" + f,
			"parts": [{ "res": "res://assets/pieces/casques/%s.res" % f, "src": "res://assets/pieces/casques/src/%s.glb" % f, "b": "head",
				"xf": Transform3D(Basis(Vector3.RIGHT, -float(c[4])) * Basis(Vector3.UP, PI).scaled(Vector3(s, s, s)), Vector3(0, c[2], c[3])) }],
			"hide": [{ "b": "head", "xf": Transform3D(Basis.from_scale(Vector3(0.15, 0.17, 0.18)), Vector3(0, 1.75, 0.0)) }],
		}
	if MESHY_BRAS.has(piece_id):
		var f: String = MESHY_BRAS[piece_id][0]
		var ln: Array = MESHY_BRAS[piece_id][1]
		var w: Array = MESHY_BRAS[piece_id][2]
		var sh: Vector3 = BONES_L["upper_arm"]
		var el: Vector3 = BONES_L["forearm"]
		var wr: Vector3 = BONES_L["hand"]
		var tip := wr + (wr - el).normalized() * 0.21
		return _limb(f, [["upper_arm", sh, el, ln[0], f + "_upper", 0.14, w[0]], ["forearm", el, wr, ln[1], f + "_fore", 0.13, w[1]],
			["hand", wr, tip, ln[2], f + "_hand", 0.11, w[2]]], false, "bras")
	match piece_id:
		"ranger.mech.helmet":
			return {
				"tex": "res://assets/pieces/mech/helmet",
				"parts": [{ "res": "res://assets/pieces/mech/helmet.res", "b": "head",
					"xf": Transform3D(Basis(Vector3.UP, PI).scaled(Vector3(0.232, 0.232, 0.232)), Vector3(0, 1.758, 0.0)) }],
				"hide": [{ "b": "head", "xf": Transform3D(Basis.from_scale(Vector3(0.15, 0.15, 0.17)), Vector3(0, 1.80, -0.02)) }],
			}
		"ranger.mech.chest":
			# torse Meshy (col, épaulettes, ventre et ceinture) porté par l'os de la poitrine
			return {
				"tex": "res://assets/pieces/mech/chest",
				"parts": [{ "res": "res://assets/pieces/mech/torso.res", "b": "chest",
					"xf": Transform3D(Basis(Vector3.UP, PI).scaled(Vector3(0.36, 0.36, 0.36)), Vector3(0, 1.36, 0.0)) }],
				"hide": [{ "b": "chest", "xf": Transform3D(Basis.from_scale(Vector3(0.22, 0.27, 0.17)), Vector3(0, 1.4, 0.0)) }],
			}
		"ranger.mech.arms":
			# bras gauche Meshy coupé en 3 (bras, avant-bras, main), le droit est son miroir
			var sh: Vector3 = BONES_L["upper_arm"]
			var el: Vector3 = BONES_L["forearm"]
			var wr: Vector3 = BONES_L["hand"]
			var tip := wr + (wr - el).normalized() * 0.21
			var d := _limb("arms", [["upper_arm", sh, el, 0.54, "arm_upper", 0.14, 0.64], ["forearm", el, wr, 0.52, "arm_fore", 0.13, 0.56], ["hand", wr, tip, 0.5, "arm_hand", 0.11, 0.44]])
			for side in [-1.0, 1.0]:
				# les lames d'épaule du Solaris d'origine, au-dessus de l'épaulière
				d["hide"].append({ "b": "upper_arm" + ("_L" if side < 0.0 else "_R"), "xf": Transform3D(Basis.from_scale(Vector3(0.14, 0.12, 0.14)), Vector3(0.37 * side, 1.64, 0)) })
			return d
		"ranger.exo.arms":
			# bras Meshy « Exo Ranger » : un modèle pour le gauche, un pour le droit, coupés en 3 (bras, avant-bras, main)
			var sh: Vector3 = BONES_L["upper_arm"]
			var el: Vector3 = BONES_L["forearm"]
			var wr: Vector3 = BONES_L["hand"]
			var tip := wr + (wr - el).normalized() * 0.24
			return _limb("arm_%s", [["upper_arm", sh, el, 0.52, "arm_%s_upper", 0.13, 0.47], ["forearm", el, wr, 0.66, "arm_%s_fore", 0.12, 0.45], ["hand", wr, tip, 0.53, "arm_%s_hand", 0.1, 0.45]], true, "exo")
		"ranger.mech.legs":
			# jambe gauche Meshy coupée en 3 (cuisse, tibia, pied), la droite est son miroir.
			# Le rig du Solaris a une cuisse courte : la cuisse Meshy est un peu tassée (×0,40) et le tibia ×0,50.
			var hip: Vector3 = BONES_L["thigh"]
			var knee: Vector3 = BONES_L["shin"]
			var ank: Vector3 = BONES_L["foot"]
			var sole := Vector3(ank.x, 0.0, ank.z)
			var legs := _limb("legs", [
				["thigh", hip, knee, 0.575, "leg_thigh", 0.0, 0.8, Transform3D(Basis.from_scale(Vector3(0.17, 0.25, 0.17)), Vector3(-0.16, 0.72, -0.02))],
				["shin", knee, ank, 0.8, "leg_shin", 0.0, 0.76, Transform3D(Basis.from_scale(Vector3(0.17, 0.27, 0.25)), Vector3(-0.165, 0.38, 0.03))],
				["foot", ank, sole, 0.30, "leg_foot", 0.0, 0.72, Transform3D(Basis.from_scale(Vector3(0.2, 0.26, 0.38)), Vector3(-0.17, 0.08, -0.04))]])
			for side in [-1.0, 1.0]:
				# les plaques de hanche du Solaris d'origine, qui dépassent au-dessus des cuissardes
				legs["hide"].append({ "b": "thigh" + ("_L" if side < 0.0 else "_R"), "xf": Transform3D(Basis.from_scale(Vector3(0.12, 0.1, 0.2)), Vector3(0.24 * side, 0.94, -0.02)) })
			return legs
	return {}



## Lecture d'un look (preset ou look porté) : utilisée par le Solaris, la Forge et les vignettes.
static func look_color(look: Dictionary, zone: int) -> Color:
	return Color(look["color_slots"][zone])


static func look_material(look: Dictionary, zone: int) -> Dictionary:
	return find(MATERIALS, look["material_slots"][zone])


## Usure effective : le type choisi, multiplié par le curseur d'intensité (100 % = le type tel quel).
static func look_wear(look: Dictionary) -> Dictionary:
	var w := find(WEAR, look.get("wear_state", "clean")).duplicate()
	var k := clampf(float(look.get("wear_amount", 1.0)), 0.0, 1.0)
	for key in ["dirt", "scratches", "chips", "fade"]:
		w[key] = float(w[key]) * k
	return w


## Emplacements qu'un pack fournit (tous par défaut).
static func pack_slots(pack: Dictionary) -> Array:
	return pack.get("slots", SLOTS)


static func has_piece(piece_id: String) -> bool:
	for p in RANGER_PACKS:
		if p["id"] == pack_of(piece_id):
			return slot_of(piece_id) in pack_slots(p)
	return false

## Presets de départ fournis (décision : 10 presets par mode, les autres emplacements sont vides).
static func starter_presets() -> Array:
	var mech := _preset("Mech orange", "ranger.default", ["paint_gloss", "paint_matte", "metal_polished", "metal_brushed", "rubber", "emissive"],
		["#F07A2A", "#F2EEE4", "#1E2024", "#1E2024", "#0E0F11", "#7EC8F0"], "scratched", "chevrons", "drop", "salute", ["salute", "point", "scan"])
	mech["helmet_piece_id"] = "ranger.mech.helmet"
	mech["arms_piece_id"] = "ranger.mech.arms"
	mech["chest_piece_id"] = "ranger.mech.chest"
	mech["legs_piece_id"] = "ranger.mech.legs"
	var aegis := _preset("Aegis", "ranger.default", ["paint_gloss", "paint_matte", "metal_polished", "metal_brushed", "rubber", "emissive"],
		["#F07A2A", "#F2EEE4", "#1E2024", "#1E2024", "#0E0F11", "#7EC8F0"], "clean", "none", "drop", "salute", ["salute", "point", "scan"])
	var aegis_exo: Dictionary = aegis.duplicate(true)
	aegis_exo["name"] = "Aegis bras Exo"
	aegis_exo["arms_piece_id"] = "ranger.exo.arms"
	return [
		aegis,
		aegis_exo,
		_preset("Épave", "ranger.default", ["paint_matte", "paint_matte", "metal_brushed", "metal_brushed", "fabric", "emissive"],
			["#8E7F68", "#D85A10", "#B87333", "#5A5E66", "#3A2418", "#E0402E"], "worn", "danger", "scan", "fist", ["wave", "point", "stretch"]),
		_preset("Horizon", "ranger.default", ["paint_matte", "paint_matte", "paint_gloss", "metal_brushed", "rubber", "emissive"],
			["#8E9196", "#34373D", "#F07A2A", "#5A5E66", "#1E2024", "#7EC8F0"], "scratched", "horizon", "drop", "salute", ["salute", "point", "scan"]),
		_preset("Originel ivoire", "ranger.default", ["ceramic", "metal_brushed", "metal_polished", "metal_brushed", "fabric", "emissive"],
			["#E8E0CF", "#8C6A3F", "#D4A84A", "#3A3A3F", "#2B2A28", "#FFC85A"], "clean", "glyphes", "ignite", "kneel", ["wave", "kneel", "scan"]),
		_preset("Éclipse", "ranger.default", ["paint_gloss", "carbon", "chrome", "metal_brushed", "rubber", "emissive"],
			["#34373D", "#1E2024", "#A070F0", "#5A5E66", "#0E0F11", "#A070F0"], "clean", "none", "drop", "crossed", ["point", "stretch", "salute"]),
		mech,
	]


static func _preset(name: String, pack: String, mats: Array, cols: Array, wear: String, vinyl: String, arrival: String, victory: String, emotes: Array) -> Dictionary:
	var vplace := "chest"
	for v in VINYLS:
		if v["id"] == vinyl and v.has("place"):
			vplace = v["place"]
	return {
		"name": name, "exosuitClass": "ranger",
		"helmet_piece_id": pack + ".helmet", "chest_piece_id": pack + ".chest",
		"arms_piece_id": pack + ".arms", "legs_piece_id": pack + ".legs",
		"material_slots": mats.duplicate(), "color_slots": cols.duplicate(),
		"wear_state": wear, "vinyl_id": vinyl, "vinyl_place": vplace,
		"animation_arrival": arrival, "animation_victory": victory, "emotes": emotes.duplicate(),
	}


static func empty_preset(n: int) -> Dictionary:
	var p := _preset("Emplacement %d" % n, "ranger.default", ["paint_gloss", "paint_matte", "metal_polished", "metal_brushed", "rubber", "emissive"],
		["#C9C6C0", "#34373D", "#D4A84A", "#5A5E66", "#1E2024", "#9AF0FF"], "clean", "none", "drop", "salute", ["wave", "point", "kneel"])
	p["empty"] = true
	return p


static func find(list: Array, id: String) -> Dictionary:
	for e in list:
		if e["id"] == id:
			return e
	return list[0]


static func index_of(list: Array, id: String) -> int:
	for i in list.size():
		if list[i]["id"] == id:
			return i
	return 0


static func pack_of(piece_id: String) -> String:
	return piece_id.substr(0, piece_id.rfind("."))


static func slot_of(piece_id: String) -> String:
	return piece_id.substr(piece_id.rfind(".") + 1)


static func pack_name(pack_id: String) -> String:
	for p in RANGER_PACKS:
		if p["id"] == pack_id:
			return p["name"]
	return pack_id


## Le catalogue complet (77 packs) pour un mode, depuis le JSON du document de conception.
static func full_catalog(mode: String) -> Array:
	var f := FileAccess.open("res://data/catalogue-armures.json", FileAccess.READ)
	if f == null:
		return []
	var data = JSON.parse_string(f.get_as_text())
	var out := []
	if data is Dictionary:
		for p in data.get("armorPacks", []):
			if p["exosuitClass"] == mode:
				out.append(p)
	return out


# ---------------------------------------------------------------- géométrie des pièces
## Une forme : t = box | cyl | sph | torus | cone ; s = taille ; p = position ; r = rotation ; z = zone (1-6) ; b = os.
static func _f(t: String, s, p: Vector3, z: int, b: String, r := Vector3.ZERO) -> Dictionary:
	return { "t": t, "s": s, "p": p, "r": r, "z": z, "b": b }


## Côté : sx = -1 gauche du personnage (-X), +1 droite. Os suffixé _L / _R.
static func _side(sx: float) -> String:
	return "_L" if sx < 0.0 else "_R"


## Retourne { shapes: [], anchors: { nom: [pos, rot, os] }, flames: Vector3 (torse) }.
static func piece(piece_id: String) -> Dictionary:
	var out := _shape_piece(piece_id)
	if not out.has("mesh"):
		out["shapes"] = []     # corps Aegis : les pièces en formes simples sont retirées (ancres et flammes gardées)
	return out


static func _shape_piece(piece_id: String) -> Dictionary:
	var pack := pack_of(piece_id)
	var slot := slot_of(piece_id)
	var sh := []
	var an := {}
	var out := { "shapes": sh, "anchors": an }
	var md := mesh_def(piece_id)
	if not md.is_empty():
		out["mesh"] = md
		# les ancres de vinyle et les flammes restent celles de la pièce Default du même emplacement
		var base := _shape_piece("ranger.default." + slot)
		out["anchors"] = base["anchors"]
		if base.has("flames"):
			out["flames"] = base["flames"]
		return out
	match slot:
		"helmet":
			match pack:
				"ranger.recup":
					sh.append(_f("box", Vector3(0.16, 0.1, 0.03), Vector3(0.05, 1.83, -0.13), 2, "head", Vector3(0, 0, 0.2)))
					sh.append(_f("box", Vector3(0.27, 0.025, 0.025), Vector3(0, 1.76, -0.115), 5, "head", Vector3(0, 0, -0.08)))
					sh.append(_f("sph", Vector3(0.035, 0.05, 0), Vector3(-0.05, 1.79, -0.14), 6, "head"))
					sh.append(_f("cyl", Vector3(0.006, 0.32, 0), Vector3(-0.1, 1.98, 0.06), 4, "head", Vector3(0.1, 0, 0.3)))
					sh.append(_f("box", Vector3(0.06, 0.08, 0.1), Vector3(-0.13, 1.8, 0.0), 1, "head"))
				"ranger.horizon":
					sh.append(_f("box", Vector3(0.24, 0.05, 0.05), Vector3(0, 1.79, -0.13), 6, "head"))
					sh.append(_f("box", Vector3(0.26, 0.012, 0.06), Vector3(0, 1.82, -0.13), 3, "head"))
					for sx in [-1.0, 1.0]:
						sh.append(_f("box", Vector3(0.05, 0.11, 0.13), Vector3(sx * 0.13, 1.78, 0.0), 2, "head"))
					sh.append(_f("box", Vector3(0.18, 0.03, 0.22), Vector3(0, 1.91, 0.0), 1, "head"))
				"ranger.originel":
					sh.append(_f("box", Vector3(0.02, 0.13, 0.2), Vector3(0, 1.96, 0.02), 3, "head", Vector3(-0.3, 0, 0)))
					for sx in [-1.0, 1.0]:
						sh.append(_f("box", Vector3(0.015, 0.1, 0.16), Vector3(sx * 0.07, 1.93, 0.03), 3, "head", Vector3(-0.3, 0, sx * -0.35)))
					sh.append(_f("torus", Vector3(0.15, 0.17, 0), Vector3(0, 1.86, 0.13), 6, "head", Vector3(1.25, 0, 0)))
					sh.append(_f("box", Vector3(0.18, 0.03, 0.03), Vector3(0, 1.79, -0.135), 6, "head"))
					sh.append(_f("box", Vector3(0.22, 0.06, 0.02), Vector3(0, 1.84, -0.125), 1, "head", Vector3(-0.2, 0, 0)))
				_:
					sh.append(_f("box", Vector3(0.04, 0.07, 0.22), Vector3(0, 1.9, 0.0), 1, "head"))
					sh.append(_f("box", Vector3(0.2, 0.035, 0.04), Vector3(0, 1.78, -0.13), 6, "head"))
		"chest":
			var flames := Vector3(0.22, 1.2, 0.3)
			match pack:
				"ranger.recup":
					sh.append(_f("box", Vector3(0.18, 0.2, 0.05), Vector3(-0.08, 1.4, -0.21), 2, "chest", Vector3(0, 0, 0.1)))
					sh.append(_f("box", Vector3(0.15, 0.15, 0.05), Vector3(0.1, 1.32, -0.2), 1, "chest", Vector3(0, 0, -0.15)))
					sh.append(_f("cyl", Vector3(0.09, 0.42, 0), Vector3(0.18, 1.3, 0.3), 4, "chest", Vector3(0.5, 0, -0.35)))
					sh.append(_f("cyl", Vector3(0.1, 0.05, 0), Vector3(0.24, 1.12, 0.38), 6, "chest", Vector3(0.5, 0, -0.35)))
					sh.append(_f("cyl", Vector3(0.02, 0.6, 0), Vector3(-0.15, 1.1, 0.27), 5, "chest", Vector3(0, 0, 0.9)))
					sh.append(_f("box", Vector3(0.22, 0.2, 0.06), Vector3(-0.1, 1.42, 0.25), 2, "chest", Vector3(0, 0, 0.12)))
					an["vinyl_chest"] = [Vector3(-0.08, 1.4, -0.236), Vector3(0, 0, 0.1), "chest"]
					an["vinyl_back"] = [Vector3(-0.1, 1.42, 0.281), Vector3(0, PI, -0.12), "chest"]
					flames = Vector3(0.2, 1.15, 0.36)
				"ranger.horizon":
					sh.append(_f("box", Vector3(0.38, 0.26, 0.07), Vector3(0, 1.36, -0.21), 1, "chest", Vector3(-0.08, 0, 0)))
					for sx in [-1.0, 1.0]:
						sh.append(_f("box", Vector3(0.02, 0.24, 0.075), Vector3(sx * 0.12, 1.36, -0.215), 3, "chest", Vector3(-0.08, 0, 0)))
						sh.append(_f("cyl", Vector3(0.1, 0.45, 0), Vector3(sx * 0.22, 1.3, 0.32), 4, "chest", Vector3(0.3, 0, 0)))
						sh.append(_f("cyl", Vector3(0.12, 0.08, 0), Vector3(sx * 0.22, 1.08, 0.39), 6, "chest", Vector3(0.3, 0, 0)))
					sh.append(_f("box", Vector3(0.32, 0.36, 0.14), Vector3(0, 1.36, 0.25), 2, "chest"))
					sh.append(_f("box", Vector3(0.3, 0.05, 0.12), Vector3(0, 1.53, -0.13), 5, "chest"))
					an["vinyl_chest"] = [Vector3(0.0, 1.37, -0.252), Vector3(-0.08, 0, 0), "chest"]
					an["vinyl_back"] = [Vector3(0.0, 1.38, 0.322), Vector3(0, PI, 0), "chest"]
				"ranger.originel":
					sh.append(_f("box", Vector3(0.32, 0.24, 0.06), Vector3(0, 1.4, -0.2), 1, "chest", Vector3(-0.1, 0, 0)))
					sh.append(_f("box", Vector3(0.34, 0.02, 0.07), Vector3(0, 1.52, -0.19), 3, "chest", Vector3(-0.1, 0, 0)))
					sh.append(_f("sph", Vector3(0.09, 0.18, 0), Vector3(0, 1.27, -0.24), 6, "chest"))
					sh.append(_f("torus", Vector3(0.09, 0.115, 0), Vector3(0, 1.27, -0.235), 3, "chest", Vector3(PI / 2, 0, 0)))
					for sx in [-1.0, 1.0]:
						sh.append(_f("box", Vector3(0.95, 0.06, 0.28), Vector3(sx * 0.62, 1.48, 0.3), 1, "chest", Vector3(0.1, 0, sx * 0.55)))
						sh.append(_f("box", Vector3(0.95, 0.025, 0.07), Vector3(sx * 0.62, 1.48, 0.43), 3, "chest", Vector3(0.1, 0, sx * 0.55)))
						sh.append(_f("cyl", Vector3(0.09, 0.42, 0), Vector3(sx * 0.22, 1.3, 0.32), 1, "chest", Vector3(0.3, 0, 0)))
						sh.append(_f("cyl", Vector3(0.1, 0.06, 0), Vector3(sx * 0.22, 1.09, 0.39), 6, "chest", Vector3(0.3, 0, 0)))
					sh.append(_f("box", Vector3(0.26, 0.3, 0.1), Vector3(0, 1.38, 0.24), 2, "chest"))
					an["vinyl_chest"] = [Vector3(0.0, 1.43, -0.233), Vector3(-0.1, 0, 0), "chest"]
					an["vinyl_back"] = [Vector3(0.0, 1.4, 0.292), Vector3(0, PI, 0), "chest"]
					out["light"] = Vector3(0, 1.28, -0.32)
				_:
					sh.append(_f("box", Vector3(0.34, 0.22, 0.06), Vector3(0, 1.38, -0.21), 1, "chest", Vector3(-0.1, 0, 0)))
					sh.append(_f("box", Vector3(0.3, 0.05, 0.1), Vector3(0, 1.53, -0.15), 3, "chest"))
					sh.append(_f("box", Vector3(0.3, 0.32, 0.12), Vector3(0, 1.35, 0.24), 2, "chest"))
					for sx in [-1.0, 1.0]:
						sh.append(_f("cyl", Vector3(0.07, 0.3, 0), Vector3(sx * 0.13, 1.22, 0.31), 4, "chest", Vector3(0.3, 0, 0)))
						sh.append(_f("cyl", Vector3(0.08, 0.04, 0), Vector3(sx * 0.13, 1.07, 0.35), 6, "chest", Vector3(0.3, 0, 0)))
					an["vinyl_chest"] = [Vector3(0.0, 1.39, -0.244), Vector3(-0.1, 0, 0), "chest"]
					an["vinyl_back"] = [Vector3(0.0, 1.36, 0.301), Vector3(0, PI, 0), "chest"]
					flames = Vector3(0.13, 1.1, 0.33)
			out["flames"] = flames
		"arms":
			match pack:
				"ranger.recup":
					sh.append(_f("box", Vector3(0.28, 0.14, 0.3), Vector3(-0.35, 1.6, 0.0), 2, "upper_arm_L", Vector3(0, 0, -0.3)))
					sh.append(_f("box", Vector3(0.29, 0.03, 0.08), Vector3(-0.35, 1.6, -0.15), 4, "upper_arm_L", Vector3(0, 0, -0.3)))
					sh.append(_f("box", Vector3(0.11, 0.2, 0.13), Vector3(-0.41, 1.06, -0.02), 1, "forearm_L"))
					sh.append(_f("cyl", Vector3(0.075, 0.24, 0), Vector3(0.41, 1.08, 0.0), 5, "forearm_R"))
					sh.append(_f("box", Vector3(0.16, 0.06, 0.18), Vector3(0.31, 1.58, 0.0), 1, "upper_arm_R", Vector3(0, 0, 0.35)))
					an["vinyl_shoulder_L"] = [Vector3(-0.42, 1.58, 0.0), Vector3(0, PI / 2, -0.3), "upper_arm_L"]
					an["vinyl_shoulder_R"] = [Vector3(0.39, 1.56, 0.0), Vector3(0, -PI / 2, 0.35), "upper_arm_R"]
				"ranger.horizon":
					for sx in [-1.0, 1.0]:
						var s := _side(sx)
						sh.append(_f("box", Vector3(0.24, 0.12, 0.26), Vector3(sx * 0.34, 1.6, 0.0), 1, "upper_arm" + s, Vector3(0, 0, sx * 0.2)))
						sh.append(_f("box", Vector3(0.245, 0.03, 0.04), Vector3(sx * 0.34, 1.6, -0.12), 3, "upper_arm" + s, Vector3(0, 0, sx * 0.2)))
						sh.append(_f("box", Vector3(0.11, 0.24, 0.13), Vector3(sx * 0.41, 1.06, -0.02), 2, "forearm" + s))
						sh.append(_f("box", Vector3(0.115, 0.03, 0.135), Vector3(sx * 0.41, 1.15, -0.02), 5, "forearm" + s))
					an["vinyl_shoulder_L"] = [Vector3(-0.465, 1.575, 0.0), Vector3(0, PI / 2, -0.2), "upper_arm_L"]
					an["vinyl_shoulder_R"] = [Vector3(0.465, 1.575, 0.0), Vector3(0, -PI / 2, 0.2), "upper_arm_R"]
				"ranger.originel":
					for sx in [-1.0, 1.0]:
						var s := _side(sx)
						sh.append(_f("sph", Vector3(0.17, 0.2, 0), Vector3(sx * 0.33, 1.59, 0.0), 1, "upper_arm" + s))
						sh.append(_f("torus", Vector3(0.15, 0.17, 0), Vector3(sx * 0.33, 1.57, 0.0), 3, "upper_arm" + s, Vector3(0, 0, sx * 0.25)))
						sh.append(_f("box", Vector3(0.03, 0.28, 0.12), Vector3(sx * 0.47, 1.08, 0.0), 3, "forearm" + s))
						sh.append(_f("box", Vector3(0.1, 0.22, 0.12), Vector3(sx * 0.41, 1.06, -0.02), 1, "forearm" + s))
					an["vinyl_shoulder_L"] = [Vector3(-0.49, 1.59, 0.0), Vector3(0, PI / 2, 0), "upper_arm_L"]
					an["vinyl_shoulder_R"] = [Vector3(0.49, 1.59, 0.0), Vector3(0, -PI / 2, 0), "upper_arm_R"]
				_:
					for sx in [-1.0, 1.0]:
						var s := _side(sx)
						sh.append(_f("box", Vector3(0.2, 0.09, 0.22), Vector3(sx * 0.33, 1.6, 0.0), 1, "upper_arm" + s, Vector3(0, 0, sx * 0.25)))
						sh.append(_f("box", Vector3(0.2, 0.02, 0.23), Vector3(sx * 0.33, 1.65, 0.0), 3, "upper_arm" + s, Vector3(0, 0, sx * 0.25)))
						sh.append(_f("box", Vector3(0.1, 0.2, 0.12), Vector3(sx * 0.41, 1.06, -0.02), 2, "forearm" + s))
					an["vinyl_shoulder_L"] = [Vector3(-0.44, 1.575, 0.0), Vector3(0, PI / 2, -0.25), "upper_arm_L"]
					an["vinyl_shoulder_R"] = [Vector3(0.44, 1.575, 0.0), Vector3(0, -PI / 2, 0.25), "upper_arm_R"]
		"legs":
			match pack:
				"ranger.recup":
					sh.append(_f("box", Vector3(0.18, 0.34, 0.2), Vector3(-0.15, 0.32, -0.02), 2, "shin_L"))
					sh.append(_f("box", Vector3(0.17, 0.32, 0.19), Vector3(0.15, 0.31, -0.02), 1, "shin_R"))
					sh.append(_f("cyl", Vector3(0.09, 0.08, 0), Vector3(0.16, 0.56, -0.01), 5, "shin_R"))
					sh.append(_f("box", Vector3(0.12, 0.16, 0.05), Vector3(-0.15, 0.73, -0.1), 4, "thigh_L", Vector3(0, 0, 0.2)))
				"ranger.horizon":
					for sx in [-1.0, 1.0]:
						var s := _side(sx)
						sh.append(_f("box", Vector3(0.15, 0.22, 0.06), Vector3(sx * 0.15, 0.72, -0.1), 1, "thigh" + s))
						sh.append(_f("box", Vector3(0.12, 0.1, 0.07), Vector3(sx * 0.16, 0.56, -0.1), 4, "shin" + s))
						sh.append(_f("box", Vector3(0.15, 0.34, 0.07), Vector3(sx * 0.165, 0.33, -0.08), 1, "shin" + s))
						sh.append(_f("box", Vector3(0.03, 0.3, 0.075), Vector3(sx * 0.165, 0.33, -0.085), 3, "shin" + s))
				"ranger.originel":
					for sx in [-1.0, 1.0]:
						var s := _side(sx)
						sh.append(_f("box", Vector3(0.17, 0.34, 0.19), Vector3(sx * 0.15, 0.32, -0.02), 1, "shin" + s))
						sh.append(_f("box", Vector3(0.05, 0.3, 0.02), Vector3(sx * 0.15, 0.32, -0.12), 3, "shin" + s))
						sh.append(_f("cyl", Vector3(0.06, 0.03, 0), Vector3(sx * 0.16, 0.57, -0.11), 6, "shin" + s, Vector3(PI / 2, 0, 0)))
						sh.append(_f("box", Vector3(0.14, 0.2, 0.05), Vector3(sx * 0.15, 0.73, -0.1), 2, "thigh" + s))
				_:
					for sx in [-1.0, 1.0]:
						var s := _side(sx)
						sh.append(_f("box", Vector3(0.13, 0.18, 0.05), Vector3(sx * 0.15, 0.72, -0.1), 2, "thigh" + s))
						sh.append(_f("box", Vector3(0.11, 0.09, 0.06), Vector3(sx * 0.16, 0.56, -0.1), 3, "shin" + s))
						sh.append(_f("box", Vector3(0.13, 0.3, 0.06), Vector3(sx * 0.165, 0.33, -0.08), 1, "shin" + s))
	return out
