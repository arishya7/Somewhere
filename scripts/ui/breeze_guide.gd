extends Control
## Talk to the Breeze: your fairy godmother of a guide. She explains how things work and
## suggests places, but she never picks people for you. That part is yours.

const UI = preload("res://scripts/ui.gd")
const Places = preload("res://scripts/places.gd")

const QUICK := [
	"How does Somewhere work?", "Where should I go?", "How do matches work?", "What are quests?",
	"What can I do inside places?", "How do strikes work?", "Who can see my info?", "Can my friends join?",
]

var _host: Control
var _log: VBoxContainer
var _scroll: ScrollContainer
var _input: LineEdit


static func open(host: Control) -> Control:
	for c in host.get_children():
		if c.get_script() == load("res://scripts/ui/breeze_guide.gd"):
			return c
	var g = load("res://scripts/ui/breeze_guide.gd").new()
	g._host = host
	host.add_child(g)
	return g


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var scrim := UI.scrim(self)
	scrim.color.a = 0.0
	scrim.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed:
			_close())
	var card := PanelContainer.new()
	card.theme_type_variation = "Card"
	card.anchor_left = 1.0
	card.anchor_right = 1.0
	card.anchor_bottom = 1.0
	card.offset_left = -500
	card.offset_right = -24
	card.offset_top = 24
	card.offset_bottom = -24
	add_child(card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	card.add_child(v)
	var head := HBoxContainer.new()
	v.add_child(head)
	var titles := VBoxContainer.new()
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titles.add_child(UI.eyebrow("Your guide", UI.GOLD))
	titles.add_child(UI.title("The Breeze", 34))
	head.add_child(titles)
	var close := UI.button("×", "TextButton")
	close.pressed.connect(_close)
	head.add_child(close)
	v.add_child(UI.label("I only answer questions about Somewhere. I suggest places, never people. Who you meet is up to you.", 13, UI.FAINT))
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(_scroll)
	_log = VBoxContainer.new()
	_log.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_log.add_theme_constant_override("separation", 10)
	_scroll.add_child(_log)
	var chips := HFlowContainer.new()
	chips.add_theme_constant_override("h_separation", 6)
	chips.add_theme_constant_override("v_separation", 6)
	v.add_child(chips)
	for q in QUICK:
		var b := UI.button(q, "Chip")
		b.add_theme_font_size_override("font_size", 13)
		b.pressed.connect(_ask.bind(q))
		chips.add_child(b)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	v.add_child(row)
	_input = LineEdit.new()
	_input.placeholder_text = "Ask the Breeze..."
	_input.max_length = 200
	_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_input.add_theme_font_size_override("font_size", 16)
	_input.text_submitted.connect(func(t: String) -> void:
		_input.text = ""
		_ask(t))
	row.add_child(_input)
	_say("Hello, %s. The air's warm tonight. What would you like to know?" % Profile.data.name)
	card.modulate.a = 0.0
	create_tween().tween_property(card, "modulate:a", 1.0, 0.3)


func _close() -> void:
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.2)
	tw.tween_callback(queue_free)


func _bubble(text: String, mine: bool) -> Label:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END if mine else BoxContainer.ALIGNMENT_BEGIN
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UI.box(UI.CREAM if mine else Color(1, 1, 1, 0.06), 16, Color(0, 0, 0, 0), 0, 14, 10))
	var l := UI.label(text, 15 if mine else 17, UI.INK if mine else UI.CREAM)
	if not mine:
		l.add_theme_font_override("font", UI.serif(400, true))
	l.custom_minimum_size.x = mini(380, int(UI.font().get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x) + 8)
	p.add_child(l)
	row.add_child(p)
	_log.add_child(row)
	_scroll_end()
	return l


func _say(text: String) -> void:
	_bubble(text, false)


func _scroll_end() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	if is_instance_valid(_scroll):
		_scroll.scroll_vertical = int(_scroll.get_v_scroll_bar().max_value)


func _ask(q: String) -> void:
	q = q.strip_edges()
	if q == "":
		return
	_bubble(q, true)
	await get_tree().create_timer(0.5).timeout
	if not is_inside_tree():
		return
	var t := q.to_lower()
	var words := t.replace("?", " ").replace(",", " ").replace(".", " ").replace("!", " ").replace("'", "").split(" ", false)
	# Someone having a hard time always gets a real, kind answer first, never a redirect.
	if _distress(t, words):
		_say("I'm really glad you said something. I'm only a guide inside an app, so I can't be the support you deserve right now, but people can.")
		_say("In Singapore you can call Samaritans of Singapore any time, day or night, on 1767. If you're in danger right now, call 995.")
		_say("The Shore is always here if you want somewhere quiet. Nothing in Somewhere expires, and nobody is waiting on you to perform. Be gentle with yourself.")
		return
	var want_type := _venue_wanted(t, words)
	if want_type != "":
		_suggest_venues(want_type)
		return
	if not _on_topic(t, words):
		_say("I can only help with Somewhere itself: how it works, where to go, strings and matches, activities, quests, calls, friends, safety and privacy.")
		_say("Ask me about one of those?")
		return
	if ("where" in words and ("go" in words or "should" in words or "tonight" in words)) or "recommend" in t or "suggest" in t:
		_suggest_places()
	elif "compatib" in t or "similar" in t or "in common" in t or "spotlight" in t or "glow" in t:
		_say("I don't match people, but I do light the way. On streets and inside places, anyone who shares your interests stands in a soft gold glow.")
		_say("Hover over them to see how many interests you have in common. Then do something together and see how it feels.")
	elif "quest" in t:
		_say("Quests are small adventures for two. Open a chat with a match and tap Plan a quest. Pick one, and if they accept, it shows up with steps to do together.")
		_say("Each step happens in the world: go somewhere, do something. Finish them all and the quest is complete.")
	elif "voice" in t or "call" in t or "talk" in words:
		_say("You can voice call anyone you've matched with who's playing right now. Open their chat and tap Call. They'll need to accept first.")
	elif "ghost" in t or "strike" in t or "remind" in t or "ban" in words or "banned" in words:
		_say("Ghosting hurts, so here's the deal. If someone messages you and you don't reply for 3 days, I'll remind you, up to 3 times.")
		_say("After 3 reminders with no reply, that's a strike. 3 strikes and your account is closed. Not feeling it? Use Close kindly in the chat. That never counts as ghosting.")
	elif "match" in t or "string" in t or "follow" in words or "like" in words:
		_say("When someone catches your eye, tap them and choose Follow the string. If they follow it back, you match and can talk.")
		_say("If they don't, nothing happens and nobody is told. Strings stay tied; fate is patient. And I never pick people for you.")
	elif "inside" in t or "activit" in t or "shop" in t or "venue" in t or "do" in words:
		_say("Every door has something to do. Bars run trivia nights. Cafés have shared tables with a conversation card. Restaurants host supper clubs.")
		_say("Thrift stores let you try things on (and keep them). Galleries ask what a piece makes you feel. Record stores have listening stations, arcades have air hockey, clubs have a dance floor, and studios have a slow breathing class.")
	elif "see" in words or "privacy" in t or "info" in words or "data" in words or "safe" in t:
		_say("Other people see your name, handle, age, photos, interests and prompt. Never your phone number, email or birthday. Those stay on this device.")
		_say("You choose when to follow a string, and nobody is ever told if you didn't.")
	elif "friend" in t or "join" in words or "host" in words or "together" in words:
		_say("Yes! Open Play with friends on the welcome screen. One of you hosts, the others connect, and you'll see each other walking the same streets.")
	elif "shy" in words or "nervous" in words or "anxious" in words:
		_say("Then start small. Trivia is easy: you're on a team, and the questions do the talking. A café's shared table works too.")
		_say("And there's no rush. Nothing expires here.")
	elif "interest" in t:
		_say("You can pick up to 10 interests from the list. Places on the map glow gold when they match them, and teal when people are there right now.")
	else:
		_say("You wander Singapore. Places glow gold when they match your interests, and teal when people are there right now.")
		_say("Walk the streets, go through doors, do things with whoever's there. When you're curious about someone, tap them. That's it. That's the magic.")


const DISTRESS := ["depressed", "depression", "suicid", "kill myself", "end my life", "want to die", "self harm", "self-harm",
	"hurt myself", "hopeless", "cant go on", "can't go on", "no reason to live", "worthless", "panic attack"]
const CRAVINGS := {
	"restaurant": ["burger", "food", "eat", "dinner", "lunch", "supper", "noodle", "hungry", "chicken rice", "laksa", "pizza", "restaurant"],
	"cafe": ["coffee", "kopi", "brunch", "breakfast", "cake", "matcha", "bakery", "pastry", "croissant", "tea"],
	"bar": ["drink", "beer", "cocktail", "wine", "pub", "quiz", "trivia"],
	"bookstore": ["book", "read"],
	"records": ["vinyl", "record"],
	"thrift": ["thrift", "clothes", "vintage", "outfit"],
	"arcade": ["arcade", "air hockey", "board game"],
	"club": ["dance", "dancing", "party", "club"],
	"gallery": ["art", "gallery", "exhibition"],
	"studio": ["yoga", "climb", "workout", "breathe"],
}


func _distress(t: String, _words: PackedStringArray) -> bool:
	for d in DISTRESS:
		if d in t:
			return true
	return false


## "Where can I find a good burger?" points to places inside Somewhere that fit.
func _venue_wanted(t: String, words: PackedStringArray) -> String:
	if not ("where" in words or "find" in words or "get" in words or "recommend" in t or "good" in words or "best" in words):
		return ""
	for vt in CRAVINGS:
		for w in CRAVINGS[vt]:
			if (" " in w and w in t) or w in words or (w + "s") in words:
				return vt
	return ""


func _suggest_venues(vt: String) -> void:
	var mine := Profile.categories()
	var found := []
	for h in Places.HOTSPOTS:
		for i in h.venues.size():
			if h.venues[i][1] == vt:
				var n := 0
				for c in h.cats:
					if c in mine:
						n += 1
				found.append([n + randf() * 0.5, h, i])
	found.sort_custom(func(a, b) -> bool: return a[0] > b[0])
	if found.is_empty():
		_say("I don't know a spot like that in Somewhere yet. Try the map's filters?")
		return
	_say("Inside Somewhere, here's where I'd go for that. (These are places in the game, not real-world reviews.)")
	for item in found.slice(0, 3):
		var h: Dictionary = item[1]
		var i: int = item[2]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var text := VBoxContainer.new()
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text.add_child(UI.label(h.venues[i][0], 16, UI.CREAM, 500))
		text.add_child(UI.label("%s  ·  %s" % [h.name, Places.VENUE_MOOD.get(vt, "")], 13, UI.MUTED))
		row.add_child(text)
		var go := UI.button("Go", "PrimaryButton")
		go.custom_minimum_size = Vector2(70, 40)
		go.pressed.connect(func() -> void: _host.get_parent().go("district", {"place": h.name, "at": i}))
		row.add_child(go)
		_log.add_child(row)
	_scroll_end()


## Only questions about Somewhere get an answer. Everything else gets a gentle redirect.
func _on_topic(t: String, words: PackedStringArray) -> bool:
	const STEMS := ["somewhere", "breeze", "string", "match", "map", "place", "shop", "venue", "trivia", "activit", "quest",
		"chat", "message", "voice", "call", "profile", "avatar", "photo", "handle", "interest", "privacy", "friend",
		"strike", "ghost", "remind", "shore", "street", "door", "dock", "app", "game", "café", "cafe", "bar", "arcade",
		"thrift", "gallery", "club", "studio", "restaurant", "bookshop", "record", "account", "safe", "compatib", "similar", "in common"]
	const WORDS := ["go", "tonight", "follow", "like", "meet", "people", "join", "host", "together", "shy", "nervous",
		"anxious", "inside", "see", "info", "data", "ban", "banned", "work", "works"]
	# "...in Paris" and the like: places outside the game are out of scope.
	var at := words.find("in")
	if at >= 0 and at + 1 < words.size():
		var nxt: String = words[at + 1]
		var known := ["singapore", "somewhere", "the", "a", "an", "my", "this", "here", "app", "game", "chat", "places", "town"]
		for h in Places.HOTSPOTS:
			known.append_array(h.name.to_lower().split(" "))
		if not nxt in known:
			return false
	for stem in STEMS:
		if stem in t:
			return true
	var hits := 0
	for w in words:
		if w in WORDS:
			hits += 1
	# Generic words alone ("how does this work") count; a stray "go" in an unrelated question doesn't.
	return hits >= 2 or (words.size() <= 5 and hits >= 1)


func _suggest_places() -> void:
	var mine := Profile.categories()
	var scored := []
	for h in Places.HOTSPOTS:
		var n := 0
		for c in h.cats:
			if c in mine:
				n += 1
		scored.append([n + randf() * 0.5, h])
	scored.sort_custom(func(a, b) -> bool: return a[0] > b[0])
	_say("Here's where the air feels warm for you tonight:")
	for item in scored.slice(0, 3):
		var h: Dictionary = item[1]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var text := VBoxContainer.new()
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text.add_child(UI.label(h.name, 16, UI.CREAM, 500))
		text.add_child(UI.label(h.blurb, 13, UI.MUTED))
		row.add_child(text)
		var go := UI.button("Go", "PrimaryButton")
		go.custom_minimum_size = Vector2(70, 40)
		go.pressed.connect(func() -> void: _host.get_parent().go("district", {"place": h.name}))
		row.add_child(go)
		_log.add_child(row)
	_scroll_end()
