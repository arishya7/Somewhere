extends PanelContainer
## The intro film: a short, animated explainer of what Somewhere is and how to move through it,
## narrated by the Breeze. Plays on a floating screen in front of you on the beach.

signal finished

const UI = preload("res://scripts/ui.gd")
const Avatar = preload("res://scripts/avatar.gd")
const Places = preload("res://scripts/places.gd")

const SLIDE_SECONDS := 8.0
const SLIDES := [
	["Welcome to Somewhere", "You don't hunt here. You resonate.",
		"Somewhere is a world for meeting people the way it used to happen: by being somewhere, doing something you love, and noticing who's there too."],
	["The pulse", "Everyone carries a pulse.",
		"Your pulse is you: what you love, where you linger, how you spend your time. You can't aim it or fake it. You just live, and it hums."],
	["The red string", "Some strings are already tied.",
		"Threads run beneath the world, connecting you to people you're meant to cross paths with. Gold for kindred spirits, red for the strongest pull. They stay slack until you meet."],
	["The Breeze", "And I'm the Breeze.",
		"Think of me as your fairy godmother, with better boundaries. I won't push you anywhere, but I'll whisper when something's stirring and nudge you toward the right door."],
	["Your world", "Singapore is your map.",
		"Places glow warmer where your interests live: galleries in Bras Basah, music by the river, long lunches in Katong. Pick a glow and go."],
	["Step inside", "Walk the streets. Go through doors.",
		"Every place has its own streets, shops, bars and cafés. Wander a mall, browse a thrift store, take a seat somewhere warm."],
	["Do something together", "Meet people by doing things.",
		"Join trivia night and team up with a stranger. Some rounds test what you know; some are about you. It's the easiest way to see how someone thinks."],
	["See the real them", "Curious? Tap them.",
		"Tap anyone to see who they really are: their photos, their answers, and what you noticed about them tonight."],
	["Match, talk, go", "Match. Talk. Then go on a quest.",
		"When the string pulls taut on both sides, you match. Start a conversation, and when it feels right, set out on a small adventure together."],
]

var _i := 0
var _st := 0.0
var _t := 0.0
var _canvas: Control
var _eyebrow: Label
var _title: Label
var _body: Label
var _bars: Array[ColorRect] = []
var _next: Button
var _prev: Button
var _arrow_prev: Button
var _cast := []


func _ready() -> void:
	var sb := UI.box(Color(0.07, 0.05, 0.1, 0.82), 22, Color(1, 1, 1, 0.12), 1, 0, 0)
	sb.shadow_color = Color(0, 0, 0, 0.45)
	sb.shadow_size = 50
	add_theme_stylebox_override("panel", sb)
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for i in 6:
		_cast.append(Avatar.random_config(rng))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	add_child(v)
	var frame := Panel.new()
	frame.custom_minimum_size = Vector2(880, 330)
	frame.add_theme_stylebox_override("panel", UI.box(Color("#120C1A"), 22))
	frame.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	v.add_child(frame)
	_canvas = Control.new()
	_canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_canvas.draw.connect(_draw_slide)
	frame.add_child(_canvas)
	# Big round arrows on the film itself, so it's obvious you can go back and forth.
	for side in [-1, 1]:
		var arrow := Button.new()
		arrow.text = "‹" if side < 0 else "›"
		arrow.focus_mode = Control.FOCUS_NONE
		arrow.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		arrow.add_theme_font_size_override("font_size", 34)
		arrow.add_theme_color_override("font_color", UI.CREAM)
		arrow.add_theme_stylebox_override("normal", UI.box(Color(0, 0, 0, 0.35), 28, Color(1, 1, 1, 0.25), 1, 0, 0))
		arrow.add_theme_stylebox_override("hover", UI.box(Color(0, 0, 0, 0.55), 28, Color(1, 1, 1, 0.5), 1, 0, 0))
		arrow.add_theme_stylebox_override("pressed", UI.box(Color(0, 0, 0, 0.65), 28, Color(1, 1, 1, 0.5), 1, 0, 0))
		arrow.add_theme_stylebox_override("disabled", UI.box(Color(0, 0, 0, 0.1), 28, Color(1, 1, 1, 0.06), 1, 0, 0))
		arrow.custom_minimum_size = Vector2(56, 56)
		arrow.anchor_top = 0.5
		arrow.anchor_bottom = 0.5
		arrow.offset_top = -28
		arrow.offset_bottom = 28
		if side < 0:
			arrow.offset_left = 16
			arrow.offset_right = 72
			arrow.pressed.connect(func() -> void: _go(_i - 1))
			_arrow_prev = arrow
		else:
			arrow.anchor_left = 1.0
			arrow.anchor_right = 1.0
			arrow.offset_left = -72
			arrow.offset_right = -16
			arrow.pressed.connect(func() -> void: _next.pressed.emit())
		frame.add_child(arrow)

	var text := MarginContainer.new()
	for side in ["left", "right"]:
		text.add_theme_constant_override("margin_" + side, 34)
	text.add_theme_constant_override("margin_top", 22)
	text.add_theme_constant_override("margin_bottom", 22)
	v.add_child(text)
	var tv := VBoxContainer.new()
	tv.add_theme_constant_override("separation", 6)
	text.add_child(tv)
	var bars := HBoxContainer.new()
	bars.add_theme_constant_override("separation", 6)
	tv.add_child(bars)
	for i in SLIDES.size():
		var bg := ColorRect.new()
		bg.color = Color(1, 1, 1, 0.15)
		bg.custom_minimum_size = Vector2(0, 3)
		bg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var fill := ColorRect.new()
		fill.color = UI.CREAM
		fill.anchor_bottom = 1.0
		bg.add_child(fill)
		bars.add_child(bg)
		_bars.append(fill)
	tv.add_child(UI.gap(8))
	_eyebrow = UI.eyebrow("", UI.GOLD)
	tv.add_child(_eyebrow)
	_title = UI.title("", 32)
	tv.add_child(_title)
	_body = UI.label("", 16, UI.MUTED)
	_body.custom_minimum_size = Vector2(812, 48)
	tv.add_child(_body)
	tv.add_child(UI.gap(6))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	tv.add_child(row)
	var skip := UI.button("Skip intro", "TextButton")
	skip.pressed.connect(func() -> void: finished.emit())
	row.add_child(skip)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	_prev = UI.button("‹  Back")
	_prev.custom_minimum_size = Vector2(110, 48)
	_prev.pressed.connect(func() -> void: _go(_i - 1))
	row.add_child(_prev)
	_next = UI.button("Next", "PrimaryButton")
	_next.custom_minimum_size = Vector2(200, 48)
	_next.pressed.connect(func() -> void:
		if _i == SLIDES.size() - 1:
			finished.emit()
		else:
			_go(_i + 1))
	row.add_child(_next)
	_go(0)


func _unhandled_key_input(event: InputEvent) -> void:
	if not (event.pressed and not event.echo):
		return
	if event.keycode == KEY_RIGHT:
		_next.pressed.emit()
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_LEFT:
		_go(_i - 1)
		get_viewport().set_input_as_handled()


func _go(i: int) -> void:
	_i = clampi(i, 0, SLIDES.size() - 1)
	_st = 0.0
	_eyebrow.text = SLIDES[_i][0].to_upper()
	_title.text = SLIDES[_i][1]
	_body.text = SLIDES[_i][2]
	_prev.disabled = _i == 0
	_arrow_prev.disabled = _i == 0
	_next.text = "Go to Singapore" if _i == SLIDES.size() - 1 else "Next  ›"
	for l in [_eyebrow, _title, _body]:
		l.modulate.a = 0.0
		create_tween().tween_property(l, "modulate:a", 1.0, 0.6)


func _process(delta: float) -> void:
	_t += delta
	_st += delta
	# No auto-advance: everyone reads at their own pace.
	for j in _bars.size():
		var k := 1.0 if j <= _i else 0.0
		_bars[j].anchor_right = k
		_bars[j].offset_right = 0
	_canvas.queue_redraw()


# --- Illustrations ------------------------------------------------------------

func _glow(c: Vector2, r: float, col: Color, steps := 12) -> void:
	for k in steps:
		_canvas.draw_circle(c, r * (1.0 - float(k) / steps), Color(col, col.a / steps * 2.0))


func _pulse(c: Vector2, col: Color, reach: float, alpha := 0.6) -> void:
	for k in 3:
		var ph := fmod(_t / 2.2 + k / 3.0, 1.0)
		_canvas.draw_arc(c, 14.0 + ph * reach, 0.0, TAU, 48, Color(col, alpha * (1.0 - ph)), 2.0, true)


func _string(a: Vector2, b: Vector2, tension: float, col: Color, alpha := 1.0) -> void:
	var mid := (a + b) / 2.0 + Vector2(sin(_t) * 10.0 * (1.0 - tension), 10.0 + 90.0 * (1.0 - tension))
	var pts := PackedVector2Array()
	for i in 31:
		var u := i / 30.0
		pts.append(a.lerp(mid, u).lerp(mid.lerp(b, u), u))
	_canvas.draw_polyline(pts, Color(col, 0.22 * alpha), 9.0, true)
	_canvas.draw_polyline(pts, Color(col, alpha), 2.2, true)


func _draw_slide() -> void:
	var s := _canvas.size
	var c := s / 2.0
	var ground := s.y * 0.86
	_canvas.draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(s.x, 0), s, Vector2(0, s.y)]),
		PackedColorArray([Color("#1E1430"), Color("#2A1838"), Color("#3A2040"), Color("#24182F")]))
	var me: Dictionary = Profile.data.avatar
	var ease_in := clampf(_st / 1.2, 0.0, 1.0)
	match _i:
		0:
			for i in 30:
				var p := Vector2(fposmod(i * 97.0 + _t * (8.0 + i % 5), s.x), fposmod(i * 53.0 - _t * (6.0 + i % 3), s.y))
				_canvas.draw_circle(p, 1.5, Color(1.0, 0.85, 0.6, 0.35))
			_glow(Vector2(c.x, ground - 70), 200.0, Color(1.0, 0.6, 0.45, 0.25))
			_pulse(Vector2(c.x, ground - 80), UI.CORAL, 160.0)
			Avatar.draw(_canvas, me, Vector2(c.x, ground), 0.75, _t)
		1:
			var hues := [0.55, 0.02, 0.33, 0.97, 0.75]
			for i in 5:
				var x := s.x * (0.14 + i * 0.18)
				var col := UI.CORAL if i == 2 else Color.from_hsv(hues[i], 0.55, 1.0)
				if i == 3:
					col = UI.CORAL.lightened(0.1)
				_pulse(Vector2(x, ground - 64), col, 70.0 + 10.0 * ease_in, 0.7)
				Avatar.draw(_canvas, me if i == 2 else _cast[i], Vector2(x, ground), 0.55, _t + i)
			if _st > 3.0:
				var a := clampf((_st - 3.0) / 1.0, 0.0, 1.0)
				_canvas.draw_string(UI.serif(400, true), Vector2(s.x * 0.5 - 60, 40), "in tune", HORIZONTAL_ALIGNMENT_CENTER, s.x * 0.18 + 120, 18, Color(UI.CORAL, a))
		2:
			var tension := clampf((_st - 1.0) / 3.0, 0.0, 1.0)
			var a := Vector2(s.x * 0.2, ground)
			var b := Vector2(s.x * 0.8, ground)
			for i in 3:
				var x := s.x * (0.38 + i * 0.12)
				_string(a + Vector2(30, -110), Vector2(x, ground - 70), 0.2, UI.GOLD, 0.25)
				Avatar.draw(_canvas, _cast[i + 2], Vector2(x, ground), 0.42, _t + i, {"mono": Color("#3A2A48")})
			_string(a + Vector2(30, -110), b + Vector2(-30, -110), ease(tension, 0.4), UI.RED_STRING)
			Avatar.draw(_canvas, me, a, 0.7, _t)
			Avatar.draw(_canvas, _cast[0], b, 0.7, _t + 1.0)
			if tension >= 1.0:
				_glow(a + Vector2(30, -110), 40.0, Color(UI.RED_STRING, 0.5))
				_glow(b + Vector2(-30, -110), 40.0, Color(UI.RED_STRING, 0.5))
		3:
			_glow(c, 150.0 + sin(_t * 1.5) * 10.0, Color(1.0, 0.85, 0.7, 0.35))
			for r in 6:
				var pts := PackedVector2Array()
				for i in 60:
					var u := i / 59.0
					var ang := u * TAU * 1.2 + _t * (0.5 + r * 0.08) + r
					var rad := 30.0 + u * (110.0 + r * 14.0)
					pts.append(c + Vector2(cos(ang) * rad * 1.6, sin(ang) * rad * 0.7))
				_canvas.draw_polyline(pts, Color(1.0, 0.95, 0.9, 0.12 + 0.04 * r), 1.5, true)
			for i in 26:
				var ang := _t * 0.6 + i * 0.7
				var p := c + Vector2(cos(ang) * (60 + i * 7), sin(ang * 1.3) * (30 + i * 3))
				_canvas.draw_circle(p, 1.5 + (i % 3), Color(1.0, 0.9, 0.7, 0.5 + 0.4 * sin(_t * 3.0 + i)))
			_canvas.draw_circle(c, 10.0, Color(1, 0.97, 0.9))
		4:
			var coast := []
			for ll in Places.COAST:
				coast.append(ll)
			var k := 1500.0
			var origin := Vector2(103.6, 1.48)
			var off := Vector2(c.x - (103.82 - origin.x) * k, s.y * 0.14)
			var pts := PackedVector2Array()
			for ll in coast:
				pts.append(off + Vector2((ll.x - origin.x) * k, (origin.y - ll.y) * k))
			_canvas.draw_colored_polygon(pts, Color("#3B4A63"))
			var outline := pts.duplicate()
			outline.append(pts[0])
			_canvas.draw_polyline(outline, Color(0.7, 0.8, 1.0, 0.4), 1.5, true)
			for i in Places.HOTSPOTS.size():
				var h: Dictionary = Places.HOTSPOTS[i]
				var p := off + Vector2((h.ll.x - origin.x) * k, (origin.y - h.ll.y) * k)
				var on := clampf((_st * 3.0 - i * 0.4), 0.0, 1.0)
				var col: Color = Profile.CATEGORIES[h.cats[0]].color
				_glow(p, 30.0 * on, Color(col, 0.5 * on), 6)
				_canvas.draw_circle(p, 3.5, Color(col, 0.3 + 0.7 * on))
		5:
			var labels := ["Café", "Bar", "Thrift"]
			var cols := [Color("#9ED9C6"), Color("#F4B6C2"), Color("#F6D58E")]
			var walker_x := fposmod(_st * 90.0, s.x + 100.0) - 50.0
			for i in 3:
				var x := s.x * (0.2 + i * 0.3)
				_canvas.draw_rect(Rect2(x - 110, ground - 230, 220, 230), cols[i])
				for w in 3:
					_canvas.draw_rect(Rect2(x - 85 + w * 60, ground - 210, 40, 60), Color(cols[i].darkened(0.35)))
				var near := absf(walker_x - x) < 60.0
				var door := Rect2(x - 32, ground - 100, 64, 100)
				_canvas.draw_rect(door, Color(1.0, 0.82, 0.55) if near else Color(0.9, 0.65, 0.45))
				if near:
					_glow(Vector2(x, ground - 50), 90.0, Color(1.0, 0.85, 0.55, 0.45), 6)
				_canvas.draw_rect(Rect2(x - 60, ground - 138, 120, 28), Color("#1A1224"))
				_canvas.draw_string(UI.serif(500), Vector2(x - 60, ground - 118), labels[i], HORIZONTAL_ALIGNMENT_CENTER, 120, 15, UI.CREAM)
			_canvas.draw_rect(Rect2(0, ground, s.x, s.y - ground), Color("#2A2030"))
			Avatar.draw(_canvas, me, Vector2(walker_x, ground + 30), 0.45, _t, {"stride": sin(_t * 8.0)})
		6:
			var card := Rect2(s.x * 0.3, s.y * 0.12, s.x * 0.4, s.y * 0.72)
			_canvas.draw_style_box(UI.box(Color(1, 1, 1, 0.06), 16, Color(1, 1, 1, 0.1), 1), card)
			_canvas.draw_string(UI.spaced(600, 2), card.position + Vector2(20, 30), "ROUND 3  ·  TRIVIA", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, UI.GOLD)
			_canvas.draw_string(UI.serif(500), card.position + Vector2(20, 62), "Which planet has the most moons?", HORIZONTAL_ALIGNMENT_LEFT, card.size.x - 40, 18, UI.CREAM)
			var opts := ["Saturn", "Jupiter", "Neptune", "Mars"]
			var picked := int(_st / 1.2) % 5
			for i in 4:
				var r := Rect2(card.position.x + 20 + (i % 2) * (card.size.x / 2.0 - 15), card.position.y + 86 + (i / 2) * 52, card.size.x / 2.0 - 30, 42)
				var on := _st > 4.0 and i == 0
				var hl := i == picked and not on
				_canvas.draw_style_box(UI.box(Color(UI.SAGE, 0.35) if on else Color(1, 1, 1, 0.12 if hl else 0.05), 10), r)
				_canvas.draw_string(UI.font(500), r.position + Vector2(0, 27), opts[i], HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 15, UI.CREAM)
			Avatar.draw_portrait(_canvas, me, Vector2(s.x * 0.17, s.y * 0.45), 48.0, UI.CORAL, _t)
			Avatar.draw_portrait(_canvas, _cast[0], Vector2(s.x * 0.83, s.y * 0.45), 48.0, UI.GOLD, _t)
			if _st > 4.5:
				_canvas.draw_string(UI.serif(400, true), Vector2(s.x * 0.71, s.y * 0.75), "\"Great minds.\"", HORIZONTAL_ALIGNMENT_CENTER, s.x * 0.24, 16, UI.CREAM)
		7:
			var flip := clampf((_st - 1.5) / 1.2, 0.0, 1.0)
			var sx := absf(cos(flip * PI))
			var card := Rect2(c.x - 110 * sx, s.y * 0.08, 220 * sx, s.y * 0.84)
			if flip < 0.5:
				_canvas.draw_style_box(UI.box(Color(1, 1, 1, 0.05), 14, Color(1, 1, 1, 0.12), 1), card)
				_canvas.draw_set_transform(Vector2(c.x, ground - 10), 0.0, Vector2(sx, 1.0))
				Avatar.draw(_canvas, _cast[0], Vector2.ZERO, 0.75, _t)
				_canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			else:
				_canvas.draw_polygon(PackedVector2Array([card.position, Vector2(card.end.x, card.position.y), card.end, Vector2(card.position.x, card.end.y)]),
					PackedColorArray([Color("#F0A37A"), Color("#F0A37A"), Color("#7A3B5C"), Color("#7A3B5C")]))
				if sx > 0.6:
					Avatar.draw_portrait(_canvas, _cast[0], Vector2(c.x, s.y * 0.42), 72.0 * sx, Color(0, 0, 0, 0), _t)
					_canvas.draw_string(UI.serif(500), Vector2(card.position.x, s.y * 0.82), "Aisha, 29", HORIZONTAL_ALIGNMENT_CENTER, card.size.x, 18, Color.WHITE)
			if flip >= 1.0:
				for i in 3:
					_canvas.draw_circle(Vector2(c.x - 14 + i * 14, s.y * 0.96), 3.0, Color(1, 1, 1, 0.9 if i == 0 else 0.35))
		8:
			var a := Vector2(s.x * 0.22, s.y * 0.45)
			var b := Vector2(s.x * 0.78, s.y * 0.45)
			_string(a + Vector2(56, 0), b - Vector2(56, 0), clampf(_st / 2.0, 0.0, 1.0), UI.RED_STRING)
			Avatar.draw_portrait(_canvas, me, a, 52.0, UI.CREAM, _t)
			Avatar.draw_portrait(_canvas, _cast[0], b, 52.0, UI.CREAM, _t)
			var lines := [["Same team next time?", false], ["Only if you name it.", true], ["Deal. Ferry this weekend?", false]]
			for i in lines.size():
				var at := 2.0 + i * 1.4
				if _st < at:
					continue
				var mine: bool = lines[i][1]
				var w := UI.font(500).get_string_size(lines[i][0], HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x + 28
				var r := Rect2((c.x + 10) if mine else (c.x - w - 10), s.y * 0.14 + i * 44, w, 34)
				_canvas.draw_style_box(UI.box(UI.CREAM if mine else Color(1, 1, 1, 0.1), 14), r)
				_canvas.draw_string(UI.font(500), r.position + Vector2(0, 22), lines[i][0], HORIZONTAL_ALIGNMENT_CENTER, w, 14, UI.INK if mine else UI.CREAM)
			if _st > 6.0:
				_canvas.draw_string(UI.spaced(600, 2), Vector2(0, s.y * 0.88), "QUESTS  ·  COMING NEXT", HORIZONTAL_ALIGNMENT_CENTER, s.x, 11, UI.GOLD)
