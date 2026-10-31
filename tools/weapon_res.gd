extends Node
## Maillages des armes tenues en main : <id>_main.glb (sortie de tools/meshy_armes.py) -> assets/weapons/<id>.res,
## le maillage seul (sans matériau ni texture), comme rifle.res : le jeu le repeint avec les textures <id>_*.png.
## Lancer : WEAPON_GLB=<dossier des _main.glb> godot --headless --path . tools/weapon_res.tscn

const IDS := ["tacticien", "ivoire", "minuit", "repetiteur", "sentinelle", "silencieux", "titan"]


func _ready() -> void:
	var dir := OS.get_environment("WEAPON_GLB")
	for id in IDS:
		var doc := GLTFDocument.new()
		var state := GLTFState.new()
		if doc.append_from_file(dir.path_join(id + "_main.glb"), state) != OK:
			push_error("[armes] lecture impossible : " + id)
			continue
		var root := doc.generate_scene(state)
		var src: Mesh = null
		for n in root.find_children("*", "", true, false):
			if n is MeshInstance3D:
				src = n.mesh
			elif n is ImporterMeshInstance3D:
				src = n.mesh.get_mesh()
		var mesh := ArrayMesh.new()
		for s in src.get_surface_count():
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, src.surface_get_arrays(s))
		ResourceSaver.save(mesh, "res://assets/weapons/%s.res" % id)
		print("[armes] %s.res  aabb %s" % [id, mesh.get_aabb()])
		root.free()
	get_tree().quit()
