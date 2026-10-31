"""Recalcule les poids de peau de aegis_rig.glb : les bras sont séparés du torse et des hanches par
la distance aux os (et non plus par un plan vertical), pour éviter les bandes étirées entre bras et jambes."""
import struct, json, numpy as np, sys
src, dst = sys.argv[1], sys.argv[2]
d = bytearray(open(src, 'rb').read())
ln = struct.unpack_from('<I', d, 12)[0]
js = json.loads(d[20:20 + ln]); boff = 20 + ln + 8
def view(i):
    a = js['accessors'][i]; bv = js['bufferViews'][a['bufferView']]
    return boff + bv.get('byteOffset', 0) + a.get('byteOffset', 0), bv.get('byteStride'), a['count']
pr = js['meshes'][0]['primitives'][0]
o, st, n = view(pr['attributes']['POSITION'])
st = st or 12
raw = np.frombuffer(bytes(d), np.uint8)
P = raw[o + np.arange(n)[:, None] * st + np.arange(12)[None, :]].copy().view(np.float32).reshape(-1, 3)
x, y, z = P.T
names = [js['nodes'][j]['name'] for j in js['skins'][0]['joints']]
bi = {nm: i for i, nm in enumerate(names)}
B = {"hips": (0, -0.03, 0), "spine": (0, 0.10, 0), "chest": (0, 0.30, 0), "neck": (0, 0.66, 0), "head": (0, 0.74, 0),
     "upper_arm_L": (0.27, 0.55, 0), "forearm_L": (0.35, 0.29, 0), "hand_L": (0.38, 0.01, 0), "hand_L_tip": (0.40, -0.24, 0),
     "thigh_L": (0.12, -0.06, 0), "shin_L": (0.20, -0.48, 0), "foot_L": (0.24, -0.82, 0), "foot_L_tip": (0.25, -0.95, 0.08)}
for k in list(B):
    if k.endswith("_L") or k.endswith("_L_tip"):
        v = B[k]; B[k.replace("_L", "_R")] = (-v[0], v[1], v[2])
B = {k: np.array(v, np.float32) for k, v in B.items()}

def seg(a, b):
    dd = b - a
    u = np.clip(((P - a) @ dd) / float(dd @ dd), 0, 1)
    return np.linalg.norm(P - (a + u[:, None] * dd), axis=1)

def smooth(a, lo, hi):
    t = np.clip((a - lo) / (hi - lo), 0, 1)
    return t * t * (3 - 2 * t)

W = np.zeros((n, len(names)), np.float32)
# Torse : colonne elliptique (plus large que profonde)
Q = P.copy(); Q[:, 0] /= 1.55
yc = np.clip(y, -0.05, 0.62)
dT = np.sqrt(Q[:, 0] ** 2 + Q[:, 2] ** 2 + (y - yc) ** 2) - 0.155
for s in "LR":
    up, fo, ha, tip = B["upper_arm_" + s], B["forearm_" + s], B["hand_" + s], B["hand_" + s + "_tip"]
    d_up, d_fo, d_ha = seg(up, fo), seg(fo, ha), seg(ha, tip)
    dA = np.minimum(np.minimum(d_up, d_fo), d_ha) - 0.075
    side = (x >= 0) if s == "L" else (x < 0)
    # bras = plus proche du bras que du torse ; près de l'épaule on mélange avec le buste
    dL = np.minimum(seg(B["thigh_" + s], B["shin_" + s]), seg(B["shin_" + s], B["foot_" + s])) - 0.10
    m = smooth(dT - dA, -0.006, 0.012) * smooth(dL - dA, -0.006, 0.012) * side * (y > -0.27)
    near_sh = np.linalg.norm(P - up, axis=1)
    m *= 0.35 + 0.65 * smooth(near_sh, 0.05, 0.16)
    m = np.where(y < 0.2, (m > 0.5).astype(np.float32), m)   # sous l'aisselle : bras ou corps, pas de mélange
    D = np.stack([d_up, d_fo, d_ha], 1)
    wa = 1.0 / (D + 0.01) ** 6; wa /= wa.sum(1, keepdims=True)
    for k, nm in enumerate(["upper_arm_" + s, "forearm_" + s, "hand_" + s]):
        W[:, bi[nm]] += m * wa[:, k]
    if s == "L":
        armL = m
    else:
        armR = m
arm_m = armL + armR
leg_m = smooth(-y, 0.02, 0.12) * (1 - arm_m)
tor_m = 1 - arm_m - leg_m
t_hips = 1 - smooth(y, 0.0, 0.08)
t_spine = smooth(y, 0.0, 0.08) * (1 - smooth(y, 0.20, 0.30))
t_chest = smooth(y, 0.20, 0.30) * (1 - smooth(y, 0.62, 0.68))
t_neck = smooth(y, 0.62, 0.68) * (1 - smooth(y, 0.72, 0.77))
t_head = smooth(y, 0.72, 0.77)
for nm, t in (("hips", t_hips), ("spine", t_spine), ("chest", t_chest), ("neck", t_neck), ("head", t_head)):
    W[:, bi[nm]] += tor_m * t
for s in "LR":
    side = (x >= 0) if s == "L" else (x < 0)
    D = np.stack([seg(B["thigh_" + s], B["shin_" + s]), seg(B["shin_" + s], B["foot_" + s]), seg(B["foot_" + s], B["foot_" + s + "_tip"])], 1)
    wl = 1.0 / (D + 0.01) ** 6; wl /= wl.sum(1, keepdims=True)
    for k, nm in enumerate(["thigh_" + s, "shin_" + s, "foot_" + s]):
        W[:, bi[nm]] += leg_m * side * wl[:, k]
W /= np.maximum(W.sum(1, keepdims=True), 1e-6)

# --- Casque rigide : chaque pièce du casque (menton et bas du visage compris) suit la tête à 100 %,
# sinon elle est partagée avec le cou et s'étire quand la tête tourne.
ia = js['accessors'][pr['indices']]
o3, st3, n3 = view(pr['indices'])
it = {5123: np.uint16, 5125: np.uint32}[ia['componentType']]
tri = np.frombuffer(bytes(d[o3:o3 + n3 * np.dtype(it).itemsize]), it).astype(np.int64).reshape(-1, 3)
par = np.arange(n)
def find(a):
    r = a
    while par[r] != r:
        r = par[r]
    while par[a] != r:
        par[a], a = r, par[a]
    return r
for a, b, c in tri:
    for p, q in ((a, b), (b, c)):
        rp, rq = find(p), find(q)
        if rp != rq:
            par[rp] = rq
_, isl = np.unique([find(v) for v in range(n)], return_inverse=True)
for k in range(isl.max() + 1):
    m = isl == k
    ws = W[m].mean(0)
    if ws[bi["head"]] + ws[bi["neck"]] < 0.5 or ws[bi["head"]] <= 0.02:
        continue
    if y[m].mean() >= 0.70 or (y[m].max() >= 0.745 and z[m].mean() > 0.04):
        W[m] = 0
        W[m, bi["head"]] = 1
# Bouts de doigts devant la cuisse : pondérés sur cuisse / hanches, ils restaient en l'air quand le bras bougeait.
for k in range(isl.max() + 1):
    m = isl == k
    if m.sum() > 40:
        continue
    ws = W[m].mean(0)
    top = names[int(np.argmax(ws))]
    if top.startswith(("thigh", "hips")) and abs(x[m].mean()) > 0.28 and z[m].mean() > 0.12 and -0.13 < y[m].mean() < -0.06:
        W[m] = 0
        W[m, bi["hand_L" if x[m].mean() > 0 else "hand_R"]] = 1

top = np.argsort(-W, axis=1)[:, :4]
J = top.astype(np.uint16)
Wt = np.take_along_axis(W, top, axis=1).astype(np.float32)
Wt /= np.maximum(Wt.sum(1, keepdims=True), 1e-6)
np.save('P.npy', P); np.save('dom.npy', np.array([names[j] for j in J[:, 0]]))
for key, arr in (("JOINTS_0", J), ("WEIGHTS_0", Wt)):
    o2, st2, n2 = view(pr['attributes'][key])
    a = js['accessors'][pr['attributes'][key]]
    assert n2 == n and (st2 is None or st2 == arr.itemsize * 4) and a['componentType'] == (5123 if key == "JOINTS_0" else 5126)
    d[o2:o2 + arr.nbytes] = arr.tobytes()
open(dst, 'wb').write(d)
print("ok", dst, "bras L/R:", int((armL > 0.5).sum()), int((armR > 0.5).sum()))

# --- Le maillage Meshy est soudé entre la main et la cuisse : les triangles qui relient le bras au reste
# du corps sous l'aisselle deviennent des bandes étirées quand le bras bouge. On les écrase (triangles vides).
arm_dom = np.isin(J[:, 0], [bi[nm] for nm in names if "arm" in nm or "hand" in nm])
ia = js['accessors'][pr['indices']]
o3, st3, n3 = view(pr['indices'])
it = {5123: np.uint16, 5125: np.uint32}[ia['componentType']]
I = np.frombuffer(bytes(d[o3:o3 + n3 * np.dtype(it).itemsize]), it).reshape(-1, 3).copy()
A = arm_dom[I]
low = (P[I][:, :, 1] < 0.32).all(1)
cut = A.any(1) & ~A.all(1) & low
I[cut] = I[cut][:, :1]
d[o3:o3 + I.nbytes] = I.tobytes()
open(dst, 'wb').write(d)
print("triangles coupés :", int(cut.sum()), "sur", len(I))
