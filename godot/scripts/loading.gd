extends CanvasLayer
class_name LoadingScreen
## Yükleme ekranı: oyundan yakalanmış anahtar görseller yavaşça yakınlaşarak geçer (Ken Burns),
## ilk açılışta görsel yoksa neon şehir silüeti çizilir. Sol altta başlık ve bölge adı,
## sağ altta dönen shuriken, aşama yazısı ve yüzde; altta neon ilerleme çubuğu; dönen ipuçları.

const TIPS := [
	"Shift ile koşarken kamera geri çekilir, sokakları daha geniş görürsün.",
	"Gece olunca sokak lambaları, vitrinler ve Eski Çarşı'nın fenerleri kendiliğinden yanar.",
	"Bir aracın yanına gidip F'ye bas; boşluk el frenidir.",
	"C ile eğilip sessizce ilerleyebilirsin.",
	"F11 tam ekranı açıp kapatır.",
	"Kasırga Manastırı adanın kuzeyindeki dağın tepesinde. Yol Eski Çarşı'nın kuzeyinden başlar.",
	"Güvenlikli Ada'ya doğudaki kırmızı köprüden geçilir.",
	"Ayarlar > Ses bölümünden altyazıları açıp kapatabilirsin.",
	"Denize düşersen en son bastığın kıyıya geri dönersin.",
	"Ananas Smoothie'nin dev neon ananası Liman yolundan bile görünür.",
]
const CAPTIONS := ["ESKİ ÇARŞI", "SAHİL", "NEON BULVAR", "KASIRGA MANASTIRI"]
const SLIDE_T := 6.5

var bar: ProgressBar
var glow: ColorRect
var pct: Label
var stage_lbl: Label
var tip: Label
var caption: Label
var spinner: Control
var slides: Array[TextureRect] = []
var arts: Array[Texture2D] = []
var _target := 0.0
var _shown := 0.0
var _t := 0.0
var _slide := 0
var _tip_t := 0.0
var _tip_i := 0


static func cached_keyart() -> Array[Texture2D]:
	var out: Array[Texture2D] = []
	for i in range(6):
		var p := "user://keyart/k%d.jpg" % i
		if FileAccess.file_exists(p):
			var img := Image.load_from_file(p)
			if img:
				out.append(ImageTexture.create_from_image(img))
	return out


func _ready() -> void:
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	var bg := ColorRect.new()
	bg.color = Color(0.04, 0.03, 0.07)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	if Game.keyart.size() > 0:
		arts.assign(Game.keyart)
	else:
		arts = cached_keyart()
	if arts.is_empty():
		var sky := ColorRect.new()
		sky.set_anchors_preset(Control.PRESET_FULL_RECT)
		var sm := ShaderMaterial.new()
		var sh := Shader.new()
		sh.code = SKYLINE
		sm.shader = sh
		sky.material = sm
		add_child(sky)
	else:
		var holder := Control.new()
		holder.set_anchors_preset(Control.PRESET_FULL_RECT)
		holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(holder)
		for i in range(2):
			var tr := TextureRect.new()
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
			tr.set_anchors_preset(Control.PRESET_FULL_RECT)
			tr.modulate.a = 0.0
			holder.add_child(tr)
			slides.append(tr)
		slides[0].texture = arts[0]
		slides[0].modulate.a = 1.0
	var shade := ColorRect.new()
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	var gm := ShaderMaterial.new()
	var gsh := Shader.new()
	gsh.code = "shader_type canvas_item; void fragment(){ float b = smoothstep(0.35, 1.0, UV.y); float l = smoothstep(0.55, 0.0, UV.x) * 0.45; float v = length((UV - 0.5) * vec2(1.0, 0.8)); COLOR = vec4(0.03, 0.02, 0.06, clamp(b * 0.92 + l * b + smoothstep(0.45, 0.85, v) * 0.5, 0.0, 0.96)); }"
	gm.shader = gsh
	shade.material = gm
	add_child(shade)
	# başlık + bölge adı (sol alt)
	var accent := ColorRect.new()
	accent.color = Color(1.0, 0.3, 0.75)
	_anchor_bl(accent, 74, -268, 80, -190)
	add_child(accent)
	var title := Game.styled_label("NEON GÖLGELER", 104, Color.WHITE, true)
	_anchor_bl(title, 96, -292, 1000, -180)
	title.add_theme_color_override("font_shadow_color", Color(1.0, 0.2, 0.7, 0.55))
	title.add_theme_constant_override("shadow_offset_x", 5)
	title.add_theme_constant_override("shadow_offset_y", 5)
	add_child(title)
	caption = Game.styled_label("", 26, Color(0.35, 0.95, 1.0), true)
	_anchor_bl(caption, 100, -186, 800, -150)
	add_child(caption)
	tip = Game.styled_label("", 20, Color(1, 1, 1, 0.88))
	_anchor_bl(tip, 76, -128, 1100, -96)
	add_child(tip)
	_show_tip(randi() % TIPS.size())
	# shuriken + aşama + yüzde (sağ alt)
	spinner = Control.new()
	spinner.anchor_left = 1.0
	spinner.anchor_right = 1.0
	spinner.anchor_top = 1.0
	spinner.anchor_bottom = 1.0
	spinner.offset_left = -128
	spinner.offset_top = -170
	spinner.offset_right = -74
	spinner.offset_bottom = -116
	spinner.pivot_offset = Vector2(27, 27)
	spinner.draw.connect(_draw_shuriken)
	add_child(spinner)
	pct = Game.styled_label("0%", 44, Color.WHITE, true)
	pct.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_anchor_br(pct, -420, -176, -146, -118)
	add_child(pct)
	stage_lbl = Game.styled_label("Hazırlanıyor…", 18, Color(1, 1, 1, 0.75))
	stage_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_anchor_br(stage_lbl, -700, -112, -74, -88)
	add_child(stage_lbl)
	# neon ilerleme çubuğu
	bar = ProgressBar.new()
	bar.show_percentage = false
	bar.anchor_top = 1.0
	bar.anchor_bottom = 1.0
	bar.anchor_right = 1.0
	bar.offset_left = 74
	bar.offset_right = -74
	bar.offset_top = -66
	bar.offset_bottom = -60
	var fg := StyleBoxFlat.new()
	fg.bg_color = Color(1.0, 0.35, 0.78)
	fg.corner_radius_top_right = 3
	fg.corner_radius_bottom_right = 3
	fg.shadow_color = Color(1.0, 0.3, 0.8, 0.55)
	fg.shadow_size = 8
	var bgs := StyleBoxFlat.new()
	bgs.bg_color = Color(1, 1, 1, 0.1)
	bar.add_theme_stylebox_override("fill", fg)
	bar.add_theme_stylebox_override("background", bgs)
	add_child(bar)
	glow = ColorRect.new()
	glow.color = Color(0.5, 1.0, 1.0)
	glow.size = Vector2(14, 10)
	add_child(glow)
	var ver := Game.styled_label("Sürüm %d" % Game.version if Game.version > 0 else "Geliştirme sürümü", 14, Color(1, 1, 1, 0.45))
	ver.anchor_left = 1.0
	ver.anchor_right = 1.0
	ver.offset_left = -300
	ver.offset_right = -24
	ver.offset_top = 18
	ver.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(ver)
	_update_caption()


func _anchor_bl(c: Control, l: float, t: float, r: float, b: float) -> void:
	c.anchor_top = 1.0
	c.anchor_bottom = 1.0
	c.offset_left = l
	c.offset_top = t
	c.offset_right = r
	c.offset_bottom = b


func _anchor_br(c: Control, l: float, t: float, r: float, b: float) -> void:
	c.anchor_left = 1.0
	c.anchor_right = 1.0
	_anchor_bl(c, l, t, r, b)


func _process(delta: float) -> void:
	_t += delta
	_shown = move_toward(_shown, _target, delta * 0.9)
	_shown = lerpf(_shown, _target, minf(1.0, delta * 6.0))
	bar.value = _shown * 100.0
	pct.text = "%d%%" % int(round(_shown * 100.0))
	var w := bar.size.x
	glow.position = bar.global_position + Vector2(w * _shown - 7.0, -2.0)
	glow.modulate.a = 0.6 + 0.4 * sin(_t * 6.0)
	spinner.rotation += delta * 5.0
	# ipuçları
	_tip_t += delta
	if _tip_t > 7.0:
		_show_tip(_tip_i + 1)
	tip.modulate.a = minf(1.0, _tip_t * 2.0) * minf(1.0, (7.0 - _tip_t) * 2.0)
	# görsel geçişi + yavaş yakınlaşma
	if slides.size() == 2:
		var k := fmod(_t, SLIDE_T) / SLIDE_T
		var a := slides[_slide % 2]
		var s := 1.04 + k * 0.08
		a.scale = Vector2(s, s)
		a.pivot_offset = a.size * Vector2(0.5 + (0.08 if _slide % 2 == 0 else -0.08), 0.45)
		if _t > SLIDE_T * (_slide + 1) and arts.size() > 1:
			_slide += 1
			var b := slides[_slide % 2]
			b.texture = arts[_slide % arts.size()]
			b.scale = Vector2(1.04, 1.04)
			b.modulate.a = 0.0
			b.move_to_front()
			_update_caption()
		var nb := slides[_slide % 2]
		nb.modulate.a = minf(1.0, nb.modulate.a + delta * 0.9)


func _update_caption() -> void:
	if arts.is_empty():
		caption.text = "▸  ADA UYANIYOR"
	else:
		caption.text = "▸  " + CAPTIONS[_slide % arts.size() % CAPTIONS.size()]


func _show_tip(i: int) -> void:
	_tip_i = i % TIPS.size()
	_tip_t = 0.0
	tip.text = "İpucu: " + TIPS[_tip_i]


func _draw_shuriken() -> void:
	var c := Vector2(27, 27)
	var pts := PackedVector2Array()
	for k in range(8):
		var a := k * TAU / 8.0
		var r := 26.0 if k % 2 == 0 else 8.0
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	spinner.draw_colored_polygon(pts, Color(0.92, 0.94, 1.0))
	spinner.draw_polyline(pts + PackedVector2Array([pts[0]]), Color(1.0, 0.35, 0.8), 2.0, true)
	spinner.draw_circle(c, 4.0, Color(0.06, 0.05, 0.09))


func set_progress(v: float) -> void:
	_target = clampf(v, 0.0, 1.0)


func step(v: float, txt: String) -> void:
	set_progress(v)
	stage_lbl.text = txt + "…"


const SKYLINE := """
shader_type canvas_item;
float h1(float x){ return fract(sin(x * 127.1) * 43758.5453); }
void fragment(){
	vec2 uv = UV;
	float t = TIME;
	vec3 top = vec3(0.05, 0.02, 0.12);
	vec3 hor = vec3(0.55, 0.12, 0.42);
	vec3 col = mix(hor, top, smoothstep(0.62, 0.05, uv.y) * 0.0 + smoothstep(0.65, 0.0, uv.y));
	float horizon = 0.66;
	// iki kat bina silüeti
	for (int layer = 0; layer < 2; layer++){
		float fl = float(layer);
		float n = 28.0 + fl * 22.0;
		float x = uv.x * n + fl * 7.3 + t * (0.01 + fl * 0.015);
		float id = floor(x);
		float hgt = 0.12 + h1(id + fl * 31.0) * (0.32 - fl * 0.12);
		if (h1(id * 3.1 + fl) > 0.85) hgt += 0.12;
		float top_y = horizon - hgt;
		if (uv.y > top_y && uv.y < horizon){
			vec3 b = mix(vec3(0.06, 0.04, 0.1), vec3(0.02, 0.015, 0.04), fl);
			vec2 w = vec2(fract(x) * 6.0, (uv.y - top_y) * 140.0);
			float lit = step(0.55, h1(floor(w.x) + floor(w.y) * 17.0 + id * 5.0));
			float win = step(0.25, fract(w.x)) * step(0.3, fract(w.y));
			vec3 wc = mix(vec3(1.0, 0.75, 0.4), vec3(0.3, 0.9, 1.0), h1(id));
			b += wc * lit * win * (0.5 - fl * 0.25);
			if (abs(uv.y - top_y) < 0.003) b += mix(vec3(1.0, 0.2, 0.7), vec3(0.2, 1.0, 1.0), h1(id + 9.0)) * 1.5;
			col = b;
		}
	}
	// su yansıması
	if (uv.y >= horizon){
		float d = uv.y - horizon;
		vec2 ruv = vec2(uv.x + sin(uv.y * 160.0 + t * 2.0) * 0.003, horizon - d);
		vec3 refl = mix(hor, top, 0.5) * 0.35;
		refl += vec3(1.0, 0.25, 0.7) * smoothstep(0.02, 0.0, d) * 0.6;
		refl += vec3(0.2, 0.9, 1.0) * step(0.97, h1(floor(ruv.x * 90.0) + floor(d * 60.0))) * 0.4 * (1.0 - d * 3.0);
		col = refl;
	}
	// yağmur
	vec2 r = vec2(uv.x * 90.0 + uv.y * 12.0, uv.y * 6.0 - t * 3.5);
	float drop = step(0.985, h1(floor(r.x))) * smoothstep(0.0, 0.08, fract(r.y)) * (1.0 - smoothstep(0.08, 0.16, fract(r.y)));
	col += vec3(0.5, 0.6, 0.8) * drop * 0.25;
	COLOR = vec4(col, 1.0);
}
"""
