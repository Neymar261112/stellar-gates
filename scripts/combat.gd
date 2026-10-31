extends Node
class_name Combat
## Combat du Solaris en mode Ranger, repris d'Anthem : deux armes (une en main, l'autre dans le dos),
## tir au sol et en vol stationnaire seulement, grenade (LB) et lanceur d'assaut (RB), mêlée,
## ultime « Batterie de missiles » tirée depuis les épaules, vie et bouclier qui se régénère.

signal hit(target: Node3D, amount: float, melee: bool)
signal damaged(amount: float)
signal died
signal respawned
signal power_used(index: int)
signal combo(target: Node3D)
signal ultimate_started
signal weapon_changed(index: int)

## Les deux armes du Ranger (modèles Meshy de cyril). L'origine de chaque arme est sa poignée.
## scale / offset : placement du modèle couché le long de X (canon vers -X) dans la main.
const WEAPONS := [
	{ "id": "avantgarde", "name": "Fusil d'assaut Avant-garde", "family": "Fusil d'assaut",
	  "mesh": "res://assets/weapons/rifle.res", "tex": "res://assets/weapons/rifle",
	  "scale": 0.47, "offset": Vector3(0, 0.047, -0.188), "muzzle": Vector3(0, 0.08, -0.64),
	  "fore": Vector3(0, -0.02, -0.3),
	  "auto": true, "damage": 11.0, "interval": 0.11, "mag": 30, "reload": 1.5,
	  "spread_hip": 0.035, "spread_aim": 0.008, "kick": 0.006, "shake": 0.07, "push": 0.0,
	  "tracer": 0.05, "casing": 0.6, "twin": false },
	{ "id": "vipers", "name": "Fusil de précision Twin Vipers", "family": "Fusil de précision",
	  "mesh": "res://assets/weapons/vipers.res", "tex": "res://assets/weapons/vipers",
	  "scale": 0.56, "offset": Vector3(0, 0.056, -0.213), "muzzle": Vector3(0, 0.07, -0.75),
	  "fore": Vector3(0, -0.02, -0.36),
	  "auto": false, "damage": 44.0, "interval": 0.32, "mag": 10, "reload": 1.9,
	  "spread_hip": 0.02, "spread_aim": 0.0015, "kick": 0.022, "shake": 0.14, "push": 1.6,
	  "tracer": 0.07, "casing": 1.0, "twin": true },
]
## Les autres armes du butin (modèles Meshy de cyril du 29 oct, tools/meshy_armes.py). Même repère, mais le
## maillage est déjà à la bonne taille avec l'origine à la poignée (scale 1, offset nul).
## L'arme en main et celle du dos prennent le modèle et les stats de l'objet équipé (Arme 1 / Arme 2).
## Clés en plus, facultatives : range (portée, m), sound / volume (son du tir), flash (taille de la flamme),
## lights (lumières peintes dans la texture qui prennent la couleur Énergie : 1 froides, 2 chaudes).
## Tacticien et Minuit réduits à 0,87 (ils dépassaient trop devant le Solaris) : bouche et garde-main suivent.
const WEAPON_MODELS := {
	"tacticien": { "id": "tacticien", "name": "Fusil d'assaut Tacticien", "family": "Fusil d'assaut",
	  "mesh": "res://assets/weapons/tacticien.res", "tex": "res://assets/weapons/tacticien",
	  "scale": 0.87, "offset": Vector3.ZERO, "muzzle": Vector3(0, 0.113, -0.565), "fore": Vector3(0, 0.0, -0.383),
	  "auto": true, "damage": 13.0, "interval": 0.125, "mag": 28, "reload": 1.6,
	  "spread_hip": 0.03, "spread_aim": 0.007, "kick": 0.008, "shake": 0.08, "push": 0.0,
	  "tracer": 0.05, "casing": 0.6, "twin": false },
	"ivoire": { "id": "ivoire", "name": "Fusil d'assaut Vigile", "family": "Fusil d'assaut",
	  "mesh": "res://assets/weapons/ivoire.res", "tex": "res://assets/weapons/ivoire",
	  "scale": 1.0, "offset": Vector3.ZERO, "muzzle": Vector3(0, 0.086, -0.683), "fore": Vector3(0, 0.034, -0.325),
	  "auto": true, "damage": 10.0, "interval": 0.1, "mag": 34, "reload": 1.4,
	  "spread_hip": 0.028, "spread_aim": 0.005, "kick": 0.005, "shake": 0.06, "push": 0.0,
	  "tracer": 0.05, "casing": 0.6, "twin": false, "range": 140.0 },
	"minuit": { "id": "minuit", "name": "Fusil d'assaut Minuit", "family": "Fusil d'assaut",
	  "mesh": "res://assets/weapons/minuit.res", "tex": "res://assets/weapons/minuit",
	  "scale": 0.87, "offset": Vector3.ZERO, "muzzle": Vector3(0, 0.102, -0.639), "fore": Vector3(0, 0.038, -0.371),
	  "auto": true, "damage": 19.0, "interval": 0.17, "mag": 40, "reload": 2.4,
	  "spread_hip": 0.045, "spread_aim": 0.012, "kick": 0.011, "shake": 0.11, "push": 0.4,
	  "tracer": 0.06, "casing": 0.8, "twin": false, "volume": 0.0, "flash": 1.2, "lights": 2 },
	"repetiteur": { "id": "repetiteur", "name": "Fusil d'assaut Répétiteur", "family": "Fusil d'assaut",
	  "mesh": "res://assets/weapons/repetiteur.res", "tex": "res://assets/weapons/repetiteur",
	  "scale": 1.0, "offset": Vector3.ZERO, "muzzle": Vector3(0, 0.053, -0.635), "fore": Vector3(0, 0.025, -0.309),
	  "auto": true, "damage": 7.0, "interval": 0.07, "mag": 45, "reload": 1.7,
	  "spread_hip": 0.05, "spread_aim": 0.014, "kick": 0.004, "shake": 0.05, "push": 0.0,
	  "tracer": 0.04, "casing": 0.5, "twin": false, "volume": -5.0, "flash": 0.8 },
	"sentinelle": { "id": "sentinelle", "name": "Fusil de précision Sentinelle arctique", "family": "Fusil de précision",
	  "mesh": "res://assets/weapons/sentinelle.res", "tex": "res://assets/weapons/sentinelle",
	  "scale": 1.0, "offset": Vector3.ZERO, "muzzle": Vector3(0, 0.059, -0.784), "fore": Vector3(0, 0.025, -0.412),
	  "auto": false, "damage": 58.0, "interval": 0.45, "mag": 8, "reload": 2.1,
	  "spread_hip": 0.018, "spread_aim": 0.0008, "kick": 0.026, "shake": 0.15, "push": 1.6,
	  "tracer": 0.07, "casing": 1.0, "twin": false, "range": 180.0, "sound": "sniper", "flash": 1.4 },
	"silencieux": { "id": "silencieux", "name": "Fusil de précision Silencieux", "family": "Fusil de précision",
	  "mesh": "res://assets/weapons/silencieux.res", "tex": "res://assets/weapons/silencieux",
	  "scale": 1.0, "offset": Vector3.ZERO, "muzzle": Vector3(0, 0.116, -0.784), "fore": Vector3(0, 0.043, -0.339),
	  "auto": false, "damage": 30.0, "interval": 0.2, "mag": 14, "reload": 1.7,
	  "spread_hip": 0.02, "spread_aim": 0.002, "kick": 0.014, "shake": 0.08, "push": 0.6,
	  "tracer": 0.06, "casing": 0.9, "twin": false, "sound": "rifle", "volume": -12.0, "flash": 0.5 },
	"titan": { "id": "titan", "name": "Fusil de précision Titan", "family": "Fusil de précision",
	  "mesh": "res://assets/weapons/titan.res", "tex": "res://assets/weapons/titan",
	  "scale": 1.0, "offset": Vector3.ZERO, "muzzle": Vector3(0, 0.079, -0.845), "fore": Vector3(0, 0.018, -0.468),
	  "auto": false, "damage": 80.0, "interval": 0.7, "mag": 6, "reload": 2.6,
	  "spread_hip": 0.022, "spread_aim": 0.001, "kick": 0.035, "shake": 0.2, "push": 2.4,
	  "tracer": 0.08, "casing": 1.2, "twin": false, "range": 150.0, "sound": "sniper", "volume": 3.0, "flash": 1.8 },
}
const SWITCH_TIME := 0.9      # ranger l'arme dans le dos, attraper l'autre, la ramener devant
const HOLSTER_Z := -0.3         # dos du Solaris dans le repère de l'os du torse
const POD_Z := -0.14
@export var range_m := 120.0
@export var lock_angle := 0.14          # rad : cône de l'aide à la visée
@export var melee_damage := 45.0
var melee_mult := 1.0            # jambières
@export var melee_cooldown := 1.1
@export var max_health := 100.0
@export var max_shield := 60.0
@export var shield_regen := 22.0        # par seconde
@export var shield_delay := 3.5         # s sans dégâts avant régénération

var weapon_index := 0
var ammo := 30
var mag_size := 30
var _ammo_by := [30, 10]
var switch_t := 0.0
var _switched := false
var reloading := 0.0
var fire_cd := 0.0
var aiming := false
var _trigger_was := false
var _fly_hint_t := 0.0
var melee_cd := 0.0
var melee_t := 0.0
var _melee_done := false
var health := 100.0
var shield := 60.0
var dead_t := 0.0
var hit_marker := 0.0
var _since_damage := 99.0
var lock_target: Node3D = null

## Kit du Ranger : LB = un emplacement de grenade, RB = un lanceur d'assaut.
## Amorce = marque la cible (brûlée, gelée) ; détonateur = la fait exploser (COMBO).
const ARSENAL := [
	{ "id": "frag", "slot": 0, "name": "Grenade à fragmentation", "role": "Détonateur", "desc": "Explose au contact, gros dégâts de zone", "cooldown": 8.0 },
	{ "id": "givre", "slot": 0, "name": "Grenade de givre", "role": "Amorce", "desc": "Gèle les ennemis pris dans le souffle (4 s)", "cooldown": 10.0 },
	{ "id": "brasier", "slot": 0, "name": "Grenade incendiaire", "role": "Amorce", "desc": "Flaque de feu qui brûle 5 s", "cooldown": 10.0 },
	{ "id": "missile", "slot": 1, "name": "Missile au poignet", "role": "Détonateur", "desc": "Missile à tête chercheuse tiré du poignet gauche", "cooldown": 6.0 },
	{ "id": "lance", "slot": 1, "name": "Rayon d'étincelles", "role": "Amorce", "desc": "Rayon perçant, les cibles touchées brûlent", "cooldown": 7.0 },
	{ "id": "impulsion", "slot": 1, "name": "Salve d'impulsion", "role": "Détonateur", "desc": "Boule d'énergie rapide qui éclate à l'impact", "cooldown": 5.0 },
]
const SLOT_NAMES := ["Grenade", "Lanceur d'assaut"]
const SLOT_KEYS := ["LB / E", "RB / R"]
const ULT := { "key": "LB+RB / F", "name": "Batterie de missiles",
	"desc": "Lanceurs d'épaules : verrouille jusqu'à 8 cibles, 3 salves à tête chercheuse (RT)" }
var equipped := [0, 3]         # index dans ARSENAL pour LB (grenade) et RB (lanceur)
const BEAM_DAMAGE := 35.0
const BURN_SECONDS := 7.0
const FREEZE_SECONDS := 4.0
const COMBO_DAMAGE := 70.0
# Ultime
const ULT_SECONDS := 12.0
const ULT_SALVOS := 3
const ULT_MAX_LOCKS := 8
const ULT_RANGE := 85.0
const ULT_CONE := 0.55
const ULT_MISSILE_DAMAGE := 34.0
var power_cd := [0.0, 0.0]
var ult_charge := 0.0          # 0..100, monte avec les dégâts infligés
var ult_t := 0.0               # batterie déployée (s restantes)
var ult_salvos := 0
var ult_locks: Array = []
var _salvo_cd := 0.0
var _lock_marks := {}
var _pods: Array = []          # deux lanceurs d'épaules
var _pod_open := 0.0
var combo_flash := 0.0
var combo_name := ""
var combo_color := Color(1.0, 0.6, 0.2)
var _chord_t := 0.0            # LB puis RB (ou l'inverse) dans la foulée = ultime
var _pending_power := -1
var _tracer_mat: StandardMaterial3D
var _casing_mesh: BoxMesh
var _casing_mat: StandardMaterial3D
var _ring_tex: GradientTexture2D
var guns: Array = []           # les deux armes (Node3D, poignée à l'origine)
var _gun_ids := ["", ""]       # exemplaire affiché dans chaque emplacement (id de l'arme + uid de l'objet)
var _gun_mats := [null, null]  # matériau de chaque arme (textures d'origine, lumières Énergie, liseré de rareté)
## Liseré de rareté des armes : intensité par rareté (Épique, Chef-d'œuvre, Légendaire), aucune en dessous.
const RARITY_RIM := { 3: 0.6, 4: 0.75, 5: 0.95 }
const WEAPON_SHADER := preload("res://shaders/weapon_meshy.gdshader")
const RIM_SHADER := preload("res://shaders/weapon_rim.gdshader")
var weapon: Node3D             # l'arme en main
var muzzle: Node3D
var _flash: OmniLight3D
var _energy := Color(1.0, 0.8, 0.45)

@onready var player: CharacterBody3D = get_parent()


func _ready() -> void:
	_tracer_mat = StandardMaterial3D.new()
	_tracer_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_tracer_mat.albedo_color = Color(1.0, 0.85, 0.45)
	_tracer_mat.emission_enabled = true
	_tracer_mat.emission = Color(1.0, 0.8, 0.4)
	_tracer_mat.emission_energy_multiplier = 3.0
	_tracer_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_casing_mesh = BoxMesh.new()
	_casing_mesh.size = Vector3(0.025, 0.025, 0.07)
	_casing_mat = StandardMaterial3D.new()
	_casing_mat.albedo_color = Color(0.85, 0.62, 0.25)
	_casing_mat.metallic = 0.9
	_casing_mat.roughness = 0.3
	_build_weapons()
	_build_pods()
	_select(0)
	health = max_health
	shield = max_shield


## Les armes Meshy de cyril, avec leurs textures d'origine. L'arme en main est calée sur la main droite,
## l'autre est accrochée en diagonale dans le dos (voir _process).
func _build_weapons() -> void:
	for i in WEAPONS.size():
		var g := Node3D.new()
		player.model.add_child(g)
		guns.append(g)
		_fill_gun(i)
	_flash = OmniLight3D.new()
	_flash.light_color = Color(1.0, 0.8, 0.45)
	_flash.light_energy = 0.0
	_flash.omni_range = 5.0
	player.model.add_child(_flash)
	var inv := get_node_or_null("/root/Inventory")
	if inv:
		inv.changed.connect(_refresh_guns)


## Modèle et bouche du canon de l'arme de l'emplacement i (celle de l'objet équipé).
func _fill_gun(i: int) -> void:
	var w := weapon_def(i)
	var g: Node3D = guns[i]
	for n in g.get_children():
		g.remove_child(n)
		n.queue_free()
	g.name = "Weapon_%d" % i
	_gun_ids[i] = _gun_key(i)
	var body := MeshInstance3D.new()
	body.mesh = load(w["mesh"])
	# le modèle Meshy est couché le long de X (canon vers -X) : canon vers -Z, poignée à l'origine
	body.transform = Transform3D(Basis(Vector3.UP, -PI / 2).scaled(Vector3.ONE * float(w["scale"])), w["offset"])
	_gun_mats[i] = weapon_material(w, int(_equipped(i).get("rarity", 0)), _energy)
	body.material_override = _gun_mats[i]
	g.add_child(body)
	var m := Node3D.new()
	m.name = "Muzzle"
	m.position = w["muzzle"]
	g.add_child(m)


## Matériau d'une arme : textures Meshy d'origine, lumières à la couleur Énergie, liseré de la rareté.
static func weapon_material(w: Dictionary, rarity: int, energy: Color) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = WEAPON_SHADER
	m.set_shader_parameter("albedo_tex", load(w["tex"] + "_albedo.png"))
	m.set_shader_parameter("normal_tex", load(w["tex"] + "_normal.png"))
	m.set_shader_parameter("rough_tex", load(w["tex"] + "_roughness.png"))
	m.set_shader_parameter("metal_tex", load(w["tex"] + "_metallic.png"))
	m.set_shader_parameter("lights", int(w.get("lights", 0)))
	m.set_shader_parameter("energy", energy)
	m.set_shader_parameter("rim_color", LootDB.rarity_color(rarity))
	m.set_shader_parameter("rim", float(RARITY_RIM.get(rarity, 0.0)))
	return m


## Liseré de rareté seul, posé par-dessus le matériau d'origine (modèle de la fiche d'objet). null sous Épique.
static func rarity_overlay(rarity: int) -> ShaderMaterial:
	if not RARITY_RIM.has(rarity):
		return null
	var m := ShaderMaterial.new()
	m.shader = RIM_SHADER
	m.set_shader_parameter("rim_color", LootDB.rarity_color(rarity))
	m.set_shader_parameter("rim", float(RARITY_RIM[rarity]))
	return m


## L'objet équipé dans l'emplacement i ({} sans inventaire).
func _equipped(i: int) -> Dictionary:
	var inv := get_node_or_null("/root/Inventory")
	return inv.equipped_item("weapon%d" % i) if inv else {}


func _gun_key(i: int) -> String:
	return "%s:%s" % [weapon_def(i)["id"], _equipped(i).get("uid", "")]


## L'objet équipé a changé (Forge, menu) : on remplace le modèle des armes concernées et leurs munitions.
func _refresh_guns() -> void:
	for i in guns.size():
		if _gun_key(i) == _gun_ids[i]:
			continue
		_fill_gun(i)      # autre arme, ou autre exemplaire de la même (liseré de rareté, chargeur)
		var full := int(weapon_def(i)["mag"])
		if i == weapon_index:
			muzzle = guns[i].get_node("Muzzle")
			mag_size = int(current()["mag"])
			ammo = mag_size
		else:
			_ammo_by[i] = full


## Données d'une arme par son id d'objet (avantgarde, vipers, tacticien…), {} si inconnue.
static func weapon_data(id: String) -> Dictionary:
	for w in WEAPONS:
		if w["id"] == id:
			return w
	return WEAPON_MODELS.get(id, {})


## L'arme de l'emplacement i (0 = Arme 1, 1 = Arme 2) : celle de l'objet équipé, sinon l'arme de base.
func weapon_def(i: int) -> Dictionary:
	var inv := get_node_or_null("/root/Inventory")
	if inv:
		var w := weapon_data(inv.equipped_item("weapon%d" % i).get("base", ""))
		if not w.is_empty():
			return w
	return WEAPONS[i]


## Lanceurs de la batterie de missiles : deux blocs sur les épaules, repliés tant que l'ultime dort.
func _build_pods() -> void:
	for side in [-1.0, 1.0]:
		var pod := Node3D.new()
		pod.name = "MissilePod"
		player.model.add_child(pod)
		var box := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.2, 0.17, 0.34)
		box.mesh = bm
		box.set_meta("zone", 1)
		pod.add_child(box)
		var rim := MeshInstance3D.new()
		var rm := BoxMesh.new()
		rm.size = Vector3(0.22, 0.04, 0.36)
		rim.mesh = rm
		rim.position.y = -0.085
		rim.set_meta("zone", 3)
		pod.add_child(rim)
		# 4 tubes en carré, ouverture vers l'avant
		for tx in [-0.055, 0.055]:
			for ty in [-0.045, 0.045]:
				var tube := MeshInstance3D.new()
				var cm := CylinderMesh.new()
				cm.top_radius = 0.042
				cm.bottom_radius = 0.042
				cm.height = 0.06
				tube.mesh = cm
				tube.rotation.x = PI / 2
				tube.position = Vector3(tx * 0.85, ty * 0.85, -0.17)
				var tm := StandardMaterial3D.new()
				tm.albedo_color = Color(0.05, 0.05, 0.05)
				tm.emission_enabled = true
				tm.emission = Color(1.0, 0.5, 0.15)
				tm.emission_energy_multiplier = 0.6
				tube.material_override = tm
				pod.add_child(tube)
		pod.set_meta("side", side)
		pod.visible = false
		_pods.append(pod)


## Les nœuds à repeindre avec le preset (armes et lanceurs).
func paint_nodes() -> Array:
	return guns + _pods


## L'arme en main, avec les stats de l'équipement (fil loot/progression : BuildStats). Sans BuildStats, l'arme de base.
func current() -> Dictionary:
	var bs := get_node_or_null("/root/BuildStats")
	if bs and bs.has_method("weapon"):
		return bs.weapon(weapon_index, weapon_def(weapon_index))
	return weapon_def(weapon_index)


func weapon_name() -> String:
	return current()["name"]


func _select(i: int) -> void:
	_ammo_by[weapon_index] = ammo
	weapon_index = i
	weapon = guns[i]
	muzzle = weapon.get_node("Muzzle")
	mag_size = int(current()["mag"])
	ammo = _ammo_by[i]
	weapon_changed.emit(i)


func is_dead() -> bool:
	return dead_t > 0.0


func _unhandled_input(event: InputEvent) -> void:
	if is_dead() or get_tree().paused:
		return
	if event.is_action_pressed("melee"):
		_melee_press()
	elif event.is_action_pressed("reload"):
		start_reload()
	elif event.is_action_pressed("switch_weapon"):
		switch_weapon()
	elif event.is_action_pressed("power1") or event.is_action_pressed("power2"):
		var other := "power2" if event.is_action_pressed("power1") else "power1"
		if Input.is_action_pressed(other) or _chord_t > 0.0:
			_chord_t = 0.0
			_pending_power = -1
			use_ultimate()
		else:
			_chord_t = 0.18
			_pending_power = 0 if event.is_action_pressed("power1") else 1
	elif event.is_action_pressed("ultimate"):
		use_ultimate()


## Tir permis au sol, en saut et en vol stationnaire ; jamais en vol (comme dans Anthem).
func can_shoot() -> bool:
	return player.state != player.State.FLY and not player.dead and player.roll_t <= 0.0


## Chaque image : l'arme en main suit la main droite, l'autre reste dans le dos, les lanceurs sur les épaules.
func _process(delta: float) -> void:
	if guns.is_empty() or player.look == null:
		return
	var hand: Node3D = player.look.hand_node("hand_R")
	var chest: Node3D = player.look.hand_node("chest")
	if hand == null or chest == null:
		return
	var cb: Basis = chest.global_basis.orthonormalized()
	var model_b: Basis = player.model.global_basis.orthonormalized()
	# Avec le squelette animé, c'est l'animation qui place les armes (tenue à deux mains, dos, changement)
	if player.anim:
		_place_pods(delta, chest, cb, model_b)
		return
	for i in guns.size():
		if i == weapon_index:
			continue
		guns[i].global_transform = holster_xf(i, chest.global_transform)
	var held: Node3D = weapon
	var low: Basis = model_b * Basis(Vector3.RIGHT, -0.5)
	var target: Basis = low
	if (aiming or Input.is_action_pressed("fire")) and can_shoot() and switch_t <= 0.0 \
			and not (player.in_cover and player.cover_peek < 0.3):
		target = Basis.looking_at(_aim_dir(), Vector3.UP)
	if switch_t > 0.0:
		target = model_b * Basis(Vector3.RIGHT, 0.9)       # on dégaine : l'arme sort par-dessus l'épaule
	var k := minf(1.0, delta * 14.0)
	held.global_basis = held.global_basis.orthonormalized().slerp(target.orthonormalized(), k)
	held.global_position = hand.global_position + held.global_basis * Vector3(0, -0.02, 0.02)
	_place_pods(delta, chest, cb, model_b)


## Arme rangée dans le dos (repère monde) : en diagonale, canon vers le haut. Chaque arme a sa place.
func holster_xf(i: int, chest: Transform3D) -> Transform3D:
	var cb: Basis = chest.basis.orthonormalized()
	# Le modèle regarde +Z dans le repère des os ; « dans le dos » = -Z des os, donc +Z du joueur.
	var b := cb * Basis(Vector3(0, 0, 1), 0.55) * Basis(Vector3.RIGHT, PI / 2)
	var off := Vector3(0.05, -0.12, HOLSTER_Z) if i == 0 else Vector3(-0.05, -0.1, HOLSTER_Z - 0.07)
	return Transform3D(b, chest.origin + cb * off)


func _place_pods(delta: float, chest: Node3D, cb: Basis, model_b: Basis) -> void:
	_flash.global_position = muzzle.global_position
	# Lanceurs d'épaules : sortent du dos pendant l'ultime
	_pod_open = move_toward(_pod_open, 1.0 if ult_t > 0.0 else 0.0, delta * 3.0)
	for pod in _pods:
		pod.visible = _pod_open > 0.01
		if not pod.visible:
			continue
		var side: float = pod.get_meta("side")
		var e := ease(_pod_open, -2.0)
		pod.global_basis = model_b.scaled(Vector3.ONE * maxf(0.05, e))
		# Les os regardent +Z, le joueur -Z : épaule gauche du Solaris = +X des os
		pod.global_position = chest.global_position + cb * Vector3(side * 0.2, 0.1 + 0.14 * e, POD_Z)
	_update_lock_marks()


func _physics_process(delta: float) -> void:
	fire_cd = maxf(0.0, fire_cd - delta)
	melee_cd = maxf(0.0, melee_cd - delta)
	combo_flash = maxf(0.0, combo_flash - delta)
	_fly_hint_t = maxf(0.0, _fly_hint_t - delta)
	_salvo_cd = maxf(0.0, _salvo_cd - delta)
	for i in 2:
		power_cd[i] = maxf(0.0, power_cd[i] - delta)
	if _chord_t > 0.0:
		_chord_t -= delta
		if _chord_t <= 0.0 and _pending_power >= 0 and not is_dead():
			use_power(_pending_power)
			_pending_power = -1
	hit_marker = maxf(0.0, hit_marker - delta)
	_flash.light_energy = maxf(0.0, _flash.light_energy - delta * 40.0)
	_since_damage += delta
	if dead_t > 0.0:
		dead_t -= delta
		if dead_t <= 0.0:
			_respawn()
		return
	if switch_t > 0.0:
		switch_t -= delta
		if not _switched and switch_t <= SWITCH_TIME * 0.5:
			_switched = true
			_select(1 - weapon_index)
	if reloading > 0.0:
		reloading -= delta
		if reloading <= 0.0:
			ammo = mag_size
			player.message.emit("Rechargé", 0.8)
	if shield < max_shield and _since_damage > shield_delay:
		shield = minf(max_shield, shield + shield_regen * delta)
	aiming = Input.is_action_pressed("aim") and not get_tree().paused
	# Viser en plein vol : le Solaris se cale en vol stationnaire pour pouvoir tirer
	if aiming and player.state == player.State.FLY:
		player.enter_hover()
	_update_lock()
	if melee_t > 0.0:
		melee_t -= delta
		if melee_t < 0.1 and not _melee_done:
			_melee_done = true
			_melee_hit()
	var trigger: bool = Input.is_action_pressed("fire") and not get_tree().paused
	if ult_t > 0.0:
		_ult_step(delta, trigger and not _trigger_was)
	elif trigger:
		if not can_shoot():
			if player.state == player.State.FLY and _fly_hint_t <= 0.0:
				_fly_hint_t = 2.5
				player.message.emit("Pas de tir en vol : vise (LT / clic droit) pour passer en stationnaire", 2.0)
		elif bool(current()["auto"]) or not _trigger_was:
			_try_fire()
	_trigger_was = trigger


# ---------------------------------------------------------------- visée
func _update_lock() -> void:
	lock_target = null
	var cam: Camera3D = player.camera
	var fwd := -cam.global_transform.basis.z
	var best := lock_angle if aiming else lock_angle * 0.5
	for t in get_tree().get_nodes_in_group("targets"):
		if not t.alive:
			continue
		var to: Vector3 = aim_center(t) - cam.global_position
		var d := to.length()
		if d > 70.0:
			continue
		var ang := fwd.angle_to(to)
		if ang < best:
			best = ang
			lock_target = t
	# Aide à la visée : la caméra glisse doucement vers la cible verrouillée quand on vise
	if aiming and lock_target and Input.get_vector("look_left", "look_right", "look_up", "look_down").length() < 0.1:
		var to: Vector3 = aim_center(lock_target) - cam.global_position
		var want_yaw := atan2(-to.x, -to.z)
		var want_pitch := clampf(-asin(clampf(to.normalized().y, -1.0, 1.0)), -0.5, 1.0)
		player.cam_yaw = lerp_angle(player.cam_yaw, want_yaw, 0.08)
		player.cam_pitch = lerpf(player.cam_pitch, want_pitch, 0.08)


func aim_center(t: Node3D) -> Vector3:
	if t is Enemy:
		return t.center()
	match t.kind:
		"drone": return t.global_position
		"turret": return t.global_position + Vector3(0, 1.1, 0)
		_: return t.global_position + Vector3(0, 1.3, 0)


func _aim_dir() -> Vector3:
	var cam: Camera3D = player.camera
	var dir := -cam.global_transform.basis.z
	if lock_target:
		dir = (aim_center(lock_target) - cam.global_position).normalized()
	return dir


# ---------------------------------------------------------------- armes
func start_reload() -> void:
	if reloading > 0.0 or ammo == mag_size or switch_t > 0.0:
		return
	reloading = float(current()["reload"])
	player.message.emit("Rechargement…", reloading)


## Y au sol (T ou molette au clavier) : on range l'arme dans le dos et on dégaine l'autre.
func switch_weapon() -> void:
	if switch_t > 0.0 or is_dead() or ult_t > 0.0 or melee_t > 0.0:
		return
	reloading = 0.0
	switch_t = SWITCH_TIME
	_switched = false
	fire_cd = maxf(fire_cd, SWITCH_TIME)
	if player.anim:
		player.anim.draw()
	player.message.emit(weapon_def(1 - weapon_index)["name"], 1.2)


func _try_fire() -> void:
	if fire_cd > 0.0 or reloading > 0.0 or switch_t > 0.0 or melee_t > 0.0:
		return
	if ammo <= 0:
		start_reload()
		return
	fire()


## Bonus de dégâts des capacités (grenades, lanceurs, combos, ultime), donné par l'équipement.
func damage_mult() -> float:
	var bs := get_node_or_null("/root/BuildStats")
	if bs and bs.has_method("ability_mult"):
		return float(bs.ability_mult())
	return 1.0


func _charge_ult(amount: float) -> void:
	if ult_t > 0.0:
		return
	var before := ult_charge
	ult_charge = minf(100.0, ult_charge + amount)
	if before < 100.0 and ult_charge >= 100.0:
		player.message.emit("Batterie de missiles prête ! (LB+RB ou F)", 2.0)


func fire() -> void:
	var w := current()
	ammo -= 1
	fire_cd = float(w["interval"])
	if player.anim:
		player.anim.recoil(1.0 if bool(w["auto"]) else 2.2)
	var cam: Camera3D = player.camera
	var from := cam.global_position
	var dir := -cam.global_transform.basis.z
	if lock_target and aiming:
		dir = (aim_center(lock_target) - from).normalized()
	var spread: float = w["spread_aim"] if aiming else w["spread_hip"]
	var axis := dir.cross(Vector3.UP).normalized()
	dir = dir.rotated(axis, randf_range(-spread, spread)).rotated(dir.cross(axis).normalized(), randf_range(-spread, spread))
	var to := from + dir * float(w.get("range", range_m))
	var q := PhysicsRayQueryParameters3D.create(from, to)
	q.exclude = [player.get_rid()]
	var r := player.get_world_3d().direct_space_state.intersect_ray(q)
	var end := to
	var twin := bool(w["twin"])
	var surface := ""
	var normal := -dir
	if not r.is_empty():
		end = r["position"]
		normal = r["normal"]
		var c: Node3D = r["collider"]
		surface = Fx.surface_of(c)
		if c.has_method("take_damage"):
			var dmg: float = float(w["damage"])
			c.take_damage(dmg, end, false)
			hit_marker = 0.12
			hit.emit(c, dmg, false)
			_charge_ult(3.0 * dmg / 11.0)
	# Les dégâts sont immédiats ; ce qu'on voit, c'est une balle qui file et l'impact à son arrivée
	var mz := muzzle.global_position
	var arrive := Callable()
	if surface != "":
		arrive = Fx.impact.bind(end, normal, surface, twin)
	if twin:
		# Twin Vipers : deux canons superposés, deux balles
		var up := weapon.global_basis.y * 0.035
		Fx.bullet(mz + up, end + up * 0.3, Color(1.0, 0.85, 0.6), 520.0, 0.045, arrive)
		Fx.bullet(mz - up, end - up * 0.3, Color(1.0, 0.85, 0.6), 520.0, 0.045)
		Fx.sound("sniper", mz, 0.0, 0.05, 14.0)
	else:
		var sniper: bool = w.get("sound", "rifle") == "sniper"
		Fx.bullet(mz, end, Color(1.0, 0.85, 0.6) if sniper else Color(1.0, 0.8, 0.5), 520.0 if sniper else 420.0, 0.03, arrive)
		Fx.sound(w.get("sound", "rifle"), mz, float(w.get("volume", 0.0 if sniper else -3.0)), 0.07, 12.0)
	var flash: float = float(w.get("flash", 1.4 if twin else 1.0))
	Fx.muzzle(mz, dir, _energy.lightened(0.3), 0.7 * flash)
	_flash.light_energy = 2.5 * flash + (0.5 if twin else 0.0)
	_eject_casing(float(w["casing"]))
	player.cam_pitch -= float(w["kick"])
	player.cam_yaw += randf_range(-0.3, 0.3) * float(w["kick"])
	Fx.shake(float(w["shake"]))
	# Chaque balle fait respirer l'image : petit coup de zoom, plus fort pour les fusils de précision
	Fx.kick(0.6 if bool(w["auto"]) else 1.5)
	# Recul : en vol stationnaire, le tir repousse un peu l'armure
	if player.state == player.State.HOVER and float(w["push"]) > 0.0:
		player.velocity -= Vector3(dir.x, 0.0, dir.z).normalized() * float(w["push"])
	if ammo <= 0:
		start_reload()


## Douille éjectée sur la droite de l'arme : petit arc doré, rebond, disparaît.
func _eject_casing(size: float) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = _casing_mesh
	mi.material_override = _casing_mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	player.get_parent().add_child(mi)
	var b := weapon.global_basis.orthonormalized()
	var p0 := weapon.global_position + b * Vector3(0.06, 0.08, -0.12)
	var v := b * Vector3(randf_range(2.2, 3.2), randf_range(1.8, 2.8), randf_range(0.2, 0.8)) + player.velocity * 0.8
	var spin := Vector3(randf_range(-20, 20), randf_range(-20, 20), randf_range(-20, 20))
	mi.global_position = p0
	mi.scale = Vector3.ONE * size
	var floor_y := player.global_position.y + 0.03 if player.is_on_floor() else -1000.0
	var tw := mi.create_tween()
	tw.tween_method(func(t: float):
		var p := p0 + v * t + Vector3(0, -11.0, 0) * t * t * 0.5
		p.y = maxf(p.y, floor_y)
		mi.global_position = p
		mi.rotation = spin * t, 0.0, 0.7, 0.7)
	tw.tween_callback(mi.queue_free)
	if floor_y > -1000.0 and randf() < 0.6:
		get_tree().create_timer(0.38).timeout.connect(func(): Fx.sound("casing", player.global_position, -16.0, 0.2, 4.0))


# ---------------------------------------------------------------- mêlée
func _melee_press() -> void:
	if melee_cd > 0.0 or melee_t > 0.0 or switch_t > 0.0:
		return
	melee_t = 0.3
	_melee_done = false
	melee_cd = melee_cooldown
	player.heat = minf(1.0, player.heat + 0.05)
	player.begin_melee()


## Masse à impulsion du Ranger : coup électrique, détone les cibles amorcées.
func _melee_hit() -> void:
	var fwd := Basis(Vector3.UP, player.model.rotation.y) * Vector3(0, 0, -1)
	var center := player.global_position + Vector3(0, 1.0, 0) + fwd * 1.4
	var any := false
	for t in get_tree().get_nodes_in_group("targets"):
		if not t.alive:
			continue
		if aim_center(t).distance_to(center) < 2.6:
			var dmg := melee_damage * melee_mult
			t.take_damage(dmg, aim_center(t), true)
			hit.emit(t, dmg, true)
			_charge_ult(10.0)
			Fx.sparks(aim_center(t), Vector3.UP, Color(0.6, 0.85, 1.0), 26, 10.0, 0.4, 0.1, 180.0, -6.0)
			Fx.sparks(aim_center(t), Vector3.UP, Color(1.0, 0.9, 0.6), 14, 9.0, 0.5, 0.14, 150.0, -10.0)
			Fx.ring(aim_center(t), 2.0, Color(0.6, 0.85, 1.0, 0.8), 0.25, fwd, 0.3)
			Fx.flash(aim_center(t), Color(0.6, 0.85, 1.0), 5.0, 6.0, 0.15)
			Fx.shake(0.3)
			Fx.hitstop(0.4, 0.07)
			if t.is_primed():
				_detonate(t)
			any = true
	if any:
		hit_marker = 0.15
		_flash.light_energy = 3.0
	Fx.sparks(player.global_position + Vector3(0, 0.2, 0), -fwd, Color(0.8, 0.7, 0.5), 14, 5.0, 0.5, 0.2, 60.0, -4.0)


# ---------------------------------------------------------------- pouvoirs
func power_in_slot(slot: int) -> Dictionary:
	return ARSENAL[equipped[slot]]


## Équipe une grenade ou un lanceur. Chaque pouvoir a sa place : grenade en LB, lanceur en RB.
func equip(_slot: int, arsenal_index: int) -> void:
	var slot: int = ARSENAL[arsenal_index]["slot"]
	equipped[slot] = arsenal_index
	power_cd[slot] = 2.0
	Loadout.powers = equipped.duplicate()
	player.message.emit("%s équipé en %s" % [ARSENAL[arsenal_index]["name"], "LB" if slot == 0 else "RB"], 1.2)


func use_power(slot: int) -> void:
	var p: Dictionary = power_in_slot(slot)
	if slot >= int(Loadout.stat("noyau", "power_slots")):
		player.message.emit("Noyau bridé : un seul pouvoir (LB). Il faut un meilleur noyau.", 1.4)
		return
	if is_dead() or switch_t > 0.0 or ult_t > 0.0:
		return
	if power_cd[slot] > 0.0:
		player.message.emit("%s : encore %.0f s" % [p["name"], ceil(power_cd[slot])], 0.8)
		return
	if player.state == player.State.FLY:
		player.enter_hover()               # pas de pouvoir en plein vol : on se cale en stationnaire
	power_cd[slot] = p["cooldown"] * float(Loadout.stat("noyau", "cooldown_mult"))
	power_used.emit(slot)
	if player.anim:
		if slot == 1:
			player.anim.cast()
		else:
			player.anim.throw()
	player.model.rotation.y = player.cam_yaw
	# Le coup part au bon moment du geste : la grenade quitte la main au sommet du lancer,
	# le missile part quand le bras est tendu (avant, tout partait dès l'appui).
	var f := Callable()
	var delay := 0.12
	match p["id"]:
		"frag", "givre", "brasier":
			f = _grenade.bind(p["id"])
			delay = 0.22
			_hold_grenade(delay, p["id"])
		"missile": f = _wrist_missile
		"lance": f = _core_lance
		"impulsion": f = _pulse
	if player.anim == null:
		f.call()
	else:
		get_tree().create_timer(delay, false).timeout.connect(func(): if not is_dead(): f.call())


## La grenade apparaît dans la main gauche pendant l'armé du lancer.
func _hold_grenade(seconds: float, kind := "") -> void:
	var h: Node3D = player.look.hand_node("hand_L") if player.look else null
	if h == null:
		return
	var g := grenade_visual(kind)
	h.add_child(g)
	g.position = Vector3(0, -0.12, 0.04)
	get_tree().create_timer(seconds, false).timeout.connect(g.queue_free)


## Le modèle de la grenade équipée (modèles Meshy de cyril dans assets/loot/, matériaux d'origine).
## Sans modèle, on retombe sur l'« Ember Core » repeinte par le preset.
func grenade_visual(kind: String) -> Node3D:
	var path := "res://assets/loot/%s.glb" % kind
	if kind != "" and ResourceLoader.exists(path):
		var n: Node3D = (load(path) as PackedScene).instantiate()
		n.scale = Vector3.ONE * 0.12
		return n
	var mi := MeshInstance3D.new()
	mi.mesh = load("res://assets/weapons/grenade.res")
	mi.scale = Vector3.ONE * 0.15
	var gm := SolarisLook.meshy_material({ "tex": "res://assets/weapons/grenade" })
	SolarisLook.meshy_params(gm, Appearance.current, Appearance.wear())
	gm.set_shader_parameter("glow", 3.0)
	mi.material_override = gm
	return mi


func _left_hand() -> Vector3:
	var h: Node3D = player.look.hand_node("hand_L") if player.look else null
	return h.global_position if h else player.global_position + Vector3(0, 1.3, 0)


## Grenade lancée en cloche de la main gauche (modèle « Ember Core » de cyril).
## Si une cible est verrouillée, on calcule la vitesse pour retomber dessus.
func _grenade(kind: String) -> void:
	var dir := _aim_dir()
	var ball: Area3D = load("res://scripts/turret_shot.gd").new()
	ball.damage = 0.0
	ball.arc_gravity = 18.0
	ball.grenade = true
	ball.visual = grenade_visual(kind)
	var from := _left_hand() + dir * 0.4
	var launch_dir := (dir + Vector3(0, 0.3, 0)).normalized()
	ball.speed = 18.0
	var aim_pt := Vector3.INF
	if lock_target:
		aim_pt = aim_center(lock_target)
	else:
		var q := PhysicsRayQueryParameters3D.create(player.camera.global_position, player.camera.global_position + dir * 40.0)
		q.exclude = [player.get_rid()]
		var r := player.get_world_3d().direct_space_state.intersect_ray(q)
		if not r.is_empty():
			aim_pt = r["position"]
	if aim_pt != Vector3.INF:
		var to: Vector3 = aim_pt - from
		var flat := Vector3(to.x, 0, to.z)
		var d := flat.length()
		if d > 1.0:
			var ang := 0.55
			# portée balistique avec dénivelé : v² = g d² / (2 cos² a (d tan a - h))
			var h := to.y
			var den := 2.0 * cos(ang) * cos(ang) * (d * tan(ang) - h)
			if den > 0.1:
				launch_dir = (flat.normalized() * cos(ang) + Vector3(0, sin(ang), 0)).normalized()
				ball.speed = clampf(sqrt(ball.arc_gravity * d * d / den), 6.0, 32.0)
	ball.life = 5.0
	ball.on_impact = func(pos: Vector3): _grenade_burst(kind, pos)
	Fx.sound("grenade_throw", from, -6.0, 0.1, 6.0)
	player.get_parent().add_child(ball)
	ball.launch(from, launch_dir, player.get_rid())
	Fx.kick(1.5)
	player.message.emit(ARSENAL[equipped[0]]["name"], 0.8)


func _grenade_burst(kind: String, pos: Vector3) -> void:
	match kind:
		"frag":
			Fx.explosion(pos, 5.5, Color(1.0, 0.55, 0.2), 1.4)
			Fx.debris(pos, Color(0.5, 0.45, 0.4), 10, 9.0)
			Fx.hitstop(0.3, 0.06)
			Fx.kick(5.0)
			area_damage(pos, 5.5, 60.0, true, null)
		"givre":
			var ice := Color(0.65, 0.9, 1.0)
			Fx.sphere(pos, 4.5, Color(ice.r, ice.g, ice.b, 0.5), 0.5)
			Fx.ring(pos, 5.5, Color(ice.r, ice.g, ice.b, 0.9), 0.5, Vector3.UP, 0.25)
			Fx.sparks(pos, Vector3.UP, Color(0.85, 0.95, 1.0), 60, 9.0, 0.9, 0.18, 180.0, -3.0)
			Fx.flash(pos, ice, 6.0, 12.0, 0.4)
			# Brume glacée qui roule au sol, éclats de glace
			Fx.shockwave(pos, 6.0, Color(0.8, 0.95, 1.0, 0.6))
			Fx.smoke(pos, 10, 2.0, 2.2, Color(0.85, 0.95, 1.0, 0.4), -0.1, 0.8, 6.0, Vector3.UP, 100.0)
			Fx.streaks(pos, Vector3.UP, Color(0.8, 0.95, 1.0), 30, 16.0, 0.7, 0.4, 180.0, -10.0, 0.05)
			Fx.chips(pos, Vector3.UP, Color(0.75, 0.9, 1.0), 14, 9.0, 0.12, 1.4, true)
			Fx.sound("blast_small", pos, 2.0, 0.05, 20.0)
			Fx.sound("ricochet", pos, -4.0, 0.3, 12.0)
			Fx.shake(0.3)
			for t in get_tree().get_nodes_in_group("targets"):
				if not t.alive or aim_center(t).distance_to(pos) > 5.0:
					continue
				t.take_damage(15.0 * damage_mult(), aim_center(t), false)
				t.freeze(FREEZE_SECONDS)
				t.slow(FREEZE_SECONDS + 2.0)
				hit.emit(t, 15.0, false)
				_charge_ult(6.0)
		"brasier":
			var z: Node3D = load("res://scripts/fire_zone.gd").new()
			z.combat = self
			player.get_parent().add_child(z)
			z.global_position = pos + Vector3(0, 0.05, 0)
			Fx.explosion(pos, 3.0, Color(1.0, 0.45, 0.1), 0.8)
			Fx.shake(0.3)


## Dégâts de zone (explosions) : décroissent avec la distance, détonent les cibles amorcées.
func area_damage(pos: Vector3, radius: float, dmg: float, detonator: bool, _src) -> void:
	var any := false
	for t in get_tree().get_nodes_in_group("targets"):
		if not t.alive:
			continue
		var d := aim_center(t).distance_to(pos)
		if d > radius:
			continue
		var amount := dmg * damage_mult() * lerpf(1.0, 0.5, d / radius)
		var primed: bool = t.is_primed()
		t.take_damage(amount, aim_center(t), false)
		hit.emit(t, amount, false)
		_charge_ult(amount * 0.15)
		any = true
		if detonator and primed:
			_detonate(t)
	if any:
		hit_marker = 0.18


## Missile au poignet : part du bras gauche, vire vers la cible verrouillée.
func _wrist_missile() -> void:
	var m := Missile.new()
	m.combat = self
	m.target = lock_target if lock_target else _nearest_in_view(0.35, 70.0)
	m.damage = 50.0
	m.radius = 3.0
	m.color = _energy
	m.size = 1.3
	player.get_parent().add_child(m)
	var dir := _aim_dir()
	m.launch(_left_hand() + dir * 0.3, (dir + Vector3(0, 0.25, 0)).normalized(), player.get_rid())
	Fx.muzzle(_left_hand(), dir, _energy, 0.8)
	Fx.kick(2.5)
	Fx.shake(0.12)
	player.message.emit("Missile au poignet", 0.8)


## Salve d'impulsion : boule d'énergie rapide, sans guidage, qui éclate (détonateur).
func _pulse() -> void:
	var m := Missile.new()
	m.combat = self
	m.turn_rate = 0.0
	m.speed = 48.0
	m.damage = 40.0
	m.radius = 3.5
	m.color = Color(0.55, 0.85, 1.0)
	m.size = 1.6
	m.smoky = false
	player.get_parent().add_child(m)
	var from := _left_hand()
	var dir := (_aim_point() - from).normalized()       # depuis la main : sinon le décalage caméra fait rater
	m.launch(from + dir * 0.4, dir, player.get_rid())
	m._body.visible = false
	Fx.muzzle(_left_hand(), dir, m.color, 1.0)
	Fx.sound("beam", from, -3.0, 0.1, 12.0)
	Fx.kick(3.0)
	player.message.emit("Salve d'impulsion", 0.8)


## Point visé : la cible verrouillée, sinon ce que touche le centre de l'écran.
func _aim_point() -> Vector3:
	if lock_target:
		return aim_center(lock_target)
	var cam: Camera3D = player.camera
	var from := cam.global_position
	var to := from - cam.global_transform.basis.z * range_m
	var q := PhysicsRayQueryParameters3D.create(from, to)
	q.exclude = [player.get_rid()]
	var r := player.get_world_3d().direct_space_state.intersect_ray(q)
	return to if r.is_empty() else r["position"]


func _nearest_in_view(cone: float, dist: float) -> Node3D:
	var cam: Camera3D = player.camera
	var fwd := -cam.global_transform.basis.z
	var best: Node3D = null
	var best_ang := cone
	for t in get_tree().get_nodes_in_group("targets"):
		if not t.alive:
			continue
		var to: Vector3 = aim_center(t) - cam.global_position
		if to.length() > dist:
			continue
		var a := fwd.angle_to(to)
		if a < best_ang:
			best_ang = a
			best = t
	return best


## Rayon d'étincelles : rayon doré qui traverse tout sur son passage, amorce « brûlure ».
func _core_lance() -> void:
	var cam: Camera3D = player.camera
	var from := cam.global_position
	var dir := _aim_dir()
	var space := player.get_world_3d().direct_space_state
	var exclude: Array[RID] = [player.get_rid()]
	var end := from + dir * range_m
	var hits := 0
	var start := from
	while hits < 6:
		var q := PhysicsRayQueryParameters3D.create(start, from + dir * range_m)
		q.exclude = exclude
		var r := space.intersect_ray(q)
		if r.is_empty():
			break
		var c: Node3D = r["collider"]
		if c.has_method("take_damage"):
			c.take_damage(BEAM_DAMAGE * damage_mult(), r["position"], false)
			c.prime(BURN_SECONDS)
			Fx.sparks(r["position"], -dir, Color(1.0, 0.55, 0.15), 24, 10.0, 0.6, 0.16, 90.0, -8.0)
			Fx.sphere(r["position"], 1.2, Color(1.0, 0.7, 0.3, 0.8), 0.25)
			hit.emit(c, BEAM_DAMAGE, false)
			_charge_ult(12.0)
			exclude.append(c.get_rid())
			start = r["position"] + dir * 0.1
			hits += 1
		else:
			end = r["position"]
			Fx.impact(end, r["normal"], Fx.surface_of(r["collider"]), true)
			Fx.mark(end, r["normal"], "scorch", 1.2, Color(1, 1, 1, 0.8), 15.0)
			break
	var origin := _left_hand()
	_beam(origin, end)
	Fx.sound("beam", origin, 0.0, 0.08, 14.0)
	Fx.ring(origin + dir * 0.6, 1.6, Color(1.0, 0.85, 0.45, 0.8), 0.3, dir, 0.3)
	Fx.sparks(origin, dir, Color(1.0, 0.9, 0.6), 20, 14.0, 0.4, 0.14, 15.0, -3.0)
	Fx.flash(origin, Color(1.0, 0.85, 0.45), 6.0, 10.0, 0.3)
	Fx.kick(5.0)
	Fx.shake(0.3)
	hit_marker = 0.2 if hits > 0 else 0.0
	player.message.emit("Rayon d'étincelles", 0.8)


func _beam(a: Vector3, b: Vector3) -> void:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.12
	cm.bottom_radius = 0.12
	cm.height = 1.0
	cm.radial_segments = 8
	mi.mesh = cm
	var m: StandardMaterial3D = _tracer_mat.duplicate()
	m.albedo_color = Color(1.0, 0.97, 0.85, 1.0)
	m.emission_energy_multiplier = 6.0
	mi.material_override = m
	# Halo additif autour du cœur
	var halo := MeshInstance3D.new()
	var hm := CylinderMesh.new()
	hm.top_radius = 0.45
	hm.bottom_radius = 0.45
	hm.height = 1.0
	hm.radial_segments = 12
	halo.mesh = hm
	var hmat := StandardMaterial3D.new()
	hmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	hmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	hmat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	hmat.albedo_color = Color(1.0, 0.7, 0.3, 0.45)
	halo.material_override = hmat
	mi.add_child(halo)
	player.get_parent().add_child(mi)
	mi.global_position = (a + b) * 0.5
	mi.look_at(b, Vector3.UP if absf((b - a).normalized().y) < 0.99 else Vector3.RIGHT)
	mi.rotate_object_local(Vector3.RIGHT, PI / 2.0)
	mi.scale = Vector3(1.6, a.distance_to(b), 1.6)
	var tw := mi.create_tween()
	tw.set_parallel(true)
	tw.tween_property(mi, "scale:x", 0.05, 0.45).set_ease(Tween.EASE_IN)
	tw.tween_property(mi, "scale:z", 0.05, 0.45).set_ease(Tween.EASE_IN)
	tw.tween_property(halo, "material_override:albedo_color:a", 0.0, 0.3)
	tw.chain().tween_callback(mi.queue_free)


## Combo : une cible amorcée (brûlée, gelée) touchée par un détonateur explose.
func _detonate(t: Node3D) -> void:
	var c: Vector3 = aim_center(t)
	# Le combo dépend de l'amorce, comme dans Anthem : la glace éclate, le feu s'embrase, le choc foudroie
	var kind := "choc"
	if float(t.get("frozen") if t.get("frozen") != null else 0.0) > 0.0:
		kind = "glace"
	elif t.burning > 0.0:
		kind = "feu"
	if t.has_method("clear_status"):
		t.clear_status()
	else:
		t.burning = 0.0
		t.stunned = 0.0
	var radius := 4.0
	var dmg := COMBO_DAMAGE * damage_mult()
	match kind:
		"glace":
			combo_name = "ÉCLAT DE GLACE"
			combo_color = Color(0.62, 0.88, 1.0)
			radius = 5.0
			Fx.sphere(c, 2.2, Color(0.8, 0.95, 1.0, 0.7), 0.25)
			Fx.shockwave(c, 7.0, Color(0.8, 0.95, 1.0, 0.7))
			Fx.ring(c, 6.0, Color(0.7, 0.92, 1.0, 0.9), 0.4, Vector3.UP, 0.3)
			Fx.chips(c, Vector3.UP, Color(0.75, 0.92, 1.0), 40, 14.0, 0.14, 1.6, true)
			Fx.streaks(c, Vector3.UP, Color(0.9, 0.97, 1.0), 50, 22.0, 0.5, 0.6, 180.0, -12.0, 0.05)
			Fx.sparks(c, Vector3.UP, Color(0.85, 0.95, 1.0), 60, 12.0, 0.8, 0.16, 180.0, -6.0)
			Fx.smoke(c, 10, 2.4, 2.0, Color(0.85, 0.95, 1.0, 0.45), -0.1, 1.0, 5.0, Vector3.UP, 120.0)
			Fx.flash(c, combo_color, 10.0, 14.0, 0.4)
			Fx.sound("ricochet", c, 2.0, 0.2, 16.0)
			Fx.sound("blast_small", c, 4.0, 0.05, 20.0)
		"feu":
			combo_name = "EMBRASEMENT"
			combo_color = Color(1.0, 0.55, 0.15)
			radius = 5.5
			Fx.explosion(c, 5.5, Color(1.0, 0.5, 0.12), 1.8)
			Fx.fireball(c, 3.0, 16, 1.1)
			Fx.ring(c, 6.5, Color(1.0, 0.6, 0.2, 0.9), 0.45, Vector3.UP, 0.35)
			Fx.streaks(c, Vector3.UP, Color(1.0, 0.7, 0.3), 40, 18.0, 0.6, 0.5, 180.0, -10.0, 0.05)
		_:
			combo_name = "FOUDROIEMENT"
			combo_color = Color(0.75, 0.85, 1.0)
			Fx.explosion(c, 4.5, Color(0.6, 0.75, 1.0), 1.4)
			Fx.streaks(c, Vector3.UP, Color(0.85, 0.92, 1.0), 40, 20.0, 0.3, 0.7, 180.0, 0.0, 0.035)
	Fx.hitstop(0.25, 0.14)
	Fx.kick(6.0)
	Fx.shake(0.5)
	for o in get_tree().get_nodes_in_group("targets"):
		if not o.alive or aim_center(o).distance_to(c) > radius:
			continue
		o.take_damage(dmg if o == t else dmg * 0.5, aim_center(o), true)
		if o != t and o.alive:
			match kind:
				"glace":
					o.slow(3.0)          # le froid se propage : les voisins ralentissent
				"feu":
					o.prime(3.0)         # le feu se propage : les voisins brûlent (réamorcés)
	combo_flash = 1.2
	_charge_ult(15.0)
	combo.emit(t)
	player.message.emit("COMBO : " + combo_name, 1.4)


# ---------------------------------------------------------------- ultime
## Batterie de missiles : les lanceurs sortent des épaules, verrouillent les cibles en vue,
## RT tire une salve (deux missiles par cible). Trois salves, ou 12 s.
func use_ultimate() -> void:
	if is_dead() or ult_t > 0.0 or switch_t > 0.0:
		return
	if not Loadout.stat("noyau", "ultimate"):
		player.message.emit("Ultime verrouillé : le noyau n'est pas d'origine.", 1.4)
		return
	if ult_charge < 100.0:
		player.message.emit("Batterie de missiles : %d %%" % int(ult_charge), 0.8)
		return
	if player.state == player.State.FLY:
		player.enter_hover()
	ult_charge = 0.0
	ult_t = ULT_SECONDS
	ult_salvos = ULT_SALVOS
	_salvo_cd = 0.5
	reloading = 0.0
	if player.anim:
		player.anim.cast()
	var c := player.global_position + Vector3(0, 1.6, 0)
	Fx.ring(player.global_position + Vector3(0, 0.15, 0), 5.0, Color(_energy.r, _energy.g, _energy.b, 0.9), 0.5, Vector3.UP, 0.15)
	Fx.sparks(c, Vector3.UP, _energy, 40, 7.0, 0.6, 0.15, 120.0, -4.0)
	Fx.flash(c, _energy, 4.0, 8.0, 0.4)
	Fx.kick(5.0)
	Fx.shake(0.3)
	ultimate_started.emit()
	player.message.emit("BATTERIE DE MISSILES : verrouille et tire (RT)", 2.0)


func _ult_step(delta: float, pressed: bool) -> void:
	ult_t -= delta
	# Verrouillage : toutes les cibles dans le cône de la caméra, les plus proches d'abord
	var cam: Camera3D = player.camera
	var fwd := -cam.global_transform.basis.z
	var found := []
	for t in get_tree().get_nodes_in_group("targets"):
		if not t.alive:
			continue
		var to: Vector3 = aim_center(t) - cam.global_position
		if to.length() > ULT_RANGE or fwd.angle_to(to) > ULT_CONE:
			continue
		found.append([to.length(), t])
	found.sort_custom(func(a, b): return a[0] < b[0])
	ult_locks.clear()
	for f in found.slice(0, ULT_MAX_LOCKS):
		ult_locks.append(f[1])
	if pressed and _salvo_cd <= 0.0 and _pod_open > 0.9 and ult_salvos > 0:
		_salvo()
	if ult_t <= 0.0 or (ult_salvos <= 0 and _salvo_cd <= 0.0):
		_end_ult()


func _salvo() -> void:
	ult_salvos -= 1
	_salvo_cd = 0.7
	var targets: Array = ult_locks.duplicate()
	var shots := []
	if targets.is_empty():
		for i in 6:
			shots.append(null)
	else:
		for t in targets:
			shots.append(t)
			shots.append(t)
	var fwd: Vector3 = -player.camera.global_transform.basis.z
	for i in shots.size():
		var pod: Node3D = _pods[i % 2]
		var delay := 0.04 * i
		get_tree().create_timer(delay, false).timeout.connect(func():
			if not is_instance_valid(pod):
				return
			var m := Missile.new()
			m.combat = self
			m.target = shots[i]
			m.damage = ULT_MISSILE_DAMAGE
			m.radius = 2.6
			m.color = _energy
			m.speed = 26.0
			m.turn_rate = 6.5
			m.arm_time = 0.22
			m.shake = 0.12
			m.size = 1.0
			player.get_parent().add_child(m)
			var side: float = pod.get_meta("side")
			var up := Vector3(0, 1.0, 0)
			var spread: Vector3 = Basis(Vector3.UP, side * randf_range(0.1, 0.5)) * fwd
			var d: Vector3 = (spread * 0.6 + up * randf_range(0.7, 1.1)).normalized()
			m.launch(pod.global_position + pod.global_basis.orthonormalized() * Vector3(0, 0, -0.25), d, player.get_rid())
			Fx.muzzle(pod.global_position, d, _energy, 0.5))
	Fx.kick(4.0)
	Fx.shake(0.25)
	player.message.emit("Salve ! (%d restante%s)" % [ult_salvos, "s" if ult_salvos > 1 else ""], 1.0)


func _end_ult() -> void:
	ult_t = 0.0
	ult_salvos = 0
	ult_locks.clear()
	player.message.emit("Batterie de missiles repliée", 1.2)


## Marqueurs de verrouillage : un anneau orange qui tourne autour de chaque cible.
func _update_lock_marks() -> void:
	for t in _lock_marks.keys():
		if not is_instance_valid(t) or not t in ult_locks:
			var mk: Node3D = _lock_marks[t]
			if is_instance_valid(mk):
				mk.queue_free()
			_lock_marks.erase(t)
	for t in ult_locks:
		if not _lock_marks.has(t):
			_lock_marks[t] = _make_mark()
		var mk: MeshInstance3D = _lock_marks[t]
		mk.global_position = aim_center(t)
		var pulse := 1.0 + 0.15 * sin(Time.get_ticks_msec() * 0.012)
		var d: float = player.camera.global_position.distance_to(mk.global_position)
		mk.scale = Vector3.ONE * pulse * clampf(d * 0.06, 0.8, 3.5)


func _make_mark() -> MeshInstance3D:
	if _ring_tex == null:
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.62, 0.72, 0.86, 0.95])
		g.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
		_ring_tex = GradientTexture2D.new()
		_ring_tex.gradient = g
		_ring_tex.fill = GradientTexture2D.FILL_RADIAL
		_ring_tex.fill_from = Vector2(0.5, 0.5)
		_ring_tex.fill_to = Vector2(0.5, 0.0)
		_ring_tex.width = 64
		_ring_tex.height = 64
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.9, 0.9)
	mi.mesh = q
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.no_depth_test = true
	m.albedo_color = Color(1.0, 0.45, 0.1, 0.95)
	m.albedo_texture = _ring_tex
	m.render_priority = 10
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	player.get_parent().add_child(mi)
	return mi


# ---------------------------------------------------------------- vie
## from_dir : direction du projectile (vide pour un coup au corps à corps).
func take_damage(amount: float, from_dir := Vector3.ZERO) -> void:
	if is_dead():
		return
	if player.dash_t > 0.0 or player.roll_t > 0.0:
		player.message.emit("Esquivé !", 0.6)
		return
	if player.in_cover and from_dir != Vector3.ZERO and from_dir.dot(player.cover_normal) > 0.2:
		if player.cover_peek < 0.5:
			# Caché : l'obstacle prend tout
			Fx.sparks(player.global_position + Vector3(0, 0.9, 0) - player.cover_normal * 0.5, player.cover_normal, Color(1.0, 0.7, 0.4), 8, 5.0, 0.3, 0.08, 70.0)
			return
		amount *= 0.5                    # sorti pour tirer : à moitié protégé
	_since_damage = 0.0
	var left := amount
	if shield > 0.0:
		var absorbed := minf(shield, left)
		shield -= absorbed
		left -= absorbed
		if shield <= 0.0:
			player.message.emit("Bouclier à plat !", 1.2)
	health = maxf(0.0, health - left)
	damaged.emit(amount)
	Fx.shake(0.25)
	Fx.sparks(player.global_position + Vector3(0, 1.1, 0), Vector3.UP, Color(0.5, 0.8, 1.0), 14, 6.0, 0.4, 0.12, 180.0, -4.0)
	if health <= 0.0:
		_die()


func _die() -> void:
	dead_t = 2.8
	reloading = 0.0
	melee_t = 0.0
	switch_t = 0.0
	aiming = false
	if ult_t > 0.0:
		_end_ult()
	player.message.emit("Armure hors service… réactivation", 2.8)
	died.emit()
	player.begin_death()


func _respawn() -> void:
	health = max_health
	shield = max_shield
	_ammo_by = [int(weapon_def(0)["mag"]), int(weapon_def(1)["mag"])]
	ammo = mag_size
	_since_damage = 99.0
	player.end_death()
	respawned.emit()
	player.message.emit("Armure réactivée", 1.5)


## Pièces montées : carapace (bouclier, vie, régénération).
func apply_loadout() -> void:
	var c: Dictionary = Loadout.part("carapace")
	var shield_frac := shield / max_shield if max_shield > 0.0 else 1.0
	var hp_frac := health / max_health if max_health > 0.0 else 1.0
	max_shield = c["max_shield"]
	max_health = c["max_health"]
	shield_regen = c["shield_regen"]
	shield = max_shield * shield_frac
	health = max_health * hp_frac
	melee_mult = float(Loadout.stat("jambes", "melee_mult"))
	equipped = sanitize_powers(Loadout.powers)


## Anciennes sauvegardes (avant le kit du Ranger) : chaque emplacement reprend un pouvoir de sa catégorie.
static func sanitize_powers(p: Array) -> Array:
	var out := [0, 3]
	for slot in 2:
		if slot < p.size():
			var i := int(p[slot])
			if i >= 0 and i < ARSENAL.size() and int(ARSENAL[i]["slot"]) == slot:
				out[slot] = i
	return out


## Couleur d'énergie du preset (zone 6) : traçantes, lueur du tir, missiles.
func apply_energy_color(c: Color) -> void:
	_energy = c
	if _tracer_mat:
		_tracer_mat.albedo_color = c.lightened(0.25)
		_tracer_mat.emission = c
	if _flash:
		_flash.light_color = c
	for m in _gun_mats:
		if m:
			m.set_shader_parameter("energy", c)
