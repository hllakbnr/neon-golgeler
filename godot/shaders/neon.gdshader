shader_type spatial;
render_mode unshaded, cull_disabled;
// Neon tüp / şerit: gündüz sönük renkli plastik, gece parlak (hafif titreşim)
global uniform float night;
instance uniform vec4 neon_col : source_color = vec4(1.0, 0.2, 0.8, 1.0);
instance uniform float phase = 0.0;
uniform float power = 5.0;

void fragment() {
	float flick = 0.92 + 0.08 * sin(TIME * 23.0 + phase * 7.0) * step(0.85, fract(phase * 13.1));
	float on = mix(0.35, power, smoothstep(0.15, 0.6, night)) * flick;
	ALBEDO = neon_col.rgb * on;
}
