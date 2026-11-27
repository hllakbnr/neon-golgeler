shader_type spatial;
// Deniz: kayan dalga normalleri; derinlik arazi yükseklik dokusundan → kıyıda açık turkuaz ve köpük,
// açıkta lacivert; gece neon yansımaları (SSR)
global uniform float night;
uniform sampler2D height_tex : filter_linear;
uniform vec4 world_rect = vec4(-1700.0, -1900.0, 5200.0, 6600.0);
uniform float sea_y = -1.2;
varying vec3 wpos;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) { vec2 i = floor(p), f = fract(p); f = f * f * (3.0 - 2.0 * f); return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y); }

float ground(vec2 p) {
	vec2 uv = (p - world_rect.xy) / world_rect.zw;
	if (uv.x < 0.0 || uv.y < 0.0 || uv.x > 1.0 || uv.y > 1.0) { return -60.0; }
	return texture(height_tex, uv).r;
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float d = clamp((sea_y - ground(wpos.xz)) / 6.0, 0.0, 1.0);
	VERTEX.y += (sin(wpos.x * 0.08 + TIME * 0.9) * 0.18 + sin(wpos.z * 0.11 + TIME * 1.3) * 0.12) * d;
}

void fragment() {
	vec2 p = wpos.xz;
	float t = TIME;
	float n1 = noise(p * 0.35 + vec2(t * 0.25, t * 0.1));
	float n2 = noise(p * 0.9 - vec2(t * 0.2, t * 0.35));
	float depth = sea_y - ground(p);
	vec3 deep = mix(vec3(0.02, 0.14, 0.24), vec3(0.01, 0.02, 0.06), night);
	vec3 mid = mix(vec3(0.04, 0.32, 0.42), vec3(0.02, 0.05, 0.1), night);
	vec3 shallow = mix(vec3(0.22, 0.62, 0.6), vec3(0.05, 0.1, 0.14), night);
	vec3 col = mix(shallow, mid, smoothstep(0.3, 4.0, depth));
	col = mix(col, deep, smoothstep(4.0, 22.0, depth));
	float foam = smoothstep(0.9, 0.1, depth) * smoothstep(0.45, 0.8, n1 + 0.25 * sin(t * 1.5 + p.x * 0.2));
	ALBEDO = col + foam * mix(0.7, 0.15, night);
	ROUGHNESS = 0.04 + n2 * 0.05 + foam * 0.5;
	METALLIC = 0.0;
	SPECULAR = 0.7;
	NORMAL_MAP = normalize(vec3(n1 - 0.5, n2 - 0.5, 1.6)) * 0.5 + 0.5;
	NORMAL_MAP_DEPTH = 0.6;
}
