shader_type canvas_item;
// Menü arka planı: bulanık oyun sahnesi + koyu/mor tonlama
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float lod = 3.5;
uniform vec4 tint : source_color = vec4(0.18, 0.08, 0.3, 0.45);
void fragment() {
	vec3 c = textureLod(screen_tex, SCREEN_UV, lod).rgb;
	c = mix(c, tint.rgb, tint.a);
	COLOR = vec4(c, 1.0);
}
