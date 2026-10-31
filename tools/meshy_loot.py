"""Butin 3D : modèles Meshy de cyril -> GLB légers pour Godot + vignettes rendues (fond transparent).

Pour chaque objet : import du FBX Meshy, fusion, décimation (~1-3 M -> ~20 k triangles), centrage,
taille ramenée à 1 m (le jeu met à l'échelle), textures réduites à 1024 px, export assets/loot/<id>.glb,
puis vignette 512 px vue de 3/4 dans assets/loot/icons/<id>.png (Cycles, éclairage studio).

Lancer (module bpy, voir tools/blender_fx.py) :
  ~/work/bpyenv/bin/python tools/meshy_loot.py <dossier_extrait> <id> [<id>...]
Le dossier extrait contient un sous-dossier par id (FBX + 4 PNG du ZIP Meshy).
"""
import glob
import math
import os
import sys

import bpy
from mathutils import Vector

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "loot")
TARGET_TRIS = 20000
TEX = 1024


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def load_tex(path, colorspace):
    img = bpy.data.images.load(path)
    img.colorspace_settings.name = colorspace
    if img.size[0] > TEX:
        img.scale(TEX, TEX)
    img.pack()
    return img


def build(folder, item):
    reset()
    fbx = glob.glob(os.path.join(folder, "*.fbx"))[0]
    bpy.ops.import_scene.fbx(filepath=fbx)
    meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    for o in bpy.context.scene.objects:
        o.select_set(o in meshes)
    bpy.context.view_layer.objects.active = meshes[0]
    if len(meshes) > 1:
        bpy.ops.object.join()
    ob = bpy.context.view_layer.objects.active
    for o in list(bpy.context.scene.objects):
        if o != ob:
            bpy.data.objects.remove(o)
    ob.parent = None
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    tris = sum(len(p.vertices) - 2 for p in ob.data.polygons)
    if tris > TARGET_TRIS:
        m = ob.modifiers.new("dec", "DECIMATE")
        m.ratio = TARGET_TRIS / tris
        bpy.ops.object.modifier_apply(modifier="dec")
    # Centre et taille 1 m
    bb = [ob.matrix_world @ Vector(c) for c in ob.bound_box]
    lo = Vector((min(v.x for v in bb), min(v.y for v in bb), min(v.z for v in bb)))
    hi = Vector((max(v.x for v in bb), max(v.y for v in bb), max(v.z for v in bb)))
    size = max(hi - lo)
    for v in ob.data.vertices:
        v.co = (v.co - (lo + hi) / 2) / size
    # Matériau PBR propre avec les 4 textures Meshy
    base = glob.glob(os.path.join(folder, "*texture.png"))[0]
    stem = base[:-4]
    mat = bpy.data.materials.new(item)
    mat.use_nodes = True
    nt = mat.node_tree
    bsdf = nt.nodes["Principled BSDF"]
    def tex(path, cs, socket, normal=False):
        if not os.path.exists(path):
            return
        n = nt.nodes.new("ShaderNodeTexImage")
        n.image = load_tex(path, cs)
        if normal:
            nm = nt.nodes.new("ShaderNodeNormalMap")
            nt.links.new(n.outputs["Color"], nm.inputs["Color"])
            nt.links.new(nm.outputs["Normal"], bsdf.inputs["Normal"])
        else:
            nt.links.new(n.outputs["Color"], bsdf.inputs[socket])
    tex(base, "sRGB", "Base Color")
    tex(stem + "_metallic.png", "Non-Color", "Metallic")
    tex(stem + "_roughness.png", "Non-Color", "Roughness")
    tex(stem + "_normal.png", "Non-Color", None, True)
    ob.data.materials.clear()
    ob.data.materials.append(mat)
    ob.name = item
    bpy.ops.object.shade_smooth()
    os.makedirs(OUT, exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, item + ".glb"), export_format="GLB", use_selection=False)
    print("[loot3d] %s : %d -> %d triangles" % (item, tris, sum(len(p.vertices) - 2 for p in ob.data.polygons)))
    return ob


def icon(ob, item):
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    sc.cycles.samples = 48
    sc.cycles.use_denoising = True
    sc.render.film_transparent = True
    sc.render.resolution_x = 512
    sc.render.resolution_y = 512
    sc.view_settings.view_transform = "AgX"
    world = bpy.data.worlds.new("w")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = (0.35, 0.42, 0.55, 1)
    world.node_tree.nodes["Background"].inputs[1].default_value = 0.6
    sc.world = world
    ob.rotation_euler = (0, 0, math.radians(35))
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    cam.data.lens = 50
    sc.collection.objects.link(cam)
    d = 2.1
    cam.location = (d * 0.0, -d * 0.93, d * 0.38)
    cam.rotation_euler = (math.radians(68), 0, 0)
    sc.camera = cam
    for name, loc, energy, col in [("key", (2.2, -2.0, 2.6), 260, (1.0, 0.95, 0.88)),
                                   ("fill", (-2.6, -1.2, 1.0), 90, (0.7, 0.8, 1.0)),
                                   ("rim", (0.5, 2.6, 2.0), 220, (0.8, 0.9, 1.0))]:
        l = bpy.data.objects.new(name, bpy.data.lights.new(name, "AREA"))
        l.data.energy = energy
        l.data.size = 1.5
        l.data.color = col
        l.location = loc
        l.rotation_euler = (Vector((0, 0, 0)) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
        sc.collection.objects.link(l)
    os.makedirs(os.path.join(OUT, "icons"), exist_ok=True)
    sc.render.filepath = os.path.join(OUT, "icons", item + ".png")
    bpy.ops.render.render(write_still=True)


if __name__ == "__main__":
    src = sys.argv[1]
    for item in sys.argv[2:]:
        ob = build(os.path.join(src, item), item)
        icon(ob, item)
