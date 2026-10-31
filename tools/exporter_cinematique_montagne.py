"""Exporte la cinématique « montagne » de Blender vers Godot (assets/cinematique/) :
- decor_montagne.glb : terrain + lac ;
- vegetation.glb : un sapin, un feuillu, un rocher (posés en MultiMesh par Godot) ;
- accessoires.glb : Twin Vipers (avec l'éclair du canon), les 4 flammes, l'onde de choc ;
- montagne.json : 720 images à 24 i/s (squelette du Solaris en pose locale Godot, caméra, accessoires,
  fondu), plus les positions des arbres et le soleil.
Usage : blender -b travail_claude/cinematique_montagne.blend -P tools/exporter_cinematique_montagne.py"""
import bpy, json, os
from mathutils import Matrix, Vector

ROOT = r"C:\Users\Shadow\Downloads\arches-astrions-28oct"
OUT = os.path.join(ROOT, "assets", "cinematique")
os.makedirs(OUT, exist_ok=True)
sc = bpy.context.scene

# Blender (Z haut, -Y avant) -> Godot / glTF (Y haut, +Z avant) : (x, y, z) -> (x, z, -y)
C = Matrix(((1, 0, 0, 0), (0, 0, 1, 0), (0, -1, 0, 0), (0, 0, 0, 1)))
CI = C.inverted()

def r5(v):
    return [round(float(x), 5) for x in v]

def xf(m):
    """Transform3D Godot : base (colonnes x, y, z) puis origine — 12 nombres"""
    return r5([m[0][0], m[1][0], m[2][0], m[0][1], m[1][1], m[2][1], m[0][2], m[1][2], m[2][2], m[0][3], m[1][3], m[2][3]])

def obj_g(o):          # objet exporté en glTF (maillage converti lui aussi)
    return C @ o.matrix_world @ CI

def cam_g(o):          # caméra : mêmes axes locaux dans les deux moteurs
    return C @ o.matrix_world

def export(names, path):
    bpy.ops.object.select_all(action='DESELECT')
    keep = {}
    for n in names:
        o = bpy.data.objects[n]
        # l'animation recacherait l'objet (fusil rangé) pendant l'export : on la met de côté
        act = o.animation_data.action if o.animation_data else None
        if act:
            o.animation_data.action = None
        keep[n] = (o.hide_viewport, o.hide_render, o.hide_get(), act)
        o.hide_viewport = False; o.hide_render = False; o.hide_set(False)
        o.select_set(True)
    bpy.ops.export_scene.gltf(filepath=path, use_selection=True, export_format='GLB', export_apply=True,
                              export_animations=False, export_lights=False, export_cameras=False, export_yup=True)
    for n, (hv, hr, hs, act) in keep.items():
        o = bpy.data.objects[n]; o.hide_viewport = hv; o.hide_render = hr; o.hide_set(hs)
        if act:
            o.animation_data.action = act

sc.frame_set(1)
# --- décor
export(["Terrain-col", "Lac"], os.path.join(OUT, "decor_montagne.glb"))
# --- végétation : un exemplaire de chaque, ramené à l'origine
families = {"Sapin": [], "Feuillu": [], "Rocher": []}
for o in bpy.data.objects:
    if o.type == 'MESH':
        for fam in families:
            if o.data.name == fam:
                families[fam].append(o)
protos = []
for fam, objs in families.items():
    p = bpy.data.objects.new("proto_" + fam, objs[0].data)
    sc.collection.objects.link(p)
    protos.append(p.name)
export(protos, os.path.join(OUT, "vegetation.glb"))
for n in protos:
    bpy.data.objects.remove(bpy.data.objects[n])
# --- accessoires
ACC = ["TwinVipers", "EclairCanon", "Flamme_dos_L", "Flamme_dos_L_coeur", "Flamme_dos_R", "Flamme_dos_R_coeur",
       "Flamme_pied_L", "Flamme_pied_L_coeur", "Flamme_pied_R", "Flamme_pied_R_coeur", "OndeChoc"]
export(ACC, os.path.join(OUT, "accessoires.glb"))

# --- animation
arm = bpy.data.objects["SolarisArmature"]
cam = bpy.data.objects["CamCine"]
bones = [b.name for b in arm.data.bones]
parent = {b.name: (b.parent.name if b.parent else None) for b in arm.data.bones}
rest_head_g = {b.name: C @ b.head_local for b in arm.data.bones}
onde_mat = bpy.data.materials.get("Onde")
em = None
if onde_mat:
    em = next((n for n in onde_mat.node_tree.nodes if n.type == 'EMISSION'), None)
TRACK = ["TwinVipers", "TwinVipers_dos", "Flamme_dos_L", "Flamme_dos_R", "Flamme_pied_L", "Flamme_pied_R", "OndeChoc"]
frames = []
for f in range(sc.frame_start, sc.frame_end + 1):
    sc.frame_set(f)
    # squelette : pose globale Godot B = C D C^-1 * Repos ; puis locale = parent^-1 * B
    glob = {}
    for b in bones:
        pb = arm.pose.bones[b]
        D = C @ (pb.matrix @ arm.data.bones[b].matrix_local.inverted()) @ CI
        glob[b] = D @ Matrix.Translation(rest_head_g[b])
    loc = {}
    for b in bones:
        Lm = (glob[parent[b]].inverted() @ glob[b]) if parent[b] else glob[b]
        t, q, s = Lm.decompose()
        loc[b] = r5(t) + r5((q.x, q.y, q.z, q.w))
    e = {
        "skel": xf(C @ arm.matrix_world @ CI),
        "bones": loc,
        "cam": xf(cam_g(cam)),
        "lens": round(cam.data.lens, 3),
        "expo": round(sc.view_settings.exposure, 3),
        "obj": {n: xf(obj_g(bpy.data.objects[n])) + [0 if bpy.data.objects[n].hide_render else 1] for n in TRACK},
        "eclair": 0 if bpy.data.objects["EclairCanon"].hide_render else 1,
        "onde_em": round(em.inputs[1].default_value, 3) if em else 0.0,
        "lum_canon": round(bpy.data.objects["LumiereCanon"].data.energy, 2),
        "lum_prop": round(bpy.data.objects["LumiereProp"].data.energy, 2),
    }
    frames.append(e)

trees = {fam: [xf(obj_g(o)) for o in objs] for fam, objs in families.items()}
sun = bpy.data.objects["Soleil"]
data = {
    "fps": sc.render.fps, "frames": frames, "bones": bones,
    "sensor": cam.data.sensor_width, "aspect": [sc.render.resolution_x, sc.render.resolution_y],
    "vegetation": trees,
    "soleil": {"xf": xf(cam_g(sun)), "energie": sun.data.energy, "couleur": r5(sun.data.color)},
}
json.dump(data, open(os.path.join(OUT, "montagne.json"), "w"), separators=(",", ":"))
print("EXPORT OK", len(frames), "images,", {k: len(v) for k, v in trees.items()}, "arbres/rochers")
