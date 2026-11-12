extends Control
## Inside a venue. People are here doing their thing; tap anyone to see who they are.
## Bars run trivia night, where you can team up with a stranger.

const UI = preload("res://scripts/ui.gd")
const Avatar = preload("res://scripts/avatar.gd")
const Places = preload("res://scripts/places.gd")
const Quests = preload("res://scripts/quests.gd")
const People = preload("res://scripts/people.gd")
const ProfileView = preload("res://scripts/ui/profile_view.gd")
const Trivia = preload("res://scripts/ui/trivia.gd")
const Dock = preload("res://scripts/ui/dock.gd")
const Activities = preload("res://scripts/ui/activities.gd")

const SPOTS := [0.38, 0.52, 0.66, 0.8, 0.45, 0.73]
## Tables you can sit at (x as a fraction of the screen). Two seats each: seat = table * 2 + side.
const TABLES := {"cafe": [0.54, 0.8], "restaurant": [0.54, 0.8], "bar": [0.54, 0.8], "bookstore": [0.54, 0.8], "records": [0.56], "gallery": [0.62]}
const Synth = preload("res://scripts/synth.gd")

## Little things to do in each room: [label, x, y (fractions of the screen), kind, payload]
const PROPS := {
	"bar": [["Jukebox", 0.1, 0.62, "tune", null], ["Order a drink", 0.6, 0.55, "choose", ["What'll it be?", ["Lime soda", "House lager", "Old fashioned", "Ginger beer"], "The bartender slides over a %s."]]],
	"club": [["Request a song", 0.55, 0.52, "tune", null], ["Coat check", 0.08, 0.62, "text", ["Coat check", "Ticket number 27. Don't lose it."]]],
	"cafe": [["Menu board", 0.48, 0.2, "choose", ["Order something", ["Flat white", "Iced matcha", "Banana bread", "Kaya toast"], "Your %s arrives with a little heart drawn on the napkin."]], ["Notice board", 0.13, 0.4, "random", ["Notice board", ["Lost: one blue umbrella. Sentimental value.", "Book club, Thursdays at 7. This month: anything with a map in it.", "Free guitar lessons for anyone who brings pastries.", "Run club leaves from here every Saturday, 7am. All paces."]]]],
	"restaurant": [["Tonight's specials", 0.2, 0.25, "random", ["Specials", ["Charred cabbage, miso butter.", "Slow-cooked beef rendang.", "Burnt basque cheesecake (it's supposed to look like that)."]]], ["Kitchen pass", 0.76, 0.3, "text", ["The kitchen", "The chef waves at you through the steam. You wave back. This is now a friendship."]]],
	"thrift": [["Mirror", 0.11, 0.4, "activity", null], ["Bargain bin", 0.88, 0.62, "random", ["Bargain bin", ["A silk scarf with tiny lemons on it. $3.", "A denim jacket covered in pins from 1994.", "A tie that plays a tune when squeezed.", "A perfectly good raincoat, somehow $2."]]]],
	"gallery": [["Guestbook", 0.47, 0.6, "guestbook", null], ["Artist statement", 0.88, 0.62, "text", ["Artist statement", "These works are about the space between strangers, and the moment it closes."]]],
	"bookstore": [["Staff picks", 0.3, 0.3, "random", ["Staff pick", ["A novel about a lighthouse keeper who answers letters.", "Essays on walking cities at night.", "A cookbook organised by mood.", "Poems you can read in the time it takes a kettle to boil."]]], ["Reading chair", 0.9, 0.62, "text", ["Reading chair", "You sit for a while. Nobody rushes you. The chair has clearly seen many good afternoons."]]],
	"records": [["Turntable", 0.86, 0.55, "tune", null], ["Crate dig", 0.3, 0.6, "random", ["Crate dig", ["A jazz record with a coffee ring on the sleeve.", "A 90s dance single, signed by nobody you know.", "Field recordings of rain. Weirdly perfect.", "A soundtrack to a film that doesn't exist."]]]],
	"arcade": [["Claw machine", 0.1, 0.45, "claw", null], ["Photo booth", 0.9, 0.45, "photobooth", null]],
	"studio": [["Class schedule", 0.15, 0.25, "text", ["This week", "Mon: Slow flow. Wed: Breathwork. Fri: Sunset stretch. Sun: Nap (unofficial)."]], ["Water station", 0.9, 0.6, "text", ["Water station", "Cucumber water. You feel 4% healthier."]]],
}
const CHATTER := {
	"bar": ["Is it trivia or karaoke tonight?", "One more round?", "This song is a classic.", "Who's winning?"],
	"club": ["I love this track!", "Shall we dance?", "The DJ is good tonight.", "Water break, then back out."],
	"cafe": ["Has anyone tried the banana bread?", "Working from here today.", "This is my third coffee.", "Sorry, is this seat taken?"],
	"restaurant": ["Should we share everything?", "The specials sound good.", "Save room for dessert.", "Cheers to Friday."],
	"thrift": ["Is this vintage or just old?", "Five dollars! Unbelievable.", "Does this suit me?", "Found it!"],
	"gallery": ["What do you think it means?", "I love the colours.", "My kid could do this. Kidding.", "This one's my favourite."],
	"bookstore": ["Have you read this one?", "Just browsing...", "The ending ruined me.", "Staff picks are always good here."],
	"records": ["Listen to this bassline.", "They don't make them like this anymore.", "Crate digging, my favourite sport.", "Is this a first pressing?"],
	"arcade": ["One more go!", "New high score!", "Air hockey rematch?", "I'm terrible at this."],
	"studio": ["First time here?", "My hamstrings disagree.", "Namaste, I guess.", "That was exactly what I needed."],
}

var params := {}
var _type := "bar"
var _name := ""
var _place := {}
var _people := []
var _hover := -1
var _t := 0.0
var _overlay: Control
var _staff := {}
var _bubble := {"who": -1, "text": "", "until": 0.0}
var _bubble_in := 2.0
var _hover_prop := -1
var _player: AudioStreamPlayer
var _popover: Control
var _partner := {}
var _seat := -1
var _join: Button
var _host_btn: Button
var _status: Label
var _hover_table := -1


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	_type = params.get("type", "bar")
	_name = params.get("venue", "The Riverside Tap")
	_place = Places.find(params.get("place", "Clarke Quay"))
	var cats: Array = _place.get("cats", [])
	for i in (SPOTS.size() if Profile.DEMO_PEOPLE else 0):
		# Venues attract people who are into what the place is about.
		var lean: Array = [cats[i % cats.size()]] if not cats.is_empty() and i % 2 == 0 else []
		_people.append(People.make("%s-%d" % [_name, i], lean))
	_partner = Profile.quest_partner(_place.get("name", ""), _type)
	if not _partner.is_empty() and not _people.is_empty():
		_people[0] = _partner
	_build_hud()
	_listen_for_invites()
	Dock.attach(self, "", _back_params())
	_staff = People.make(_name + "-staff")
	Profile.quest_event.call_deferred("enter", _place.get("name", ""), _type)
	_player = AudioStreamPlayer.new()
	add_child(_player)


func _build_hud() -> void:
	var plate := PanelContainer.new()
	plate.position = Vector2(28, 24)
	plate.add_theme_stylebox_override("panel", UI.box(Color(0.07, 0.045, 0.1, 0.62), 20, Color(1, 1, 1, 0.08), 1, 24, 18))
	add_child(plate)
	var head := VBoxContainer.new()
	head.add_theme_constant_override("separation", 4)
	plate.add_child(head)
	var back := UI.button("‹  Back outside", "TextButton")
	back.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	back.pressed.connect(_leave)
	head.add_child(back)
	head.add_child(UI.eyebrow(Places.VENUE_LABELS[_type] + "  ·  " + params.get("mall", _place.get("name", "")), Color(1, 1, 1, 0.7)))
	var t := UI.nowrap(UI.title(_name, 44, Color.WHITE))
	t.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.4))
	t.add_theme_constant_override("shadow_offset_y", 2)
	head.add_child(t)

	var card := PanelContainer.new()
	card.theme_type_variation = "Card"
	card.anchor_left = 1.0
	card.anchor_right = 1.0
	card.offset_left = -440
	card.offset_right = -36
	card.offset_top = 30
	add_child(card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	card.add_child(v)
	v.add_child(UI.eyebrow("Tonight", UI.GOLD))
	v.add_child(UI.label(Places.VENUE_MOOD[_type], 18, UI.CREAM, 500))
	_status = UI.label("", 14, UI.MUTED)
	v.add_child(_status)
	_join = UI.button("Join trivia" if _type == "bar" else Activities.ACTIONS.get(_type, "Join in"), "PrimaryButton")
	_join.custom_minimum_size.y = 48
	_join.pressed.connect(_on_join)
	v.add_child(_join)
	_host_btn = UI.button("", "TextButton")
	_host_btn.pressed.connect(func() -> void: _start_activity())
	v.add_child(_host_btn)
	_stand_btn = UI.button("Stand up from the table", "TextButton")
	_stand_btn.pressed.connect(func() -> void:
		_seat = -1
		_refresh_hud())
	v.add_child(_stand_btn)
	_quest_nudge = UI.button("", "TextButton")
	_quest_nudge.pressed.connect(_nudge_partner)
	v.add_child(_quest_nudge)
	_refresh_hud()


var _quest_nudge: Button
var _stand_btn: Button
var _hud_clock := 0.0


## Who you'd play with right now: someone at your table, then your quest partner, then the only friend here.
func _play_target() -> String:
	var fr := _friends()
	var mates := _tablemates()
	if not mates.is_empty():
		return mates[0]
	var qp := Profile.real_quest_partner(_place.get("name", ""))
	if qp != "" and qp in fr:
		return qp
	if fr.size() == 1:
		return fr[0]
	return ""


func _activity_name() -> String:
	return "trivia" if _type == "bar" else Activities.ACTIONS.get(_type, "join in").to_lower()


func _refresh_hud() -> void:
	if _join == null:
		return
	var fr := _friends()
	var target := _play_target()
	var qp := Profile.real_quest_partner(_place.get("name", ""))
	var q := Profile.quest_here(_place.get("name", ""))
	var qv: String = Quests.venue_of(q)[0] if not q.is_empty() else ""
	_quest_nudge.visible = false
	if not q.is_empty() and qv != "" and qv != _name and not params.has("mall"):
		_status.text = "Your quest is at %s, a few doors down. Head back outside and look for the gold star." % qv
		_status.add_theme_color_override("font_color", UI.GOLD)
	elif qp != "" and qp in fr:
		_status.text = "@%s is here for your quest. Sit at a table together, or just tap Play." % qp
		_status.add_theme_color_override("font_color", UI.GOLD)
	elif qp != "":
		var online := Net.players.has(qp)
		_status.text = ("Your quest partner @%s is %s." % [qp, Net.where_text(qp)]) if online else "Your quest partner @%s isn't online right now." % qp
		_status.add_theme_color_override("font_color", UI.GOLD)
		_quest_nudge.text = "Tell @%s you're here  ›" % qp
		_quest_nudge.visible = true
	elif not _partner.is_empty():
		_status.text = "%s is here for your quest. Do it together." % _partner.name
		_status.add_theme_color_override("font_color", UI.GOLD)
	else:
		var here := _people.size() + fr.size()
		_status.text = "Nobody else is here yet. Your friends can find you from Who's on." if here == 0 \
			else "%d %s here. Tap a table to sit, or tap someone to see who they are." % [here, "person" if here == 1 else "people"]
		_status.add_theme_color_override("font_color", UI.MUTED)
	if target != "":
		_join.text = "Play %s with @%s" % ["trivia" if _type == "bar" else "together", target]
		_host_btn.text = "or play with %s, the host" % _staff_name()
		_host_btn.visible = true
	else:
		_join.text = "Join trivia" if _type == "bar" else Activities.ACTIONS.get(_type, "Join in")
		_host_btn.visible = false
	_refresh_table_card()


func _on_join() -> void:
	var target := _play_target()
	if target == "":
		_start_activity()
		return
	_invite(target)


func _invite(handle: String) -> void:
	_invite_seed = randi() % 1000000 + 1
	Net.send_invite(handle, _name, _invite_seed)
	get_parent().toast("Asked @%s to play. Waiting for them to say yes…" % handle)


func _nudge_partner() -> void:
	var qp := Profile.real_quest_partner(_place.get("name", ""))
	if qp == "":
		return
	var id := Net.person_id(qp)
	var text := "I'm at %s in %s for our quest. Come find me! (Who's on → Go to them)" % [_name, _place.get("name", "")]
	Net.send_chat(qp, text)
	if Profile.data.matches.has(id):
		Profile.add_message(id, true, text)
	get_parent().toast("Sent @%s a message saying where you are." % qp)
	_quest_nudge.visible = false


# --- Tables --------------------------------------------------------------------------

func _tables() -> Array:
	return TABLES.get(_type, [])


func _table_center(t: int) -> Vector2:
	return Vector2(size.x * float(_tables()[t]), size.y * 0.84)


func _seat_pos(seat: int) -> Vector2:
	var c := _table_center(seat / 2)
	return Vector2(c.x + (-1.0 if seat % 2 == 0 else 1.0) * size.x * 0.055, size.y * 0.97)


func _table_rect(t: int) -> Rect2:
	var c := _table_center(t)
	var w := size.x * 0.2
	return Rect2(c.x - w / 2.0, c.y - size.y * 0.3, w, size.y * 0.46)


func _table_at(pos: Vector2) -> int:
	for t in _tables().size():
		if _table_rect(t).has_point(pos):
			return t
	return -1


## Who's sitting in a seat here (a friend's handle, "me", or "").
func _seated(seat: int) -> String:
	if seat == _seat:
		return "me"
	for h in _friends():
		if Net.seat_of(h) == seat:
			return h
	return ""


func _tablemates() -> Array:
	if _seat < 0:
		return []
	var other := _seat + (1 if _seat % 2 == 0 else -1)
	var h := _seated(other)
	return [h] if h != "" and h != "me" else []


func _click_table(t: int) -> void:
	if _seat >= 0 and _seat / 2 == t:
		_seat = -1
		_refresh_hud()
		return
	for side in 2:
		if _seated(t * 2 + side) == "":
			_seat = t * 2 + side
			var mates := _tablemates()
			get_parent().toast(("You sat down with @%s." % mates[0]) if not mates.is_empty() else "You took a seat. Friends can sit with you.")
			_refresh_hud()
			return
	get_parent().toast("That table's full. Try another one.")


func _refresh_table_card() -> void:
	_stand_btn.visible = _seat >= 0
	if _seat < 0:
		return
	var mates := _tablemates()
	if mates.is_empty():
		_status.text = "You're sitting at a table. When a friend sits with you, you can play together."
	else:
		_status.text = "You're at a table with @%s." % mates[0]
	_status.add_theme_color_override("font_color", UI.SAGE)


func _leave() -> void:
	var p := {"place": _place.get("name", ""), "at": int(params.get("door", 0))}
	if params.has("mall"):
		p.mall = params.mall
	get_parent().go("district", p)


func _back_params() -> Dictionary:
	var p := params.duplicate()
	p.screen = "venue"
	return p


func _staff_name() -> String:
	return People.host(_name).name


func _start_activity(with := {}) -> void:
	if _people.is_empty() and with.is_empty():
		# Real people only: activities aren't shared live yet, so the venue host plays with you.
		with = People.host(_name)
	var best: Dictionary = with if _people.is_empty() else _people[0]
	if not with.is_empty():
		best = with
	elif _partner.is_empty():
		for p in _people:
			if not Profile.data.matches.has(p.id) and People.shared_with_me(p) >= People.shared_with_me(best):
				best = p
	if _type == "bar":
		_overlay = Trivia.open(self, best, _name)
	else:
		_overlay = Activities.open(self, _type, best, _name)
	_overlay.profile_requested.connect(_open_profile)
	_overlay.completed.connect(func() -> void: Profile.quest_event("activity", _place.get("name", ""), _type))


func _open_profile(p: Dictionary, invite := false) -> void:
	var play := ""
	if invite and p.get("real", false):
		# Real people: trivia is played live together. Other activities aren't shared yet.
		play = "Invite to play trivia" if _type == "bar" else "Invite to: " + _activity_name()
	elif invite:
		play = "Invite to play trivia" if _type == "bar" else "Invite to: " + Activities.ACTIONS.get(_type, "join in").to_lower()
	_overlay = ProfileView.open(self, p, _name, play)
	if p.get("real", false) and invite:
		var seat := Net.seat_of(p.handle)
		if seat >= 0 and _seated(seat + (1 if seat % 2 == 0 else -1)) == "":
			_overlay.add_action("Sit with @%s" % p.handle, func() -> void:
				_seat = seat + (1 if seat % 2 == 0 else -1)
				get_parent().toast("You sat down with @%s." % p.handle)
				_refresh_hud())
	_overlay.chat_requested.connect(func(id: String) -> void: get_parent().go("chat", {"id": id, "back": _back_params()}))
	_overlay.play_requested.connect(func(who: Dictionary) -> void:
		if who.get("real", false):
			_invite(who.handle)
			return
		get_parent().toast("%s said yes. Let's go!" % who.name)
		_start_activity(who))


var _invite_seed := 0


## Live invites between real people in this venue.
func _listen_for_invites() -> void:
	var on_invite := func(handle: String, venue_name: String, seed: int) -> void:
		if venue_name != _name or (_overlay and is_instance_valid(_overlay)):
			if venue_name == _name:
				Net.reply_invite(handle, false, seed)
			return
		_invite_card(handle, seed)
	var on_answer := func(handle: String, yes: bool, seed: int) -> void:
		if seed != _invite_seed:
			return
		_invite_seed = 0
		if not yes:
			get_parent().toast("@%s can't play right now. Maybe later!" % handle)
			return
		get_parent().toast("@%s said yes! Starting now." % handle)
		_start_live(Net.person_for(handle), seed)
	Net.invited.connect(on_invite)
	Net.invite_answered.connect(on_answer)
	tree_exiting.connect(func() -> void:
		Net.invited.disconnect(on_invite)
		Net.invite_answered.disconnect(on_answer))


func _invite_card(handle: String, seed: int) -> void:
	var person := Net.person_for(handle)
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
	card.offset_left = -250
	card.offset_right = 250
	card.offset_top = -150
	card.offset_bottom = 150
	overlay.add_child(card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	card.add_child(v)
	v.add_child(UI.eyebrow(("Trivia night" if _type == "bar" else Activities.ACTIONS.get(_type, "Play")) + "  ·  " + _name, UI.GOLD))
	v.add_child(UI.title("@%s wants to play with you" % handle, 30))
	v.add_child(UI.label("%s%s is here in %s and asked you to %s together." % [person.name, (" (" + person.pronouns + ")") if person.pronouns != "" else "", _name, "play trivia" if _type == "bar" else _activity_name()], 15, UI.MUTED))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	v.add_child(row)
	var yes := UI.button("Let's play", "PrimaryButton")
	yes.pressed.connect(func() -> void:
		overlay.queue_free()
		Net.reply_invite(handle, true, seed)
		_start_live(person, seed))
	row.add_child(yes)
	var no := UI.button("Not now")
	no.pressed.connect(func() -> void:
		overlay.queue_free()
		Net.reply_invite(handle, false, seed))
	row.add_child(no)
	var view := UI.button("See profile", "TextButton")
	view.pressed.connect(func() -> void: ProfileView.open(self, person, _name))
	row.add_child(view)


func _start_live(person: Dictionary, seed: int) -> void:
	if _overlay and is_instance_valid(_overlay):
		_overlay.queue_free()
	if _type == "bar":
		_overlay = Trivia.open(self, person, _name, seed)
	else:
		_overlay = Activities.open(self, _type, person, _name, seed)
	_overlay.profile_requested.connect(_open_profile)
	_overlay.completed.connect(func() -> void: Profile.quest_event("activity", _place.get("name", ""), _type))


func _feet(i: int) -> Vector2:
	# The last two stand further back, so the room feels fuller.
	return Vector2(size.x * SPOTS[i], size.y * (0.86 if i < 4 else 0.76))


func _scale() -> float:
	return size.y * 0.4 / 300.0


func _person_at(pos: Vector2) -> int:
	for i in _people.size():
		var f := _feet(i)
		if Rect2(f + Vector2(-40, -size.y * 0.42), Vector2(80, size.y * 0.42)).has_point(pos):
			return i
	return -1


func _gui_input(event: InputEvent) -> void:
	if _overlay and is_instance_valid(_overlay):
		return
	if event is InputEventMouseMotion:
		_hover_prop = _prop_at(event.position)
		_hover = _person_at(event.position) if _hover_prop < 0 else -1
		_hover_table = _table_at(event.position) if _hover_prop < 0 and _hover < 0 and _friend_at(event.position) == "" else -1
		if _hover_prop >= 0 or _hover_table >= 0:
			mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			return
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if _hover >= 0 else Control.CURSOR_ARROW
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var prop := _prop_at(event.position)
		if prop >= 0:
			_use_prop(PROPS[_type][prop])
			return
		var friend := _friend_at(event.position)
		if friend != "":
			_open_profile(Net.person_for(friend), true)
			return
		var i := _person_at(event.position)
		if i >= 0:
			_open_profile(_people[i], true)
			return
		var t := _table_at(event.position)
		if t >= 0:
			_click_table(t)


func _process(delta: float) -> void:
	_t += delta
	_bubble_in -= delta
	if _bubble_in <= 0.0:
		var lines: Array = CHATTER.get(_type, [])
		if not lines.is_empty() and not _people.is_empty():
			_bubble = {"who": randi() % _people.size(), "text": lines[randi() % lines.size()], "until": _t + 3.5}
		_bubble_in = randf_range(4.0, 8.0)
	var extra := {"type": _type, "door": int(params.get("door", 0)), "seat": _seat}
	if params.has("mall"):
		extra.mall = str(params.mall)
	Net.set_presence("venue", _place.get("name", ""), _name, Vector2.ZERO, extra)
	_hud_clock -= delta
	if _hud_clock <= 0.0:
		_hud_clock = 0.5
		# A friend took my seat while I sat down at the same moment: stand up.
		if _seat >= 0:
			for h in _friends():
				if Net.seat_of(h) == _seat and h < str(Profile.data.get("handle", "")):
					_seat = -1
		_refresh_hud()
	queue_redraw()


## Friends who are in this same venue right now.
func _friends() -> Array:
	return Net.players_where("venue", _place.get("name", ""), _name)


func _friend_feet(i: int) -> Vector2:
	var h: String = _friends()[i] if i < _friends().size() else ""
	var seat := Net.seat_of(h) if h != "" else -1
	if seat >= 0 and seat / 2 < _tables().size():
		return _seat_pos(seat)
	return Vector2(size.x * (0.25 + i * 0.065), size.y * 0.8)


func _friend_at(pos: Vector2) -> String:
	var fr := _friends()
	for i in fr.size():
		var f := _friend_feet(i)
		if Rect2(f + Vector2(-34, -size.y * 0.36), Vector2(68, size.y * 0.36)).has_point(pos):
			return fr[i]
	return ""


# --- Drawing --------------------------------------------------------------------

func _quad(r: Rect2, c0: Color, c1: Color) -> void:
	draw_polygon(PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]),
		PackedColorArray([c0, c0, c1, c1]))


func _glow(c: Vector2, r: float, col: Color, steps := 10) -> void:
	for k in steps:
		draw_circle(c, r * (1.0 - float(k) / steps), Color(col, col.a / steps * 2.0))


func _pendant(x: float, y: float, col := Color(1.0, 0.8, 0.5)) -> void:
	draw_line(Vector2(x, 0), Vector2(x, y), Color(0, 0, 0, 0.6), 1.5)
	draw_colored_polygon(PackedVector2Array([Vector2(x - 20, y + 18), Vector2(x - 8, y), Vector2(x + 8, y), Vector2(x + 20, y + 18)]), Color("#1A1414"))
	_glow(Vector2(x, y + 22), 160.0, Color(col, 0.3))
	draw_circle(Vector2(x, y + 20), 5.0, col.lightened(0.4))


func _draw() -> void:
	var s := size
	if s.x < 10.0:
		return
	var floor_y := s.y * 0.7
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(_name)
	match _type:
		"bar", "club":
			var club := _type == "club"
			_quad(Rect2(0, 0, s.x, floor_y), Color("#160E14") if club else Color("#24161A"), Color("#2C1A20") if club else Color("#3B2420"))
			if club:
				var cols := [Color("#B57BFF"), Color("#FF6FB1"), Color("#5FD4FF")]
				for i in 6:
					var x := s.x * (0.1 + i * 0.16)
					var sway := sin(_t * 0.8 + i) * 120.0
					draw_colored_polygon(PackedVector2Array([Vector2(x, 0), Vector2(x + sway - 90, floor_y + 60), Vector2(x + sway + 90, floor_y + 60)]), Color(cols[i % 3], 0.1))
				draw_rect(Rect2(s.x * 0.45, floor_y - 150, s.x * 0.2, 150), Color("#0E0A10"))
				draw_rect(Rect2(s.x * 0.47, floor_y - 160, s.x * 0.16, 12), Color("#2A2030"))
			else:
				# Back bar: shelves of bottles, glowing.
				var shelf := Rect2(s.x * 0.3, s.y * 0.2, s.x * 0.62, s.y * 0.3)
				_quad(shelf, Color("#4A2A1E"), Color("#2C1814"))
				_glow(shelf.get_center(), shelf.size.x * 0.5, Color(1.0, 0.7, 0.4, 0.18))
				for row in 3:
					var y := shelf.position.y + 20 + row * shelf.size.y / 3.0
					draw_rect(Rect2(shelf.position.x, y + shelf.size.y / 3.0 - 26, shelf.size.x, 5), Color("#6A4430"))
					var x := shelf.position.x + 14
					while x < shelf.end.x - 20:
						var bh := rng.randf_range(34, 58)
						var bc: Color = [Color("#7DBB8A"), Color("#E6B55C"), Color("#B5523F"), Color("#9EC6D9"), Color("#E9E1D0")][rng.randi() % 5]
						draw_rect(Rect2(x, y + shelf.size.y / 3.0 - 26 - bh, 12, bh), Color(bc, 0.85))
						draw_rect(Rect2(x + 3, y + shelf.size.y / 3.0 - 26 - bh - 10, 6, 10), Color(bc, 0.85))
						x += rng.randf_range(16, 26)
				# Trivia board.
				var board := Rect2(s.x * 0.05, s.y * 0.34, s.x * 0.19, s.y * 0.19)
				draw_rect(board, Color("#1B2420"))
				draw_rect(board, Color("#6A4430"), false, 6.0)
				draw_string(UI.serif(500, true), board.position + Vector2(0, board.size.y * 0.42), "Trivia Night", HORIZONTAL_ALIGNMENT_CENTER, board.size.x, 26, Color("#F2EBDD"))
				draw_string(UI.spaced(600, 2), board.position + Vector2(0, board.size.y * 0.7), "TONIGHT  ·  8PM", HORIZONTAL_ALIGNMENT_CENTER, board.size.x, 12, UI.GOLD)
				draw_rect(Rect2(s.x * 0.28, floor_y - 120, s.x * 0.66, 120), Color("#3A1F17"))
				draw_rect(Rect2(s.x * 0.27, floor_y - 128, s.x * 0.68, 12), Color("#7A4A30"))
			for i in 4:
				_pendant(s.x * (0.2 + i * 0.2), s.y * 0.08, Color(1.0, 0.7, 0.45) if not club else Color(0.8, 0.6, 1.0))
			_quad(Rect2(0, floor_y, s.x, s.y - floor_y), Color("#2A1A16"), Color("#120B0A"))
		"restaurant":
			_quad(Rect2(0, 0, s.x, floor_y), Color("#5A2E2A"), Color("#3A1E1C"))
			draw_rect(Rect2(0, floor_y - 120, s.x, 120), Color("#2E1715"))
			draw_line(Vector2(0, floor_y - 120), Vector2(s.x, floor_y - 120), Color("#B88A5A"), 3.0)
			var pass_win := Rect2(s.x * 0.62, s.y * 0.16, s.x * 0.3, s.y * 0.2)
			_quad(pass_win, Color(1.0, 0.82, 0.55), Color(1.0, 0.65, 0.4))
			draw_rect(pass_win, Color("#1E1210"), false, 8.0)
			for i in 3:
				var m := Rect2(s.x * (0.1 + i * 0.16), s.y * 0.14, s.x * 0.1, s.y * 0.24)
				draw_rect(m, Color(1, 0.9, 0.8, 0.12))
				draw_rect(m, Color("#B88A5A"), false, 4.0)
			_quad(Rect2(0, floor_y, s.x, s.y - floor_y), Color("#3A2420"), Color("#1A100E"))
			for i in 4:
				var c := Vector2(s.x * (0.12 + i * 0.26), floor_y + 50)
				draw_set_transform(c, 0.0, Vector2(1.0, 0.3))
				draw_circle(Vector2.ZERO, 90.0, Color("#F2EBDD"))
				draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
				draw_rect(Rect2(c.x - 3, c.y - 22, 6, 18), Color("#F2EBDD"))
				_glow(c + Vector2(0, -26), 60.0, Color(1.0, 0.75, 0.4, 0.5), 6)
				draw_circle(c + Vector2(0, -26), 3.0, Color("#FFE2A0"))
		"cafe":
			_quad(Rect2(0, 0, s.x, floor_y), Color("#EADBC8"), Color("#D9C4AA"))
			for i in 2:
				var b := Rect2(s.x * (0.4 + i * 0.2), s.y * 0.1, s.x * 0.17, s.y * 0.22)
				draw_rect(b, Color("#2B2A28"))
				draw_string(UI.serif(500, true), b.position + Vector2(0, 30), ["Coffee", "Bakes"][i], HORIZONTAL_ALIGNMENT_CENTER, b.size.x, 22, Color("#F2EBDD"))
				for l in 5:
					draw_line(b.position + Vector2(18, 48 + l * 18), b.position + Vector2(b.size.x - 40 - (l * 13) % 30, 48 + l * 18), Color(1, 1, 1, 0.5), 1.5)
			draw_rect(Rect2(s.x * 0.3, floor_y - 110, s.x * 0.6, 110), Color("#8A5E3C"))
			draw_rect(Rect2(s.x * 0.29, floor_y - 118, s.x * 0.62, 10), Color("#C9A57C"))
			draw_rect(Rect2(s.x * 0.36, floor_y - 190, 110, 72), Color("#B9BCC0"))
			draw_rect(Rect2(s.x * 0.36 + 8, floor_y - 182, 94, 30), Color("#8E9196"))
			for i in 5:
				var x := s.x * (0.08 + i * 0.2)
				draw_line(Vector2(x, 0), Vector2(x, s.y * 0.06), Color(0, 0, 0, 0.4), 1.0)
				draw_circle(Vector2(x, s.y * 0.06 + 10), 12.0, Color("#4E7F52"))
				draw_circle(Vector2(x - 10, s.y * 0.06 + 20), 9.0, Color("#6E9A5A"))
			_quad(Rect2(0, floor_y, s.x, s.y - floor_y), Color("#B08A64"), Color("#7A5A40"))
			for i in 12:
				draw_line(Vector2(i * s.x / 12.0, floor_y), Vector2(i * s.x / 12.0 - 60, s.y), Color(0, 0, 0, 0.08), 2.0)
		"thrift":
			_quad(Rect2(0, 0, s.x, floor_y), Color("#EFE6D8"), Color("#E0D2BE"))
			draw_string(UI.serif(500, true), Vector2(s.x * 0.3, s.y * 0.3), "second hand, first love", HORIZONTAL_ALIGNMENT_CENTER, s.x * 0.45, 30, Color("#E05A7A"))
			_glow(Vector2(s.x * 0.52, s.y * 0.28), 200.0, Color(1.0, 0.4, 0.6, 0.12))
			for r in 3:
				var rx := s.x * (0.3 + r * 0.22)
				var ry := s.y * 0.36
				draw_line(Vector2(rx - 110, ry), Vector2(rx + 110, ry), Color("#6B6B6B"), 4.0)
				draw_line(Vector2(rx - 100, ry), Vector2(rx - 110, floor_y + 30), Color("#6B6B6B"), 3.0)
				draw_line(Vector2(rx + 100, ry), Vector2(rx + 110, floor_y + 30), Color("#6B6B6B"), 3.0)
				for k in 10:
					var gx := rx - 100 + k * 21.0
					var gc: Color = Avatar.CLOTH[rng.randi() % Avatar.CLOTH.size()]
					draw_colored_polygon(PackedVector2Array([Vector2(gx, ry + 4), Vector2(gx + 18, ry + 4), Vector2(gx + 20, ry + 110 + (k % 3) * 20), Vector2(gx - 2, ry + 110 + (k % 3) * 20)]), gc)
			draw_rect(Rect2(s.x * 0.06, s.y * 0.14, s.x * 0.1, s.y * 0.5), Color(0.8, 0.88, 0.92, 0.5))
			draw_rect(Rect2(s.x * 0.06, s.y * 0.14, s.x * 0.1, s.y * 0.5), Color("#B88A5A"), false, 6.0)
			_quad(Rect2(0, floor_y, s.x, s.y - floor_y), Color("#9A7A5A"), Color("#6A5240"))
		"gallery":
			_quad(Rect2(0, 0, s.x, floor_y), Color("#F4F2EE"), Color("#E8E4DE"))
			var pieces := [Rect2(0.06, 0.3, 0.15, 0.24), Rect2(0.3, 0.26, 0.2, 0.3), Rect2(0.58, 0.32, 0.12, 0.18), Rect2(0.78, 0.26, 0.14, 0.28)]
			for i in pieces.size():
				var r: Rect2 = pieces[i]
				var pr := Rect2(s.x * r.position.x, s.y * r.position.y, s.x * r.size.x, s.y * r.size.y)
				_glow(pr.get_center() - Vector2(0, pr.size.y * 0.5), pr.size.x, Color(1.0, 0.95, 0.85, 0.25), 6)
				draw_rect(pr, [Color("#E46C4C"), Color("#1F2D4A"), Color("#F2C14E"), Color("#5E8C61")][i])
				draw_circle(pr.get_center() + Vector2(pr.size.x * 0.15, -pr.size.y * 0.1), pr.size.x * 0.22, [Color("#F2C14E"), Color("#E5A2B5"), Color("#1F2D4A"), Color("#F3EEE6")][i])
				draw_line(pr.position + Vector2(0, pr.size.y * 0.7), pr.end - Vector2(0, pr.size.y * 0.1), Color(1, 1, 1, 0.6), 3.0)
			_quad(Rect2(0, floor_y, s.x, s.y - floor_y), Color("#D9D3CB"), Color("#BDB5AA"))
			draw_rect(Rect2(s.x * 0.44, floor_y + 20, s.x * 0.16, 16), Color("#3A3330"))
		"bookstore":
			_quad(Rect2(0, 0, s.x, floor_y), Color("#3B2A20"), Color("#2A1D16"))
			for sh in 5:
				var x := s.x * (0.04 + sh * 0.2)
				draw_rect(Rect2(x, s.y * 0.06, s.x * 0.18, floor_y - s.y * 0.06), Color("#5A3E2C"))
				for row in 5:
					var y := s.y * 0.08 + row * (floor_y - s.y * 0.1) / 5.0
					var bx := x + 8
					while bx < x + s.x * 0.18 - 12:
						var bw := rng.randf_range(7, 14)
						var bh := rng.randf_range(50, 74)
						draw_rect(Rect2(bx, y + 78 - bh, bw, bh), [Color("#B8452E"), Color("#2F4C7A"), Color("#D9B45A"), Color("#5E8C61"), Color("#E9E1D0"), Color("#7A5C99")][rng.randi() % 6])
						bx += bw + 2
					draw_rect(Rect2(x, y + 78, s.x * 0.18, 6), Color("#3A2618"))
			_glow(Vector2(s.x * 0.5, s.y * 0.3), s.x * 0.4, Color(1.0, 0.75, 0.45, 0.12))
			_quad(Rect2(0, floor_y, s.x, s.y - floor_y), Color("#4A3020"), Color("#21150E"))
		"records":
			_quad(Rect2(0, 0, s.x, floor_y), Color("#1F2A2E"), Color("#16201F"))
			for row in 3:
				for col in 9:
					var r := Rect2(s.x * (0.08 + col * 0.095), s.y * (0.1 + row * 0.17), s.x * 0.08, s.x * 0.08)
					var c: Color = [Color("#E46C4C"), Color("#2F4C7A"), Color("#F2C14E"), Color("#5E8C61"), Color("#E5A2B5"), Color("#F3EEE6"), Color("#7A5C99")][rng.randi() % 7]
					draw_rect(r, c)
					draw_circle(r.get_center(), r.size.x * 0.28, c.darkened(0.4))
					draw_circle(r.get_center(), r.size.x * 0.05, c.lightened(0.3))
			var turn := Vector2(s.x * 0.86, floor_y - 40)
			draw_circle(turn, 40.0, Color("#0E0E0E"))
			draw_set_transform(turn, _t * 3.5, Vector2.ONE)
			draw_line(Vector2(-30, 0), Vector2(30, 0), Color(1, 1, 1, 0.15), 1.0)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			_quad(Rect2(0, floor_y, s.x, s.y - floor_y), Color("#2E2A26"), Color("#141210"))
		"arcade":
			_quad(Rect2(0, 0, s.x, floor_y), Color("#140F24"), Color("#1E1636"))
			var cols := [Color("#5FD4FF"), Color("#FF6FB1"), Color("#B57BFF"), Color("#7CF2A2")]
			for i in 7:
				var x := s.x * (0.05 + i * 0.135)
				var c: Color = cols[i % 4]
				draw_rect(Rect2(x, floor_y - 260, 100, 260), Color("#0B0816"))
				draw_rect(Rect2(x + 10, floor_y - 240, 80, 60), Color(c, 0.85))
				_glow(Vector2(x + 50, floor_y - 210), 110.0, Color(c, 0.3), 6)
				draw_rect(Rect2(x, floor_y - 280, 100, 22), Color(c, 0.9))
				for k in 4:
					draw_rect(Rect2(x + 12 + k * 18, floor_y - 236 + fmod(_t * 40.0 + k * 13.0 + i * 7.0, 50.0), 8, 8), Color.WHITE)
			_quad(Rect2(0, floor_y, s.x, s.y - floor_y), Color("#22184A"), Color("#0E0A20"))
			for i in 30:
				draw_circle(Vector2(rng.randf() * s.x, floor_y + rng.randf() * (s.y - floor_y)), 3.0, Color(cols[i % 4], 0.3))
		"studio":
			_quad(Rect2(0, 0, s.x, floor_y), Color("#F2EDE4"), Color("#E6DDCF"))
			var win := Rect2(s.x * 0.08, s.y * 0.08, s.x * 0.84, s.y * 0.42)
			_quad(win, Color("#BFE0EE"), Color("#E9F2E2"))
			for i in 9:
				var x := win.position.x + rng.randf() * win.size.x
				draw_circle(Vector2(x, win.end.y - rng.randf_range(10, 60)), rng.randf_range(30, 60), Color("#7FAF7A", 0.6))
			for i in 5:
				draw_line(Vector2(win.position.x + i * win.size.x / 4.0, win.position.y), Vector2(win.position.x + i * win.size.x / 4.0, win.end.y), Color("#FFFFFF"), 6.0)
			draw_colored_polygon(PackedVector2Array([win.position + Vector2(0, win.size.y), win.end, Vector2(win.end.x + 100, s.y), Vector2(win.position.x + 200, s.y)]), Color(1, 1, 0.9, 0.12))
			_quad(Rect2(0, floor_y, s.x, s.y - floor_y), Color("#D9B88E"), Color("#B8946A"))
			for i in 4:
				var c := Vector2(s.x * (0.3 + i * 0.16), floor_y + 60)
				draw_set_transform(c, 0.0, Vector2(1.0, 0.25))
				draw_rect(Rect2(-70, -60, 140, 120), [Color("#8FB3A0"), Color("#E5A2B5"), Color("#A9C8EC"), Color("#F2C14E")][i])
				draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	_draw_staff(s, floor_y)
	_draw_props(s)

	# Friends who are here too, standing a little further back (seated ones are drawn at their table).
	var fr := _friends()
	var qp := Profile.real_quest_partner(_place.get("name", ""))
	for i in fr.size():
		if _is_seated(fr[i]):
			continue
		var f := _friend_feet(i)
		var resting := Net.is_resting(fr[i])
		Avatar.draw(self, Net.person_for(fr[i]).cfg, f, _scale() * 0.9, _t + i, {"mono": Color(0.62, 0.6, 0.66, 0.55)} if resting else {})
		_friend_tag(fr[i], f + Vector2(0, -s.y * 0.36 - 14), fr[i] == qp)

	# You, just inside the door (unless you've sat down).
	var sc := _scale()
	if _seat < 0:
		Avatar.draw(self, Profile.data.avatar, Vector2(s.x * 0.13, s.y * 0.88), sc, _t)
		UI.draw_tag(self, Vector2(s.x * 0.13, s.y * 0.88 - s.y * 0.4 - 14), "You", UI.CREAM, UI.INK, Profile.data.get("orientation", "") if Profile.data.get("show_flag", false) else "", 14)
	var order := [4, 5, 0, 1, 2, 3].filter(func(i) -> bool: return i < _people.size())
	for i in order:
		var p: Dictionary = _people[i]
		var f := _feet(i)
		var psc := sc * (0.86 if i >= 4 else 1.0)
		if People.kindred(p):
			People.draw_spotlight(self, f, s.y * 0.11 * (0.86 if i >= 4 else 1.0), _t + i)
		Avatar.draw(self, p.cfg, f, psc, _t + i * 1.7)
		var label_y := f.y - s.y * 0.42 * (0.86 if i >= 4 else 1.0) - 16
		if _bubble.who == i and _t < _bubble.until:
			var bw := UI.font(500).get_string_size(_bubble.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x + 28
			var br := Rect2(f.x - bw / 2.0, label_y - 52, bw, 32)
			draw_style_box(UI.box(Color(1, 1, 1, 0.92), 14), br)
			draw_colored_polygon(PackedVector2Array([Vector2(f.x - 6, br.end.y), Vector2(f.x + 6, br.end.y), Vector2(f.x, br.end.y + 8)]), Color(1, 1, 1, 0.92))
			draw_string(UI.font(500), br.position + Vector2(0, 21), _bubble.text, HORIZONTAL_ALIGNMENT_CENTER, bw, 14, UI.INK)
		var a := 1.0 if i == _hover else 0.0
		if not _partner.is_empty() and p.id == _partner.id:
			var ql := "★  %s  ·  your quest partner" % p.name
			var qw := UI.font(500).get_string_size(ql, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x + 26
			draw_style_box(UI.box(UI.GOLD, 12), Rect2(f.x - qw / 2.0, label_y - 22, qw, 28))
			draw_string(UI.font(500), Vector2(f.x - qw / 2.0, label_y - 3), ql, HORIZONTAL_ALIGNMENT_CENTER, qw, 14, UI.INK)
		elif Profile.data.matches.has(p.id):
			draw_string(UI.font(600), Vector2(f.x - 80, label_y), "♥  " + p.name, HORIZONTAL_ALIGNMENT_CENTER, 160, 14, UI.ROSE)
		elif a > 0.0:
			UI.draw_tag(self, Vector2(f.x, label_y + 8), People.tag(p), UI.CREAM, UI.INK, p.get("orientation", ""), 15)

	_draw_tables(s)


func _is_seated(h: String) -> bool:
	var seat := Net.seat_of(h)
	return seat >= 0 and seat / 2 < _tables().size()


func _friend_tag(h: String, at: Vector2, quest: bool) -> void:
	var fp := Net.person_for(h)
	var resting := Net.is_resting(h)
	var label: String = ("★  " if quest else "") + "@" + h + ("  ·  " + fp.pronouns if fp.pronouns != "" else "") + ("  ·  resting" if resting else "")
	UI.draw_tag(self, at, label, UI.GOLD if quest else UI.SAGE, UI.INK, fp.get("orientation", ""), 14)


## Tables with whoever's sitting at them. Bodies go behind the tabletop so they read as seated.
func _draw_tables(s: Vector2) -> void:
	var sc := _scale()
	var qp := Profile.real_quest_partner(_place.get("name", ""))
	var wood := Color("#6B4A33") if _type in ["bar", "records", "bookstore"] else Color("#F2EBDD")
	for t in _tables().size():
		var c := _table_center(t)
		var w := s.x * 0.2
		var top_y := s.y * 0.8
		# Chairs.
		for side in 2:
			var sp := _seat_pos(t * 2 + side)
			var chair := Rect2(sp.x - s.x * 0.035, top_y - s.y * 0.17, s.x * 0.07, s.y * 0.2)
			draw_style_box(UI.box(Color("#3A2A22"), 10), chair)
			draw_style_box(UI.box(Color("#5A4030"), 8), chair.grow(-6))
		# People sitting.
		for side in 2:
			var seat := t * 2 + side
			var who := _seated(seat)
			if who == "":
				continue
			var cfg: Dictionary = Profile.data.avatar if who == "me" else Net.person_for(who).cfg
			Avatar.draw(self, cfg, _seat_pos(seat), sc, _t + seat)
		# The table itself, in front.
		if t == _hover_table:
			_glow(Vector2(c.x, top_y), w * 0.7, Color(UI.GOLD, 0.25), 6)
		draw_set_transform(Vector2(c.x, top_y), 0.0, Vector2(1.0, 0.22))
		draw_circle(Vector2.ZERO, w / 2.0 + 4.0, wood.darkened(0.35))
		draw_circle(Vector2.ZERO, w / 2.0, wood)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		draw_colored_polygon(PackedVector2Array([Vector2(c.x - w / 2.0, top_y), Vector2(c.x + w / 2.0, top_y),
			Vector2(c.x + w / 2.0 + 10, s.y), Vector2(c.x - w / 2.0 - 10, s.y)]), wood.darkened(0.12))
		draw_line(Vector2(c.x - w / 2.0, top_y + 2), Vector2(c.x + w / 2.0, top_y + 2), wood.darkened(0.4), 2.0)
		# Two cups.
		for side in [-1.0, 1.0]:
			var cup := Vector2(c.x + side * w * 0.2, top_y - 4)
			draw_rect(Rect2(cup.x - 9, cup.y - 16, 18, 16), Color("#FFFFFF") if _type != "bar" else Color("#E6B55C", 0.9))
			draw_arc(cup + Vector2(side * 11, -9), 5.0, 0, TAU, 12, Color(1, 1, 1, 0.9), 2.0)
		# Name tags over whoever is sitting.
		for side in 2:
			var seat := t * 2 + side
			var who := _seated(seat)
			var head := _seat_pos(seat) + Vector2(0, -s.y * 0.34 - 8)
			if who == "me":
				UI.draw_tag(self, head, "You", UI.CREAM, UI.INK, Profile.data.get("orientation", "") if Profile.data.get("show_flag", false) else "", 14)
			elif who != "":
				_friend_tag(who, head, who == qp)
		if t == _hover_table:
			var hint := "Stand up" if _seat >= 0 and _seat / 2 == t else ("Sit here" if _seated(t * 2) == "" or _seated(t * 2 + 1) == "" else "Table full")
			UI.draw_tag(self, Vector2(c.x, top_y - s.y * 0.06), hint, UI.GOLD, UI.INK, "", 14)


# --- Life in the room: staff, things to touch ------------------------------------

func _draw_staff(s: Vector2, floor_y: float) -> void:
	var cfg: Dictionary = _staff.get("cfg", {})
	match _type:
		"bar":
			Avatar.draw(self, cfg, Vector2(s.x * 0.62 + sin(_t * 0.4) * 60.0, floor_y - 4), s.y * 0.34 / 300.0, _t)
			draw_rect(Rect2(s.x * 0.28, floor_y - 120, s.x * 0.66, 120), Color("#3A1F17"))
			draw_rect(Rect2(s.x * 0.27, floor_y - 128, s.x * 0.68, 12), Color("#7A4A30"))
		"cafe":
			Avatar.draw(self, cfg, Vector2(s.x * 0.52 + sin(_t * 0.5) * 50.0, floor_y - 4), s.y * 0.34 / 300.0, _t)
			draw_rect(Rect2(s.x * 0.3, floor_y - 110, s.x * 0.6, 110), Color("#8A5E3C"))
			draw_rect(Rect2(s.x * 0.29, floor_y - 118, s.x * 0.62, 10), Color("#C9A57C"))
			for k in 3:
				var x := s.x * 0.36 + 30 + k * 26.0
				var y := floor_y - 196 - fmod(_t * 20.0 + k * 9.0, 40.0)
				draw_circle(Vector2(x + sin(_t * 2.0 + k) * 4.0, y), 6.0, Color(1, 1, 1, 0.12))
		"club":
			Avatar.draw(self, cfg, Vector2(s.x * 0.55, floor_y - 10 - absf(sin(_t * 4.0)) * 8.0), s.y * 0.34 / 300.0, _t)
			draw_rect(Rect2(s.x * 0.45, floor_y - 150, s.x * 0.2, 150), Color("#0E0A10"))
			draw_rect(Rect2(s.x * 0.47, floor_y - 160, s.x * 0.16, 12), Color("#2A2030"))
			for k in 6:
				draw_rect(Rect2(s.x * 0.48 + k * 22.0, floor_y - 120, 14, 6), Color.from_hsv(fmod(_t * 0.3 + k * 0.15, 1.0), 0.6, 1.0))


func _prop_pos(prop: Array) -> Vector2:
	return Vector2(size.x * prop[1], size.y * prop[2])


func _prop_at(pos: Vector2) -> int:
	var props: Array = PROPS.get(_type, [])
	for i in props.size():
		if pos.distance_to(_prop_pos(props[i])) < 46.0:
			return i
	return -1


func _draw_props(_s: Vector2) -> void:
	var props: Array = PROPS.get(_type, [])
	for i in props.size():
		var p := _prop_pos(props[i])
		var pulse := 0.5 + 0.5 * sin(_t * 2.5 + i)
		_glow(p, 46.0, Color(1.0, 0.9, 0.6, 0.25 + 0.2 * pulse), 6)
		draw_circle(p, 16.0, Color(UI.CREAM, 0.95))
		# A four-pointed sparkle, drawn (web builds have no font fallback for ✦).
		var spark := PackedVector2Array()
		for k in 8:
			var r := 9.0 if k % 2 == 0 else 2.6
			var ang := -PI / 2.0 + k * PI / 4.0
			spark.append(p + Vector2(cos(ang), sin(ang)) * r)
		draw_colored_polygon(spark, UI.INK)
		var label: String = props[i][0]
		var lw := UI.font(500).get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x + 24
		var a := 1.0 if i == _hover_prop else 0.75
		draw_style_box(UI.box(Color(0.07, 0.05, 0.1, 0.8 * a), 12), Rect2(p + Vector2(-lw / 2.0, 22), Vector2(lw, 26)))
		draw_string(UI.font(500), p + Vector2(-lw / 2.0, 40), label, HORIZONTAL_ALIGNMENT_CENTER, lw, 14, Color(UI.CREAM, a))


func _use_prop(prop: Array) -> void:
	var app := get_parent()
	match prop[3]:
		"tune":
			var r: Array = Activities.RECORDS[randi() % Activities.RECORDS.size()]
			_player.stream = Synth.melody(r[4], r[2], r[3])
			_player.play()
			app.toast("Now playing: %s" % r[0])
		"text":
			_popover_card(prop[4][0], prop[4][1], [])
		"random":
			var list: Array = prop[4][1]
			_popover_card(prop[4][0], list[randi() % list.size()], [["Another", func() -> void: _use_prop(prop)]])
		"choose":
			var opts := []
			for o in prop[4][1]:
				opts.append([o, func() -> void:
					_close_popover()
					app.toast(prop[4][2] % o.to_lower())])
			_popover_card(prop[4][0], "", opts)
		"activity":
			_start_activity()
		"claw":
			var prizes := ["a tiny plush whale", "a keychain shaped like a dumpling", "absolutely nothing (the claw is weak)", "a glow-in-the-dark frog", "absolutely nothing, again"]
			_popover_card("Claw machine", "The claw wobbles... and you win %s." % prizes[randi() % prizes.size()], [["Try again", func() -> void: _use_prop(prop)]])
		"guestbook":
			var names := []
			for p in _people.slice(0, 3):
				names.append("%s: \"%s\"" % [p.name, ["Loved it.", "Came back twice.", "The blue one!", "Moving."][randi() % 4]])
			if names.is_empty():
				names.append("No one has signed yet. Be the first.")
			_popover_card("Guestbook", "\n".join(names), [["Sign it", func() -> void:
				_close_popover()
				app.toast("You signed the guestbook as @%s." % Profile.data.get("handle", Profile.data.name))]])
		"photobooth":
			_photobooth()


func _close_popover() -> void:
	if _popover and is_instance_valid(_popover):
		_popover.queue_free()


func _popover_card(title: String, body: String, actions: Array) -> void:
	_close_popover()
	var card := PanelContainer.new()
	card.theme_type_variation = "Card"
	card.anchor_top = 1.0
	card.anchor_bottom = 1.0
	card.offset_left = 36
	card.offset_right = 456
	card.offset_top = -36
	card.offset_bottom = -36
	card.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(card)
	_popover = card
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	card.add_child(v)
	var head := HBoxContainer.new()
	v.add_child(head)
	var t := UI.title(title, 26)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	var x := UI.button("×", "TextButton")
	x.pressed.connect(_close_popover)
	head.add_child(x)
	if body != "":
		v.add_child(UI.label(body, 16, UI.CREAM))
	if not actions.is_empty():
		var flow := HFlowContainer.new()
		flow.add_theme_constant_override("h_separation", 8)
		flow.add_theme_constant_override("v_separation", 8)
		v.add_child(flow)
		for a in actions:
			var b := UI.button(a[0], "Chip")
			b.toggle_mode = false
			b.pressed.connect(a[1])
			flow.add_child(b)


func _photobooth() -> void:
	_close_popover()
	var card := PanelContainer.new()
	card.theme_type_variation = "Card"
	card.anchor_top = 1.0
	card.anchor_bottom = 1.0
	card.offset_left = 36
	card.offset_right = 300
	card.offset_top = -36
	card.offset_bottom = -36
	card.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(card)
	_popover = card
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	card.add_child(v)
	v.add_child(UI.eyebrow("Photo booth  ·  4 shots", UI.GOLD))
	var strip := Control.new()
	strip.custom_minimum_size = Vector2(220, 4 * 110)
	strip.draw.connect(func() -> void:
		var faces := [[0, 1], [2, 0], [1, 2], [0, 3]]
		for k in 4:
			var r := Rect2(0, k * 110, 220, 104)
			strip.draw_rect(r, Color("#F4EDE2"))
			var cfg: Dictionary = Profile.data.avatar.duplicate()
			cfg.mouth = faces[k][0]
			cfg.eyes = faces[k][1]
			Avatar.draw_portrait(strip, cfg, r.get_center(), 44.0, Color(0, 0, 0, 0)))
	v.add_child(strip)
	var done := UI.button("Keep the strip", "Chip")
	done.toggle_mode = false
	done.pressed.connect(func() -> void:
		_close_popover()
		get_parent().toast("Photo strip saved to your pocket. You look great in all four."))
	v.add_child(done)
