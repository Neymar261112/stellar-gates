extends StaticBody3D
class_name TrainingTarget
## Cible d'entraînement : mannequin au sol, drone en vol ou tourelle qui riposte.
## Prend des dégâts (take_damage), affiche sa vie, se détruit puis réapparaît.

signal destroyed(target: TrainingTarget)

var kind := "ground"            # ground | drone | turret
var max_hp := 120.0
var hp := 120.0
var alive := true
var respawn_after := 6.0
var base_pos := Vector3.ZERO
var player: Node3D
var _t := 0.0
var _flash := 0.0
var _respawn_t := 0.0
var _fire_cd := 2.0
var _visual: Node3D
var _bar: Node3D
var _bar_fill: MeshInstance3D
var _mats: Array = []
var _barrel: Node3D
var burning := 0.0            # amorce « brûlure » (s restantes)
var slowed := 0.0             # ralenti par la Résonance
var frozen := 0.0             # gel (grenade de givre), compte aussi comme étourdi
var _sfx: StatusFx
var stunned := 0.0            # étourdi par l'Éclat solaire (compte comme amorcé)
var _burn_tick := 0.0
var _status: Label3D

const GREY := Color(0.42, 0.44, 0.48)
const CORE := Color(1.0, 0.45, 0.12)


func setup(k: String, pos: Vector3) -> void:
	kind = k
	base_pos = pos
	position = pos
	match kind:
		"drone":
			max_hp = 80.0
			respawn_after = 7.0
		"turret":
			max_hp = 200.0
			respawn_after = 9.0
	hp = max_hp


func _ready() -> void:
	add_to_group("targets")
	_t = randf() * TAU
	_visual = Node3D.new()
	add_child(_visual)
	match kind:
		"drone":
			_mesh(_visual, _sphere(0.55), Vector3(0, 0, 0), GREY)
			var ring := TorusMesh.new()
			ring.inner_radius = 0.7
			ring.outer_radius = 0.85
			_mesh(_visual, ring, Vector3(0, 0, 0), GREY.darkened(0.3))
			_mesh(_visual, _sphere(0.22), Vector3(0, 0, -0.5), CORE, true)
			_shape(SphereShape3D.new(), Vector3.ZERO, 0.8)
		"turret":
			_mesh(_visual, _cyl(0.9, 0.9), Vector3(0, 0.45, 0), GREY.darkened(0.2))
			_barrel = Node3D.new()
			_barrel.position = Vector3(0, 1.1, 0)
			_visual.add_child(_barrel)
			_mesh(_barrel, _sphere(0.45), Vector3.ZERO, GREY)
			_mesh(_barrel, _box(Vector3(0.18, 0.18, 1.1)), Vector3(0, 0, -0.7), GREY.darkened(0.4))
			_mesh(_barrel, _sphere(0.14), Vector3(0, 0, -1.25), CORE, true)
			var sh := CylinderShape3D.new()
			sh.radius = 0.9
			sh.height = 1.7
			_shape(sh, Vector3(0, 0.85, 0))
		_:
			_mesh(_visual, _box(Vector3(0.9, 1.4, 0.55)), Vector3(0, 1.2, 0), GREY)
			_mesh(_visual, _sphere(0.3), Vector3(0, 2.2, 0), GREY.lightened(0.1))
			_mesh(_visual, _box(Vector3(0.3, 0.3, 0.1)), Vector3(0, 1.4, -0.3), CORE, true)
			_mesh(_visual, _box(Vector3(1.2, 0.2, 0.8)), Vector3(0, 0.1, 0), GREY.darkened(0.4))
			var bs := BoxShape3D.new()
			bs.size = Vector3(1.0, 2.5, 0.8)
			_shape(bs, Vector3(0, 1.25, 0))
	_build_bar()
	_status = Label3D.new()
	_status.text = ""
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
	_sfx.setup(self, _visual, 1.4 if kind == "turret" else 1.0)


func _sphere(r: float) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = r
	m.height = r * 2.0
	m.radial_segments = 16
	m.rings = 8
	return m


func _box(size: Vector3) -> BoxMesh:
	var m := BoxMesh.new()
	m.size = size
	return m


func _cyl(r: float, h: float) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = r * 0.8
	m.bottom_radius = r
	m.height = h
	m.radial_segments = 12
	return m


func _mesh(parent: Node3D, mesh: Mesh, pos: Vector3, color: Color, glow := false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.55
	m.metallic = 0.6
	if glow:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = 2.5
	mi.material_override = m
	_mats.append(m)
	parent.add_child(mi)
	return mi


func _shape(shape: Shape3D, pos: Vector3, radius := 0.0) -> void:
	if shape is SphereShape3D:
		shape.radius = radius
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.position = pos
	add_child(cs)


func _build_bar() -> void:
	_bar = Node3D.new()
	_bar.position.y = 2.9 if kind == "ground" else (1.2 if kind == "drone" else 2.3)
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


func _flat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = c
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.no_depth_test = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


## Dégâts reçus. pos : point d'impact (pour le chiffre flottant). kind_txt : "" tir, "melee", "burn", "combo", "power"
func take_damage(amount: float, pos: Vector3, melee := false, show_number := true) -> void:
	if not alive:
		return
	hp = maxf(0.0, hp - amount)
	_flash = 0.07
	if show_number:
		_spawn_number(amount, pos, melee)
	if hp <= 0.0:
		_die()


## Amorce : la cible brûle (dégâts sur la durée) et peut être détonée par un détonateur.
func prime(seconds: float) -> void:
	if not alive:
		return
	burning = seconds
	_status.text = "BRÛLÉ"


func is_primed() -> bool:
	return alive and (burning > 0.0 or stunned > 0.0)


## Amorce : la cible est étourdie (ne bouge ni ne tire) et peut être détonée.
func stun(seconds: float) -> void:
	if not alive:
		return
	stunned = maxf(stunned, seconds)
	_status.text = "ÉTOURDI"


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


func center() -> Vector3:
	match kind:
		"drone": return global_position
		"turret": return global_position + Vector3(0, 1.1, 0)
		_: return global_position + Vector3(0, 1.3, 0)


func _spawn_number(amount: float, pos: Vector3, melee: bool) -> void:
	var l := Label3D.new()
	l.text = str(int(round(amount)))
	l.font_size = 64 if melee else 44
	l.pixel_size = 0.005
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.outline_size = 10
	l.modulate = Color(1.0, 0.93, 0.6) if not melee else Color.WHITE
	get_parent().add_child(l)
	l.global_position = pos + Vector3(randf_range(-0.3, 0.3), 0.3, 0)
	l.scale = Vector3.ONE * 0.3
	var tw := l.create_tween()
	tw.set_parallel(true)
	tw.tween_property(l, "scale", Vector3.ONE * (1.6 if melee else 1.1), 0.12).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tw.tween_property(l, "position:y", l.position.y + 1.6, 0.8)
	tw.tween_property(l, "modulate:a", 0.0, 0.8).set_delay(0.3)
	tw.chain().tween_callback(l.queue_free)


func _die() -> void:
	alive = false
	frozen = 0.0
	_sfx.update(0.0, 0.0, 0.0, 0.0, center())
	burning = 0.0
	slowed = 0.0
	stunned = 0.0
	_status.text = ""
	_respawn_t = respawn_after
	collision_layer = 0
	destroyed.emit(self)
	var col := Color(1.0, 0.55, 0.2) if kind != "drone" else Color(0.6, 0.85, 1.0)
	Fx.explosion(center(), 3.0 if kind != "turret" else 4.5, col, 1.0)
	Fx.debris(center(), GREY, 12, 8.0)
	Fx.sparks(center(), Vector3.UP, Color(0.3, 0.3, 0.32), 18, 3.0, 1.4, 0.6, 180.0, 1.5)   # fumée
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(_visual, "scale", Vector3(0.05, 0.05, 0.05), 0.35).set_ease(Tween.EASE_IN)
	tw.tween_property(_visual, "rotation:x", -1.2, 0.35)
	tw.chain().tween_callback(func(): _visual.visible = false; _bar.visible = false)


func _respawn() -> void:
	alive = true
	hp = max_hp
	collision_layer = 1
	_visual.visible = true
	_bar.visible = true
	_visual.rotation = Vector3.ZERO
	_visual.scale = Vector3(0.05, 0.05, 0.05)
	var tw := create_tween()
	tw.tween_property(_visual, "scale", Vector3.ONE, 0.4).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)


func _process(delta: float) -> void:
	_t += delta
	if not alive:
		_respawn_t -= delta
		if _respawn_t <= 0.0:
			_respawn()
		return
	# Statuts
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
	# Mouvement propre
	match kind:
		"drone":
			if slowed > 0.0 or stunned > 0.0:
				_visual.rotation.y += delta * 0.1
			else:
				position = base_pos + Vector3(sin(_t * 0.7) * 1.5, sin(_t * 1.6) * 0.4, cos(_t * 0.5) * 1.0)
				_visual.rotation.y += delta * 0.8
		"turret":
			if player and _barrel:
				var to := player.global_position + Vector3(0, 1.0, 0) - _barrel.global_position
				if to.length() > 0.5:
					_barrel.look_at(player.global_position + Vector3(0, 1.0, 0), Vector3.UP)
	# Flash de dégâts
	var f := _flash > 0.0
	_flash = maxf(0.0, _flash - delta)
	for m in _mats:
		m.emission_enabled = f or burning > 0.0 or m.albedo_color == CORE
		if f:
			m.emission = Color(1, 0.9, 0.7)
			m.emission_energy_multiplier = 0.7
		elif burning > 0.0 and m.albedo_color != CORE:
			m.emission = Color(1.0, 0.4, 0.05)
			m.emission_energy_multiplier = 0.6 + 0.5 * absf(sin(_t * 9.0))
		elif m.albedo_color == CORE:
			m.emission = CORE
			m.emission_energy_multiplier = 2.5
	# Barre de vie face à la caméra
	var cam := get_viewport().get_camera_3d()
	if cam:
		var frac := hp / max_hp
		_bar_fill.scale.x = maxf(0.001, frac)
		_bar_fill.position.x = -(1.0 - frac) * 0.75
		var p := cam.global_position
		p.y = _bar.global_position.y
		if p.distance_to(_bar.global_position) > 0.1:
			_bar.look_at(p, Vector3.UP, true)


func _physics_process(delta: float) -> void:
	if kind != "turret" or not alive or player == null or slowed > 0.0 or stunned > 0.0:
		return
	_fire_cd -= delta
	if _fire_cd > 0.0:
		return
	var aim := player.global_position + Vector3(0, 1.0, 0)
	var from := _barrel.global_position
	if from.distance_to(aim) > 38.0:
		return
	var q := PhysicsRayQueryParameters3D.create(from, aim)
	q.exclude = [get_rid()]
	var r := get_world_3d().direct_space_state.intersect_ray(q)
	if r.is_empty() or not r["collider"].is_in_group("player"):
		return
	_fire_cd = 1.7
	var dir := (aim - from).normalized()
	Fx.muzzle(from + dir * 1.2, dir, Color(1.0, 0.5, 0.15), 0.8)
	Fx.sound("rifle", from, -8.0, 0.1, 10.0)
	var shot: Area3D = load("res://scripts/turret_shot.gd").new()
	get_parent().add_child(shot)
	shot.launch(from + dir * 1.5, dir, get_rid())
