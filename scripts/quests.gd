extends RefCounted
## Quests: small adventures for two. Every step happens in the world, so they finish themselves
## as you play: go somewhere, step inside, do the thing.
## Step kinds: "visit" a place, "enter" a venue type there, "activity" of that type there.

const CATALOG := [
	{"id": "coffee_crawl", "title": "Coffee crawl in Tiong Bahru", "blurb": "Slow morning, good coffee, a shared table.", "place": "Tiong Bahru",
		"steps": [["visit", "", "Meet in Tiong Bahru"], ["enter", "cafe", "Find the bakery café"], ["activity", "cafe", "Share a table and order"]]},
	{"id": "trivia_rematch", "title": "Trivia rematch", "blurb": "Same team. Better answers. Probably.", "place": "Holland Village",
		"steps": [["visit", "", "Head to Holland Village"], ["enter", "bar", "Find the quiz house"], ["activity", "bar", "Play a full trivia night"]]},
	{"id": "thrift_look", "title": "Thrift each other a look", "blurb": "Twenty dollars, one outfit, no vetoes.", "place": "Bugis",
		"steps": [["visit", "", "Go to Bugis"], ["enter", "thrift", "Find a thrift store"], ["activity", "thrift", "Try things on and keep a look"]]},
	{"id": "records", "title": "Record hunting on Haji Lane", "blurb": "Dig for something neither of you has heard.", "place": "Haji Lane",
		"steps": [["visit", "", "Walk down Haji Lane"], ["enter", "records", "Find the record store"], ["activity", "records", "Pick a favourite at the listening station"]]},
	{"id": "gallery", "title": "Gallery date", "blurb": "Decide what the art means. Disagree beautifully.", "place": "Bras Basah",
		"steps": [["visit", "", "Meet in Bras Basah"], ["enter", "gallery", "Find the gallery"], ["activity", "gallery", "Walk the new show"]]},
	{"id": "showdown", "title": "Arcade showdown", "blurb": "Air hockey. Winner picks dinner.", "place": "one-north",
		"steps": [["visit", "", "Go to one-north"], ["enter", "arcade", "Find the arcade"], ["activity", "arcade", "Play air hockey"]]},
	{"id": "river_night", "title": "A night by the river", "blurb": "Music, lights, and a dance floor if you're brave.", "place": "Clarke Quay",
		"steps": [["visit", "", "Head to Clarke Quay"], ["enter", "club", "Find the club"], ["activity", "club", "Dance a full song"]]},
	{"id": "supper", "title": "Supper club in Katong", "blurb": "Order too much. Share everything.", "place": "Katong",
		"steps": [["visit", "", "Go to Katong"], ["enter", "restaurant", "Find the kitchen"], ["activity", "restaurant", "Join the supper club table"]]},
]


const Places = preload("res://scripts/places.gd")


static func find(id: String) -> Dictionary:
	for q in CATALOG:
		if q.id == id:
			return q
	return {}


## The venue type a quest happens in ("cafe", "arcade", ...).
static func venue_type(q: Dictionary) -> String:
	for st in q.get("steps", []):
		var t: String = st[1] if st is Array else st.get("type", "")
		if t != "":
			return t
	return ""


## The exact door for a quest: [venue name, door index] on the place's street.
static func venue_of(q: Dictionary) -> Array:
	var place := Places.find(q.get("place", ""))
	var want := venue_type(q)
	var venues: Array = place.get("venues", [])
	for i in venues.size():
		if venues[i][1] == want:
			return [venues[i][0], i]
	return ["", 0]


## A live copy of a catalogue quest with its own progress.
static func instance(template: Dictionary, person_id: String, from_me: bool) -> Dictionary:
	var where := venue_of(template)
	var steps := []
	for st in template.steps:
		var text: String = st[2]
		if st[0] == "enter" and where[0] != "":
			text = "Step inside %s" % where[0]
		elif st[0] == "activity" and where[0] != "":
			text = "%s at %s" % [text, where[0]]
		steps.append({"kind": st[0], "type": st[1], "text": text, "done": false})
	return {
		"qid": "%s-%s-%d" % [template.id, person_id, Time.get_unix_time_from_system()], "template": template.id,
		"title": template.title, "blurb": template.blurb, "place": template.place, "with": person_id,
		"venue": where[0], "door": where[1], "steps": steps, "status": "proposed", "from_me": from_me,
	}


static func progress(q: Dictionary) -> int:
	var n := 0
	for st in q.steps:
		if st.done:
			n += 1
	return n
