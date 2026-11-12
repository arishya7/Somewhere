extends Control
## The map: Singapore at dusk. Places glow by what you love, and people drift in.
## Other players are simulated for now; swap _spawn() for a server feed later.

const UI = preload("res://scripts/ui.gd")
const Avatar = preload("res://scripts/avatar.gd")
const Portrait = preload("res://scripts/portrait.gd")
const Places = preload("res://scripts/places.gd")
const People = preload("res://scripts/people.gd")
const Dock = preload("res://scripts/ui/dock.gd")
const Tour = preload("res://scripts/ui/tour.gd")
const INTEREST := Color("#F2C77B")
const BUSY := Color("#5EEAD4")
const BUSY_AT := 3

const K := 4000.0 # world units per degree
const ORIGIN := Vector2(103.6, 1.48)

const ISLANDS := [
	[Vector2(103.690, 1.265), Vector2(0.03, 0.012)], # Jurong Island
	[Vector2(103.828, 1.249), Vector2(0.016, 0.0065)], # Sentosa
	[Vector2(103.958, 1.408), Vector2(0.03, 0.009)], # Pulau Ubin
	[Vector2(104.055, 1.405), Vector2(0.025, 0.018)], # Pulau Tekong
]
const PARKS := [
	[Vector2(103.810, 1.375), Vector2(0.03, 0.034)],
	[Vector2(103.690, 1.400), Vector2(0.025, 0.02)],
	[Vector2(103.775, 1.355), Vector2(0.012, 0.01)],
]
const RESERVOIRS := [
	[Vector2(103.826, 1.344), Vector2(0.008, 0.004)], [Vector2(103.805, 1.373), Vector2(0.006, 0.006)],
	[Vector2(103.800, 1.402), Vector2(0.011, 0.004)], [Vector2(103.735, 1.428), Vector2(0.012, 0.005)],
	[Vector2(103.866, 1.283), Vector2(0.006, 0.003)], [Vector2(103.930, 1.341), Vector2(0.004, 0.003)],
]
const ROADS := [
	[Vector2(103.64, 1.335), Vector2(103.72, 1.34), Vector2(103.77, 1.33), Vector2(103.82, 1.325), Vector2(103.86, 1.33), Vector2(103.90, 1.33), Vector2(103.95, 1.34), Vector2(103.99, 1.355)],
	[Vector2(103.84, 1.28), Vector2(103.845, 1.31), Vector2(103.85, 1.35), Vector2(103.855, 1.39), Vector2(103.87, 1.42)],
	[Vector2(103.77, 1.34), Vector2(103.77, 1.38), Vector2(103.78, 1.44)],
	[Vector2(103.86, 1.285), Vector2(103.90, 1.30), Vector2(103.95, 1.315), Vector2(103.99, 1.33)],
	[Vector2(103.88, 1.42), Vector2(103.93, 1.39), Vector2(103.98, 1.37)],
	[Vector2(103.70, 1.31), Vector2(103.74, 1.32), Vector2(103.77, 1.33)],
]
const HOTSPOTS := Places.HOTSPOTS
const COAST := Places.COAST
const NAMES := [
	"Aisha", "Mateo", "Yuki", "Liam", "Priya", "Noah", "Zara", "Kenji", "Sofia", "Omar", "Chloe", "Daniel", "Mei", "Lucas",
	"Amara", "Ethan", "Nadia", "Arjun", "Hana", "Leo", "Camila", "Ravi", "Isla", "Jin", "Elena", "Kofi", "Maya", "Felix",
	"Leila", "Tomas", "Ines", "Sam", "Nia", "Hugo", "Ana", "Theo", "Lina", "Marcus", "Sara", "Ezra",
]

var params := {}
var _offset := Vector2.ZERO
var _zoom := 0.6
var _dragging := false
var _drag_moved := 0.0
var _hover := -1
var _selected := -1
var _filter := ""
var _t := 0.0
var _people := []
var _my_cats := []
var _me_pos := Vector2.ZERO
var _spawn_in := 2.0
var _has_fated := false

var _land := PackedVector2Array()
var _land_cols := PackedColorArray()
var _islands := []
var _parks := []
var _reservoirs := []
var _roads := []
var _johor := PackedVector2Array()
var _batam := PackedVector2Array()

var _panel: PanelContainer
var _legend: Control
var _filters: Control
var _dock: Control
var _best := 0
var _panel_box: VBoxContainer
var _online: Label
var _faces: HBoxContainer
var _faces_clock := 0.0


func _rebuild_faces() -> void:
	if _faces == null:
		return
	for c in _faces.get_children():
		c.queue_free()
	var handles := Net.players.keys()
	handles.sort()
	for h in handles.slice(0, 7):
		var person := Net.person_for(h)
		var b := Button.new()
		b.flat = true
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(38, 38)
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		b.tooltip_text = "@%s  ·  %s" % [h, Net.where_text(h)]
		var ring := UI.FAINT if Net.is_resting(h) else UI.SAGE
		b.draw.connect(func() -> void: Avatar.draw_portrait(b, person.cfg, b.size / 2.0, 16.0, ring, 0.0))
		b.pressed.connect(func() -> void: load("res://scripts/ui/whos_on.gd").open(self))
		_faces.add_child(b)
	if handles.size() > 7:
		_faces.add_child(UI.label("+%d" % (handles.size() - 7), 14, UI.MUTED, 600))
var _toasts: VBoxContainer
var _font: Font
var _font_bold: Font


static func P(ll: Vector2) -> Vector2:
	return Vector2((ll.x - ORIGIN.x) * K, (ORIGIN.y - ll.y) * K)


static func _blob(center: Vector2, radius: Vector2, seed: int, n := 28) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var a := TAU * i / n
		var wob := 1.0 + 0.08 * sin(a * 3.0 + seed) + 0.05 * sin(a * 5.0 + seed * 2.0)
		pts.append(P(center + Vector2(cos(a) * radius.x, sin(a) * radius.y) * wob))
	return pts


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	_font = UI.font(500)
	_font_bold = UI.font(650)
	_build_geometry()

	_my_cats = Profile.categories()
	var best := 0
	var best_score := -1
	for i in HOTSPOTS.size():
		var score := _match(i)
		if score > best_score:
			best_score = score
			best = i
	_me_pos = P(HOTSPOTS[best].ll) + Vector2(18, 14)
	_best = best
	if Profile.DEMO_PEOPLE:
		for i in 34:
			_spawn(false)
	_build_ui()
	_dock = Dock.attach(self, "map", {"screen": "map"})
	resized.connect(_fit)
	_fit.call_deferred()
	if not Profile.data.get("seen_map_tour", false):
		_start_tour.call_deferred()


## First time on the map, walk through what everything means and what it's all for.
func _start_tour() -> void:
	await get_tree().create_timer(0.8).timeout
	if not is_inside_tree():
		return
	var spot := func() -> Rect2:
		var c := _to_screen(P(HOTSPOTS[_best].ll))
		return Rect2(c - Vector2(70, 70), Vector2(140, 140))
	var me := func() -> Rect2:
		var c := _to_screen(_me_pos)
		return Rect2(c - Vector2(40, 40), Vector2(80, 80))
	var tour := Tour.open(self, [
		{"title": "Welcome to Singapore", "text": "This is where you meet people, not by swiping, but by turning up somewhere and doing something together. Here's a 30-second look around.", "target": null},
		{"title": "This is you", "text": "Your avatar goes wherever you choose. We never use your real location.", "target": me},
		{"title": "Gold and teal", "text": "Gold places match your interests. Teal places are busy right now. The number shows how many people are there.", "target": _legend},
		{"title": "Looking for something specific?", "text": "Filter the map by interest. People who share your interests glow gold when you walk past them.", "target": _filters},
		{"title": "Tap a place, then walk in", "text": "Every street has doors you can open. Inside there's always something happening: trivia, air hockey, a shared table. Do it with whoever's there.", "target": spot},
		{"title": "Like someone? Follow the string", "text": "Tap anyone to see their real photos and profile. Follow their string. If they follow yours back, you match and can message, call and plan quests.", "target": null},
		{"title": "Your dock", "text": "Map brings you back here. Shore is a quiet break where you show as resting. The Breeze answers questions about the app. Messages holds your matches and quests.", "target": _dock},
	])
	tour.finished.connect(func() -> void:
		Profile.data.seen_map_tour = true
		Profile.save())


func replay_tour() -> void:
	Profile.data.seen_map_tour = false
	_start_tour()


func _build_geometry() -> void:
	var smooth := PackedVector2Array()
	for i in COAST.size():
		smooth.append(P(COAST[i]))
	# Two passes of corner-cutting to soften the outline.
	for _pass in 2:
		var out := PackedVector2Array()
		for i in smooth.size():
			var a := smooth[i]
			var b := smooth[(i + 1) % smooth.size()]
			out.append(a.lerp(b, 0.25))
			out.append(a.lerp(b, 0.75))
		smooth = out
	_land = smooth
	var bounds := Rect2(_land[0], Vector2.ZERO)
	for p in _land:
		bounds = bounds.expand(p)
	for p in _land:
		var u := (p.y - bounds.position.y) / bounds.size.y
		_land_cols.append(Color("#3D4D66").lerp(Color("#2E3A50"), u))
	for i in ISLANDS.size():
		_islands.append(_blob(ISLANDS[i][0], ISLANDS[i][1], i))
	for i in PARKS.size():
		_parks.append(_blob(PARKS[i][0], PARKS[i][1], i + 7))
	for i in RESERVOIRS.size():
		_reservoirs.append(_blob(RESERVOIRS[i][0], RESERVOIRS[i][1], i + 13, 18))
	for r in ROADS:
		var line := PackedVector2Array()
		for ll in r:
			line.append(P(ll))
		_roads.append(line)
	_johor = PackedVector2Array()
	for x in range(0, 21):
		var lon := lerpf(103.40, 104.25, x / 20.0)
		var lat := 1.478 + 0.012 * sin(x * 1.7) + (0.03 if lon < 103.62 else 0.0) - (0.03 if lon > 104.05 else 0.0)
		_johor.append(P(Vector2(lon, lat)))
	_johor.append(P(Vector2(104.25, 1.9)))
	_johor.append(P(Vector2(103.40, 1.9)))
	_batam = PackedVector2Array()
	for x in range(0, 21):
		var lon := lerpf(103.40, 104.25, x / 20.0)
		_batam.append(P(Vector2(lon, 1.175 + 0.01 * sin(x * 2.1))))
	_batam.append(P(Vector2(104.25, 0.8)))
	_batam.append(P(Vector2(103.40, 0.8)))


func _fit() -> void:
	var bounds := Rect2(_land[0], Vector2.ZERO)
	for p in _land:
		bounds = bounds.expand(p)
	# Land zoomed into the city centre, where most places are, so nothing is squished together.
	# Outlying places (Changi, Punggol, Woodlands, Jurong) are a drag or a zoom-out away.
	var centre := Rect2(P(Vector2(103.79, 1.33)), Vector2.ZERO)
	for h in HOTSPOTS:
		var ll: Vector2 = h.ll
		if ll.x > 103.78 and ll.x < 103.94 and ll.y > 1.24 and ll.y < 1.36:
			centre = centre.expand(P(ll))
	centre = centre.grow(60)
	var avail := size - Vector2(160, 300)
	_zoom = clampf(minf(avail.x / centre.size.x, avail.y / centre.size.y), 0.3, 3.0)
	_offset = size / 2.0 - centre.get_center() * _zoom + Vector2(0, 40)


func _match(i: int) -> int:
	var n := 0
	for c in HOTSPOTS[i].cats:
		if c in _my_cats:
			n += 1
	return n


func _label_rank(i: int) -> int:
	if i == _selected or i == _hover:
		return 10
	return _match(i)


func _visible(cats: Array) -> bool:
	return _filter == "" or _filter in cats


func _to_screen(w: Vector2) -> Vector2:
	return _offset + w * _zoom


# --- People (simulated) -------------------------------------------------------

func _spawn(announce: bool) -> void:
	var keys := Profile.CATEGORIES.keys()
	keys.shuffle()
	var cats: Array = keys.slice(0, randi_range(2, 3))
	var shared := 0
	for c in cats:
		if c in _my_cats:
			shared += 1
	var person := People.make("map-%d-%d" % [Time.get_ticks_msec(), _people.size()], cats)
	var hot := _pick_hotspot(cats)
	var p := {
		"name": person.name, "cfg": person.cfg, "cats": cats, "shared": shared, "fated": false, "person": person,
		"hot": hot, "pos": P(HOTSPOTS[hot].ll) + _jitter(), "wait": randf_range(6.0, 24.0), "appear": 0.0 if announce else 1.0,
	}
	p.target = p.pos
	_people.append(p)
	if announce:
		_toast(p)


func _pick_hotspot(cats: Array) -> int:
	var options := []
	for i in HOTSPOTS.size():
		for c in HOTSPOTS[i].cats:
			if c in cats:
				options.append(i)
	if options.is_empty():
		return randi() % HOTSPOTS.size()
	# People drift toward where others already are: crowds form, places get lively.
	if randf() < 0.6:
		var busiest: int = options[0]
		for o in options:
			if _people_at(o).size() > _people_at(busiest).size():
				busiest = o
		return busiest
	return options.pick_random()


func _jitter() -> Vector2:
	return Vector2.from_angle(randf() * TAU) * randf_range(14.0, 34.0)


## Your interests that this place speaks to.
func _interests_for(i: int) -> Array:
	return Profile.data.interests.filter(func(it) -> bool: return Profile.category_of(it) in HOTSPOTS[i].cats)


func _busy(i: int) -> int:
	return _people_at(i).size() + _friends_at(i).size()


func _friends_at(i: int) -> Array:
	var out := []
	for h in Net.players:
		if Net.players[h].get("presence", {}).get("place", "") == HOTSPOTS[i].name:
			out.append(h)
	return out


func _people_at(i: int) -> Array:
	return _people.filter(func(p) -> bool: return p.hot == i and p.pos.distance_to(p.target) < 40.0)


# --- UI -------------------------------------------------------------------------

func _build_ui() -> void:
	var top := HBoxContainer.new()
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 28
	top.offset_right = -28
	top.offset_top = 22
	top.add_theme_constant_override("separation", 14)
	add_child(top)

	var me := PanelContainer.new()
	me.theme_type_variation = "Card"
	me.add_theme_stylebox_override("panel", UI.box(UI.PANEL, 34, Color(1, 1, 1, 0.08), 1, 10, 8))
	top.add_child(me)
	var me_row := HBoxContainer.new()
	me_row.add_theme_constant_override("separation", 12)
	me.add_child(me_row)
	me_row.add_child(Portrait.make(Profile.data.avatar, 52, UI.CORAL))
	var me_text := VBoxContainer.new()
	me_text.add_theme_constant_override("separation", 0)
	me_text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	me_row.add_child(me_text)
	me_text.add_child(UI.nowrap(UI.label("Hi, %s" % Profile.data.name, 19, UI.CREAM, 650)))
	var cat_names := []
	for c in _my_cats.slice(0, 3):
		cat_names.append(Profile.CATEGORIES[c].label)
	me_text.add_child(UI.nowrap(UI.label("Lit up for you: " + ", ".join(cat_names) if not cat_names.is_empty() else "Pick interests to light the map", 13, UI.MUTED)))
	var pad := Control.new()
	pad.custom_minimum_size.x = 8
	me_row.add_child(pad)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(spacer)

	var tour_b := UI.button("?  Tour")
	tour_b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tour_b.tooltip_text = "Show the quick tour again"
	tour_b.pressed.connect(replay_tour)
	top.add_child(tour_b)

	var online := PanelContainer.new()
	online.add_theme_stylebox_override("panel", UI.box(UI.PANEL, 24, Color(1, 1, 1, 0.08), 1, 18, 10))
	online.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(online)
	var on_row := HBoxContainer.new()
	on_row.add_theme_constant_override("separation", 10)
	online.add_child(on_row)
	var dot := UI.label("●", 14, Color("#4FD1A5"))
	on_row.add_child(dot)
	_online = UI.label("", 16, UI.CREAM, 600)
	_online.autowrap_mode = TextServer.AUTOWRAP_OFF
	on_row.add_child(_online)
	# Everyone online, as faces you can tap (they might be on the map too, with nowhere to stand).
	_faces = HBoxContainer.new()
	_faces.add_theme_constant_override("separation", 4)
	on_row.add_child(_faces)
	_rebuild_faces()
	Net.roster_changed.connect(_rebuild_faces)
	tree_exiting.connect(func() -> void: Net.roster_changed.disconnect(_rebuild_faces))

	var legend := PanelContainer.new()
	legend.add_theme_stylebox_override("panel", UI.box(UI.PANEL, 16, Color(1, 1, 1, 0.08), 1, 16, 12))
	legend.anchor_top = 1.0
	legend.anchor_bottom = 1.0
	legend.offset_left = 28
	legend.offset_top = -28
	legend.offset_bottom = -28
	legend.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(legend)
	_legend = legend
	var lv := VBoxContainer.new()
	lv.add_theme_constant_override("separation", 6)
	legend.add_child(lv)
	for spec in [[INTEREST, "Matches your interests"], [BUSY, "People are here now"]]:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		row.add_child(UI.nowrap(UI.label("●", 16, spec[0])))
		row.add_child(UI.nowrap(UI.label(spec[1], 14, UI.CREAM)))
		lv.add_child(row)

	var filters := HFlowContainer.new()
	filters.set_anchors_preset(Control.PRESET_TOP_WIDE)
	filters.offset_left = 28
	filters.offset_right = -28
	filters.offset_top = 104
	filters.add_theme_constant_override("h_separation", 8)
	filters.add_theme_constant_override("v_separation", 8)
	add_child(filters)
	_filters = filters
	var group := ButtonGroup.new()
	var all := UI.chip("Everything")
	all.button_group = group
	all.button_pressed = true
	all.pressed.connect(func() -> void: _filter = "")
	filters.add_child(all)
	for key in Profile.CATEGORIES:
		var b := UI.chip(Profile.CATEGORIES[key].label)
		b.button_group = group
		var col: Color = Profile.CATEGORIES[key].color
		b.add_theme_color_override("font_color", col.lightened(0.25))
		b.add_theme_stylebox_override("pressed", UI.box(Color(col, 0.85), 22, col, 1, 18, 10))
		b.add_theme_stylebox_override("hover_pressed", UI.box(Color(col, 0.95), 22, col, 1, 18, 10))
		b.pressed.connect(func() -> void: _filter = key)
		filters.add_child(b)

	var zoom := VBoxContainer.new()
	zoom.anchor_left = 1.0
	zoom.anchor_right = 1.0
	zoom.anchor_top = 1.0
	zoom.anchor_bottom = 1.0
	zoom.offset_left = -84
	zoom.offset_right = -28
	zoom.offset_top = -150
	zoom.offset_bottom = -28
	zoom.add_theme_constant_override("separation", 8)
	add_child(zoom)
	for spec in [["+", 1.25], ["−", 0.8]]:
		var b := UI.button(spec[0])
		b.custom_minimum_size = Vector2(52, 52)
		b.add_theme_font_size_override("font_size", 24)
		b.pressed.connect(func() -> void: _zoom_at(size / 2.0, spec[1]))
		zoom.add_child(b)

	_toasts = VBoxContainer.new()
	_toasts.anchor_top = 1.0
	_toasts.anchor_bottom = 1.0
	_toasts.offset_left = 28
	_toasts.offset_right = 400
	_toasts.offset_top = -130
	_toasts.offset_bottom = -130
	_toasts.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_toasts.alignment = BoxContainer.ALIGNMENT_END
	_toasts.add_theme_constant_override("separation", 10)
	_toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_toasts)

	_panel = PanelContainer.new()
	_panel.theme_type_variation = "Card"
	_panel.anchor_left = 1.0
	_panel.anchor_right = 1.0
	_panel.offset_left = -420
	_panel.offset_right = -28
	_panel.offset_top = 170
	_panel.visible = false
	add_child(_panel)
	_panel_box = VBoxContainer.new()
	_panel_box.add_theme_constant_override("separation", 12)
	_panel.add_child(_panel_box)


func _toast(p: Dictionary) -> void:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UI.box(UI.PANEL, 22, Color(1, 1, 1, 0.08), 1, 12, 10))
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	card.add_child(row)
	row.add_child(Portrait.make(p.cfg, 42, _ring(p)))
	var text := VBoxContainer.new()
	text.add_theme_constant_override("separation", 0)
	row.add_child(text)
	text.add_child(UI.nowrap(UI.label("%s just arrived" % p.name, 15, UI.CREAM, 650)))
	var labels := []
	for c in p.cats:
		labels.append(Profile.CATEGORIES[c].label)
	var line: String = "Into " + ", ".join(labels) + "  ·  at " + str(HOTSPOTS[p.hot].name)
	text.add_child(UI.nowrap(UI.label(line, 13, UI.MUTED)))
	_toasts.add_child(card)
	while _toasts.get_child_count() > 3:
		_toasts.get_child(0).queue_free()
		_toasts.remove_child(_toasts.get_child(0))
	card.modulate.a = 0.0
	var tw := card.create_tween()
	tw.tween_property(card, "modulate:a", 1.0, 0.5)
	tw.tween_interval(4.5)
	tw.tween_property(card, "modulate:a", 0.0, 0.8)
	tw.tween_callback(card.queue_free)


func _ring(p: Dictionary) -> Color:
	if p.shared >= 2:
		return UI.GOLD
	return Color(1, 1, 1, 0.75)


func _select(i: int) -> void:
	_selected = i
	if i < 0:
		_panel.visible = false
		return
	for c in _panel_box.get_children():
		c.queue_free()
	var h: Dictionary = HOTSPOTS[i]
	var tags := HBoxContainer.new()
	tags.add_theme_constant_override("separation", 6)
	for c in h.cats:
		tags.add_child(UI.pill(Profile.CATEGORIES[c].label, Profile.CATEGORIES[c].color))
	_panel_box.add_child(tags)
	_panel_box.add_child(UI.title(h.name, 32))
	_panel_box.add_child(UI.label(h.blurb, 16, UI.MUTED))
	var here := _people_at(i)
	_panel_box.add_child(UI.label("%d %s here right now" % [here.size(), "person" if here.size() == 1 else "people"], 16, UI.CREAM, 600))
	if not here.is_empty():
		var faces := HFlowContainer.new()
		faces.add_theme_constant_override("h_separation", 6)
		faces.add_theme_constant_override("v_separation", 6)
		for p in here.slice(0, 12):
			faces.add_child(Portrait.make(p.cfg, 44, _ring(p)))
		_panel_box.add_child(faces)
	var mine := _interests_for(i)
	if not mine.is_empty():
		_panel_box.add_child(UI.eyebrow("Matches your interests", INTEREST))
		_panel_box.add_child(UI.label(", ".join(mine), 15, UI.CREAM))
	if here.size() >= BUSY_AT:
		_panel_box.add_child(UI.eyebrow("Lively right now", BUSY))
	var doors: Array = h.venues.map(func(v): return v[0])
	_panel_box.add_child(UI.eyebrow("Places to go in"))
	_panel_box.add_child(UI.label(", ".join(doors), 14, UI.MUTED))
	var go := UI.button("Go to %s" % h.name, "PrimaryButton")
	go.custom_minimum_size.y = 54
	go.pressed.connect(func() -> void: get_parent().go("district", {"place": h.name}))
	_panel_box.add_child(go)
	var close := UI.button("Close", "TextButton")
	close.pressed.connect(_select.bind(-1))
	_panel_box.add_child(close)
	_panel.visible = true
	_panel.modulate.a = 0.0
	create_tween().tween_property(_panel, "modulate:a", 1.0, 0.25)


# --- Input --------------------------------------------------------------------

func _zoom_at(p: Vector2, factor: float) -> void:
	var world := (p - _offset) / _zoom
	_zoom = clampf(_zoom * factor, 0.3, 3.0)
	_offset = p - world * _zoom


func _hotspot_at(p: Vector2) -> int:
	var best := -1
	var best_d := 26.0
	for i in HOTSPOTS.size():
		var d := p.distance_to(_to_screen(P(HOTSPOTS[i].ll)))
		if d < best_d:
			best_d = d
			best = i
	return best


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		match event.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				if event.pressed: _zoom_at(event.position, 1.1)
			MOUSE_BUTTON_WHEEL_DOWN:
				if event.pressed: _zoom_at(event.position, 1.0 / 1.1)
			MOUSE_BUTTON_LEFT:
				if event.pressed:
					_dragging = true
					_drag_moved = 0.0
				else:
					_dragging = false
					if _drag_moved < 6.0:
						_select(_hotspot_at(event.position))
	elif event is InputEventMouseMotion:
		if _dragging:
			_offset += event.relative
			_drag_moved += event.relative.length()
		_hover = _hotspot_at(event.position)
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if _hover >= 0 else (Control.CURSOR_DRAG if _dragging else Control.CURSOR_ARROW)
	elif event is InputEventMagnifyGesture:
		_zoom_at(event.position, event.factor)
	elif event is InputEventPanGesture:
		_offset -= event.delta * 14.0


# --- Simulation -----------------------------------------------------------------

func _process(delta: float) -> void:
	_t += delta
	Net.set_presence("map")
	for p in _people:
		p.appear = minf(1.0, p.appear + delta * 1.5)
		p.wait -= delta
		if p.wait <= 0.0:
			p.hot = _pick_hotspot(p.cats)
			p.target = P(HOTSPOTS[p.hot].ll) + _jitter()
			p.wait = randf_range(12.0, 30.0)
		p.pos = p.pos.move_toward(p.target, 22.0 * delta)
	_spawn_in -= delta
	if Profile.DEMO_PEOPLE and _spawn_in <= 0.0 and _people.size() < 90:
		_spawn(true)
		_spawn_in = randf_range(2.5, 6.0)
	if Profile.DEMO_PEOPLE:
		_online.text = "%d here now" % (_people.size() + 1) + ("  ·  %d friends" % Net.players.size() if Net.is_online() else "")
	else:
		_online.text = ("%d here now" % (Net.players.size() + 1)) if Net.is_online() else "Just you  ·  connecting…"
	_faces_clock -= delta
	if _faces_clock <= 0.0:
		_faces_clock = 3.0
		_rebuild_faces()
	queue_redraw()


# --- Drawing --------------------------------------------------------------------

func _draw() -> void:
	var s := size
	draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(s.x, 0), s, Vector2(0, s.y)]),
		PackedColorArray([Color("#121C33"), Color("#16213C"), Color("#1D2A4A"), Color("#1A2441")]))

	draw_set_transform(_offset, 0.0, Vector2(_zoom, _zoom))
	var px := 1.0 / _zoom
	for row in range(-6, 30):
		var y := row * 50.0
		var wave := PackedVector2Array()
		for x in range(-600, 2400, 60):
			wave.append(Vector2(x, y + sin(x * 0.01 + _t * 0.4 + row) * 5.0))
		draw_polyline(wave, Color(0.6, 0.75, 1.0, 0.035), 1.5 * px)
	draw_colored_polygon(_johor, Color("#222C42"))
	draw_colored_polygon(_batam, Color("#222C42"))
	for k in 3:
		var outline := _land.duplicate()
		outline.append(_land[0])
		draw_polyline(outline, Color(0.55, 0.7, 1.0, 0.05), (18.0 - k * 6.0) * px)
	draw_polygon(_land, _land_cols)
	for isl in _islands:
		draw_colored_polygon(isl, Color("#36455C"))
	for park in _parks:
		draw_colored_polygon(park, Color(0.3, 0.5, 0.42, 0.45))
	for res in _reservoirs:
		draw_colored_polygon(res, Color("#1F3050"))
	for road in _roads:
		draw_polyline(road, Color(1, 1, 1, 0.06), 2.5 * px, true)
	var coast := _land.duplicate()
	coast.append(_land[0])
	draw_polyline(coast, Color(0.7, 0.8, 1.0, 0.35), 1.5 * px, true)
	for isl in _islands:
		var o: PackedVector2Array = isl.duplicate()
		o.append(isl[0])
		draw_polyline(o, Color(0.7, 0.8, 1.0, 0.25), 1.2 * px, true)

	# Hotspot glow: fate pools where your interests are.
	for i in HOTSPOTS.size():
		var h: Dictionary = HOTSPOTS[i]
		var m := _match(i)
		var busy := _busy(i) >= BUSY_AT
		if m == 0 and not busy:
			continue
		var col := INTEREST if m > 0 else BUSY
		var fade := 1.0 if _visible(h.cats) else 0.25
		var r := (40.0 + 18.0 * m) * (1.0 + 0.06 * sin(_t * 2.0 + i)) * px * clampf(_zoom * 1.6, 0.8, 1.6)
		var a := (0.06 + 0.03 * m) * fade
		for k in 8:
			draw_circle(P(h.ll), r * (1.0 - k / 8.0), Color(col, a))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


	# People.
	for p in _people:
		if p.appear <= 0.01:
			continue
		var faded := 1.0 if _visible(p.cats) else 0.3
		var sp := _to_screen(p.pos)
		var r := 11.0 * (0.5 + 0.5 * ease(p.appear, 0.4))
		var ring := _ring(p)
		ring.a *= faded
		Avatar.draw_portrait(self, p.cfg, sp, r, ring, _t)

	# Hotspot markers and labels. Labels that would collide are skipped,
	# with your matches, hover and selection getting first claim on space.
	var taken: Array[Rect2] = []
	var order := range(HOTSPOTS.size())
	order.sort_custom(func(a: int, b: int) -> bool: return _label_rank(a) > _label_rank(b))
	var show_label := {}
	for i in order:
		var sp := _to_screen(P(HOTSPOTS[i].ll))
		var w := _font_bold.get_string_size(HOTSPOTS[i].name, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
		var rect := Rect2(sp.x - w / 2.0 - 4.0, sp.y - 32.0, w + 8.0, 20.0)
		if _label_rank(i) < 1 and _zoom < 0.9 and _filter == "":
			continue
		if not _visible(HOTSPOTS[i].cats):
			continue
		if taken.any(func(r: Rect2) -> bool: return r.intersects(rect)):
			continue
		taken.append(rect)
		show_label[i] = true
	for i in HOTSPOTS.size():
		var h: Dictionary = HOTSPOTS[i]
		var sp := _to_screen(P(h.ll))
		var m := _match(i)
		var count := _busy(i)
		var busy := count >= BUSY_AT
		var on := _visible(h.cats)
		var alpha := 1.0 if on else 0.3
		var col := INTEREST if m > 0 else Color(UI.CREAM, 0.55)
		var r := 6.0 + m * 1.5 + (3.0 if i == _hover or i == _selected else 0.0)
		if busy and on:
			var ph := fmod(_t * 0.6 + i * 0.13, 1.0)
			draw_arc(sp, r + 4.0 + ph * 24.0, 0.0, TAU, 32, Color(BUSY, (1.0 - ph) * 0.7), 2.0, true)
			draw_arc(sp, r + 4.0, 0.0, TAU, 32, Color(BUSY, 0.95 * alpha), 3.0, true)
			var badge := Rect2(sp + Vector2(r + 2.0, -r - 16.0), Vector2(22, 16))
			draw_style_box(UI.box(Color(BUSY, 0.95 * alpha), 8), badge)
			draw_string(_font_bold, badge.position + Vector2(0, 12.5), str(count), HORIZONTAL_ALIGNMENT_CENTER, badge.size.x, 11, UI.INK)
		draw_circle(sp, r + 3.0, Color(0.07, 0.09, 0.16, 0.8 * alpha))
		draw_circle(sp, r, Color(col, alpha))
		for q in Profile.data.get("quests", []):
			if q.status == "active" and q.place == h.name:
				var flag := sp + Vector2(-r - 30, -r - 18)
				draw_style_box(UI.box(UI.ROSE, 9), Rect2(flag, Vector2(56, 18)))
				draw_string(_font_bold, flag + Vector2(0, 13), "QUEST", HORIZONTAL_ALIGNMENT_CENTER, 56, 10, Color.WHITE)
				var partner: Dictionary = Profile.data.matches.get(q.with, {}).get("person", {})
				if not partner.is_empty():
					var pp := sp + Vector2(r + 22, 0)
					Avatar.draw_portrait(self, partner.cfg, pp, 14.0, UI.GOLD, _t)
					draw_string(_font_bold, pp + Vector2(-70, 30), "%s is waiting" % partner.name, HORIZONTAL_ALIGNMENT_CENTER, 140, 11, UI.GOLD)
				break
		if i == _selected:
			draw_arc(sp, r + 7.0, 0.0, TAU, 32, UI.CREAM, 2.0, true)
		if show_label.has(i):
			var la := 1.0 if (m > 0 or i == _hover) else 0.7
			draw_string(_font_bold, sp + Vector2(-110, -16), h.name, HORIZONTAL_ALIGNMENT_CENTER, 220, 14, Color(UI.CREAM, la))

	# Friends, at the place they're visiting (or by the shore if they're on the map).
	for i in HOTSPOTS.size():
		var fr := _friends_at(i)
		for j in fr.size():
			var sp := _to_screen(P(HOTSPOTS[i].ll)) + Vector2(-18 + j * 26, 26)
			Avatar.draw_portrait(self, Net.person_for(fr[j]).cfg, sp, 13.0, UI.SAGE, _t)
			draw_string(_font_bold, sp + Vector2(-60, 28), "@" + fr[j], HORIZONTAL_ALIGNMENT_CENTER, 120, 11, UI.SAGE)

	# You.
	var me := _to_screen(_me_pos)
	for k in 3:
		var ph := fmod(_t / 2.2 + k / 3.0, 1.0)
		draw_arc(me, 20.0 + ph * 60.0, 0.0, TAU, 48, Color(UI.CORAL, (1.0 - ph) * 0.55), 2.0, true)
	Avatar.draw_portrait(self, Profile.data.avatar, me, 18.0, UI.CORAL, _t)
	draw_string(_font_bold, me + Vector2(-60, 38), "You", HORIZONTAL_ALIGNMENT_CENTER, 120, 13, UI.CREAM)
