shader_type spatial;
// Ada arazisi: kumsal (alçak), çimen, eğimli yerlerde kaya; dünya-konumlu doku
uniform sampler2D grass_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool has_grass = false;
uniform sampler2D rock_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool has_rock = false;
varying vec3 wpos;
varying vec3 wnor;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) { vec2 i = floor(p), f = fract(p); f = f * f * (3.0 - 2.0 * f); return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y); }

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnor = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec2 uv = wpos.xz * 0.12;
	float n = noise(wpos.xz * 0.05) * 0.6 + noise(wpos.xz * 0.4) * 0.4;
	vec3 grass = vec3(0.32, 0.48, 0.2) * (0.8 + 0.4 * n);
	if (has_grass) { grass = texture(grass_tex, uv).rgb * vec3(0.85, 1.0, 0.8); }
	vec3 rock = vec3(0.45, 0.43, 0.42) * (0.75 + 0.5 * n);
	if (has_rock) { rock = texture(rock_tex, uv * 0.5).rgb * 0.9; }
	vec3 sand = vec3(0.9, 0.8, 0.6) * (0.9 + 0.2 * n);
	vec3 wet = vec3(0.55, 0.46, 0.33);
	float slope = 1.0 - clamp(wnor.y, 0.0, 1.0);
	float y = wpos.y + (n - 0.5) * 0.8;
	vec3 col = grass;
	col = mix(col, rock, smoothstep(0.32, 0.5, slope));
	col = mix(col, sand, 1.0 - smoothstep(1.2, 2.4, y));
	col = mix(col, wet, 1.0 - smoothstep(-0.9, -0.2, y));
	ALBEDO = col;
	ROUGHNESS = mix(0.9, 0.6, 1.0 - smoothstep(-0.9, -0.2, y));
	SPECULAR = 0.3;
}
