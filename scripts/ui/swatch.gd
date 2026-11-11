extends Button
## A colour dot with a fine offset ring when selected.

const UI = preload("res://scripts/ui.gd")

var color := Color.WHITE


static func make(col: Color, selected: bool) -> Button:
	var b = load("res://scripts/ui/swatch.gd").new()
	b.color = col
	b.toggle_mode = true
	b.button_pressed = selected
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(38, 38)
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	return b


func _ready() -> void:
	mouse_entered.connect(queue_redraw)
	mouse_exited.connect(queue_redraw)
	toggled.connect(func(_on: bool) -> void: queue_redraw())


func _draw() -> void:
	var c := size / 2.0
	var r := minf(size.x, size.y) / 2.0
	if button_pressed:
		draw_arc(c, r - 1.0, 0.0, TAU, 40, UI.CREAM, 1.5, true)
	elif is_hovered():
		draw_arc(c, r - 1.0, 0.0, TAU, 40, Color(UI.CREAM, 0.35), 1.0, true)
	draw_circle(c, r - 5.5, color)
	draw_arc(c, r - 5.5, 0.0, TAU, 40, Color(1, 1, 1, 0.12), 1.0, true)
