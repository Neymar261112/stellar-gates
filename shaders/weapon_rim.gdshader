shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, shadows_disabled, fog_disabled;
// Liseré de rareté posé par-dessus le matériau d'origine d'une arme (material_overlay) :
// le modèle 3D qui tourne dans la fiche d'objet (Forge, menu).

uniform vec4 rim_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float rim = 0.0;

#include "res://shaders/weapon_rim.gdshaderinc"

void fragment() {
	ALBEDO = rim_color.rgb * rim * rarity_rim(NORMAL, VIEW, TIME);
}
