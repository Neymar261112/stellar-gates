extends Node3D
## Essai de la tourelle Hunyuan3D (assets/essais/tourelle_hunyuan) sur un plateau tournant, dans le décor de
## la Forge. Touches 1-6 (ou boutons) : texture d'origine puis 5 jeux de couleurs ; Espace : pause,
## +/- : vitesse. Lancée avec `-- capture` : une image par mode dans videos/essai_tourelle/ puis quitte.

const DECOR := preload("res://scenes/forge/forge_decor.tscn")
const TURRET := preload("res://assets/essais/tourelle_hunyuan/tourelle_hunyuan.glb")
const SHADER := preload("res://scenes/essais/tourelle_repeint.gdshader")
const DECK := 0.25        # plateau du socle de la Forge

# nom, principale (clair), secondaire (sombre), accent (saturé), lueur de l'accent
const MODES := [
	["Texture d'origine", null, null, null, 0.0],
	["Aegis", Color(0.92, 0.92, 0.9), Color(0.07, 0.07, 0.08), Color(0.95, 0.45, 0.1), 0.0],
	["Braise", Color(0.55, 0.06, 0.05), Color(0.05, 0.04, 0.04), Color(0.95, 0.72, 0.25), 0.0],
	["Marine", Color(0.07, 0.12, 0.3), Color(0.88, 0.87, 0.82), Color(0.9, 0.7, 0.28), 0.0],
	["Commando", Color(0.3, 0.33, 0.17), Color(0.68, 0.6, 0.44), Color(0.04, 0.04, 0.04), 0.0],
	["Ombre", Color(0.06, 0.06, 0.07), Color(0.2, 0.21, 0.23), Color(0.1, 0.9, 1.0), 3.0],
]

var speed := 0.35          # rad/s
var paused := false
var mode := 0
var _table: Node3D
var _mat: ShaderMaterial
var _label: Label
var _slider: HSlider


func _ready() -> void:
	add_child(DECOR.instantiate())
	_table = Node3D.new()
	_table.position.y = DECK
	add_child(_table)
	var disc := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 1.2
	cyl.bottom_radius = 1.2
	cyl.height = 0.03
	cyl.radial_segments = 64
	disc.mesh = cyl
	disc.position.y = 0.015
	var dm := StandardMaterial3D.new()
	dm.albedo_color = Color(0.12, 0.12, 0.13)
	dm.metallic = 0.7
	dm.roughness = 0.4
	disc.material_override = dm
	_table.add_child(disc)
	var turret := TURRET.instantiate()
	turret.position.y = 0.03
	_table.add_child(turret)
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	for mi in turret.find_children("*", "MeshInstance3D", true, false):
		var src: BaseMaterial3D = mi.mesh.surface_get_material(0)
		_mat.set_shader_parameter("albedo_tex", src.albedo_texture)
		mi.material_override = _mat
	var fill := OmniLight3D.new()
	fill.position = Vector3(-1.6, 2.2, -2.4)
	fill.light_energy = 1.2
	fill.omni_range = 7.0
	fill.light_color = Color(1.0, 0.92, 0.82)
	add_child(fill)
	var cam := Camera3D.new()
	cam.fov = 40
	add_child(cam)
	cam.look_at_from_position(Vector3(0, 1.35, -2.9), Vector3(0, 0.78, 0), Vector3.UP)
	cam.make_current()
	_ui()
	set_mode(0)
	if "capture" in OS.get_cmdline_user_args():
		_capture()


func _ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var box := VBoxContainer.new()
	box.position = Vector2(16, 16)
	layer.add_child(box)
	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 22)
	box.add_child(_label)
	var row := HBoxContainer.new()
	box.add_child(row)
	for i in MODES.size():
		var b := Button.new()
		b.text = "%d  %s" % [i + 1, MODES[i][0]]
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(set_mode.bind(i))
		row.add_child(b)
	var srow := HBoxContainer.new()
	box.add_child(srow)
	var sl := Label.new()
	sl.text = "Rotation (Espace : pause, +/- : vitesse)"
	srow.add_child(sl)
	_slider = HSlider.new()
	_slider.min_value = 0.0
	_slider.max_value = 1.5
	_slider.step = 0.05
	_slider.value = speed
	_slider.custom_minimum_size = Vector2(220, 0)
	_slider.focus_mode = Control.FOCUS_NONE
	_slider.value_changed.connect(func(v: float) -> void: speed = v)
	srow.add_child(_slider)


func set_mode(i: int) -> void:
	mode = i
	var m: Array = MODES[i]
	_mat.set_shader_parameter("repaint", m[1] != null)
	if m[1] != null:
		_mat.set_shader_parameter("primary", m[1])
		_mat.set_shader_parameter("secondary", m[2])
		_mat.set_shader_parameter("accent", m[3])
		_mat.set_shader_parameter("accent_glow", m[4])
	_label.text = "%d  %s" % [i + 1, m[0]]


func _unhandled_input(e: InputEvent) -> void:
	if not (e is InputEventKey and e.pressed and not e.echo):
		return
	var k: int = e.keycode
	if k >= KEY_1 and k <= KEY_6:
		set_mode(k - KEY_1)
	elif k >= KEY_KP_1 and k <= KEY_KP_6:
		set_mode(k - KEY_KP_1)
	elif k == KEY_SPACE:
		paused = not paused
	elif k == KEY_PLUS or k == KEY_KP_ADD or k == KEY_EQUAL:
		_slider.value += 0.1
	elif k == KEY_MINUS or k == KEY_KP_SUBTRACT:
		_slider.value -= 0.1


func _process(delta: float) -> void:
	if not paused:
		_table.rotate_y(speed * delta)


func _capture() -> void:
	paused = true
	_table.rotation.y = 2.4     # trois quarts, canon vers la gauche
	var dir := ProjectSettings.globalize_path("res://videos/essai_tourelle")
	DirAccess.make_dir_recursive_absolute(dir)
	for i in MODES.size():
		set_mode(i)
		for k in 8:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var name: String = MODES[i][0].to_lower().replace("'", "_").replace(" ", "_")
		get_viewport().get_texture().get_image().save_png("%s/%d_%s.png" % [dir, i + 1, name])
	print("test_tourelle ok")
	get_tree().quit()
