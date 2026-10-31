extends Node
## Captures de la nouvelle interface de la Forge, un écran par onglet (xvfb-run, opengl3).
var f: Node3D

func _ready() -> void:
	f = load("res://scenes/atelier.tscn").instantiate()
	add_child(f)
	await get_tree().create_timer(14.0).timeout
	for t in [1, 0, 2, 3]:
		f._set_tab(t)
		if t == 1:
			f.goto(1, "piece_helmet")
		await get_tree().create_timer(4.0 if t == 3 else 1.5).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://out/ui_%d.png" % t)
	f.goto(1, "color")
	f._nav(Vector2i(1, 0))
	f._nav(Vector2i(1, 0))
	await get_tree().create_timer(2.5).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://out/ui_color.png")
	get_tree().quit()
