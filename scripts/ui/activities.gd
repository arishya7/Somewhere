extends Control
## Things to do inside each kind of venue, with someone who's there.
## Conversation activities (café, supper club, gallery, bookshop, studio) are data-driven "moments";
## thrift, record store, arcade and club are hands-on. All end with what you noticed about them.

signal profile_requested(person: Dictionary)
## Emitted once the activity is finished (for quests).
signal completed
signal closed

const UI = preload("res://scripts/ui.gd")
const People = preload("res://scripts/people.gd")
const Portrait = preload("res://scripts/portrait.gd")
const Avatar = preload("res://scripts/avatar.gd")
const Synth = preload("res://scripts/synth.gd")

const ACTIONS := {
	"cafe": "Order & share a table", "restaurant": "Join the supper club table", "gallery": "Walk the new show",
	"bookstore": "Blind date with a book", "studio": "Join the class", "thrift": "Browse the racks",
	"records": "Try the listening station", "arcade": "Play air hockey", "club": "Hit the dance floor",
}

## Each step: [prompt, options, fact template ("%s" = their answer), visual]
const MOMENTS := {
	"cafe": {"open": "Mind if I share your table? Everywhere else is full.", "steps": [
		["What are you ordering?", ["Flat white", "Iced matcha", "Kopi, extra strong", "Chai latte", "Hot chocolate"], "Orders a %s, every time", ""],
		["Table card: what are you looking forward to this month?", ["A trip somewhere new", "A friend's wedding", "Doing absolutely nothing", "A gig I've waited ages for"], "Is looking forward to %s", ""],
		["Table card: the best thing you've eaten lately?", ["Something from a street stall", "Homemade pasta", "A ridiculous dessert", "Someone's mum's cooking"], "Says the best thing they ate lately was %s", ""],
	]},
	"restaurant": {"open": "Supper club rules: we share everything, including opinions.", "steps": [
		["Pick a dish for the table.", ["Charred corn with lime", "Truffle mushroom pasta", "Spicy dan dan noodles", "Burrata with peaches"], "Would always order %s", ""],
		["Table talk: the last place you travelled to?", ["Somewhere with mountains", "A big, loud city", "A tiny island", "Home, to family"], "Last travelled to %s", ""],
		["Table talk: cook at home or eat out?", ["Cook, always", "Eat out, obviously", "Cook for others, eat out alone", "Depends on the week"], "On cooking vs eating out: %s", ""],
	]},
	"gallery": {"open": "I can never tell if I get modern art. Walk with me?", "steps": [
		["Piece one. How does it make you feel?", ["Calm", "Restless", "Nostalgic", "Hungry, somehow"], "Felt %s in front of the first piece", "art0"],
		["Piece two. First word that comes to mind?", ["Ocean", "Argument", "Sunday", "Electric"], "Called the second piece '%s'", "art1"],
		["Piece three. Would you hang it at home?", ["In the living room", "Only in the bathroom", "I'd gift it to an enemy", "I'd build a room for it"], "Would hang the last piece: %s", "art2"],
	]},
	"bookstore": {"open": "These are wrapped so you only see a clue. Want to pick one each?", "steps": [
		["Pick a wrapped book by its clue.", ["A slow love story set in Lisbon", "A murder on a night train", "Essays about getting lost", "Sci-fi with a sad robot"], "Picked the book with '%s'", "books"],
		["Be honest: do you fold page corners?", ["Yes, proudly", "Never, I'm not a monster", "Only for recipes", "I use receipts as bookmarks"], "On folding page corners: %s", ""],
		["What do you read on a lazy Sunday?", ["A thriller", "Something that makes me cry", "The news, sadly", "Comics"], "Reads %s on a lazy Sunday", ""],
	]},
	"studio": {"open": "First class? Me too. Grab the mat next to mine.", "steps": [
		["Let's start with two slow breaths.", ["Begin"], "", "breath"],
		["How do you feel now?", ["Lighter", "Sleepy", "Exactly the same", "Weirdly emotional"], "Felt %s after class", ""],
		["What gets you moving in the morning?", ["Coffee", "A run", "Music, loud", "Nothing. I'm a night person"], "Gets moving in the morning with %s", ""],
	]},
}

## Played live with a real person in venues whose usual activity is hands-on (not synced yet).
const LIVE_MOMENTS := {
	"thrift": {"open": "", "steps": [
		["Pick a piece for the other person to try on.", ["The loud printed shirt", "A leather jacket", "Something sequinned", "A very serious blazer"], "Picked %s for you", ""],
		["Budget: twenty dollars. Spend it on…", ["One great thing", "As many weird things as possible", "Something for someone else", "Nothing, just browsing"], "With twenty dollars: %s", ""],
		["Your thrift rule?", ["Always check the pockets", "If it fits, it's fate", "Never buy shoes", "Sniff test, every time"], "Thrift rule: %s", ""],
	]},
	"records": {"open": "", "steps": [
		["Pick a crate to dig through together.", ["Late-night jazz", "Lo-fi beats", "Synth pop", "Soul & funk"], "Went for the %s crate", ""],
		["A song you'd play on a long drive?", ["Something to sing along to", "Something slow and sad", "Old classics", "Whatever the radio says"], "On a long drive: %s", ""],
		["Vinyl, streaming or live?", ["Vinyl, obviously", "Streaming, sorry", "Live, every time", "Whatever's playing"], "Prefers %s", ""],
	]},
	"arcade": {"open": "", "steps": [
		["Pick a game to play first.", ["Air hockey", "The claw machine", "Dance machine", "Racing"], "Wanted to start with %s", ""],
		["Are you competitive?", ["Extremely", "Only when losing", "Not at all", "I let people win"], "On being competitive: %s", ""],
		["Prize-counter splurge?", ["A giant plushie", "Sweets", "A tiny rubber duck", "Save tickets forever"], "At the prize counter: %s", ""],
	]},
	"club": {"open": "", "steps": [
		["Request a song for the DJ.", ["A 2000s throwback", "Something brand new", "A K-pop banger", "Anything you can't sit still to"], "Requested %s", ""],
		["Dance floor or the edge of it?", ["Middle of the floor", "Near the speakers", "Edge, watching", "Wherever my friends are"], "Dances %s", ""],
		["Last train or stay till close?", ["Last train, always", "Till close", "Leave when it's best", "Depends who's there"], "On going home: %s", ""],
	]},
}

## [name, slot, style index, colour index, price]
const THRIFT_ITEMS := [
	["Vintage denim jacket", "top", 4, 2, 18], ["Cream knit sweater", "top", 6, 12, 14], ["Rust silk shirt", "top", 2, 10, 22],
	["Black band tee", "top", 0, 1, 8], ["Floral summer dress", "top", 5, 5, 20], ["Forest green hoodie", "top", 1, 8, 12],
	["Wide-leg trousers", "bottom", 1, 12, 16], ["Pleated skirt", "bottom", 3, 13, 12], ["Light-wash jeans", "bottom", 0, 3, 15],
]

## [title, colour, bpm, wave, notes]
const RECORDS := [
	["Late-night jazz", Color("#2F4C7A"), 92.0, "triangle", [[62, 1], [65, 0.5], [69, 0.5], [72, 1], [70, 0.5], [67, 1.5], [-1, 0.5], [65, 0.5], [69, 0.5], [74, 1], [72, 2]]],
	["Lo-fi beats", Color("#7A5C99"), 74.0, "sine", [[60, 1], [64, 1], [67, 1], [71, 1], [69, 1], [67, 1], [64, 2]]],
	["Synth pop", Color("#E5A2B5"), 120.0, "square", [[69, 0.5], [72, 0.5], [76, 0.5], [72, 0.5], [74, 0.5], [77, 0.5], [81, 1], [79, 0.5], [76, 0.5], [74, 1], [72, 1]]],
	["Soul & funk", Color("#C9733C"), 104.0, "saw", [[57, 0.5], [60, 0.5], [62, 1], [64, 0.5], [62, 0.5], [60, 1], [57, 0.5], [55, 0.5], [57, 2]]],
]

var kind := ""
var companion := {}
var venue := ""
var _rng := RandomNumberGenerator.new()
var _card: PanelContainer
var _body: VBoxContainer
var _bubble: Label
var _learned := []
var _step := 0
var _canvas: Control
var _game := {}
var _player: AudioStreamPlayer
var _preview := {}
## Live game with a real person: shared seed, their actual picks by step.
var seed := 0
var _theirs_by_step := {}
var _waiting := {}


func _real() -> bool:
	return companion.get("real", false)


static func open(host: Control, activity: String, person: Dictionary, venue_name: String, shared_seed := 0) -> Control:
	var a = load("res://scripts/ui/activities.gd").new()
	a.seed = shared_seed
	a.kind = activity
	a.companion = person
	a.venue = venue_name
	host.add_child(a)
	return a


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	UI.scrim(self)
	_rng.seed = seed if seed != 0 else hash(companion.id + str(Time.get_ticks_msec()))
	if _real():
		var on_play := func(h: String, r: int, choice: int) -> void:
			if h == companion.get("handle", ""):
				_theirs_by_step[r] = choice
				if not _waiting.is_empty() and int(_waiting.step) == r:
					var cb: Callable = _waiting.cb
					_waiting = {}
					cb.call()
		Net.play_received.connect(on_play)
		tree_exiting.connect(func() -> void: Net.play_received.disconnect(on_play))
	_player = AudioStreamPlayer.new()
	add_child(_player)
	_card = PanelContainer.new()
	_card.theme_type_variation = "Card"
	_card.anchor_left = 0.5
	_card.anchor_right = 0.5
	_card.anchor_top = 0.5
	_card.anchor_bottom = 0.5
	_card.offset_left = -440
	_card.offset_right = 440
	_card.offset_top = -340
	_card.offset_bottom = 340
	add_child(_card)
	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 14)
	_card.add_child(_body)
	if _real():
		load("res://scripts/ui/quick_chat.gd").attach(self, _card, companion)
		_moment()
		return
	match kind:
		"thrift": _thrift()
		"records": _records()
		"arcade": _arcade_intro()
		"club": _club_intro()
		_: _moment()


# --- Shared pieces --------------------------------------------------------------

func _clear() -> void:
	for c in _body.get_children():
		c.queue_free()
	_canvas = null


func _header(title: String) -> void:
	var row := HBoxContainer.new()
	_body.add_child(row)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_child(UI.eyebrow(ACTIONS.get(kind, "") + "  ·  " + venue, UI.GOLD))
	row.add_child(left)
	var close := UI.button("×", "TextButton")
	close.pressed.connect(_close)
	row.add_child(close)
	_body.add_child(UI.title(title, 30))


func _companion(text: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	_body.add_child(row)
	row.add_child(Portrait.make(companion.cfg, 54, UI.GOLD))
	var bubble := PanelContainer.new()
	bubble.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bubble.add_theme_stylebox_override("panel", UI.box(Color(1, 1, 1, 0.06), 16, Color(0, 0, 0, 0), 0, 16, 11))
	row.add_child(bubble)
	_bubble = UI.label(text, 16, UI.CREAM)
	bubble.add_child(_bubble)


func _spacer() -> void:
	var s := Control.new()
	s.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.add_child(s)


func _primary(text: String, cb: Callable) -> Button:
	var b := UI.button(text, "PrimaryButton")
	b.custom_minimum_size.y = 52
	b.pressed.connect(cb)
	_body.add_child(b)
	return b


func _canvas_area(h: float, draw_cb: Callable) -> Control:
	var frame := Panel.new()
	frame.custom_minimum_size = Vector2(0, h)
	frame.add_theme_stylebox_override("panel", UI.box(Color("#120C1A"), 16))
	frame.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	_body.add_child(frame)
	_canvas = Control.new()
	_canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_canvas.draw.connect(draw_cb)
	frame.add_child(_canvas)
	return frame


func _fact(text: String) -> void:
	if text != "":
		_learned.append(text)


func _finish(headline: String) -> void:
	completed.emit()
	_clear()
	_header(headline)
	var facts := _learned.duplicate()
	if _real():
		Profile.learn(companion.id, facts)
		_body.add_child(UI.eyebrow("What you found out about @%s" % companion.handle, UI.GOLD))
		for f in facts.slice(0, 5):
			_body.add_child(UI.label("·  " + f, 15, UI.CREAM))
	elif not companion.get("host", false):
		for f in companion.facts.slice(0, 1):
			facts.append(f.left(1).to_upper() + f.substr(1))
		Profile.learn(companion.id, facts)
		_body.add_child(UI.eyebrow("What you noticed about %s" % companion.name, UI.GOLD))
		for f in facts.slice(0, 5):
			_body.add_child(UI.label("·  " + f, 15, UI.CREAM))
	if _real():
		_companion("You and @%s finished this together. Say hi in chat, or play again." % companion.handle)
	elif companion.get("traits", []).size() > 1:
		_companion("This was nice. " + People.TRAITS[companion.traits[1]].voice)
	else:
		_companion("This was nice. Come back any time.")
	_spacer()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	_body.add_child(row)
	var back := UI.button("Back to %s" % venue)
	back.custom_minimum_size.y = 52
	back.pressed.connect(_close)
	row.add_child(back)
	if companion.get("host", false) or _real():
		return
	var view := UI.button("See %s's profile" % companion.name, "PrimaryButton")
	view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	view.custom_minimum_size.y = 52
	view.pressed.connect(func() -> void:
		profile_requested.emit(companion)
		queue_free())
	row.add_child(view)


func _close() -> void:
	closed.emit()
	queue_free()


func _process(delta: float) -> void:
	if kind == "arcade" and _game.get("running", false):
		_arcade_step(delta)
	if kind == "club" and _game.get("running", false):
		if Time.get_ticks_msec() / 1000.0 - _game.start > 21.0:
			_game.running = false
			_club_done()
	if _canvas and is_instance_valid(_canvas):
		_canvas.queue_redraw()


# --- Moments: choice-based conversations -------------------------------------------

func _moment() -> void:
	var data: Dictionary = MOMENTS.get(kind, LIVE_MOMENTS.get(kind, MOMENTS.cafe))
	_clear()
	if _step >= data.steps.size():
		_finish("That was lovely.")
		return
	var step: Array = data.steps[_step]
	_header(step[0])
	var visual: String = step[3]
	if visual.begins_with("art"):
		var seed_n := int(visual.substr(3))
		_canvas_area(220, _draw_art.bind(seed_n))
	elif visual == "breath":
		_breath()
		return
	if _real():
		_companion("You're doing this live with @%s. You both pick, then you see each other's answer." % companion.handle)
	else:
		_companion(data.open if _step == 0 else "Your turn first.")
	var options: Array = step[1]
	var theirs: String = options[_rng.randi() % options.size()]
	var my_step := _step
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	_body.add_child(grid)
	var buttons: Array[Button] = []
	for o in options:
		var b := UI.button(o, "Chip")
		b.custom_minimum_size = Vector2(395, 54)
		b.add_theme_font_size_override("font_size", 15)
		buttons.append(b)
		grid.add_child(b)
	_spacer()
	var next := _primary("Next", func() -> void:
		_step += 1
		_moment())
	next.visible = false
	for b in buttons:
		b.pressed.connect(func() -> void:
			for x in buttons:
				x.disabled = true
			if _real():
				Net.send_play(companion.handle, my_step, options.find(b.text))
				var reveal := func() -> void:
					if _step != my_step or not is_instance_valid(b):
						return
					var t: String = options[clampi(int(_theirs_by_step.get(my_step, 0)), 0, options.size() - 1)]
					_mark(buttons, b.text, t)
					_bubble.text = ("@%s picked the same: %s." if t == b.text else "@%s picked: %s.") % [companion.handle, t]
					_fact(step[2] % (t.left(1).to_lower() + t.substr(1)) if step[2] != "" else "")
					next.visible = true
				if _theirs_by_step.has(my_step):
					reveal.call()
				else:
					_bubble.text = "Waiting for @%s to pick…" % companion.handle
					_waiting = {"step": my_step, "cb": reveal}
					_wait_escape(next)
				return
			for x in buttons:
				if x.text == b.text:
					x.add_theme_stylebox_override("disabled", UI.box(UI.CREAM, 12, Color(0, 0, 0, 0), 0, 16, 9))
					x.add_theme_color_override("font_disabled_color", UI.INK)
				elif x.text == theirs:
					x.add_theme_stylebox_override("disabled", UI.box(Color(UI.GOLD, 0.2), 12, UI.GOLD, 1, 16, 9))
					x.add_theme_color_override("font_disabled_color", UI.CREAM)
			if b.text == theirs:
				_bubble.text = ["Same! Okay, I like you already.", "No way, me too.", "Great minds."][_rng.randi() % 3]
			else:
				_bubble.text = "Ooh. I'd have said '%s'. Tell me why yours?" % theirs
			_fact(step[2] % (theirs.left(1).to_lower() + theirs.substr(1)) if step[2] != "" else "")
			next.visible = true)


## Colour your pick and theirs.
func _mark(buttons: Array, mine: String, theirs: String) -> void:
	for x in buttons:
		if x.text == mine:
			x.add_theme_stylebox_override("disabled", UI.box(UI.CREAM, 12, Color(0, 0, 0, 0), 0, 16, 9))
			x.add_theme_color_override("font_disabled_color", UI.INK)
		elif x.text == theirs:
			x.add_theme_stylebox_override("disabled", UI.box(Color(UI.GOLD, 0.2), 12, UI.GOLD, 1, 16, 9))
			x.add_theme_color_override("font_disabled_color", UI.CREAM)


## If the other person wanders off, don't leave you stuck waiting.
func _wait_escape(next: Button) -> void:
	await get_tree().create_timer(20.0).timeout
	if not is_instance_valid(next) or _waiting.is_empty():
		return
	_bubble.text = "@%s is taking a while. They may have stepped away." % companion.handle
	next.text = "Carry on without them"
	next.visible = true


func _draw_art(seed_n: int) -> void:
	var s := _canvas.size
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(venue) + seed_n
	_canvas.draw_rect(Rect2(Vector2.ZERO, s), Color("#F2EFE9"))
	var frame := Rect2(s.x * 0.3, 18, s.x * 0.4, s.y - 36)
	_canvas.draw_rect(frame.grow(8), Color("#C9A26B"))
	var cols := [Color("#E46C4C"), Color("#1F2D4A"), Color("#F2C14E"), Color("#5E8C61"), Color("#E5A2B5"), Color("#F3EEE6")]
	_canvas.draw_rect(frame, cols[rng.randi() % cols.size()])
	for i in 5:
		var c: Color = cols[rng.randi() % cols.size()]
		match rng.randi() % 3:
			0: _canvas.draw_circle(frame.position + Vector2(rng.randf(), rng.randf()) * frame.size, rng.randf_range(12, 50), c)
			1: _canvas.draw_rect(Rect2(frame.position + Vector2(rng.randf() * 0.7, rng.randf() * 0.7) * frame.size, Vector2(rng.randf_range(20, 90), rng.randf_range(20, 90))), c)
			2: _canvas.draw_line(frame.position + Vector2(rng.randf(), rng.randf()) * frame.size, frame.position + Vector2(rng.randf(), rng.randf()) * frame.size, c, rng.randf_range(3, 12))
	_canvas.draw_string(UI.font(500), Vector2(0, s.y - 4), "Untitled No. %d" % (seed_n + 3), HORIZONTAL_ALIGNMENT_CENTER, s.x, 11, Color(0, 0, 0, 0.45))


func _breath() -> void:
	_companion(("Breathing with @%s. In for three, out for three." % companion.handle) if _real() else "In for three, out for three. I'll count.")
	_game = {"start": -1.0}
	_canvas_area(280, func() -> void:
		var s := _canvas.size
		var c := s / 2.0
		var t: float = (Time.get_ticks_msec() / 1000.0 - _game.start) if _game.start >= 0.0 else 0.0
		var cycle := fmod(t, 6.0)
		var k := cycle / 3.0 if cycle < 3.0 else 1.0 - (cycle - 3.0) / 3.0
		if _game.start < 0.0:
			k = 0.3
		for i in 10:
			_canvas.draw_circle(c, (60.0 + 80.0 * ease(k, -2.0)) * (1.0 - i / 10.0) + 20.0, Color(0.56, 0.78, 0.65, 0.05))
		_canvas.draw_circle(c, 40.0 + 70.0 * ease(k, -2.0), Color(0.56, 0.78, 0.65, 0.5))
		var label := "Ready when you are"
		if _game.start >= 0.0:
			label = "Done" if t >= 12.0 else ("Breathe in" if cycle < 3.0 else "Breathe out")
		_canvas.draw_string(UI.serif(400, true), Vector2(0, s.y - 24), label, HORIZONTAL_ALIGNMENT_CENTER, s.x, 22, UI.CREAM))
	_spacer()
	var b := _primary("Begin", func() -> void: pass)
	b.pressed.connect(func() -> void:
		if _game.start < 0.0:
			_game.start = Time.get_ticks_msec() / 1000.0
			b.disabled = true
			b.text = "Breathing..."
			_bubble.text = "One... two... three..."
			await get_tree().create_timer(12.0).timeout
			if not is_instance_valid(b):
				return
			_bubble.text = "Done. Breathing together, even miles apart." if _real() else "Okay. That actually helped."
			b.disabled = false
			b.text = "Next"
		else:
			_step += 1
			_moment())


# --- Thrift: try things on ------------------------------------------------------------

func _thrift() -> void:
	_clear()
	_header("Try something on.")
	_preview = Profile.data.avatar.duplicate()
	_companion("Okay, I'm going to be honest with you about everything you try on.")
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.add_child(row)
	var mirror := Panel.new()
	mirror.custom_minimum_size = Vector2(250, 360)
	mirror.add_theme_stylebox_override("panel", UI.box(Color("#E9E1D6"), 16, Color("#C9A26B"), 6))
	row.add_child(mirror)
	var cv := Control.new()
	cv.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cv.draw.connect(func() -> void:
		Avatar.draw(cv, _preview, Vector2(cv.size.x / 2.0, cv.size.y - 26), (cv.size.y - 60) / 300.0, Time.get_ticks_msec() / 1000.0))
	mirror.add_child(cv)
	_canvas = cv
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	row.add_child(grid)
	var tried := []
	var lines := ["Oh, that's very you.", "Bold. I respect it.", "That colour is doing a lot for you.", "Hmm. Next.", "Wait, go back, that one was great."]
	for item in THRIFT_ITEMS:
		var b := Button.new()
		b.custom_minimum_size = Vector2(170, 86)
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		b.add_theme_stylebox_override("normal", UI.box(Color(1, 1, 1, 0.05), 12))
		b.add_theme_stylebox_override("hover", UI.box(Color(1, 1, 1, 0.1), 12))
		b.add_theme_stylebox_override("pressed", UI.box(Color(1, 1, 1, 0.14), 12))
		var v := VBoxContainer.new()
		v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 10)
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(v)
		var sw := ColorRect.new()
		sw.color = Avatar.CLOTH[item[3]]
		sw.custom_minimum_size = Vector2(24, 24)
		sw.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(sw)
		var name_l := UI.label(item[0], 13, UI.CREAM, 500)
		name_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(name_l)
		var price := UI.label("$%d" % item[4], 12, UI.MUTED)
		price.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(price)
		b.pressed.connect(func() -> void:
			_preview[item[1]] = item[2]
			_preview[item[1] + "_color"] = item[3]
			if not item[0] in tried:
				tried.append(item[0])
			_bubble.text = lines[_rng.randi() % lines.size()])
		grid.add_child(b)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 10)
	_body.add_child(actions)
	var reset := UI.button("Put it all back")
	reset.custom_minimum_size.y = 50
	reset.pressed.connect(func() -> void:
		_preview = Profile.data.avatar.duplicate()
		_bubble.text = "Classic. Fair.")
	actions.add_child(reset)
	var keep := UI.button("Keep this look", "PrimaryButton")
	keep.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	keep.custom_minimum_size.y = 50
	keep.pressed.connect(func() -> void:
		Profile.data.avatar = _preview.duplicate()
		Profile.save()
		_fact("Gave honest opinions on %d things you tried on" % maxi(1, tried.size()))
		_fact("Thrifts for %s" % ["vintage denim", "old band tees", "anything in rust", "knitwear, even in this heat"][_rng.randi() % 4])
		_finish("Looking good."))
	actions.add_child(keep)


# --- Record store: listening station ---------------------------------------------------

func _records() -> void:
	_clear()
	_header("Put on a record.")
	_companion("Headphones are clean, I checked. Play one?")
	var favourite: Array = RECORDS[_rng.randi() % RECORDS.size()]
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 12)
	_body.add_child(grid)
	var played := []
	_game = {"playing": -1, "since": 0.0}
	for i in RECORDS.size():
		var r: Array = RECORDS[i]
		var b := Button.new()
		b.custom_minimum_size = Vector2(190, 230)
		b.flat = true
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		b.draw.connect(func() -> void:
			var s := b.size
			var cover := Rect2(10, 0, s.x - 20, s.x - 20)
			b.draw_rect(cover, r[1])
			var c := cover.get_center()
			var spin: float = (Time.get_ticks_msec() / 1000.0 - _game.since) * 3.0 if _game.playing == i else 0.0
			b.draw_circle(c, cover.size.x * 0.32, Color("#0E0E0E"))
			b.draw_arc(c, cover.size.x * 0.22, spin, spin + 1.2, 12, Color(1, 1, 1, 0.2), 2.0, true)
			b.draw_circle(c, cover.size.x * 0.08, r[1].lightened(0.3))
			b.draw_string(UI.font(500), Vector2(0, s.y - 26), r[0], HORIZONTAL_ALIGNMENT_CENTER, s.x, 14, UI.CREAM)
			b.draw_string(UI.font(500), Vector2(0, s.y - 6), "▶  Playing" if _game.playing == i else "▶  Listen", HORIZONTAL_ALIGNMENT_CENTER, s.x, 12, UI.GOLD if _game.playing == i else UI.MUTED))
		b.pressed.connect(func() -> void:
			_player.stream = Synth.melody(r[4], r[2], r[3])
			_player.play()
			_game.playing = i
			_game.since = Time.get_ticks_msec() / 1000.0
			if not r[0] in played:
				played.append(r[0])
			if r == favourite:
				_bubble.text = "Oh, THIS one. I'd play this on a long drive."
			else:
				_bubble.text = ["Not bad. A bit sleepy?", "My dad would love this.", "Okay, the bassline is good.", "Play the next one!"][_rng.randi() % 4])
		grid.add_child(b)
	_canvas = Control.new()
	_canvas.custom_minimum_size = Vector2(0, 1)
	_canvas.draw.connect(func() -> void:
		for c in grid.get_children():
			c.queue_redraw())
	_body.add_child(_canvas)
	_spacer()
	var done := _primary("Pick a favourite", func() -> void: pass)
	done.pressed.connect(func() -> void:
		_player.stop()
		_fact("Would play %s on a long drive" % favourite[0].to_lower())
		_fact("Listened to %d records with you" % maxi(1, played.size()))
		_finish("Good taste."))


# --- Arcade: air hockey, you vs them ---------------------------------------------------

const GOALS_TO_WIN := 5


func _arcade_intro() -> void:
	_clear()
	_header("Air hockey. You versus %s." % companion.name)
	_companion("First to %d. Move your mallet with the mouse (or arrow keys). No pressure, it's just for fun." % GOALS_TO_WIN)
	_game = {"running": false, "you": 0, "them": 0, "puck": Vector2(0.5, 0.5), "vel": Vector2.ZERO,
		"me": Vector2(0.15, 0.5), "me_prev": Vector2(0.15, 0.5), "ai": Vector2(0.85, 0.5), "ai_prev": Vector2(0.85, 0.5),
		"target": Vector2(0.15, 0.5), "pause": 0.0, "skill": 0.3 + 0.15 * _rng.randf()}
	var frame := _canvas_area(400, _draw_arcade)
	frame.custom_minimum_size.y = 400
	_canvas.mouse_filter = Control.MOUSE_FILTER_STOP
	_canvas.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseMotion and _canvas.size.x > 0:
			_game.target = Vector2(e.position.x / _canvas.size.x, e.position.y / _canvas.size.y))
	_spacer()
	var start := _primary("Face off", func() -> void: pass)
	start.pressed.connect(func() -> void:
		if not _game.running:
			_game.running = true
			_serve(-1.0)
			start.visible = false)


func _serve(towards: float) -> void:
	_game.puck = Vector2(0.5, 0.5)
	_game.vel = Vector2(towards * 0.25, _rng.randf_range(-0.15, 0.15))
	_game.pause = 0.8


func _arcade_step(dt: float) -> void:
	var aspect := _canvas.size.x / maxf(_canvas.size.y, 1.0) if _canvas else 2.0
	if _game.pause > 0.0:
		_game.pause -= dt
		return
	# Your mallet: follows the mouse or arrow keys, stays on your half.
	var key := Vector2(
		float(Input.is_key_pressed(KEY_RIGHT) or Input.is_physical_key_pressed(KEY_D)) - float(Input.is_key_pressed(KEY_LEFT) or Input.is_physical_key_pressed(KEY_A)),
		float(Input.is_key_pressed(KEY_DOWN) or Input.is_physical_key_pressed(KEY_S)) - float(Input.is_key_pressed(KEY_UP) or Input.is_physical_key_pressed(KEY_W)))
	if key != Vector2.ZERO:
		_game.target = _game.me + key * dt * 1.4
	_game.me_prev = _game.me
	_game.me = _game.me.move_toward(Vector2(clampf(_game.target.x, 0.04, 0.47), clampf(_game.target.y, 0.08, 0.92)), dt * 3.2)
	# Their mallet: chases the puck on their half, otherwise guards the goal.
	_game.ai_prev = _game.ai
	var want := Vector2(0.88, clampf(_game.puck.y, 0.25, 0.75))
	if _game.puck.x > 0.5:
		# Get behind the puck, lined up with your goal, then drive through it.
		var aim: Vector2 = (_game.puck - Vector2(0.0, 0.5)).normalized()
		want = _game.puck + aim * 0.05
		if _game.ai.distance_to(want) < 0.03:
			want = _game.puck - aim * 0.05
	# Friendly, not pro: slower than you, and it eases off further when it's ahead.
	var lead := float(_game.them - _game.you)
	var ai_speed: float = (0.45 + 0.7 * _game.skill) * (0.75 if lead > 0.0 else 1.0)
	_game.ai = _game.ai.move_toward(Vector2(clampf(want.x, 0.53, 0.96), clampf(want.y, 0.08, 0.92)), dt * ai_speed)
	# Puck.
	var pk: Vector2 = _game.puck + _game.vel * dt
	var v: Vector2 = _game.vel * pow(0.85, dt)
	if pk.y < 0.05 or pk.y > 0.95:
		v.y = -v.y
		pk.y = clampf(pk.y, 0.05, 0.95)
	var in_goal_mouth := pk.y > 0.35 and pk.y < 0.65
	if pk.x < 0.02:
		if in_goal_mouth:
			_goal(false)
			return
		v.x = absf(v.x)
		pk.x = 0.02
	if pk.x > 0.98:
		if in_goal_mouth:
			_goal(true)
			return
		v.x = -absf(v.x)
		pk.x = 0.98
	for who in ["me", "ai"]:
		var m: Vector2 = _game[who]
		var d := Vector2((pk.x - m.x) * aspect, pk.y - m.y)
		var reach := 0.125 if who == "me" else 0.1
		if d.length() < reach:
			var n := d.normalized()
			var mallet_v: Vector2 = (m - _game[who + "_prev"]) / maxf(dt, 0.001)
			pk = m + Vector2(n.x / aspect, n.y) * reach
			var power := 1.0 if who == "me" else 0.7
			v = (Vector2(n.x / aspect, n.y) * maxf(0.75, v.length()) + mallet_v * 0.7) * power
	_game.puck = pk
	_game.vel = v.limit_length(1.6)


func _goal(you_scored: bool) -> void:
	if you_scored:
		_game.you += 1
		_bubble.text = ["Okay, lucky shot.", "Hey! I wasn't ready.", "Fine. FINE."][_rng.randi() % 3]
	else:
		_game.them += 1
		_bubble.text = ["Goal! Did you see that?", "Too easy. Kidding. Mostly.", "And the crowd goes wild."][_rng.randi() % 3]
	if _game.you >= GOALS_TO_WIN or _game.them >= GOALS_TO_WIN:
		_game.running = false
		_arcade_done()
	else:
		_serve(-1.0 if you_scored else 1.0)


func _draw_arcade() -> void:
	var s := _canvas.size
	var table := Rect2(Vector2(10, 10), s - Vector2(20, 20))
	_canvas.draw_style_box(UI.box(Color("#DCEBF3"), 26, Color("#5FD4FF"), 4), table)
	_canvas.draw_line(Vector2(s.x / 2.0, table.position.y), Vector2(s.x / 2.0, table.end.y), Color(0.85, 0.2, 0.3, 0.5), 3.0)
	_canvas.draw_arc(s / 2.0, s.y * 0.18, 0.0, TAU, 48, Color(0.85, 0.2, 0.3, 0.5), 3.0, true)
	for side in [0.0, 1.0]:
		var gx: float = table.position.x if side == 0.0 else table.end.x
		_canvas.draw_line(Vector2(gx, s.y * 0.35), Vector2(gx, s.y * 0.65), Color("#1A1224"), 10.0)
		_canvas.draw_arc(Vector2(gx, s.y / 2.0), s.y * 0.2, -PI / 2.0 if side == 0.0 else PI / 2.0, PI / 2.0 if side == 0.0 else PI * 1.5, 24, Color(0.2, 0.4, 0.85, 0.4), 3.0, true)
	var to_px := func(p: Vector2) -> Vector2: return Vector2(p.x * s.x, p.y * s.y)
	var r := s.y * 0.11
	_canvas.draw_circle(to_px.call(_game.puck), r * 0.42, Color("#1A1224"))
	_canvas.draw_circle(to_px.call(_game.puck), r * 0.3, Color("#2A2234"))
	for spec in [[_game.me, UI.CORAL], [_game.ai, Color("#5E6FD8")]]:
		var c: Vector2 = to_px.call(spec[0])
		_canvas.draw_circle(c + Vector2(0, 3), r * 0.62, Color(0, 0, 0, 0.2))
		_canvas.draw_circle(c, r * 0.62, spec[1])
		_canvas.draw_circle(c, r * 0.32, spec[1].lightened(0.25))
	Avatar.draw_portrait(_canvas, Profile.data.avatar, Vector2(60, 50), 24.0, UI.CORAL)
	Avatar.draw_portrait(_canvas, companion.cfg, Vector2(s.x - 60, 50), 24.0, Color("#5E6FD8"))
	_canvas.draw_string(UI.font(800), Vector2(0, 62), "%d   :   %d" % [_game.you, _game.them], HORIZONTAL_ALIGNMENT_CENTER, s.x, 30, UI.INK)


func _arcade_done() -> void:
	var won: bool = _game.you > _game.them
	_bubble.text = "Good game! %s" % ("You got me. Rematch soon?" if won else "Don't worry, I've had a lot of practice.")
	_fact("Plays air hockey like the World Cup is on the line")
	_fact("%s, %d–%d" % ["Lost to you" if won else "Beat you", maxi(_game.you, _game.them), mini(_game.you, _game.them)])
	await get_tree().create_timer(2.5).timeout
	if is_inside_tree():
		_finish("Game over. Good game.")


# --- Club: dance floor ------------------------------------------------------------------

const LANES := [KEY_LEFT, KEY_DOWN, KEY_UP, KEY_RIGHT]
const ARROWS := ["←", "↓", "↑", "→"]


func _club_intro() -> void:
	_clear()
	_header("The DJ's playing your song.")
	_companion("Hit the arrow keys when the notes reach the line. I'll be right next to you.")
	var bpm := 120.0
	var notes := []
	var t := 2.0
	while t < 20.0:
		notes.append({"t": t, "lane": _rng.randi() % 4, "hit": false})
		t += 60.0 / bpm * (1 if _rng.randf() < 0.7 else 2)
	_game = {"running": false, "start": 0.0, "notes": notes, "score": 0, "perfect": 0, "flash": [0.0, 0.0, 0.0, 0.0], "bpm": bpm}
	_canvas_area(380, _draw_club)
	_spacer()
	var start := _primary("Start", func() -> void: pass)
	start.pressed.connect(func() -> void:
		if not _game.running:
			_player.stream = Synth.beat(bpm, 22.0)
			_player.play()
			_game.running = true
			_game.start = Time.get_ticks_msec() / 1000.0
			start.visible = false)


func _input(event: InputEvent) -> void:
	if kind != "club" or not _game.get("running", false):
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var lane := LANES.find(event.keycode)
		if lane < 0:
			return
		var now: float = Time.get_ticks_msec() / 1000.0 - _game.start
		for n in _game.notes:
			if n.lane == lane and not n.hit and absf(n.t - now) < 0.22:
				n.hit = true
				_game.score += 2 if absf(n.t - now) < 0.1 else 1
				if absf(n.t - now) < 0.1:
					_game.perfect += 1
				_game.flash[lane] = 1.0
				break
		get_viewport().set_input_as_handled()


func _draw_club() -> void:
	var s := _canvas.size
	var now: float = Time.get_ticks_msec() / 1000.0 - _game.start if _game.running else 0.0
	var line_y := s.y * 0.82
	var cols := [Color("#B57BFF"), Color("#5FD4FF"), Color("#7CF2A2"), Color("#FF6FB1")]
	var pulse: float = 0.5 + 0.5 * cos(now * TAU * _game.bpm / 60.0) if _game.running else 0.0
	_canvas.draw_rect(Rect2(Vector2.ZERO, s), Color(0.5, 0.3, 0.9, 0.05 + 0.05 * pulse))
	for l in 4:
		var x := s.x * (0.32 + l * 0.12)
		_canvas.draw_line(Vector2(x, 0), Vector2(x, s.y), Color(1, 1, 1, 0.06), 2.0)
		_game.flash[l] = maxf(0.0, _game.flash[l] - get_process_delta_time() * 4.0)
		_canvas.draw_circle(Vector2(x, line_y), 26.0, Color(cols[l], 0.25 + 0.6 * _game.flash[l]))
		_canvas.draw_string(UI.font(800), Vector2(x - 20, line_y + 8), ARROWS[l], HORIZONTAL_ALIGNMENT_CENTER, 40, 20, UI.CREAM)
	for n in _game.notes:
		if n.hit:
			continue
		var y: float = line_y - (n.t - now) * 220.0
		if y < -30 or y > s.y + 30:
			continue
		var x: float = s.x * (0.32 + n.lane * 0.12)
		_canvas.draw_circle(Vector2(x, y), 20.0, cols[n.lane])
		_canvas.draw_string(UI.font(800), Vector2(x - 20, y + 7), ARROWS[n.lane], HORIZONTAL_ALIGNMENT_CENTER, 40, 18, UI.INK)
	# You and your companion, dancing.
	var bob := absf(sin(now * PI * _game.bpm / 60.0)) * 8.0
	Avatar.draw(_canvas, Profile.data.avatar, Vector2(s.x * 0.12, s.y - 10 - bob), 0.9, now)
	Avatar.draw(_canvas, companion.cfg, Vector2(s.x * 0.88, s.y - 10 - (8.0 - bob)), 0.9, now + 1.0)
	_canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_canvas.draw_string(UI.font(800), Vector2(16, 30), "%d" % _game.score, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, UI.CREAM)


func _club_done() -> void:
	var hits := 0
	for n in _game.notes:
		if n.hit:
			hits += 1
	_bubble.text = "%d out of %d! %s" % [hits, _game.notes.size(), "You can actually dance." if hits > _game.notes.size() / 2 else "We'll call it interpretive."]
	_fact("Dances like nobody's watching (everybody was)")
	_fact("Knew every word to the DJ's last song")
	await get_tree().create_timer(2.5).timeout
	if is_inside_tree():
		_finish("What a night.")
