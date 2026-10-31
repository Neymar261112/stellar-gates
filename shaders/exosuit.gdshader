shader_type spatial;
// Matériau unique des pièces du Solaris : une zone = une couleur + un type de matériau,
// et l'usure (saleté, rayures, peinture écaillée, délavé) peinte par-dessus avec du bruit.
// Le même matériau sert au corps, aux pièces, à l'arme : tout suit le preset actif.

uniform vec4 base_color : source_color = vec4(1.0);
uniform bool use_tex = false;
uniform sampler2D albedo_tex : source_color, hint_default_white;
uniform bool use_normal = false;
uniform sampler2D normal_tex : hint_normal;
uniform float metallic : hint_range(0.0, 1.0) = 0.5;
uniform float roughness : hint_range(0.0, 1.0) = 0.5;
uniform int pattern = 0;              // 0 lisse, 1 brossé, 2 carbone, 3 tissu
uniform float glow = 0.0;             // émission (zone Énergie)
uniform float dirt = 0.0;
uniform float scratches = 0.0;
uniform float chips = 0.0;
uniform float fade = 0.0;
uniform float noise_scale = 1.0;      // le corps du Solaris est plus grand que les pièces
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

#include "res://shaders/wear.gdshaderinc"

varying vec3 opos;
varying vec3 wpos;

void vertex() {
	opos = VERTEX * noise_scale;
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
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
	vec3 col = base_color.rgb;
	if (use_tex) {
		col *= texture(albedo_tex, UV).rgb * 1.15;
	}
	float met = metallic;
	float rgh = roughness;
	// Motif du type de matériau
	if (pattern == 1) {
		float b = noise(vec3(opos.x * 6.0, opos.y * 260.0, opos.z * 6.0));
		rgh = clamp(rgh + (b - 0.5) * 0.25, 0.02, 1.0);
		col *= 0.92 + b * 0.12;
	} else if (pattern == 2) {
		vec2 q = (opos.xy + opos.zy) * 90.0;
		float w = step(0.5, fract(q.x * 0.5 + step(0.5, fract(q.y * 0.5)) * 0.5));
		col *= 0.75 + w * 0.35;
		rgh = mix(rgh, rgh * 0.6, w);
	} else if (pattern == 3) {
		float a = sin((opos.x + opos.y) * 420.0) * sin((opos.z - opos.y) * 420.0);
		col *= 0.85 + a * 0.12;
	}
	float painted = 1.0 - step(0.7, metallic);
	float d;
	apply_wear(col, met, rgh, opos, painted, fade, chips, scratches, dirt, d);

	ALBEDO = col;
	METALLIC = met;
	ROUGHNESS = rgh;
	if (use_normal) {
		NORMAL_MAP = texture(normal_tex, UV).rgb;
	}
	EMISSION = base_color.rgb * glow * (1.0 - d * 0.6);
}
