extends Control
## An illustrated stand-in for a simulated person's photo. Real members show uploaded photos.
## Kinds: 0 golden-hour portrait, 1 in their element (by first interest), 2 travel shot.

const Avatar = preload("res://scripts/avatar.gd")

var person := {}
var kind := 0
var _t := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _quad(r: Rect2, c0: Color, c1: Color) -> void:
	draw_polygon(PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]),
		PackedColorArray([c0, c0, c1, c1]))


func _bokeh(rng: RandomNumberGenerator, cols: Array, n: int) -> void:
	for i in n:
		var p := Vector2(rng.randf() * size.x, rng.randf() * size.y * 0.75)
		var r := rng.randf_range(8, 34)
		var c: Color = cols[i % cols.size()]
		draw_circle(p, r, Color(c, 0.18))
		draw_circle(p, r * 0.7, Color(c, 0.12))


func _draw() -> void:
	var s := size
	if s.x < 4.0:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(str(person.get("id", "")) + str(kind))
	var cfg: Dictionary = person.get("cfg", {})
	match kind:
		0:
			_quad(Rect2(Vector2.ZERO, s), Color("#F0A37A"), Color("#7A3B5C"))
			_bokeh(rng, [Color("#FFE2B0"), Color("#FFB38A"), Color("#FFFFFF")], 18)
			var sc := s.y * 1.55 / 300.0
			Avatar.draw(self, cfg, Vector2(s.x * 0.5, s.y * 0.4 - Avatar.HEAD.y * sc), sc, 1.0)
		1:
			_scene(rng, str(person.get("cats", ["outdoors"])[0]))
			var sc := s.y * 0.72 / 300.0
			Avatar.draw(self, cfg, Vector2(s.x * 0.5, s.y * 0.92), sc, 2.0)
		_:
			_quad(Rect2(0, 0, s.x, s.y * 0.55), Color("#8EC5E8"), Color("#F6D7B8"))
			var far := PackedVector2Array([Vector2(0, s.y * 0.55)])
			for i in 9:
				far.append(Vector2(s.x * i / 8.0, s.y * (0.38 + 0.08 * sin(i * 1.7 + rng.randf()))))
			far.append(Vector2(s.x, s.y * 0.55))
			draw_colored_polygon(far, Color("#7C8FA8"))
			_quad(Rect2(0, s.y * 0.55, s.x, s.y * 0.45), Color("#3F7FA6"), Color("#22506E"))
			for i in 6:
				draw_line(Vector2(rng.randf() * s.x, s.y * (0.6 + i * 0.06)), Vector2(rng.randf() * s.x, s.y * (0.6 + i * 0.06)), Color(1, 1, 1, 0.25), 1.5)
			_quad(Rect2(0, s.y * 0.86, s.x, s.y * 0.14), Color("#C9B08E"), Color("#9E8466"))
			Avatar.draw(self, cfg, Vector2(s.x * 0.62, s.y * 0.96), s.y * 0.42 / 300.0, 3.0)
	# Finish: warm grade, vignette, a little grain.
	draw_rect(Rect2(Vector2.ZERO, s), Color(1.0, 0.75, 0.55, 0.05))
	for k in 10:
		var inset := float(k) * 6.0
		draw_rect(Rect2(Vector2(inset, inset), s - Vector2(inset, inset) * 2.0), Color(0, 0, 0, 0.035), false, 6.0)
	for i in 220:
		draw_rect(Rect2(rng.randf() * s.x, rng.randf() * s.y, 1, 1), Color(1, 1, 1, 0.06))


func _scene(rng: RandomNumberGenerator, cat: String) -> void:
	var s := size
	match cat:
		"food", "culture":
			_quad(Rect2(Vector2.ZERO, s), Color("#5A3A2E"), Color("#2E1E1A"))
			for i in 5:
				var x := s.x * (0.1 + i * 0.2)
				draw_rect(Rect2(x - 18, s.y * 0.12, 36, s.y * 0.5), Color("#3F2A22"))
				for j in 6:
					draw_rect(Rect2(x - 14, s.y * (0.14 + j * 0.08), 28, 4), Color("#E8C69B", 0.5) if cat == "culture" else Color("#B98B5E", 0.4))
			_bokeh(rng, [Color("#FFD38A")], 10)
			draw_rect(Rect2(0, s.y * 0.8, s.x, s.y * 0.2), Color("#3A261F"))
		"music", "nightlife", "gaming":
			_quad(Rect2(Vector2.ZERO, s), Color("#24143A"), Color("#0E0A18"))
			var cols := [Color("#B57BFF"), Color("#FF6FB1"), Color("#5FD4FF")]
			for i in 4:
				var x := s.x * (0.15 + i * 0.25)
				draw_colored_polygon(PackedVector2Array([Vector2(x, 0), Vector2(x - 60, s.y * 0.8), Vector2(x + 60, s.y * 0.8)]), Color(cols[i % 3], 0.12))
			_bokeh(rng, cols, 16)
		"sports":
			_quad(Rect2(0, 0, s.x, s.y * 0.6), Color("#9ED3F0"), Color("#E6F1F2"))
			_quad(Rect2(0, s.y * 0.6, s.x, s.y * 0.4), Color("#C4553F"), Color("#9A3C2E"))
			for i in 4:
				draw_line(Vector2(0, s.y * (0.68 + i * 0.08)), Vector2(s.x, s.y * (0.66 + i * 0.08)), Color(1, 1, 1, 0.7), 2.0)
		"art":
			_quad(Rect2(Vector2.ZERO, s), Color("#F2EEE8"), Color("#DDD6CC"))
			draw_rect(Rect2(s.x * 0.12, s.y * 0.14, s.x * 0.3, s.y * 0.3), Color("#E46C4C"))
			draw_rect(Rect2(s.x * 0.58, s.y * 0.1, s.x * 0.28, s.y * 0.38), Color("#2F4C7A"))
			draw_circle(Vector2(s.x * 0.72, s.y * 0.29), s.x * 0.07, Color("#F2C14E"))
			draw_rect(Rect2(0, s.y * 0.82, s.x, s.y * 0.18), Color("#B9AE9F"))
		"wellness":
			_quad(Rect2(Vector2.ZERO, s), Color("#E9E2D3"), Color("#CDC2AA"))
			for i in 7:
				var x := rng.randf() * s.x
				draw_colored_polygon(PackedVector2Array([Vector2(x, s.y * 0.8), Vector2(x - 14, s.y * 0.55), Vector2(x, s.y * 0.35), Vector2(x + 14, s.y * 0.55)]), Color("#6F8F6A", 0.7))
			draw_rect(Rect2(s.x * 0.15, s.y * 0.88, s.x * 0.7, s.y * 0.05), Color("#8FB3A0"))
		_:
			_quad(Rect2(0, 0, s.x, s.y * 0.55), Color("#B9E0F2"), Color("#F3E6CF"))
			for i in 8:
				var x := rng.randf() * s.x
				var h := rng.randf_range(0.25, 0.5)
				draw_line(Vector2(x, s.y * 0.82), Vector2(x, s.y * (0.82 - h)), Color("#4A3628"), 6.0)
				draw_circle(Vector2(x, s.y * (0.82 - h)), rng.randf_range(30, 55), Color("#4E7F52").lerp(Color("#76A86A"), rng.randf()))
			_quad(Rect2(0, s.y * 0.78, s.x, s.y * 0.22), Color("#88A86A"), Color("#5E7F4A"))
