extends RefCounted
## Simulated people. Each one is generated from a seed, so the same person is the same
## every time you meet them: look, background, interests, personality and voice.

const Avatar = preload("res://scripts/avatar.gd")

const NAMES := [
	["Aisha", "she/her"], ["Mateo", "he/him"], ["Yuki", "she/her"], ["Liam", "he/him"], ["Priya", "she/her"],
	["Noah", "he/him"], ["Zara", "she/her"], ["Kenji", "he/him"], ["Sofia", "she/her"], ["Omar", "he/him"],
	["Chloe", "she/her"], ["Daniel", "he/him"], ["Mei", "she/her"], ["Lucas", "he/him"], ["Amara", "she/her"],
	["Ethan", "he/him"], ["Nadia", "she/her"], ["Arjun", "he/him"], ["Hana", "she/her"], ["Leo", "he/him"],
	["Camila", "she/her"], ["Ravi", "he/him"], ["Isla", "she/her"], ["Jin", "he/him"], ["Elena", "she/her"],
	["Kofi", "he/him"], ["Maya", "she/her"], ["Felix", "he/him"], ["Leila", "she/her"], ["Tomas", "he/him"],
	["Sam", "they/them"], ["Rowan", "they/them"], ["Alex", "they/them"], ["Jules", "they/them"], ["Nia", "she/her"],
	["Hugo", "he/him"], ["Ines", "she/her"], ["Theo", "he/him"], ["Lina", "she/her"], ["Marcus", "he/him"],
]
const HOMETOWNS := [
	"Lisbon", "Melbourne", "Seoul", "Lagos", "Toronto", "Mumbai", "Mexico City", "Manchester", "Osaka", "Nairobi",
	"Kuala Lumpur", "Berlin", "Manila", "São Paulo", "Auckland", "Jakarta", "Dublin", "Cape Town", "Chennai", "Vancouver",
]
const JOBS := [
	"Product designer", "Nurse", "Architect", "Data analyst", "Chef", "Teacher", "Marine biologist", "Lawyer",
	"Illustrator", "Software engineer", "Physiotherapist", "Journalist", "Pilot", "Founder (it's complicated)",
	"Music producer", "Researcher", "Photographer", "Consultant", "Barista and part-time poet", "Vet",
]
const TRAITS := {
	"curious": {"label": "Curious", "fact": "asks a follow-up question to everything", "voice": "Wait, tell me more about that."},
	"competitive": {"label": "Quietly competitive", "fact": "really, really wanted to win", "voice": "Okay but we were robbed on question three."},
	"warm": {"label": "Warm", "fact": "made sure everyone at the table felt included", "voice": "Honestly that made my night."},
	"witty": {"label": "Dry humour", "fact": "had a joke ready for every wrong answer", "voice": "I'd like to formally blame the question."},
	"calm": {"label": "Unhurried", "fact": "never once looked rushed, even on the timer", "voice": "No rush. I like slow conversations."},
	"adventurous": {"label": "Adventurous", "fact": "has a story that starts with 'so I missed my flight'", "voice": "Want to do something slightly ridiculous?"},
	"thoughtful": {"label": "Thoughtful", "fact": "took a second before every answer, and was usually right", "voice": "I've been thinking about what you said."},
	"playful": {"label": "Playful", "fact": "named your team in under three seconds", "voice": "Rematch. Same team. Same terrible name."},
}
const INTEREST_FACTS := {
	"art": ["sketches strangers on the train (with permission, mostly)", "can't walk past a gallery without going in"],
	"music": ["plays guitar badly but with total commitment", "has a playlist for every kind of weather"],
	"food": ["is on a mission to find the city's best dumplings", "bakes bread when stressed, so is very good at bread"],
	"sports": ["runs before sunrise, somehow by choice", "plays five-a-side every Thursday"],
	"outdoors": ["has hiked most of the trails on the island", "chases sunsets like it's a job"],
	"nightlife": ["knows a bar with no sign on the door", "is a karaoke closer, every time"],
	"culture": ["reads two books at once and finishes both", "rewatches the same three films every year"],
	"gaming": ["was top 500 in a game they won't name", "owns more board games than plates"],
	"wellness": ["meditates every morning, even the bad ones", "will talk you into a sunrise yoga class"],
}
const PROMPTS := [
	["My order at a kopitiam says a lot about me:", ["Kopi C kosong. I'm consistent like that.", "Teh peng and whatever the uncle recommends.", "Milo dinosaur. I'm not embarrassed."]],
	["A small thing that makes my whole day:", ["A bookshop with a reading chair.", "When the bus comes exactly as I reach the stop.", "Dogs. Any dog. All dogs."]],
	["A green flag I look for:", ["You remember the small things I mention.", "You send me a song you think I'll like.", "You laugh at my worst jokes."]],
	["I'll always say yes to...", ["Late-night noodles after a long day.", "A trivia night, even though we'll lose.", "A ferry somewhere, figuring it out when we land."]],
	["Ask me about...", ["The time I got lost in Johor with no battery.", "Why I'm scared of geese.", "My very serious ranking of chicken rice."]],
]
const INTENTS := ["Something long-term", "New friends", "Still figuring it out", "Something casual"]


static func make(seed_key: String, categories: Array = []) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(seed_key)
	# Only generate people who fit who you said you'd like to meet.
	var name_pool := NAMES.filter(func(n) -> bool: return n[1] in allowed_pronouns())
	var who: Array = name_pool[rng.randi() % name_pool.size()]
	var groups: Array = Profile.INTEREST_GROUPS.duplicate()
	var cats: Array = categories.duplicate()
	while cats.size() < 3:
		var c: String = groups[rng.randi() % groups.size()].cat
		if not c in cats:
			cats.append(c)
	var interests := []
	for c in cats:
		for g in groups:
			if g.cat == c:
				interests.append(g.items[rng.randi() % g.items.size()])
	var trait_keys := TRAITS.keys()
	var t1: String = trait_keys[rng.randi() % trait_keys.size()]
	var t2: String = t1
	while t2 == t1:
		t2 = trait_keys[rng.randi() % trait_keys.size()]
	var prompts := []
	var order := range(PROMPTS.size())
	for i in 2:
		var p: Array = PROMPTS[order.pop_at(rng.randi() % order.size())]
		prompts.append([p[0], p[1][rng.randi() % p[1].size()]])
	var facts := []
	for c in cats.slice(0, 2):
		var pool: Array = INTEREST_FACTS[c]
		facts.append(pool[rng.randi() % pool.size()])
	var home: String = HOMETOWNS[rng.randi() % HOMETOWNS.size()]
	var person := {
		"id": seed_key,
		"name": who[0],
		"pronouns": who[1],
		"age": rng.randi_range(22, 37),
		"cfg": Avatar.random_config(rng, {"she/her": "woman", "he/him": "man"}.get(who[1], "")),
		"cats": cats,
		"interests": interests,
		"traits": [t1, t2],
		"job": JOBS[rng.randi() % JOBS.size()],
		"home": home,
		"intent": INTENTS[rng.randi() % INTENTS.size()],
		"prompts": prompts,
		"facts": facts,
		"bio": "Grew up in %s, landed in Singapore %d years ago and stayed for the food and the thunderstorms." % [home, rng.randi_range(1, 8)],
	}
	_orient(person, rng)
	return person


## Venue staff who keep you company when nobody else is around. Never someone to date.
static func host(venue_name: String) -> Dictionary:
	var p := make(venue_name + "-host")
	p.id = "host:" + venue_name
	p.host = true
	return p


## Gives a simulated person an orientation, and who they'd want to meet, that fit together and fit you.
static func _orient(p: Dictionary, rng: RandomNumberGenerator) -> void:
	var me := Profile.gender_group()
	var options := []
	match p.pronouns:
		"she/her":
			options = [["Straight", ["Men"]], ["Lesbian", ["Women"]], ["Bisexual", ["Everyone"]], ["Queer", ["Everyone"]], ["Pansexual", ["Everyone"]]]
		"he/him":
			options = [["Straight", ["Women"]], ["Gay", ["Men"]], ["Bisexual", ["Everyone"]], ["Queer", ["Everyone"]]]
		_:
			options = [["Queer", ["Everyone"]], ["Pansexual", ["Everyone"]], ["Bisexual", ["Everyone"]]]
	# Mostly people who'd be interested in you, so the world isn't full of dead ends.
	var fits := options.filter(func(o) -> bool: return "Everyone" in o[1] or me in o[1])
	var pool: Array = fits if not fits.is_empty() and rng.randf() < 0.85 else options
	var pick: Array = pool[rng.randi() % pool.size()]
	p.orientation = pick[0] if rng.randf() < 0.75 else ""
	p.show_me = pick[1]


static func allowed_pronouns() -> Array:
	var want: Array = Profile.data.get("show_me", [])
	if want.is_empty() or "Everyone" in want:
		return ["she/her", "he/him", "they/them"]
	var out := []
	if "Women" in want: out.append("she/her")
	if "Men" in want: out.append("he/him")
	if "Non-binary people" in want: out.append("they/them")
	return out if not out.is_empty() else ["she/her", "he/him", "they/them"]


static func subject(p: Dictionary) -> String:
	match p.pronouns:
		"she/her": return "she"
		"he/him": return "he"
	return "they"


static func trait_label(key: String) -> String:
	return TRAITS[key].label


## How compatible this person is with you, from shared map categories.
static func shared_with_me(p: Dictionary) -> int:
	var mine := Profile.categories()
	var n := 0
	for c in p.cats:
		if c in mine:
			n += 1
	return n


## Interests you both picked, word for word.
static func shared_interests(p: Dictionary) -> Array:
	var mine: Array = Profile.data.get("interests", [])
	return p.get("interests", []).filter(func(i) -> bool: return i in mine)


## Someone worth a second look: you share an interest, or most of what you're into.
static func kindred(p: Dictionary) -> bool:
	return not shared_interests(p).is_empty() or shared_with_me(p) >= 2


## The little name tag shown on hover: name, age, pronouns, and what you have in common.
static func tag(p: Dictionary) -> String:
	var t := "%s, %d  ·  %s" % [p.name, int(p.age), p.get("pronouns", "")]
	var n := shared_interests(p).size()
	if n > 0:
		t += "  ·  ◆ %d in common" % n
	elif shared_with_me(p) >= 2:
		t += "  ·  ◆ similar vibe"
	return t


## A soft gold pool of light under someone you have things in common with.
static func draw_spotlight(ci: CanvasItem, feet: Vector2, width: float, t: float) -> void:
	var pulse := 0.75 + 0.25 * sin(t * 2.0)
	for k in 4:
		var r := width * (1.0 - k * 0.18)
		var pts := PackedVector2Array()
		for a in 24:
			var ang := TAU * a / 24.0
			pts.append(feet + Vector2(cos(ang) * r, sin(ang) * r * 0.28))
		ci.draw_colored_polygon(pts, Color(0.95, 0.78, 0.38, 0.07 * pulse))
