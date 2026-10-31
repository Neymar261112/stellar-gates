extends Node3D
class_name LootDrop
## Butin au sol : un diamant lumineux à la couleur de sa rareté, avec une colonne de lumière
## (plus haute pour les objets rares). Il jaillit de l'ennemi ou de la caisse, retombe, tourne,
## puis file vers le Solaris quand il passe à côté. Le détail de l'objet reste caché jusqu'à la fin de mission.

var item: Dictionary
var _t := 0.0
var _gem: MeshInstance3D
var _beam: MeshInstance3D
var _light: OmniLight3D
var _taken := false
var _landed := false
var _ground := 0.0
var _vel := Vector3.ZERO
var _player: Node3D
var _color := Color.WHITE

const MAGNET := 6.0
const PICK := 1.3


static func spawn(parent: Node, it: Dictionary, pos: Vector3) -> LootDrop:
	var d := LootDrop.new()
	d.item = it
	parent.add_child(d)
	d.global_position = pos
	return d


func _ready() -> void:
	add_to_group("loot_drops")
	var r := int(item.get("rarity", 0))
	_color = LootDB.rarity_color(r)
	_ground = _find_ground(global_position)
	_vel = Vector3(randf_range(-2.5, 2.5), 7.0 + r * 0.5, randf_range(-2.5, 2.5))
	_gem = MeshInstance3D.new()
	var sm := SphereMesh.new()       # 4 côtés et 2 anneaux : un diamant (octaèdre)
	sm.radial_segments = 4
	sm.rings = 2
	sm.radius = 0.22 + r * 0.025
	sm.height = (0.22 + r * 0.025) * 2.6
	_gem.mesh = sm
	var m := StandardMaterial3D.new()
	m.albedo_color = _color
	m.emission_enabled = true
	m.emission = _color
	m.emission_energy_multiplier = 2.5 + r * 0.6
	m.metallic = 0.4
	m.roughness = 0.2
	_gem.material_override = m
	_gem.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_gem)
	# Colonne de lumière : se voit de loin, haute pour l'épique et au-delà
	_beam = MeshInstance3D.new()
	var cm := CylinderMesh.new()
	var h := 2.0 + r * 1.6
	cm.top_radius = 0.02
	cm.bottom_radius = 0.09 + r * 0.02
	cm.height = h
	cm.radial_segments = 8
	cm.cap_top = false
	cm.cap_bottom = false
	_beam.mesh = cm
	var bm := StandardMaterial3D.new()
	bm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	bm.albedo_color = Color(_color.r, _color.g, _color.b, 0.35 + r * 0.06)
	bm.cull_mode = BaseMaterial3D.CULL_DISABLED
	_beam.material_override = bm
	_beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_beam.position.y = h * 0.5
	_beam.visible = false
	add_child(_beam)
	_light = OmniLight3D.new()
	_light.light_color = _color
	_light.light_energy = 1.2 + r * 0.4
	_light.omni_range = 3.0 + r * 0.8
	_light.position.y = 0.5
	add_child(_light)
	Fx.sparks(global_position, Vector3.UP, _color, 10 + r * 4, 5.0, 0.5, 0.08, 70.0)
	if r >= 4:
		Fx.flash(global_position, _color, 4.0, 8.0, 0.4)
		Fx.ring(global_position, 2.0, _color, 0.5, Vector3.UP, 0.15)
	Fx.sound("loot_drop", global_position, -4.0 + r, 0.04, 14.0)


func _find_ground(from: Vector3) -> float:
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(from + Vector3.UP * 0.5, from + Vector3.DOWN * 60.0)
	q.collision_mask = 1
	var hit := space.intersect_ray(q)
	return float(hit["position"].y) if not hit.is_empty() else from.y - 1.0


func _process(delta: float) -> void:
	if _taken:
		return
	_t += delta
	if not _landed:
		_vel.y -= 22.0 * delta
		global_position += _vel * delta
		if global_position.y <= _ground + 0.55 and _vel.y < 0.0:
			global_position.y = _ground + 0.55
			_landed = true
			_beam.visible = true
			_beam.position.y = (_beam.mesh as CylinderMesh).height * 0.5 - 0.55
			Fx.ring(Vector3(global_position.x, _ground + 0.05, global_position.z), 1.0, _color, 0.35, Vector3.UP, 0.08)
	else:
		_gem.position.y = sin(_t * 2.4) * 0.12
	_gem.rotation.y += delta * 2.2
	_light.light_energy = (1.2 + item.get("rarity", 0) * 0.4) * (0.85 + 0.15 * sin(_t * 5.0))
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player")
		return
	if _t < 0.6:
		return
	var target := _player.global_position + Vector3(0, 1.0, 0)
	var dist := global_position.distance_to(target)
	if dist < MAGNET:
		var spd := lerpf(18.0, 6.0, dist / MAGNET)
		global_position = global_position.move_toward(target, spd * delta)
		_beam.visible = false
	if dist < PICK:
		_pick()


func _pick() -> void:
	_taken = true
	var r := int(item.get("rarity", 0))
	Fx.sparks(global_position, Vector3.UP, _color, 14 + r * 3, 4.0, 0.4, 0.07)
	Fx.flash(global_position, _color, 2.0 + r, 4.0, 0.2)
	Fx.sound("loot_pick" if r < 5 else "loot_gold", global_position, -2.0, 0.05, 12.0)
	Expedition.collect(item)
	queue_free()
