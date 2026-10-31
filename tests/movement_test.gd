extends Node
## Test automatique des déplacements de l'exo : course, cachette (muret et mur), tir bloqué par l'obstacle,
## saut par-dessus le muret, vrille en vol (esquive + écart latéral), réception lourde.
## Lancer : godot --headless --path . tests/movement_test.tscn

var t := 0.0
var step := 0
var _mark := 0.0
var _p0 := Vector3.ZERO
var _v := 0.0
@onready var main: Node = $Main
@onready var player: CharacterBody3D = $Main/Player


func _ready() -> void:
	Appearance.persist = false
	Appearance.reset()


func _check(ok: bool, msg: String) -> void:
	if not ok:
		print("[move] ÉCHEC : " + msg)
		get_tree().quit(1)
		set_physics_process(false)


func _next(s: int) -> void:
	step = s
	_mark = t


func _since() -> float:
	return t - _mark


func _place(pos: Vector3, yaw := 0.0) -> void:
	player.global_position = pos
	player.velocity = Vector3.ZERO
	player.state = player.State.GROUND
	player.cam_yaw = yaw
	player.model.rotation.y = yaw


func _physics_process(delta: float) -> void:
	t += delta
	var c = player.combat
	match step:
		0:
			if t > 0.6:
				for sl in Loadout.SLOTS:
					Loadout.set_tier(sl, 2)
				_place(Vector3(45.0, 0.2, 82.0), 0.0)
				Input.action_press("move_forward")
				_next(1)
		1:
			if _since() > 1.0:
				_v = Vector2(player.velocity.x, player.velocity.z).length()
				print("[move] marche v=%.2f" % _v)
				player._sprint_press()
				_next(2)
		2:
			if _since() > 1.0:
				var v := Vector2(player.velocity.x, player.velocity.z).length()
				print("[move] pos=%s floor=%s wall=%s state=%s" % [player.global_position, player.is_on_floor(), player.is_on_wall(), player.state])
				print("[move] course v=%.2f sprinting=%s label=%s" % [v, player.sprinting, player.state_label()])
				_check(player.sprinting and v > _v * 1.4, "la course doit aller nettement plus vite que la marche")
				Input.action_release("move_forward")
				_next(3)
		3:
			if _since() > 0.6:
				_check(not player.sprinting, "la course s'arrête quand on lâche le stick")
				# Muret du champ de tir : (21.5, 70), on se place juste au sud
				_place(Vector3(21.5, 0.2, 71.4), 0.0)
				_next(4)
		4:
			if _since() > 0.3:
				var cv: Dictionary = player._find_cover()
				print("[move] obstacle trouvé=%s" % [cv])
				_check(not cv.is_empty() and cv["low"], "le muret doit être détecté comme muret")
				# B maintenu : cachette (pas de dash)
				Input.action_press("dash")
				player._dash_press()
				_next(5)
		5:
			if _since() > 0.4:
				Input.action_release("dash")
				print("[move] cachette in_cover=%s low=%s normal=%s dash_t=%.2f label=%s" % [player.in_cover, player.cover_low, player.cover_normal, player.dash_t, player.state_label()])
				_check(player.in_cover and player.cover_low, "B maintenu près du muret doit mettre à couvert")
				_check(player.cover_normal.z > 0.9, "normale du muret vers le sud attendue")
				_next(6)
		6:
			if _since() > 0.5:
				# Un tir venu de l'autre côté du muret est bloqué
				var before: float = c.shield + c.health
				c.take_damage(20.0, Vector3(0, 0, 1))
				print("[move] tir caché : %.0f -> %.0f" % [before, c.shield + c.health])
				_check(is_equal_approx(before, c.shield + c.health), "caché, le muret prend tout")
				# Déplacement latéral le long du muret
				_p0 = player.global_position
				Input.action_press("move_right")
				_next(7)
		7:
			if _since() > 0.6:
				Input.action_release("move_right")
				var dx: float = player.global_position.x - _p0.x
				print("[move] glisse le long du muret dx=%.2f dz=%.2f in_cover=%s" % [dx, player.global_position.z - _p0.z, player.in_cover])
				_check(player.in_cover and dx > 0.8, "on glisse le long du muret")
				# A : saut par-dessus
				player._fly_press()
				_next(8)
		8:
			if _since() > 1.2:
				print("[move] saut du muret pos=%s in_cover=%s" % [player.global_position, player.in_cover])
				_check(not player.in_cover and player.global_position.z < 69.5, "on doit être passé de l'autre côté")
				# Mur haut : (28.75, 79), tourné de 90°, on se place à l'est
				_place(Vector3(30.0, 0.2, 79.0), PI / 2)
				_next(9)
		9:
			if _since() > 0.3:
				player._try_cover(true)
				print("[move] mur haut in_cover=%s low=%s normal=%s" % [player.in_cover, player.cover_low, player.cover_normal])
				_check(player.in_cover and not player.cover_low, "le mur haut doit être détecté")
				Input.action_press("aim")
				_next(10)
		10:
			if _since() > 0.5:
				var before: float = c.shield + c.health
				c.take_damage(20.0, player.cover_normal)
				print("[move] sorti pour tirer peek=%.2f dégâts %.0f -> %.0f" % [player.cover_peek, before, c.shield + c.health])
				_check(player.cover_peek > 0.9 and before - (c.shield + c.health) > 9.0 and before - (c.shield + c.health) < 11.0, "sorti, on prend la moitié")
				Input.action_release("aim")
				player._dash_press()     # B : on sort de la cachette
				_check(not player.in_cover, "B doit sortir de la cachette")
				# Loin de tout obstacle : B court = dash immédiat
				_place(Vector3(40.0, 0.2, 60.0), 0.0)
				_next(11)
		11:
			if _since() > 0.3:
				player.dash_cd = 0.0
				player._dash_press()
				print("[move] dash loin d'un obstacle dash_t=%.2f" % player.dash_t)
				_check(player.dash_t > 0.0, "sans obstacle, B = dash tout de suite")
				_next(12)
		12:
			if _since() > 0.6:
				# Vol puis vrille à droite
				player._fly_press()
				_next(13)
		13:
			if _since() > 0.2:
				player._fly_press()
				_next(14)
		14:
			if _since() > 1.5:
				_check(player.flying(), "on doit voler")
				player.state = player.State.HOVER
				_next(15)
		15:
			if _since() > 1.0:
				_p0 = player.global_position
				Input.action_press("move_right")
				player._dash_press()
				var hp: float = c.shield + c.health
				c.take_damage(30.0, Vector3(1, 0, 0))
				print("[move] vrille roll_t=%.2f esquive=%s" % [player.roll_t, is_equal_approx(hp, c.shield + c.health)])
				_check(player.roll_t > 0.0 and is_equal_approx(hp, c.shield + c.health), "la vrille esquive")
				_next(16)
		16:
			if _since() > 0.2:
				Input.action_release("move_right")
			if _since() > 0.55:
				var right := Basis(Vector3.UP, player.cam_yaw) * Vector3(1, 0, 0)
				var side: float = (player.global_position - _p0).dot(right)
				print("[move] après vrille écart=%.2f m label=%s" % [side, player.state_label()])
				_check(side > 2.0, "la vrille doit écarter le Solaris sur le côté")
				# Couper les propulseurs haut : réception lourde
				player.global_position.y = 25.0
				player._land_press()
				_next(17)
		17:
			if player.state == player.State.LANDING:
				print("[move] réception lourde OK (landing_t=%.2f)" % player.landing_t)
				_next(18)
			elif _since() > 4.0:
				_check(false, "pas de réception lourde après une chute de 25 m")
		18:
			if _since() > 1.0:
				print("[move] état final %s" % player.state_label())
				print("[move] OK")
				get_tree().quit()
