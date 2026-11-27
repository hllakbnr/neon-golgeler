shader_type spatial;
render_mode unshaded, cull_disabled;
// Birleştirilmiş neon şeritler: renk köşe renginde, faz UV.x'te
global uniform float night;
uniform float power = 5.0;

void fragment() {
	float ph = UV.x;
	float flick = 0.92 + 0.08 * sin(TIME * 23.0 + ph * 7.0) * step(0.85, fract(ph * 13.1));
	float on = mix(0.35, power, smoothstep(0.15, 0.6, night)) * flick;
	ALBEDO = COLOR.rgb * on;
}
