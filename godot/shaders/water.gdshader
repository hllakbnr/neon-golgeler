shader_type spatial;
// Deniz: kayan dalga normalleri, kıyıya yakın açık renk, gece neon yansımaları (SSR)
global uniform float night;
varying vec3 wpos;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) { vec2 i = floor(p), f = fract(p); f = f * f * (3.0 - 2.0 * f); return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y); }

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	VERTEX.y += sin(wpos.x * 0.08 + TIME * 0.9) * 0.18 + sin(wpos.z * 0.11 + TIME * 1.3) * 0.12;
}

void fragment() {
	vec2 p = wpos.xz;
	float t = TIME;
	float n1 = noise(p * 0.35 + vec2(t * 0.25, t * 0.1));
	float n2 = noise(p * 0.9 - vec2(t * 0.2, t * 0.35));
	vec3 deep = mix(vec3(0.02, 0.16, 0.24), vec3(0.01, 0.02, 0.06), night);
	vec3 shallow = mix(vec3(0.1, 0.45, 0.5), vec3(0.03, 0.06, 0.12), night);
	float shore = smoothstep(80.0, 0.0, wpos.z - 255.0);
	ALBEDO = mix(deep, shallow, shore * 0.7);
	ROUGHNESS = 0.04 + n2 * 0.05;
	METALLIC = 0.0;
	SPECULAR = 0.7;
	NORMAL_MAP = normalize(vec3(n1 - 0.5, n2 - 0.5, 1.6)) * 0.5 + 0.5;
	NORMAL_MAP_DEPTH = 0.6;
	float foam = smoothstep(0.75, 0.95, n1) * smoothstep(12.0, 0.0, wpos.z - 255.0);
	ALBEDO += foam * 0.6;
}
