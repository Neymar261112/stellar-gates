extends Node3D
## Vagues d'entraînement : quand le joueur entre dans la zone, des ennemis apparaissent par vagues.

signal wave_changed(wave: int, total: int, remaining: int)
signal arena_cleared

var def: Dictionary
var world: Node3D
var player: Node3D
var wave := 0
var active := false
var _enemies: Array = []
var _next_t := 0.0
var _done := false
var _cooldown := 0.0
var _console: Node3D


func setup(arena_def: Dictionary, w: Node3D, p: Node3D) -> void:
	def = arena_def
	world = w
	player = p


func _ready() -> void:
	# Borne d'entraînement : un anneau rouge au sol et une colonne lumineuse
	_console = Node3D.new()
	_console.position = world.cell_center(def["console"])
	add_child(_console)
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 1.6
	tm.outer_radius = 1.9
	ring.mesh = tm
	ring.position.y = 0.08
	var rm := StandardMaterial3D.new()
	rm.albedo_color = Color(1.0, 0.3, 0.2)
	rm.emission_enabled = true
	rm.emission = Color(1.0, 0.25, 0.15)
	rm.emission_energy_multiplier = 1.5
	ring.material_override = rm
	_console.add_child(ring)
	var col := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.25
	cm.bottom_radius = 0.35
	cm.height = 1.6
	col.mesh = cm
	col.position.y = 0.8
	col.material_override = rm
	_console.add_child(col)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.3, 0.2)
	light.light_energy = 1.5
	light.omni_range = 7.0
	light.position.y = 1.5
	_console.add_child(light)


func _near_console() -> bool:
	if player == null:
		return false
	var p := player.global_position
	p.y = _console.global_position.y
	return p.distance_to(_console.global_position) < 2.2


func _process(delta: float) -> void:
	if _cooldown > 0.0:
		_cooldown -= delta
		if _cooldown <= 0.0:
			_done = false
		return
	if _console:
		_console.rotation.y += delta * (3.0 if active else 0.6)
	if not active:
		if _near_console() and not _done:
			start()
		return
	_enemies = _enemies.filter(func(e): return is_instance_valid(e) and e.alive)
	if _enemies.is_empty():
		if _next_t <= 0.0:
			if wave >= def["waves"].size():
				active = false
				_done = true
				_cooldown = 25.0
				arena_cleared.emit()
				world.message.emit("Zone sécurisée ! Nouvelles vagues dans 25 s.", 4.0)
				for pl in get_tree().get_nodes_in_group("player"):
					pl.play_victory()
				return
			_next_t = 3.5
			world.message.emit("Vague %d dans 3 s…" % (wave + 1), 2.5)
		_next_t -= delta
		if _next_t <= 0.0:
			_spawn_wave()


func start() -> void:
	active = true
	wave = 0
	_next_t = 1.5
	world.message.emit("Entraînement au combat : %d vagues. Tiens bon !" % def["waves"].size(), 3.0)


func _spawn_wave() -> void:
	var kinds: Array = def["waves"][wave]
	wave += 1
	var spawns: Array = def["spawns"].duplicate()
	spawns.shuffle()
	for i in kinds.size():
		var cell: Vector2i = spawns[i % spawns.size()]
		var e := Enemy.new()
		e.name = "Ennemi_%s_%d_%d" % [kinds[i], wave, i]
		var pos: Vector3 = world.cell_center(cell) + Vector3(randf_range(-0.8, 0.8), 0.3, randf_range(-0.8, 0.8))
		if kinds[i] == "drone":
			pos.y += 7.0
		e.setup(kinds[i], pos)
		e.player = player
		e.died.connect(_on_enemy_died)
		world.add_child(e)
		_enemies.append(e)
		Fx.ring(pos + Vector3(0, 0.2, 0), 2.5, Color(1.0, 0.3, 0.2, 0.9), 0.5, Vector3.UP, 0.2)
		Fx.sparks(pos + Vector3(0, 1.0, 0), Vector3.UP, Color(1.0, 0.3, 0.2), 20, 6.0, 0.6, 0.2, 180.0, -2.0)
	world.message.emit("Vague %d / %d" % [wave, def["waves"].size()], 2.0)
	wave_changed.emit(wave, def["waves"].size(), _enemies.size())


func _on_enemy_died(_e: Enemy) -> void:
	var remaining := 0
	for e in _enemies:
		if is_instance_valid(e) and e.alive:
			remaining += 1
	wave_changed.emit(wave, def["waves"].size(), remaining)
	Fx.shake(0.2)
