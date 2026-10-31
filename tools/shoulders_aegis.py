"""Ajoute deux os d'épaule (shoulder_L / shoulder_R, entre le torse et le bras) au corps Aegis et refait les poids
des bras : l'épaulière et le haut du bras suivent maintenant le bras (avant, ils restaient collés au torse et
seul l'avant-bras bougeait). Usage : python3 tools/shoulders_aegis.py assets/solaris/aegis_rig.glb sortie.glb"""
import struct, json, sys
import numpy as np

src, dst = sys.argv[1], sys.argv[2]
d = open(src, 'rb').read()
ln = struct.unpack_from('<I', d, 12)[0]
js = json.loads(d[20:20 + ln])
off = 20 + ln
clen = struct.unpack_from('<I', d, off)[0]
bin_ = bytearray(d[off + 8:off + 8 + clen])


def view(i):
    a = js['accessors'][i]
    bv = js['bufferViews'][a['bufferView']]
    return bv.get('byteOffset', 0) + a.get('byteOffset', 0), bv.get('byteStride'), a['count']


pr = js['meshes'][0]['primitives'][0]
o, st, n = view(pr['attributes']['POSITION'])
st = st or 12
raw = np.frombuffer(bytes(bin_), np.uint8)
P = raw[o + np.arange(n)[:, None] * st + np.arange(12)[None, :]].copy().view(np.float32).reshape(-1, 3)
x, y, z = P.T
skin = js['skins'][0]
node_of = {js['nodes'][j]['name']: j for j in skin['joints']}
assert 'shoulder_L' not in node_of, "les épaules sont déjà là"

# --- nouveaux os : épaule entre le torse (0, 0.30) et le bras (±0.27, 0.55)
SH = {"L": np.array([0.12, 0.57, 0.0], np.float32), "R": np.array([-0.12, 0.57, 0.0], np.float32)}
UP = {"L": np.array([0.27, 0.55, 0.0], np.float32), "R": np.array([-0.27, 0.55, 0.0], np.float32)}
CHEST = np.array([0.0, 0.30, 0.0], np.float32)
chest_n = node_of['chest']
for s in "LR":
    up_n = node_of['upper_arm_' + s]
    js['nodes'][chest_n]['children'].remove(up_n)
    js['nodes'].append({"name": "shoulder_" + s, "translation": [float(v) for v in SH[s] - CHEST], "children": [up_n]})
    new_n = len(js['nodes']) - 1
    js['nodes'][chest_n]['children'].append(new_n)
    js['nodes'][up_n]['translation'] = [float(v) for v in UP[s] - SH[s]]
    skin['joints'].append(new_n)
    node_of['shoulder_' + s] = new_n
names = [js['nodes'][j]['name'] for j in skin['joints']]
bi = {nm: i for i, nm in enumerate(names)}

# inverse bind matrices : os sans rotation, translation seule (position globale de repos)
def gpos(nm):
    if nm.startswith("shoulder_"):
        return SH[nm[-1]]
    return None

oi, _, ni = view(skin['inverseBindMatrices'])
ibm = np.frombuffer(bytes(bin_[oi:oi + ni * 64]), np.float32).reshape(-1, 16).copy()
extra = []
for s in "LR":
    M = np.eye(4, dtype=np.float32)
    M[:3, 3] = -SH[s]
    extra.append(M.T.flatten())
ibm = np.vstack([ibm, np.array(extra)])

# --- poids
B = {"hips": (0, -0.03, 0), "spine": (0, 0.10, 0), "chest": (0, 0.30, 0), "neck": (0, 0.66, 0), "head": (0, 0.74, 0),
     "shoulder_L": (0.12, 0.57, 0), "upper_arm_L": (0.27, 0.55, 0), "forearm_L": (0.35, 0.29, 0), "hand_L": (0.38, 0.01, 0),
     "hand_L_tip": (0.40, -0.24, 0), "thigh_L": (0.12, -0.06, 0), "shin_L": (0.20, -0.48, 0), "foot_L": (0.24, -0.82, 0),
     "foot_L_tip": (0.25, -0.95, 0.08)}
for k in list(B):
    if "_L" in k:
        v = B[k]
        B[k.replace("_L", "_R")] = (-v[0], v[1], v[2])
B = {k: np.array(v, np.float32) for k, v in B.items()}


def seg(a, b):
    dd = b - a
    u = np.clip(((P - a) @ dd) / float(dd @ dd), 0, 1)
    return np.linalg.norm(P - (a + u[:, None] * dd), axis=1)


def smooth(a, lo, hi):
    t = np.clip((a - lo) / (hi - lo), 0, 1)
    return t * t * (3 - 2 * t)


W = np.zeros((n, len(names)), np.float32)
# Torse : colonne elliptique (plus large que profonde), plus étroite au niveau des épaules
Q = P.copy()
Q[:, 0] /= 1.55
yc = np.clip(y, -0.05, 0.62)
narrow = 0.155 - 0.03 * smooth(y, 0.38, 0.5)
dT = np.sqrt(Q[:, 0] ** 2 + Q[:, 2] ** 2 + (y - yc) ** 2) - narrow
arm_masks = {}
for s in "LR":
    up, fo, ha, tip = B["upper_arm_" + s], B["forearm_" + s], B["hand_" + s], B["hand_" + s + "_tip"]
    d_up, d_fo, d_ha = seg(up, fo), seg(fo, ha), seg(ha, tip)
    # rayons : épaulière et biceps épais, avant-bras moyen, main fine
    dA = np.minimum(np.minimum(d_up - 0.12, d_fo - 0.09), d_ha - 0.075)
    side = (x >= 0) if s == "L" else (x < 0)
    dL = np.minimum(seg(B["thigh_" + s], B["shin_" + s]), seg(B["shin_" + s], B["foot_" + s])) - 0.10
    m = smooth(dT - dA, -0.01, 0.02) * smooth(dL - dA, -0.006, 0.012) * side * (y > -0.27)
    # l'épaulière (au-dessus et en dehors de l'articulation) part avec le bras
    pad = smooth(np.abs(x), 0.17, 0.23) * smooth(y, 0.45, 0.52) * side
    m = np.maximum(m, pad)
    m = np.where(y < 0.2, (m > 0.5).astype(np.float32), m)   # sous l'aisselle : bras ou corps, pas de mélange
    D = np.stack([d_up, d_fo, d_ha], 1)
    wa = 1.0 / (D + 0.01) ** 6
    wa /= wa.sum(1, keepdims=True)
    # près de l'articulation, une part va à l'épaule (qui fait le lien avec le torse)
    near = np.linalg.norm(P - up, axis=1)
    to_sh = (1.0 - smooth(near, 0.06, 0.2)) * 0.45
    W[:, bi["shoulder_" + s]] += m * wa[:, 0] * to_sh
    W[:, bi["upper_arm_" + s]] += m * wa[:, 0] * (1 - to_sh)
    W[:, bi["forearm_" + s]] += m * wa[:, 1]
    W[:, bi["hand_" + s]] += m * wa[:, 2]
    arm_masks[s] = m
arm_m = arm_masks["L"] + arm_masks["R"]
leg_m = smooth(-y, 0.02, 0.12) * (1 - arm_m)
tor_m = np.clip(1 - arm_m - leg_m, 0, 1)
t_hips = 1 - smooth(y, 0.0, 0.08)
t_spine = smooth(y, 0.0, 0.08) * (1 - smooth(y, 0.20, 0.30))
t_chest = smooth(y, 0.20, 0.30) * (1 - smooth(y, 0.62, 0.68))
t_neck = smooth(y, 0.62, 0.68) * (1 - smooth(y, 0.72, 0.77))
t_head = smooth(y, 0.72, 0.77)
# haut du torse sur les côtés (trapèzes) : partagé entre le torse et l'épaule
for s in "LR":
    side = (x >= 0) if s == "L" else (x < 0)
    trap = smooth(np.abs(x), 0.08, 0.17) * smooth(y, 0.42, 0.52) * (1 - smooth(y, 0.66, 0.72)) * side * 0.6
    W[:, bi["shoulder_" + s]] += tor_m * t_chest * trap
    t_chest = t_chest * (1 - trap)
for nm, t in (("hips", t_hips), ("spine", t_spine), ("chest", t_chest), ("neck", t_neck), ("head", t_head)):
    W[:, bi[nm]] += tor_m * t
for s in "LR":
    side = (x >= 0) if s == "L" else (x < 0)
    D = np.stack([seg(B["thigh_" + s], B["shin_" + s]), seg(B["shin_" + s], B["foot_" + s]), seg(B["foot_" + s], B["foot_" + s + "_tip"])], 1)
    wl = 1.0 / (D + 0.01) ** 6
    wl /= wl.sum(1, keepdims=True)
    for k, nm in enumerate(["thigh_" + s, "shin_" + s, "foot_" + s]):
        W[:, bi[nm]] += leg_m * side * wl[:, k]
W /= np.maximum(W.sum(1, keepdims=True), 1e-6)
top = np.argsort(-W, axis=1)[:, :4]
J = top.astype(np.uint16)
Wt = np.take_along_axis(W, top, axis=1).astype(np.float32)
Wt /= np.maximum(Wt.sum(1, keepdims=True), 1e-6)
for s in "LR":
    print("bras", s, ":", int((arm_masks[s] > 0.5).sum()), "sommets ; épaule", s, ":", int((W[:, bi["shoulder_" + s]] > 0.2).sum()))

# --- réécrit JOINTS_0 / WEIGHTS_0 en place, ajoute les nouvelles matrices
for key, arr in (("JOINTS_0", J), ("WEIGHTS_0", Wt)):
    o2, st2, n2 = view(pr['attributes'][key])
    a = js['accessors'][pr['attributes'][key]]
    assert n2 == n and (st2 is None or st2 == arr.itemsize * 4) and a['componentType'] == (5123 if key == "JOINTS_0" else 5126)
    bin_[o2:o2 + arr.nbytes] = arr.tobytes()
# Le maillage Meshy est soudé entre la main et la cuisse : les triangles qui relient le bras au reste du corps
# sous l'aisselle deviennent des fils étirés quand le bras bouge. On les écrase (triangles vides).
arm_ids = [bi[nm] for nm in names if "arm" in nm or "hand" in nm]
arm_dom = np.isin(J[:, 0], arm_ids)
ia = js['accessors'][pr['indices']]
o3, _, n3 = view(pr['indices'])
it = {5123: np.uint16, 5125: np.uint32}[ia['componentType']]
I = np.frombuffer(bytes(bin_[o3:o3 + n3 * np.dtype(it).itemsize]), it).reshape(-1, 3).copy()
A = arm_dom[I]
low = (P[I][:, :, 1] < 0.36).all(1)
edge = np.max(np.linalg.norm(P[I] - np.roll(P[I], 1, axis=1), axis=2), axis=1)
cut = A.any(1) & ~A.all(1) & (low | (edge > 0.06))
I[cut] = I[cut][:, :1]
bin_[o3:o3 + I.nbytes] = I.tobytes()
print("triangles coupés :", int(cut.sum()), "sur", len(I))
while len(bin_) % 4:
    bin_.append(0)
m_off = len(bin_)
bin_ += ibm.astype(np.float32).tobytes()
js['bufferViews'].append({"buffer": 0, "byteOffset": m_off, "byteLength": ibm.nbytes})
js['accessors'].append({"bufferView": len(js['bufferViews']) - 1, "componentType": 5126, "count": len(ibm), "type": "MAT4"})
skin['inverseBindMatrices'] = len(js['accessors']) - 1
js['buffers'][0]['byteLength'] = len(bin_)
jb = json.dumps(js, separators=(',', ':')).encode()
while len(jb) % 4:
    jb += b' '
out = bytearray()
out += struct.pack('<III', 0x46546C67, 2, 12 + 8 + len(jb) + 8 + len(bin_))
out += struct.pack('<II', len(jb), 0x4E4F534A) + jb
out += struct.pack('<II', len(bin_), 0x004E4942) + bytes(bin_)
open(dst, 'wb').write(out)
print("écrit", dst, len(out), "octets,", len(names), "os")
