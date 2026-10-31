// Impression de vitesse : flou radial sur les bords de l'image (course, vol, boost, esquive).
// Le centre (le perso et la visée) reste net.
shader_type spatial;
render_mode unshaded, depth_test_disabled, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear, repeat_disable;
uniform float amount = 0.0;

void vertex() {
	POSITION = vec4(VERTEX.xy * 2.0, 0.0, 1.0);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 d = uv - vec2(0.45, 0.5);
	float m = smoothstep(0.12, 0.55, length(d)) * amount;
	vec3 col = vec3(0.0);
	for (int i = 0; i < 10; i++) {
		float t = float(i) / 9.0;
		col += texture(screen_tex, uv - d * m * t * 0.14).rgb;
	}
	ALBEDO = col / 10.0;
	ALPHA = clamp(m * 2.5, 0.0, 1.0);
}
