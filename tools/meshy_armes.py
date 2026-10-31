"""Armes Meshy de cyril (29 oct) -> modèles tenus en main + modèles de butin + textures pour Godot.

Pour chaque arme : import du FBX Meshy, fusion, décimation (~25 k triangles), textures réduites à 1024 px.
 - assets/weapons/<id>_albedo/_normal/_roughness/_metallic.png : textures (repeintes en jeu par le preset) ;
 - <sortie>/<id>_main.glb : arme couchée le long de X, canon vers -X, haut +Z (Blender), ORIGINE À LA POIGNÉE,
   en mètres. tools/weapon_res.gd en tire assets/weapons/<id>.res (le maillage seul, comme rifle.res) ;
 - assets/loot/<id>.glb : modèle de butin centré, 1 m (fiche d'objet de la Forge), comme tools/meshy_loot.py.

Les points (poignée, bouche du canon, garde-main) sont relevés sur une vue de profil de l'arme posée canon
vers -X, longueur 1 (repère X avant/arrière, Z haut/bas), puis l'arme est mise à sa longueur réelle.
Les valeurs muzzle / fore à recopier dans scripts/combat.gd (WEAPON_MODELS) sont affichées à la fin.

Lancer (Blender 5.2, sans fenêtre) :
  blender -b --factory-startup --python tools/meshy_armes.py -- <dossier_extrait> <sortie_glb> [<id>...]
Le dossier extrait contient un sous-dossier par id avec texture.fbx et les 4 PNG du ZIP Meshy
(noms raccourcis : texture.png, texture_metallic.png, texture_normal.png, texture_roughness.png).
"""
import glob
import os
import sys

import bpy
from mathutils import Vector

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TARGET_TRIS = 25000
TEX = 1024

# id : longueur réelle (m), poignée, bouche du canon, garde-main (main gauche) en (X, Z) sur l'arme de longueur 1
ARMES = {
    "tacticien":  {"len": 0.95, "grip": (0.184, -0.077), "muzzle": (-0.499, 0.060), "fore": (-0.279, -0.077)},
    "ivoire":     {"len": 1.00, "grip": (0.184, -0.043), "muzzle": (-0.499, 0.043), "fore": (-0.141, -0.009)},
    "minuit":     {"len": 1.05, "grip": (0.201, -0.051), "muzzle": (-0.499, 0.060), "fore": (-0.206, -0.009)},
    "repetiteur": {"len": 0.95, "grip": (0.171, -0.026), "muzzle": (-0.497, 0.030), "fore": (-0.154, 0.000)},
    "sentinelle": {"len": 1.20, "grip": (0.154, -0.034), "muzzle": (-0.499, 0.015), "fore": (-0.189, -0.013)},
    "silencieux": {"len": 1.10, "grip": (0.214, -0.060), "muzzle": (-0.499, 0.045), "fore": (-0.094, -0.021)},
    "titan":      {"len": 1.15, "grip": (0.236, -0.026), "muzzle": (-0.499, 0.043), "fore": (-0.171, -0.010)},
}


def import_weapon(folder):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.fbx(filepath=glob.glob(os.path.join(folder, "*.fbx"))[0])
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
    # Les FBX Meshy arrivent canon vers -X, haut +Z : on centre la boîte et on ramène la longueur à 1
    vs = [v.co for v in ob.data.vertices]
    lo = Vector((min(v.x for v in vs), min(v.y for v in vs), min(v.z for v in vs)))
    hi = Vector((max(v.x for v in vs), max(v.y for v in vs), max(v.z for v in vs)))
    for v in ob.data.vertices:
        v.co = (v.co - (lo + hi) / 2) / (hi.x - lo.x)
    print("[armes] %s : %d -> %d triangles" % (os.path.basename(folder), tris, sum(len(p.vertices) - 2 for p in ob.data.polygons)))
    return ob


def textures(folder, item):
    """Les 4 textures Meshy en 1024 px, nommées comme celles du fusil (assets/weapons/rifle_*.png)."""
    out = {}
    for src, dst, cs in [("texture.png", "albedo", "sRGB"), ("texture_normal.png", "normal", "Non-Color"),
                         ("texture_roughness.png", "roughness", "Non-Color"), ("texture_metallic.png", "metallic", "Non-Color")]:
        img = bpy.data.images.load(os.path.join(folder, src))
        img.colorspace_settings.name = cs
        if img.size[0] > TEX:
            img.scale(TEX, TEX)
        path = os.path.join(ROOT, "assets", "weapons", "%s_%s.png" % (item, dst))
        img.filepath_raw = path
        img.file_format = "PNG"
        img.save()
        out[dst] = img
    return out


def material(ob, item, imgs):
    mat = bpy.data.materials.new(item)
    mat.use_nodes = True
    nt = mat.node_tree
    bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
    def tex(img, socket, normal=False):
        n = nt.nodes.new("ShaderNodeTexImage")
        n.image = img
        if normal:
            nm = nt.nodes.new("ShaderNodeNormalMap")
            nt.links.new(n.outputs["Color"], nm.inputs["Color"])
            nt.links.new(nm.outputs["Normal"], bsdf.inputs["Normal"])
        else:
            nt.links.new(n.outputs["Color"], bsdf.inputs[socket])
    tex(imgs["albedo"], "Base Color")
    tex(imgs["metallic"], "Metallic")
    tex(imgs["roughness"], "Roughness")
    tex(imgs["normal"], None, True)
    ob.data.materials.clear()
    ob.data.materials.append(mat)
    ob.name = item
    bpy.ops.object.shade_smooth()


def export(path):
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=False)


def build(src, out, item):
    a = ARMES[item]
    folder = os.path.join(src, item)
    ob = import_weapon(folder)
    imgs = textures(folder, item)
    material(ob, item, imgs)
    # Modèle de butin : centré, 1 m (images embarquées, comme tools/meshy_loot.py)
    export(os.path.join(ROOT, "assets", "loot", item + ".glb"))
    # Arme en main : origine à la poignée, longueur réelle
    g = Vector((a["grip"][0], 0.0, a["grip"][1]))
    L = a["len"]
    for v in ob.data.vertices:
        v.co = (v.co - g) * L
    ob.data.update()
    export(os.path.join(out, item + "_main.glb"))
    # Repère de l'arme en jeu (combat.gd) : canon vers -Z, haut +Y ; X du modèle -> Z, Z du modèle -> Y
    def gun(p):
        return "Vector3(0, %.3f, %.3f)" % ((p[1] - a["grip"][1]) * L, (p[0] - a["grip"][0]) * L)
    print("[armes] %s  muzzle %s  fore %s" % (item, gun(a["muzzle"]), gun(a["fore"])))


if __name__ == "__main__":
    args = sys.argv[sys.argv.index("--") + 1:]
    for item in args[2:] or list(ARMES):
        build(args[0], args[1], item)
