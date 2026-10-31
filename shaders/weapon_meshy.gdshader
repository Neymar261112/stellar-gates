shader_type spatial;
// Arme Meshy : les textures d'origine telles quelles (couleur, métal, rugosité, relief), sans la
// peinture du preset. Seules les lumières de l'arme prennent la couleur Énergie (zone 6), et un
// liseré discret montre la rareté de l'exemplaire.

uniform sampler2D albedo_tex : source_color, hint_default_white;
uniform sampler2D normal_tex : hint_normal;
uniform sampler2D rough_tex : hint_default_white;
uniform sampler2D metal_tex : hint_default_black;
uniform vec4 energy : source_color = vec4(0.5, 0.8, 0.95, 1.0);
uniform int lights = 0;               // lumières de la texture : 0 aucune, 1 froides (bleu, vert), 2 chaudes (orange)
uniform float glow = 2.6;
uniform vec4 rim_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float rim = 0.0;              // 0 = pas de liseré (Commun, Peu commun, Rare)

#include "res://shaders/weapon_rim.gdshaderinc"

void fragment() {
	vec3 t = texture(albedo_tex, UV).rgb;
	float mx = max(t.r, max(t.g, t.b));
	float mn = min(t.r, min(t.g, t.b));
	float sat = (mx - mn) / max(mx, 0.001);
	float w = 0.0;
	if (lights == 1) {
		w = smoothstep(0.08, 0.2, max(t.g, t.b) - t.r) * smoothstep(0.35, 0.55, sat) * smoothstep(0.4, 0.6, mx);
	} else if (lights == 2) {
		w = smoothstep(0.45, 0.65, sat) * smoothstep(0.5, 0.7, mx) * step(t.b, t.r);
	}
	ALBEDO = mix(t, energy.rgb, w * 0.7);
	METALLIC = texture(metal_tex, UV).r;
	ROUGHNESS = texture(rough_tex, UV).r;
	NORMAL_MAP = texture(normal_tex, UV).rgb;
	EMISSION = energy.rgb * w * glow + rim_color.rgb * rim * rarity_rim(NORMAL, VIEW, TIME);
}
