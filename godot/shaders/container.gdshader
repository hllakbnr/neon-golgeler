shader_type spatial;
// Yük konteyneri: oluklu yan sac, kapı ucunda dikey çubuk ve menteşeler, pas ve kir, renk örnekten
varying vec3 lpos;
varying vec3 lnor;
varying vec3 tint;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) { vec2 i = floor(p), f = fract(p); f = f * f * (3.0 - 2.0 * f); return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y); }

void vertex() {
	lpos = VERTEX;
	lnor = NORMAL;
	tint = COLOR.rgb;
}

void fragment() {
	vec3 base = tint;
	float rib = 0.0;
	vec2 uv;
	if (abs(lnor.x) > 0.5) {          // uzun yanlar: oluk z boyunca
		rib = sin(lpos.z * 22.0);
		uv = vec2(lpos.z, lpos.y);
		NORMAL_MAP = normalize(vec3(cos(lpos.z * 22.0) * 0.45, 0.0, 1.0)) * 0.5 + 0.5;
	} else if (abs(lnor.z) > 0.5) {   // uçlar: kapı panelleri
		rib = sin(lpos.x * 14.0);
		uv = vec2(lpos.x, lpos.y);
		NORMAL_MAP = normalize(vec3(cos(lpos.x * 14.0) * 0.3, 0.0, 1.0)) * 0.5 + 0.5;
		float seam = step(abs(lpos.x), 0.02);
		base *= 1.0 - seam * 0.6;
	} else {                          // tavan: hafif oluk
		uv = lpos.xz;
		NORMAL_MAP = normalize(vec3(0.0, cos(lpos.z * 9.0) * 0.2, 1.0)) * 0.5 + 0.5;
	}
	NORMAL_MAP_DEPTH = 1.0;
	float n = noise(uv * 3.0) * 0.6 + noise(uv * 11.0) * 0.4;
	float rust = smoothstep(0.62, 0.82, n) * 0.6 + smoothstep(0.05, 0.0, abs(uv.y + 1.2)) * 0.2;
	vec3 col = mix(base, vec3(0.38, 0.2, 0.1), rust * 0.55);
	col *= 0.85 + 0.15 * rib;
	col *= 0.9 + 0.1 * noise(uv * 0.7);
	// alt kenarda kir
	col *= mix(0.65, 1.0, smoothstep(-1.3, -0.6, lpos.y));
	ALBEDO = col;
	ROUGHNESS = mix(0.55, 0.9, rust);
	METALLIC = 0.35;
}
