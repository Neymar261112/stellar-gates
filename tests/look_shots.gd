extends Node
## Captures des 4 ensembles du Ranger, de face et de dos (xvfb-run, opengl3).
var f: Node3D
var t := 0.0
var i := 0
var packs := ["ranger.default", "ranger.recup", "ranger.horizon", "ranger.originel"]
var presets := [3, 0, 1, 2]

func _ready() -> void:
	f = load("res://scenes/atelier.tscn").instantiate()
	add_child(f)

func _process(delta: float) -> void:
	t += delta
	if t < 1.0:
		return
	var k := int((t - 1.0) / 0.8)
	if k >= packs.size() * 2:
		get_tree().quit()
		return
	if k != i - 1 and k == i:
		var pk: String = packs[k / 2]
		Appearance.load_preset(presets[k / 2])
		Appearance.set_pack(pk)
		f._yaw = 0.0 if k % 2 == 0 else PI
		f._idle = 0.0
		f._want_focus = Vector3(0, 1.1, 0)
		f._want_dist = 3.2
		f._focus = f._want_focus
		f._dist = f._want_dist
		f._ui.visible = false
		i += 1
		await get_tree().create_timer(0.6).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://out/look_%d_%s.png" % [k, pk.substr(7)])
