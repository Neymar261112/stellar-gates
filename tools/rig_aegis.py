"""Squelette et poids de peau pour le corps Aegis (modèle Meshy de cyril, face +Z, centré, 1,90 m).
Mêmes 17 os que le Solaris : les animations procédurales et la Forge marchent pareil.
Sortie : un nouveau GLB avec skin (JOINTS_0 / WEIGHTS_0), importable tel quel par Godot."""
import struct, json, numpy as np, sys
src, dst = sys.argv[1], sys.argv[2]
d = open(src, 'rb').read()
ln = struct.unpack_from('<I', d, 12)[0]
js = json.loads(d[20:20 + ln])
off = 20 + ln
clen, ctype = struct.unpack_from('<II', d, off)
bin_ = bytearray(d[off + 8:off + 8 + clen])
pr = js['meshes'][0]['primitives'][0]
acc = js['accessors'][pr['attributes']['POSITION']]
bv = js['bufferViews'][acc['bufferView']]
stride = bv.get('byteStride', 12)
start = bv.get('byteOffset', 0) + acc.get('byteOffset', 0)
raw = np.frombuffer(bytes(bin_), dtype=np.uint8)
n = acc['count']
idx = start + np.arange(n)[:, None] * stride + np.arange(12)[None, :]
P = raw[idx].copy().view(np.float32).reshape(-1, 3)
x, y, z = P[:, 0], P[:, 1], P[:, 2]

# --- os : nom, parent, position (espace modèle, centré : le sol est à y = -0.95)
BONES = [
    ("hips", None, (0, -0.03, 0)),
    ("spine", "hips", (0, 0.10, 0)),
    ("chest", "spine", (0, 0.30, 0)),
    ("neck", "chest", (0, 0.66, 0)),
    ("head", "neck", (0, 0.74, 0)),
    ("upper_arm_L", "chest", (0.27, 0.55, 0)),
    ("forearm_L", "upper_arm_L", (0.35, 0.29, 0)),
    ("hand_L", "forearm_L", (0.38, 0.01, 0)),
    ("upper_arm_R", "chest", (-0.27, 0.55, 0)),
    ("forearm_R", "upper_arm_R", (-0.35, 0.29, 0)),
    ("hand_R", "forearm_R", (-0.38, 0.01, 0)),
    ("thigh_L", "hips", (0.12, -0.06, 0)),
    ("shin_L", "thigh_L", (0.20, -0.48, 0)),
    ("foot_L", "shin_L", (0.24, -0.82, 0)),
    ("thigh_R", "hips", (-0.12, -0.06, 0)),
    ("shin_R", "thigh_R", (-0.20, -0.48, 0)),
    ("foot_R", "shin_R", (-0.24, -0.82, 0)),
]
TAIL = {"hand_L": (0.40, -0.24, 0), "hand_R": (-0.40, -0.24, 0), "foot_L": (0.25, -0.95, 0.08), "foot_R": (-0.25, -0.95, 0.08)}
names = [b[0] for b in BONES]
bi = {nm: i for i, nm in enumerate(names)}

def smooth(a, lo, hi):
    t = np.clip((a - lo) / (hi - lo), 0, 1)
    return t * t * (3 - 2 * t)

def seg_dist(nm):
    i = bi[nm]
    h = np.array(BONES[i][2], dtype=np.float32)
    kids = [b for b in BONES if b[1] == nm and not b[0].startswith(("upper_arm", "thigh"))]
    t = np.array(TAIL[nm] if nm in TAIL else kids[0][2], dtype=np.float32)
    d = t - h
    u = np.clip(((P - h) @ d) / max(float(d @ d), 1e-6), 0, 1)
    return np.linalg.norm(P - (h + u[:, None] * d), axis=1)

def by_distance(group):
    D = np.stack([seg_dist(nm) for nm in group], 1)
    w = 1.0 / (D + 0.01) ** 6
    return w / w.sum(1, keepdims=True)

W = np.zeros((n, len(BONES)), dtype=np.float32)
ax = np.abs(x)
side_L = x >= 0
# régions : bras (hors du torse), jambes (sous le bassin), torse (le reste)
bound = 0.24 + 0.06 * (1 - smooth(y, -0.08, 0.02))          # les mains descendent le long des cuisses
arm_m = smooth(ax, bound - 0.02, bound + 0.02) * (y > -0.32)
leg_m = smooth(-y, 0.02, 0.12) * (1 - arm_m)
tor_m = 1 - arm_m - leg_m

torso = np.zeros_like(W)
t_hips = 1 - smooth(y, 0.0, 0.08)
t_spine = smooth(y, 0.0, 0.08) * (1 - smooth(y, 0.20, 0.30))
t_chest = smooth(y, 0.20, 0.30) * (1 - smooth(y, 0.62, 0.68))
t_neck = smooth(y, 0.62, 0.68) * (1 - smooth(y, 0.72, 0.77))
t_head = smooth(y, 0.72, 0.77)
for nm, t in (("hips", t_hips), ("spine", t_spine), ("chest", t_chest), ("neck", t_neck), ("head", t_head)):
    torso[:, bi[nm]] = t
# les épaulières suivent un peu le bras
arm = np.zeros_like(W)
leg = np.zeros_like(W)
for s, suf in ((side_L, "_L"), (~side_L, "_R")):
    ga = ["upper_arm" + suf, "forearm" + suf, "hand" + suf]
    wa = by_distance(ga)
    gl = ["thigh" + suf, "shin" + suf, "foot" + suf]
    wl = by_distance(gl)
    for k in range(3):
        arm[s, bi[ga[k]]] = wa[s, k]
        leg[s, bi[gl[k]]] = wl[s, k]
W = torso * tor_m[:, None] + arm * arm_m[:, None] + leg * leg_m[:, None]
# Normalise, garde les 4 plus forts
W = W / np.maximum(W.sum(1, keepdims=True), 1e-6)
top = np.argsort(-W, axis=1)[:, :4]
J = top.astype(np.uint16)
Wt = np.take_along_axis(W, top, axis=1).astype(np.float32)
Wt = Wt / np.maximum(Wt.sum(1, keepdims=True), 1e-6)
print("poids par os (somme) :")
for i, nm in enumerate(names):
    print(f"  {nm:14s} {W[:, i].sum():9.0f}")

# --- inverse bind matrices (os sans rotation : translation seule)
def gpos(i):
    nm, par, p = BONES[i]
    return np.array(p, dtype=np.float32)
ibm = np.zeros((len(BONES), 16), dtype=np.float32)
for i in range(len(BONES)):
    M = np.eye(4, dtype=np.float32)
    M[:3, 3] = -gpos(i)
    ibm[i] = M.T.flatten()   # glTF : column-major

# --- ajoute les données au buffer
def align4(b):
    while len(b) % 4: b.append(0)
align4(bin_)
j_off = len(bin_); bin_ += J.tobytes(); align4(bin_)
w_off = len(bin_); bin_ += Wt.tobytes(); align4(bin_)
m_off = len(bin_); bin_ += ibm.tobytes(); align4(bin_)
js['bufferViews'] += [
    {"buffer": 0, "byteOffset": j_off, "byteLength": J.nbytes, "target": 34962},
    {"buffer": 0, "byteOffset": w_off, "byteLength": Wt.nbytes, "target": 34962},
    {"buffer": 0, "byteOffset": m_off, "byteLength": ibm.nbytes},
]
nbv = len(js['bufferViews'])
js['accessors'] += [
    {"bufferView": nbv - 3, "componentType": 5123, "count": n, "type": "VEC4"},
    {"bufferView": nbv - 2, "componentType": 5126, "count": n, "type": "VEC4"},
    {"bufferView": nbv - 1, "componentType": 5126, "count": len(BONES), "type": "MAT4"},
]
nacc = len(js['accessors'])
pr['attributes']['JOINTS_0'] = nacc - 3
pr['attributes']['WEIGHTS_0'] = nacc - 2
js['buffers'][0]['byteLength'] = len(bin_)
# --- nœuds d'os
base = len(js['nodes'])
for i, (nm, par, p) in enumerate(BONES):
    pp = np.array(BONES[bi[par]][2]) if par else np.zeros(3)
    node = {"name": nm, "translation": [float(v) for v in (np.array(p) - pp)]}
    js['nodes'].append(node)
for i, (nm, par, p) in enumerate(BONES):
    if par:
        js['nodes'][base + bi[par]].setdefault('children', []).append(base + i)
js['skins'] = [{"name": "SolarisSkin", "joints": [base + i for i in range(len(BONES))], "inverseBindMatrices": nacc - 1, "skeleton": base}]
mesh_node = [i for i, nd in enumerate(js['nodes']) if 'mesh' in nd][0]
for nd in js['nodes'][:base]:
    nd.pop('children', None)
js['nodes'][mesh_node]['skin'] = 0
js['nodes'][mesh_node]['name'] = 'SolarisMesh'
# la scène : racine armature contenant le maillage et la racine des os
arm_node = {"name": "SolarisArmature", "children": [mesh_node, base]}
js['nodes'].append(arm_node)
js['scenes'][0]['nodes'] = [len(js['nodes']) - 1]
# l'export Godot laisse un nœud racine vide (le premier) : on le retire et on renumérote
if 'mesh' not in js['nodes'][0] and js['nodes'][0].get('name') == 'Root':
    js['nodes'].pop(0)
    fix = lambda i: i - 1
    for nd in js['nodes']:
        if 'children' in nd:
            nd['children'] = [fix(c) for c in nd['children']]
    js['skins'][0]['joints'] = [fix(j) for j in js['skins'][0]['joints']]
    js['skins'][0]['skeleton'] = fix(js['skins'][0]['skeleton'])
    js['scenes'][0]['nodes'] = [fix(i) for i in js['scenes'][0]['nodes']]
js.pop('extensionsUsed', None)   # GODOT_single_root : la racine n'est plus le premier nœud
# --- écriture
jb = json.dumps(js, separators=(',', ':')).encode()
while len(jb) % 4: jb += b' '
out = bytearray()
out += struct.pack('<III', 0x46546C67, 2, 12 + 8 + len(jb) + 8 + len(bin_))
out += struct.pack('<II', len(jb), 0x4E4F534A) + jb
out += struct.pack('<II', len(bin_), 0x004E4942) + bytes(bin_)
open(dst, 'wb').write(out)
print("écrit", dst, len(out), "octets")
