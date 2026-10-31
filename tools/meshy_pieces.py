"""Pièces d'armure Meshy de cyril -> maillages et textures pour la Forge (étape 1 de 2, Blender).

Pour chaque pièce : import du FBX Meshy, fusion, décimation (~30 000 triangles), centrage de la boîte
(taille Meshy gardée), textures réduites à 1024 px. Sorties :
 - assets/pieces/<dossier>/<nom>_albedo/_normal/_roughness/_metallic.png (repeintes en jeu par le preset) ;
 - assets/pieces/<dossier>/src/<nom>.glb : le maillage seul (Godot : devant = +Z, haut = +Y) ;
 - <aperçus>/<nom>_face.png, _profil.png : vues orthographiques pour vérifier le sens et le côté.
L'étape 2 (Godot, tools/skin_pieces.tscn) tire le .res du .glb, le pose sur le corps avec Catalog.mesh_def,
puis l'habille sur le squelette (poids du corps) et calcule le masque du corps.

Lancer (Blender 5.2, sans fenêtre) :
  blender -b --factory-startup --python tools/meshy_pieces.py -- <dossier_extrait> <aperçus> <nom:dossier>...
Le dossier extrait contient un sous-dossier par nom avec texture.fbx et les 4 PNG du ZIP Meshy
(texture.png, texture_metallic.png, texture_normal.png, texture_roughness.png).
"""
import glob
import math
import os
import sys

import bmesh
import bpy
from mathutils import Vector

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TARGET_TRIS = 30000
TEX = 1024


def import_piece(folder):
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
    vs = [v.co for v in ob.data.vertices]
    lo = Vector((min(v.x for v in vs), min(v.y for v in vs), min(v.z for v in vs)))
    hi = Vector((max(v.x for v in vs), max(v.y for v in vs), max(v.z for v in vs)))
    for v in ob.data.vertices:
        v.co = v.co - (lo + hi) / 2
    ob.data.update()
    d = hi - lo
    # repère Godot : X = X Blender, Y = Z Blender (haut), Z = -Y Blender (devant)
    print("[pieces] %s : %d -> %d triangles, taille Godot x %.3f  y %.3f  z %.3f"
          % (os.path.basename(folder), tris, sum(len(p.vertices) - 2 for p in ob.data.polygons), d.x, d.z, d.y))
    return ob


def textures(folder, out_dir, name):
    imgs = {}
    for src, dst, cs in [("texture.png", "albedo", "sRGB"), ("texture_normal.png", "normal", "Non-Color"),
                         ("texture_roughness.png", "roughness", "Non-Color"), ("texture_metallic.png", "metallic", "Non-Color")]:
        img = bpy.data.images.load(os.path.join(folder, src))
        img.colorspace_settings.name = cs
        if img.size[0] > TEX:
            img.scale(TEX, TEX)
        img.filepath_raw = os.path.join(out_dir, "%s_%s.png" % (name, dst))
        img.file_format = "PNG"
        img.save()
        imgs[dst] = img
    return imgs


def material(ob, name, imgs):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nt = mat.node_tree
    bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
    n = nt.nodes.new("ShaderNodeTexImage")
    n.image = imgs["albedo"]
    nt.links.new(n.outputs["Color"], bsdf.inputs["Base Color"])
    ob.data.materials.clear()
    ob.data.materials.append(mat)
    ob.name = name
    bpy.ops.object.shade_smooth()


def previews(ob, out, name):
    """Vues orthographiques texturées : face (on regarde le devant, -Y Blender) et profil (côté +X)."""
    sc = bpy.context.scene
    try:
        sc.render.engine = "BLENDER_WORKBENCH"
    except TypeError:
        pass
    sc.display.shading.light = "STUDIO"
    sc.display.shading.color_type = "TEXTURE"
    sc.render.resolution_x = 512
    sc.render.resolution_y = 512
    size = max(ob.dimensions) * 1.15
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = size
    sc.collection.objects.link(cam)
    sc.camera = cam
    for view, loc, rot in [("face", (0, -5, 0), (math.pi / 2, 0, 0)), ("profil", (5, 0, 0), (math.pi / 2, 0, math.pi / 2)),
                           ("dessus", (0, 0, 5), (0, 0, 0))]:
        cam.location = loc
        cam.rotation_euler = rot
        sc.render.filepath = os.path.join(out, "%s_%s.png" % (name, view))
        bpy.ops.render.render(write_still=True)
    bpy.data.objects.remove(cam)


def build(src, prev, name, folder):
    out_dir = os.path.join(ROOT, "assets", "pieces", folder)
    os.makedirs(os.path.join(out_dir, "src"), exist_ok=True)
    ob = import_piece(os.path.join(src, name))
    imgs = textures(os.path.join(src, name), out_dir, name)
    material(ob, name, imgs)
    previews(ob, prev, name)
    bpy.ops.export_scene.gltf(filepath=os.path.join(out_dir, "src", name + ".glb"), export_format="GLB",
                              use_selection=False, export_materials="NONE")


## Bras Meshy (modélisés pliés) : épaule, coude, poignet et bout des doigts relevés sur les vues face/profil
## (repère Blender, modèle centré). Le bras est coupé en 3 au coude et au poignet (plans bissecteurs), chaque
## morceau est redressé à la verticale, articulation du haut à l'origine, pendant vers le bas (-Z Blender =
## -Y Godot), le devant du bras (côté où le coude plie) vers -Y Blender (= +Z Godot, comme les autres pièces)
## et le dehors du bras vers +X (ou -X avec "flip"). Catalog._limb les pose ensuite sur les os, comme le
## bras Mech. Les longueurs des 3 morceaux (à recopier dans Catalog) sont affichées.
BRAS = {
    "bras_tigre": {"S": (0.274, 0.21, 0.55), "E": (0.445, 0.06, -0.145), "W": (-0.175, -0.2, -0.466), "T": (-0.432, -0.41, -0.787)},
    "bras_emberclaw": {"S": (-0.238, 0.36, 0.59), "E": (-0.559, 0.24, -0.103), "W": (0.188, -0.06, -0.444), "T": (0.487, -0.35, -0.785)},
    # bras du 29 oct (2e lot), relevés sur des vues face/profil quadrillées (2,2 m sur 768 px)
    "bras_precision": {"S": (-0.25, 0.35, 0.6), "E": (-0.45, 0.4, -0.15), "W": (0.08, -0.3, -0.48), "T": (0.3, -0.62, -0.82)},
    "bras_limier": {"S": (-0.3, 0.3, 0.6), "E": (-0.5, 0.2, -0.12), "W": (0.15, -0.45, -0.52), "T": (0.45, -0.75, -0.82)},
    "bras_cyber_a": {"S": (-0.28, 0.4, 0.6), "E": (-0.5, 0.42, -0.15), "W": (0.08, -0.42, -0.5), "T": (0.38, -0.65, -0.85)},
    "bras_cyber_b": {"S": (-0.25, 0.38, 0.6), "E": (-0.5, 0.4, -0.15), "W": (0.08, -0.45, -0.5), "T": (0.36, -0.68, -0.85)},
    "bras_prothese": {"S": (0.3, 0.2, 0.6), "E": (0.52, 0.0, -0.15), "W": (-0.15, -0.4, -0.5), "T": (-0.48, -0.5, -0.82)},
    "bras_allonge": {"S": (0.1, 0.45, 0.6), "E": (0.2, 0.6, -0.15), "W": (0.15, -0.3, -0.52), "T": (0.12, -0.6, -0.78)},
    "bras_serre": {"S": (0.3, 0.2, 0.6), "E": (0.53, 0.25, -0.08), "W": (-0.2, -0.35, -0.52), "T": (-0.48, -0.45, -0.82)},
    "bras_exocoque": {"S": (-0.12, 0.5, 0.62), "E": (0.33, 0.5, -0.12), "W": (0.3, -0.35, -0.5), "T": (0.3, -0.65, -0.8)},
    "bras_mech_braise": {"S": (0.3, 0.35, 0.58), "E": (0.52, 0.08, -0.12), "W": (-0.2, -0.5, -0.55), "T": (-0.48, -0.78, -0.8)},
    "bras_cobra": {"S": (-0.35, 0.45, 0.58), "E": (-0.56, 0.15, -0.2), "W": (0.15, -0.45, -0.55), "T": (0.45, -0.72, -0.85)},
    "bras_servo": {"S": (0.05, 0.45, 0.55), "E": (0.4, 0.25, -0.2), "W": (0.2, -0.48, -0.5), "T": (0.2, -0.78, -0.75)},
    "bras_titan": {"S": (-0.3, 0.22, 0.58), "E": (-0.55, 0.2, -0.12), "W": (0.12, -0.35, -0.52), "T": (0.36, -0.5, -0.85)},
}


## Bras dont l'épaulière est ramenée sur le dehors de l'épaule (2e lot ; le Tigre et l'Emberclaw restent tels quels).
TWIST_PAD = ["bras_precision", "bras_limier", "bras_cyber_a", "bras_cyber_b", "bras_prothese", "bras_allonge", "bras_serre",
             "bras_exocoque", "bras_mech_braise", "bras_cobra", "bras_servo", "bras_titan"]
OVERHANG = 0.32    # au-delà de cette distance de l'os de l'avant-bras ou de la main, une face appartient au bras


def _seg_dist(p, a, b):
    ab = b - a
    t = max(0.0, min(1.0, (p - a).dot(ab) / ab.dot(ab)))
    return (p - (a + ab * t)).length


def _drop_strays(bm, a, b):
    """Retire les petits îlots coupés loin de l'os (bouts de plaque qui flotteraient une fois le bras redressé)."""
    seen = set()
    islands = []
    for f in bm.faces:
        if f in seen:
            continue
        isl = []
        stack = [f]
        seen.add(f)
        while stack:
            g = stack.pop()
            isl.append(g)
            for e in g.edges:
                for h in e.link_faces:
                    if h not in seen:
                        seen.add(h)
                        stack.append(h)
        islands.append(isl)
    total = len(bm.faces)
    drop = []
    for isl in islands:
        c = sum((g.calc_center_median() for g in isl), Vector()) / len(isl)
        if len(isl) < 0.02 * total and _seg_dist(c, a, b) > 0.2:
            drop += isl
    if drop:
        bmesh.ops.delete(bm, geom=drop, context="FACES")


def build_arm(src, prev, name, folder, flip=False):
    out_dir = os.path.join(ROOT, "assets", "pieces", folder)
    os.makedirs(os.path.join(out_dir, "src"), exist_ok=True)
    ob = import_piece(os.path.join(src, name))
    imgs = textures(os.path.join(src, name), out_dir, name)
    material(ob, name, imgs)
    j = {k: Vector(v) for k, v in BRAS[name].items()}
    du = (j["E"] - j["S"]).normalized()
    df = (j["W"] - j["E"]).normalized()
    dh = (j["T"] - j["W"]).normalized()
    n = du.cross(df).normalized()                  # normale au plan du pli
    front = (df - du * df.dot(du)).normalized()    # le coude plie vers l'avant
    segs = [("upper", j["S"], j["E"], du, None, (du + df).normalized()),
            ("fore", j["E"], j["W"], df, (du + df).normalized(), (df + dh).normalized()),
            ("hand", j["W"], j["T"], dh, (df + dh).normalized(), None)]
    sc = bpy.context.scene
    off = 0.0
    for seg, a, b, d, cut_a, cut_b in segs:
        part = ob.copy()
        part.data = ob.data.copy()
        sc.collection.objects.link(part)
        me = part.data
        bm = bmesh.new()
        bm.from_mesh(me)
        A, B = (j["S"], j["E"]) if seg == "upper" else ((j["E"], j["W"]) if seg == "fore" else (j["W"], j["T"]))
        drop = []
        for f in bm.faces:
            c = f.calc_center_median()
            if cut_a is not None and (c - A).dot(cut_a) < 0:
                drop.append(f)
            elif cut_b is not None and (c - B).dot(cut_b) > 0:
                drop.append(f)
            elif seg != "upper" and _seg_dist(c, A, B) > OVERHANG:
                drop.append(f)      # lèvre de l'épaulière qui pend au-dessus de l'avant-bras plié : reste au bras
        if seg == "upper":
            # les faces des morceaux du dessous trop loin de leur os reviennent au bras (épaulière)
            keep = set(drop)
            for f in bm.faces:
                c = f.calc_center_median()
                if f in keep and (c - j["E"]).dot((du + df).normalized()) > 0:
                    lo_seg = (j["E"], j["W"]) if (c - j["W"]).dot((df + dh).normalized()) <= 0 else (j["W"], j["T"])
                    if _seg_dist(c, *lo_seg) > OVERHANG:
                        keep.discard(f)
            drop = list(keep)
        bmesh.ops.delete(bm, geom=drop, context="FACES")
        _drop_strays(bm, A, B)
        # repère du morceau : axe d -> -Z, normale du pli -> +X (dehors), devant -> -Y
        side = n if not flip else -n
        fwd = d.cross(side).normalized()
        if fwd.dot(front) < 0:
            side = -side
            fwd = -fwd
        for v in bm.verts:
            p = v.co - A
            v.co = Vector((p.dot(side), -p.dot(fwd), -p.dot(d)))
        if seg == "upper" and name in TWIST_PAD:
            # l'épaulière Meshy regarde la main (vers l'avant une fois redressée) : on tourne le bras sur son axe
            # pour qu'elle couvre le dehors de l'épaule (+X), le coude plie toujours vers l'avant
            cx = sum(v.co.x for v in bm.verts) / len(bm.verts)
            cy = sum(v.co.y for v in bm.verts) / len(bm.verts)
            if math.hypot(cx, cy) > 0.04:
                a = -math.atan2(cy, cx)
                ca, sa = math.cos(a), math.sin(a)
                for v in bm.verts:
                    v.co = Vector((v.co.x * ca - v.co.y * sa, v.co.x * sa + v.co.y * ca, v.co.z))
                print("[bras] %s : épaulière tournée de %.0f°" % (name, math.degrees(a)))
        bm.to_mesh(me)
        bm.free()
        me.update()
        print("[bras] %s_%s : longueur %.3f" % (name, seg, (B - A).length))
        for o in sc.objects:
            o.select_set(o == part)
        bpy.context.view_layer.objects.active = part
        bpy.ops.export_scene.gltf(filepath=os.path.join(out_dir, "src", "%s_%s.glb" % (name, seg)), export_format="GLB",
                                  use_selection=True, export_materials="NONE")
        part.location = (0, 0, -off)
        off += (B - A).length
    # aperçu : les trois morceaux redressés posés bout à bout
    bpy.data.objects.remove(ob)
    previews_all(prev, name + "_droit")


def previews_all(out, name):
    sc = bpy.context.scene
    bpy.context.view_layer.update()
    objs = [o for o in sc.objects if o.type == "MESH"]
    lo = Vector((min(min((o.matrix_world @ Vector(c))[i] for c in o.bound_box) for o in objs) for i in range(3)))
    hi = Vector((max(max((o.matrix_world @ Vector(c))[i] for c in o.bound_box) for o in objs) for i in range(3)))
    mid = (lo + hi) / 2
    try:
        sc.render.engine = "BLENDER_WORKBENCH"
    except TypeError:
        pass
    sc.display.shading.light = "STUDIO"
    sc.display.shading.color_type = "TEXTURE"
    sc.render.resolution_x = 512
    sc.render.resolution_y = 512
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = max(hi - lo) * 1.15
    sc.collection.objects.link(cam)
    sc.camera = cam
    for view, loc, rot in [("face", (0, -5, 0), (math.pi / 2, 0, 0)), ("profil", (5, 0, 0), (math.pi / 2, 0, math.pi / 2))]:
        cam.location = mid + Vector(loc)
        cam.rotation_euler = rot
        sc.render.filepath = os.path.join(out, "%s_%s.png" % (name, view))
        bpy.ops.render.render(write_still=True)
    bpy.data.objects.remove(cam)


if __name__ == "__main__":
    args = sys.argv[sys.argv.index("--") + 1:]
    os.makedirs(args[1], exist_ok=True)
    for spec in args[2:]:
        name, folder = spec.split(":")[:2]
        if name in BRAS:
            build_arm(args[0], args[1], name, folder, spec.endswith(":flip"))
        else:
            build(args[0], args[1], name, folder)
