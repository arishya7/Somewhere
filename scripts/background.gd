extends Control
## Dusk backdrop for menus: a deep gradient with slow, warm light drifting through it.

var top := Color("#1A1130")
var bottom := Color("#3E1F3F")
var _t := 0.0
var _orbs := [
	{"x": 0.15, "y": 0.2, "r": 420.0, "col": Color("#FF6F59"), "speed": 0.13, "phase": 0.0},
	{"x": 0.85, "y": 0.75, "r": 480.0, "col": Color("#E8456B"), "speed": 0.1, "phase": 2.0},
	{"x": 0.7, "y": 0.1, "r": 300.0, "col": Color("#FFC86B"), "speed": 0.17, "phase": 4.0},
	{"x": 0.3, "y": 0.9, "r": 360.0, "col": Color("#8B5CF6"), "speed": 0.11, "phase": 1.0},
]


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	show_behind_parent = true


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var s := size
	draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(s.x, 0), s, Vector2(0, s.y)]),
		PackedColorArray([top, top, bottom, bottom]))
	for o in _orbs:
		# Barely-there drift: calm, not busy.
		var c := Vector2(o.x * s.x + sin(_t * o.speed * 0.5 + o.phase) * 18.0, o.y * s.y + cos(_t * o.speed * 0.6 + o.phase) * 12.0)
		for k in 14:
			draw_circle(c, o.r * (1.0 - k / 14.0), Color(o.col, 0.016))
