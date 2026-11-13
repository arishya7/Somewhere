extends Control
## Messages: everyone you've matched with, and the conversation that follows.
## Replies are simulated in each person's voice; quests are the next chapter.

const UI = preload("res://scripts/ui.gd")
const People = preload("res://scripts/people.gd")
const Portrait = preload("res://scripts/portrait.gd")
const Background = preload("res://scripts/background.gd")
const ProfileView = preload("res://scripts/ui/profile_view.gd")
const Quests = preload("res://scripts/quests.gd")
## Chat-first games for getting to know someone before (or instead of) playing anything.
const ICEBREAKERS := [
	"This or that: sunrise run or midnight supper?", "This or that: beach day or museum day?",
	"This or that: hawker centre or fancy brunch?", "This or that: karaoke or board games?",
	"This or that: plan everything or wing it?", "This or that: texting or voice notes?",
	"Would you rather: always know the best food spot, or always find a seat on the MRT?",
	"Would you rather: a week in Tokyo or a week somewhere with no wifi?",
	"Would you rather: be able to talk to animals or speak every language?",
	"Never have I ever: cried at an ad.", "Never have I ever: gone to a concert alone.",
	"Never have I ever: pretended to know a song at karaoke.",
	"Two truths and a lie, your turn first:", "Quick one: what's the best thing that happened to you this week?",
	"Quick one: what's a small thing you're looking forward to?",
]

var params := {}
var _current := ""
var _list: VBoxContainer
var _thread: VBoxContainer
var _scroll: ScrollContainer
var _header: HBoxContainer
var _input: LineEdit
var _typing: Control
var _empty: Control
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_rng.randomize()
	add_child(Background.new())
	var root := HBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 0)
	add_child(root)

	# Sidebar.
	var side := PanelContainer.new()
	side.custom_minimum_size.x = 340
	side.add_theme_stylebox_override("panel", UI.box(Color(0.06, 0.04, 0.09, 0.7), 0, Color(0, 0, 0, 0), 0, 24, 28))
	root.add_child(side)
	var sv := VBoxContainer.new()
	sv.add_theme_constant_override("separation", 12)
	side.add_child(sv)
	var back := UI.button("‹  Back", "TextButton")
	back.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	back.pressed.connect(_back)
	sv.add_child(back)
	sv.add_child(UI.title("Messages", 34))
	var strikes := int(Profile.data.get("strikes", 0))
	sv.add_child(UI.label("Strikes: %d of %d" % [strikes, Profile.STRIKES_TO_BAN], 12, UI.ROSE if strikes > 0 else UI.FAINT))
	sv.add_child(UI.gap(4))
	var list_scroll := ScrollContainer.new()
	list_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sv.add_child(list_scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 4)
	list_scroll.add_child(_list)

	# Conversation.
	var main := MarginContainer.new()
	main.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side_name in ["left", "right"]:
		main.add_theme_constant_override("margin_" + side_name, 48)
	main.add_theme_constant_override("margin_top", 28)
	main.add_theme_constant_override("margin_bottom", 28)
	root.add_child(main)
	var mv := VBoxContainer.new()
	mv.add_theme_constant_override("separation", 14)
	main.add_child(mv)
	_header = HBoxContainer.new()
	_header.add_theme_constant_override("separation", 14)
	mv.add_child(_header)
	var rule := ColorRect.new()
	rule.color = UI.HAIRLINE
	rule.custom_minimum_size.y = 1
	mv.add_child(rule)
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	mv.add_child(_scroll)
	_thread = VBoxContainer.new()
	_thread.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_thread.add_theme_constant_override("separation", 8)
	_scroll.add_child(_thread)
	var compose := HBoxContainer.new()
	compose.add_theme_constant_override("separation", 10)
	mv.add_child(compose)
	_input = LineEdit.new()
	_input.placeholder_text = "Say something kind, or curious"
	_input.max_length = 1000
	_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_input.add_theme_font_size_override("font_size", 17)
	_input.text_submitted.connect(func(_t: String) -> void: _send())
	var ice := UI.button("Icebreaker")
	ice.custom_minimum_size = Vector2(0, 52)
	ice.tooltip_text = "Get to know each other with a quick question: this or that, would you rather, never have I ever."
	ice.pressed.connect(func() -> void:
		_input.text = ICEBREAKERS[_rng.randi() % ICEBREAKERS.size()]
		_input.grab_focus()
		_input.caret_column = _input.text.length())
	compose.add_child(ice)
	compose.add_child(_input)
	var send := UI.button("Send", "PrimaryButton")
	send.custom_minimum_size = Vector2(110, 52)
	send.pressed.connect(_send)
	compose.add_child(send)

	_empty = VBoxContainer.new()
	_empty.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_empty.offset_left = 340
	_empty.mouse_filter = Control.MOUSE_FILTER_IGNORE
	(_empty as VBoxContainer).alignment = BoxContainer.ALIGNMENT_CENTER
	var et := UI.title("No strings yet.", 36)
	et.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_empty.add_child(et)
	var es := UI.label("Head into a bar for trivia, or tap someone who catches your eye.", 16, UI.MUTED)
	es.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_empty.add_child(es)
	add_child(_empty)

	var ids: Array = Profile.data.matches.keys()
	ids.sort_custom(func(a, b) -> bool: return float(Profile.data.matches[a].at) > float(Profile.data.matches[b].at))
	_current = params.get("id", ids[0] if not ids.is_empty() else "")
	main.visible = _current != ""
	_empty.visible = _current == ""
	_refresh_list()
	if _current != "":
		_open(_current)
	var on_chat := func(id: String, _text: String) -> void:
		if id == _current:
			Profile.data.matches[id].unread = 0
			_render_thread()
		_refresh_list()
	Net.chat_received.connect(on_chat)
	tree_exiting.connect(func() -> void: Net.chat_received.disconnect(on_chat))
	var on_quests := func() -> void:
		if _current != "" and is_inside_tree():
			_render_thread()
			_refresh_list()
	Profile.quests_changed.connect(on_quests)
	tree_exiting.connect(func() -> void: Profile.quests_changed.disconnect(on_quests))
	var on_closed := func(pid: String) -> void:
		if pid == _current:
			_open(pid)
	Profile.closed_changed.connect(on_closed)
	tree_exiting.connect(func() -> void: Profile.closed_changed.disconnect(on_closed))


func _back() -> void:
	var b: Dictionary = params.get("back", {"screen": "map"})
	var p := b.duplicate()
	var screen: String = p.get("screen", "map")
	p.erase("screen")
	get_parent().go(screen, p)


func _refresh_list() -> void:
	for c in _list.get_children():
		c.queue_free()
	var ids: Array = Profile.data.matches.keys()
	ids.sort_custom(func(a, b) -> bool: return float(Profile.data.matches[a].at) > float(Profile.data.matches[b].at))
	for id in ids:
		var m: Dictionary = Profile.data.matches[id]
		var row := Button.new()
		row.toggle_mode = false
		row.custom_minimum_size.y = 72
		row.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var on: bool = id == _current
		var sb := UI.box(Color(1, 1, 1, 0.08 if on else 0.0), 14, Color(0, 0, 0, 0), 0, 10, 8)
		for st in ["normal", "pressed", "focus"]:
			row.add_theme_stylebox_override(st, sb)
		row.add_theme_stylebox_override("hover", UI.box(Color(1, 1, 1, 0.06), 14, Color(0, 0, 0, 0), 0, 10, 8))
		row.pressed.connect(_open.bind(id))
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 12)
		h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 10)
		h.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(h)
		h.add_child(Portrait.make(m.person.cfg, 50, UI.ROSE if int(m.unread) > 0 else Color(1, 1, 1, 0.3)))
		var tv := VBoxContainer.new()
		tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tv.alignment = BoxContainer.ALIGNMENT_CENTER
		tv.add_theme_constant_override("separation", 0)
		tv.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(tv)
		var name_l := UI.nowrap(UI.label(m.person.name, 16, UI.CREAM, 600))
		name_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tv.add_child(name_l)
		var last: String = m.messages[-1].text if not m.messages.is_empty() else "Say hi"
		var last_l := UI.nowrap(UI.label(last, 13, UI.MUTED))
		last_l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		last_l.custom_minimum_size.x = 200
		last_l.clip_text = true
		last_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tv.add_child(last_l)
		_list.add_child(row)
	var active: Array = Profile.data.get("quests", []).filter(func(q) -> bool: return q.status == "active")
	if not active.is_empty():
		_list.add_child(UI.gap(10))
		_list.add_child(UI.eyebrow("Quests in progress", UI.GOLD))
		for q in active:
			var who: String = Profile.data.matches.get(q.with, {}).get("person", {}).get("name", "")
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 8)
			var col := VBoxContainer.new()
			col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			col.add_theme_constant_override("separation", 0)
			col.add_child(UI.label(q.title, 14, UI.CREAM, 500))
			col.add_child(UI.label("with %s  ·  %d of %d  ·  %s" % [who, Quests.progress(q), q.steps.size(), Quests.venue_of(q)[0]], 12, UI.MUTED))
			row.add_child(col)
			var go_b := UI.button("Go", "Chip")
			go_b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			go_b.pressed.connect(_go_quest.bind(q))
			row.add_child(go_b)
			_list.add_child(row)
	var waiting: Dictionary = Profile.data.get("following", {})
	var pending := waiting.keys().filter(func(k) -> bool: return not Profile.data.matches.has(k))
	if not pending.is_empty():
		_list.add_child(UI.gap(10))
		_list.add_child(UI.eyebrow("Strings you've followed"))
		_list.add_child(UI.label("You'll match if they follow back. Doing something together (trivia, a shared table, a game) makes it more likely.", 12, UI.FAINT))
		for k in pending:
			var f: Dictionary = waiting[k]
			var h := HBoxContainer.new()
			h.add_theme_constant_override("separation", 12)
			h.add_child(Portrait.make(f.person.cfg, 40, Color(1, 1, 1, 0.25)))
			var tv := VBoxContainer.new()
			tv.add_theme_constant_override("separation", 0)
			tv.add_child(UI.nowrap(UI.label(f.person.name, 15, UI.MUTED, 500)))
			tv.add_child(UI.nowrap(UI.label("Waiting  ·  %s" % f.where, 12, UI.FAINT)))
			h.add_child(tv)
			_list.add_child(h)


func _open(id: String) -> void:
	_current = id
	var m: Dictionary = Profile.data.matches[id]
	m.unread = 0
	Profile.save()
	for c in _header.get_children():
		c.queue_free()
	var person: Dictionary = m.person
	var face := Portrait.make(person.cfg, 54, UI.RED_STRING)
	_header.add_child(face)
	var hv := VBoxContainer.new()
	hv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hv.alignment = BoxContainer.ALIGNMENT_CENTER
	hv.add_theme_constant_override("separation", 0)
	_header.add_child(hv)
	var name_l := UI.title(person.name, 28)
	name_l.autowrap_mode = TextServer.AUTOWRAP_OFF
	hv.add_child(name_l)
	hv.add_child(UI.nowrap(UI.label("Matched at %s" % m.where if m.where != "" else "Matched on Somewhere", 13, UI.MUTED)))
	var view := UI.button("View profile")
	view.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	view.pressed.connect(func() -> void: ProfileView.open(self, person, m.where))
	_header.add_child(view)
	var quest := UI.button("Plan a quest", "PrimaryButton")
	quest.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	quest.pressed.connect(_quest_picker.bind(person))
	_header.add_child(quest)
	if not m.get("closed", false) and not Profile.is_closing(id):
		var close := UI.button("Close kindly", "TextButton")
		close.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		close.tooltip_text = "End this conversation gracefully. It never counts as ghosting."
		close.pressed.connect(_confirm_close.bind(person))
		_header.add_child(close)
	var call := UI.button("Call")
	call.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if person.get("real", false):
		call.pressed.connect(func() -> void: Net.start_call(person.handle))
	else:
		call.disabled = true
		call.tooltip_text = "Voice calls work with real players. Invite friends from Play with friends."
	_header.add_child(call)
	_call_bar(person)
	_render_thread()
	_refresh_list()
	_input.grab_focus.call_deferred()


func _render_thread() -> void:
	for c in _thread.get_children():
		c.queue_free()
	var m: Dictionary = Profile.data.matches[_current]
	if int(m.get("reminders", 0)) > 0 and not m.get("closed", false):
		var warn := UI.label("Reminder %d of %d: %s is waiting on a reply. Reply, or close the conversation kindly." % [m.reminders, Profile.REMINDERS_PER_STRIKE, m.person.name], 14, UI.ROSE)
		warn.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_thread.add_child(warn)
	var intro := UI.label("The string pulled taut at %s. Fate is patient, so take your time." % (m.where if m.where != "" else "Somewhere"), 13, UI.FAINT)
	intro.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_thread.add_child(intro)
	_thread.add_child(UI.gap(6))
	for msg in m.messages:
		if msg.has("quest"):
			_quest_card(Profile.quest(str(msg.quest)), bool(msg.me))
		else:
			_bubble(msg.text, bool(msg.me))
	var last: Dictionary = m.messages[-1] if not m.messages.is_empty() else {}
	if not last.is_empty() and not bool(last.me) and not m.get("closed", false):
		var waited := Time.get_unix_time_from_system() - maxf(float(last.at), float(m.get("ghost_from", 0.0)))
		var n := int(m.get("reminders", 0))
		var next := Profile.DAY * (3 + n) - waited
		var what := "a reminder" if n < Profile.REMINDERS_PER_STRIKE else "a strike"
		var note := UI.label("%s is waiting on you. Reply within %s to avoid %s  ·  reminders %d of %d  ·  strikes %d of %d" % [
			m.person.name, _duration(maxf(next, 0.0)), what, n, Profile.REMINDERS_PER_STRIKE, int(Profile.data.get("strikes", 0)), Profile.STRIKES_TO_BAN], 12, UI.GOLD)
		note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_thread.add_child(note)
	if m.get("closed", false):
		var closed := UI.label(("%s closed this conversation kindly. Nothing more can be sent either way." % m.person.name) if m.get("closed_by", "me") == "them" else "You closed this conversation kindly. Nothing more can be sent either way.", 13, UI.FAINT)
		closed.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_thread.add_child(closed)
	_input.editable = not m.get("closed", false)
	_scroll_to_end()


func _bubble(text: String, mine: bool) -> void:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END if mine else BoxContainer.ALIGNMENT_BEGIN
	var b := PanelContainer.new()
	var sb := UI.box(UI.CREAM if mine else Color(1, 1, 1, 0.08), 18, Color(0, 0, 0, 0), 0, 16, 11)
	if mine:
		sb.corner_radius_bottom_right = 4
	else:
		sb.corner_radius_bottom_left = 4
	b.add_theme_stylebox_override("panel", sb)
	var l := UI.label(text, 16, UI.INK if mine else UI.CREAM)
	l.custom_minimum_size.x = mini(460, int(UI.font().get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x) + 4)
	b.add_child(l)
	row.add_child(b)
	_thread.add_child(row)


func _scroll_to_end() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	_scroll.scroll_vertical = int(_scroll.get_v_scroll_bar().max_value)


func _send() -> void:
	var text := _input.text.strip_edges()
	if text == "" or _current == "" or Profile.data.matches[_current].get("closed", false):
		return
	_input.text = ""
	Profile.add_message(_current, true, text)
	_bubble(text, true)
	_refresh_list()
	_scroll_to_end()
	var id := _current
	if id.begins_with("net:"):
		Net.send_chat(id.trim_prefix("net:"), text)
		return
	var reply := _reply_to(Profile.data.matches[id].person, text, Profile.data.matches[id].messages.size())
	await get_tree().create_timer(0.6).timeout
	_show_typing(id)
	await get_tree().create_timer(clampf(reply.length() * 0.035, 1.2, 3.2)).timeout
	if is_instance_valid(_typing):
		_typing.queue_free()
	if not is_inside_tree():
		return
	Profile.add_message(id, false, reply)
	if _current == id:
		Profile.data.matches[id].unread = 0
		_bubble(reply, false)
		_scroll_to_end()
	_refresh_list()


func _show_typing(id: String) -> void:
	if _current != id:
		return
	var row := HBoxContainer.new()
	var b := PanelContainer.new()
	b.add_theme_stylebox_override("panel", UI.box(Color(1, 1, 1, 0.06), 18, Color(0, 0, 0, 0), 0, 16, 11))
	var dots := UI.label("•  •  •", 16, UI.MUTED)
	b.add_child(dots)
	row.add_child(b)
	_thread.add_child(row)
	_typing = row
	var tw := dots.create_tween().set_loops()
	tw.tween_property(dots, "modulate:a", 0.3, 0.5)
	tw.tween_property(dots, "modulate:a", 1.0, 0.5)
	_scroll_to_end()


## A small, honest reply engine: reacts to what you said, in their voice.
func _reply_to(p: Dictionary, text: String, count: int) -> String:
	var t := text.to_lower()
	var voice: String = People.TRAITS[p.traits[1]].voice
	var interest: String = p.interests[_rng.randi() % p.interests.size()]
	var fact: String = p.facts[_rng.randi() % p.facts.size()] if not p.facts.is_empty() else "loves a good story"
	if count <= 3 and t.length() < 24 and (t.begins_with("hi") or t.begins_with("hey") or t.begins_with("hello") or "hello" in t):
		return "Hi! Okay, honest question: what made you come out tonight?"
	if t.begins_with("this or that:"):
		var opts := t.trim_prefix("this or that:").replace("?", "").split(" or ")
		if opts.size() == 2:
			var pick: String = opts[_rng.randi() % 2].strip_edges()
			return ["%s, no contest. Okay, your turn, what would you pick?" % pick.capitalize(), "Easy. %s. Is that a dealbreaker?" % pick.capitalize(), "Ooh. %s, but I'd hear the other side out." % pick.capitalize()][_rng.randi() % 3]
	if t.begins_with("would you rather"):
		return ["Okay I thought about this way too long. The first one. Why, what's your answer?", "The second, obviously. Wait, is that the wrong answer?", "Can I say both? No? Fine. The first one."][_rng.randi() % 3]
	if t.begins_with("never have i ever"):
		return ["...I have. Story for another time. You?", "Never! Honestly, a bit proud of that. Have you?", "Guilty. Very guilty. I'll tell you over coffee."][_rng.randi() % 3]
	if t.begins_with("two truths"):
		return "Okay: I've been to 14 countries, I can't swim, and I once met a famous chef by accident. Guess the lie!"
	if t.begins_with("quick one"):
		return "Honestly? %s. You?" % fact.capitalize()
	if "trivia" in t or "quiz" in t or "team" in t:
		return "We were robbed on at least one question and I will not be taking feedback. Rematch soon?"
	if "meet" in t or "drink" in t or "coffee" in t or "date" in t or "dinner" in t or "go out" in t:
		return "I'd like that. Let's make it a little adventure rather than just a coffee. Somewhere new to both of us?"
	if "?" in t:
		var answers := [
			"Ha, good question. Lately it's mostly %s. I %s." % [interest.to_lower(), fact],
			"Honestly? I %s. What about you?" % fact,
			"I'm from %s originally, so the answer is always 'it's complicated'. What's yours?" % p.home,
			"Probably %s. Ask me again when I've had a coffee." % interest.to_lower(),
		]
		return answers[_rng.randi() % answers.size()]
	if "haha" in t or "lol" in t or "😂" in t:
		return "Okay you're funny. That's noted. " + voice
	var general := [
		"I like that. " + voice,
		"Wait, tell me more. Is that a %s thing or a you thing?" % ["Singapore", "big city", "weekend"][_rng.randi() % 3],
		"That's very 'main character in a slow film' of you. I'm into it.",
		"Okay, now I'm curious what your perfect Sunday looks like.",
		"Same, honestly. Also, I %s, in case that's relevant." % fact,
	]
	return general[_rng.randi() % general.size()]


# --- Quests ---------------------------------------------------------------------

func _quest_picker(person: Dictionary) -> void:
	var overlay := Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)
	var scrim := UI.scrim(overlay)
	scrim.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed:
			overlay.queue_free())
	var card := PanelContainer.new()
	card.theme_type_variation = "Card"
	card.anchor_left = 0.5
	card.anchor_right = 0.5
	card.anchor_top = 0.5
	card.anchor_bottom = 0.5
	card.offset_left = -380
	card.offset_right = 380
	card.offset_top = -330
	card.offset_bottom = 330
	overlay.add_child(card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	card.add_child(v)
	v.add_child(UI.eyebrow("For you and %s" % person.name, UI.GOLD))
	v.add_child(UI.title("Plan a quest", 34))
	v.add_child(UI.label("Pick a small adventure. If %s says yes, every step happens as you play: go there, step inside, do the thing." % person.name, 14, UI.MUTED))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	scroll.add_child(grid)
	for q in Quests.CATALOG:
		var b := Button.new()
		b.custom_minimum_size = Vector2(345, 108)
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		b.add_theme_stylebox_override("normal", UI.box(Color(1, 1, 1, 0.05), 14))
		b.add_theme_stylebox_override("hover", UI.box(Color(1, 1, 1, 0.1), 14, Color(UI.CREAM, 0.4), 1))
		b.add_theme_stylebox_override("pressed", UI.box(Color(1, 1, 1, 0.14), 14))
		var col := VBoxContainer.new()
		col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 14)
		col.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_theme_constant_override("separation", 2)
		b.add_child(col)
		for l in [UI.eyebrow(q.place, UI.GOLD), UI.label(q.title, 16, UI.CREAM, 500), UI.label(q.blurb, 13, UI.MUTED)]:
			l.mouse_filter = Control.MOUSE_FILTER_IGNORE
			col.add_child(l)
		b.pressed.connect(func() -> void:
			overlay.queue_free()
			Profile.propose_quest(person, q.id))
		grid.add_child(b)
	var cancel := UI.button("Not now", "TextButton")
	cancel.pressed.connect(overlay.queue_free)
	v.add_child(cancel)


## Close kindly asks first and shows exactly what will be sent, then gives a few seconds to undo.
func _confirm_close(person: Dictionary) -> void:
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
	card.offset_left = -270
	card.offset_right = 270
	card.offset_top = -200
	card.offset_bottom = 200
	overlay.add_child(card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	card.add_child(v)
	v.add_child(UI.eyebrow("Close kindly", UI.ROSE))
	v.add_child(UI.title("End things with %s?" % person.name, 30))
	v.add_child(UI.label("Everyone gets the same gentle message, so nobody takes it personally:", 14, UI.MUTED))
	v.add_child(UI.label("\u201C%s\u201D" % Profile.CLOSE_KINDLY_TEXT, 14, UI.CREAM))
	v.add_child(UI.label("You'll have %d seconds to undo. It never counts as ghosting." % int(Profile.UNDO_SECONDS), 13, UI.FAINT))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	v.add_child(row)
	var yes := UI.button("Close kindly", "PrimaryButton")
	yes.pressed.connect(func() -> void:
		overlay.queue_free()
		Profile.request_close_kindly(person.id)
		_open(person.id))
	row.add_child(yes)
	var no := UI.button("Keep talking")
	no.pressed.connect(overlay.queue_free)
	row.add_child(no)


## Straight to the quest's door, so nobody gets lost on the way.
func _go_quest(q: Dictionary) -> void:
	get_parent().go("district", {"place": q.place, "at": int(Quests.venue_of(q)[1])})


func _quest_card(q: Dictionary, mine: bool) -> void:
	if q.is_empty():
		return
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END if mine else BoxContainer.ALIGNMENT_BEGIN
	var card := PanelContainer.new()
	card.custom_minimum_size.x = 420
	var border: Color = {"proposed": UI.GOLD, "active": UI.SAGE, "done": UI.CREAM, "declined": UI.FAINT}.get(q.status, UI.GOLD)
	card.add_theme_stylebox_override("panel", UI.box(Color(0.12, 0.09, 0.16, 0.95), 18, Color(border, 0.7), 1, 18, 14))
	row.add_child(card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	card.add_child(v)
	var status: String = {"proposed": "Quest proposed", "active": "Quest in progress  ·  %d of %d" % [Quests.progress(q), q.steps.size()], "done": "Quest complete", "declined": "Maybe another time"}.get(q.status, "")
	v.add_child(UI.eyebrow(status, border))
	v.add_child(UI.title(q.title, 22))
	var where: Array = Quests.venue_of(q)
	v.add_child(UI.label(q.blurb + "  ·  " + (where[0] + ", " if where[0] != "" else "") + q.place, 13, UI.MUTED))
	if q.status in ["active", "done"]:
		for st in q.steps:
			v.add_child(UI.label(("✓  " if st.done else "○  ") + st.text, 14, UI.SAGE if st.done else UI.CREAM))
	if q.status == "active":
		var go_b := UI.button("Go there now  ›", "PrimaryButton")
		go_b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		go_b.tooltip_text = "Takes you straight to the door of %s. Your match will meet you there." % where[0]
		go_b.pressed.connect(_go_quest.bind(q))
		v.add_child(go_b)
	if q.status == "proposed" and not mine:
		var actions := HBoxContainer.new()
		actions.add_theme_constant_override("separation", 8)
		v.add_child(actions)
		var yes := UI.button("Accept", "PrimaryButton")
		yes.pressed.connect(func() -> void: Profile.accept_quest(q.qid, true))
		actions.add_child(yes)
		var no := UI.button("Not now")
		no.pressed.connect(func() -> void: Profile.decline_quest(q.qid, true))
		actions.add_child(no)
	elif q.status == "proposed":
		v.add_child(UI.label("Waiting for them to say yes...", 13, UI.FAINT))
	_thread.add_child(row)


var _call_box: PanelContainer


func _call_bar(person: Dictionary) -> void:
	if _call_box and is_instance_valid(_call_box):
		_call_box.queue_free()
	_call_box = PanelContainer.new()
	_call_box.add_theme_stylebox_override("panel", UI.box(Color(UI.SAGE, 0.16), 14, Color(UI.SAGE, 0.6), 1, 16, 10))
	_call_box.visible = false
	_header.get_parent().add_child(_call_box)
	_header.get_parent().move_child(_call_box, _header.get_index() + 1)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	_call_box.add_child(row)
	var label := UI.label("", 15, UI.CREAM, 500)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	var mute := UI.button("Mute")
	mute.pressed.connect(func() -> void:
		Net.muted = not Net.muted
		mute.text = "Unmute" if Net.muted else "Mute")
	row.add_child(mute)
	# Noisy room? Push to talk only sends your voice while you hold the button.
	var ptt := UI.button("Push to talk: off")
	ptt.tooltip_text = "Only send your voice while you hold Talk. Good for noisy places."
	var hold := UI.button("Hold to talk", "PrimaryButton")
	hold.visible = false
	hold.button_down.connect(func() -> void: Net.talking = true)
	hold.button_up.connect(func() -> void: Net.talking = false)
	ptt.pressed.connect(func() -> void:
		Net.push_to_talk = not Net.push_to_talk
		Net.talking = false
		ptt.text = "Push to talk: on" if Net.push_to_talk else "Push to talk: off"
		hold.visible = Net.push_to_talk and Net.call_state == "active")
	row.add_child(ptt)
	row.add_child(hold)
	var end := UI.button("End call", "PrimaryButton")
	end.pressed.connect(func() -> void: Net.end_call())
	row.add_child(end)
	var started := [0.0]
	var update := func(st: String) -> void:
		if not is_instance_valid(_call_box):
			return
		var mine: bool = person.get("handle", "") == Net.call_with
		_call_box.visible = mine and st != "idle"
		mute.visible = st == "active"
		ptt.visible = st == "active"
		hold.visible = st == "active" and Net.push_to_talk
		if st == "active":
			started[0] = Time.get_ticks_msec() / 1000.0
		label.text = {"ringing_out": "Calling %s..." % person.name, "ringing_in": "%s is calling" % person.name, "active": "On a call with %s" % person.name}.get(st, "")
	Net.call_state_changed.connect(update)
	_call_box.tree_exiting.connect(func() -> void: Net.call_state_changed.disconnect(update))
	update.call(Net.call_state)


static func _duration(sec: float) -> String:
	if sec >= 86400.0:
		return "%d day%s" % [ceili(sec / 86400.0), "" if ceili(sec / 86400.0) == 1 else "s"]
	if sec >= 3600.0:
		return "%d hours" % ceili(sec / 3600.0)
	if sec >= 60.0:
		return "%d min" % ceili(sec / 60.0)
	return "%d sec" % ceili(sec)
