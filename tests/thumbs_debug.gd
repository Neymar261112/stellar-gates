extends Node
var th: ForgeThumbs
func _ready() -> void:
	Appearance.persist = false
	Appearance.unlock_all()
	th = ForgeThumbs.new()
	add_child(th)
	var ps: Array = Appearance.presets["ranger"]
	for i in 5:
		th.preset(ps[i], "p%d" % i)
	await get_tree().create_timer(6.0).timeout
	print("queue left ", th._queue.size(), " cache ", th._cache.size())
	var i := 0
	for k in th._cache:
		th._cache[k].get_image().save_png("res://out/th_%d.png" % i)
		i += 1
	get_tree().quit()
