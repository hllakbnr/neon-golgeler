shader_type sky;
// Gün/gece gökyüzü: renk geçişi, güneş/ay diski, hareketli bulutlar, yıldızlar
uniform vec3 top_col = vec3(0.18, 0.38, 0.75);
uniform vec3 hor_col = vec3(0.75, 0.85, 0.95);
uniform vec3 ground_col = vec3(0.25, 0.24, 0.26);
uniform float night_f = 0.0;
uniform float cloud_cov = 0.42;
uniform float cloud_t = 0.0;

float hash3(vec3 p) { return fract(sin(dot(p, vec3(12.9898, 78.233, 37.719))) * 43758.5453); }
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) { vec2 i = floor(p), f = fract(p); f = f * f * (3.0 - 2.0 * f); return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y); }
float fbm(vec2 p) { float v = 0.0, a = 0.5; for (int i = 0; i < 5; i++) { v += a * noise(p); p *= 2.03; a *= 0.5; } return v; }

void sky() {
	vec3 d = EYEDIR;
	float y = d.y;
	vec3 col = mix(hor_col, top_col, pow(clamp(y, 0.0, 1.0), 0.45));
	if (y < 0.0) { col = mix(hor_col, ground_col, clamp(-y * 5.0, 0.0, 1.0)); }
	if (LIGHT0_ENABLED) {
		float s = max(dot(d, LIGHT0_DIRECTION), 0.0);
		col += LIGHT0_COLOR * LIGHT0_ENERGY * (pow(s, 1500.0) * 30.0 + pow(s, 12.0) * 0.35 * (1.0 - night_f));
	}
	if (y > 0.0 && !AT_CUBEMAP_PASS) {
		vec2 uv = d.xz / (y + 0.12) * 1.3 + vec2(cloud_t * 0.01, cloud_t * 0.004);
		float c = fbm(uv);
		c = smoothstep(1.0 - cloud_cov, 1.0 - cloud_cov + 0.32, c);
		vec3 lit = mix(vec3(1.0), hor_col * 1.15, 0.35) * mix(1.0, 0.07, night_f);
		vec3 shade = mix(lit * 0.62, top_col * 0.5, 0.3);
		vec3 cc = mix(lit, shade, smoothstep(0.4, 0.9, fbm(uv * 1.7 + 3.0)));
		col = mix(col, cc, c * smoothstep(0.0, 0.18, y) * 0.92);
	}
	if (night_f > 0.01 && y > 0.0) {
		vec3 cell = floor(d * 320.0);
		float st = step(0.9982, hash3(cell)) * (0.5 + 0.5 * hash3(cell + 7.0));
		col += vec3(st) * night_f * smoothstep(0.02, 0.25, y);
	}
	COLOR = col;
}
