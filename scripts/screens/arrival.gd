extends Control
## Arrival. An empty shore at golden hour; you sit alone on the sea wall watching the water.
## The Breeze says hello, then a screen opens in front of you and plays the intro film.

const UI = preload("res://scripts/ui.gd")
const Avatar = preload("res://scripts/avatar.gd")
const Montage = preload("res://scripts/ui/montage.gd")

## A different one each time you come back to rest. Attributions checked; no misquotes.
const QUOTES := [
	["To love oneself is the beginning of a lifelong romance.", "Oscar Wilde"],
	["Talk to yourself like you would to someone you love.", "Brené Brown"],
	["Almost everything will work again if you unplug it for a few minutes, including you.", "Anne Lamott"],
	["Rest is not idleness.", "John Lubbock"],
	["Wherever you go, there you are.", "Jon Kabat-Zinn"],
	["Today you are You, that is truer than true. There is no one alive who is Youer than You.", "Dr. Seuss"],
	["There is only one corner of the universe you can be certain of improving, and that's your own self.", "Aldous Huxley"],
	["Owning our story and loving ourselves through that process is the bravest thing we'll ever do.", "Brené Brown"],
	["The best way out is always through.", "Robert Frost"],
	["Self-care is how you take your power back.", "Lalah Delia"],
]

var params := {}
var _t := 0.0
var _whisper: Label
var _montage: Control
var _choices: VBoxContainer


func _ready() -> void:
	Net.set_resting(true)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_whisper = UI.label("", 28, Color(1, 0.97, 0.92))
	_whisper.add_theme_font_override("font", UI.serif(400, true))
	_whisper.add_theme_color_override("font_shadow_color", Color(0.3, 0.1, 0.2, 0.45))
	_whisper.add_theme_constant_override("shadow_offset_y", 2)
	_whisper.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_whisper.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_whisper.offset_top = 70
	_whisper.offset_bottom = 120
	_whisper.modulate.a = 0.0
	add_child(_whisper)
	_sequence()


func _say(text: String, hold := 2.6) -> void:
	_whisper.text = text
	var tw := create_tween()
	tw.tween_property(_whisper, "modulate:a", 1.0, 1.2)
	tw.tween_interval(hold)
	tw.tween_property(_whisper, "modulate:a", 0.0, 1.0)
	await tw.finished


func _sequence() -> void:
	await get_tree().create_timer(2.0).timeout
	var name: String = Profile.data.name
	if Profile.data.get("seen_intro", false) and not params.get("replay", false):
		await _say("Back on the sea wall, %s. Rest a while." % name, 2.0)
		_show_quote()
		await get_tree().create_timer(1.5).timeout
		_show_choices()
		return
	await _say("…there you are, %s." % name)
	await _say("Sit a while. Let me show you how this place works.", 2.4)
	_open_montage()


func _show_quote() -> void:
	var i := int(Profile.data.get("quote_i", 0)) % QUOTES.size()
	Profile.data.quote_i = i + 1
	Profile.save()
	var box := VBoxContainer.new()
	box.anchor_left = 0.5
	box.anchor_right = 0.5
	box.offset_left = -420
	box.offset_right = 420
	box.offset_top = 70
	box.add_theme_constant_override("separation", 12)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)
	var q := UI.label("\u201C%s\u201D" % QUOTES[i][0], 34, Color(1, 0.97, 0.92))
	q.add_theme_font_override("font", UI.serif(400, true))
	q.add_theme_color_override("font_shadow_color", Color(0.3, 0.1, 0.2, 0.45))
	q.add_theme_constant_override("shadow_offset_y", 2)
	q.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(q)
	var who := UI.eyebrow("\u2014  " + QUOTES[i][1], Color(1, 0.92, 0.85, 0.85))
	who.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(who)
	box.add_child(UI.gap(6))
	var rest := UI.label("You're resting. You still show where you left off, greyed out, so people can see your profile. Log off to disappear completely.", 14, Color(1, 0.95, 0.9, 0.7))
	rest.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(rest)
	box.modulate.a = 0.0
	create_tween().tween_property(box, "modulate:a", 1.0, 1.6)


func _open_montage() -> void:
	if _choices and is_instance_valid(_choices):
		_choices.queue_free()
	_montage = Montage.new()
	_montage.anchor_left = 0.59
	_montage.anchor_right = 0.59
	_montage.anchor_top = 0.45
	_montage.anchor_bottom = 0.45
	_montage.offset_left = -440
	_montage.offset_right = 440
	_montage.offset_top = -300
	_montage.offset_bottom = 300
	_montage.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(_montage)
	_montage.pivot_offset = Vector2(440, 300)
	_montage.modulate.a = 0.0
	_montage.scale = Vector2(0.94, 0.94)
	var tw := create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(_montage, "modulate:a", 1.0, 0.9)
	tw.tween_property(_montage, "scale", Vector2.ONE, 0.9)
	_montage.finished.connect(_go)


func _show_choices() -> void:
	_choices = VBoxContainer.new()
	_choices.add_theme_constant_override("separation", 10)
	_choices.anchor_left = 0.5
	_choices.anchor_right = 0.5
	_choices.anchor_top = 0.5
	_choices.anchor_bottom = 0.5
	_choices.offset_left = -170
	_choices.offset_right = 170
	add_child(_choices)
	var go := UI.button("Go to Singapore", "PrimaryButton")
	go.custom_minimum_size.y = 54
	go.pressed.connect(_go)
	_choices.add_child(go)
	var again := UI.button("Watch the intro again")
	again.custom_minimum_size.y = 50
	again.pressed.connect(_open_montage)
	_choices.add_child(again)
	_choices.modulate.a = 0.0
	create_tween().tween_property(_choices, "modulate:a", 1.0, 0.8)


func _go() -> void:
	Profile.data.seen_intro = true
	Profile.save()
	get_parent().go("map")


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


# --- The shore --------------------------------------------------------------------

func _quad(y0: float, y1: float, c0: Color, c1: Color) -> void:
	draw_polygon(PackedVector2Array([Vector2(0, y0), Vector2(size.x, y0), Vector2(size.x, y1), Vector2(0, y1)]),
		PackedColorArray([c0, c0, c1, c1]))


func _draw() -> void:
	var s := size
	if s.x < 10.0:
		return
	var hz := s.y * 0.5
	_quad(0, hz * 0.6, Color("#2B1E44"), Color("#8A3D62"))
	_quad(hz * 0.6, hz, Color("#8A3D62"), Color("#FFA06A"))

	# Clouds drifting.
	for i in 6:
		var cx := fposmod(i * 330.0 + _t * (4.0 + i), s.x + 400.0) - 200.0
		var cy := hz * (0.25 + 0.1 * (i % 3))
		for k in 4:
			draw_set_transform(Vector2(cx + k * 46.0, cy + sin(k) * 6.0), 0.0, Vector2(1.0, 0.32))
			draw_circle(Vector2.ZERO, 70.0 - k * 6.0, Color(1.0, 0.75, 0.7, 0.07))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# The sun, just touching the water.
	var sun := Vector2(s.x * 0.62, hz + 10.0)
	for k in 9:
		draw_circle(sun, 80.0 + k * 55.0, Color(1.0, 0.72, 0.45, 0.05))
	draw_circle(sun, 74.0, Color("#FFDBA6"))

	# The sea: layered swells that move, a glitter path under the sun.
	_quad(hz, s.y, Color("#E9876F"), Color("#2A1C44"))
	for row in 26:
		var u := float(row) / 25.0
		var y := hz + 6.0 + pow(u, 1.6) * (s.y - hz)
		var amp := 1.5 + u * 7.0
		var speed := 0.4 + u * 0.6
		var pts := PackedVector2Array()
		for x in range(-40, int(s.x) + 60, 30):
			pts.append(Vector2(x, y + sin(x * (0.012 - u * 0.006) + _t * speed + row * 1.3) * amp))
		draw_polyline(pts, Color(1.0, 0.86, 0.78, 0.07 + 0.05 * (1.0 - u)), 1.0 + u * 2.0, true)
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	for i in 90:
		var u := rng.randf()
		var y := hz + 8.0 + pow(u, 1.4) * (s.y * 0.36)
		var spread := 40.0 + u * 260.0
		var x := sun.x + rng.randf_range(-spread, spread)
		var twinkle := 0.5 + 0.5 * sin(_t * rng.randf_range(1.5, 4.0) + i)
		draw_line(Vector2(x, y), Vector2(x + 10.0 + u * 30.0, y), Color(1.0, 0.9, 0.7, 0.55 * twinkle * (1.0 - u * 0.6)), 2.0)

	# A few birds, far out.
	for i in 3:
		var bx := fposmod(s.x * 0.2 + i * 90.0 + _t * 18.0, s.x + 200.0) - 100.0
		var by := hz * 0.55 + i * 22.0 + sin(_t + i) * 6.0
		var flap := sin(_t * 6.0 + i) * 4.0
		draw_polyline(PackedVector2Array([Vector2(bx - 9, by - flap), Vector2(bx, by), Vector2(bx + 9, by - flap)]), Color("#3A2040", 0.7), 1.6, true)

	# The sea wall you're sitting on.
	var wall := s.y * 0.84
	draw_polygon(PackedVector2Array([Vector2(0, wall - 6), Vector2(s.x, wall + 4), Vector2(s.x, s.y), Vector2(0, s.y)]),
		PackedColorArray([Color("#4A3346"), Color("#3F2B3E"), Color("#1A1220"), Color("#1A1220")]))
	draw_line(Vector2(0, wall - 6), Vector2(s.x, wall + 4), Color(1.0, 0.75, 0.6, 0.45), 2.0, true)
	for i in 14:
		var x := i * s.x / 13.0
		draw_line(Vector2(x, wall + 6), Vector2(x - 6, s.y), Color(0, 0, 0, 0.15), 1.5)

	# You, from behind, legs over the edge, watching the water.
	var seat := Vector2(s.x * 0.15, wall + 2)
	Avatar.draw_back_sitting(self, Profile.data.avatar, seat, s.y * 0.0021, _t)
