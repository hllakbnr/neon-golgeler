extends CanvasLayer
class_name LoadingScreen
## Yükleme ekranı: oyundan yakalanmış "anahtar görseller" eğik panellerde, başlık, ipucu, ilerleme.

const TIPS := [
	"İpucu: Shift ile koşarken kamera geri çekilir, sokakları daha geniş görürsün.",
	"İpucu: Gece olunca sokak lambaları ve vitrinler kendiliğinden yanar. T ile zamanı hızlandır.",
	"İpucu: Bir aracın yanına gidip F'ye bas; boşluk el frenidir.",
	"Neon Şehir'de gece hiç bitmez, ışıklar hiç sönmez.",
]
var bar: ProgressBar
var tip: Label
var arts: Array = []


func _ready() -> void:
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	var bg := ColorRect.new()
	bg.color = Color(0.06, 0.05, 0.09)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var vp := Vector2(1600, 900)
	var n := maxi(1, Game.keyart.size())
	for i in range(3):
		var tex: Texture2D = Game.keyart[i % n] if Game.keyart.size() > 0 else null
		var clip := Control.new()
		clip.clip_contents = true
		clip.position = Vector2(-80 + i * 560, -60)
		clip.size = Vector2(600, 1040)
		clip.rotation = 0.06
		add_child(clip)
		var tr := TextureRect.new()
		tr.texture = tex
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		tr.size = Vector2(1000, 1040)
		tr.position = Vector2(-200 - i * 40, 0)
		clip.add_child(tr)
		arts.append(tr)
		var edge := ColorRect.new()
		edge.color = Color(0.06, 0.05, 0.09)
		edge.position = Vector2(590, 0)
		edge.size = Vector2(14, 1040)
		clip.add_child(edge)
	var shade := ColorRect.new()
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	var gm := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = "shader_type canvas_item; void fragment(){ float t = smoothstep(0.45, 1.0, UV.y); COLOR = vec4(0.04,0.03,0.07, t*0.92); }"
	gm.shader = sh
	shade.material = gm
	add_child(shade)
	var title := Game.styled_label("NEON GÖLGELER", 84, Color.WHITE, true)
	title.anchor_top = 1.0
	title.anchor_bottom = 1.0
	title.offset_left = 70
	title.offset_top = -230
	title.add_theme_color_override("font_shadow_color", Color(0.9, 0.3, 0.7, 0.6))
	title.add_theme_constant_override("shadow_offset_x", 4)
	title.add_theme_constant_override("shadow_offset_y", 4)
	add_child(title)
	tip = Game.styled_label(TIPS[randi() % TIPS.size()], 20, Color(1, 1, 1, 0.85))
	tip.anchor_top = 1.0
	tip.anchor_bottom = 1.0
	tip.offset_left = 74
	tip.offset_right = 1100
	tip.offset_top = -120
	add_child(tip)
	bar = ProgressBar.new()
	bar.show_percentage = false
	bar.anchor_top = 1.0
	bar.anchor_bottom = 1.0
	bar.anchor_right = 1.0
	bar.offset_left = 74
	bar.offset_right = -74
	bar.offset_top = -70
	bar.offset_bottom = -64
	var fg := StyleBoxFlat.new()
	fg.bg_color = Color(0.95, 0.45, 0.75)
	var bgs := StyleBoxFlat.new()
	bgs.bg_color = Color(1, 1, 1, 0.12)
	bar.add_theme_stylebox_override("fill", fg)
	bar.add_theme_stylebox_override("background", bgs)
	add_child(bar)


func _process(delta: float) -> void:
	for i in arts.size():
		var tr: TextureRect = arts[i]
		tr.position.x -= delta * (6.0 + i * 2.0)


func set_progress(v: float) -> void:
	bar.value = v * 100.0
