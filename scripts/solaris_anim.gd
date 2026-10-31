class_name SolarisAnim
extends Node
## Animation procédurale du Solaris riggé (assets/solaris/solaris_rig.glb, 17 os).
## Pas de fichiers d'animation : chaque état du joueur définit une pose cible (angles d'Euler par os),
## on glisse vers elle, et on ajoute les cycles (marche, course, respiration, flottement).
## Repère des os = repère du modèle GLB : avant = +Z, gauche = +X. Une rotation X négative
## envoie un membre vers l'avant ; une rotation Z positive écarte le bras gauche, négative le droit.

var skeleton: Skeleton3D
var player: CharacterBody3D
var _idx := {}
var _cur := {}                 # os -> Vector3 (Euler courant)
var _t := 0.0
var _cycle := 0.0              # phase du cycle de marche
var _punch_t := 0.0
var _cast_t := 0.0
var _recoil := 0.0
var _draw_t := 0.0             # changement d'arme : la main droite va chercher l'arme dans le dos
var _throw_t := 0.0            # lancer de grenade de la main gauche
var _land_t := 0.0
var _land_heavy := false
var _step_sign := 1.0
# Animations du preset (arrivée, victoire, emotes) : jouées par play(), coupées si on bouge.
var act := ""
var _act_t := 0.0
var _act_len := 0.0
var _hips_rest := Vector3.ZERO
var _hips_y := 0.0
var _hips_x := 0.0
var preview := false               # Forge : pas d'interruption par le mouvement

var BONES := ["hips", "spine", "chest", "neck", "head", "shoulder_L", "shoulder_R",
	"upper_arm_L", "forearm_L", "hand_L", "upper_arm_R", "forearm_R", "hand_R",
	"thigh_L", "shin_L", "foot_L", "thigh_R", "shin_R", "foot_R"]


func setup(sk: Skeleton3D, p: CharacterBody3D) -> void:
	skeleton = sk
	player = p
	# Les épaules n'existent que sur le corps Aegis (tools/shoulders_aegis.py) : on ignore les os absents
	BONES = BONES.filter(func(b): return sk.find_bone(b) >= 0)
	for b in BONES:
		_idx[b] = sk.find_bone(b)
		_cur[b] = Vector3.ZERO
	_hips_rest = sk.get_bone_rest(_idx["hips"]).origin


const LENGTHS := { "drop": 2.4, "scan": 2.8, "ignite": 2.6, "salute": 2.4, "fist": 2.4, "crossed": 2.8,
	"kneel": 3.0, "wave": 2.2, "point": 2.0, "stretch": 2.6 }

## Joue une animation d'arrivée, de victoire ou une emote (ids de Catalog).
func play(id: String) -> void:
	act = id
	_act_t = 0.0
	_act_len = LENGTHS.get(id, 2.4)
	if id == "drop" and player.is_inside_tree():
		Fx.ring(player.global_position + Vector3(0, 0.1, 0), 3.0, Color(0.8, 0.75, 0.65), 0.5, Vector3.UP, 0.2)
		Fx.debris(player.global_position + Vector3(0, 0.2, 0), Color(0.5, 0.45, 0.4), 10, 6.0)
		Fx.shake(0.4)
	elif id == "ignite" and player.is_inside_tree() and player.look:
		var c: Color = Appearance.color(5)
		Fx.flash(player.global_position + Vector3(0, 1.3, -0.3), c, 6.0, 6.0, 0.6)
		Fx.sparks(player.global_position + Vector3(0, 1.3, -0.3), Vector3.UP, c, 30)


func stop() -> void:
	act = ""


## Déclenché par le joueur / le combat
func punch() -> void:
	_punch_t = 0.42


func cast() -> void:
	_cast_t = 0.6


## strength : 1 fusil d'assaut, ~2 fusil de précision (le recul relève les bras et le buste).
func recoil(strength := 1.0) -> void:
	_recoil = maxf(_recoil, strength)


const DRAW_TIME := 0.55
func draw() -> void:
	_draw_t = DRAW_TIME


const THROW_TIME := 0.5
func throw() -> void:
	_throw_t = THROW_TIME


## strength : 0.5 réception normale, 1.0 réception de super-héros (genou et poing au sol).
func land(strength := 0.5) -> void:
	_land_t = 0.5
	_land_heavy = strength >= 1.0


func _mirror(p: Dictionary, bone: String, v: Vector3) -> void:
	p[bone + "_L"] = v
	p[bone + "_R"] = Vector3(v.x, -v.y, -v.z)


## À chaque image (et non à chaque pas de physique) : les membres bougent aussi souplement que l'écran.
func _process(delta: float) -> void:
	if skeleton == null or player == null:
		return
	_t += delta
	_punch_t = maxf(0.0, _punch_t - delta)
	_cast_t = maxf(0.0, _cast_t - delta)
	_land_t = maxf(0.0, _land_t - delta)
	_recoil = maxf(0.0, _recoil - delta * 9.0)
	_draw_t = maxf(0.0, _draw_t - delta)
	_throw_t = maxf(0.0, _throw_t - delta)
	var target := _target_pose(delta)
	if act != "":
		_act_t += delta
		var moving: bool = Vector3(player.velocity.x, 0, player.velocity.z).length() > 1.5 or player.state != player.State.GROUND
		if _act_t >= _act_len or (moving and not preview) or player.dead:
			act = ""
		else:
			target = _act_pose(act, _act_t / _act_len, _act_t)
	var rate: float = target.get("_rate", 10.0)
	for b in BONES:
		var want: Vector3 = target.get(b, Vector3.ZERO)
		_cur[b] = _cur[b].lerp(want, minf(1.0, delta * rate))
		skeleton.set_bone_pose_rotation(_idx[b], Quaternion.from_euler(_cur[b]))
	_hips_y = lerpf(_hips_y, float(target.get("_hips", 0.0)), minf(1.0, delta * rate))
	_hips_x = lerpf(_hips_x, float(target.get("_hips_x", 0.0)), minf(1.0, delta * rate))
	skeleton.set_bone_pose_position(_idx["hips"], _hips_rest + Vector3(_hips_x, _hips_y, 0))
	_hold_weapon(delta)


func _target_pose(delta: float) -> Dictionary:
	var p := {}
	var S = player.State
	var st: int = player.state
	var hvel := Vector3(player.velocity.x, 0, player.velocity.z)
	var hspeed := hvel.length()
	var on_floor: bool = player.is_on_floor()
	var combat = player.combat
	var aiming: bool = combat != null and combat.aiming
	var breathe := sin(_t * 1.6)
	p["_rate"] = 10.0

	if player.dead:
		# Effondré : tout relâché, tête tombée
		p["_rate"] = 4.0
		p["spine"] = Vector3(0.35, 0, 0)
		p["head"] = Vector3(0.5, 0, 0)
		_mirror(p, "upper_arm", Vector3(-0.2, 0, 0.3))
		_mirror(p, "thigh", Vector3(-0.5, 0, 0.1))
		_mirror(p, "shin", Vector3(0.6, 0, 0))
		return p

	if _punch_t > 0.0:
		# Coup de poing droit : armé puis lancé
		var k := 1.0 - _punch_t / 0.42
		var swing := sin(k * PI)
		p["_rate"] = 22.0
		p["spine"] = Vector3(-0.15 * swing, -0.5 * swing, 0)
		p["chest"] = Vector3(0, -0.3 * swing, 0)
		p["upper_arm_R"] = Vector3(-1.7 * swing, 0, -0.2)
		p["forearm_R"] = Vector3(-0.2 - 0.9 * (1.0 - swing), 0, 0)
		p["upper_arm_L"] = Vector3(0.5 * swing, 0, 0.4)
		p["forearm_L"] = Vector3(-1.1, 0, 0)
		p["thigh_L"] = Vector3(-0.45 * swing, 0, 0)
		p["thigh_R"] = Vector3(0.35 * swing, 0, 0)
		p["shin_R"] = Vector3(0.5 * swing, 0, 0)
		return p

	match st:
		S.FLY:
			# Vol : jambes tendues en arrière, bras plaqués le long du corps, tête relevée
			var wob := sin(_t * 2.2) * 0.04
			p["spine"] = Vector3(-0.1, 0, wob)
			p["head"] = Vector3(-0.35, 0, 0)
			_mirror(p, "upper_arm", Vector3(0.75 + wob, 0, 0.12))
			_mirror(p, "forearm", Vector3(0.25, 0, 0))
			_mirror(p, "hand", Vector3(0.2, 0, 0))
			_mirror(p, "thigh", Vector3(0.22, 0, -0.04 + wob))
			_mirror(p, "shin", Vector3(0.12, 0, 0))
			_mirror(p, "foot", Vector3(0.4, 0, 0))
			if player.boost_t > 0.0:
				# Boost : bras collés en arrière, tête dans l'axe
				_mirror(p, "upper_arm", Vector3(1.1, 0, 0.05))
				_mirror(p, "forearm", Vector3(0.1, 0, 0))
				p["head"] = Vector3(-0.5, 0, 0)
			if player.roll_t > 0.0:
				# Vrille : on se ramasse
				_mirror(p, "upper_arm", Vector3(0.6, 0, 0.0))
				_mirror(p, "forearm", Vector3(-1.2, 0, 0))
				_mirror(p, "thigh", Vector3(-0.2, 0, 0))
				_mirror(p, "shin", Vector3(0.5, 0, 0))
				p["_rate"] = 14.0
			else:
				p["_rate"] = 6.0
			if player.takeoff_t > 0.0:
				# Décollage : corps droit, bras tendus vers le bas et en arrière, poings serrés, jambes jointes
				p["spine"] = Vector3(0.05, 0, 0)
				p["head"] = Vector3(-0.3, 0, 0)
				_mirror(p, "upper_arm", Vector3(0.35, 0, 0.32))
				_mirror(p, "forearm", Vector3(-0.1, 0, 0))
				_mirror(p, "hand", Vector3(0.3, 0, 0))
				_mirror(p, "thigh", Vector3(0.05, 0, -0.02))
				_mirror(p, "shin", Vector3(0.15, 0, 0))
				_mirror(p, "foot", Vector3(0.5, 0, 0))
				p["_rate"] = 12.0
		S.HOVER:
			# Stationnaire : posture de combat suspendue, une jambe repliée, bras prêts, léger flottement
			var fl := sin(_t * 2.5)
			p["spine"] = Vector3(-0.08 + fl * 0.03, 0, 0)
			p["head"] = Vector3(-0.05, 0, 0)
			_mirror(p, "upper_arm", Vector3(-0.25 + fl * 0.05, 0, 0.45))
			_mirror(p, "forearm", Vector3(-0.7, 0, 0))
			p["thigh_L"] = Vector3(-0.55 + fl * 0.05, 0, 0.1)
			p["shin_L"] = Vector3(1.1, 0, 0)
			p["thigh_R"] = Vector3(-0.1 - fl * 0.04, 0, -0.08)
			p["shin_R"] = Vector3(0.35, 0, 0)
			_mirror(p, "foot", Vector3(0.45, 0, 0))
			if player.roll_t > 0.0:
				_mirror(p, "thigh", Vector3(-0.8, 0, 0.1))
				_mirror(p, "shin", Vector3(1.4, 0, 0))
				_mirror(p, "upper_arm", Vector3(-0.3, 0, 0.1))
				_mirror(p, "forearm", Vector3(-1.4, 0, 0))
			p["_rate"] = 7.0
		S.AIR, S.FALL:
			var vy: float = player.velocity.y
			if player.takeoff_t > 0.0 or vy > 2.0:
				# Saut / décollage : genoux remontés, bras levés
				_mirror(p, "upper_arm", Vector3(-0.6, 0, 0.9))
				_mirror(p, "forearm", Vector3(-0.6, 0, 0))
				_mirror(p, "thigh", Vector3(-0.55, 0, 0.08))
				_mirror(p, "shin", Vector3(1.0, 0, 0))
				p["spine"] = Vector3(-0.1, 0, 0)
			else:
				# Chute : bras ouverts qui battent, jambes écartées
				var fl := sin(_t * 6.0)
				_mirror(p, "upper_arm", Vector3(-0.4 + fl * 0.15, 0, 1.3))
				_mirror(p, "forearm", Vector3(-0.3, 0, 0))
				_mirror(p, "thigh", Vector3(-0.3, 0, 0.25))
				_mirror(p, "shin", Vector3(0.5, 0, 0))
				p["spine"] = Vector3(-0.2, 0, 0)
				p["head"] = Vector3(-0.2, 0, 0)
			p["_rate"] = 9.0
		S.LANDING:
			# Réception : accroupi, bras en avant
			p["spine"] = Vector3(-0.45, 0, 0)
			p["head"] = Vector3(0.3, 0, 0)
			_mirror(p, "upper_arm", Vector3(-0.9, 0, 0.5))
			_mirror(p, "forearm", Vector3(-0.4, 0, 0))
			_mirror(p, "thigh", Vector3(-0.9, 0, 0.15))
			_mirror(p, "shin", Vector3(1.4, 0, 0))
			_mirror(p, "foot", Vector3(-0.4, 0, 0))
			p["_rate"] = 16.0
			if _land_heavy:
				# Réception de super-héros : genou droit au sol, poing droit planté, bras gauche ouvert, tête baissée
				p["_hips"] = -0.42
				p["spine"] = Vector3(-0.6, 0, 0)
				p["chest"] = Vector3(-0.1, 0.15, 0)
				p["head"] = Vector3(0.35, 0, 0)
				p["upper_arm_R"] = Vector3(-0.35, 0, -0.25)
				p["forearm_R"] = Vector3(-0.15, 0, 0)
				p["upper_arm_L"] = Vector3(0.45, 0, 0.9)
				p["forearm_L"] = Vector3(-0.5, 0, 0)
				p["thigh_L"] = Vector3(-1.35, 0, 0.12)
				p["shin_L"] = Vector3(1.45, 0, 0)
				p["foot_L"] = Vector3(-0.1, 0, 0)
				p["thigh_R"] = Vector3(0.15, 0, -0.08)
				p["shin_R"] = Vector3(1.55, 0, 0)
				p["foot_R"] = Vector3(0.6, 0, 0)
				p["_rate"] = 22.0
		_:
			# Au sol
			if player.in_cover:
				_cover_pose(p)
			elif player.dash_t > 0.0:
				# Esquive : bond propulsé, genoux remontés, bras écartés pour l'équilibre
				p["spine"] = Vector3(-0.25, 0, 0)
				p["head"] = Vector3(-0.1, 0, 0)
				_mirror(p, "upper_arm", Vector3(0.5, 0, 0.55))
				_mirror(p, "forearm", Vector3(-0.5, 0, 0))
				p["thigh_L"] = Vector3(-0.85, 0, 0.12)
				p["shin_L"] = Vector3(1.1, 0, 0)
				p["thigh_R"] = Vector3(-0.35, 0, -0.1)
				p["shin_R"] = Vector3(0.9, 0, 0)
				_mirror(p, "foot", Vector3(0.35, 0, 0))
				p["_hips"] = -0.05
				p["_rate"] = 20.0
			elif _land_t > 0.0 and hspeed < 1.0:
				var k := _land_t / 0.5 * (1.0 if _land_heavy else 0.6)
				p["spine"] = Vector3(-0.35 * k, 0, 0)
				_mirror(p, "thigh", Vector3(-0.6 * k, 0, 0.1))
				_mirror(p, "shin", Vector3(1.0 * k, 0, 0))
				_mirror(p, "upper_arm", Vector3(-0.4 * k, 0, 0.4 * k))
				p["_rate"] = 14.0
			else:
				# Repos, marche, course : animations capturées (Mixamo) transférées sur le Solaris
				_locomotion(p, delta, hspeed, on_floor)

	var firing: bool = Input.is_action_pressed("fire") and not player.get_tree().paused and combat != null and combat.can_shoot()
	var hidden: bool = player.in_cover and player.cover_peek < 0.3
	var still: bool = hspeed < 0.6 and on_floor and st == S.GROUND and not player.in_cover
	# Visée : fusil épaulé, buste tourné, recul au tir
	var airborne: bool = st == S.HOVER or st == S.AIR
	if aiming and not player.dead and not hidden and st != S.FLY:
		var rec := _recoil * 0.35
		# Buste de profil (épaule gauche devant) ; le recul le repousse un peu en arrière
		p["chest"] = Vector3(0.07 * _recoil, -0.32 - 0.03 * _recoil, 0) + p.get("chest", Vector3.ZERO) * 0.3
		p["upper_arm_R"] = Vector3(-1.5 + rec, 0.25, -0.1)
		p["forearm_R"] = Vector3(-0.05 - rec * 0.5, 0, 0)
		p["hand_R"] = Vector3(0, 0, 0)
		p["upper_arm_L"] = Vector3(-1.0, -0.35, -0.25)
		p["forearm_L"] = Vector3(-0.7, 0, 0)
		p["head"] = Vector3(-0.05, 0.3, 0)
		if airborne:
			# Tir en stationnaire : le recul repousse le buste, les jambes balancent
			p["spine"] = p.get("spine", Vector3.ZERO) + Vector3(rec * 0.5, 0, 0)
			p["thigh_L"] = p.get("thigh_L", Vector3.ZERO) + Vector3(rec * 0.4, 0, 0)
			p["thigh_R"] = p.get("thigh_R", Vector3.ZERO) + Vector3(rec * 0.25, 0, 0)
		if still:
			# Posture de tir : jambes écartées, genoux fléchis, poids en avant
			p["_hips"] = -0.1
			p["spine"] = Vector3(-0.12, 0, 0)
			p["thigh_L"] = Vector3(-0.4, 0, 0.12)
			p["shin_L"] = Vector3(0.55, 0, 0)
			p["thigh_R"] = Vector3(0.1, 0, -0.14)
			p["shin_R"] = Vector3(0.3, 0, 0)
			p["foot_L"] = Vector3(-0.15, 0, 0)
		p["_rate"] = maxf(p["_rate"], 14.0)
	elif firing and not player.dead and not hidden and _punch_t <= 0.0:
		# Tir à la hanche : fusil remonté, main gauche sous le canon, buste penché sur l'arme
		var rec := _recoil * 0.3
		p["chest"] = Vector3(0.05 * _recoil, -0.2, 0) + p.get("chest", Vector3.ZERO) * 0.5
		p["upper_arm_R"] = Vector3(-0.85 + rec, 0.2, -0.2)
		p["forearm_R"] = Vector3(-0.75 - rec * 0.4, 0, 0)
		p["upper_arm_L"] = Vector3(-0.75, -0.3, -0.2)
		p["forearm_L"] = Vector3(-1.05, 0, 0)
		p["head"] = Vector3(0.0, 0.15, 0)
		if still:
			p["_hips"] = -0.06
			p["thigh_L"] = Vector3(-0.3, 0, 0.1)
			p["shin_L"] = Vector3(0.4, 0, 0)
			p["thigh_R"] = Vector3(0.12, 0, -0.1)
		p["_rate"] = maxf(p["_rate"], 14.0)

	# Changement d'arme : le bras droit est guidé par l'arme elle-même (voir _hold_weapon) ; le buste accompagne
	var sw := _switch_k()
	if sw >= 0.0:
		var reach := sin(sw * PI) if sw < 0.5 else sin(sw * PI)
		p["chest"] = p.get("chest", Vector3.ZERO) + Vector3(0.05 * reach, 0.3 * reach, 0)
		p["head"] = Vector3(0.05 * reach, 0.35 * reach, 0)
		p["_rate"] = maxf(p["_rate"], 16.0)
	# Grenade : armé au-dessus de l'épaule gauche puis lancer par-dessus
	if _throw_t > 0.0:
		var k := 1.0 - _throw_t / THROW_TIME
		var rel := smoothstep(0.3, 0.6, k)
		var back := 1.0 - smoothstep(0.75, 1.0, k)
		p["upper_arm_L"] = Vector3(lerpf(-2.8, -1.1, rel) * back, 0, 0.35 * back)
		p["forearm_L"] = Vector3(lerpf(-1.7, -0.1, rel) * back, 0, 0)
		p["spine"] = p.get("spine", Vector3.ZERO) + Vector3(lerpf(0.12, -0.2, rel) * back, lerpf(-0.35, 0.3, rel) * back, 0)
		p["_rate"] = maxf(p["_rate"], 20.0)
	# Pouvoir : main gauche projetée vers l'avant
	if _cast_t > 0.0:
		var k := _cast_t / 0.6
		var push := sin(k * PI)
		p["upper_arm_L"] = Vector3(-1.6 * push, 0.2, 0.2)
		p["forearm_L"] = Vector3(-0.1, 0, 0)
		p["spine"] = p.get("spine", Vector3.ZERO) + Vector3(-0.1 * push, 0.3 * push, 0)
		p["_rate"] = maxf(p["_rate"], 18.0)
	return p


## Poses des animations du preset. k = avancement 0..1, t = secondes écoulées.
func _act_pose(id: String, k: float, t: float) -> Dictionary:
	var p := {}
	var e := smoothstep(0.0, 0.15, k) * (1.0 - smoothstep(0.85, 1.0, k))   # entrée / sortie
	p["_rate"] = 9.0
	match id:
		"drop":
			# Réception héroïque : accroupi, poing droit au sol, puis on se relève
			var down := 1.0 - smoothstep(0.45, 0.8, k)
			p["_rate"] = 14.0 if k < 0.1 else 6.0
			p["_hips"] = -0.32 * down
			p["spine"] = Vector3(-0.75 * down, 0, 0)
			p["head"] = Vector3(-0.2 * down, 0, 0)
			p["upper_arm_R"] = Vector3(-0.5 * down, 0, -0.35 * down)
			p["forearm_R"] = Vector3(-0.2 * down, 0, 0)
			p["upper_arm_L"] = Vector3(0.6 * down, 0, 0.7 * down)
			p["thigh_L"] = Vector3(-1.3 * down, 0, 0.1)
			p["shin_L"] = Vector3(1.4 * down, 0, 0)
			p["thigh_R"] = Vector3(0.1 * down, 0, -0.1)
			p["shin_R"] = Vector3(1.4 * down, 0, 0)
		"scan":
			# Main à la visière, la tête balaie l'horizon
			p["upper_arm_L"] = Vector3(-1.1 * e, 0, 0.55 * e)
			p["forearm_L"] = Vector3(-2.0 * e, 0, 0)
			p["head"] = Vector3(-0.1 * e, sin(t * 2.2) * 0.7 * e, 0)
			p["chest"] = Vector3(0, sin(t * 2.2) * 0.25 * e, 0)
			_mirror_one(p, "upper_arm_R", Vector3(0.05, 0, -0.1))
		"ignite":
			# Le noyau s'éveille : bras ouverts vers le bas, buste bombé, tête levée
			var pulse := sin(k * PI)
			p["spine"] = Vector3(0.18 * pulse, 0, 0)
			p["chest"] = Vector3(0.15 * pulse, 0, 0)
			p["head"] = Vector3(-0.45 * pulse, 0, 0)
			p["upper_arm_L"] = Vector3(0.25 * pulse, 0, 0.75 * pulse)
			p["upper_arm_R"] = Vector3(0.25 * pulse, 0, -0.75 * pulse)
			p["forearm_L"] = Vector3(-0.3 * pulse, 0, 0)
			p["forearm_R"] = Vector3(-0.3 * pulse, 0, 0)
			p["_rate"] = 5.0
		"salute":
			p["upper_arm_R"] = Vector3(-1.25 * e, 0, -0.95 * e)
			p["forearm_R"] = Vector3(-2.2 * e, 0, 0)
			p["head"] = Vector3(-0.08 * e, 0, 0)
			p["upper_arm_L"] = Vector3(0.05, 0, 0.08)
			p["spine"] = Vector3(0.05 * e, 0, 0)
		"fist":
			p["upper_arm_R"] = Vector3(-2.85 * e, 0, -0.15 * e)
			p["forearm_R"] = Vector3(-0.25 * e, 0, 0)
			p["head"] = Vector3(-0.35 * e, 0, 0)
			p["spine"] = Vector3(0.12 * e, 0, 0)
			p["upper_arm_L"] = Vector3(0.1 * e, 0, 0.25 * e)
			p["forearm_L"] = Vector3(-0.6 * e, 0, 0)
		"crossed":
			p["upper_arm_L"] = Vector3(-0.55 * e, 0, 0.2 * e)
			p["upper_arm_R"] = Vector3(-0.55 * e, 0, -0.2 * e)
			p["forearm_L"] = Vector3(-1.75 * e, -0.9 * e, 0)
			p["forearm_R"] = Vector3(-1.75 * e, 0.9 * e, 0)
			p["head"] = Vector3(-0.1 * e, 0.15 * sin(t), 0)
			p["thigh_L"] = Vector3(0, 0, 0.12 * e)
			p["thigh_R"] = Vector3(0, 0, -0.12 * e)
		"kneel":
			p["_rate"] = 6.0
			p["_hips"] = -0.35 * e
			p["thigh_L"] = Vector3(-1.1 * e, 0, 0)
			p["shin_L"] = Vector3(1.1 * e, 0, 0)
			p["thigh_R"] = Vector3(0.2 * e, 0, 0)
			p["shin_R"] = Vector3(1.4 * e, 0, 0)
			p["foot_R"] = Vector3(0.6 * e, 0, 0)
			p["spine"] = Vector3(-0.2 * e, 0, 0)
			p["head"] = Vector3(0.35 * e, 0, 0)
			p["upper_arm_L"] = Vector3(-0.6 * e, 0, 0.2 * e)
			p["forearm_L"] = Vector3(-0.6 * e, 0, 0)
			p["upper_arm_R"] = Vector3(-0.2 * e, 0, -0.1 * e)
		"wave":
			p["upper_arm_R"] = Vector3(-0.3 * e, 0, -2.35 * e)
			p["forearm_R"] = Vector3(0, 0, (-0.2 + 0.55 * sin(t * 11.0)) * e)
			p["head"] = Vector3(0, -0.2 * e, 0)
			p["upper_arm_L"] = Vector3(0.05, 0, 0.1)
		"point":
			p["chest"] = Vector3(0, -0.3 * e, 0)
			p["upper_arm_R"] = Vector3(-1.5 * e, 0.2 * e, -0.15 * e)
			p["forearm_R"] = Vector3(-0.05, 0, 0)
			p["head"] = Vector3(-0.05, -0.3 * e, 0)
			p["upper_arm_L"] = Vector3(0.1, 0, 0.15)
		"stretch":
			var up := sin(k * PI)
			p["upper_arm_L"] = Vector3(-2.8 * up, 0, 0.35 * up)
			p["upper_arm_R"] = Vector3(-2.8 * up, 0, -0.35 * up)
			p["forearm_L"] = Vector3(-0.3 * up, 0, 0)
			p["forearm_R"] = Vector3(-0.3 * up, 0, 0)
			p["spine"] = Vector3(0.25 * up, 0, 0)
			p["head"] = Vector3(-0.3 * up, 0, 0)
			p["_rate"] = 5.0
	return p


## À couvert. Muret : accroupi, fusil serré contre le torse ; on se relève à moitié pour tirer.
## Mur : debout, épaule contre la paroi, fusil levé canon en l'air.
func _cover_pose(p: Dictionary) -> void:
	var peek: float = player.cover_peek
	var hide := 1.0 - peek
	var breathe := sin(_t * 1.8) * 0.02
	if player.cover_low:
		p["_hips"] = -0.55 * hide - 0.12 * peek
		p["spine"] = Vector3(-0.35 * hide - 0.1 * peek + breathe, 0, 0)
		p["head"] = Vector3(0.05, 0.35 * hide, 0)
		p["thigh_L"] = Vector3(-1.35 * hide - 0.35 * peek, 0, 0.18)
		p["shin_L"] = Vector3(1.9 * hide + 0.5 * peek, 0, 0)
		p["foot_L"] = Vector3(-0.4 * hide, 0, 0)
		p["thigh_R"] = Vector3(-0.6 * hide + 0.1 * peek, 0, -0.18)
		p["shin_R"] = Vector3(1.9 * hide + 0.3 * peek, 0, 0)
		p["foot_R"] = Vector3(0.3 * hide, 0, 0)
	else:
		p["spine"] = Vector3(-0.05 + breathe, 0.25 * hide, 0)
		p["head"] = Vector3(0, 0.55 * hide, 0)
		p["thigh_L"] = Vector3(-0.2, 0, 0.1)
		p["shin_L"] = Vector3(0.3, 0, 0)
		p["thigh_R"] = Vector3(0.05, 0, -0.12)
		p["shin_R"] = Vector3(0.15, 0, 0)
	# Fusil serré : bras droit replié, main gauche sur le garde-main
	p["upper_arm_R"] = Vector3(-0.45, 0.1, -0.3)
	p["forearm_R"] = Vector3(-1.7, 0, 0)
	p["upper_arm_L"] = Vector3(-0.6, -0.2, 0.05)
	p["forearm_L"] = Vector3(-1.5, 0, 0)
	p["_rate"] = 10.0


# ---------------------------------------------------------------- animations capturées
## assets/anim/locomotion.json : idle, walk, run (Xbot de three.js, rig Mixamo) transférés par tools/bake_anim.gd.
static var _clips := {}
const WALK_SPEED := 1.4          # vitesse (m/s) à laquelle le pied d'appui ne glisse pas (mesurée sur le clip)
const RUN_SPEED := 3.05          # idem pour la course
const MAX_PLAYBACK := 1.9
const MAX_AMP := 1.6             # un exo va plus vite qu'un humain : on allonge la foulée plutôt que d'affoler la cadence
const RUN_PHASE := -0.1          # décalage du clip de course pour que les pieds tombent au même moment que la marche        # au-delà on allonge les gestes au lieu d'accélérer encore la cadence
var _phase := 0.0                # avancement du cycle marche/course (0..1, partagé par les deux clips)
var _idle_t := 0.0
var _loco_w := 0.0               # 0 repos, 1 en mouvement (lissé)


static func _load_clips() -> void:
	if not _clips.is_empty():
		return
	var txt := FileAccess.get_file_as_string("res://assets/anim/locomotion.json")
	var data = JSON.parse_string(txt)
	if data == null:
		push_warning("locomotion.json introuvable : animations procédurales seulement")
		_clips["_none"] = true
		return
	var names: Array = data["bones"]
	for clip in data["clips"]:
		var frames := []
		for fr in data["clips"][clip]["frames"]:
			var q := {}
			for i in names.size():
				var v: Array = fr["q"][i]
				q[names[i]] = Quaternion(v[0], v[1], v[2], v[3])
			frames.append({ "q": q, "hips": Vector2(float(fr["hips"][0]), float(fr["hips"][1])) })
		_clips[clip] = { "length": float(data["clips"][clip]["length"]), "frames": frames }


## Pose d'un clip à l'avancement k (0..1), interpolée entre deux images.
func _sample(clip: String, k: float) -> Dictionary:
	var c: Dictionary = _clips[clip]
	var frames: Array = c["frames"]
	var f := fposmod(k, 1.0) * frames.size()
	var a: Dictionary = frames[int(f) % frames.size()]
	var b: Dictionary = frames[(int(f) + 1) % frames.size()]
	var w: float = f - floor(f)
	var q := {}
	for bone in BONES:
		q[bone] = (a["q"].get(bone, Quaternion()) as Quaternion).slerp(b["q"].get(bone, Quaternion()), w)
	return { "q": q, "hips": (a["hips"] as Vector2).lerp(b["hips"], w) }


func _blend(x: Dictionary, y: Dictionary, w: float) -> Dictionary:
	var q := {}
	for bone in BONES:
		q[bone] = (x["q"][bone] as Quaternion).slerp(y["q"][bone], w)
	return { "q": q, "hips": (x["hips"] as Vector2).lerp(y["hips"], w) }


func _locomotion(p: Dictionary, delta: float, hspeed: float, on_floor: bool) -> void:
	_load_clips()
	if _clips.has("_none"):
		return
	_idle_t += delta
	var moving := hspeed > 0.4 and on_floor
	_loco_w = move_toward(_loco_w, 1.0 if moving else 0.0, delta * 5.0)
	var run_w := smoothstep(WALK_SPEED * 1.3, RUN_SPEED, hspeed)
	var clip_speed := lerpf(WALK_SPEED, RUN_SPEED, run_w)
	var factor := hspeed / clip_speed
	var playback := factor
	var amp := 1.0
	if factor > 1.0:                              # moitié cadence, moitié longueur de foulée
		playback = minf(MAX_PLAYBACK, pow(factor, 0.6))
		amp = clampf(factor / playback, 1.0, MAX_AMP)
	var cyc_len := lerpf(_clips["walk"]["length"], _clips["run"]["length"], run_w)
	var before := _phase
	if moving:
		_phase = fposmod(_phase + delta * playback / cyc_len, 1.0)
		# un pied touche le sol deux fois par cycle
		if (before < 0.5 and _phase >= 0.5) or _phase < before:
			if player.has_method("footstep"):
				player.footstep(run_w)
	var loco := _blend(_sample("walk", _phase), _sample("run", _phase + RUN_PHASE), run_w)
	var idle := _sample("idle", _idle_t / _clips["idle"]["length"])
	var pose := _blend(idle, loco, _loco_w)
	for bone in BONES:
		var e: Vector3 = (pose["q"][bone] as Quaternion).get_euler()
		if amp > 1.0 and (bone.begins_with("thigh") or bone.begins_with("shin") or bone.begins_with("upper_arm") or bone.begins_with("foot")):
			e.x *= amp
		p[bone] = e
	p["_hips"] = pose["hips"].y * (1.0 + (amp - 1.0) * 1.5)
	p["_hips_x"] = (pose["hips"].x - 0.022) * _loco_w      # balancement latéral du bassin (centré)
	p["_rate"] = 24.0


func _mirror_one(p: Dictionary, bone: String, v: Vector3) -> void:
	p[bone] = v


# ================================================================ tenue de l'arme
# L'arme n'est plus collée à la main : on place l'arme là où un soldat la tient (crosse à l'épaule en visée,
# en travers du torse au repos), puis les deux bras vont la chercher par cinématique inverse (IK) :
# main droite sur la poignée, main gauche sous le canon. Au changement d'arme, c'est l'arme qui fait
# le trajet (devant → par-dessus l'épaule → dans le dos) et la main droite la suit.
var _gun_xf := Transform3D.IDENTITY
var _gun_init := false
var _ik_r := 0.0                 # poids de l'IK du bras droit (0 = animation seule)
var _ik_l := 0.0
var hand_w := 1.0               # orientation des mains sur l'arme (0 = laissée à l'animation)


## Avancement du changement d'arme (0..1), -1 hors changement.
func _switch_k() -> float:
	var c = player.combat if player else null
	if c == null or c.switch_t <= 0.0:
		return -1.0
	return 1.0 - c.switch_t / Combat.SWITCH_TIME


func _bone_world(name: String) -> Transform3D:
	return skeleton.global_transform * skeleton.get_bone_global_pose(_idx[name])


func _ready_xf(sh: Vector3, fwd: Vector3, up: Vector3, right: Vector3) -> Transform3D:
	# Au repos (« prêt ») : arme devant soi, canon vers l'avant-bas un peu à gauche, poignée devant la hanche
	# droite, assez loin du corps pour que le coude reste libre en arrière
	var d := (fwd * 0.9 - up * 0.38 - right * 0.24).normalized()
	var bob := _gun_bob(up, right)
	return Transform3D(Basis.looking_at(d, up).rotated(up, bob.w), sh + fwd * 0.4 - up * 0.33 + right * 0.02 + Vector3(bob.x, bob.y, bob.z))


## Balancement de l'arme avec le pas : petit rebond vertical et lacet, plus marqué en course.
func _gun_bob(up: Vector3, right: Vector3) -> Vector4:
	if _loco_w < 0.05:
		return Vector4(0, sin(_t * 1.6) * 0.004, 0, 0)       # respiration
	var amp := _loco_w * (1.6 if player.sprinting else 1.0)
	var ph := _phase * TAU
	var v := up * sin(ph * 2.0) * 0.012 * amp + right * sin(ph) * 0.01 * amp
	return Vector4(v.x, v.y, v.z, sin(ph) * 0.05 * amp)


func _hold_weapon(delta: float) -> void:
	var c = player.combat
	if c == null or c.guns.is_empty() or player.look == null:
		return
	var S = player.State
	var st: int = player.state
	var chest := _bone_world("chest")
	var mb: Basis = player.model.global_basis.orthonormalized()
	var fwd := -mb.z
	var right := mb.x
	var up := Vector3.UP
	var sh := _bone_world("upper_arm_R").origin
	var hand := _bone_world("hand_R")
	var sw := _switch_k()
	# Armes rangées
	for i in c.guns.size():
		if i != c.weapon_index:
			c.guns[i].global_transform = c.holster_xf(i, chest)
	# Où doit être l'arme en main ?
	var want_r := 1.0
	var want_l := 1.0
	var target: Transform3D
	var snap := false
	var aim_dir: Vector3 = c._aim_point() - sh
	aim_dir = aim_dir.normalized() if aim_dir.length() > 0.5 else fwd
	var hidden: bool = player.in_cover and player.cover_peek < 0.3
	var shooting: bool = (c.aiming or (Input.is_action_pressed("fire") and not player.get_tree().paused)) and c.can_shoot() and not hidden
	var one_hand: bool = player.dead or act != "" or _punch_t > 0.0 or st == S.FLY or st == S.LANDING \
		or (st == S.AIR and not shooting) or player.roll_t > 0.0
	if sw >= 0.0:
		# Changement d'arme : devant → au-dessus de l'épaule → dans le dos, on lâche, on attrape l'autre, retour
		var over := Transform3D(Basis.looking_at((up * 0.75 - fwd * 0.55 + right * 0.1).normalized(), -fwd),
			sh + up * 0.32 + fwd * 0.06 + right * 0.06)
		var ready := _ready_xf(sh, fwd, up, right)
		var holster: Transform3D = c.holster_xf(c.weapon_index, chest)
		if sw < 0.5:
			target = _path(ready, over, holster, smoothstep(0.0, 0.5, sw))
		else:
			target = _path(holster, over, ready, smoothstep(0.5, 1.0, sw))
		snap = true
		want_l = 0.0
	elif one_hand:
		# Une main : l'arme pend au bout du bras droit, canon vers l'avant-bas
		var hb := hand.basis.orthonormalized()
		target = Transform3D(mb * Basis(Vector3.RIGHT, -0.9), hand.origin + mb * Vector3(0.0, -0.05, -0.04))
		want_r = 0.0
		want_l = 0.0
		snap = true
	elif shooting:
		# Le recul remonte le canon et repousse l'arme vers l'épaule ; les bras suivent (IK), le buste encaisse
		var rec := _recoil
		var aim_r := aim_dir.cross(up).normalized()
		var b := Basis.looking_at(aim_dir, up).rotated(aim_r, 0.06 * rec)
		if c.aiming:
			# Épaulé : poignée devant l'épaule, crosse dedans, ligne de visée à hauteur des yeux
			target = Transform3D(b, sh + aim_dir * 0.27 - up * 0.08 + aim_r * 0.03 - aim_dir * 0.04 * rec + up * 0.012 * rec)
		else:
			# À la hanche : arme devant la poitrine, un peu plus bas et plus loin
			target = Transform3D(b, sh + aim_dir * 0.36 - up * 0.22 + aim_r * 0.02 - aim_dir * 0.035 * rec)
	else:
		target = _ready_xf(sh, fwd, up, right)
	if _throw_t > 0.0 or _cast_t > 0.0:
		want_l = 0.0
	if not _gun_init:
		_gun_xf = target
		_gun_init = true
	elif snap:
		_gun_xf = _gun_xf.interpolate_with(target, minf(1.0, delta * 30.0))
	else:
		_gun_xf = _gun_xf.interpolate_with(target, minf(1.0, delta * 16.0))
	_ik_r = move_toward(_ik_r, want_r, delta * 6.0)
	_ik_l = move_toward(_ik_l, want_l, delta * (8.0 if want_l > _ik_l else 10.0))
	var gb := _gun_xf.basis.orthonormalized()
	c.weapon.global_transform = Transform3D(gb, _gun_xf.origin)
	# Directions de l'arme : avant (canon), haut, droite
	var g_f := -gb.z
	var g_u := gb.y
	var g_r := gb.x
	# Main droite : poignet derrière la poignée, doigts vers l'avant-bas, paume contre la poignée (vers la gauche)
	var rf := (g_f - g_u * 0.45).normalized()
	var fore: Vector3 = c.current().get("fore", Vector3(0, -0.02, -0.3))
	var grip_w := _gun_xf.origin - rf * 0.075 + g_r * 0.035 - g_u * 0.01
	# Main gauche : sous le garde-main, paume vers le haut, doigts vers l'avant et vers l'arme
	var lf := (g_f + g_r * 0.35).normalized()
	var fore_w := _gun_xf.origin + gb * fore - lf * 0.06 - g_u * 0.015
	# Coudes : le droit vers le bas, en dehors et un peu en arrière (relevé en visée) ; le gauche sous l'arme
	var elbow_r := (-up * 0.75 + right * 0.55 - fwd * 0.45)
	var elbow_l := (-up * 1.0 - right * 0.15 - fwd * 0.1)
	if shooting and c.aiming:
		elbow_r = (-up * 0.7 + right * 0.7 - fwd * 0.25)
		elbow_l = (-up * 1.0 + right * 0.35)
	if sw >= 0.0:
		elbow_r = up * 0.6 + right * 0.8
	# Les épaules accompagnent les deux bras de la même façon : elles avancent et se lèvent vers la main
	_shoulder("shoulder_R", "upper_arm_R", grip_w, _ik_r)
	_shoulder("shoulder_L", "upper_arm_L", fore_w, _ik_l)
	_ik("upper_arm_R", "forearm_R", "hand_R", grip_w, elbow_r, _ik_r)
	_ik("upper_arm_L", "forearm_L", "hand_L", fore_w, elbow_l, _ik_l)
	_orient_hand("hand_R", rf, -g_r, _ik_r * hand_w)
	_orient_hand("hand_L", lf, g_u, _ik_l * hand_w)
	c._flash.global_position = c.muzzle.global_position


## Épaule : pivote d'une fraction de l'angle vers la main visée (au plus 0,35 rad), comme une vraie épaule
## qui avance quand on tend le bras et se lève quand on épaule.
const SHOULDER_SHARE := 0.3
func _shoulder(sh: String, upper: String, target_w: Vector3, w: float) -> void:
	if w <= 0.001 or not _idx.has(sh):
		return
	var target := skeleton.global_transform.affine_inverse() * target_w
	var i_s: int = _idx[sh]
	var g := skeleton.get_bone_global_pose(i_s)
	var child := skeleton.get_bone_global_pose(_idx[upper]).origin
	var cur := (child - g.origin).normalized()
	var want := (target - g.origin).normalized()
	var ang := minf(cur.angle_to(want) * SHOULDER_SHARE, 0.35)
	if ang < 0.001:
		return
	var axis := cur.cross(want).normalized()
	var dir := cur.rotated(axis, ang)
	_aim_bone(i_s, g, child, g.origin + dir * (child - g.origin).length(), w)


## Trajet d'arme entre trois repères (courbe douce par le point du milieu).
func _path(a: Transform3D, m: Transform3D, b: Transform3D, k: float) -> Transform3D:
	var p0 := a.origin.lerp(m.origin, k)
	var p1 := m.origin.lerp(b.origin, k)
	var pos := p0.lerp(p1, k)
	var q: Quaternion
	if k < 0.5:
		q = a.basis.get_rotation_quaternion().slerp(m.basis.get_rotation_quaternion(), k * 2.0)
	else:
		q = m.basis.get_rotation_quaternion().slerp(b.basis.get_rotation_quaternion(), k * 2.0 - 1.0)
	return Transform3D(Basis(q), pos)


## IK à deux os (bras, avant-bras) : la main (poignet) va sur target, le coude part vers pole. Repère monde.
func _ik(upper: String, fore: String, hand: String, target_w: Vector3, pole_w: Vector3, w: float) -> void:
	if w <= 0.001:
		return
	var inv := skeleton.global_transform.affine_inverse()
	var target := inv * target_w
	var pole := (inv.basis * pole_w).normalized()
	var iu: int = _idx[upper]
	var i_f: int = _idx[fore]
	var ih: int = _idx[hand]
	var gu := skeleton.get_bone_global_pose(iu)
	var gf := skeleton.get_bone_global_pose(i_f)
	var gh := skeleton.get_bone_global_pose(ih)
	var a := gu.origin.distance_to(gf.origin)
	var b := gf.origin.distance_to(gh.origin)
	var to := target - gu.origin
	var d := clampf(to.length(), absf(a - b) + 0.01, a + b - 0.002)
	var dir := to.normalized()
	var cos_a := clampf((a * a + d * d - b * b) / (2.0 * a * d), -1.0, 1.0)
	var ang := acos(cos_a)
	var perp := pole - dir * pole.dot(dir)
	if perp.length() < 0.001:
		perp = Vector3.DOWN - dir * Vector3.DOWN.dot(dir)
	perp = perp.normalized()
	var elbow := gu.origin + (dir * cos(ang) + perp * sin(ang)) * a
	_aim_bone(iu, gu, gf.origin, elbow, w)
	gf = skeleton.get_bone_global_pose(i_f)
	gh = skeleton.get_bone_global_pose(ih)
	_aim_bone(i_f, gf, gh.origin, gu.origin + dir * d, w)


## Tourne un os (repère squelette) pour que son enfant (child_pos) passe par want.
func _aim_bone(idx: int, g: Transform3D, child_pos: Vector3, want: Vector3, w: float) -> void:
	var from := (child_pos - g.origin).normalized()
	var to := (want - g.origin).normalized()
	if from.dot(to) > 0.99999:
		return
	var q := Quaternion(from, to)
	var nb := (Basis(q) * g.basis.orthonormalized())
	if w < 1.0:
		nb = Basis(g.basis.orthonormalized().get_rotation_quaternion().slerp(nb.get_rotation_quaternion(), w))
	var parent := skeleton.get_bone_parent(idx)
	var pb := skeleton.get_bone_global_pose(parent).basis.orthonormalized() if parent >= 0 else Basis()
	skeleton.set_bone_pose_rotation(idx, (pb.inverse() * nb).get_rotation_quaternion())


## Oriente la main : f = direction poignet → doigts, palm = vers où regarde la paume (repère monde).
## Au repos (pose A du rig) les bras pendent : doigts vers le bas, paumes tournées vers le corps.
const HAND_REST_F := Vector3(-0.08, -1.0, 0.0)
func _frame(f: Vector3, palm: Vector3) -> Basis:
	var x := f.normalized()
	var y := (palm - x * palm.dot(x)).normalized()
	return Basis(x, y, x.cross(y))


func _orient_hand(hand: String, f_w: Vector3, palm_w: Vector3, w: float) -> void:
	if w <= 0.001:
		return
	var ih: int = _idx[hand]
	var inv := skeleton.global_transform.basis.orthonormalized().inverse()
	var left := hand == "hand_L"
	var rest := _frame(Vector3(-HAND_REST_F.x if left else HAND_REST_F.x, HAND_REST_F.y, 0), Vector3(-1 if left else 1, 0, 0))
	var nb := _frame(inv * f_w, inv * palm_w) * rest.inverse()
	var g := skeleton.get_bone_global_pose(ih)
	var q := g.basis.orthonormalized().get_rotation_quaternion().slerp(nb.get_rotation_quaternion(), w)
	var parent := skeleton.get_bone_parent(ih)
	var pb := skeleton.get_bone_global_pose(parent).basis.orthonormalized()
	skeleton.set_bone_pose_rotation(ih, (pb.inverse() * Basis(q)).get_rotation_quaternion())
