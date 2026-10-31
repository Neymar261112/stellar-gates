"""Ajoute un squelette humanoïde et des poids de peau au GLB du Solaris (pose en A, face +Z).
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

# --- os : nom, parent, position (espace modèle)
BONES = [
    ("hips", None, (0, -0.15, 0)),
    ("spine", "hips", (0, 0.02, 0)),
    ("chest", "spine", (0, 0.22, 0)),
    ("neck", "chest", (0, 0.70, 0)),
    ("head", "neck", (0, 0.78, 0)),
    ("upper_arm_L", "chest", (0.27, 0.56, 0)),
    ("forearm_L", "upper_arm_L", (0.40, 0.22, 0)),
    ("hand_L", "forearm_L", (0.42, 0.0, 0)),
    ("upper_arm_R", "chest", (-0.27, 0.56, 0)),
    ("forearm_R", "upper_arm_R", (-0.40, 0.22, 0)),
    ("hand_R", "forearm_R", (-0.42, 0.0, 0)),
    ("thigh_L", "hips", (0.15, -0.15, 0)),
    ("shin_L", "thigh_L", (0.16, -0.38, 0)),
    ("foot_L", "shin_L", (0.17, -0.78, 0)),
    ("thigh_R", "hips", (-0.15, -0.15, 0)),
    ("shin_R", "thigh_R", (-0.16, -0.38, 0)),
    ("foot_R", "shin_R", (-0.17, -0.78, 0)),
]
names = [b[0] for b in BONES]
bi = {nm: i for i, nm in enumerate(names)}

def smooth(a, lo, hi):
    t = np.clip((a - lo) / (hi - lo), 0, 1)
    return t * t * (3 - 2 * t)

W = np.zeros((n, len(BONES)), dtype=np.float32)
ax = np.abs(x)
side_L = x >= 0
# Régions
arm_bound = np.where(y > 0.42, 0.33, 0.30)
is_arm = (ax > arm_bound - 0.03) & (y > -0.22) & (y < 0.68)
arm_mix = smooth(ax, arm_bound - 0.03, arm_bound + 0.03)      # 0 = torse, 1 = bras
is_leg = y < -0.12
leg_mix = smooth(-y, 0.12, 0.19)                               # 0 = hanches, 1 = jambe

# Torse (par hauteur, avec fondus)
t_hips = 1 - smooth(y, -0.04, 0.04)
t_spine = smooth(y, -0.04, 0.04) * (1 - smooth(y, 0.18, 0.26))
t_chest = smooth(y, 0.18, 0.26) * (1 - smooth(y, 0.66, 0.74))
t_neck = smooth(y, 0.66, 0.74) * (1 - smooth(y, 0.75, 0.81))
t_head = smooth(y, 0.75, 0.81)
torso = np.zeros_like(W)
torso[:, bi["hips"]] = t_hips
torso[:, bi["spine"]] = t_spine
torso[:, bi["chest"]] = t_chest
torso[:, bi["neck"]] = t_neck
torso[:, bi["head"]] = t_head

# Bras (par hauteur le long du bras en A)
a_up = 1 - smooth(-y, -0.27, -0.17)                 # au-dessus du coude (y > 0.22)
a_fore = smooth(-y, -0.27, -0.17) * (1 - smooth(-y, -0.04, 0.04))
a_hand = smooth(-y, -0.04, 0.04)
arm = np.zeros_like(W)
for s, suf in ((side_L, "_L"), (~side_L, "_R")):
    arm[s, bi["upper_arm" + suf]] = a_up[s]
    arm[s, bi["forearm" + suf]] = a_fore[s]
    arm[s, bi["hand" + suf]] = a_hand[s]

# Jambes
l_thigh = 1 - smooth(-y, 0.34, 0.42)
l_shin = smooth(-y, 0.34, 0.42) * (1 - smooth(-y, 0.75, 0.81))
l_foot = smooth(-y, 0.75, 0.81)
leg = np.zeros_like(W)
for s, suf in ((side_L, "_L"), (~side_L, "_R")):
    leg[s, bi["thigh" + suf]] = l_thigh[s]
    leg[s, bi["shin" + suf]] = l_shin[s]
    leg[s, bi["foot" + suf]] = l_foot[s]

W = torso.copy()
m = is_arm
W[m] = torso[m] * (1 - arm_mix[m])[:, None] + arm[m] * arm_mix[m][:, None]
m = is_leg
hipsW = np.zeros_like(W); hipsW[:, bi["hips"]] = 1.0
W[m] = hipsW[m] * (1 - leg_mix[m])[:, None] + leg[m] * leg_mix[m][:, None]
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
js['nodes'][mesh_node]['skin'] = 0
js['nodes'][mesh_node]['name'] = 'SolarisMesh'
# la scène : racine armature contenant le maillage et la racine des os
arm_node = {"name": "SolarisArmature", "children": [mesh_node, base]}
js['nodes'].append(arm_node)
js['scenes'][0]['nodes'] = [len(js['nodes']) - 1]
# --- écriture
jb = json.dumps(js, separators=(',', ':')).encode()
while len(jb) % 4: jb += b' '
out = bytearray()
out += struct.pack('<III', 0x46546C67, 2, 12 + 8 + len(jb) + 8 + len(bin_))
out += struct.pack('<II', len(jb), 0x4E4F534A) + jb
out += struct.pack('<II', len(bin_), 0x004E4942) + bytes(bin_)
open(dst, 'wb').write(out)
print("écrit", dst, len(out), "octets")
