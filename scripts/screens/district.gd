extends Control
## A street you can walk: storefronts with doors, people passing, the feel of the neighbourhood.
## Walk with WASD or the arrow keys (up/down moves along the pavement), or click where you want to go.
## The street is drawn in a larger virtual space and scaled down, so you see the whole block.
## Inside a mall the same street becomes an indoor concourse of shops.

const UI = preload("res://scripts/ui.gd")
const Avatar = preload("res://scripts/avatar.gd")
const Places = preload("res://scripts/places.gd")
const People = preload("res://scripts/people.gd")
const ProfileView = preload("res://scripts/ui/profile_view.gd")

const SPACING := 560.0
const MARGIN := 520.0
const SPEED := 300.0
const VH := 1250.0 # virtual height of the street view
const Dock = preload("res://scripts/ui/dock.gd")
const Quests = preload("res://scripts/quests.gd")
const FACADES := {
	"shophouse": [Color("#9ED9C6"), Color("#F4B6C2"), Color("#F6D58E"), Color("#A9C8EC"), Color("#F2C1A0"), Color("#C9B6E4")],
	"quay": [Color("#C94F4F"), Color("#2E8C8A"), Color("#E3A93B"), Color("#7656A6"), Color("#D9705A")],
	"city": [Color("#2A3550"), Color("#323049"), Color("#26404A")],
	"park": [Color("#7A5A44"), Color("#6E5140")],
	"village": [Color("#F1ECE2"), Color("#ECE6DA")],
	"beach": [Color("#A57A55"), Color("#B88A60")],
	"mall": [Color("#EDE6DD"), Color("#E4DCD2")],
}

var params := {}
var _place := {}
var _style := "shophouse"
var _title := ""
var _venues := []
var _length := 0.0
var _pos := Vector2.ZERO
var _target := Vector2(-1, -1)
var _pending_door := -1
var _cam := 0.0
var _t := 0.0
var _walk := 0.0
var _moving := false
var _walkers := []
var _hover_door := -1
var _hover_walker := -1
var _overlay: Control
var _prompt: Label
var _rng := RandomNumberGenerator.new()
var _facing := 1.0
var _cars := []
var _real_pos := {} # handle -> smoothed Vector2 for friends on this street
var _hover_real := ""
var _partner := {}
var _partner_pos := Vector2.ZERO
var _quest_door := -1
var _quest_venue := ""


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	_place = Places.find(params.get("place", "Katong"))
	if _place.is_empty():
		_place = Places.HOTSPOTS[0]
	if params.has("mall"):
		_style = "mall"
		_title = params.mall
		_venues = Places.MALL_SHOPS.get(params.mall, [])
	else:
		_style = _place.street
		_title = _place.name
		_venues = _place.venues
	_length = MARGIN * 2.0 + _venues.size() * SPACING
	_pos = Vector2(MARGIN * 0.6, _ground() + 150.0)
	if params.has("at"):
		_pos.x = _door_x(int(params.at))
		_pos.y = _ground() + 60.0
	elif params.has("at_x"):
		_pos.x = float(params.at_x)
	_cam = clampf(_pos.x - _vs().x / 2.0, 0.0, maxf(0.0, _length - _vs().x))
	_rng.seed = hash(_title)
	for i in (9 if Profile.DEMO_PEOPLE else 0):
		var p := People.make("%s-walker-%d" % [_title, i])
		_walkers.append({"p": p, "x": _rng.randf() * _length, "y": _rng.randf_range(_band().x + 20.0, _band().y),
			"dir": 1.0 if _rng.randf() < 0.5 else -1.0, "speed": _rng.randf_range(40, 75), "t": _rng.randf() * 10.0,
			"pause": 0.0})
	_build_hud()
	Dock.attach(self, "", _back_params())
	Profile.quest_event.call_deferred("visit", _place.name)
	if _style != "mall":
		_partner = Profile.quest_partner(_place.name)
		var q := Profile.quest_here(_place.name)
		if not q.is_empty():
			var where: Array = Quests.venue_of(q)
			_quest_venue = where[0]
			_quest_door = int(where[1]) if _quest_venue != "" else -1
		if not _partner.is_empty():
			_partner_pos = _pos + Vector2(-110, 10)
			get_parent().toast.call_deferred("%s is here for your quest. They'll walk with you to %s (the gold star)." % [_partner.name, _quest_venue])


func _door_x(i: int) -> float:
	return MARGIN + i * SPACING + SPACING / 2.0


func _k() -> float:
	return maxf(size.y, 400.0) / VH


func _vs() -> Vector2:
	return Vector2(maxf(size.x, 400.0), maxf(size.y, 400.0)) / _k()


func _ground() -> float:
	return VH * 0.6


## The walkable pavement, as (top, bottom) in virtual units.
func _band() -> Vector2:
	return Vector2(_ground() + 24.0, _ground() + VH * 0.24)


func _depth_scale(y: float) -> float:
	var b := _band()
	return lerpf(0.88, 1.08, clampf((y - b.x) / (b.y - b.x), 0.0, 1.0)) * VH * 0.165 / 300.0


func _build_hud() -> void:
	var plate := PanelContainer.new()
	plate.position = Vector2(28, 24)
	plate.add_theme_stylebox_override("panel", UI.box(Color(0.07, 0.045, 0.1, 0.62), 20, Color(1, 1, 1, 0.08), 1, 24, 18))
	add_child(plate)
	var head := VBoxContainer.new()
	head.add_theme_constant_override("separation", 4)
	plate.add_child(head)
	var back := UI.button("‹  " + ("Back to " + _place.name if _style == "mall" else "Map"), "TextButton")
	back.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	back.pressed.connect(_leave)
	head.add_child(back)
	head.add_child(UI.eyebrow("Mall" if _style == "mall" else ", ".join(_place.cats.map(func(c): return Profile.CATEGORIES[c].label)), Color(1, 1, 1, 0.7)))
	var t := UI.nowrap(UI.title(_title, 46, Color.WHITE))
	t.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.35))
	t.add_theme_constant_override("shadow_offset_y", 2)
	head.add_child(t)
	var blurb := UI.label("Shops, food and the odd surprise." if _style == "mall" else _place.blurb, 15, Color(1, 1, 1, 0.85))
	blurb.custom_minimum_size.x = 400
	blurb.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.35))
	blurb.add_theme_constant_override("shadow_offset_y", 1)
	head.add_child(blurb)

	var hint := UI.nowrap(UI.label("Arrow keys or WASD to walk   ·   click a door to go in   ·   click someone to say hi", 13, Color(1, 1, 1, 0.8)))
	hint.add_theme_font_override("font", UI.spaced(500, 1))
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.anchor_left = 1.0
	hint.anchor_right = 1.0
	hint.offset_left = -560
	hint.offset_right = -32
	hint.offset_top = 36
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hint.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.4))
	hint.add_theme_constant_override("shadow_offset_y", 1)
	add_child(hint)

	_prompt = UI.nowrap(UI.label("", 14, UI.INK, 600))
	_prompt.add_theme_stylebox_override("normal", UI.box(UI.CREAM, 16, Color(0, 0, 0, 0), 0, 14, 7))
	_prompt.visible = false
	_prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_prompt)


func _back_params() -> Dictionary:
	var p := {"screen": "district", "place": _place.name, "at_x": _pos.x}
	if _style == "mall":
		p.mall = _title
	return p


func _leave() -> void:
	if _style == "mall":
		var idx := 0
		for i in _place.venues.size():
			if _place.venues[i][0] == _title:
				idx = i
		get_parent().go("district", {"place": _place.name, "at": idx})
	else:
		get_parent().go("map")


func _enter(i: int) -> void:
	var v: Array = _venues[i]
	if v[1] == "mall":
		get_parent().go("district", {"place": _place.name, "mall": v[0]})
	else:
		var p := {"place": _place.name, "venue": v[0], "type": v[1], "door": i}
		if _style == "mall":
			p.mall = _title
		get_parent().go("venue", p)


# --- Input ----------------------------------------------------------------------

func _to_world(screen: Vector2) -> Vector2:
	return screen / _k() + Vector2(_cam, 0)


func _door_rect(i: int) -> Rect2:
	var g := _ground()
	return Rect2(_door_x(i) - 70, g - 190, 140, 200)


func _real_at(screen: Vector2) -> String:
	var w := _to_world(screen)
	for h in _real_pos:
		var p: Vector2 = _real_pos[h]
		var hh := 300.0 * _depth_scale(p.y)
		if Rect2(Vector2(p.x - 34, p.y - hh), Vector2(68, hh)).has_point(w):
			return h
	return ""


func _walker_at(screen: Vector2) -> int:
	var w := _to_world(screen)
	var best := -1
	for i in _walkers.size():
		var it: Dictionary = _walkers[i]
		var h := 300.0 * _depth_scale(it.y)
		if Rect2(Vector2(it.x - 34, it.y - h), Vector2(68, h)).has_point(w):
			best = i
	return best


func _gui_input(event: InputEvent) -> void:
	if _overlay and is_instance_valid(_overlay):
		return
	if event is InputEventMouseMotion:
		var w := _to_world(event.position)
		_hover_door = -1
		for i in _venues.size():
			if _door_rect(i).has_point(w):
				_hover_door = i
		_hover_walker = _walker_at(event.position)
		_hover_real = _real_at(event.position)
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if (_hover_door >= 0 or _hover_walker >= 0 or _hover_real != "") else Control.CURSOR_ARROW
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if not _partner.is_empty():
			var pw := _to_world(event.position)
			var ph := 300.0 * _depth_scale(_partner_pos.y)
			if Rect2(Vector2(_partner_pos.x - 34, _partner_pos.y - ph), Vector2(68, ph)).has_point(pw):
				_open_profile(_partner)
				return
		var friend := _real_at(event.position)
		if friend != "":
			_open_profile(Net.person_for(friend))
			return
		var hit := _walker_at(event.position)
		if hit >= 0:
			_open_profile(_walkers[hit].p)
			return
		var w := _to_world(event.position)
		_pending_door = -1
		for i in _venues.size():
			if _door_rect(i).has_point(w):
				_pending_door = i
		if _pending_door >= 0:
			_target = Vector2(_door_x(_pending_door), _band().x + 10.0)
		else:
			var b := _band()
			_target = Vector2(w.x, clampf(w.y, b.x, b.y))


func _unhandled_key_input(event: InputEvent) -> void:
	if event.pressed and (event.keycode == KEY_E or event.keycode == KEY_ENTER) and _near_door() >= 0 and not (_overlay and is_instance_valid(_overlay)):
		_enter(_near_door())


func _near_door() -> int:
	for i in _venues.size():
		if absf(_door_x(i) - _pos.x) < 80.0 and _pos.y < _band().x + 90.0:
			return i
	return -1


func _open_profile(p: Dictionary) -> void:
	_overlay = ProfileView.open(self, p, _title)
	_overlay.chat_requested.connect(func(id: String) -> void: get_parent().go("chat", {"id": id, "back": _back_params()}))


# --- Simulation -----------------------------------------------------------------

func _process(delta: float) -> void:
	_t += delta
	var dir := Vector2.ZERO
	if not (_overlay and is_instance_valid(_overlay)) and get_viewport().gui_get_focus_owner() == null:
		if Input.is_physical_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT): dir.x -= 1.0
		if Input.is_physical_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT): dir.x += 1.0
		if Input.is_physical_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP): dir.y -= 1.0
		if Input.is_physical_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN): dir.y += 1.0
	if dir != Vector2.ZERO:
		_target = Vector2(-1, -1)
		_pending_door = -1
	elif _target.x >= 0.0:
		if _pos.distance_to(_target) < 8.0:
			_target = Vector2(-1, -1)
			if _pending_door >= 0:
				var d := _pending_door
				_pending_door = -1
				_enter(d)
		else:
			dir = (_target - _pos).normalized()
	dir = dir.limit_length(1.0)
	_moving = dir != Vector2.ZERO
	var b := _band()
	_pos += Vector2(dir.x, dir.y * 0.6) * SPEED * delta
	_pos = Vector2(clampf(_pos.x, 80.0, _length - 80.0), clampf(_pos.y, b.x, b.y))
	if _moving:
		_walk += delta
		if dir.x != 0.0:
			_facing = signf(dir.x)
	_cam = lerpf(_cam, clampf(_pos.x - _vs().x / 2.0, 0.0, maxf(0.0, _length - _vs().x)), 1.0 - exp(-5.0 * delta))
	for w in _walkers:
		w.t += delta
		if w.pause > 0.0:
			w.pause -= delta
			continue
		w.x += w.dir * w.speed * delta
		if _rng.randf() < 0.002:
			w.pause = _rng.randf_range(2.0, 5.0)
		if w.x < -100.0:
			w.x = _length + 80.0
		elif w.x > _length + 100.0:
			w.x = -80.0
	for c in _cars:
		c.x += c.speed * delta
		if c.x > _length + 400.0:
			c.x = -400.0
		elif c.x < -400.0:
			c.x = _length + 400.0
	Net.set_presence("district", _place.name, _title if _style == "mall" else "", _pos)
	var here := Net.players_where("district", _place.name, _title if _style == "mall" else "")
	for h in _real_pos.keys():
		if not h in here:
			_real_pos.erase(h)
	for h in here:
		var pr: Dictionary = Net.players[h].presence
		var target := Vector2(float(pr.get("x", 0)), float(pr.get("y", _band().x)))
		_real_pos[h] = _real_pos.get(h, target).lerp(target, 1.0 - exp(-8.0 * delta))
	if not _partner.is_empty():
		var want := _pos + Vector2(-110.0 * _facing, 14.0)
		want.y = clampf(want.y, _band().x, _band().y)
		_partner_pos = _partner_pos.lerp(want, 1.0 - exp(-3.0 * delta))
	var near := _near_door()
	_prompt.visible = near >= 0
	if near >= 0:
		_prompt.text = "Go into %s   ·   E" % _venues[near][0]
		_prompt.reset_size()
		_prompt.position = Vector2((_door_x(near) - _cam) * _k() - _prompt.size.x / 2.0, (_ground() - 300.0) * _k())
	queue_redraw()


func _quad(r: Rect2, c0: Color, c1: Color) -> void:
	draw_polygon(PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]),
		PackedColorArray([c0, c0, c1, c1]))


func _glow(c: Vector2, r: float, col: Color, steps := 10) -> void:
	for k in steps:
		draw_circle(c, r * (1.0 - float(k) / steps), Color(col, col.a / steps * 2.0))


## Draw an avatar at a virtual position, then restore the world transform.
func _avatar(cfg: Dictionary, vpos: Vector2, vscale: float, t: float, opts := {}) -> void:
	var k := _k()
	Avatar.draw(self, cfg, (vpos - Vector2(_cam, 0)) * k, vscale * k, t, opts)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(k, k))


func _draw() -> void:
	if size.x < 10.0:
		return
	var s := _vs()
	var g := _ground()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(_k(), _k()))
	_draw_sky(s, g)
	_draw_far(s, g)
	for i in _venues.size():
		_draw_facade(i, _door_x(i) - _cam, g)
	_draw_street(s, g)
	for i in _venues.size():
		_draw_props(i, _door_x(i) - _cam, g)
	if _quest_door >= 0 and _quest_door < _venues.size():
		_draw_quest_beacon(_door_x(_quest_door) - _cam, g)
	# People and you, back to front, smaller further from the kerb.
	var figures := []
	for i in _walkers.size():
		figures.append([_walkers[i].y, i])
	figures.append([_pos.y, -1])
	for f in _street_furniture():
		figures.append([f.y, -2, f])
	for h in _real_pos:
		figures.append([_real_pos[h].y, -3, h])
	if not _partner.is_empty():
		figures.append([_partner_pos.y, -4, null])
	figures.sort_custom(func(a, b) -> bool: return a[0] < b[0])
	for f in figures:
		if f[1] == -1:
			var stride := sin(_walk * 9.0) if _moving else 0.0
			_avatar(Profile.data.avatar, _pos, _depth_scale(_pos.y), _t, {"stride": stride})
			var tag := Vector2(_pos.x - _cam, _pos.y - 300.0 * _depth_scale(_pos.y) - 26.0)
			var pr: Array = Profile.data.get("pronouns", [])
			UI.draw_tag(self, tag + Vector2(0, 8), "You" + ("  ·  " + "/".join(pr).replace("/ask me", "") if not pr.is_empty() else ""), Color(1, 1, 1, 0.85), UI.INK,
				Profile.data.get("orientation", "") if Profile.data.get("show_flag", true) else "", 16)
		elif f[1] == -2:
			_draw_furniture(f[2])
		elif f[1] == -4:
			var moving := _partner_pos.distance_to(_pos + Vector2(-110.0 * _facing, 14.0)) > 10.0
			_avatar(_partner.cfg, _partner_pos, _depth_scale(_partner_pos.y), _t + 2.0, {"stride": sin(_t * 9.0) if moving else 0.0})
			var tag := Vector2(_partner_pos.x - _cam, _partner_pos.y - 300.0 * _depth_scale(_partner_pos.y) - 26.0)
			var label := "★  %s  ·  quest" % _partner.name
			var lw := UI.font(500).get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x + 28
			draw_style_box(UI.box(UI.GOLD, 14), Rect2(tag + Vector2(-lw / 2.0, -26), Vector2(lw, 34)))
			draw_string(UI.font(500), tag + Vector2(-lw / 2.0, -3), label, HORIZONTAL_ALIGNMENT_CENTER, lw, 18, UI.INK)
		elif f[1] == -3:
			var h: String = f[2]
			var p: Vector2 = _real_pos[h]
			var person := Net.person_for(h)
			var resting := Net.is_resting(h)
			if resting:
				_avatar(person.cfg, p, _depth_scale(p.y), _t, {"mono": Color(0.62, 0.6, 0.66, 0.55)})
			else:
				_avatar(person.cfg, p, _depth_scale(p.y), _t, {"stride": sin(_t * 9.0) * 0.6})
			var tag := Vector2(p.x - _cam, p.y - 300.0 * _depth_scale(p.y) - 26.0)
			var label: String = "@" + h + ("  ·  " + person.pronouns if person.pronouns != "" else "") + ("  ·  resting at the Shore" if resting else "")
			UI.draw_tag(self, tag + Vector2(0, 8), label, UI.SAGE, UI.INK, person.get("orientation", ""), 18)
		else:
			var w: Dictionary = _walkers[f[1]]
			if w.x - _cam < -120 or w.x - _cam > s.x + 120:
				continue
			var stride := 0.0 if w.pause > 0.0 else sin(w.t * 7.0)
			if People.kindred(w.p):
				People.draw_spotlight(self, Vector2(w.x - _cam, w.y), 260.0 * _depth_scale(w.y), _t)
			_avatar(w.p.cfg, Vector2(w.x, w.y), _depth_scale(w.y), w.t, {"stride": stride})
			if f[1] == _hover_walker:
				var top := Vector2(w.x - _cam, w.y - 300.0 * _depth_scale(w.y) - 22.0)
				UI.draw_tag(self, top + Vector2(0, 10), People.tag(w.p), UI.CREAM, UI.INK, w.p.get("orientation", ""), 20)
	_draw_road(s, g)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_sky(s: Vector2, g: float) -> void:
	match _style:
		"quay":
			_quad(Rect2(0, 0, s.x, g), Color("#0F0C24"), Color("#3A2350"))
			for i in 40:
				draw_circle(Vector2(fposmod(i * 197.0 - _cam * 0.05, s.x), fposmod(i * 61.0, g * 0.5)), 1.0, Color(1, 1, 1, 0.4))
		"city":
			_quad(Rect2(0, 0, s.x, g * 0.6), Color("#2A2350"), Color("#B5607A"))
			_quad(Rect2(0, g * 0.6, s.x, g * 0.4), Color("#B5607A"), Color("#F0A070"))
		"park":
			_quad(Rect2(0, 0, s.x, g), Color("#9CCFE6"), Color("#F5E2BC"))
		"village":
			_quad(Rect2(0, 0, s.x, g), Color("#3B2C52"), Color("#E9A27C"))
		"beach":
			_quad(Rect2(0, 0, s.x, g * 0.55), Color("#5A3D6E"), Color("#F7A26E"))
			draw_circle(Vector2(s.x * 0.7 - _cam * 0.02, g * 0.55), 60.0, Color("#FFDCA0"))
		"mall":
			_quad(Rect2(0, 0, s.x, g), Color("#F3EEE8"), Color("#E2D9CE"))
			for i in 8:
				var x := fposmod(i * 300.0 - _cam * 0.4, s.x + 300.0) - 150.0
				draw_rect(Rect2(x, 0, 160, 40), Color(1, 1, 1, 0.9))
				draw_colored_polygon(PackedVector2Array([Vector2(x, 40), Vector2(x + 160, 40), Vector2(x + 240, g), Vector2(x - 80, g)]), Color(1, 1, 1, 0.12))
			# Upper level with a glass balustrade.
			_quad(Rect2(0, g * 0.28, s.x, 26), Color("#D8CEC2"), Color("#CABFB2"))
			draw_rect(Rect2(0, g * 0.28 - 50, s.x, 50), Color(0.8, 0.9, 0.95, 0.18))
			draw_line(Vector2(0, g * 0.28 - 50), Vector2(s.x, g * 0.28 - 50), Color(1, 1, 1, 0.7), 2.0)
		_:
			_quad(Rect2(0, 0, s.x, g), Color("#F4C59A"), Color("#FBE6C8"))


func _draw_far(s: Vector2, g: float) -> void:
	var px := _cam * 0.35
	match _style:
		"quay", "city":
			var rng := RandomNumberGenerator.new()
			rng.seed = 7
			var x := -px
			while x < s.x + 200:
				var w := rng.randf_range(60, 140)
				var h := rng.randf_range(g * 0.25, g * 0.7)
				if x > -w:
					draw_rect(Rect2(x, g - h, w, h), Color("#1B1830") if _style == "quay" else Color("#3B2F55", 0.85))
					for wy in range(int(g - h + 12), int(g - 20), 18):
						for wx in range(int(x + 8), int(x + w - 8), 16):
							if rng.randf() < 0.45:
								draw_rect(Rect2(wx, wy, 6, 8), Color(1.0, 0.85, 0.55, 0.55))
				x += w + rng.randf_range(4, 20)
		"park", "village":
			for i in 22:
				var x := fposmod(i * 137.0 - px, s.x + 300.0) - 150.0
				var h := 120.0 + (i * 53) % 90
				draw_line(Vector2(x, g), Vector2(x, g - h), Color("#3E2E25"), 8.0)
				var col := Color("#3F6B45").lerp(Color("#6E9A5A"), float(i % 4) / 3.0)
				if _style == "village":
					col = col.darkened(0.35)
				draw_circle(Vector2(x, g - h), 52.0 + (i * 31) % 30, col)
				draw_circle(Vector2(x - 30, g - h + 24), 40.0, col.darkened(0.08))
		"beach":
			_quad(Rect2(0, g * 0.55, s.x, g * 0.45), Color("#E58F78"), Color("#4C3A6A"))
			for i in 8:
				var y := g * 0.6 + i * 18.0
				var pts := PackedVector2Array()
				for x in range(0, int(s.x) + 40, 40):
					pts.append(Vector2(x, y + sin(x * 0.012 + _t * (0.6 + i * 0.1) + i) * 3.0))
				draw_polyline(pts, Color(1, 0.92, 0.85, 0.12), 1.5, true)
		"shophouse":
			for i in 16:
				var x := fposmod(i * 190.0 - px, s.x + 380.0) - 190.0
				draw_colored_polygon(PackedVector2Array([Vector2(x, g * 0.45), Vector2(x + 95, g * 0.3), Vector2(x + 190, g * 0.45), Vector2(x + 190, g), Vector2(x, g)]), Color("#C99A7C", 0.5))


func _draw_facade(i: int, cx: float, g: float) -> void:
	if cx < -SPACING or cx > _vs().x + SPACING:
		return
	var palette: Array = FACADES[_style]
	var col: Color = palette[i % palette.size()]
	var w := SPACING - 30.0
	var left := cx - w / 2.0
	var v: Array = _venues[i]
	var hover := i == _hover_door or i == _near_door()
	match _style:
		"shophouse":
			var top := g - 430.0
			_quad(Rect2(left, top, w, 430), col.lightened(0.08), col.darkened(0.06))
			draw_rect(Rect2(left - 8, top - 18, w + 16, 22), col.darkened(0.25))
			draw_rect(Rect2(left - 4, top + 150, w + 8, 14), col.darkened(0.18))
			for k in 3:
				var wx := left + 60 + k * (w - 120) / 2.0 - 34
				draw_rect(Rect2(wx, top + 30, 68, 110), col.darkened(0.4))
				for l in 8:
					draw_line(Vector2(wx + 4, top + 38 + l * 13), Vector2(wx + 64, top + 38 + l * 13), col.lightened(0.15), 2.0)
				draw_arc(Vector2(wx + 34, top + 30), 34, PI, TAU, 16, col.darkened(0.25), 4.0)
			for k in 2:
				var colx := left + 24 + k * (w - 48)
				draw_rect(Rect2(colx - 10, top + 164, 20, 266), col.lightened(0.12))
			for k in 12:
				draw_rect(Rect2(left + 30 + k * (w - 60) / 12.0, g - 22, (w - 60) / 12.0 - 2, 18), [Color("#2F7F8C"), Color("#D86A5A"), Color("#E6C46A")][k % 3])
		"quay":
			var top := g - 360.0
			_quad(Rect2(left, top, w, 360), col, col.darkened(0.25))
			draw_colored_polygon(PackedVector2Array([Vector2(left - 10, top), Vector2(cx, top - 60), Vector2(left + w + 10, top)]), col.darkened(0.35))
			for k in 4:
				var wx := left + 40 + k * (w - 80) / 3.0 - 30
				draw_rect(Rect2(wx, top + 40, 60, 80), Color(1.0, 0.8, 0.5, 0.7))
			var bulbs := PackedVector2Array()
			for k in 21:
				var u := k / 20.0
				bulbs.append(Vector2(left + u * w, top + 150 + sin(u * PI) * 30.0))
			draw_polyline(bulbs, Color(0, 0, 0, 0.5), 1.0, true)
			for p in bulbs:
				draw_circle(p, 3.0, Color(1.0, 0.85, 0.5, 0.6 + 0.4 * sin(_t * 3.0 + p.x)))
		"city":
			var top := g - 560.0
			_quad(Rect2(left, top, w, 560), col.lightened(0.1), col.darkened(0.2))
			for gx in range(int(left + 20), int(left + w - 20), 46):
				draw_line(Vector2(gx, top), Vector2(gx, g - 190), Color(1, 1, 1, 0.07), 2.0)
			for gy in range(int(top + 30), int(g - 190), 40):
				draw_line(Vector2(left, gy), Vector2(left + w, gy), Color(1, 1, 1, 0.05), 1.0)
			draw_colored_polygon(PackedVector2Array([Vector2(left + w * 0.6, top), Vector2(left + w * 0.9, top), Vector2(left + w * 0.3, g - 190), Vector2(left, g - 190)]), Color(1, 1, 1, 0.04))
			_quad(Rect2(left + 20, g - 190, w - 40, 190), Color(1.0, 0.85, 0.65, 0.35), Color(1.0, 0.8, 0.6, 0.2))
		"park":
			var top := g - 210.0
			draw_rect(Rect2(left + 60, top + 40, w - 120, 170), Color("#E9DCC4"))
			draw_colored_polygon(PackedVector2Array([Vector2(left + 30, top + 46), Vector2(cx, top - 30), Vector2(left + w - 30, top + 46)]), col)
			draw_rect(Rect2(left + 80, top + 70, 90, 60), Color(1.0, 0.85, 0.6, 0.6))
			draw_rect(Rect2(left + w - 170, top + 70, 90, 60), Color(1.0, 0.85, 0.6, 0.6))
		"village":
			var top := g - 300.0
			draw_rect(Rect2(left + 20, top + 60, w - 40, 240), col)
			for k in 6:
				draw_line(Vector2(left + 20 + k * (w - 40) / 5.0, top + 60), Vector2(left + 20 + k * (w - 40) / 5.0, top + 300), Color("#1E1A1A"), 5.0)
			draw_line(Vector2(left + 20, top + 150), Vector2(left + w - 20, top + 150), Color("#1E1A1A"), 5.0)
			draw_colored_polygon(PackedVector2Array([Vector2(left - 10, top + 64), Vector2(cx, top - 40), Vector2(left + w + 10, top + 64)]), Color("#5A3A30"))
			for k in 4:
				var wx := left + 50 + k * (w - 100) / 3.0 - 26
				draw_rect(Rect2(wx, top + 80, 52, 56), Color(1.0, 0.82, 0.55, 0.75))
		"beach":
			var top := g - 240.0
			draw_rect(Rect2(left + 50, top + 60, w - 100, 180), col)
			for k in 10:
				draw_line(Vector2(left + 50, top + 70 + k * 17), Vector2(left + w - 50, top + 70 + k * 17), col.darkened(0.2), 1.5)
			draw_colored_polygon(PackedVector2Array([Vector2(left + 10, top + 70), Vector2(cx, top - 10), Vector2(left + w - 10, top + 70)]), Color("#D8B878"))
			for k in 24:
				var u := k / 23.0
				draw_line(Vector2(left + 10 + u * (w - 20), top + 70), Vector2(left + 10 + u * (w - 20), top + 82), Color("#B89858"), 2.0)
		"mall":
			var top := g * 0.28 + 26.0
			draw_rect(Rect2(left, top, w, g - top), Color("#D7CDC1"))
			draw_rect(Rect2(left + 16, top + 70, w - 32, g - top - 70), Color(0.75, 0.85, 0.9, 0.35))
			draw_rect(Rect2(left + 16, top + 70, w - 32, g - top - 70), Color(1, 1, 1, 0.5), false, 2.0)
			_glow(Vector2(cx, g - 80), 160.0, Color(1.0, 0.85, 0.6, 0.25), 8)
	# Door and sign, shared by every style.
	var door := Rect2(cx - 52, g - 160, 104, 160)
	_quad(door, Color(1.0, 0.82, 0.55), Color(0.95, 0.6, 0.4))
	draw_rect(door, Color("#1E1520"), false, 5.0)
	draw_line(Vector2(cx, door.position.y), Vector2(cx, g), Color("#1E1520"), 3.0)
	if hover:
		_glow(Vector2(cx, g - 80), 150.0, Color(1.0, 0.85, 0.6, 0.35), 8)
	# A big, lit sign above the awning so the name reads from across the street.
	var font := UI.serif(500)
	var sign_y := g - 318.0
	var name_w := font.get_string_size(v[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 38).x
	var sign := Rect2(cx - name_w / 2.0 - 34, sign_y - 46, name_w + 68, 88)
	_glow(sign.get_center(), sign.size.x * 0.7, Color(1.0, 0.8, 0.5, 0.35 if hover else 0.18), 8)
	var plate := UI.box(Color("#1A1224"), 14, Color(1.0, 0.85, 0.6, 0.9) if hover else Color(1.0, 0.85, 0.6, 0.35), 3)
	plate.shadow_color = Color(0, 0, 0, 0.35)
	plate.shadow_size = 10
	draw_style_box(plate, sign)
	draw_string(font, Vector2(sign.position.x, sign_y + 6), v[0], HORIZONTAL_ALIGNMENT_CENTER, sign.size.x, 38, Color("#FFF6EA"))
	draw_string(UI.spaced(800, 3), Vector2(sign.position.x, sign_y + 32), Places.VENUE_LABELS[v[1]].to_upper(), HORIZONTAL_ALIGNMENT_CENTER, sign.size.x, 15, UI.GOLD)


func _draw_street(s: Vector2, g: float) -> void:
	var b := _band()
	var kerb := b.y + 30.0
	match _style:
		"park":
			_quad(Rect2(0, g, s.x, VH - g), Color("#B9C98E"), Color("#7FA25E"))
			_quad(Rect2(0, b.x - 10, s.x, b.y - b.x + 30), Color("#E2D3B2"), Color("#CDBB95"))
		"beach":
			_quad(Rect2(0, g, s.x, VH - g), Color("#EFCDA4"), Color("#D9AE82"))
			for i in 30:
				var x := fposmod(i * 131.0 - _cam, s.x + 100.0)
				draw_circle(Vector2(x, g + 40 + (i * 37) % int(VH - g - 60)), 2.0, Color(0, 0, 0, 0.05))
		"mall":
			_quad(Rect2(0, g, s.x, VH - g), Color("#ECE5DC"), Color("#D4CABD"))
			for i in 16:
				var x := fposmod(i * 180.0 - _cam, s.x + 180.0) - 90.0
				draw_line(Vector2(x, g), Vector2(x - 200, VH), Color(0, 0, 0, 0.04), 2.0)
			draw_line(Vector2(0, (g + VH) / 2.0), Vector2(s.x, (g + VH) / 2.0), Color(0, 0, 0, 0.04), 2.0)
		_:
			_quad(Rect2(0, g, s.x, kerb - g), Color("#D7C8B8") if _style != "quay" else Color("#6A5E6E"), Color("#BFAE9C") if _style != "quay" else Color("#4E4554"))
			for i in 40:
				var x := fposmod(i * 70.0 - _cam, s.x + 70.0) - 35.0
				draw_line(Vector2(x, g), Vector2(x - 40, kerb), Color(0, 0, 0, 0.05), 1.5)
			for r in 6:
				draw_line(Vector2(0, g + r * (kerb - g) / 6.0), Vector2(s.x, g + r * (kerb - g) / 6.0), Color(0, 0, 0, 0.035), 1.0)
			draw_rect(Rect2(0, kerb - 6, s.x, 12), Color("#A39383") if _style != "quay" else Color("#3A3240"))
			if _style == "quay":
				_quad(Rect2(0, kerb + 6, s.x, VH - kerb), Color("#1E3150"), Color("#0E1828"))
				for i in 36:
					var x := fposmod(i * 113.0 - _cam * 1.1 + _t * 14.0, s.x)
					var y := kerb + 30.0 + (i % 6) * 30.0
					draw_line(Vector2(x, y), Vector2(x + 40, y), Color(1.0, 0.8, 0.5, 0.22), 2.5)
			else:
				_quad(Rect2(0, kerb + 6, s.x, VH - kerb), Color("#4A4650"), Color("#35323A"))
				var mid := kerb + (VH - kerb) * 0.5
				var x0 := fposmod(-_cam, 120.0) - 120.0
				while x0 < s.x:
					draw_rect(Rect2(x0, mid - 3, 60, 6), Color(1, 1, 1, 0.5))
					x0 += 120.0
	# Street lamps along the kerb.
	if _style in ["shophouse", "quay", "village", "city", "park"]:
		# Lamps stand between buildings, never in front of a sign.
		for li in _venues.size() + 1:
			var x := MARGIN + li * SPACING - _cam
			if x < -100 or x > s.x + 100:
				continue
			var base := Vector2(x, b.x - 4.0)
			draw_line(base, base + Vector2(0, -330), Color("#1E1A22"), 5.0)
			draw_line(base + Vector2(0, -330), base + Vector2(26, -340), Color("#1E1A22"), 4.0)
			draw_circle(base + Vector2(30, -334), 10.0, Color("#FFE2A8"))
			_glow(base + Vector2(30, -334), 90.0, Color(1.0, 0.85, 0.55, 0.28), 6)


## Awnings, planters and window boxes: the things that make a street feel cared for.
func _draw_props(i: int, cx: float, g: float) -> void:
	if cx < -SPACING or cx > _vs().x + SPACING or _style == "beach":
		return
	var v: Array = _venues[i]
	var palette := [Color("#C8553D"), Color("#2F6F73"), Color("#D9A441"), Color("#5B4B8A"), Color("#3F7D5A")]
	var stripe: Color = palette[(i + hash(_title)) % palette.size()]
	# Scalloped, striped awning over the door.
	var top := g - 230.0
	var w := 230.0
	var awning := PackedVector2Array([Vector2(cx - w / 2.0 + 20, top), Vector2(cx + w / 2.0 - 20, top), Vector2(cx + w / 2.0, top + 54), Vector2(cx - w / 2.0, top + 54)])
	draw_colored_polygon(awning, Color("#F4EDE2"))
	for k in 7:
		if k % 2 == 0:
			var u0 := k / 7.0
			var u1 := (k + 1) / 7.0
			draw_colored_polygon(PackedVector2Array([
				Vector2(lerpf(cx - w / 2.0 + 20, cx + w / 2.0 - 20, u0), top), Vector2(lerpf(cx - w / 2.0 + 20, cx + w / 2.0 - 20, u1), top),
				Vector2(lerpf(cx - w / 2.0, cx + w / 2.0, u1), top + 54), Vector2(lerpf(cx - w / 2.0, cx + w / 2.0, u0), top + 54)]), stripe)
	for k in 7:
		var x := lerpf(cx - w / 2.0, cx + w / 2.0, (k + 0.5) / 7.0)
		draw_circle(Vector2(x, top + 54), w / 14.0, stripe if k % 2 == 0 else Color("#F4EDE2"))
	# Planters either side of the door.
	for side in [-1.0, 1.0]:
		var px: float = cx + side * 92.0
		draw_rect(Rect2(px - 22, g - 46, 44, 46), Color("#3A3036"))
		draw_rect(Rect2(px - 26, g - 50, 52, 8), Color("#4A3E44"))
		for k in 6:
			draw_circle(Vector2(px - 16 + k * 6.4, g - 56 - (k % 3) * 8.0), 13.0, Color("#3F7A4E").lerp(Color("#6EA567"), (k % 3) / 2.0))
		if (i + int(side)) % 2 == 0:
			for k in 3:
				draw_circle(Vector2(px - 8 + k * 8.0, g - 70), 4.0, [Color("#F4B6C2"), Color("#F6D58E"), Color("#FFFFFF")][k])


## A bobbing gold star over the quest's door, so you know exactly where to go.
func _draw_quest_beacon(cx: float, g: float) -> void:
	var y := g - 520.0 + sin(_t * 2.4) * 10.0
	_glow(Vector2(cx, y), 70.0, Color(UI.GOLD, 0.05))
	var label := "★  Your quest  ·  go in here"
	var lw := UI.font(600).get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x + 40
	draw_style_box(UI.box(UI.GOLD, 20), Rect2(cx - lw / 2.0, y - 24, lw, 48))
	draw_string(UI.font(600), Vector2(cx - lw / 2.0, y + 9), label, HORIZONTAL_ALIGNMENT_CENTER, lw, 24, UI.INK)
	draw_colored_polygon(PackedVector2Array([Vector2(cx - 12, y + 24), Vector2(cx + 12, y + 24), Vector2(cx, y + 40)]), UI.GOLD)
	# A dotted line down to the sign.
	for k in 5:
		draw_circle(Vector2(cx, y + 56 + k * 22.0), 4.0, Color(UI.GOLD, 0.8 - k * 0.12))


## Things on the pavement that people walk in front of or behind.
func _street_furniture() -> Array:
	var out := []
	var b := _band()
	for i in _venues.size():
		var cx := _door_x(i)
		var t: String = _venues[i][1]
		if t in ["cafe", "restaurant", "bar"] and _style != "mall":
			out.append({"kind": "table", "x": cx + 190.0, "y": b.x + 70.0})
			out.append({"kind": "table", "x": cx - 190.0, "y": b.x + 70.0})
		elif _style != "mall":
			out.append({"kind": "bench", "x": cx + 200.0, "y": b.x + 50.0})
		if _style in ["shophouse", "village", "city", "park", "quay"]:
			out.append({"kind": "tree", "x": cx + SPACING / 2.0, "y": b.y + 24.0})
		if i % 2 == 1 and _style in ["shophouse", "city", "village"]:
			out.append({"kind": "bike", "x": cx - 150.0, "y": b.x + 40.0})
		if _style == "mall":
			out.append({"kind": "plant", "x": cx + SPACING / 2.0, "y": b.x + 120.0})
	return out


func _draw_furniture(f: Dictionary) -> void:
	var p := Vector2(f.x - _cam, f.y)
	if p.x < -200 or p.x > _vs().x + 200:
		return
	match f.kind:
		"table":
			draw_set_transform(p * _k(), 0.0, Vector2(_k(), _k() * 0.3))
			draw_circle(Vector2.ZERO, 40.0, Color(0, 0, 0, 0.15))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2(_k(), _k()))
			draw_line(p, p + Vector2(0, -150), Color("#5A4A44"), 4.0)
			draw_colored_polygon(PackedVector2Array([p + Vector2(-80, -140), p + Vector2(0, -175), p + Vector2(80, -140)]), Color("#F4EDE2"))
			draw_colored_polygon(PackedVector2Array([p + Vector2(-80, -140), p + Vector2(-40, -158), p + Vector2(0, -140)]), Color("#C8553D"))
			draw_colored_polygon(PackedVector2Array([p + Vector2(0, -140), p + Vector2(40, -158), p + Vector2(80, -140)]), Color("#C8553D"))
			draw_set_transform(p * _k() + Vector2(0, -60) * _k(), 0.0, Vector2(_k(), _k() * 0.35))
			draw_circle(Vector2.ZERO, 46.0, Color("#E9E1D6"))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2(_k(), _k()))
			draw_line(p + Vector2(0, -60), p, Color("#3A3036"), 4.0)
			for side in [-1.0, 1.0]:
				var c: Vector2 = p + Vector2(side * 64.0, 0)
				draw_line(c, c + Vector2(0, -48), Color("#3A3036"), 3.0)
				draw_line(c + Vector2(-14, -40), c + Vector2(14, -40), Color("#3A3036"), 4.0)
				draw_line(c + Vector2(side * 14, -40), c + Vector2(side * 14, -80), Color("#3A3036"), 3.0)
			draw_rect(Rect2(p + Vector2(-8, -78), Vector2(10, 14)), Color("#FFFFFF"))
		"bench":
			draw_rect(Rect2(p + Vector2(-70, -46), Vector2(140, 10)), Color("#7A5A44"))
			draw_rect(Rect2(p + Vector2(-70, -80), Vector2(140, 8)), Color("#7A5A44"))
			for x in [-60.0, 60.0]:
				draw_line(p + Vector2(x, -84), p + Vector2(x, 0), Color("#2A2228"), 4.0)
		"tree":
			draw_rect(Rect2(p + Vector2(-34, -16), Vector2(68, 22)), Color("#5A5058"))
			draw_line(p + Vector2(0, -10), p + Vector2(0, -260), Color("#4A3628"), 10.0)
			var leaf := Color("#3E7048") if _style != "quay" else Color("#2D4B3A")
			for k in 7:
				var a := k * TAU / 7.0
				draw_circle(p + Vector2(cos(a) * 54.0, -290 + sin(a) * 40.0), 58.0, leaf.lerp(Color("#6EA567"), float(k % 3) / 3.0))
			draw_circle(p + Vector2(0, -300), 64.0, leaf.lightened(0.08))
		"bike":
			for x in [-34.0, 34.0]:
				draw_arc(p + Vector2(x, -30), 28.0, 0.0, TAU, 24, Color("#2A2228"), 4.0, true)
			draw_polyline(PackedVector2Array([p + Vector2(-34, -30), p + Vector2(-6, -70), p + Vector2(26, -70), p + Vector2(34, -30)]), Color("#C8553D"), 5.0, true)
			draw_line(p + Vector2(-6, -70), p + Vector2(0, -30), Color("#C8553D"), 5.0)
			draw_line(p + Vector2(26, -70), p + Vector2(22, -90), Color("#2A2228"), 4.0)
			draw_rect(Rect2(p + Vector2(-14, -80), Vector2(22, 7)), Color("#2A2228"))
		"plant":
			draw_rect(Rect2(p + Vector2(-40, -60), Vector2(80, 60)), Color("#F4EDE2"))
			for k in 9:
				var a := -PI / 2.0 + (k - 4) * 0.3
				draw_line(p + Vector2(0, -56), p + Vector2(0, -56) + Vector2(cos(a), sin(a)) * 120.0, Color("#3E7048"), 10.0, true)


func _draw_road(s: Vector2, g: float) -> void:
	if not _style in ["shophouse", "city", "village"]:
		return
	if _cars.is_empty():
		var colors := [Color("#C8553D"), Color("#F4EDE2"), Color("#2F6F73"), Color("#D9A441"), Color("#3A3640")]
		for i in 5:
			var lane := i % 2
			_cars.append({"x": _rng.randf() * _length, "speed": (160.0 + _rng.randf() * 80.0) * (1.0 if lane == 0 else -1.0),
				"y": _band().y + 110.0 + lane * 70.0, "color": colors[i]})
	for c in _cars:
		var p := Vector2(c.x - _cam, c.y)
		if p.x < -300 or p.x > s.x + 300:
			continue
		var col: Color = c.color
		draw_set_transform(p * _k() + Vector2(0, 6) * _k(), 0.0, Vector2(_k(), _k() * 0.25))
		draw_circle(Vector2.ZERO, 120.0, Color(0, 0, 0, 0.2))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(_k(), _k()))
		draw_style_box(UI.box(col, 22), Rect2(p + Vector2(-120, -70), Vector2(240, 60)))
		draw_style_box(UI.box(col.darkened(0.05), 26), Rect2(p + Vector2(-70, -118), Vector2(140, 60)))
		draw_style_box(UI.box(Color("#A9C8EC", 0.85), 14), Rect2(p + Vector2(-58, -108), Vector2(52, 40)))
		draw_style_box(UI.box(Color("#A9C8EC", 0.85), 14), Rect2(p + Vector2(4, -108), Vector2(52, 40)))
		for x in [-74.0, 74.0]:
			draw_circle(p + Vector2(x, -10), 24.0, Color("#1E1A22"))
			draw_circle(p + Vector2(x, -10), 10.0, Color("#8A8A8F"))
		var front := 1.0 if c.speed > 0 else -1.0
		draw_circle(p + Vector2(front * 112, -48), 7.0, Color("#FFE2A8"))
