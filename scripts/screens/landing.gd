extends Control
## Landing: one word, one sunset, and two strangers already tied by a red string.

const UI = preload("res://scripts/ui.gd")
const Avatar = preload("res://scripts/avatar.gd")

var params := {}
var _t := 0.0
var _left := {}
var _right := {}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_left = Avatar.random_config()
	_right = Avatar.random_config()

	var title := VBoxContainer.new()
	title.anchor_left = 0.5
	title.anchor_right = 0.5
	title.anchor_top = 0.22
	title.anchor_bottom = 0.22
	title.offset_left = -400
	title.offset_right = 400
	title.add_theme_constant_override("separation", 4)
	add_child(title)
	var word := UI.label("Somewhere", 120, UI.CREAM)
	word.add_theme_font_override("font", UI.serif(400, true))
	word.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	word.add_theme_color_override("font_shadow_color", Color(0.4, 0.1, 0.2, 0.35))
	word.add_theme_constant_override("shadow_offset_y", 4)
	title.add_child(word)
	var tag := UI.label("LET IT FIND YOU", 14, Color(UI.CREAM, 0.85))
	tag.add_theme_font_override("font", UI.spaced(600, 6))
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_child(tag)

	var actions := VBoxContainer.new()
	actions.anchor_left = 0.5
	actions.anchor_right = 0.5
	actions.anchor_top = 1.0
	actions.anchor_bottom = 1.0
	actions.offset_left = -170
	actions.offset_right = 170
	actions.offset_top = -300
	actions.offset_bottom = -60
	actions.add_theme_constant_override("separation", 12)
	add_child(actions)

	var primary := UI.button("Get started", "PrimaryButton")
	primary.custom_minimum_size.y = 58
	actions.add_child(primary)
	if Profile.has_profile():
		primary.text = "Continue as %s" % Profile.data.name
		primary.pressed.connect(func(): get_parent().go("map"))
		var restart := UI.button("Start a new profile", "TextButton")
		restart.pressed.connect(func():
			Profile.reset()
			get_parent().go("onboarding"))
		actions.add_child(restart)
	else:
		primary.pressed.connect(func():
			Profile.reset()
			get_parent().go("onboarding"))
	var friends := UI.button("Play with friends")
	friends.custom_minimum_size.y = 50
	friends.pressed.connect(_friends_panel)
	actions.add_child(friends)
	var legal := UI.label("By continuing, you agree to our Terms and acknowledge our Privacy Policy.", 13, UI.FAINT)
	legal.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	actions.add_child(legal)

	title.modulate.a = 0.0
	actions.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_interval(0.3)
	tw.tween_property(title, "modulate:a", 1.0, 1.6)
	tw.tween_property(actions, "modulate:a", 1.0, 0.9)


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _quad(y0: float, y1: float, c0: Color, c1: Color) -> void:
	draw_polygon(PackedVector2Array([Vector2(0, y0), Vector2(size.x, y0), Vector2(size.x, y1), Vector2(0, y1)]),
		PackedColorArray([c0, c0, c1, c1]))


func _draw() -> void:
	var s := size
	if s.x < 10.0:
		return
	var hz := s.y * 0.58
	_quad(0, hz * 0.55, Color("#1C1233"), Color("#6E2F57"))
	_quad(hz * 0.55, hz, Color("#6E2F57"), Color("#FF9466"))
	for i in 46:
		var p := Vector2(fposmod(i * 211.7, s.x), fposmod(i * 97.3, hz * 0.5))
		draw_circle(p, 1.1, Color(1, 1, 1, 0.25 + 0.2 * sin(_t * 1.5 + i)))

	var sun := Vector2(s.x * 0.5, hz + 6)
	for k in 8:
		draw_circle(sun, 90.0 + k * 50.0, Color(1.0, 0.72, 0.45, 0.06))
	draw_circle(sun, 86.0, Color("#FFD9A0"))

	_quad(hz, s.y * 0.8, Color("#F08A6E"), Color("#4A2650"))
	for i in 12:
		var w := 190.0 - i * 13.0 + sin(_t * 1.6 + i) * 22.0
		draw_rect(Rect2(sun.x - w / 2.0, hz + 6.0 + i * 13.0, w, 3.0), Color(1.0, 0.86, 0.62, 0.55 - i * 0.04))
	for row in 5:
		var wave := PackedVector2Array()
		for x in range(0, int(s.x) + 40, 40):
			wave.append(Vector2(x, hz + 22.0 + row * 26.0 + sin(x * 0.01 + _t * (0.5 + row * 0.15) + row) * 3.0))
		draw_polyline(wave, Color(1, 0.9, 0.85, 0.1), 1.5, true)

	var sand_y := s.y * 0.8
	var shore := PackedVector2Array()
	var cols := PackedColorArray()
	for x in range(0, int(s.x) + 40, 40):
		shore.append(Vector2(x, sand_y + sin(x * 0.008 + _t * 0.7) * 5.0))
		cols.append(Color("#E7A784"))
	shore.append(Vector2(s.x, s.y))
	cols.append(Color("#9C5C58"))
	shore.append(Vector2(0, s.y))
	cols.append(Color("#9C5C58"))
	draw_polygon(shore, cols)
	var foam := shore.slice(0, shore.size() - 2)
	draw_polyline(foam, Color(1, 0.96, 0.92, 0.75), 3.0, true)

	# Two strangers at either edge, already tied.
	var sc := s.y * 0.17 / 300.0
	var a := Vector2(s.x * 0.12, s.y * 0.96)
	var b := Vector2(s.x * 0.88, s.y * 0.96)
	var silhouette := {"mono": Color("#3A1B33")}
	Avatar.draw(self, _left, a, sc, _t, silhouette)
	Avatar.draw(self, _right, b, sc, _t + 1.3, silhouette)
	var from := a + Avatar.CHEST * sc + Vector2(14, 0)
	var to := b + Avatar.CHEST * sc - Vector2(14, 0)
	var mid := (from + to) / 2.0 + Vector2(sin(_t * 0.7) * 30.0, s.y * 0.05 + sin(_t * 1.1) * 8.0)
	var pts := PackedVector2Array()
	for i in 41:
		var u := i / 40.0
		pts.append(from.lerp(mid, u).lerp(mid.lerp(to, u), u))
	draw_polyline(pts, Color(UI.RED_STRING, 0.18 + 0.06 * sin(_t * 2.0)), 10.0, true)
	draw_polyline(pts, Color(UI.RED_STRING, 0.95), 2.2, true)


func _friends_panel() -> void:
	var overlay := Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)
	UI.scrim(overlay)
	var card := PanelContainer.new()
	card.theme_type_variation = "Card"
	card.anchor_left = 0.5
	card.anchor_right = 0.5
	card.anchor_top = 0.5
	card.anchor_bottom = 0.5
	card.offset_left = -300
	card.offset_right = 300
	card.offset_top = -290
	card.offset_bottom = 290
	overlay.add_child(card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	card.add_child(v)
	v.add_child(UI.eyebrow("Multiplayer", UI.GOLD))
	v.add_child(UI.title("Play with friends", 36))
	v.add_child(UI.label("One of you hosts on their computer; everyone else joins with the host's address. You'll see each other on the map and on the streets, and can follow strings and chat for real.", 14, UI.MUTED))
	var status := UI.label("", 14, UI.SAGE, 500)
	var show_status := func(st: String) -> void:
		var names := {"offline": "Not connected", "connecting": "Connecting...", "online": "Connected  ·  %d friend(s) here" % Net.players.size()}
		status.text = names.get(st, st)
		status.add_theme_color_override("font_color", UI.SAGE if st == "online" else UI.MUTED)
	var on_roster := func() -> void: show_status.call(Net.status)
	Net.status_changed.connect(show_status)
	Net.roster_changed.connect(on_roster)
	overlay.tree_exiting.connect(func() -> void:
		Net.status_changed.disconnect(show_status)
		Net.roster_changed.disconnect(on_roster))
	if Profile.data.get("handle", "") == "":
		var Validate = load("res://scripts/validate.gd")
		v.add_child(UI.eyebrow("First, pick your handle", UI.GOLD))
		var hrow := HBoxContainer.new()
		hrow.add_theme_constant_override("separation", 8)
		v.add_child(hrow)
		var he := LineEdit.new()
		he.placeholder_text = "yourname"
		he.max_length = 20
		he.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hrow.add_child(he)
		var hmsg := UI.label("", 13, UI.ROSE)
		var save := UI.button("Save")
		save.pressed.connect(func() -> void:
			var h := he.text.strip_edges().to_lower()
			var err: String = Validate.handle_error(h)
			hmsg.text = err
			if err == "":
				Profile.data.handle = h
				Profile.save()
				hmsg.text = "✓  You're @%s" % h
				hmsg.add_theme_color_override("font_color", UI.SAGE)
				save.disabled = true)
		hrow.add_child(save)
		v.add_child(hmsg)
		card.offset_top = -340
		card.offset_bottom = 340
	if Net.server_url() != "":
		v.add_child(UI.gap(4))
		v.add_child(UI.eyebrow("Online", UI.SAGE))
		v.add_child(UI.label("You're on the Somewhere server automatically. Send your friends the link; anyone who's playing shows up on the map and streets.", 14, UI.CREAM))
		var reconnect := UI.button("Reconnect")
		reconnect.pressed.connect(func() -> void: Net.join(Net.server_url()))
		v.add_child(reconnect)
	v.add_child(UI.gap(4))
	v.add_child(UI.eyebrow("Host"))
	var host := UI.button("Host a game on this computer", "PrimaryButton")
	host.custom_minimum_size.y = 50
	var addr := UI.label("", 14, UI.CREAM)
	host.pressed.connect(func() -> void:
		var err: String = Net.host()
		if err != "":
			addr.text = err
			return
		var ips: Array = Net.local_addresses()
		addr.text = "Friends on the same Wi-Fi join with:  " + ("  or  ".join(ips) if not ips.is_empty() else "your computer's IP address")
		host.disabled = true
		host.text = "Hosting")
	v.add_child(host)
	v.add_child(addr)
	v.add_child(UI.gap(4))
	v.add_child(UI.eyebrow("Join"))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	v.add_child(row)
	var input := LineEdit.new()
	input.placeholder_text = "Host's address, e.g. 192.168.1.23"
	input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	input.add_theme_font_size_override("font_size", 16)
	input.max_length = 200
	row.add_child(input)
	var join := UI.button("Join")
	join.custom_minimum_size = Vector2(90, 50)
	join.pressed.connect(func() -> void:
		if input.text.strip_edges() != "":
			Net.join(input.text.strip_edges()))
	row.add_child(join)
	v.add_child(status)
	v.add_child(UI.label("Everyone needs a finished profile with a handle. Playing across different networks needs the host to share a public tunnel address instead.", 12, UI.FAINT))
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(spacer)
	var done := UI.button("Done")
	done.custom_minimum_size.y = 48
	done.pressed.connect(overlay.queue_free)
	v.add_child(done)
	show_status.call(Net.status)
