extends RefCounted
## Somewhere's look: colours, type, a theme built in code, and small UI helpers.
## Type pairs a warm editorial serif for headlines with a clean humanist sans.

const CREAM := Color("#F7EDE2")
const INK := Color("#1A1224")
const MUTED := Color(0.969, 0.929, 0.886, 0.66)
const FAINT := Color(0.969, 0.929, 0.886, 0.4)
const HAIRLINE := Color(1, 1, 1, 0.1)
const CORAL := Color("#F2765E")
const ROSE := Color("#EE7A8C")
const RED_STRING := Color("#E23B45")
const GOLD := Color("#F2C77B")
const PEACH := Color("#FFC9A3")
const SAGE := Color("#8FC7A6")
const PLUM := Color("#2A1B3D")
const PLUM_DEEP := Color("#130D1D")
const PANEL := Color(0.094, 0.067, 0.133, 0.96)

const SANS := ["Avenir", "Avenir Next", "Helvetica Neue", "Segoe UI", "Roboto", "Arial"]
const SERIF := ["New York", "Iowan Old Style", "Hoefler Text", "Georgia", "Times New Roman"]

static var _fonts := {}
static var _theme: Theme


static func theme() -> Theme:
	if _theme == null:
		_theme = build_theme()
	return _theme


## Bundled, open-licence fonts (fonts/, SIL OFL): Inter for text, Fraunces for headlines.
## Bundled so the game looks the same on every Mac, PC and browser.
const FONT_FILES := {
	"sans": "res://fonts/Inter.ttf", "sans-i": "res://fonts/Inter-Italic.ttf",
	"serif": "res://fonts/Fraunces.ttf", "serif-i": "res://fonts/Fraunces-Italic.ttf",
}


static func _bundled(kind: String, weight: int, italic := false) -> Font:
	var key := "%s-%d-%s" % [kind, weight, italic]
	if not _fonts.has(key):
		var file := kind + ("-i" if italic else "")
		var base: FontFile = load(FONT_FILES[file])
		base.hinting = TextServer.HINTING_LIGHT
		base.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_AUTO
		var f := FontVariation.new()
		f.base_font = base
		var ts := TextServerManager.get_primary_interface()
		var axes := {ts.name_to_tag("wght"): clampi(weight, 100, 900)}
		if kind == "serif":
			axes[ts.name_to_tag("SOFT")] = 50 # a little softer, warmer serif
		f.variation_opentype = axes
		_fonts[key] = f
	return _fonts[key]


static func _system(names: Array, weight: int, italic := false) -> Font:
	return _bundled("serif" if names == SERIF else "sans", weight, italic)


static func font(weight := 400) -> Font:
	return _bundled("sans", weight)


static func serif(weight := 400, italic := false) -> Font:
	return _bundled("serif", weight, italic)


static func spaced(weight: int, spacing: int, use_serif := false) -> Font:
	var fv := FontVariation.new()
	fv.base_font = serif(weight) if use_serif else (_system(SANS, weight) if weight >= 800 else font(weight))
	fv.spacing_glyph = spacing
	return fv


static func box(bg: Color, radius := 14, border := Color(0, 0, 0, 0), bw := 0, px := 22, py := 14) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	s.border_color = border
	s.set_border_width_all(bw)
	s.content_margin_left = px
	s.content_margin_right = px
	s.content_margin_top = py
	s.content_margin_bottom = py
	s.corner_detail = 16
	s.anti_aliasing = true
	return s


static func _button_styles(t: Theme, type: String, normal: StyleBox, hover: StyleBox, pressed: StyleBox, disabled: StyleBox) -> void:
	t.set_stylebox("normal", type, normal)
	t.set_stylebox("hover", type, hover)
	t.set_stylebox("pressed", type, pressed)
	t.set_stylebox("hover_pressed", type, pressed)
	t.set_stylebox("disabled", type, disabled)
	t.set_stylebox("focus", type, StyleBoxEmpty.new())


static func _font_colors(t: Theme, type: String, c: Color, pressed: Color, disabled: Color) -> void:
	for k in ["font_color", "font_hover_color", "font_focus_color"]:
		t.set_color(k, type, c)
	t.set_color("font_pressed_color", type, pressed)
	t.set_color("font_hover_pressed_color", type, pressed)
	t.set_color("font_disabled_color", type, disabled)


static func build_theme() -> Theme:
	var t := Theme.new()
	t.default_font = font(400)
	t.default_font_size = 17
	t.set_color("font_color", "Label", CREAM)

	# Secondary: a quiet outline.
	_button_styles(t, "Button",
		box(Color(1, 1, 1, 0.0), 26, Color(1, 1, 1, 0.22), 1, 24, 13),
		box(Color(1, 1, 1, 0.06), 26, Color(1, 1, 1, 0.34), 1, 24, 13),
		box(Color(1, 1, 1, 0.1), 26, Color(1, 1, 1, 0.4), 1, 24, 13),
		box(Color(1, 1, 1, 0.0), 26, Color(1, 1, 1, 0.08), 1, 24, 13))
	_font_colors(t, "Button", CREAM, CREAM, Color(CREAM, 0.3))
	t.set_font("font", "Button", font(500))

	# Primary: ivory with ink text. Calm, not shouty.
	t.set_type_variation("PrimaryButton", "Button")
	_button_styles(t, "PrimaryButton",
		box(CREAM, 26, Color(0, 0, 0, 0), 0, 30, 15),
		box(Color.WHITE, 26, Color(0, 0, 0, 0), 0, 30, 15),
		box(CREAM.darkened(0.08), 26, Color(0, 0, 0, 0), 0, 30, 15),
		box(Color(1, 1, 1, 0.08), 26, Color(0, 0, 0, 0), 0, 30, 15))
	_font_colors(t, "PrimaryButton", INK, INK, Color(CREAM, 0.32))
	t.set_font("font", "PrimaryButton", spaced(500, 1))

	# Chips: soft filled tiles; selected turns ivory.
	t.set_type_variation("Chip", "Button")
	_button_styles(t, "Chip",
		box(Color(1, 1, 1, 0.055), 12, Color(0, 0, 0, 0), 0, 16, 9),
		box(Color(1, 1, 1, 0.1), 12, Color(0, 0, 0, 0), 0, 16, 9),
		box(CREAM, 12, Color(0, 0, 0, 0), 0, 16, 9),
		box(Color(1, 1, 1, 0.025), 12, Color(0, 0, 0, 0), 0, 16, 9))
	_font_colors(t, "Chip", Color(CREAM, 0.88), INK, Color(CREAM, 0.28))
	t.set_font_size("font_size", "Chip", 15)
	t.set_font("font", "Chip", font(500))

	# Tabs: text with an underline when active.
	t.set_type_variation("Tab", "Button")
	var tab_on := box(Color(0, 0, 0, 0), 0, CREAM, 0, 2, 10)
	tab_on.border_width_bottom = 2
	var tab_off := box(Color(0, 0, 0, 0), 0, Color(0, 0, 0, 0), 0, 2, 10)
	tab_off.border_width_bottom = 2
	_button_styles(t, "Tab", tab_off, tab_off, tab_on, tab_off)
	_font_colors(t, "Tab", FAINT, CREAM, Color(CREAM, 0.2))
	t.set_color("font_hover_color", "Tab", MUTED)
	t.set_font("font", "Tab", font(600))
	t.set_font_size("font_size", "Tab", 15)

	t.set_type_variation("TextButton", "Button")
	var empty := StyleBoxEmpty.new()
	for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
		empty.set_content_margin(side, 6)
	_button_styles(t, "TextButton", empty, empty, empty, empty)
	_font_colors(t, "TextButton", MUTED, CREAM, Color(CREAM, 0.25))
	t.set_color("font_hover_color", "TextButton", CREAM)
	t.set_font("font", "TextButton", font(500))

	for type in ["LineEdit", "TextEdit"]:
		t.set_stylebox("normal", type, box(Color(1, 1, 1, 0.05), 14, HAIRLINE, 1, 20, 15))
		t.set_stylebox("focus", type, box(Color(1, 1, 1, 0.07), 14, Color(CREAM, 0.55), 1, 20, 15))
		t.set_stylebox("read_only", type, box(Color(1, 1, 1, 0.03), 14, HAIRLINE, 1, 20, 15))
		t.set_color("font_color", type, CREAM)
		t.set_color("font_placeholder_color", type, Color(CREAM, 0.3))
		t.set_color("caret_color", type, CREAM)
		t.set_color("selection_color", type, Color(CORAL, 0.35))
	t.set_font_size("font_size", "LineEdit", 20)

	_button_styles(t, "OptionButton",
		box(Color(1, 1, 1, 0.05), 14, HAIRLINE, 1, 18, 15),
		box(Color(1, 1, 1, 0.08), 14, Color(1, 1, 1, 0.2), 1, 18, 15),
		box(Color(1, 1, 1, 0.1), 14, Color(CREAM, 0.5), 1, 18, 15),
		box(Color(1, 1, 1, 0.03), 14, HAIRLINE, 1, 18, 15))
	_font_colors(t, "OptionButton", CREAM, CREAM, Color(CREAM, 0.3))

	t.set_stylebox("panel", "PopupMenu", box(Color("#211830"), 12, HAIRLINE, 1, 8, 8))
	t.set_stylebox("hover", "PopupMenu", box(Color(1, 1, 1, 0.07), 8, Color(0, 0, 0, 0), 0, 8, 6))
	t.set_color("font_color", "PopupMenu", CREAM)
	t.set_color("font_hover_color", "PopupMenu", Color.WHITE)
	t.set_font_size("font_size", "PopupMenu", 15)

	t.set_stylebox("background", "ProgressBar", box(Color(1, 1, 1, 0.08), 2, Color(0, 0, 0, 0), 0, 0, 0))
	t.set_stylebox("fill", "ProgressBar", box(CREAM, 2, Color(0, 0, 0, 0), 0, 0, 0))

	var card := box(PANEL, 22, Color(1, 1, 1, 0.07), 1, 30, 28)
	card.shadow_color = Color(0, 0, 0, 0.35)
	card.shadow_size = 30
	card.shadow_offset = Vector2(0, 10)
	t.set_type_variation("Card", "PanelContainer")
	t.set_stylebox("panel", "Card", card)

	for type in ["VScrollBar", "HScrollBar"]:
		t.set_stylebox("scroll", type, box(Color(0, 0, 0, 0), 3, Color(0, 0, 0, 0), 0, 2, 2))
		t.set_stylebox("grabber", type, box(Color(1, 1, 1, 0.16), 3, Color(0, 0, 0, 0), 0, 2, 2))
		t.set_stylebox("grabber_highlight", type, box(Color(1, 1, 1, 0.28), 3, Color(0, 0, 0, 0), 0, 2, 2))
		t.set_stylebox("grabber_pressed", type, box(Color(1, 1, 1, 0.36), 3, Color(0, 0, 0, 0), 0, 2, 2))
	t.set_color("font_color", "TooltipLabel", CREAM)
	t.set_stylebox("panel", "TooltipPanel", box(Color("#211830"), 8, HAIRLINE, 1, 10, 6))
	return t


# --- Helpers ----------------------------------------------------------------

static func label(text: String, size := 17, col := CREAM, weight := 400) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	if weight != 400:
		l.add_theme_font_override("font", font(weight))
	return l


## Editorial serif headline.
static func title(text: String, size := 40, col := CREAM) -> Label:
	var l := label(text, size, col)
	l.add_theme_font_override("font", serif(500))
	l.add_theme_constant_override("line_spacing", -2)
	return l


## Small spaced capitals above a section.
static func eyebrow(text: String, col := FAINT) -> Label:
	var l := label(text.to_upper(), 11, col)
	l.add_theme_font_override("font", spaced(800, 2))
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	return l


static func nowrap(l: Label) -> Label:
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	return l


static func button(text: String, variation := "") -> Button:
	var b := Button.new()
	b.text = text
	b.theme_type_variation = variation
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	return b


static func chip(text: String) -> Button:
	var b := button(text, "Chip")
	b.toggle_mode = true
	return b


static func gap(h: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(h, h)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


static func pill(text: String, col: Color) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", box(Color(col, 0.14), 9, Color(0, 0, 0, 0), 0, 9, 3))
	var l := label(text, 12, col.lightened(0.15), 600)
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	p.add_child(l)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


## A full-screen dimmer for modal cards.
static func scrim(host: Control) -> ColorRect:
	var s := ColorRect.new()
	s.color = Color(0.03, 0.02, 0.05, 0.0)
	s.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	s.mouse_filter = Control.MOUSE_FILTER_STOP
	host.add_child(s)
	s.create_tween().tween_property(s, "color:a", 0.62, 0.3)
	return s


## A rounded image (photos, thumbnails).
static func rounded_image(tex: Texture2D, size: Vector2, radius: int) -> Control:
	var mask := Panel.new()
	mask.custom_minimum_size = size
	mask.add_theme_stylebox_override("panel", box(Color.WHITE, radius))
	mask.clip_children = CanvasItem.CLIP_CHILDREN_ONLY
	mask.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tr := TextureRect.new()
	tr.texture = tex
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	tr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mask.add_child(tr)
	return mask


## A phone-style notification banner that slides down; tapping it runs on_tap.
static func banner(host: Control, source: String, text: String, on_tap: Callable) -> void:
	var p := PanelContainer.new()
	var sb := box(Color(0.97, 0.95, 0.95, 0.97), 20, Color(0, 0, 0, 0), 0, 16, 13)
	sb.shadow_color = Color(0, 0, 0, 0.3)
	sb.shadow_size = 20
	p.add_theme_stylebox_override("panel", sb)
	p.anchor_left = 0.5
	p.anchor_right = 0.5
	p.offset_left = -230
	p.offset_right = 230
	p.offset_top = -160
	p.offset_bottom = -160
	p.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 13)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(row)
	var icon := PanelContainer.new()
	icon.custom_minimum_size = Vector2(40, 40)
	icon.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	icon.add_theme_stylebox_override("panel", box(INK, 10, Color(0, 0, 0, 0), 0, 0, 0))
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var s := label("S", 21, CREAM)
	s.add_theme_font_override("font", serif(500, true))
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	s.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	icon.add_child(s)
	row.add_child(icon)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 1)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(col)
	var head := HBoxContainer.new()
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var src := nowrap(label(source, 12, Color(0.35, 0.3, 0.38), 600))
	src.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(src)
	head.add_child(nowrap(label("now", 12, Color(0.5, 0.45, 0.55))))
	col.add_child(head)
	col.add_child(label(text, 15, Color(0.1, 0.07, 0.12), 500))
	col.add_child(label("Tap to fill in the code", 12, Color(0.5, 0.45, 0.55)))
	for c in col.get_children() + head.get_children() + [s]:
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.add_child(p)

	var slide := func(to: float, dur: float) -> Tween:
		var tw := p.create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(p, "offset_top", to, dur)
		tw.tween_property(p, "offset_bottom", to, dur)
		return tw
	slide.call(18.0, 0.5)
	var dismissed := [false]
	var dismiss := func() -> void:
		if dismissed[0] or not is_instance_valid(p):
			return
		dismissed[0] = true
		var tw: Tween = slide.call(-160.0, 0.4)
		tw.chain().tween_callback(p.queue_free)
	p.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			on_tap.call()
			dismiss.call())
	p.create_tween().tween_interval(10.0).finished.connect(dismiss)


const ORIENTATIONS := ["Straight", "Gay", "Lesbian", "Bisexual", "Pansexual", "Queer", "Asexual", "Prefer not to say"]
const FLAGS := {
	"Gay": ["#E40303", "#FF8C00", "#FFED00", "#008026", "#004DFF", "#750787"],
	"Queer": ["#E40303", "#FF8C00", "#FFED00", "#008026", "#004DFF", "#750787"],
	"Lesbian": ["#D52D00", "#FF9A56", "#FFFFFF", "#D362A4", "#A30262"],
	"Bisexual": ["#D60270", "#D60270", "#9B4F96", "#0038A8", "#0038A8"],
	"Pansexual": ["#FF218C", "#FFD800", "#21B1FF"],
	"Asexual": ["#000000", "#A3A3A3", "#FFFFFF", "#800080"],
}


## A small pride flag (horizontal stripes) for an orientation, if it has one.
static func draw_flag(ci: CanvasItem, r: Rect2, orientation: String) -> void:
	var stripes: Array = FLAGS.get(orientation, [])
	if stripes.is_empty():
		return
	var h := r.size.y / stripes.size()
	for i in stripes.size():
		ci.draw_rect(Rect2(r.position + Vector2(0, h * i), Vector2(r.size.x, h + 0.5)), Color(stripes[i]))
	ci.draw_rect(r, Color(0, 0, 0, 0.35), false, 1.0)


## A name tag above someone's head: text in a pill, with their pride flag on the left if they show one.
static func draw_tag(ci: CanvasItem, bottom_center: Vector2, text: String, bg: Color, fg: Color, orientation := "", size := 15) -> void:
	var f := font(500)
	var tw := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var has_flag := FLAGS.has(orientation)
	var fw := size * 1.3 if has_flag else 0.0
	var w := tw + 26.0 + (fw + 8.0 if has_flag else 0.0)
	var h := size + 14.0
	var r := Rect2(bottom_center + Vector2(-w / 2.0, -h), Vector2(w, h))
	ci.draw_style_box(box(bg, int(h / 2.0)), r)
	var x := r.position.x + 13.0
	if has_flag:
		draw_flag(ci, Rect2(Vector2(x, r.position.y + h * 0.28), Vector2(fw, h * 0.44)), orientation)
		x += fw + 8.0
	ci.draw_string(f, Vector2(x, r.position.y + h / 2.0 + size * 0.36), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, fg)
