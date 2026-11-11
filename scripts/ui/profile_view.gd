extends Control
## Someone's profile, opened by tapping them: photos, who they are, what you learned
## about them tonight, and the choice to match. Consent-first: "Not now" is always there.

signal chat_requested(person_id: String)
signal closed
## Asked to do this place's activity together, before matching.
signal play_requested(person: Dictionary)

const UI = preload("res://scripts/ui.gd")
const People = preload("res://scripts/people.gd")
const PhotoCard = preload("res://scripts/ui/photo_card.gd")
const Portrait = preload("res://scripts/portrait.gd")

const PHOTO_COUNT := 3

var person := {}
var where := ""
var play_text := ""
var _photo: Control
var _dots: HBoxContainer
var _index := 0
var _card: PanelContainer
var _real: TextureRect
var _right: VBoxContainer


## An extra action under the profile (e.g. "Sit with @x"). Closes the profile, then runs cb.
func add_action(text: String, cb: Callable) -> void:
	if _right == null:
		return
	var b := UI.button(text, "PrimaryButton")
	b.custom_minimum_size.y = 48
	b.pressed.connect(func() -> void:
		_close()
		cb.call())
	_right.add_child(b)


## Your own profile, exactly as other people see it.
static func open_self(host: Control) -> Control:
	var me := Profile.public_profile()
	var cfg := {}
	for k in me.avatar:
		cfg[k] = int(me.avatar[k])
	var p := {
		"id": "me", "self": true, "real": true, "handle": me.handle, "name": me.name, "pronouns": me.pronouns,
		"age": int(me.age), "cfg": cfg, "cats": me.cats, "interests": me.interests, "intent": me.intent,
		"prompts": me.prompts, "traits": [], "facts": [], "job": "", "home": "",
		"bio": "This is you. Everyone you meet sees this when they tap your avatar.",
	}
	return open(host, p, "")


static func open(host: Control, p: Dictionary, place: String, play := "") -> Control:
	var v = load("res://scripts/ui/profile_view.gd").new()
	v.person = p
	v.where = place
	v.play_text = play
	host.add_child(v)
	return v


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var scrim := UI.scrim(self)
	scrim.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed:
			_close())
	_card = PanelContainer.new()
	_card.theme_type_variation = "Card"
	_card.add_theme_stylebox_override("panel", _card_style())
	add_child(_card)
	_build_profile()
	_card.modulate.a = 0.0
	var tw := create_tween().set_parallel()
	tw.tween_property(_card, "modulate:a", 1.0, 0.3)


func _card_style() -> StyleBox:
	var sb := UI.box(UI.PANEL, 24, Color(1, 1, 1, 0.07), 1, 22, 22)
	sb.shadow_color = Color(0, 0, 0, 0.4)
	sb.shadow_size = 40
	return sb


func _center(card_size: Vector2) -> void:
	_card.anchor_left = 0.5
	_card.anchor_right = 0.5
	_card.anchor_top = 0.5
	_card.anchor_bottom = 0.5
	_card.offset_left = -card_size.x / 2.0
	_card.offset_right = card_size.x / 2.0
	_card.offset_top = -card_size.y / 2.0
	_card.offset_bottom = card_size.y / 2.0


func _clear() -> void:
	for c in _card.get_children():
		c.queue_free()


func _build_profile() -> void:
	_clear()
	_center(Vector2(940, 620))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 30)
	_card.add_child(row)

	# Photos.
	var photos := VBoxContainer.new()
	photos.add_theme_constant_override("separation", 10)
	row.add_child(photos)
	var mask := Panel.new()
	mask.custom_minimum_size = Vector2(400, 540)
	mask.add_theme_stylebox_override("panel", UI.box(Color.WHITE, 18))
	mask.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	mask.mouse_filter = Control.MOUSE_FILTER_STOP
	photos.add_child(mask)
	_photo = PhotoCard.new()
	_photo.person = person
	_photo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mask.add_child(_photo)
	if person.get("real", false):
		_real = TextureRect.new()
		_real.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_real.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		_real.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		mask.add_child(_real)
		if not person.get("self", false):
			Net.request_photos(person.handle)
			var refresh := func() -> void: _flip(0)
			Net.roster_changed.connect(refresh)
			tree_exiting.connect(func() -> void: Net.roster_changed.disconnect(refresh))
	for spec in [[-1, "‹", Control.PRESET_CENTER_LEFT], [1, "›", Control.PRESET_CENTER_RIGHT]]:
		var b := UI.button(spec[1])
		for st in ["normal", "hover", "pressed"]:
			b.add_theme_stylebox_override(st, UI.box(Color(0, 0, 0, 0.35 if st == "normal" else 0.55), 20, Color(0, 0, 0, 0), 0, 14, 6))
		b.add_theme_font_size_override("font_size", 22)
		b.set_anchors_and_offsets_preset(spec[2], Control.PRESET_MODE_MINSIZE, 12)
		b.pressed.connect(_flip.bind(spec[0]))
		mask.add_child(b)
	_dots = HBoxContainer.new()
	_dots.alignment = BoxContainer.ALIGNMENT_CENTER
	_dots.add_theme_constant_override("separation", 6)
	_dots.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE, 14)
	mask.add_child(_dots)
	_flip(0)

	# Details.
	var right := VBoxContainer.new()
	right.custom_minimum_size = Vector2(440, 0)
	right.add_theme_constant_override("separation", 14)
	row.add_child(right)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right.add_child(scroll)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 8)
	scroll.add_child(info)
	var head_bits := [person.pronouns, person.get("orientation", ""), person.intent].filter(func(x) -> bool: return str(x) != "")
	info.add_child(UI.eyebrow("  ·  ".join(head_bits)))
	if UI.FLAGS.has(person.get("orientation", "")):
		var flag := Control.new()
		flag.custom_minimum_size = Vector2(34, 20)
		var orient: String = person.orientation
		flag.draw.connect(func() -> void: UI.draw_flag(flag, Rect2(Vector2(0, 2), Vector2(30, 18)), orient))
		info.add_child(flag)
	info.add_child(UI.title("%s, %d" % [person.name, int(person.age)] if int(person.age) > 0 else person.name, 40))
	if person.get("self", false):
		info.add_child(UI.label("@%s  ·  this is how others see you" % person.handle, 15, UI.SAGE))
	elif person.get("real", false):
		info.add_child(UI.label("@%s  ·  playing with you right now" % person.handle, 15, UI.SAGE))
	else:
		info.add_child(UI.label("%s  ·  from %s" % [person.job, person.home], 15, UI.MUTED))
	var traits := HBoxContainer.new()
	traits.add_theme_constant_override("separation", 6)
	for t in person.traits:
		traits.add_child(UI.pill(People.trait_label(t), UI.GOLD))
	info.add_child(traits)

	var learned: Array = Profile.data.learned.get(person.id, [])
	if not learned.is_empty():
		info.add_child(UI.gap(10))
		info.add_child(UI.eyebrow("What you noticed tonight", UI.GOLD))
		for f in learned:
			info.add_child(UI.label("·  " + f, 15, UI.CREAM))

	info.add_child(UI.gap(10))
	info.add_child(UI.eyebrow("About"))
	info.add_child(UI.label(person.bio, 15, UI.CREAM))
	for p in person.prompts:
		info.add_child(UI.gap(8))
		info.add_child(UI.eyebrow(p[0]))
		var answer := UI.label(p[1], 21, UI.CREAM)
		answer.add_theme_font_override("font", UI.serif(400, true))
		info.add_child(answer)
	info.add_child(UI.gap(8))
	info.add_child(UI.eyebrow("Into"))
	var chips := HFlowContainer.new()
	chips.add_theme_constant_override("h_separation", 6)
	chips.add_theme_constant_override("v_separation", 6)
	for i in person.interests:
		chips.add_child(UI.pill(i, UI.CREAM))
	info.add_child(chips)
	info.add_child(UI.gap(6))
	if not person.get("real", false):
		info.add_child(UI.label("Simulated person. Real members show the photos they uploaded.", 12, UI.FAINT))

	if person.get("self", false):
		_self_actions(right)
		return
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 10)
	right.add_child(actions)
	var later := UI.button("Not now")
	later.custom_minimum_size = Vector2(140, 52)
	later.pressed.connect(_close)
	actions.add_child(later)
	var matched: bool = Profile.data.matches.has(person.id)
	var following: bool = Profile.data.get("following", {}).has(person.id)
	var label := "Message" if matched else ("String followed  ·  waiting" if following else "Follow the string")
	var match_btn := UI.button(label, "PrimaryButton")
	match_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	match_btn.custom_minimum_size.y = 52
	match_btn.disabled = following and not matched
	var mutual := Profile.wants_to_meet_me(person)
	var friends_only := not matched and not following and not mutual
	if friends_only:
		# They're here to meet someone else, so it can't be a date, but you can still connect as friends.
		match_btn.text = "Follow as a friend"
		match_btn.tooltip_text = "%s is here to meet %s, so this would be a friendship. If you both follow, you can chat, call and do quests together." % [person.name, ", ".join(person.get("show_me", [])).to_lower()]
	match_btn.pressed.connect(func() -> void:
		if matched:
			chat_requested.emit(person.id)
		else:
			_follow())
	actions.add_child(match_btn)
	_right = right
	if play_text != "":
		# Getting to know someone by doing something together, no match needed.
		var play := UI.button(play_text)
		play.custom_minimum_size.y = 48
		play.tooltip_text = "Ask %s to do this together. No match needed." % person.name
		play.pressed.connect(func() -> void:
			var who := person
			_close()
			play_requested.emit(who))
		right.add_child(play)
	if friends_only:
		right.add_child(UI.label("%s is looking to meet %s, so you'd connect as friends." % [person.name, ", ".join(person.get("show_me", [])).to_lower()], 12, UI.GOLD))
	if not matched:
		right.add_child(UI.label("Following is private. You only match if %s follows your string too." % person.name, 12, UI.FAINT))


## On your own profile: no following, just ways to change things.
func _self_actions(right: VBoxContainer) -> void:
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 10)
	right.add_child(actions)
	var done := UI.button("Done")
	done.custom_minimum_size = Vector2(120, 52)
	done.pressed.connect(_close)
	actions.add_child(done)
	var avatar := UI.button("Edit avatar", "PrimaryButton")
	avatar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	avatar.custom_minimum_size.y = 52
	avatar.pressed.connect(func() -> void:
		var app := get_tree().root.get_node_or_null("App")
		_close()
		if app:
			app.go("avatar", {"edit": true}))
	actions.add_child(avatar)
	var edit := UI.button("Edit profile")
	edit.custom_minimum_size = Vector2(150, 52)
	edit.tooltip_text = "Change your photos, interests and prompt."
	edit.pressed.connect(func() -> void:
		var app := get_tree().root.get_node_or_null("App")
		_close()
		if app:
			app.go("onboarding", {"step": 9, "edit": true}))
	actions.add_child(edit)
	right.add_child(UI.label("Your phone number, email and birthday are never shown to anyone.", 12, UI.FAINT))


func _flip(dir: int) -> void:
	_index = posmod(_index + dir, PHOTO_COUNT)
	_photo.kind = _index
	_photo.queue_redraw()
	if _real and is_instance_valid(_real):
		var photos: Array = Profile.photos if person.get("self", false) else Net.players.get(person.handle, {}).get("photos", [])
		_real.texture = photos[_index % photos.size()] if not photos.is_empty() else null
	for c in _dots.get_children():
		c.queue_free()
	for i in PHOTO_COUNT:
		var d := ColorRect.new()
		d.custom_minimum_size = Vector2(28 if i == _index else 14, 3)
		d.color = Color(1, 1, 1, 0.95 if i == _index else 0.45)
		_dots.add_child(d)


func _follow() -> void:
	Profile.follow(person, where)
	_clear()
	_center(Vector2(620, 520))
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 12)
	_card.add_child(v)
	var pair := Control.new()
	pair.custom_minimum_size = Vector2(560, 190)
	pair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(pair)
	var me := Portrait.make(Profile.data.avatar, 150, UI.CREAM)
	var them := Portrait.make(person.cfg, 150, UI.CREAM)
	pair.add_child(me)
	pair.add_child(them)
	me.position = Vector2(60, 20)
	them.position = Vector2(350, 20)
	var string := Control.new()
	string.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	string.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var t0 := Time.get_ticks_msec()
	string.draw.connect(func() -> void:
		var k := clampf((Time.get_ticks_msec() - t0) / 1200.0, 0.0, 1.0)
		var a := Vector2(210, 95)
		var b := Vector2(350, 95)
		var mid := (a + b) / 2.0 + Vector2(0, 60.0 - 30.0 * ease(k, 0.3))
		var pts := PackedVector2Array()
		for i in 21:
			var u := i / 20.0
			pts.append(a.lerp(mid, u).lerp(mid.lerp(b, u), u))
		string.draw_polyline(pts, Color(UI.RED_STRING, 0.25), 9.0, true)
		string.draw_polyline(pts, UI.RED_STRING, 2.5, true))
	string.set_process(true)
	pair.add_child(string)
	pair.move_child(string, 0)
	var redraw := Timer.new()
	redraw.wait_time = 0.016
	redraw.autostart = true
	redraw.timeout.connect(string.queue_redraw)
	pair.add_child(redraw)

	var t := UI.title("String followed.", 44)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var sub := UI.label("If %s follows it back, you'll match and can talk.\nIf not, nothing changes, and nobody is told." % person.name, 16, UI.MUTED)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(sub)
	v.add_child(UI.gap(10))
	var keep := UI.button("Keep exploring", "PrimaryButton")
	keep.custom_minimum_size = Vector2(320, 52)
	keep.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	keep.pressed.connect(_close)
	v.add_child(keep)
	_card.modulate.a = 0.0
	create_tween().tween_property(_card, "modulate:a", 1.0, 0.4)


func _close() -> void:
	closed.emit()
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.2)
	tw.tween_callback(queue_free)
