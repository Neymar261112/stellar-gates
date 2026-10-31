extends Area3D
## Projectile lent et lumineux tiré par une tourelle d'entraînement. Touche le joueur : 12 de dégâts.

var dir := Vector3.ZERO
var speed := 20.0
var life := 3.0
var damage := 12.0
var arc_gravity := 0.0
var on_impact: Callable
var grenade := false           # la grenade Meshy (« Ember Core ») au lieu de la boule de feu, repeinte par le preset
var visual: Node3D             # modèle de la grenade lancée (donné par combat.gd)
var _spin: Node3D


func launch(from: Vector3, d: Vector3, shooter: RID) -> void:
	global_position = from
	dir = d
	var cs := CollisionShape3D.new()
	var sh := SphereShape3D.new()
	sh.radius = 0.3
	cs.shape = sh
	add_child(cs)
	if grenade and visual:
		_spin = visual
		add_child(visual)
	else:
		var mi := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.22
		sm.height = 0.44
		mi.mesh = sm
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(1.0, 0.5, 0.15)
		m.emission_enabled = true
		m.emission = Color(1.0, 0.45, 0.1)
		m.emission_energy_multiplier = 4.0
		mi.material_override = m
		add_child(mi)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.5, 0.15)
	light.light_energy = 1.2
	light.omni_range = 4.0
	add_child(light)
	body_entered.connect(_on_body)


func _physics_process(delta: float) -> void:
	if _spin:
		_spin.rotate(Vector3(1, 0.3, 0).normalized(), delta * 9.0)
	if arc_gravity > 0.0:
		dir = (dir * speed + Vector3(0, -arc_gravity * delta, 0)) / speed
		speed = maxf(speed, 1.0)
	global_position += dir * speed * delta
	life -= delta
	if life <= 0.0 or (arc_gravity > 0.0 and global_position.y < -8.0):
		queue_free()


func _on_body(body: Node3D) -> void:
	if (body is TrainingTarget or body is Enemy) and not on_impact:
		return
	if body.is_in_group("player"):
		if damage <= 0.0:
			return
		body.combat.take_damage(damage, dir)
	if on_impact:
		on_impact.call(global_position)
	if not grenade:
		# Petite déflagration d'énergie : gerbe, boule de feu brève, fumée, son
		Fx.streaks(global_position, -dir, Color(1.0, 0.6, 0.25), 16, 12.0, 0.35, 0.3, 80.0, -10.0)
		Fx.fireball(global_position, 0.6, 5, 0.45)
		Fx.smoke(global_position, 3, 0.8, 1.2, Color(0.3, 0.28, 0.27, 0.5), 0.8, 0.1, 1.5)
		Fx.flash(global_position, Color(1.0, 0.5, 0.15), 3.0, 5.0, 0.2)
		Fx.sound("blast_small", global_position, -10.0, 0.15, 8.0)
	queue_free()
