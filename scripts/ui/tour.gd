extends Control
## A short guided tour: dims the screen, rings one thing at a time and explains it.
## Each step: {"title", "text", "target"} where target is a Control, a Callable returning a Rect2, or null.

const UI = preload("res://scripts/ui.gd")

signal finished

var _steps := []
var _i := 0
var _card: PanelContainer
var _eyebrow: Label
var _title: Label
var _text: Label
var _back: Button
var _next: Button
var _t := 0.0


static func open(host: Control, steps: Array) -> Control:
	var t = load("res://scripts/ui/tour.gd").new()
	t._steps = steps
	host.add_child(t)
	return t


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_card = PanelContainer.new()
	_card.theme_type_variation = "Card"
	_card.custom_minimum_size.x = 420
	add_child(_card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	_card.add_child(v)
	_eyebrow = UI.eyebrow("", UI.GOLD)
	v.add_child(_eyebrow)
	_title = UI.title("", 28)
	v.add_child(_title)
	_text = UI.label("", 15, UI.MUTED)
	_text.custom_minimum_size.x = 380
	v.add_child(_text)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	v.add_child(row)
	var skip := UI.button("Skip tour", "TextButton")
	skip.pressed.connect(_finish)
	row.add_child(skip)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(sp)
	_back = UI.button("‹  Back")
	_back.pressed.connect(func() -> void: _show(_i - 1))
	row.add_child(_back)
	_next = UI.button("Next  ›", "PrimaryButton")
	_next.pressed.connect(func() -> void:
		if _i >= _steps.size() - 1:
			_finish()
		else:
			_show(_i + 1))
	row.add_child(_next)
	_show.call_deferred(0)


func _unhandled_key_input(event: InputEvent) -> void:
	if event.pressed and not event.echo:
		match event.keycode:
			KEY_RIGHT, KEY_ENTER, KEY_SPACE:
				_next.pressed.emit()
			KEY_LEFT:
				if _i > 0:
					_show(_i - 1)
			KEY_ESCAPE:
				_finish()
		get_viewport().set_input_as_handled()


func _target_rect(step: Dictionary) -> Rect2:
	var tg = step.get("target")
	if tg is Control and is_instance_valid(tg):
		return Rect2(tg.global_position - global_position, tg.size).grow(8)
	if tg is Callable:
		return tg.call()
	return Rect2()


func _show(i: int) -> void:
	_i = clampi(i, 0, _steps.size() - 1)
	var st: Dictionary = _steps[_i]
	_eyebrow.text = "Quick tour  ·  %d of %d" % [_i + 1, _steps.size()]
	_title.text = st.title
	_text.text = st.text
	_back.visible = _i > 0
	_next.text = "Let's go" if _i == _steps.size() - 1 else "Next  ›"
	await get_tree().process_frame
	_card.reset_size()
	var r := _target_rect(st)
	var cs := _card.size
	var pos := (size - cs) / 2.0
	if r.size != Vector2.ZERO:
		# Sit beside the target: below it if there's room, otherwise above.
		pos.x = clampf(r.get_center().x - cs.x / 2.0, 24.0, size.x - cs.x - 24.0)
		if r.end.y + 24.0 + cs.y < size.y - 24.0:
			pos.y = r.end.y + 24.0
		else:
			pos.y = maxf(24.0, r.position.y - cs.y - 24.0)
	_card.position = pos
	queue_redraw()


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var r := _target_rect(_steps[_i]) if not _steps.is_empty() else Rect2()
	var dim := Color(0.03, 0.02, 0.06, 0.62)
	if r.size == Vector2.ZERO:
		draw_rect(Rect2(Vector2.ZERO, size), dim)
		return
	# Dim everything except the target.
	draw_rect(Rect2(0, 0, size.x, r.position.y), dim)
	draw_rect(Rect2(0, r.end.y, size.x, size.y - r.end.y), dim)
	draw_rect(Rect2(0, r.position.y, r.position.x, r.size.y), dim)
	draw_rect(Rect2(r.end.x, r.position.y, size.x - r.end.x, r.size.y), dim)
	var pulse := 0.6 + 0.4 * sin(_t * 3.0)
	var sb := UI.box(Color(0, 0, 0, 0), 18, Color(UI.GOLD, pulse), 3)
	draw_style_box(sb, r)


func _finish() -> void:
	finished.emit()
	queue_free()
