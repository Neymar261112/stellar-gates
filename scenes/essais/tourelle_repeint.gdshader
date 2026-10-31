shader_type spatial;
// Essai tourelle Hunyuan3D, repeinte comme les pièces de la Forge : on garde le relief de la texture
// d'origine et on remplace ses familles de couleur (clair = Principale, sombre = Secondaire, saturé = Accent).
// Seuils réglés sur la texture de la tourelle (gris clair ~0.6, gris sombre ~0.15, orange vif).

uniform sampler2D albedo_tex : hint_default_white;   // lu en sRGB brut pour classer, linéarisé pour l'affichage
uniform bool repaint = true;          // faux : texture d'origine
uniform vec4 primary : source_color = vec4(0.9, 0.9, 0.88, 1.0);
uniform vec4 secondary : source_color = vec4(0.1, 0.1, 0.11, 1.0);
uniform vec4 accent : source_color = vec4(0.94, 0.48, 0.16, 1.0);
uniform float accent_glow = 0.0;      // > 0 : l'accent éclaire (Ombre)
uniform float metallic = 0.5;
uniform float roughness = 0.45;

void fragment() {
	vec3 t = texture(albedo_tex, UV).rgb;
	float mx = max(t.r, max(t.g, t.b));
	float mn = min(t.r, min(t.g, t.b));
	float sat = (mx - mn) / max(mx, 0.001);
	float lum = dot(t, vec3(0.299, 0.587, 0.114));
	float wa = smoothstep(0.3, 0.45, sat) * smoothstep(0.28, 0.4, mx);
	float wp = (1.0 - wa) * smoothstep(0.28, 0.42, lum);
	float ws = clamp(1.0 - wa - wp, 0.0, 1.0);
	// détail : luminosité de la texture rapportée à celle, typique, de sa famille
	float da = clamp(mx / 0.75, 0.45, 1.25);
	float dp = clamp(lum / 0.6, 0.55, 1.2);
	float ds = clamp(lum / 0.16, 0.5, 1.6);
	vec3 col = primary.rgb * dp * wp + secondary.rgb * ds * ws + accent.rgb * da * wa;
	if (!repaint) {
		col = pow(t, vec3(2.2));
	}
	ALBEDO = col;
	METALLIC = metallic;
	ROUGHNESS = roughness;
	EMISSION = repaint ? accent.rgb * wa * accent_glow : vec3(0.0);
}
