extends Node

## Emitted when someone you followed follows your string back.
signal string_returned(person: Dictionary)
## Emitted whenever a quest is proposed, accepted or moves forward.
signal quests_changed
## Emitted when a Close kindly is started, undone, or goes through.
signal closed_changed(person_id: String)
## The player's profile: onboarding answers, photos and avatar. Saved on this device.

const Avatar = preload("res://scripts/avatar.gd")
const Validate = preload("res://scripts/validate.gd")
const Quests = preload("res://scripts/quests.gd")
const PROMPT_TEXT := [
	"My order at a kopitiam says a lot about me:", "The street I'd walk you down first:",
	"A small thing that makes my whole day:", "If we got stuck in the rain together, I'd...",
	"I'll always say yes to...", "Something I'm quietly proud of:",
	"The song playing in my head right now:", "A green flag I look for:",
	"You'll find me at the Shore when...", "Ask me about...",
]
const MAX_PHOTOS := 6

const CATEGORIES := {
	"art": {"label": "Art", "color": Color("#FF7AA2")},
	"music": {"label": "Music", "color": Color("#A78BFA")},
	"food": {"label": "Food", "color": Color("#FFB454")},
	"sports": {"label": "Sports", "color": Color("#4FD1A5")},
	"outdoors": {"label": "Outdoors", "color": Color("#8BD36F")},
	"nightlife": {"label": "Nightlife", "color": Color("#F472B6")},
	"culture": {"label": "Books & film", "color": Color("#93C5FD")},
	"gaming": {"label": "Games & tech", "color": Color("#60A5FA")},
	"wellness": {"label": "Wellness", "color": Color("#5EEAD4")},
}

const INTEREST_GROUPS := [
	{"title": "Creative", "cat": "art", "items": ["Art", "Photography", "Design", "Writing", "Crafts", "Fashion", "Painting", "Pottery", "Illustration", "Film photography", "Interior design", "Tattoos", "Street art", "Calligraphy"]},
	{"title": "Music", "cat": "music", "items": ["Live music", "Concerts", "Singing", "Playing an instrument", "DJing", "Jazz", "Indie", "Hip hop", "K-pop", "Classical", "Electronic", "R&B", "Vinyl", "Musicals", "Songwriting"]},
	{"title": "Food & drink", "cat": "food", "items": ["Cooking", "Coffee", "Brunch", "Baking", "Wine", "Trying new restaurants", "Street food", "Tea", "Vegan food", "Spicy food", "Craft beer", "Cocktail making", "Dessert", "Fine dining", "Farmers' markets"]},
	{"title": "Sports & fitness", "cat": "sports", "items": ["Running", "Gym", "Football", "Basketball", "Tennis", "Climbing", "Swimming", "Cycling", "Badminton", "Boxing", "Volleyball", "Surfing", "Skateboarding", "Martial arts", "Pickleball", "Dance fitness"]},
	{"title": "Outdoors & travel", "cat": "outdoors", "items": ["Hiking", "Beaches", "Camping", "Travel", "Road trips", "Nature walks", "Birdwatching", "Gardening", "Kayaking", "Scuba diving", "Stargazing", "Backpacking", "Sunsets", "Dogs", "Cats"]},
	{"title": "Going out", "cat": "nightlife", "items": ["Dancing", "Cocktails", "Comedy", "Festivals", "Karaoke", "Rooftop bars", "Clubbing", "Pub quizzes", "Speakeasies", "Late-night food", "Live DJs", "Bar hopping"]},
	{"title": "Books & film", "cat": "culture", "items": ["Reading", "Films", "Museums", "Theatre", "Podcasts", "Poetry", "History", "Philosophy", "Languages", "Documentaries", "Sci-fi", "Fantasy", "True crime", "Anime films", "Book clubs"]},
	{"title": "Games & tech", "cat": "gaming", "items": ["Video games", "Board games", "Tech", "Anime", "Puzzles", "Chess", "Coding", "Esports", "Tabletop RPGs", "Retro games", "VR", "AI", "Startups", "Gadgets"]},
	{"title": "Wellness", "cat": "wellness", "items": ["Yoga", "Meditation", "Pilates", "Self-care", "Journaling", "Mental health", "Spa days", "Breathwork", "Sleep (seriously)", "Healthy cooking", "Therapy-positive", "Slow mornings"]},
]

var data := {}
## Run with  -- --profile=name  to keep a separate player on the same computer (handy for testing with friends).
## Ghosting rules: a reminder after 3 days without replying, then one a day. Three reminders
## make a strike; three strikes close the account. "Close kindly" never counts.
## Run with  -- --ghost-day=60  to make a "day" last 60 seconds for testing.
const REMINDERS_PER_STRIKE := 3
const STRIKES_TO_BAN := 3
var DAY := 86400.0
## Run with  -- --instant-match  for user testing: everyone follows back within a couple of seconds.
var INSTANT_MATCH := false
## Real people only by default. Run with  -- --demo-people  to bring back simulated people (for solo demos).
var DEMO_PEOPLE := false
var SAVE_PATH := "user://profile.json"
var PHOTO_DIR := "user://photos"
var photos: Array[Texture2D] = []


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg == "--instant-match":
			INSTANT_MATCH = true
		if arg == "--demo-people":
			DEMO_PEOPLE = true
		if arg.begins_with("--ghost-day="):
			DAY = maxf(5.0, float(arg.trim_prefix("--ghost-day=")))
		if arg.begins_with("--profile="):
			var n := arg.trim_prefix("--profile=").validate_filename()
			SAVE_PATH = "user://profile_%s.json" % n
			PHOTO_DIR = "user://photos_%s" % n
	reset()
	load_saved()
	_resume_following.call_deferred()


func reset() -> void:
	data = {
		"name": "", "handle": "", "dial": "+65", "dial_index": 0, "phone": "", "phone_verified": false,
		"email": "", "email_verified": false, "birthday": {"d": "", "m": "", "y": ""},
		"gender": "", "gender_custom": "", "pronouns": [], "show_me": [], "orientation": "", "show_flag": true, "intent": "",
		"interests": [], "prompt_q": 0, "prompt_a": "", "photos": [],
		"avatar": Avatar.default_config(), "onboarded": false, "seen_intro": false,
		"matches": {}, "learned": {}, "following": {}, "quests": [], "strikes": 0, "banned": false,
	}
	photos.clear()


# --- Matches and chats --------------------------------------------------------

func learn(person_id: String, facts: Array) -> void:
	var known: Array = data.learned.get(person_id, [])
	for f in facts:
		if not f in known:
			known.append(f)
	data.learned[person_id] = known
	save()
	if data.get("following", {}).get(person_id, {}).get("decision", "") == "no":
		_decide(person_id)


## You follow someone's string. Simulated people decide after a little while, more likely
## if you've spent time together. Real players decide for themselves (see net.gd).
func follow(person: Dictionary, where: String) -> void:
	if not data.has("following"):
		data.following = {}
	data.following[person.id] = {"person": person, "where": where, "at": Time.get_unix_time_from_system(), "tries": 0}
	save()
	if person.get("real", false):
		get_node("/root/Net").follow(person.handle)
		return
	_decide(person.id)


## Will a simulated person follow your string back? Strangers rarely do; people you've spent
## time with (trivia, a shared table, a game) often do. They take a few minutes to decide, and a
## "not yet" only gets reconsidered after you do something together.
func _decide(person_id: String) -> void:
	var f: Dictionary = data.get("following", {}).get(person_id, {})
	if f.is_empty() or data.matches.has(person_id) or f.get("decision", "") == "yes":
		return
	var person: Dictionary = f.person
	var shared := 0
	for c in person.get("cats", []):
		if c in categories():
			shared += 1
	var together: bool = data.learned.has(person_id)
	var chance := clampf(0.15 + 0.1 * shared + (0.45 if together else 0.0), 0.0, 0.9)
	if INSTANT_MATCH:
		chance = 1.0
	var tries := int(f.get("tries", 0))
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(person_id + str(data.get("handle", "")) + str(tries))
	f.tries = tries + 1
	if rng.randf() > chance:
		f.decision = "no"
		save()
		return
	f.decision = "yes"
	f.due = Time.get_unix_time_from_system() + (rng.randf_range(1.5, 3.0) if INSTANT_MATCH else rng.randf_range(60.0, 240.0))
	save()
	_wait_and_match(person_id)


func _wait_and_match(person_id: String) -> void:
	var f: Dictionary = data.get("following", {}).get(person_id, {})
	if f.is_empty():
		return
	var wait := maxf(1.0, float(f.get("due", 0.0)) - Time.get_unix_time_from_system())
	await get_tree().create_timer(wait).timeout
	f = data.get("following", {}).get(person_id, {})
	if f.is_empty() or data.matches.has(person_id):
		return
	var person: Dictionary = f.person
	var where: String = f.where
	add_match(person, where)
	var opener := "Hey! I saw you at %s. Following your string back :)" % where if where != "" else "Hey! Following your string back."
	if data.learned.has(person_id):
		opener = "Okay, that was fun. Same team next time? (Hi, I'm %s.)" % person.name
	add_message(person_id, false, opener)
	data.following.erase(person_id)
	save()
	string_returned.emit(person)


func add_match(person: Dictionary, where: String) -> void:
	if data.matches.has(person.id):
		return
	data.matches[person.id] = {"person": person, "where": where, "messages": [], "unread": 0, "at": Time.get_unix_time_from_system()}
	save()


func add_message(person_id: String, from_me: bool, text: String, extra := {}) -> void:
	var m: Dictionary = data.matches[person_id]
	if from_me:
		m.reminders = 0 # Replying clears any reminders for this conversation.
	var msg := {"me": from_me, "text": text, "at": Time.get_unix_time_from_system()}
	msg.merge(extra)
	m.messages.append(msg)
	if not from_me:
		m.unread = int(m.unread) + 1
	save()


# --- Quests ---------------------------------------------------------------------

func _toast(text: String) -> void:
	var app := get_tree().root.get_node_or_null("App")
	if app:
		app.toast(text)


func quest(qid: String) -> Dictionary:
	for q in data.get("quests", []):
		if q.qid == qid:
			return q
	return {}


## Your partner for an active quest happening at this place, if any.
func quest_partner(place: String, _venue_type := "") -> Dictionary:
	for q in data.get("quests", []):
		if q.status != "active" or q.place != place or not data.matches.has(q.with):
			continue
		# Real people move on their own; only simulated partners walk with you.
		if str(q.with).begins_with("net:"):
			continue
		# They stay with you anywhere on that street, even if you wander into the wrong door.
		return data.matches[q.with].person
	return {}


## The handle of a real match you have an active quest with (at this place, or anywhere if place is "").
func real_quest_partner(place := "") -> String:
	for q in data.get("quests", []):
		if q.status == "active" and str(q.with).begins_with("net:") and (place == "" or q.place == place):
			return str(q.with).substr(4)
	return ""


## The active quest happening on this street, if any.
func quest_here(place: String) -> Dictionary:
	for q in data.get("quests", []):
		if q.status == "active" and q.place == place:
			return q
	return {}


func quests_with(person_id: String) -> Array:
	return data.get("quests", []).filter(func(q) -> bool: return q.with == person_id)


func propose_quest(person: Dictionary, template_id: String) -> void:
	var q := Quests.instance(Quests.find(template_id), person.id, true)
	data.quests.append(q)
	add_message(person.id, true, "Quest idea: %s" % q.title, {"quest": q.qid})
	quests_changed.emit()
	if person.get("real", false):
		get_node("/root/Net").send_quest(person.handle, q)
		return
	# Simulated people say yes, after a moment to think about it.
	await get_tree().create_timer(randf_range(2.0, 4.0)).timeout
	accept_quest(q.qid)
	add_message(person.id, false, ["I'm in! See you at %s.", "Yes. Absolutely yes. %s it is.", "Okay this is a great idea. Meet you outside %s?"][randi() % 3] % Quests.venue_of(q)[0])
	quests_changed.emit()


## A quest someone real proposed to you.
func receive_quest(person_id: String, template_id: String, qid: String) -> void:
	if not quest(qid).is_empty():
		return
	var q := Quests.instance(Quests.find(template_id), person_id, false)
	q.qid = qid
	data.quests.append(q)
	add_message(person_id, false, "Quest idea: %s" % q.title, {"quest": qid})
	quests_changed.emit()


func accept_quest(qid: String, tell_partner := false) -> void:
	var q := quest(qid)
	if q.is_empty() or q.status != "proposed":
		return
	q.status = "active"
	save()
	var where: Array = Quests.venue_of(q)
	_toast("Quest accepted: %s. Meet at %s, %s. Tap Go there now in the chat." % [q.title, where[0], q.place])
	if tell_partner and q.with.begins_with("net:"):
		get_node("/root/Net").send_quest_reply(q.with.trim_prefix("net:"), qid, true)
	quests_changed.emit()


func decline_quest(qid: String, tell_partner := false) -> void:
	var q := quest(qid)
	if q.is_empty():
		return
	q.status = "declined"
	save()
	if tell_partner and q.with.begins_with("net:"):
		get_node("/root/Net").send_quest_reply(q.with.trim_prefix("net:"), qid, false)
	quests_changed.emit()


## Called by the world as you play. Moves the next step of any matching quest forward.
func quest_event(kind: String, place: String, venue_type := "") -> void:
	for q in data.get("quests", []):
		if q.status != "active" or q.place != place:
			continue
		for st in q.steps:
			if st.done:
				continue
			if st.kind == kind and (st.type == "" or st.type == venue_type):
				st.done = true
				_toast("Quest  ✓  %s" % st.text)
				if Quests.progress(q) == q.steps.size():
					q.status = "done"
					_toast("Quest complete: %s!" % q.title)
					if data.matches.has(q.with):
						add_message(q.with, false, "We did it! \"%s\" complete. Same time next week?" % q.title)
			break
	save()
	quests_changed.emit()


# --- Ghosting -------------------------------------------------------------------

## End a conversation gracefully: a kind closing note, and it never counts as ghosting.
const CLOSE_KINDLY_TEXT := "Hey, I've really enjoyed talking, but I don't think we're quite the right fit. I'm closing this kindly. Wishing you the best out there."
const UNDO_SECONDS := 8.0
var _pending_close := {}


## Close kindly with a short grace period, so a mis-tap can be undone before anything is sent.
func request_close_kindly(person_id: String) -> void:
	var token := randi()
	_pending_close[person_id] = token
	var app := get_tree().root.get_node_or_null("App")
	if app:
		var who: String = data.matches.get(person_id, {}).get("person", {}).get("name", "them")
		app.toast("Closing your conversation with %s in a few seconds." % who, "Undo", func() -> void: undo_close_kindly(person_id))
	await get_tree().create_timer(UNDO_SECONDS).timeout
	if _pending_close.get(person_id, -1) == token:
		_pending_close.erase(person_id)
		close_kindly(person_id)
		closed_changed.emit(person_id)


func undo_close_kindly(person_id: String) -> void:
	_pending_close.erase(person_id)
	closed_changed.emit(person_id)


func is_closing(person_id: String) -> bool:
	return _pending_close.has(person_id)


func close_kindly(person_id: String) -> void:
	var m: Dictionary = data.matches.get(person_id, {})
	if m.is_empty():
		return
	add_message(person_id, true, CLOSE_KINDLY_TEXT)
	m.closed = true
	m.closed_by = "me"
	save()
	# Real people: actually send the goodbye, then end the connection on the server so nothing else gets through.
	if person_id.begins_with("net:"):
		var handle := person_id.substr(4)
		Net.send_chat(handle, CLOSE_KINDLY_TEXT)
		Net.send_unmatch(handle)


## The other person closed the conversation with you.
func closed_by_them(person_id: String) -> void:
	var m: Dictionary = data.matches.get(person_id, {})
	if m.is_empty() or m.get("closed", false):
		return
	m.closed = true
	m.closed_by = "them"
	save()
	closed_changed.emit(person_id)


## Checks every conversation. Returns events for the app to show:
## ["reminder", person, n] / ["strike", n] / ["banned"].
func check_ghosting() -> Array:
	var events := []
	if data.get("banned", false) or not has_profile():
		return events
	var now := Time.get_unix_time_from_system()
	for id in data.matches:
		var m: Dictionary = data.matches[id]
		if m.get("closed", false) or m.messages.is_empty():
			continue
		var last: Dictionary = m.messages[-1]
		if last.me:
			continue
		var waited := now - maxf(float(last.at), float(m.get("ghost_from", 0.0)))
		var due := int(m.get("reminders", 0))
		# Reminder n is due after 3 days, then one more each day after that.
		if due < REMINDERS_PER_STRIKE and waited >= DAY * (3 + due):
			m.reminders = due + 1
			events.append(["reminder", m.person, m.reminders])
		elif due >= REMINDERS_PER_STRIKE and waited >= DAY * (3 + REMINDERS_PER_STRIKE):
			data.strikes = int(data.get("strikes", 0)) + 1
			m.reminders = 0
			m.ghost_from = now
			events.append(["strike", data.strikes])
			if data.strikes >= STRIKES_TO_BAN:
				data.banned = true
				events.append(["banned"])
				break
	if not events.is_empty():
		save()
	return events


func unread_total() -> int:
	var n := 0
	for id in data.matches:
		n += int(data.matches[id].unread)
	return n


func has_profile() -> bool:
	return data.get("onboarded", false) and data.get("name", "") != ""


static func category_of(interest: String) -> String:
	for g in INTEREST_GROUPS:
		if interest in g.items:
			return g.cat
	return ""


## The map categories that light up for you, most-picked first.
func categories() -> Array:
	var counts := {}
	for i in data.interests:
		var c := category_of(i)
		if c != "":
			counts[c] = counts.get(c, 0) + 1
	var cats := counts.keys()
	cats.sort_custom(func(a, b): return counts[a] > counts[b])
	return cats


func age() -> int:
	var b: Dictionary = data.birthday
	if not (str(b.d).is_valid_int() and str(b.m).is_valid_int() and str(b.y).is_valid_int()) or str(b.y).length() != 4:
		return -1
	return Validate.age(int(b.d), int(b.m), int(b.y))


## The only fields other people ever see. Phone, email and birthday never leave this device.
func public_profile() -> Dictionary:
	return {
		"handle": data.get("handle", ""), "name": data.name, "age": age(), "pronouns": ", ".join(data.pronouns),
		"gender": data.gender if data.gender != "I'd rather describe it" else data.gender_custom,
		"intent": data.intent, "interests": data.interests, "cats": categories(), "avatar": data.avatar,
		"orientation": data.get("orientation", "") if data.get("show_flag", true) else "",
		"show_me": data.get("show_me", []), "gender_group": gender_group(),
		"prompts": [[PROMPT_TEXT[int(data.prompt_q)], data.prompt_a]] if data.prompt_a != "" else [],
	}


func add_photo(path: String) -> bool:
	if photos.size() >= MAX_PHOTOS:
		return false
	var img := Image.load_from_file(path)
	if img == null or img.is_empty():
		return false
	return _add_photo_image(img)


## A photo picked in the browser arrives as raw file bytes.
func add_photo_bytes(bytes: PackedByteArray, mime: String) -> bool:
	if photos.size() >= MAX_PHOTOS or bytes.size() > 15_000_000:
		return false
	var img := Image.new()
	var err := ERR_FILE_UNRECOGNIZED
	if "png" in mime:
		err = img.load_png_from_buffer(bytes)
	elif "webp" in mime:
		err = img.load_webp_from_buffer(bytes)
	else:
		err = img.load_jpg_from_buffer(bytes)
	if err != OK or img.is_empty():
		return false
	return _add_photo_image(img)


func _add_photo_image(img: Image) -> bool:
	var longest := maxi(img.get_width(), img.get_height())
	if longest > 1080:
		var k := 1080.0 / longest
		img.resize(int(img.get_width() * k), int(img.get_height() * k), Image.INTERPOLATE_LANCZOS)
	DirAccess.make_dir_recursive_absolute(PHOTO_DIR)
	var out := "%s/photo_%d.jpg" % [PHOTO_DIR, Time.get_ticks_usec()]
	img.save_jpg(out, 0.88)
	data.photos.append(out)
	photos.append(ImageTexture.create_from_image(img))
	save()
	return true


## Delete everything about you on this device: profile, photos, matches, messages. Can't be undone.
func delete_everything() -> void:
	# Tell real matches the connection is over, so the server stops passing anything between you.
	for id in data.get("matches", {}).keys():
		if str(id).begins_with("net:"):
			Net.send_unmatch(str(id).substr(4))
	for path in data.get("photos", []):
		DirAccess.remove_absolute(path)
	DirAccess.remove_absolute(PHOTO_DIR)
	DirAccess.remove_absolute(SAVE_PATH)
	reset()
	Net.leave_client()


func remove_photo(i: int) -> void:
	if i < 0 or i >= photos.size():
		return
	DirAccess.remove_absolute(data.photos[i])
	data.photos.remove_at(i)
	photos.remove_at(i)
	save()


func save() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data, "\t"))


func load_saved() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	for k in parsed:
		data[k] = parsed[k]
	# JSON stores every number as a float; the avatar wants ints.
	var cfg := Avatar.default_config()
	for k in data.avatar:
		cfg[k] = int(data.avatar[k])
	data.avatar = cfg
	photos.clear()
	var kept := []
	for p in data.photos:
		var img := Image.load_from_file(p)
		if img and not img.is_empty():
			photos.append(ImageTexture.create_from_image(img))
			kept.append(p)
	data.photos = kept


func _resume_following() -> void:
	await get_tree().create_timer(2.0).timeout
	for id in data.get("following", {}).keys():
		if data.following[id].get("decision", "") == "yes":
			_wait_and_match(id)


## A filled-in profile, so any screen can be opened directly while developing.
## Which "who would you like to meet" group you belong to.
func gender_group() -> String:
	match data.get("gender", ""):
		"Woman": return "Women"
		"Man": return "Men"
	return "Non-binary people"


## Whether this person is looking to meet someone like you (mutual, not just your preference).
func wants_to_meet_me(person: Dictionary) -> bool:
	var theirs: Array = person.get("show_me", [])
	return theirs.is_empty() or "Everyone" in theirs or gender_group() in theirs


func use_demo() -> void:
	reset()
	data.name = "Alex"
	data.email = "alex@example.com"
	data.phone = "91234567"
	data.birthday = {"d": "14", "m": "02", "y": "1997"}
	data.gender = "Non-binary"
	data.show_me = ["Everyone"]
	data.intent = "Still figuring it out"
	data.interests = ["Art", "Live music", "Coffee", "Hiking", "Films"]
	data.avatar = Avatar.random_config()
	data.onboarded = true
