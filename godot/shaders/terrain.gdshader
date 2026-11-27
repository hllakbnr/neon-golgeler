shader_type spatial;
// Kıta arazisi: renk köşe renginden (biyom: çimen/kum/çöl/kaya/kar), dünya-konumlu ayrıntı dokusu,
// a kanalı = kaya oranı. Kıyıya yakın alçak yerler ıslak.
uniform sampler2D grass_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool has_grass = false;
uniform sampler2D rock_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool has_rock = false;
varying vec3 wpos;
varying vec4 vcol;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) { vec2 i = floor(p), f = fract(p); f = f * f * (3.0 - 2.0 * f); return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y); }

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vcol = COLOR;
}

void fragment() {
	vec2 uv = wpos.xz * 0.12;
	float n = noise(wpos.xz * 0.05) * 0.6 + noise(wpos.xz * 0.4) * 0.4;
	vec3 base = vcol.rgb;
	float lum = dot(base, vec3(0.33));
	// çimen ayrıntısı (yalnızca yeşil zeminde belirgin)
	float greenish = clamp((base.g - max(base.r, base.b)) * 6.0, 0.0, 1.0);
	vec3 detail = vec3(0.85 + 0.3 * n);
	if (has_grass) { detail = mix(detail, texture(grass_tex, uv).rgb / vec3(0.32, 0.42, 0.2) * 0.55, greenish); }
	vec3 col = base * mix(vec3(0.9 + 0.2 * n), detail, greenish);
	// kaya
	float rk = vcol.a;
	vec3 rockd = vec3(0.8 + 0.4 * noise(wpos.xz * 0.9 + wpos.y * 0.3));
	if (has_rock) { rockd = texture(rock_tex, vec2(wpos.x + wpos.z, wpos.y) * 0.05).rgb * 1.6; }
	col = mix(col, base * rockd, rk * 0.8);
	// ıslak kıyı
	float wet = 1.0 - smoothstep(-0.9, 0.4, wpos.y + (n - 0.5) * 0.4);
	col = mix(col, col * 0.62, wet);
	ALBEDO = col;
	ROUGHNESS = mix(mix(0.92, 0.8, rk), 0.35, wet);
	SPECULAR = 0.3;
}
