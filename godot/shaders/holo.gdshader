shader_type spatial;
render_mode unshaded, cull_disabled, blend_add, depth_draw_never;
// Holografik reklam panosu: kayan tarama çizgileri, yumuşak şekiller, renk geçişi
global uniform float night;
instance uniform vec4 col_a : source_color = vec4(0.1, 0.9, 1.0, 1.0);
instance uniform vec4 col_b : source_color = vec4(1.0, 0.2, 0.8, 1.0);
instance uniform float kind = 0.0;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

void fragment() {
	vec2 uv = UV;
	float t = TIME * 0.35 + kind * 3.1;
	vec3 c = mix(col_a.rgb, col_b.rgb, 0.5 + 0.5 * sin(uv.y * 3.0 + t * 2.0));
	float shape;
	if (kind < 0.5) {            // halkalar
		float d = length(uv - vec2(0.5));
		shape = smoothstep(0.02, 0.0, abs(fract(d * 4.0 - t) - 0.5) - 0.18) * step(d, 0.48);
	} else if (kind < 1.5) {     // ananas silueti (yuvarlak gövde + yapraklar)
		vec2 q = uv - vec2(0.5, 0.42);
		float body = step(length(q * vec2(1.2, 0.9)), 0.26);
		float leaf = step(abs(uv.x - 0.5 + sin(uv.y * 30.0) * 0.03), (0.95 - uv.y) * 0.25) * step(0.62, uv.y) * step(uv.y, 0.95);
		float grid = step(0.85, fract((q.x + q.y) * 18.0)) + step(0.85, fract((q.x - q.y) * 18.0));
		shape = clamp(body * (0.65 + 0.35 * grid) + leaf, 0.0, 1.0);
	} else {                     // ekolayzır çubukları
		float bx = floor(uv.x * 12.0);
		float h = 0.25 + 0.6 * abs(sin(t * 3.0 + bx * 1.7)) * hash(vec2(bx, floor(t * 4.0)));
		shape = step(uv.y, h) * step(0.15, fract(uv.x * 12.0)) * step(fract(uv.x * 12.0), 0.85);
	}
	float scan = 0.75 + 0.25 * sin(uv.y * 220.0 - TIME * 12.0);
	float frame = step(uv.x, 0.015) + step(0.985, uv.x) + step(uv.y, 0.02) + step(0.98, uv.y);
	float glitch = step(0.97, hash(vec2(floor(TIME * 8.0), kind)));
	float a = (shape * scan + frame * 0.8 + 0.06) * (1.0 - glitch * 0.6);
	ALBEDO = c * a * mix(1.2, 3.2, night);
}
