extends PanelContainer
## The dock: Map, Shore, the Breeze and Messages, always one tap away.

const UI = preload("res://scripts/ui.gd")
const BreezeGuide = preload("res://scripts/ui/breeze_guide.gd")

const ITEMS := [["map", "Map"], ["shore", "Shore"], ["breeze", "Breeze"], ["messages", "Messages"], ["me", "Me"]]

var active := ""
var back := {}
var _host: Control


## host: the screen; current: which item is "here"; back_params: where chat returns to.
static func attach(host: Control, current: String, back_params: Dictionary) -> Control:
	var d = load("res://scripts/ui/dock.gd").new()
	d._host = host
	d.active = current
	d.back = back_params
	host.add_child(d)
	return d


func _ready() -> void:
	var sb := UI.box(Color(0.07, 0.05, 0.1, 0.82), 26, Color(1, 1, 1, 0.1), 1, 10, 8)
	sb.shadow_color = Color(0, 0, 0, 0.35)
	sb.shadow_size = 24
	add_theme_stylebox_override("panel", sb)
	anchor_left = 0.5
	anchor_right = 0.5
	anchor_top = 1.0
	anchor_bottom = 1.0
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BEGIN
	offset_bottom = -20
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	add_child(row)
	for item in ITEMS:
		var b := Button.new()
		b.flat = true
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(86, 62)
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		b.tooltip_text = "Talk to the Breeze, your guide" if item[0] == "breeze" else item[1]
		var on: bool = item[0] == active
		var key: String = item[0]
		b.draw.connect(func() -> void: _draw_item(b, key, item[1], on))
		b.mouse_entered.connect(b.queue_redraw)
		b.mouse_exited.connect(b.queue_redraw)
		b.pressed.connect(_pressed.bind(key))
		row.add_child(b)


func _pressed(key: String) -> void:
	var app := _host.get_parent()
	match key:
		"map":
			if active != "map":
				app.go("map")
		"shore":
			app.go("arrival")
		"breeze":
			BreezeGuide.open(_host)
		"messages":
			app.go("chat", {"back": back})
		"me":
			load("res://scripts/ui/profile_view.gd").open_self(_host)


func _draw_item(b: Button, key: String, text: String, on: bool) -> void:
	var hovered := b.is_hovered()
	if on or hovered:
		b.draw_style_box(UI.box(Color(1, 1, 1, 0.1 if on else 0.05), 18), Rect2(Vector2.ZERO, b.size))
	var col := UI.CREAM if (on or hovered) else UI.MUTED
	var c := Vector2(b.size.x / 2.0, 24)
	match key:
		"map":
			var pts := PackedVector2Array([c + Vector2(-12, -8), c + Vector2(-4, -11), c + Vector2(4, -8), c + Vector2(12, -11), c + Vector2(12, 9), c + Vector2(4, 12), c + Vector2(-4, 9), c + Vector2(-12, 12), c + Vector2(-12, -8)])
			b.draw_polyline(pts, col, 1.8, true)
			b.draw_line(c + Vector2(-4, -11), c + Vector2(-4, 9), col, 1.4, true)
			b.draw_line(c + Vector2(4, -8), c + Vector2(4, 12), col, 1.4, true)
		"shore":
			b.draw_arc(c + Vector2(0, 2), 8.0, PI, TAU, 16, col, 1.8, true)
			for k in 2:
				var wave := PackedVector2Array()
				for i in 13:
					var x := -13.0 + i * 26.0 / 12.0
					wave.append(c + Vector2(x, 6 + k * 6 + sin(i * 1.1) * 1.8))
				b.draw_polyline(wave, col, 1.8, true)
		"breeze":
			for k in 3:
				var swirl := PackedVector2Array()
				for i in 16:
					var u := i / 15.0
					swirl.append(c + Vector2(-13 + u * 22.0, -7 + k * 7 + sin(u * PI * 1.6 + k) * 3.0))
				b.draw_polyline(swirl, col, 1.6, true)
			b.draw_circle(c + Vector2(11, -9), 2.2, UI.GOLD)
		"messages":
			b.draw_style_box(UI.box(Color(0, 0, 0, 0), 8, col, 2), Rect2(c + Vector2(-12, -10), Vector2(24, 17)))
			b.draw_colored_polygon(PackedVector2Array([c + Vector2(-6, 6), c + Vector2(-1, 6), c + Vector2(-7, 12)]), col)
			var unread := Profile.unread_total()
			if unread > 0:
				b.draw_circle(c + Vector2(13, -11), 8.0, UI.ROSE)
				b.draw_string(UI.font(800), c + Vector2(5, -7), str(unread), HORIZONTAL_ALIGNMENT_CENTER, 16, 11, Color.WHITE)
	if key == "me":
		load("res://scripts/avatar.gd").draw_portrait(b, Profile.data.avatar, c + Vector2(0, 1), 12.0, col, 0.0)
	b.draw_string(UI.font(500), Vector2(0, b.size.y - 9), text, HORIZONTAL_ALIGNMENT_CENTER, b.size.x, 12, col)
