shader_type spatial;
// Terrain de la cinématique « montagne » : herbe sur le plat, roche grise sur les pentes raides,
// taches plus claires sur les hauteurs.

uniform vec3 herbe : source_color = vec3(0.23, 0.46, 0.17);
uniform vec3 herbe_claire : source_color = vec3(0.42, 0.62, 0.26);
uniform vec3 roche : source_color = vec3(0.47, 0.47, 0.46);

varying vec3 wpos;
varying vec3 wnor;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnor = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	float n = noise(wpos.xz * 0.05) * 0.6 + noise(wpos.xz * 0.23) * 0.4;
	float pente = 1.0 - clamp(wnor.y, 0.0, 1.0);
	float r = smoothstep(0.30, 0.55, pente + (n - 0.5) * 0.25);
	vec3 vert = mix(herbe, herbe_claire, smoothstep(0.3, 0.8, n) * smoothstep(5.0, 60.0, wpos.y) + 0.15 * n);
	ALBEDO = mix(vert, roche, r);
	ROUGHNESS = 0.95;
}
