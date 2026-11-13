extends Control
## Trivia night. You're paired with a stranger: general-knowledge rounds show how they
## think, and "team rounds" (no wrong answers) show who they are.

signal profile_requested(person: Dictionary)
## Emitted once the activity is finished (for quests).
signal completed
signal closed

const UI = preload("res://scripts/ui.gd")
const People = preload("res://scripts/people.gd")
const Portrait = preload("res://scripts/portrait.gd")

const QUESTIONS := [
	["Which planet has the most known moons?", ["Saturn", "Jupiter", "Neptune", "Mars"], "culture"],
	["In which city would you find the Sagrada Família?", ["Barcelona", "Madrid", "Lisbon", "Rome"], "art"],
	["How many hearts does an octopus have?", ["Three", "One", "Two", "Eight"], "outdoors"],
	["Which country gave the Statue of Liberty to the United States?", ["France", "United Kingdom", "Spain", "Italy"], "culture"],
	["Which painter cut off part of his own ear?", ["Vincent van Gogh", "Pablo Picasso", "Claude Monet", "Salvador Dalí"], "art"],
	["Which is the largest ocean on Earth?", ["Pacific", "Atlantic", "Indian", "Arctic"], "outdoors"],
	["How many keys does a standard piano have?", ["88", "76", "92", "64"], "music"],
	["What is the capital of Canada?", ["Ottawa", "Toronto", "Vancouver", "Montreal"], "culture"],
	["How many players does each football team have on the pitch?", ["11", "9", "10", "12"], "sports"],
	["Who wrote Pride and Prejudice?", ["Jane Austen", "Charlotte Brontë", "Virginia Woolf", "Mary Shelley"], "culture"],
	["In which year did humans first walk on the Moon?", ["1969", "1965", "1972", "1959"], "culture"],
	["Which band recorded Bohemian Rhapsody?", ["Queen", "The Beatles", "ABBA", "Led Zeppelin"], "music"],
	["What is the fastest land animal?", ["Cheetah", "Pronghorn", "Lion", "Greyhound"], "outdoors"],
	["Which grain is used to make traditional Japanese sake?", ["Rice", "Barley", "Wheat", "Millet"], "food"],
	["Which video game character is a plumber in red overalls?", ["Mario", "Link", "Sonic", "Kirby"], "gaming"],
	["How long is a marathon?", ["42.2 km", "40 km", "26.2 km", "50 km"], "sports"],
	["Which spice gives paella its golden colour?", ["Saffron", "Turmeric", "Paprika", "Cumin"], "food"],
	["Yoga's 'downward dog' is named after which animal pose?", ["A stretching dog", "A sleeping cat", "A cobra", "A crow"], "wellness"],
]
const TEAM_ROUNDS := [
	["Team round: the perfect first date?", ["A long walk, no plan", "Dinner somewhere candlelit", "Something active, like climbing", "A gig in a tiny venue"], "would pick %s for a first date"],
	["Team round: you win a free flight tomorrow. Where?", ["Somewhere with mountains", "A city you've never seen", "A beach with no signal", "Home, to family"], "would spend a free flight on %s"],
	["Team round: Friday night, ideally?", ["Out until late", "Dinner with close friends", "Home with a film", "Wherever the night goes"], "spends the ideal Friday: %s"],
	["Team round: pick a superpower.", ["Teleporting", "Speaking every language", "Pausing time", "Talking to animals"], "would choose %s as a superpower"],
]
const TEAM_NAMES := ["Lost Socks", "Quiz Khalifa", "The Red Herrings", "Agatha Quiztie", "Les Quizérables", "Ctrl Alt Defeat"]
const ROUNDS := 6

var teammate := {}
var venue := ""
var _rng := RandomNumberGenerator.new()
var _plan := [] # [kind, data] per round
var _round := 0
var _score := 0
var _rivals := []
var _team := ""
var _learned := []
var _agreed := 0
var _card: PanelContainer
var _body: VBoxContainer
var _bubble: Label
var _answers: Array[Button] = []
var _next_btn: Button
var _score_label: Label
var _their_pick := -1
var seed := 0
## Live game with a real person: their actual answers, by round.
var _their_rounds := {}
var _pending := []


func _real() -> bool:
	return teammate.get("real", false)


static func open(host: Control, person: Dictionary, venue_name: String, shared_seed := 0) -> Control:
	var v = load("res://scripts/ui/trivia.gd").new()
	v.teammate = person
	v.venue = venue_name
	v.seed = shared_seed
	host.add_child(v)
	return v


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	UI.scrim(self)
	# Both players use the same seed, so they get the same questions in the same order.
	_rng.seed = seed if seed != 0 else hash(teammate.id + str(Time.get_ticks_msec()))
	if _real():
		var on_play := func(h: String, r: int, choice: int) -> void:
			if h == teammate.handle:
				_their_rounds[r] = choice
				if not _pending.is_empty() and _pending[4] == r:
					var pend := _pending
					_pending = []
					_reveal(pend[0], pend[1], pend[2], pend[3])
		Net.play_received.connect(on_play)
		tree_exiting.connect(func() -> void: Net.play_received.disconnect(on_play))
	var qs := range(QUESTIONS.size())
	var trs := range(TEAM_ROUNDS.size())
	for i in ROUNDS:
		if i == 1 or i == 4:
			_plan.append(["team", TEAM_ROUNDS[trs.pop_at(_rng.randi() % trs.size())]])
		else:
			_plan.append(["quiz", QUESTIONS[qs.pop_at(_rng.randi() % qs.size())]])
	_team = TEAM_NAMES[_rng.randi() % TEAM_NAMES.size()]
	for n in ["The Usual Suspects", "Table Six", "Quizzy Rascals"]:
		_rivals.append([n, 0])

	_card = PanelContainer.new()
	_card.theme_type_variation = "Card"
	_card.anchor_left = 0.5
	_card.anchor_right = 0.5
	_card.anchor_top = 0.5
	_card.anchor_bottom = 0.5
	_card.offset_left = -420
	_card.offset_right = 420
	_card.offset_top = -330
	_card.offset_bottom = 330
	add_child(_card)
	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 14)
	_card.add_child(_body)
	if _real():
		load("res://scripts/ui/quick_chat.gd").attach(self, _card, teammate)
	_intro()


func _clear() -> void:
	for c in _body.get_children():
		c.queue_free()
	_answers.clear()


func _header(step: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	_body.add_child(row)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 2)
	left.add_child(UI.eyebrow("Trivia night  ·  " + venue, UI.GOLD))
	left.add_child(UI.nowrap(UI.label("Team %s  ·  you & %s" % [_team, teammate.name], 15, UI.MUTED, 500)))
	row.add_child(left)
	_score_label = UI.nowrap(UI.label(step, 15, UI.CREAM, 600))
	row.add_child(_score_label)
	var rule := ColorRect.new()
	rule.color = UI.HAIRLINE
	rule.custom_minimum_size.y = 1
	_body.add_child(rule)


func _teammate_row(text: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	_body.add_child(row)
	row.add_child(Portrait.make(teammate.cfg, 56, UI.GOLD))
	var bubble := PanelContainer.new()
	bubble.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bubble.add_theme_stylebox_override("panel", UI.box(Color(1, 1, 1, 0.06), 16, Color(0, 0, 0, 0), 0, 16, 12))
	row.add_child(bubble)
	_bubble = UI.label(text, 16, UI.CREAM)
	bubble.add_child(_bubble)


func _intro() -> void:
	_clear()
	_header("")
	_body.add_child(UI.gap(10))
	_body.add_child(UI.title("Trivia night is starting.", 40))
	if teammate.get("host", false):
		_body.add_child(UI.label("Nobody else is in tonight yet, so %s, the quizmaster, will play on your team." % teammate.name, 17, UI.MUTED))
	else:
		_body.add_child(UI.label("Tables are pairing up. %s is on their own and waves you over." % teammate.name, 17, UI.MUTED))
	_body.add_child(UI.gap(6))
	if _real():
		_teammate_row("You and @%s are a team. You'll each see what the other picks. Talk it through on a call!" % teammate.handle)
	else:
		_teammate_row("Hi! I'm %s. Want to be a team? I'll warn you, I %s." % [teammate.name, People.TRAITS[teammate.traits[0]].fact])
	_body.add_child(UI.gap(4))
	_body.add_child(UI.label("%d rounds. Some are trivia. Some are about you two, and have no wrong answers." % ROUNDS, 15, UI.FAINT))
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.add_child(spacer)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	_body.add_child(row)
	var no := UI.button("Maybe another time")
	no.custom_minimum_size.y = 52
	no.pressed.connect(_close)
	row.add_child(no)
	var yes := UI.button("Team up with %s" % teammate.name, "PrimaryButton")
	yes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	yes.custom_minimum_size.y = 52
	yes.pressed.connect(_show_round)
	row.add_child(yes)


func _show_round() -> void:
	_clear()
	var kind: String = _plan[_round][0]
	var q: Array = _plan[_round][1]
	_header("Round %d of %d   ·   %d pts" % [_round + 1, ROUNDS, _score])
	if kind == "team":
		_body.add_child(UI.eyebrow("Team round  ·  no wrong answers", UI.ROSE))
	var question := UI.title(q[0], 30)
	_body.add_child(question)

	var options: Array = q[1].duplicate()
	var correct: String = options[0]
	for i in range(options.size() - 1, 0, -1):
		var j := _rng.randi() % (i + 1)
		var tmp = options[i]
		options[i] = options[j]
		options[j] = tmp
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	_body.add_child(grid)
	for i in options.size():
		var b := UI.button(options[i], "Chip")
		b.custom_minimum_size = Vector2(380, 58)
		b.add_theme_font_size_override("font_size", 16)
		b.pressed.connect(_answer.bind(options[i], correct, kind, q))
		grid.add_child(b)
		_answers.append(b)

	# What your teammate thinks, after a beat.
	if _real():
		_their_pick = -1
		_teammate_row("@%s is choosing too…" % teammate.handle)
	elif kind == "quiz":
		var knows := _rng.randf() < (0.85 if q[2] in teammate.cats else 0.55)
		var pick: String = correct if knows else options.filter(func(o) -> bool: return o != correct).pick_random()
		_their_pick = options.find(pick)
		var line := ""
		if q[2] in teammate.cats and knows:
			line = "Oh, this is my kind of question. It's %s." % pick
		elif knows:
			line = "I'm fairly sure it's %s." % pick
		else:
			line = "Maybe %s? Don't quote me on that." % pick
		_teammate_row("…")
		var round_at := _round
		get_tree().create_timer(1.1).timeout.connect(func() -> void:
			if is_instance_valid(_bubble) and _round == round_at and not _answers.is_empty() and not _answers[0].disabled:
				_bubble.text = line)
	else:
		_their_pick = _rng.randi() % options.size()
		_teammate_row("You go first. I'm curious.")
	_body.add_child(UI.gap(2))
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.add_child(spacer)
	_next_btn = UI.button("Next round" if _round < ROUNDS - 1 else "See the results", "PrimaryButton")
	_next_btn.custom_minimum_size.y = 52
	_next_btn.visible = false
	_next_btn.pressed.connect(func() -> void:
		_round += 1
		if _round >= ROUNDS:
			_results()
		else:
			_show_round())
	_body.add_child(_next_btn)


func _answer(choice: String, correct: String, kind: String, q: Array) -> void:
	for b in _answers:
		b.disabled = true
	if _real():
		var mine := -1
		for i in _answers.size():
			if _answers[i].text == choice:
				mine = i
		Net.send_play(teammate.handle, _round, mine)
		if not _their_rounds.has(_round):
			_pending = [choice, correct, kind, q, _round]
			_bubble.text = "Waiting for @%s to answer…" % teammate.handle
			return
	_reveal(choice, correct, kind, q)


func _reveal(choice: String, correct: String, kind: String, q: Array) -> void:
	if _real():
		_their_pick = clampi(int(_their_rounds.get(_round, 0)), 0, _answers.size() - 1)
	var theirs := _answers[_their_pick].text
	if kind == "quiz":
		var right := choice == correct
		if right:
			_score += 10
		for b in _answers:
			if b.text == correct:
				b.add_theme_stylebox_override("disabled", UI.box(Color(UI.SAGE, 0.3), 12, UI.SAGE, 1, 16, 9))
				b.add_theme_color_override("font_disabled_color", UI.CREAM)
			elif b.text == choice:
				b.add_theme_stylebox_override("disabled", UI.box(Color(UI.ROSE, 0.2), 12, UI.ROSE, 1, 16, 9))
				b.add_theme_color_override("font_disabled_color", UI.CREAM)
		if _real():
			_bubble.text = "@%s picked %s.%s" % [teammate.handle, theirs, "  You both got it!" if right and theirs == correct else ""]
		elif right and theirs == correct:
			_bubble.text = "Yes! Great minds."
		elif right:
			_bubble.text = "Okay, you were right and I was wrong. I'll remember this."
		elif theirs == correct:
			_bubble.text = "Ha, I knew it was %s. I'll let it slide. Once." % correct
		else:
			_bubble.text = "We were both confidently wrong. Honestly, iconic."
	else:
		_score += 5
		for b in _answers:
			if b.text == choice:
				b.add_theme_stylebox_override("disabled", UI.box(Color(UI.CREAM, 0.9), 12, Color(0, 0, 0, 0), 0, 16, 9))
				b.add_theme_color_override("font_disabled_color", UI.INK)
			elif b.text == theirs:
				b.add_theme_stylebox_override("disabled", UI.box(Color(UI.GOLD, 0.2), 12, UI.GOLD, 1, 16, 9))
				b.add_theme_color_override("font_disabled_color", UI.CREAM)
		if _real():
			if choice == theirs:
				_agreed += 1
			_bubble.text = "@%s picked %s.%s" % [teammate.handle, theirs.to_lower(), "  Same as you!" if choice == theirs else ""]
		elif choice == theirs:
			_agreed += 1
			_bubble.text = "Same! Okay, we're going to get along."
		else:
			_bubble.text = "Ooh. I'd have said %s. Tell me why later?" % theirs.to_lower()
		_learned.append((q[2] % theirs.to_lower()).capitalize().left(1) + (q[2] % theirs.to_lower()).substr(1))
	for r in _rivals:
		r[1] += [0, 5, 10, 10][_rng.randi() % 4]
	_score_label.text = "Round %d of %d   ·   %d pts" % [_round + 1, ROUNDS, _score]
	_next_btn.visible = true


func _results() -> void:
	completed.emit()
	_clear()
	var board := _rivals.duplicate()
	board.append(["Team " + _team, _score])
	board.sort_custom(func(a, b) -> bool: return a[1] > b[1])
	var place := 1
	for i in board.size():
		if board[i][1] == _score and board[i][0] == "Team " + _team:
			place = i + 1
	var places := ["first", "second", "third", "fourth"]
	_header("Final  ·  %d pts" % _score)
	_body.add_child(UI.title("You came %s." % places[place - 1], 40))
	var standings := VBoxContainer.new()
	standings.add_theme_constant_override("separation", 4)
	for row in board:
		var line := HBoxContainer.new()
		var n := UI.nowrap(UI.label(row[0], 15, UI.CREAM if row[0].begins_with("Team ") else UI.MUTED, 600 if row[0].begins_with("Team ") else 400))
		n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_child(n)
		line.add_child(UI.nowrap(UI.label("%d" % row[1], 15, UI.MUTED)))
		standings.add_child(line)
	_body.add_child(standings)

	var facts := []
	for f in teammate.facts:
		facts.append(f.left(1).to_upper() + f.substr(1))
	if not teammate.get("traits", []).is_empty():
		facts.append(People.TRAITS[teammate.traits[0]].fact.left(1).to_upper() + People.TRAITS[teammate.traits[0]].fact.substr(1))
	facts.append_array(_learned)
	if not teammate.get("host", false):
		Profile.learn(teammate.id, facts)
		_body.add_child(UI.gap(4))
		_body.add_child(UI.eyebrow("What you noticed about %s" % teammate.name, UI.GOLD))
		for f in facts.slice(0, 4):
			_body.add_child(UI.label("·  " + f, 15, UI.CREAM))
	if _real():
		_teammate_row("You agreed on %d of the team rounds with @%s." % [_agreed, teammate.handle])
	else:
		var line := "We make a good team." if _agreed >= 1 else "We disagreed on everything and I loved it."
		_teammate_row(line + " " + People.TRAITS[teammate.traits[1]].voice)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.add_child(spacer)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	_body.add_child(row)
	var back := UI.button("Back to the bar")
	back.custom_minimum_size.y = 52
	back.pressed.connect(_close)
	row.add_child(back)
	if teammate.get("host", false):
		return
	var view := UI.button("See %s's profile" % teammate.name, "PrimaryButton")
	view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	view.custom_minimum_size.y = 52
	view.pressed.connect(func() -> void:
		profile_requested.emit(teammate)
		queue_free())
	row.add_child(view)


func _close() -> void:
	closed.emit()
	queue_free()
