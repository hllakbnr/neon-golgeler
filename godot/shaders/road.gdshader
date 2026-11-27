shader_type spatial;
// Asfalt + şerit çizgileri (çift sarı orta, beyaz kesikli, kenar) + yaya geçitleri
uniform sampler2D asph : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D asph_n : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D asph_r : hint_roughness_r, filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool has_tex = false;
uniform bool has_nor = false;
uniform bool has_rough = false;
uniform float cell = 80.0;
uniform float road_w = 12.0;
varying vec3 wpos;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) { vec2 i = floor(p), f = fract(p); f = f * f * (3.0 - 2.0 * f); return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y); }

void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }

void fragment() {
	vec2 p = wpos.xz;
	vec2 uv = p * 0.11;
	vec3 col = vec3(0.17, 0.17, 0.18) * (0.85 + 0.3 * noise(p * 0.7));
	if (has_tex) { col = texture(asph, uv).rgb * 0.8; }
	float rough = has_rough ? texture(asph_r, uv).r : 0.8;
	float hw = road_w * 0.5;
	float dx = abs(p.x - cell * round(p.x / cell));
	float dz = abs(p.y - cell * round(p.y / cell));
	bool vx = dx < hw;   // kuzey-güney yol
	bool vz = dz < hw;   // doğu-batı yol
	float paint = 0.0;
	vec3 pc = vec3(0.92);
	if (vx && !vz) {
		float dbl = step(abs(dx - 0.2), 0.07);
		float dash = step(abs(dx - hw * 0.5), 0.07) * step(0.55, fract(p.y / 6.0));
		float edge = step(abs(dx - (hw - 0.5)), 0.08);
		float cw = step(hw + 0.6, dz) * step(dz, hw + 3.8) * step(0.5, fract(p.x / 1.1));
		if (dbl > 0.0) { paint = dbl; pc = vec3(0.95, 0.72, 0.12); }
		else { paint = max(max(dash, edge), cw); }
	}
	if (vz && !vx) {
		float dbl = step(abs(dz - 0.2), 0.07);
		float dash = step(abs(dz - hw * 0.5), 0.07) * step(0.55, fract(p.x / 6.0));
		float edge = step(abs(dz - (hw - 0.5)), 0.08);
		float cw = step(hw + 0.6, dx) * step(dx, hw + 3.8) * step(0.5, fract(p.y / 1.1));
		if (dbl > 0.0) { paint = dbl; pc = vec3(0.95, 0.72, 0.12); }
		else { paint = max(max(dash, edge), cw); }
	}
	// boya aşınması
	paint *= smoothstep(0.15, 0.55, noise(p * 3.0) + 0.3);
	col = mix(col, pc * 0.85, paint);
	// lastik izleri
	float tire = (vx && !vz) ? exp(-pow((abs(dx - hw * 0.5) - 1.4) * 2.0, 2.0)) : ((vz && !vx) ? exp(-pow((abs(dz - hw * 0.5) - 1.4) * 2.0, 2.0)) : 0.0);
	col *= 1.0 - tire * 0.15;
	ALBEDO = col;
	ROUGHNESS = mix(rough, 0.6, paint);
	SPECULAR = 0.45;
	if (has_nor) { NORMAL_MAP = texture(asph_n, uv).rgb; NORMAL_MAP_DEPTH = 0.8; }
}
