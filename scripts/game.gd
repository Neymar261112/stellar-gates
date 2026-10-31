extends Node3D
## Racine : charge une carte, gère le passage par l'Arche (fondu, nouvelle carte, replacement du joueur).

signal world_changed(world: Node3D)

var world: Node3D
var _fade: ColorRect
var _switching := false

@onready var player: CharacterBody3D = $Player
@onready var env: WorldEnvironment = $WorldEnvironment
@onready var sun: DirectionalLight3D = $Sun


func _ready() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 10
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(layer)
	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 0)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_fade)
	_load_world("elyra", false)


func _load_world(id: String, arriving: bool) -> void:
	if world:
		world.queue_free()
		await world.tree_exited
	world = load("res://scripts/world.gd").new()
	world.name = "World"
	world.setup(Maps.by_id(id))
	add_child(world)
	move_child(world, 0)
	world.arche_entered.connect(_on_arche)
	_apply_sky(world.def["sky"])
	if arriving:
		player.set_world(world, world.arrival_position(), world.def["arche"]["facing"])
	else:
		player.set_world(world, world.start_position())
	world_changed.emit(world)
	if arriving:
		world.message.emit("Bienvenue sur %s" % world.def["name"], 3.0)


func _apply_sky(sky: Dictionary) -> void:
	var e: Environment = env.environment
	var mat: ProceduralSkyMaterial = e.sky.sky_material
	mat.sky_top_color = sky["top"]
	mat.sky_horizon_color = sky["horizon"]
	mat.ground_horizon_color = sky["ground"]
	mat.ground_bottom_color = sky["ground"].darkened(0.6)
	e.fog_light_color = sky["horizon"]
	e.fog_density = sky["fog"]
	sun.light_color = sky["sun"]
	sun.light_energy = sky["energy"]


func _on_arche(to_id: String) -> void:
	if _switching:
		return
	_switching = true
	player.set_physics_process(false)
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 1.0, 0.6)
	await tw.finished
	await _load_world(to_id, true)
	await get_tree().process_frame
	var tw2 := create_tween()
	tw2.tween_property(_fade, "color:a", 0.0, 0.8)
	player.set_physics_process(true)
	_switching = false
