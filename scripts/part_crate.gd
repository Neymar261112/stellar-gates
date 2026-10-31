extends Area3D
## Caisse de ravitaillement : posée dans le monde. Étape 7 (décision de cyril) : elle lâche un BUTIN AU HASARD
## (diamant coloré, au moins Peu commun, Rare pour une caisse d'origine), révélé en fin de mission, et débloque
## toujours la pièce d'apparence du même pack (récompense d'exploration, à choisir ensuite à l'Atelier).

var slot := "propulseurs"
var tier := 1
var _t := 0.0
var _box: MeshInstance3D
var _taken := false


func setup(s: String, t: int, pos: Vector3) -> void:
	slot = s
	tier = t
	position = pos


func _ready() -> void:
	add_to_group("crates")
	var origin := tier >= 2
	var col := Color(0.95, 0.8, 0.4) if origin else Color(0.55, 0.62, 0.7)
	var cs := CollisionShape3D.new()
	var sh := CylinderShape3D.new()
	sh.radius = 1.4
	sh.height = 3.0
	cs.shape = sh
	cs.position.y = 1.2
	add_child(cs)
	_box = MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.9, 0.6, 0.9) if not origin else Vector3(1.0, 0.7, 1.0)
	_box.mesh = bm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.25, 0.26, 0.3) if not origin else Color(0.9, 0.85, 0.7)
	m.metallic = 0.7
	m.roughness = 0.45
	_box.material_override = m
	_box.position.y = 0.9
	add_child(_box)
	# Bandes lumineuses
	for y in [-0.2, 0.2]:
		var band := MeshInstance3D.new()
		var b := BoxMesh.new()
		b.size = Vector3(bm.size.x + 0.04, 0.06, bm.size.z + 0.04)
		band.mesh = b
		var bmat := StandardMaterial3D.new()
		bmat.albedo_color = col
		bmat.emission_enabled = true
		bmat.emission = col
		bmat.emission_energy_multiplier = 2.5 if origin else 1.2
		band.material_override = bmat
		band.position.y = y
		_box.add_child(band)
	var light := OmniLight3D.new()
	light.light_color = col
	light.light_energy = 2.5 if origin else 1.2
	light.omni_range = 9.0 if origin else 6.0
	light.position.y = 1.4
	add_child(light)
	var label := Label3D.new()
	label.text = "CAISSE D'ORIGINE" if origin else "CAISSE HORIZON"
	label.font_size = 44
	label.pixel_size = 0.006
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.outline_size = 10
	label.modulate = col
	label.position.y = 2.2
	add_child(label)
	body_entered.connect(_on_body)


func _part_name() -> String:
	if slot == "finition":
		return "Finition Originel" if tier == 1 else "Finition Éclipse"
	return Loadout.PARTS[slot][tier]["name"]


func _process(delta: float) -> void:
	if _taken:
		return
	_t += delta
	_box.rotation.y += delta * 0.8
	_box.position.y = 0.9 + sin(_t * 2.0) * 0.12


func _on_body(body: Node3D) -> void:
	if _taken or not body.is_in_group("player"):
		return
	_taken = true
	var gold := Color(1.0, 0.85, 0.4)
	Fx.explosion(global_position + Vector3(0, 0.9, 0), 2.5, gold)
	Fx.ring(global_position + Vector3(0, 0.2, 0), 4.0, gold, 0.5, Vector3.UP, 0.2)
	Fx.hitstop(0.15, 0.35)
	Fx.kick(5.0)
	var look := Appearance.unlock_from_crate(slot, tier)
	Expedition.crate_opened(get_parent(), global_position, tier)
	body.message.emit("Caisse ouverte : butin !%s" % [("\n" + look) if look != "" else ""], 2.5)
	visible = false
	set_deferred("monitoring", false)
