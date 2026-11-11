extends Control
## Root of the game: owns the theme and moves between screens with a soft fade.
## Jump straight to a screen while developing: Godot --path . -- --screen=map

const UI = preload("res://scripts/ui.gd")
const SCREENS := {
	"landing": preload("res://scripts/screens/landing.gd"),
	"onboarding": preload("res://scripts/screens/onboarding.gd"),
	"avatar": preload("res://scripts/screens/avatar_room.gd"),
	"arrival": preload("res://scripts/screens/arrival.gd"),
	"map": preload("res://scripts/screens/map.gd"),
	"district": preload("res://scripts/screens/district.gd"),
	"venue": preload("res://scripts/screens/venue.gd"),
	"chat": preload("res://scripts/screens/chat.gd"),
	"banned": preload("res://scripts/screens/banned.gd"),
}

var current: Node
var _fade: ColorRect
var _busy := false
var _toasts: VBoxContainer


func _ready() -> void:
	name = "App"
	if "--relay" in OS.get_cmdline_user_args():
		# Online server: just the relay, no screens.
		var port := int(OS.get_environment("PORT")) if OS.get_environment("PORT").is_valid_int() else Net.PORT
		var err := Net.serve_only(port)
		print("Somewhere relay " + ("listening on port %d" % port if err == "" else err))
		return
	theme = UI.theme()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	get_window().title = "Somewhere"
	RenderingServer.set_default_clear_color(UI.PLUM_DEEP)
	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)
	_fade = ColorRect.new()
	_fade.color = UI.PLUM_DEEP
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(_fade)

	_toasts = VBoxContainer.new()
	_toasts.anchor_left = 0.5
	_toasts.anchor_right = 0.5
	_toasts.offset_left = -260
	_toasts.offset_right = 260
	_toasts.offset_top = 20
	_toasts.add_theme_constant_override("separation", 8)
	_toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var toast_layer := CanvasLayer.new()
	toast_layer.layer = 90
	add_child(toast_layer)
	var holder := Control.new()
	holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.theme = UI.theme()
	toast_layer.add_child(holder)
	holder.add_child(_toasts)
	Net.call_incoming.connect(_incoming_call)
	Profile.string_returned.connect(func(p: Dictionary) -> void:
		toast("%s followed your string back. You matched!" % p.name, "Say hi", func() -> void: go("chat", {"id": p.id})))

	var ghost_timer := Timer.new()
	ghost_timer.wait_time = clampf(Profile.DAY / 20.0, 2.0, 60.0)
	ghost_timer.autostart = true
	ghost_timer.timeout.connect(_check_ghosting)
	add_child(ghost_timer)

	var start := "landing"
	var params := {}
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--screen="):
			start = arg.trim_prefix("--screen=")
		elif arg.begins_with("--") and "=" in arg:
			var kv := arg.trim_prefix("--").split("=", true, 1)
			params[kv[0]] = int(kv[1]) if kv[1].is_valid_int() else kv[1].replace("_", " ")
	if start != "landing" and start != "onboarding" and not Profile.has_profile():
		Profile.use_demo()
	# With an online server configured, everyone connects automatically (it says hello once your profile is ready).
	if Net.server_url() != "" and not Net.is_online():
		Net.join(Net.server_url())
	go(start, params)


func go(screen: String, params := {}) -> void:
	if _busy or not SCREENS.has(screen):
		return
	if Profile.data.get("banned", false) and screen != "banned":
		screen = "banned"
	_busy = true
	_fade.mouse_filter = Control.MOUSE_FILTER_STOP
	if _fade.color.a < 1.0:
		var out := create_tween()
		out.tween_property(_fade, "color:a", 1.0, 0.35)
		await out.finished
	if current:
		current.queue_free()
	current = SCREENS[screen].new()
	current.set("params", params)
	add_child(current)
	move_child(current, 0)
	var back := create_tween()
	back.tween_property(_fade, "color:a", 0.0, 0.6)
	await back.finished
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_busy = false


## A small notification at the top of the screen, with an optional action.
func toast(text: String, action_text := "", action := Callable()) -> void:
	var card := PanelContainer.new()
	var sb := UI.box(Color(0.97, 0.94, 0.9, 0.98), 18, Color(0, 0, 0, 0), 0, 18, 12)
	sb.shadow_color = Color(0, 0, 0, 0.3)
	sb.shadow_size = 18
	card.add_theme_stylebox_override("panel", sb)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	card.add_child(row)
	var l := UI.label(text, 15, UI.INK, 500)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(l)
	if action_text != "":
		var b := UI.button(action_text)
		b.add_theme_color_override("font_color", UI.INK)
		b.add_theme_color_override("font_hover_color", UI.INK)
		b.add_theme_stylebox_override("normal", UI.box(Color(0, 0, 0, 0.06), 16, Color(0, 0, 0, 0.2), 1, 14, 8))
		b.add_theme_stylebox_override("hover", UI.box(Color(0, 0, 0, 0.12), 16, Color(0, 0, 0, 0.3), 1, 14, 8))
		b.pressed.connect(func() -> void:
			card.queue_free()
			action.call())
		row.add_child(b)
	_toasts.add_child(card)
	# Never more than two at once, so they don't cover the screen.
	var plain := _toasts.get_children().filter(func(c: Node) -> bool: return not c.has_meta("call"))
	while plain.size() > 2:
		var old: Node = plain.pop_front()
		_toasts.remove_child(old)
		old.queue_free()
	card.modulate.a = 0.0
	var tw := card.create_tween()
	tw.tween_property(card, "modulate:a", 1.0, 0.3)
	tw.tween_interval(7.0)
	tw.tween_property(card, "modulate:a", 0.0, 0.5)
	tw.tween_callback(card.queue_free)


func _incoming_call(handle: String) -> void:
	var person := Net.person_for(handle)
	var card := PanelContainer.new()
	card.theme_type_variation = "Card"
	card.set_meta("call", true)
	card.custom_minimum_size.x = 420
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	card.add_child(row)
	row.add_child(preload("res://scripts/portrait.gd").make(person.cfg, 56, UI.SAGE))
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_child(UI.eyebrow("Incoming voice call", UI.SAGE))
	text.add_child(UI.title(person.name, 24))
	row.add_child(text)
	var accept := UI.button("Accept", "PrimaryButton")
	accept.pressed.connect(func() -> void:
		card.queue_free()
		Net.accept_call()
		go("chat", {"id": person.id}))
	row.add_child(accept)
	var decline := UI.button("Decline")
	decline.pressed.connect(func() -> void:
		card.queue_free()
		Net.end_call())
	row.add_child(decline)
	_toasts.add_child(card)
	Net.call_state_changed.connect(func(st: String) -> void:
		if st == "idle" and is_instance_valid(card):
			card.queue_free(), CONNECT_ONE_SHOT)


func _check_ghosting() -> void:
	for e in Profile.check_ghosting():
		match e[0]:
			"reminder":
				var p: Dictionary = e[1]
				toast("Reminder %d of %d: %s is waiting on a reply. Reply, or close the conversation kindly." % [e[2], Profile.REMINDERS_PER_STRIKE, p.name],
					"Open chat", func() -> void: go("chat", {"id": p.id}))
			"strike":
				_strike_card(int(e[1]))
			"banned":
				go("banned")


func _strike_card(n: int) -> void:
	var overlay := Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var layer := CanvasLayer.new()
	layer.layer = 95
	add_child(layer)
	var holder := Control.new()
	holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	holder.theme = UI.theme()
	layer.add_child(holder)
	holder.add_child(overlay)
	UI.scrim(overlay)
	var card := PanelContainer.new()
	card.theme_type_variation = "Card"
	card.anchor_left = 0.5
	card.anchor_right = 0.5
	card.anchor_top = 0.5
	card.anchor_bottom = 0.5
	card.offset_left = -280
	card.offset_right = 280
	card.offset_top = -190
	card.offset_bottom = 190
	overlay.add_child(card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	card.add_child(v)
	v.add_child(UI.eyebrow("Strike %d of %d" % [n, Profile.STRIKES_TO_BAN], UI.ROSE))
	v.add_child(UI.title("Someone was left waiting.", 32))
	v.add_child(UI.label("You didn't reply after three reminders. Ghosting hurts, so it counts as a strike. At %d strikes, your account is closed." % Profile.STRIKES_TO_BAN, 15, UI.MUTED))
	v.add_child(UI.label("Not feeling a conversation? Use Close kindly. It never counts against you.", 14, UI.CREAM))
	var ok := UI.button("I understand", "PrimaryButton")
	ok.custom_minimum_size.y = 50
	ok.pressed.connect(layer.queue_free)
	v.add_child(ok)
