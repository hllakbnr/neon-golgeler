shader_type spatial;
// Şehir dışı yollar: UV boyunca şerit çizgileri (otoyolda çift sarı orta), kenar çizgileri, aşınma
uniform sampler2D asph : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D asph_n : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool has_tex = false;
uniform bool has_nor = false;
uniform bool highway = false;
global uniform float night;
varying vec3 wpos;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) { vec2 i = floor(p), f = fract(p); f = f * f * (3.0 - 2.0 * f); return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y); }

void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }

void fragment() {
	vec2 uvw = wpos.xz * 0.11;
	vec3 col = vec3(0.17, 0.17, 0.18) * (0.85 + 0.3 * noise(wpos.xz * 0.7));
	if (has_tex) { col = texture(asph, uvw).rgb * 0.8; }
	float u = UV.x;
	float v = UV.y;
	float paint = 0.0;
	vec3 pc = vec3(0.92);
	if (u < 0.0 || u > 1.0) {          // etek: toprak/beton
		col = vec3(0.32, 0.28, 0.24);
	} else {
		float edge = step(abs(u - 0.04), 0.012) + step(abs(u - 0.96), 0.012);
		float center;
		if (highway) {
			center = step(abs(u - 0.488), 0.008) + step(abs(u - 0.512), 0.008);
			if (center > 0.0) { pc = vec3(0.95, 0.72, 0.12); }
		} else {
			center = step(abs(u - 0.5), 0.01) * step(0.5, fract(v * 0.6));
		}
		paint = clamp(edge + center, 0.0, 1.0);
		if (center > 0.0 && highway) { paint = 1.0; }
		else if (center > 0.0) { pc = vec3(0.95); }
		paint *= smoothstep(0.15, 0.55, noise(wpos.xz * 3.0) + 0.3);
		col = mix(col, pc * 0.85, paint);
		float tire = exp(-pow((abs(u - 0.5) - 0.25) * 18.0, 2.0));
		col *= 1.0 - tire * 0.12;
	}
	float wet = night * 0.6;
	col *= 1.0 - wet * 0.3;
	ALBEDO = col;
	ROUGHNESS = mix(mix(0.82, 0.6, paint), 0.25, wet);
	SPECULAR = 0.45;
	if (has_nor) { NORMAL_MAP = texture(asph_n, uvw).rgb; NORMAL_MAP_DEPTH = 0.8; }
}
