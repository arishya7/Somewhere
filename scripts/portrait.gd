extends Control
## A round avatar portrait as a UI element.

const Avatar = preload("res://scripts/avatar.gd")

var cfg := {}
var ring := Color(1, 1, 1, 0.85)
var _t := 0.0


static func make(config: Dictionary, diameter: float, ring_color := Color(1, 1, 1, 0.85)) -> Control:
	var p = load("res://scripts/portrait.gd").new()
	p.cfg = config
	p.ring = ring_color
	p.custom_minimum_size = Vector2(diameter, diameter)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var r := minf(size.x, size.y) * 0.5 - 2.0
	Avatar.draw_portrait(self, cfg, size * 0.5, r, ring, _t)
