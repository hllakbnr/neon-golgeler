shader_type spatial;
render_mode cull_disabled;
// Palmiye yaprağı: UV'den tüy biçimli kesik (alpha scissor) + rüzgârda salınım
uniform vec4 col : source_color = vec4(0.22, 0.4, 0.14, 1.0);
void vertex() {
	float w = sin(TIME * 1.3 + NODE_POSITION_WORLD.x * 0.3 + VERTEX.x) * 0.06 * UV.y;
	VERTEX.y += w;
}
void fragment() {
	float x = abs(UV.x - 0.5) * 2.0;
	float leaflet = 0.5 + 0.5 * sin(UV.y * 70.0);
	float width = (1.0 - UV.y * 0.85) * mix(0.35, 1.0, leaflet);
	if (x > width || UV.y < 0.04 && x > 0.15) { discard; }
	vec3 c = col.rgb * mix(0.8, 1.15, UV.y) * mix(0.75, 1.0, x);
	ALBEDO = c;
	ROUGHNESS = 0.7;
	SPECULAR = 0.35;
	BACKLIGHT = vec3(0.25, 0.35, 0.1);
}
