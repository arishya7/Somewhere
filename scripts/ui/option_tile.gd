extends Button
## A selectable tile that previews an avatar option (a hairstyle, a face, an outfit).

const UI = preload("res://scripts/ui.gd")
const Avatar = preload("res://scripts/avatar.gd")

var cfg := {}
var caption := ""
var mode := "portrait" # or "body"


static func make(config: Dictionary, label: String, preview_mode: String, selected: bool) -> Button:
	var b = load("res://scripts/ui/option_tile.gd").new()
	b.cfg = config
	b.caption = label
	b.mode = preview_mode
	b.toggle_mode = true
	b.button_pressed = selected
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(92, 112)
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	return b


func _ready() -> void:
	mouse_entered.connect(queue_redraw)
	mouse_exited.connect(queue_redraw)
	toggled.connect(func(_on: bool) -> void: queue_redraw())


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	var hovered := is_hovered()
	var bg := Color(1, 1, 1, 0.1 if button_pressed else (0.07 if hovered else 0.04))
	var sb := UI.box(bg, 14, Color(UI.CREAM, 0.9) if button_pressed else Color(0, 0, 0, 0), 1 if button_pressed else 0)
	draw_style_box(sb, r)
	var preview := Vector2(size.x / 2.0, (size.y - 24.0) / 2.0 + 4.0)
	if mode == "portrait":
		Avatar.draw_portrait(self, cfg, preview, minf(size.x, size.y - 24.0) * 0.36, Color(0, 0, 0, 0))
	else:
		Avatar.draw(self, cfg, Vector2(size.x / 2.0, size.y - 30.0), (size.y - 44.0) / 300.0, 1.0)
	var font := UI.font(500)
	var col := UI.CREAM if button_pressed else UI.MUTED
	draw_string(font, Vector2(4, size.y - 9), caption, HORIZONTAL_ALIGNMENT_CENTER, size.x - 8, 12, col)
