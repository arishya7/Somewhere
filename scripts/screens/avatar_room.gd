extends Control
## The studio: a quiet room at golden hour where you shape your avatar.
## Face, hair and extras zoom the camera in; every option previews itself.

const UI = preload("res://scripts/ui.gd")
const Avatar = preload("res://scripts/avatar.gd")
const OptionTile = preload("res://scripts/ui/option_tile.gd")
const Swatch = preload("res://scripts/ui/swatch.gd")

const TABS := ["Looks", "Body", "Face", "Hair", "Outfit", "Extras"]
const CLOSE_UP := [false, false, true, true, false, true]
## What each tab is about, shown above its options.
const TAB_HINTS := [
	"Start from a ready-made look, then make it yours. Your skin tone and build stay as they are.",
	"Skin, build, height and shape.", "Face shape, eyes, brows, nose and mouth.",
	"Colour first, then style.", "Tops, bottoms and shoes, with colours.", "Facial hair, glasses and freckles.",
]

var params := {}
var _stage: Control
var _options: VBoxContainer
var _scroll: ScrollContainer
var _tab := 0
var _t := 0.0
var _zoom := 0.0
var _zoom_target := 0.0
var _tiles := {} # key -> Array of tiles, so previews refresh when anything changes
var _history := [] # earlier looks, for Undo
var _undo: Button
var _looks_seed := 1
var _view_btn: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_stage = Control.new()
	_stage.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.draw.connect(_draw_stage)
	add_child(_stage)

	var head := VBoxContainer.new()
	head.position = Vector2(48, 40)
	head.add_theme_constant_override("separation", 6)
	add_child(head)
	head.add_child(UI.eyebrow("Your avatar"))
	head.add_child(UI.title("Make yourself", 44))
	var sub := UI.label("This is how people will meet you in the world.\nYour photos stay private until you choose to share them.", 15, UI.MUTED)
	sub.custom_minimum_size.x = 420
	head.add_child(sub)

	_view_btn = UI.button("Face close-up")
	_view_btn.anchor_top = 1.0
	_view_btn.anchor_bottom = 1.0
	_view_btn.offset_left = 48
	_view_btn.offset_top = -170
	_view_btn.offset_bottom = -124
	_view_btn.pressed.connect(func() -> void:
		_zoom_target = 0.0 if _zoom_target > 0.5 else 1.0
		_view_btn.text = "Full body" if _zoom_target > 0.5 else "Face close-up")
	add_child(_view_btn)

	if not Profile.photos.is_empty():
		var strip := HBoxContainer.new()
		strip.add_theme_constant_override("separation", 8)
		strip.anchor_top = 1.0
		strip.anchor_bottom = 1.0
		strip.offset_left = 48
		strip.offset_top = -96
		add_child(strip)
		var cap := VBoxContainer.new()
		cap.add_child(UI.eyebrow("For reference"))
		var thumbs := HBoxContainer.new()
		thumbs.add_theme_constant_override("separation", 8)
		for tex in Profile.photos:
			thumbs.add_child(UI.rounded_image(tex, Vector2(48, 60), 10))
		cap.add_child(thumbs)
		strip.add_child(cap)

	var panel := PanelContainer.new()
	panel.theme_type_variation = "Card"
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_left = -520
	panel.offset_right = -32
	panel.offset_top = 32
	panel.offset_bottom = -32
	add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 16)
	panel.add_child(v)

	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 22)
	v.add_child(tabs)
	var group := ButtonGroup.new()
	for i in TABS.size():
		var b := UI.button(TABS[i], "Tab")
		b.toggle_mode = true
		b.button_group = group
		b.button_pressed = i == _tab
		b.pressed.connect(func() -> void:
			_tab = i
			_zoom_target = 1.0 if CLOSE_UP[i] else 0.0
			_view_btn.text = "Full body" if _zoom_target > 0.5 else "Face close-up"
			_build_options())
		tabs.add_child(b)
	var rule := ColorRect.new()
	rule.color = UI.HAIRLINE
	rule.custom_minimum_size.y = 1
	v.add_child(rule)

	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(_scroll)
	_options = VBoxContainer.new()
	_options.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_options.add_theme_constant_override("separation", 12)
	_scroll.add_child(_options)

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 10)
	v.add_child(actions)
	_undo = UI.button("Undo")
	_undo.custom_minimum_size = Vector2(100, 52)
	_undo.disabled = true
	_undo.pressed.connect(func() -> void:
		if _history.is_empty():
			return
		Profile.data.avatar = _history.pop_back()
		_undo.disabled = _history.is_empty()
		_build_options())
	actions.add_child(_undo)
	var shuffle := UI.button("Surprise me")
	shuffle.custom_minimum_size = Vector2(140, 52)
	shuffle.pressed.connect(func() -> void:
		_remember()
		var keep: Dictionary = Profile.data.avatar
		var fresh := Avatar.random_config()
		for k in ["skin", "body", "height", "shape"]:
			fresh[k] = keep.get(k, fresh[k])
		Profile.data.avatar = fresh
		_build_options())
	actions.add_child(shuffle)
	var done := UI.button("Continue", "PrimaryButton")
	done.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	done.custom_minimum_size.y = 52
	done.pressed.connect(func() -> void:
		Profile.data.onboarded = true
		Profile.save()
		get_parent().go("map" if params.get("edit", false) else "arrival"))
	actions.add_child(done)
	_build_options()


func _build_options() -> void:
	for c in _options.get_children():
		c.queue_free()
	_tiles.clear()
	var hint := UI.label(TAB_HINTS[_tab], 14, UI.MUTED)
	_options.add_child(hint)
	match _tab:
		0:
			_looks()
		1:
			_colors("Skin tone", "skin")
			_styles("Build", "body", "body")
			_styles("Height", "height", "body")
			_styles("Shape", "shape", "body")
		2:
			_styles("Face shape", "face", "portrait")
			_styles("Eyes", "eyes", "portrait")
			_colors("Eye colour", "eye_color")
			_styles("Brows", "brows", "portrait")
			_colors("Brow colour", "brow_color")
			_styles("Nose", "nose", "portrait")
			_styles("Mouth", "mouth", "portrait")
		3:
			_colors("Colour", "hair_color")
			_styles("Style", "hair", "portrait")
		4:
			_styles("Top", "top", "body")
			_colors("Top colour", "top_color")
			_styles("Bottoms", "bottom", "body")
			_colors("Bottoms colour", "bottom_color")
			_colors("Shoes", "shoe_color")
		5:
			_styles("Facial hair", "facial_hair", "portrait")
			_styles("Glasses", "glasses", "portrait")
			_styles("Freckles", "freckles", "portrait")
	_scroll.scroll_vertical = 0


func _section(title: String) -> void:
	_options.add_child(UI.gap(4))
	_options.add_child(UI.eyebrow(title))


func _styles(title: String, key: String, preview: String) -> void:
	_section(title)
	var grid := GridContainer.new()
	grid.columns = 3 if preview == "body" else 4
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	_options.add_child(grid)
	var group := ButtonGroup.new()
	var names: Array = Avatar.OPTIONS[key]
	var tiles := []
	for i in names.size():
		var cfg: Dictionary = Profile.data.avatar.duplicate()
		cfg[key] = i
		var b := OptionTile.make(cfg, names[i], preview, Avatar.value(Profile.data.avatar, key) == i)
		b.button_group = group
		b.custom_minimum_size = Vector2(140, 190) if preview == "body" else Vector2(104, 122)
		b.pressed.connect(func() -> void: _apply(key, i))
		grid.add_child(b)
		tiles.append(b)
	_tiles[key] = tiles


func _colors(title: String, key: String) -> void:
	_section(title)
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 4)
	flow.add_theme_constant_override("v_separation", 4)
	_options.add_child(flow)
	var group := ButtonGroup.new()
	var cols: Array = Avatar.COLOR_KEYS[key]
	for i in cols.size():
		var b := Swatch.make(cols[i], Avatar.value(Profile.data.avatar, key) == i)
		b.button_group = group
		b.pressed.connect(func() -> void: _apply(key, i))
		flow.add_child(b)


func _remember() -> void:
	_history.append(Profile.data.avatar.duplicate())
	if _history.size() > 30:
		_history.pop_front()
	_undo.disabled = false


## Ready-made looks: full outfits and hair, keeping your skin, build and shape.
func _looks() -> void:
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	_options.add_child(grid)
	var rng := RandomNumberGenerator.new()
	rng.seed = _looks_seed
	var names := ["Weekend", "Date night", "Gallery opening", "Morning run", "Office", "Gig", "Brunch", "Beach day", "Night market"]
	for i in names.size():
		var look := Avatar.random_config(rng, ["woman", "man", ""][i % 3])
		for k in ["skin", "body", "height", "shape", "eye_color", "face"]:
			look[k] = Profile.data.avatar.get(k, look[k])
		var b := OptionTile.make(look, names[i], "body", false)
		b.custom_minimum_size = Vector2(140, 190)
		b.pressed.connect(func() -> void:
			_remember()
			Profile.data.avatar = look.duplicate()
			_build_options())
		grid.add_child(b)
	var more := UI.button("Show me more looks")
	more.pressed.connect(func() -> void:
		_looks_seed += 1
		_build_options())
	_options.add_child(more)


## Apply a change and refresh every preview tile so they show it too.
func _apply(key: String, i: int) -> void:
	if Avatar.value(Profile.data.avatar, key) != i or not Profile.data.avatar.has(key):
		_remember()
	Profile.data.avatar[key] = i
	for tile_key in _tiles:
		for j in _tiles[tile_key].size():
			var cfg: Dictionary = Profile.data.avatar.duplicate()
			cfg[tile_key] = j
			_tiles[tile_key][j].cfg = cfg
			_tiles[tile_key][j].queue_redraw()


func _process(delta: float) -> void:
	_t += delta
	_zoom = lerpf(_zoom, _zoom_target, 1.0 - exp(-5.0 * delta))
	_stage.queue_redraw()


func _quad(r: Rect2, c0: Color, c1: Color) -> void:
	_stage.draw_polygon(PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]),
		PackedColorArray([c0, c0, c1, c1]))


func _glow(c: Vector2, r: float, col: Color, steps := 16) -> void:
	for k in steps:
		_stage.draw_circle(c, r * (1.0 - float(k) / steps), Color(col, col.a / steps * 2.0))


func _draw_stage() -> void:
	var s := _stage.size
	var room_w := s.x - 552.0
	var floor_y := s.y * 0.74
	_quad(Rect2(0, 0, s.x, floor_y), Color("#1C1428"), Color("#3A2338"))

	# Tall arched window throwing warm light into the room.
	var win := Rect2(room_w * 0.08, s.y * 0.2, room_w * 0.2, floor_y - s.y * 0.2 - 30.0)
	var light := PackedVector2Array([win.position + Vector2(0, win.size.y), win.end, Vector2(win.end.x + room_w * 0.34, s.y), Vector2(win.position.x + room_w * 0.14, s.y)])
	_stage.draw_colored_polygon(light, Color(1.0, 0.62, 0.42, 0.06))
	var arch := PackedVector2Array()
	var arch_cols := PackedColorArray()
	var rad := win.size.x / 2.0
	var ac := Vector2(win.get_center().x, win.position.y + rad)
	for i in 21:
		var a := PI + PI * i / 20.0
		arch.append(ac + Vector2(cos(a), sin(a)) * rad)
		arch_cols.append(Color("#5B2D52"))
	arch.append(win.end)
	arch_cols.append(Color("#F49A6E"))
	arch.append(Vector2(win.position.x, win.end.y))
	arch_cols.append(Color("#F49A6E"))
	_stage.draw_polygon(arch, arch_cols)
	_stage.draw_circle(Vector2(ac.x, win.end.y - win.size.y * 0.22), rad * 0.36, Color("#FFD9A6"))
	_stage.draw_rect(Rect2(win.position.x, win.end.y - win.size.y * 0.2, win.size.x, win.size.y * 0.2), Color("#C7707A"))
	var frame := arch.duplicate()
	frame.append(arch[0])
	_stage.draw_polyline(frame, Color("#120B19"), 8.0, true)
	_stage.draw_line(Vector2(ac.x, win.position.y), Vector2(ac.x, win.end.y), Color("#120B19"), 4.0)
	_stage.draw_line(Vector2(win.position.x, ac.y + 20), Vector2(win.end.x, ac.y + 20), Color("#120B19"), 4.0)
	# Sheer curtain.
	var sheer := PackedVector2Array()
	for k in 13:
		sheer.append(Vector2(win.end.x - 10.0 + sin(k * 0.9 + _t * 0.7) * 6.0, win.position.y - 24.0 + k * (win.size.y + 40.0) / 12.0))
	for k in range(12, -1, -1):
		sheer.append(Vector2(win.end.x + 40.0 + sin(k * 0.8 + _t * 0.6) * 8.0, win.position.y - 24.0 + k * (win.size.y + 40.0) / 12.0))
	_stage.draw_colored_polygon(sheer, Color(1.0, 0.92, 0.88, 0.1))

	# Floor lamp and plant, as quiet silhouettes.
	var lamp := Vector2(room_w * 0.86, floor_y)
	_stage.draw_line(lamp, lamp + Vector2(0, -260), Color("#120B19"), 3.0, true)
	_stage.draw_colored_polygon(PackedVector2Array([lamp + Vector2(-34, -250), lamp + Vector2(34, -250), lamp + Vector2(22, -300), lamp + Vector2(-22, -300)]), Color("#E9B97A"))
	_glow(lamp + Vector2(0, -260), 220.0, Color(1.0, 0.75, 0.45, 0.22))
	_stage.draw_colored_polygon(PackedVector2Array([lamp + Vector2(-26, 0), lamp + Vector2(26, 0), lamp + Vector2(18, -6), lamp + Vector2(-18, -6)]), Color("#120B19"))
	var pot := Vector2(room_w * 0.36, floor_y + 6)
	for k in 7:
		var ang := (k - 3) * 0.32 + sin(_t * 0.6 + k) * 0.03
		_stage.draw_set_transform(pot + Vector2(0, -36), ang, Vector2.ONE)
		_stage.draw_colored_polygon(PackedVector2Array([Vector2(0, 0), Vector2(-12, -50), Vector2(0, -104 + (k % 3) * 12), Vector2(12, -50)]), Color("#1B2A22").lerp(Color("#2E4A39"), (k % 3) / 2.0))
	_stage.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_stage.draw_colored_polygon(PackedVector2Array([pot + Vector2(-26, -40), pot + Vector2(26, -40), pot + Vector2(19, 10), pot + Vector2(-19, 10)]), Color("#2A1A24"))

	# Floor and the pedestal.
	_quad(Rect2(0, floor_y, s.x, s.y - floor_y), Color("#2B1A24"), Color("#120B13"))
	_stage.draw_line(Vector2(0, floor_y), Vector2(s.x, floor_y), Color(1, 1, 1, 0.05), 1.0)

	var full_feet := Vector2(room_w * 0.56, floor_y + (s.y - floor_y) * 0.42)
	var full_scale := s.y * 0.62 / 300.0
	_glow(full_feet + Vector2(0, -s.y * 0.3), s.y * 0.5, Color(1.0, 0.7, 0.55, 0.16))
	_stage.draw_set_transform(full_feet, 0.0, Vector2(1.0, 0.2))
	_glow(Vector2.ZERO, room_w * 0.24, Color(1.0, 0.8, 0.65, 0.18), 10)
	_stage.draw_arc(Vector2.ZERO, room_w * 0.2, 0.0, TAU, 72, Color(UI.CREAM, 0.18), 3.0, true)
	_stage.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# The camera eases toward the face for close-up tabs.
	var close_scale := s.y * 1.65 / 300.0
	var close_feet := Vector2(room_w * 0.56, s.y * 0.5) - Avatar.HEAD * close_scale + Vector2(0, s.y * 0.05)
	var e := ease(_zoom, -2.0)
	var feet := full_feet.lerp(close_feet, e)
	var sc := lerpf(full_scale, close_scale, e)
	Avatar.draw(_stage, Profile.data.avatar, feet, sc, _t)
	var name_a := 1.0 - e
	if name_a > 0.02:
		# Your name tag, exactly as people will see it above your head.
		var pr: Array = Profile.data.get("pronouns", [])
		var tag_text: String = Profile.data.name + ("  ·  " + "/".join(pr) if not pr.is_empty() else "")
		UI.draw_tag(_stage, feet + Vector2(0, -sc * 278.0 - 6.0), tag_text, Color(1, 1, 1, 0.85 * name_a), UI.INK,
			Profile.data.get("orientation", "") if Profile.data.get("show_flag", true) else "", 16)
