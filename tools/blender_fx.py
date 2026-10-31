"""Planches d'effets rendues dans Blender (volumes 3D éclairés), à la place des textures plates de gen_fx.py.

Chaque planche = 8 x 8 images (128 px) = toute la vie d'une bouffée, lue une fois par particule
(particles_anim_loop = false dans fx.gd). Les noms sont les mêmes qu'avant : le jeu les prend tel quel.

  smoke_sheet.png  : fumée grise qui gonfle, roule et se dissipe (alpha normal, teintée par le jeu)
  fire_sheet.png   : boule de feu qui s'embrase puis tourne à la fumée noire (couleurs prémultipliées)

Lancer (Blender en module Python, pas d'interface) :
  python -m venv ~/work/bpyenv && ~/work/bpyenv/bin/pip install bpy==5.2.3
  ~/work/bpyenv/bin/python tools/blender_fx.py [smoke|fire|all] [--preview]
La simulation de fluides (Mantaflow) ne marche pas dans le module bpy : on anime un bruit 4D dans une sphère.
"""
import os
import sys
import math
import tempfile

import bpy
import numpy as np

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FX = os.path.join(ROOT, "assets", "fx")
GRID = 8
CELL = 128


def reset_scene(samples):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    sc.cycles.device = "CPU"
    sc.cycles.samples = samples
    sc.cycles.use_denoising = True
    sc.cycles.denoiser = "OPENIMAGEDENOISE"
    sc.cycles.volume_bounces = 2
    sc.cycles.max_bounces = 4
    sc.render.resolution_x = CELL
    sc.render.resolution_y = CELL
    sc.render.film_transparent = True
    sc.render.image_settings.file_format = "PNG"
    sc.render.image_settings.color_mode = "RGBA"
    sc.view_settings.view_transform = "Standard"
    world = bpy.data.worlds.new("w")
    world.use_nodes = True
    bg = world.node_tree.nodes["Background"]
    bg.inputs["Color"].default_value = (0.55, 0.6, 0.7, 1.0)   # lumière du ciel (ombres bleutées)
    bg.inputs["Strength"].default_value = 0.35
    sc.world = world
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = 2.3
    cam.location = (0, -6, 0)
    cam.rotation_euler = (math.pi / 2, 0, 0)
    sc.collection.objects.link(cam)
    sc.camera = cam
    sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN"))
    sun.data.energy = 6.0
    sun.rotation_euler = (math.radians(35), math.radians(-30), 0)   # soleil haut, un peu de côté
    sc.collection.objects.link(sun)
    return sc


def node(nt, kind, **inputs):
    n = nt.nodes.new(kind)
    for k, v in inputs.items():
        if k.startswith("_"):
            setattr(n, k[1:], v)
        else:
            n.inputs[k].default_value = v
    return n


def math_node(nt, op, a, b=None, clamp=False):
    n = nt.nodes.new("ShaderNodeMath")
    n.operation = op
    n.use_clamp = clamp
    for i, v in enumerate((a, b)):
        if v is None:
            continue
        if isinstance(v, (int, float)):
            n.inputs[i].default_value = v
        else:
            nt.links.new(v, n.inputs[i])
    return n.outputs[0]


def puff_material(kind):
    """Volume dans une sphère : bruit 4D (W = temps) moins une distance au centre qui grandit.
    Les valeurs animées (rayon, temps, densité, chaleur) sont des nœuds Valeur pilotés image par image."""
    m = bpy.data.materials.new(kind)
    m.use_nodes = True
    nt = m.node_tree
    for n in list(nt.nodes):
        nt.nodes.remove(n)
    out = node(nt, "ShaderNodeOutputMaterial")
    vals = {}
    for name in ("time", "radius", "density", "heat", "rise"):
        v = nt.nodes.new("ShaderNodeValue")
        v.name = name
        vals[name] = v
    tc = nt.nodes.new("ShaderNodeTexCoord")
    # Coordonnées qui montent avec le temps (la fumée roule vers le haut)
    rise = nt.nodes.new("ShaderNodeCombineXYZ")
    nt.links.new(vals["rise"].outputs[0], rise.inputs["Z"])
    co = nt.nodes.new("ShaderNodeVectorMath")
    co.operation = "SUBTRACT"
    nt.links.new(tc.outputs["Object"], co.inputs[0])
    nt.links.new(rise.outputs[0], co.inputs[1])
    # Gros bouillonnements + détail : déformation du domaine pour l'aspect « chou-fleur »
    warp = node(nt, "ShaderNodeTexNoise", Scale=1.6, Detail=2.0, Roughness=0.5, _noise_dimensions="4D")
    nt.links.new(co.outputs[0], warp.inputs["Vector"])
    nt.links.new(vals["time"].outputs[0], warp.inputs["W"])
    wv = nt.nodes.new("ShaderNodeVectorMath")
    wv.operation = "SUBTRACT"
    nt.links.new(warp.outputs["Color"], wv.inputs[0])
    wv.inputs[1].default_value = (0.5, 0.5, 0.5)
    ws = nt.nodes.new("ShaderNodeVectorMath")
    ws.operation = "SCALE"
    nt.links.new(wv.outputs[0], ws.inputs[0])
    ws.inputs["Scale"].default_value = 0.55
    co2 = nt.nodes.new("ShaderNodeVectorMath")
    co2.operation = "ADD"
    nt.links.new(co.outputs[0], co2.inputs[0])
    nt.links.new(ws.outputs[0], co2.inputs[1])
    billow = node(nt, "ShaderNodeTexNoise", Scale=2.4, Detail=5.0, Roughness=0.5, _noise_dimensions="4D")
    nt.links.new(co2.outputs[0], billow.inputs["Vector"])
    nt.links.new(vals["time"].outputs[0], billow.inputs["W"])
    # Forme : sphère qui grandit, bord rongé par le bruit
    dist = nt.nodes.new("ShaderNodeVectorMath")
    dist.operation = "LENGTH"
    nt.links.new(co2.outputs[0], dist.inputs[0])
    shape = math_node(nt, "DIVIDE", dist.outputs["Value"], vals["radius"].outputs[0])
    edge = math_node(nt, "SUBTRACT", math_node(nt, "MULTIPLY", billow.outputs["Fac"], 1.4), shape)
    body = math_node(nt, "MULTIPLY", math_node(nt, "SUBTRACT", edge, -0.25), 9.0, clamp=True)
    dens = math_node(nt, "MULTIPLY", body, vals["density"].outputs[0])
    pv = nt.nodes.new("ShaderNodeVolumePrincipled")
    nt.links.new(dens, pv.inputs["Density"])
    if kind == "fire":
        # Cœur plus chaud que le bord : le feu est au centre, la fumée noire autour
        core = math_node(nt, "POWER", math_node(nt, "SUBTRACT", 1.0, shape, clamp=True), 1.2)
        mr = nt.nodes.new("ShaderNodeMapRange")          # contraste : poches très chaudes et zones plus sombres
        mr.interpolation_type = "SMOOTHERSTEP"
        mr.inputs["From Min"].default_value = 0.38
        mr.inputs["From Max"].default_value = 0.72
        nt.links.new(billow.outputs["Fac"], mr.inputs["Value"])
        hot = math_node(nt, "MULTIPLY", math_node(nt, "MULTIPLY", core, mr.outputs["Result"]), vals["heat"].outputs[0])
        nt.links.new(hot, pv.inputs["Blackbody Intensity"])
        pv.inputs["Temperature"].default_value = 2200.0
        pv.inputs["Color"].default_value = (0.08, 0.07, 0.065, 1.0)   # suie
        pv.inputs["Absorption Color"].default_value = (0.02, 0.02, 0.02, 1.0)
    else:
        pv.inputs["Color"].default_value = (0.85, 0.85, 0.85, 1.0)
        pv.inputs["Anisotropy"].default_value = 0.2
    nt.links.new(pv.outputs[0], out.inputs["Volume"])
    return m, vals


def build(kind):
    sc = reset_scene(32)
    bpy.ops.mesh.primitive_uv_sphere_add(radius=1.12, segments=32, ring_count=16)
    ob = bpy.context.object
    mat, vals = puff_material(kind)
    ob.data.materials.append(mat)
    return sc, vals


def drive(kind, vals, k):
    """k = avancement de la vie de la bouffée, 0 à 1."""
    vals["time"].outputs[0].default_value = 0.3 + k * 1.6
    vals["rise"].outputs[0].default_value = k * 0.35
    if kind == "smoke":
        vals["radius"].outputs[0].default_value = 0.45 + 0.5 * (1.0 - (1.0 - k) ** 2)
        vals["density"].outputs[0].default_value = 9.0 * (1.0 - k) ** 1.6 * min(1.0, k * 8.0 + 0.3)
    else:
        vals["radius"].outputs[0].default_value = 0.4 + 0.55 * (1.0 - (1.0 - k) ** 2.5)
        vals["density"].outputs[0].default_value = 6.0 * (1.0 - k) ** 1.3 * min(1.0, k * 10.0 + 0.4)
        # Chaleur : flash au départ, puis le feu s'éteint et laisse la suie
        vals["heat"].outputs[0].default_value = 70.0 * max(0.0, 1.0 - k * 1.45) ** 1.6 + 12.0 * max(0.0, 0.85 - k)


def render_sheet(kind, preview=False):
    sc, vals = build(kind)
    frames = [0, 9, 18, 27, 36, 45, 54, 63] if preview else list(range(GRID * GRID))
    tmp = tempfile.mkdtemp(prefix="bfx_")
    sheet = np.zeros((GRID * CELL, GRID * CELL, 4), np.float32)
    for i in frames:
        drive(kind, vals, i / (GRID * GRID - 1))
        path = os.path.join(tmp, "%02d.png" % i)
        sc.render.filepath = path
        bpy.ops.render.render(write_still=True)
        img = bpy.data.images.load(path)
        px = np.array(img.pixels[:], np.float32).reshape(CELL, CELL, 4)[::-1]
        bpy.data.images.remove(img)
        if kind == "fire":
            px[..., :3] *= px[..., 3:4]          # couleurs prémultipliées (fx.gd : BLEND_MODE_PREMULT_ALPHA)
            # Le feu émet : une flamme sans densité reste visible, on rend l'alpha au moins égal à sa lumière
            lum = px[..., :3].max(axis=2)
            px[..., 3] = np.maximum(px[..., 3], np.clip(lum, 0, 1))
        gx, gy = i % GRID, i // GRID
        sheet[gy * CELL:(gy + 1) * CELL, gx * CELL:(gx + 1) * CELL] = px
        print("[blender_fx] %s %d/%d" % (kind, i + 1, GRID * GRID), flush=True)
    from PIL import Image
    name = ("%s_sheet_preview.png" if preview else "%s_sheet.png") % kind
    out = os.path.join(FX if not preview else tmp, name)
    Image.fromarray((np.clip(sheet, 0, 1) * 255).astype(np.uint8), "RGBA").save(out)
    print("[blender_fx] ->", out)
    return out


if __name__ == "__main__":
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    which = args[0] if args else "all"
    preview = "--preview" in sys.argv
    for k in (["smoke", "fire"] if which == "all" else [which]):
        render_sheet(k, preview)
