shader_type canvas_item;
// Ayarlar ekranı: mor → pembe çapraz gradyan + hafif doku
uniform vec4 a : source_color = vec4(0.36, 0.17, 0.45, 1.0);
uniform vec4 b : source_color = vec4(0.62, 0.32, 0.55, 1.0);
void fragment() {
	float t = clamp(UV.x * 0.65 + (1.0 - UV.y) * 0.45, 0.0, 1.0);
	vec3 c = mix(a.rgb, b.rgb, t);
	c *= 0.96 + 0.04 * sin(UV.y * 900.0);
	COLOR = vec4(c, 1.0);
}
