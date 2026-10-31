// Liseré lumineux de la rareté des armes (Épique, Chef-d'œuvre, Légendaire), partagé par
// weapon_meshy.gdshader (arme tenue / dans le dos) et weapon_rim.gdshader (modèle de la fiche d'objet).

float rarity_rim(vec3 p_normal, vec3 p_view, float p_time) {
	float f = pow(1.0 - clamp(dot(p_normal, p_view), 0.0, 1.0), 3.0);
	return f * (0.85 + 0.15 * sin(p_time * 2.2));
}
