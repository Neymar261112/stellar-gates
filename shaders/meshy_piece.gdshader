shader_type spatial;
// Pièce Meshy texturée, repeinte par le preset : on lit les grandes familles de couleur de la
// texture d'origine (orange = Principale, blanc = Secondaire, noir = Structure, lumières bleues
// = Énergie) et on garde son relief et ses détails, multipliés par la couleur de chaque zone.
// Sert aussi au corps Aegis : les zones « hide » y cachent ce que recouvrent les pièces portées.

uniform sampler2D albedo_tex : source_color, hint_default_white;
uniform sampler2D normal_tex : hint_normal;
uniform sampler2D rough_tex : hint_default_white;
uniform sampler2D metal_tex : hint_default_black;
uniform bool repaint = true;          // faux : texture Meshy telle quelle
uniform vec4 z1 : source_color = vec4(0.94, 0.48, 0.16, 1.0);
uniform vec4 z2 : source_color = vec4(0.9, 0.9, 0.88, 1.0);
uniform vec4 z4 : source_color = vec4(0.16, 0.17, 0.19, 1.0);
uniform vec4 z6 : source_color = vec4(0.5, 0.8, 0.95, 1.0);
uniform vec3 zone_metal = vec3(0.3, 0.2, 0.8);   // métal des zones 1, 2, 4
uniform vec3 zone_rough = vec3(0.4, 0.5, 0.4);   // rugosité des zones 1, 2, 4
uniform float glow = 2.6;
uniform float dirt = 0.0;
uniform float scratches = 0.0;
uniform float chips = 0.0;
uniform float fade = 0.0;
uniform float noise_scale = 4.0;
uniform int hide_count = 0;           // pièces Meshy portées : zones du corps d'origine à cacher (20 au plus)
uniform mat4 hide0 = mat4(1.0);
uniform mat4 hide1 = mat4(1.0);
uniform mat4 hide2 = mat4(1.0);
uniform mat4 hide3 = mat4(1.0);
uniform mat4 hide4 = mat4(1.0);
uniform mat4 hide5 = mat4(1.0);
uniform mat4 hide6 = mat4(1.0);
uniform mat4 hide7 = mat4(1.0);
uniform mat4 hide8 = mat4(1.0);
uniform mat4 hide9 = mat4(1.0);
uniform mat4 hide10 = mat4(1.0);
uniform mat4 hide11 = mat4(1.0);
uniform mat4 hide12 = mat4(1.0);
uniform mat4 hide13 = mat4(1.0);
uniform mat4 hide14 = mat4(1.0);
uniform mat4 hide15 = mat4(1.0);
uniform mat4 hide16 = mat4(1.0);
uniform mat4 hide17 = mat4(1.0);
uniform mat4 hide18 = mat4(1.0);
uniform mat4 hide19 = mat4(1.0);
// Corps Aegis sous les pièces habillées (tools/skin_pieces.gd) : une texture par emplacement dit, pour le
// sommet n° VERTEX_ID (texel x = id % 256, y = id / 256), s'il est caché par l'armure portée (1) ou non (0).
uniform sampler2D mask_helmet : filter_nearest, hint_default_black;
uniform sampler2D mask_chest : filter_nearest, hint_default_black;
uniform sampler2D mask_arms : filter_nearest, hint_default_black;
uniform sampler2D mask_legs : filter_nearest, hint_default_black;
uniform vec4 mask_use = vec4(0.0);     // 1 = masque posé (casque, torse, bras, jambes)

#include "res://shaders/wear.gdshaderinc"

varying vec3 opos;
varying vec3 wpos;
varying float hidev;

void vertex() {
	hidev = 0.0;
	if (dot(mask_use, mask_use) > 0.0) {
		ivec2 c = ivec2(VERTEX_ID % 256, VERTEX_ID / 256);
		if (mask_use.x > 0.5) { hidev = max(hidev, texelFetch(mask_helmet, c, 0).r); }
		if (mask_use.y > 0.5) { hidev = max(hidev, texelFetch(mask_chest, c, 0).r); }
		if (mask_use.z > 0.5) { hidev = max(hidev, texelFetch(mask_arms, c, 0).r); }
		if (mask_use.w > 0.5) { hidev = max(hidev, texelFetch(mask_legs, c, 0).r); }
	}
	opos = VERTEX * noise_scale;
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	if (hidev > 0.5) {
		discard;
	}
	if (hide_count > 0) {
		bool h = in_ellipsoid(hide0, wpos);
		if (hide_count > 1) { h = h || in_ellipsoid(hide1, wpos); }
		if (hide_count > 2) { h = h || in_ellipsoid(hide2, wpos); }
		if (hide_count > 3) { h = h || in_ellipsoid(hide3, wpos); }
		if (hide_count > 4) { h = h || in_ellipsoid(hide4, wpos); }
		if (hide_count > 5) { h = h || in_ellipsoid(hide5, wpos); }
		if (hide_count > 6) { h = h || in_ellipsoid(hide6, wpos); }
		if (hide_count > 7) { h = h || in_ellipsoid(hide7, wpos); }
		if (hide_count > 8) { h = h || in_ellipsoid(hide8, wpos); }
		if (hide_count > 9) { h = h || in_ellipsoid(hide9, wpos); }
		if (hide_count > 10) { h = h || in_ellipsoid(hide10, wpos); }
		if (hide_count > 11) { h = h || in_ellipsoid(hide11, wpos); }
		if (hide_count > 12) { h = h || in_ellipsoid(hide12, wpos); }
		if (hide_count > 13) { h = h || in_ellipsoid(hide13, wpos); }
		if (hide_count > 14) { h = h || in_ellipsoid(hide14, wpos); }
		if (hide_count > 15) { h = h || in_ellipsoid(hide15, wpos); }
		if (hide_count > 16) { h = h || in_ellipsoid(hide16, wpos); }
		if (hide_count > 17) { h = h || in_ellipsoid(hide17, wpos); }
		if (hide_count > 18) { h = h || in_ellipsoid(hide18, wpos); }
		if (hide_count > 19) { h = h || in_ellipsoid(hide19, wpos); }
		if (h) {
			discard;
		}
	}
	vec3 t = texture(albedo_tex, UV).rgb;
	float mx = max(t.r, max(t.g, t.b));
	float mn = min(t.r, min(t.g, t.b));
	float sat = (mx - mn) / max(mx, 0.001);
	float lum = dot(t, vec3(0.299, 0.587, 0.114));
	// familles : orange (saturé, rouge > bleu), lumière (bleu dominant et clair), blanc (clair, peu saturé), le reste = structure
	float w1 = smoothstep(0.35, 0.55, sat) * step(t.b, t.r) * smoothstep(0.12, 0.25, mx);
	float w6 = smoothstep(0.08, 0.2, t.b - t.r) * smoothstep(0.35, 0.55, mx);
	float w2 = (1.0 - w1) * (1.0 - w6) * smoothstep(0.38, 0.6, lum) * (1.0 - smoothstep(0.3, 0.5, sat));
	float w4 = clamp(1.0 - w1 - w2 - w6, 0.0, 1.0);
	// détail : luminosité de la texture rapportée à la luminosité typique de sa famille
	float d1 = clamp(mx / 0.92, 0.25, 1.25);
	float d2 = clamp(lum / 0.82, 0.3, 1.2);
	float d4 = clamp(lum / 0.07, 0.4, 2.2);
	vec3 col = z1.rgb * d1 * w1 + z2.rgb * d2 * w2 + z4.rgb * d4 * w4 + z6.rgb * w6;
	if (!repaint) {
		col = t;
	}
	float tr = texture(rough_tex, UV).r;
	float m = zone_metal.x * w1 + zone_metal.y * w2 + zone_metal.z * w4;
	float r = mix(zone_rough.x * w1 + zone_rough.y * w2 + zone_rough.z * w4 + 0.3 * w6, tr, 0.35);
	float painted = 1.0 - w4;
	float d;
	apply_wear(col, m, r, opos, painted, fade, chips, scratches, dirt, d);
	ALBEDO = col;
	METALLIC = m;
	ROUGHNESS = r;
	NORMAL_MAP = texture(normal_tex, UV).rgb;
	EMISSION = z6.rgb * w6 * glow * (1.0 - d * 0.6);
}
