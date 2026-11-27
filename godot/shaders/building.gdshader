shader_type spatial;
// Bina cephesi: dünya-konumlu doku + prosedürel pencereler/vitrinler; gece yanan ışıklar
global uniform float night;
uniform sampler2D wall_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D wall_nor : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool has_tex = false;
uniform bool has_nor = false;
uniform vec4 tint : source_color = vec4(1.0);
uniform vec4 trim : source_color = vec4(0.92, 0.9, 0.86, 1.0);
uniform float tex_scale = 0.3;
uniform float floor_h = 3.4;
uniform float win_w = 2.4;
uniform float ground_h = 4.6;
uniform float glass_amt = 0.0; // 1 = cam kule
instance uniform float seed = 0.0;
varying vec3 wpos;
varying vec3 wnor;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnor = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	bool side = abs(wnor.y) < 0.5;
	float hz = abs(wnor.x) > 0.5 ? wpos.z : wpos.x;
	vec2 uv = side ? vec2(hz, wpos.y) * tex_scale : wpos.xz * tex_scale;
	vec3 base = tint.rgb;
	if (has_tex) { base *= texture(wall_tex, uv).rgb * 1.2; }
	float rough = 0.85;
	float metal = 0.0;
	vec3 emit = vec3(0.0);
	float win_any = 0.0;
	if (side && wpos.y > 0.2) {
		float y = wpos.y;
		if (y < ground_h) {
			float cx = fract(hz / 5.0);
			float inside = step(0.06, cx) * step(cx, 0.94) * step(0.45, y) * step(y, ground_h - 1.0);
			float mull = step(abs(fract(hz / 1.25) - 0.5), 0.03) * inside;            // cam çerçeveleri
			float band = step(ground_h - 0.9, y);
			float lit = hash(vec2(floor(hz / 5.0), seed));
			// iç mekân hissi: raflar / tavan ışığı bandı
			float shelf = step(0.5, fract(y * 1.6)) * 0.12;
			float ceil = smoothstep(ground_h - 1.4, ground_h - 1.0, y);
			vec3 interior = mix(vec3(0.35, 0.3, 0.26), vec3(0.2, 0.24, 0.3), step(0.6, lit)) * (0.6 + shelf) + ceil * vec3(0.5, 0.46, 0.4);
			base = mix(base, vec3(0.02, 0.025, 0.03), inside);
			rough = mix(rough, 0.03, inside);
			metal = mix(metal, 0.1, inside);
			emit += inside * (1.0 - mull) * interior * mix(0.02, 0.18, night) * step(0.15, lit);
			base = mix(base, vec3(0.12), mull);
			base = mix(base, trim.rgb * 0.85, band);
			win_any = inside;
		} else {
			float fy = (y - ground_h) / floor_h;
			vec2 cell = vec2(floor(hz / win_w), floor(fy));
			vec2 f = vec2(fract(hz / win_w), fract(fy));
			float ww = mix(0.15, 0.03, glass_amt);
			float win = step(ww, f.x) * step(f.x, 1.0 - ww) * step(mix(0.22, 0.05, glass_amt), f.y) * step(f.y, 0.88);
			float frame = (1.0 - win) * step(0.1, f.x) * step(f.x, 0.9) * step(0.17, f.y) * step(f.y, 0.92);
			float r = hash(cell + vec2(seed, seed * 1.7));
			vec3 glass = mix(vec3(0.05, 0.07, 0.1), vec3(0.2, 0.28, 0.36), r * 0.6 + glass_amt * 0.3);
			base = mix(base, glass, win);
			base = mix(base, trim.rgb, frame * 0.55 * (1.0 - glass_amt));
			rough = mix(rough, 0.03, win);
			metal = mix(metal, 0.35, win);
			float lit = step(0.5, r) * win;
			emit += lit * night * mix(vec3(1.0, 0.78, 0.5), vec3(0.75, 0.85, 1.0), step(0.78, r)) * 1.3;
			base *= 1.0 - win * 0.25 * (1.0 - f.y);
			win_any = win;
		}
	}
	if (!side && wnor.y > 0.5) { base = trim.rgb * 0.5; rough = 0.9; }
	ALBEDO = base;
	ROUGHNESS = rough;
	METALLIC = metal;
	SPECULAR = 0.5;
	EMISSION = emit;
	if (has_nor && side && win_any < 0.5) { NORMAL_MAP = texture(wall_nor, uv).rgb; }
}
