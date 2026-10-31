// Bruit et usure partagés par exosuit.gdshader (pièces simples, corps) et meshy_piece.gdshader (pièces Meshy).

float hash(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float noise(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(i + vec3(0, 0, 0)), hash(i + vec3(1, 0, 0)), f.x),
	               mix(hash(i + vec3(0, 1, 0)), hash(i + vec3(1, 1, 0)), f.x), f.y),
	           mix(mix(hash(i + vec3(0, 0, 1)), hash(i + vec3(1, 0, 1)), f.x),
	               mix(hash(i + vec3(0, 1, 1)), hash(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

float fbm(vec3 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * noise(p);
		p *= 2.03;
		a *= 0.5;
	}
	return v;
}

// Délavé, peinture écaillée, rayures, saleté : peints par-dessus la couleur avec du bruit.
void apply_wear(inout vec3 col, inout float p_met, inout float p_rgh, vec3 p_pos, float painted,
		float p_fade, float p_chips, float p_scratches, float p_dirt, out float d) {
	float lum = dot(col, vec3(0.333));
	col = mix(col, vec3(lum) * 0.9 + vec3(0.06, 0.05, 0.03), p_fade * 0.55);
	float c = smoothstep(0.6, 0.64, fbm(p_pos * 7.0 + 3.1)) * p_chips * painted;
	col = mix(col, vec3(0.52, 0.53, 0.55), c);
	p_met = mix(p_met, 0.95, c);
	p_rgh = mix(p_rgh, 0.38, c);
	float s = noise(vec3(p_pos.x * 70.0 + p_pos.z * 30.0, p_pos.y * 3.0, p_pos.z * 70.0 - p_pos.x * 20.0));
	float sc = smoothstep(0.86, 0.9, s) * p_scratches;
	col = mix(col, vec3(0.78, 0.78, 0.76), sc * 0.85);
	p_rgh = mix(p_rgh, 0.3, sc);
	d = smoothstep(0.35, 0.75, fbm(p_pos * 3.0 + 7.7)) * p_dirt;
	col = mix(col, vec3(0.16, 0.13, 0.1), d * 0.8);
	p_rgh = mix(p_rgh, 1.0, d);
	p_met = mix(p_met, 0.1, d * 0.7);
}

// Masque : le corps d'origine disparaît dans des ellipsoïdes quand une pièce Meshy le remplace
// (tête sous le casque, bras sous les bras Meshy). Jusqu'à 8 zones.
bool in_ellipsoid(mat4 p_inv, vec3 p_wpos) {
	return length((p_inv * vec4(p_wpos, 1.0)).xyz) < 1.0;
}
