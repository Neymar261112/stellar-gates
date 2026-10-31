extends CharacterBody3D
class_name Enemy
## Ennemi : soldat (tire en rafales, garde ses distances), drone (tourne autour, fonce), brute (charge, frappe).
## Même interface que les cibles d'entraînement pour l'arme, les pouvoirs et les combos :
## kind, alive, hp, center(), take_damage(), prime(), slow(), is_primed(), burning.

signal died(enemy: Enemy)

const GRAVITY := 22.0
const STATS := {
	"soldier": { "hp": 110.0, "speed": 5.0, "color": Color(0.30, 0.32, 0.38), "name": "Soldat" },
	"drone":   { "hp": 70.0,  "speed": 9.0, "color": Color(0.38, 0.36, 0.42), "name": "Drone" },
	"brute":   { "hp": 320.0, "speed": 3.4, "color": Color(0.36, 0.26, 0.24), "name": "Brute" },
}
const EYE := Color(1.0, 0.15, 0.1)

var kind := "soldier"
var label := "Soldat"
var max_hp := 100.0
var hp := 100.0
var alive := true
var burning := 0.0
var slowed := 0.0
var frozen := 0.0             # gel (grenade de givre), compte aussi comme étourdi
var _sfx: StatusFx
var stunned := 0.0   # étourdi par l'Éclat solaire : ne bouge ni ne tire, compte comme amorcé
var speed := 5.0
var player: Node3D
var alert := false
var _alert_t := 0.0
var _t := 0.0
var _flash := 0.0
var _burn_tick := 0.0
var _think_t := 0.0
var _fire_t := 1.5
var _burst := 0
var _strafe := 1.0
var _charge_t := 0.0          # brute : >0 = en charge
var _windup_t := 0.0          # brute : préparation de charge
var _swing_t := 0.0
var _dive_t := 0.0            # drone : >0 = en piqué
var _dive_cd := 4.0
var _hover_h := 7.0
var _visual: Node3D
var _bar: Node3D
var _bar_fill: MeshInstance3D
var _status: Label3D
var _mats: Array = []
var _core: MeshInstance3D
var _gun: Node3D
var _ram_hit := false


func setup(k: String, pos: Vector3) -> void:
	kind = k
	var st: Dictionary = STATS[k]
	max_hp = st["hp"]
	hp = max_hp
	speed = st["speed"]
	label = st["name"]
	position = pos
	_hover_h = randf_range(6.0, 9.0)


func _ready() -> void:
	add_to_group("targets")
	add_to_group("enemies")
	_t = randf() * TAU
	_strafe = 1.0 if randf() < 0.5 else -1.0
	collision_layer = 1
	collision_mask = 1
	_visual = Node3D.new()
	add_child(_visual)
	var col: Color = STATS[kind]["color"]
	match kind:
		"soldier":
			_mesh(_visual, _capsule(0.32, 1.3), Vector3(0, 1.05, 0), col)
			_mesh(_visual, _sphere(0.24), Vector3(0, 1.85, 0), col.lightened(0.15))
			_mesh(_visual, _box(Vector3(0.3, 0.08, 0.1)), Vector3(0, 1.88, -0.2), EYE, true)
			_mesh(_visual, _box(Vector3(0.7, 0.25, 0.5)), Vector3(0, 1.45, 0.1), col.darkened(0.25))   # épaulières
			_gun = Node3D.new()
			_gun.position = Vector3(0.35, 1.25, -0.2)
			_visual.add_child(_gun)
			_mesh(_gun, _box(Vector3(0.1, 0.12, 0.7)), Vector3(0, 0, -0.2), Color(0.12, 0.12, 0.14))
			_shape_capsule(0.4, 1.9, 0.95)
		"drone":
			_mesh(_visual, _sphere(0.5), Vector3.ZERO, col)
			for a in 4:
				var blade := _mesh(_visual, _box(Vector3(0.9, 0.05, 0.18)), Vector3.ZERO, col.darkened(0.3))
				blade.rotation.y = a * PI / 4.0
				blade.position.y = 0.45
			_mesh(_visual, _sphere(0.18), Vector3(0, -0.05, -0.45), EYE, true)
			_shape_sphere(0.65)
		"brute":
			_mesh(_visual, _box(Vector3(1.5, 1.7, 1.0)), Vector3(0, 1.6, 0), col)
			_mesh(_visual, _box(Vector3(0.55, 0.5, 0.55)), Vector3(0, 2.7, -0.1), col.lightened(0.1))
			_mesh(_visual, _box(Vector3(0.4, 0.1, 0.1)), Vector3(0, 2.72, -0.4), EYE, true)
			for x in [-1.0, 1.0]:
				_mesh(_visual, _box(Vector3(0.45, 1.3, 0.45)), Vector3(x * 1.0, 1.4, 0), col.darkened(0.2))
				_mesh(_visual, _box(Vector3(0.5, 0.9, 0.5)), Vector3(x * 0.45, 0.45, 0), col.darkened(0.35))
			_core = _mesh(_visual, _sphere(0.3), Vector3(0, 1.9, 0.6), Color(1.0, 0.5, 0.1), true)   # point faible dans le dos
			_shape_capsule(0.9, 3.2, 1.6)
	_build_bar()


# ---------------------------------------------------------------- construction
func _sphere(r: float) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = r
	m.height = r * 2.0
	m.radial_segments = 14
	m.rings = 7
	return m


func _box(size: Vector3) -> BoxMesh:
	var m := BoxMesh.new()
	m.size = size
	return m


func _capsule(r: float, h: float) -> CapsuleMesh:
	var m := CapsuleMesh.new()
	m.radius = r
	m.height = h + r * 2.0
	return m


func _mesh(parent: Node3D, mesh: Mesh, pos: Vector3, color: Color, glow := false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.5
	m.metallic = 0.65
	if glow:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = 2.5
	mi.material_override = m
	_mats.append(m)
	parent.add_child(mi)
	return mi


func _shape_capsule(r: float, h: float, y: float) -> void:
	var cs := CollisionShape3D.new()
	var sh := CapsuleShape3D.new()
	sh.radius = r
	sh.height = h
	cs.shape = sh
	cs.position.y = y
	add_child(cs)


func _shape_sphere(r: float) -> void:
	var cs := CollisionShape3D.new()
	var sh := SphereShape3D.new()
	sh.radius = r
	cs.shape = sh
	add_child(cs)


func _build_bar() -> void:
	_bar = Node3D.new()
	_bar.position.y = 2.4 if kind == "soldier" else (1.1 if kind == "drone" else 3.5)
	add_child(_bar)
	var bg := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(1.5, 0.14)
	bg.mesh = q
	bg.material_override = _flat(Color(0.05, 0.05, 0.07, 0.8))
	_bar.add_child(bg)
	_bar_fill = MeshInstance3D.new()
	var qf := QuadMesh.new()
	qf.size = Vector2(1.5, 0.14)
	_bar_fill.mesh = qf
	_bar_fill.material_override = _flat(Color(0.95, 0.25, 0.2, 1.0))
	_bar_fill.position.z = 0.01
	_bar.add_child(_bar_fill)
	_status = Label3D.new()
	_status.font_size = 40
	_status.pixel_size = 0.004
	_status.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_status.no_depth_test = true
	_status.outline_size = 8
	_status.modulate = Color(1.0, 0.55, 0.2)
	_status.position = _bar.position + Vector3(0, 0.25, 0)
	add_child(_status)
	_sfx = StatusFx.new()
	add_child(_sfx)
	_sfx.setup(self, _visual, 1.6 if kind == "brute" else 1.0)


func _flat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = c
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.no_depth_test = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


# ---------------------------------------------------------------- interface combat
func center() -> Vector3:
	match kind:
		"drone": return global_position
		"brute": return global_position + Vector3(0, 1.7, 0)
		_: return global_position + Vector3(0, 1.2, 0)


func is_primed() -> bool:
	return alive and (burning > 0.0 or stunned > 0.0)


func stun(seconds: float) -> void:
	if not alive:
		return
	stunned = maxf(stunned, seconds)
	_status.text = "ÉTOURDI"
	_windup_t = 0.0


func prime(seconds: float) -> void:
	if alive:
		burning = seconds
		_status.text = "BRÛLÉ"


## Amorce « gel » (grenade de givre) : immobilisé comme étourdi, compte comme amorcé.
func freeze(seconds: float) -> void:
	if not alive:
		return
	stun(seconds)
	frozen = maxf(frozen, seconds)


## Combo : la cible n'est plus amorcée.
func clear_status() -> void:
	burning = 0.0
	stunned = 0.0
	frozen = 0.0
	_status.text = ""


func slow(seconds: float) -> void:
	slowed = maxf(slowed, seconds)


## Point faible : tête du soldat, œil du drone, noyau dans le dos de la brute → dégâts ×2.
func _is_weak_point(pos: Vector3) -> bool:
	match kind:
		"soldier": return pos.y > global_position.y + 1.65
		"drone": return (pos - global_position).normalized().dot(-_visual.global_transform.basis.z) > 0.6
		"brute":
			if _core == null:
				return false
			return pos.distance_to(_core.global_position) < 0.75
	return false


func take_damage(amount: float, pos: Vector3, melee := false, show_number := true) -> void:
	if not alive:
		return
	var crit := show_number and not melee and _is_weak_point(pos)
	if crit:
		amount *= 2.0
	hp = maxf(0.0, hp - amount)
	_flash = 0.07
	alert = true
	_alert_t = 8.0
	if show_number:
		_spawn_number(amount, pos, melee, crit)
	if hp <= 0.0:
		_die()


func _spawn_number(amount: float, pos: Vector3, melee: bool, crit: bool) -> void:
	var l := Label3D.new()
	l.text = str(int(round(amount))) + ("  CRITIQUE" if crit else "")
	l.font_size = 64 if (melee or crit) else 44
	l.pixel_size = 0.005
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.outline_size = 10
	l.modulate = Color(1.0, 0.95, 0.75) if crit else (Color.WHITE if melee else Color(1.0, 0.93, 0.6))
	get_parent().add_child(l)
	l.global_position = pos + Vector3(randf_range(-0.3, 0.3), 0.3, 0)
	l.scale = Vector3.ONE * 0.3
	var tw := l.create_tween()
	tw.set_parallel(true)
	tw.tween_property(l, "scale", Vector3.ONE * (1.6 if (melee or crit) else 1.1), 0.12).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tw.tween_property(l, "position:y", l.position.y + 1.6, 0.8)
	tw.tween_property(l, "modulate:a", 0.0, 0.8).set_delay(0.3)
	tw.chain().tween_callback(l.queue_free)


func _die() -> void:
	alive = false
	frozen = 0.0
	_sfx.update(0.0, 0.0, 0.0, 0.0, center())
	burning = 0.0
	stunned = 0.0
	_status.text = ""
	collision_layer = 0
	collision_mask = 0
	var col := Color(1.0, 0.45, 0.15) if kind != "drone" else Color(0.6, 0.85, 1.0)
	Fx.explosion(center(), 3.5 if kind != "brute" else 6.0, col, 1.0 if kind != "brute" else 1.8)
	Fx.debris(center(), STATS[kind]["color"], 14, 9.0)
	Fx.sparks(center(), Vector3.UP, Color(0.3, 0.3, 0.32), 18, 3.0, 1.4, 0.6, 180.0, 1.5)
	if kind == "brute":
		Fx.hitstop(0.3, 0.15)
	died.emit(self)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(_visual, "scale", Vector3(0.05, 0.05, 0.05), 0.3).set_ease(Tween.EASE_IN)
	tw.tween_property(_visual, "rotation:x", -1.2, 0.3)
	tw.chain().tween_callback(queue_free)


# ---------------------------------------------------------------- comportement
func _process(delta: float) -> void:
	_t += delta
	if not alive:
		return
	slowed = maxf(0.0, slowed - delta)
	if burning > 0.0:
		burning -= delta
		_burn_tick -= delta
		if _burn_tick <= 0.0:
			_burn_tick = 0.5
			take_damage(2.5, center(), false, false)
	stunned = maxf(0.0, stunned - delta)
	frozen = maxf(0.0, frozen - delta)
	var lab: Array = StatusFx.label(burning, frozen, stunned)
	_status.text = lab[0]
	_status.modulate = lab[1]
	_sfx.update(delta, burning, frozen, stunned, center())
	var f := _flash > 0.0
	_flash = maxf(0.0, _flash - delta)
	for m in _mats:
		var is_eye: bool = m.albedo_color == EYE or m.albedo_color == Color(1.0, 0.5, 0.1)
		m.emission_enabled = f or burning > 0.0 or is_eye or _windup_t > 0.0
		if f:
			m.emission = Color(1, 0.9, 0.7)
			m.emission_energy_multiplier = 0.8
		elif _windup_t > 0.0 and not is_eye:
			m.emission = Color(1.0, 0.2, 0.1)
			m.emission_energy_multiplier = 0.4 + absf(sin(_t * 25.0)) * 0.6
		elif burning > 0.0 and not is_eye:
			m.emission = Color(1.0, 0.4, 0.05)
			m.emission_energy_multiplier = 0.6 + 0.5 * absf(sin(_t * 9.0))
		elif is_eye:
			m.emission = m.albedo_color
			m.emission_energy_multiplier = 2.5
	var cam := get_viewport().get_camera_3d()
	if cam:
		var frac := hp / max_hp
		_bar_fill.scale.x = maxf(0.001, frac)
		_bar_fill.position.x = -(1.0 - frac) * 0.75
		var p := cam.global_position
		p.y = _bar.global_position.y
		if p.distance_to(_bar.global_position) > 0.1:
			_bar.look_at(p, Vector3.UP, true)
	if kind == "drone":
		for c in _visual.get_children():
			if c.position.y > 0.4:
				c.rotation.y += delta * 30.0


func _sees_player() -> bool:
	if player == null:
		return false
	var d := global_position.distance_to(player.global_position)
	if d > 48.0:
		return false
	var q := PhysicsRayQueryParameters3D.create(center(), player.global_position + Vector3(0, 1.0, 0))
	q.exclude = [get_rid()]
	var r := get_world_3d().direct_space_state.intersect_ray(q)
	return not r.is_empty() and r["collider"].is_in_group("player")


func _physics_process(delta: float) -> void:
	if not alive or player == null:
		return
	_think_t -= delta
	if _think_t <= 0.0:
		_think_t = 0.25
		if _sees_player():
			alert = true
			_alert_t = 6.0
	if alert:
		_alert_t -= delta
		if _alert_t <= 0.0:
			alert = false
	if stunned > 0.0:
		velocity = Vector3(0, velocity.y - 20.0 * delta, 0)
		move_and_slide()
		return
	var slow_mult := 0.35 if slowed > 0.0 else 1.0
	match kind:
		"soldier": _soldier_step(delta, slow_mult)
		"drone": _drone_step(delta, slow_mult)
		"brute": _brute_step(delta, slow_mult)


func _face(dir: Vector3, delta: float, rate := 8.0) -> void:
	if dir.length() < 0.01:
		return
	var want := atan2(-dir.x, -dir.z)
	_visual.rotation.y = lerp_angle(_visual.rotation.y, want, minf(1.0, delta * rate))


func _to_player() -> Vector3:
	var v := player.global_position - global_position
	v.y = 0.0
	return v


func _ground_move(delta: float, dir: Vector3, spd: float) -> void:
	if is_on_floor():
		velocity.y = -0.5
	else:
		velocity.y -= GRAVITY * delta
	var target := dir * spd
	velocity.x = lerpf(velocity.x, target.x, minf(1.0, delta * 6.0))
	velocity.z = lerpf(velocity.z, target.z, minf(1.0, delta * 6.0))
	move_and_slide()
	if is_on_wall() and dir.length() > 0.1:
		_strafe = -_strafe


func _shoot(dmg: float, spd: float, spread := 0.05) -> void:
	var from := center() + (-_visual.global_transform.basis.z) * 1.1
	var aim := player.global_position + Vector3(0, 1.0, 0)
	var dir := (aim - from).normalized()
	dir = dir.rotated(Vector3.UP, randf_range(-spread, spread))
	var shot: Area3D = load("res://scripts/turret_shot.gd").new()
	shot.damage = dmg
	shot.speed = spd
	get_parent().add_child(shot)
	shot.launch(from, dir, get_rid())
	Fx.muzzle(from, dir, Color(1.0, 0.35, 0.15), 0.5)
	Fx.sound("rifle", from, -8.0, 0.1, 10.0)


func _soldier_step(delta: float, sm: float) -> void:
	var to := _to_player()
	var d := to.length()
	var dir := Vector3.ZERO
	if alert:
		_face(to, delta)
		var fwd := to.normalized()
		var side := fwd.cross(Vector3.UP) * _strafe
		if d > 18.0:
			dir = fwd
		elif d < 8.0:
			dir = -fwd * 0.8 + side * 0.5
		else:
			dir = side * 0.7
			if fmod(_t, 3.0) < 0.6:
				dir = Vector3.ZERO
		_fire_t -= delta
		if _fire_t <= 0.0 and d < 40.0 and _sees_player():
			_shoot(7.0, 26.0)
			_burst += 1
			_fire_t = 0.14 if _burst < 3 else 1.9
			if _burst >= 3:
				_burst = 0
	_ground_move(delta, dir, speed * sm)


func _drone_step(delta: float, sm: float) -> void:
	var to3 := player.global_position + Vector3(0, 1.0, 0) - global_position
	var to := _to_player()
	var d := to.length()
	velocity.y = 0.0
	if not alert:
		var hover := Vector3(0, _hover_h - global_position.y, 0)
		velocity = velocity.lerp(hover.limit_length(2.0), minf(1.0, delta * 2.0))
		move_and_slide()
		return
	_dive_cd -= delta
	if _dive_t > 0.0:
		_dive_t -= delta
		velocity = velocity.lerp(to3.normalized() * 22.0 * sm, minf(1.0, delta * 6.0))
		_face(to, delta, 12.0)
		if to3.length() < 1.6 and not _ram_hit:
			_ram_hit = true
			player.combat.take_damage(18.0)
			Fx.sparks(player.global_position + Vector3(0, 1.0, 0), Vector3.UP, Color(0.6, 0.85, 1.0), 20, 8.0, 0.4, 0.14, 180.0, -6.0)
			_dive_t = 0.0
		move_and_slide()
		return
	# Tourne autour du joueur à bonne hauteur
	var fwd := to.normalized()
	var side := fwd.cross(Vector3.UP) * _strafe
	var want_h := player.global_position.y + _hover_h
	var dir := side * 1.0 + fwd * clampf((d - 11.0) * 0.15, -1.0, 1.0)
	dir.y = clampf((want_h - global_position.y) * 0.5, -1.0, 1.0)
	velocity = velocity.lerp(dir.normalized() * speed * sm, minf(1.0, delta * 3.0))
	_face(to, delta, 6.0)
	_fire_t -= delta
	if _fire_t <= 0.0 and _sees_player():
		_shoot(6.0, 24.0, 0.08)
		_fire_t = 2.4
	if _dive_cd <= 0.0 and d < 25.0 and _sees_player():
		_dive_cd = 5.5
		_dive_t = 1.1
		_ram_hit = false
		Fx.sparks(global_position, -to3.normalized(), Color(0.6, 0.85, 1.0), 16, 8.0, 0.4, 0.14, 40.0, 0.0)
	move_and_slide()


func _brute_step(delta: float, sm: float) -> void:
	var to := _to_player()
	var d := to.length()
	var dir := Vector3.ZERO
	var spd := speed
	if _windup_t > 0.0:
		_windup_t -= delta
		_face(to, delta, 10.0)
		if _windup_t <= 0.0:
			_charge_t = 1.1
			_ram_hit = false
			Fx.ring(global_position + Vector3(0, 0.2, 0), 3.0, Color(1.0, 0.3, 0.1, 0.8), 0.3, Vector3.UP, 0.25)
			Fx.shake(0.2)
	elif _charge_t > 0.0:
		_charge_t -= delta
		dir = -_visual.global_transform.basis.z
		spd = 15.0
		if d < 2.8 and not _ram_hit:
			_ram_hit = true
			player.combat.take_damage(25.0)
			Fx.explosion(player.global_position + Vector3(0, 1.0, 0), 2.5, Color(1.0, 0.4, 0.15), 0.8)
			_charge_t = 0.0
		_dust_step(delta)
	elif alert:
		_face(to, delta, 5.0)
		_swing_t -= delta
		if d < 3.2:
			if _swing_t <= 0.0:
				_swing_t = 1.6
				player.combat.take_damage(18.0)
				Fx.ring(player.global_position + Vector3(0, 1.0, 0), 2.5, Color(1.0, 0.4, 0.15, 0.8), 0.25, to.normalized(), 0.3)
				Fx.shake(0.35)
		else:
			dir = to.normalized()
			if d < 16.0 and d > 6.0 and fmod(_t, 6.0) < 0.1 and _sees_player():
				_windup_t = 0.8
	_ground_move(delta, dir, spd * sm)


var _dust_t := 0.0
func _dust_step(delta: float) -> void:
	_dust_t -= delta
	if _dust_t <= 0.0 and is_on_floor():
		_dust_t = 0.07
		Fx.sparks(global_position + Vector3(0, 0.1, 0), Vector3.UP, Color(0.7, 0.6, 0.5), 5, 3.0, 0.6, 0.4, 90.0, -2.0)
