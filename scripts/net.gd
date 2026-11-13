extends Node
## Play with friends. One player hosts a small WebSocket relay inside the game; everyone
## (the host included) connects to it as a client. Only public profile fields are sent:
## never phone, email or birthday. The relay re-checks every limit on its side.

signal status_changed(text: String)
signal roster_changed
signal chat_received(person_id: String, text: String)
signal call_incoming(handle: String)
signal call_state_changed(state: String)
## Someone in the same venue asked you to play (trivia).
signal invited(handle: String, venue: String, seed: int)
signal invite_answered(handle: String, yes: bool, seed: int)
## A shared game move from your partner: their answer for a round.
signal play_received(handle: String, round: int, choice: int)

const Validate = preload("res://scripts/validate.gd")
const UI = preload("res://scripts/ui.gd")
const PORT := 9080
const BUFFER := 8 * 1024 * 1024
const MAX_PHOTOS := 3
const MAX_PHOTO_B64 := 400 * 1024

var players := {} # handle -> {"profile": {}, "presence": {}, "photos": [Texture2D]}
var status := "offline"
var url := ""

var _client: WebSocketPeer
var _said_hello := false
var _presence := {}
var _presence_dirty := false
var _presence_clock := 0.0

# Relay (host) state.
var _server: TCPServer
var _peers := {} # int id -> {"ws": WebSocketPeer, "handle": "", "profile": {}, "photos": [], "presence": {}, "follows": [], "times": []}
var _next_id := 1

# Voice calls: 16 kHz mono, 16-bit, sent in ~60 ms chunks. Only between matches, only once accepted.
const VOICE_RATE := 16000
var call_with := ""
var call_state := "idle" # idle, ringing_out, ringing_in, active
var muted := false
## Push to talk: only send your voice while talking is held (button or Space).
var push_to_talk := false
var talking := false
var _gate_open_for := 0.0 # seconds the noise gate stays open after you stop speaking
var _jitter := PackedVector2Array()
var _jitter_started := false
const GATE_LEVEL := 0.018 # below this loudness, a chunk counts as background noise
const GATE_HOLD := 0.35
const JITTER_START := 0.12 # buffer this much before playing, to smooth network hiccups
var _mic_player: AudioStreamPlayer
var _capture: AudioEffectCapture
var _voice_player: AudioStreamPlayer
var _playback: AudioStreamGeneratorPlayback
var _resample := 0.0
var _outgoing := PackedByteArray()


func is_online() -> bool:
	return status == "online"


func is_hosting() -> bool:
	return _server != null and _server.is_listening()


static func person_id(handle: String) -> String:
	return "net:" + handle


# --- Hosting --------------------------------------------------------------------------

## The always-on online server everyone connects to (set in Project Settings: somewhere/server_url).
## Empty means "no online server": people host on their own computer instead.
func server_url() -> String:
	return str(ProjectSettings.get_setting("somewhere/server_url", ""))


## Relay only, no player: used by the online server (`-- --relay`). Listens on $PORT if set.
func serve_only(port: int) -> String:
	_server = TCPServer.new()
	var err := _server.listen(port, "*")
	if err != OK:
		_server = null
		return "Couldn't listen on port %d" % port
	return ""


func host() -> String:
	if OS.has_feature("web"):
		return "Browsers can't host. Everyone joins the online server instead."
	if is_hosting():
		return ""
	_server = TCPServer.new()
	var err := _server.listen(PORT, "*")
	if err != OK:
		_server = null
		return "Couldn't open port %d (is another game already hosting?)" % PORT
	join("ws://127.0.0.1:%d" % PORT)
	return ""


func local_addresses() -> Array:
	var out := []
	for a in IP.get_local_addresses():
		if "." in a and not a.begins_with("127.") and not a.begins_with("169.254"):
			out.append(a)
	return out


func _serve() -> void:
	while _server.is_connection_available():
		var ws := WebSocketPeer.new()
		ws.inbound_buffer_size = BUFFER
		ws.outbound_buffer_size = BUFFER
		ws.accept_stream(_server.take_connection())
		_peers[_next_id] = {"ws": ws, "handle": "", "profile": {}, "photos": [], "presence": {}, "follows": [], "times": [], "call": ""}
		_next_id += 1
	for id in _peers.keys():
		var p: Dictionary = _peers[id]
		var ws: WebSocketPeer = p.ws
		ws.poll()
		match ws.get_ready_state():
			WebSocketPeer.STATE_OPEN:
				while ws.get_available_packet_count() > 0:
					var msg = JSON.parse_string(ws.get_packet().get_string_from_utf8())
					if typeof(msg) == TYPE_DICTIONARY:
						_relay(id, msg)
			WebSocketPeer.STATE_CLOSED:
				var handle: String = p.handle
				_peers.erase(id)
				if handle != "":
					_broadcast({"t": "left", "handle": handle})


func _send_to(id: int, msg: Dictionary) -> void:
	if _peers.has(id):
		_peers[id].ws.send_text(JSON.stringify(msg))


func _broadcast(msg: Dictionary, except := -1) -> void:
	for id in _peers:
		if id != except and _peers[id].handle != "":
			_send_to(id, msg)


func _peer_by_handle(handle: String) -> int:
	for id in _peers:
		if _peers[id].handle == handle:
			return id
	return -1


## The relay's side of the protocol, with its own data checks.
func _relay(id: int, msg: Dictionary) -> void:
	var p: Dictionary = _peers[id]
	var now := Time.get_ticks_msec()
	p.times = p.times.filter(func(t) -> bool: return now - t < 1000)
	p.times.append(now)
	if p.times.size() > 60:
		return # Rate limit: drop floods.
	match str(msg.get("t", "")):
		"hello":
			var prof: Dictionary = msg.get("profile", {})
			var handle := str(prof.get("handle", ""))
			var err := Validate.handle_error(handle)
			if err == "" and Validate.name_error(str(prof.get("name", ""))) != "":
				err = "Your name needs fixing first."
			if err == "" and _peer_by_handle(handle) not in [-1, id]:
				err = "Someone here is already @%s." % handle
			if err != "":
				_send_to(id, {"t": "error", "msg": err})
				return
			var photos: Array = []
			for ph in msg.get("photos", []).slice(0, MAX_PHOTOS):
				if typeof(ph) == TYPE_STRING and ph.length() <= MAX_PHOTO_B64:
					photos.append(ph)
			var clean := {}
			for k in ["handle", "name", "age", "pronouns", "gender", "intent", "interests", "cats", "avatar", "prompts", "orientation", "show_me", "gender_group"]:
				clean[k] = prof.get(k)
			if not str(clean.orientation) in UI_ORIENTATIONS:
				clean.orientation = ""
			clean.show_me = (clean.show_me if typeof(clean.show_me) == TYPE_ARRAY else []).filter(func(x) -> bool: return x in ["Women", "Men", "Non-binary people", "Everyone"])
			clean.interests = (clean.interests if typeof(clean.interests) == TYPE_ARRAY else []).slice(0, 10)
			p.handle = handle
			p.profile = clean
			p.photos = photos
			var roster := []
			for other in _peers:
				if other != id and _peers[other].handle != "":
					roster.append({"handle": _peers[other].handle, "profile": _peers[other].profile, "presence": _peers[other].presence})
			_send_to(id, {"t": "welcome", "roster": roster})
			_broadcast({"t": "joined", "handle": handle, "profile": clean}, id)
		"presence":
			if p.handle == "":
				return
			p.presence = msg.get("presence", {})
			_broadcast({"t": "presence", "handle": p.handle, "presence": p.presence}, id)
		"photos":
			var target := _peer_by_handle(str(msg.get("handle", "")))
			if target >= 0:
				_send_to(id, {"t": "photos", "handle": _peers[target].handle, "photos": _peers[target].photos})
		"follow":
			var to := str(msg.get("to", ""))
			var target := _peer_by_handle(to)
			if p.handle == "" or target < 0:
				return
			if not to in p.follows:
				p.follows.append(to)
			# A match only happens when both have followed. Nobody is told otherwise.
			if p.handle in _peers[target].follows:
				_send_to(id, {"t": "match", "handle": to})
				_send_to(target, {"t": "match", "handle": p.handle})
		"quest", "quest_reply":
			var to := str(msg.get("to", ""))
			var target := _peer_by_handle(to)
			if target < 0 or not (to in p.follows and p.handle in _peers[target].follows):
				return
			var out := {"t": msg.t, "from": p.handle, "qid": str(msg.get("qid", "")).left(120)}
			if msg.t == "quest":
				out.template = str(msg.get("template", "")).left(40)
			else:
				out.accept = bool(msg.get("accept", false))
			_send_to(target, out)
		"call", "call_accept", "call_end":
			var to := str(msg.get("to", ""))
			var target := _peer_by_handle(to)
			if target < 0 or not (to in p.follows and p.handle in _peers[target].follows):
				return
			if msg.t == "call_accept":
				p.call = to
				_peers[target].call = p.handle
			elif msg.t == "call_end":
				p.call = ""
				_peers[target].call = ""
			_send_to(target, {"t": msg.t, "from": p.handle})
		"voice":
			var to := str(msg.get("to", ""))
			var target := _peer_by_handle(to)
			var pcm := str(msg.get("pcm", ""))
			# Audio only flows inside an accepted call.
			if target < 0 or pcm.length() > 24000 or p.get("call", "") != to or _peers[target].get("call", "") != p.handle:
				return
			_send_to(target, {"t": "voice", "from": p.handle, "pcm": pcm})
		"invite", "invite_reply", "play":
			var to := str(msg.get("to", ""))
			var target := _peer_by_handle(to)
			# Games are only between two people standing in the same venue right now. No match needed.
			if p.handle == "" or target < 0 or not _same_room(p, _peers[target]):
				return
			var out := {"t": msg.t, "from": p.handle, "seed": int(msg.get("seed", 0))}
			match msg.t:
				"invite": out.venue = str(msg.get("venue", "")).left(60)
				"invite_reply": out.yes = bool(msg.get("yes", false))
				"play":
					out.round = clampi(int(msg.get("round", 0)), 0, 20)
					out.choice = clampi(int(msg.get("choice", 0)), 0, 8)
			_send_to(target, out)
		"unmatch":
			# Closing kindly ends the connection for both people: no more chat, quests or calls.
			var to := str(msg.get("to", ""))
			p.follows.erase(to)
			var target := _peer_by_handle(to)
			if target >= 0:
				_peers[target].follows.erase(p.handle)
				_send_to(target, {"t": "unmatched", "from": p.handle})
		"chat":
			var to := str(msg.get("to", ""))
			var text := str(msg.get("text", "")).strip_edges().left(Validate.MAX_MESSAGE)
			var target := _peer_by_handle(to)
			# Messages only flow between people who matched.
			if text == "" or target < 0 or not (to in p.follows and p.handle in _peers[target].follows):
				return
			_send_to(target, {"t": "chat", "from": p.handle, "text": text})


const UI_ORIENTATIONS := ["Straight", "Gay", "Lesbian", "Bisexual", "Pansexual", "Queer", "Asexual", "Prefer not to say", ""]


func _same_room(a: Dictionary, b: Dictionary) -> bool:
	var pa: Dictionary = a.get("presence", {})
	var pb: Dictionary = b.get("presence", {})
	return pa.get("screen", "") == "venue" and pb.get("screen", "") == "venue" \
		and pa.get("place", "") == pb.get("place", "") and pa.get("spot", "") == pb.get("spot", "")


# --- Client -----------------------------------------------------------------------

func join(address: String) -> void:
	leave_client()
	url = address if address.begins_with("ws") else "ws://%s:%d" % [address, PORT]
	_client = WebSocketPeer.new()
	_client.inbound_buffer_size = BUFFER
	_client.outbound_buffer_size = BUFFER
	var err := _client.connect_to_url(url)
	_set_status("connecting" if err == OK else "offline")
	_said_hello = false


func leave_client() -> void:
	if _client:
		_client.close()
	_client = null
	players.clear()
	_set_status("offline")
	roster_changed.emit()


func _set_status(s: String) -> void:
	status = s
	status_changed.emit(s)


func _send(msg: Dictionary) -> void:
	if _client and _client.get_ready_state() == WebSocketPeer.STATE_OPEN:
		_client.send_text(JSON.stringify(msg))


func _hello() -> void:
	var photos := []
	for tex in Profile.photos.slice(0, MAX_PHOTOS):
		var img: Image = tex.get_image()
		var longest := maxi(img.get_width(), img.get_height())
		if longest > 480:
			img = img.duplicate()
			img.resize(int(img.get_width() * 480.0 / longest), int(img.get_height() * 480.0 / longest))
		photos.append(Marshalls.raw_to_base64(img.save_jpg_to_buffer(0.75)))
	_send({"t": "hello", "profile": Profile.public_profile(), "photos": photos})
	_said_hello = true


## extra: venue "type", "door", "mall", and "seat" (table seat index, -1 standing) so friends can find you.
func set_presence(screen: String, place := "", spot := "", pos := Vector2.ZERO, extra := {}) -> void:
	var p := {"screen": screen, "place": place, "spot": spot, "x": snappedf(pos.x, 1.0), "y": snappedf(pos.y, 1.0)}
	p.merge(extra)
	if p != _presence:
		_presence = p
		_presence_dirty = true


## At the Shore you stay where you were, greyed out as resting, so people can still see your profile.
func set_resting(resting: bool) -> void:
	if bool(_presence.get("resting", false)) == resting:
		return
	_presence = _presence.duplicate()
	if not _presence.has("screen"):
		_presence.screen = "shore"
	_presence.resting = resting
	_presence_dirty = true


func is_resting(handle: String) -> bool:
	return bool(players.get(handle, {}).get("presence", {}).get("resting", false))


func follow(handle: String) -> void:
	_send({"t": "follow", "to": handle})


func send_unmatch(handle: String) -> void:
	_send({"t": "unmatch", "to": handle})


## After (re)connecting the server has forgotten who matched: follow every open match again.
func _refollow() -> void:
	for id in Profile.data.get("matches", {}):
		var m: Dictionary = Profile.data.matches[id]
		if str(id).begins_with("net:") and not m.get("closed", false):
			_send({"t": "follow", "to": str(id).substr(4)})


func send_chat(handle: String, text: String) -> void:
	_send({"t": "chat", "to": handle, "text": text})


func send_invite(handle: String, venue: String, seed: int) -> void:
	_send({"t": "invite", "to": handle, "venue": venue, "seed": seed})


func reply_invite(handle: String, yes: bool, seed: int) -> void:
	_send({"t": "invite_reply", "to": handle, "yes": yes, "seed": seed})


func send_play(handle: String, round: int, choice: int) -> void:
	_send({"t": "play", "to": handle, "round": round, "choice": choice})


func send_quest(handle: String, q: Dictionary) -> void:
	_send({"t": "quest", "to": handle, "template": q.template, "qid": q.qid})


func send_quest_reply(handle: String, qid: String, accept: bool) -> void:
	_send({"t": "quest_reply", "to": handle, "qid": qid, "accept": accept})


func start_call(handle: String) -> void:
	if call_state != "idle":
		return
	call_with = handle
	_set_call("ringing_out")
	_send({"t": "call", "to": handle})


func accept_call() -> void:
	if call_state != "ringing_in":
		return
	_send({"t": "call_accept", "to": call_with})
	_begin_audio()
	_set_call("active")


func end_call() -> void:
	if call_state == "idle":
		return
	_send({"t": "call_end", "to": call_with})
	_stop_audio()
	call_with = ""
	_set_call("idle")


func _set_call(state: String) -> void:
	call_state = state
	call_state_changed.emit(state)


func _begin_audio() -> void:
	var idx := AudioServer.get_bus_index("Mic")
	if idx < 0:
		AudioServer.add_bus()
		idx = AudioServer.bus_count - 1
		AudioServer.set_bus_name(idx, "Mic")
		AudioServer.add_bus_effect(idx, AudioEffectCapture.new())
		AudioServer.set_bus_volume_db(idx, -80.0)
	_capture = AudioServer.get_bus_effect(idx, 0)
	_capture.clear_buffer()
	_mic_player = AudioStreamPlayer.new()
	_mic_player.stream = AudioStreamMicrophone.new()
	_mic_player.bus = "Mic"
	add_child(_mic_player)
	_mic_player.play()
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = VOICE_RATE
	gen.buffer_length = 0.5
	_voice_player = AudioStreamPlayer.new()
	_voice_player.stream = gen
	add_child(_voice_player)
	_voice_player.play()
	_playback = _voice_player.get_stream_playback()
	_outgoing.clear()
	_jitter.clear()
	_jitter_started = false
	_gate_open_for = 0.0


func _stop_audio() -> void:
	for n in [_mic_player, _voice_player]:
		if n and is_instance_valid(n):
			n.queue_free()
	_mic_player = null
	_voice_player = null
	_playback = null
	_capture = null


func _pump_voice() -> void:
	if _capture == null:
		return
	var frames := _capture.get_frames_available()
	if frames <= 0:
		return
	var buf := _capture.get_buffer(frames)
	if muted or (push_to_talk and not talking):
		_outgoing.clear()
		return
	# Noise gate: skip chunks that are only room noise (with a short hold so words aren't clipped).
	var energy := 0.0
	for f in buf:
		energy += (f.x + f.y) * (f.x + f.y) * 0.25
	var rms := sqrt(energy / maxf(1.0, buf.size()))
	var dt := float(buf.size()) / AudioServer.get_mix_rate()
	if rms > GATE_LEVEL or push_to_talk:
		_gate_open_for = GATE_HOLD
	else:
		_gate_open_for -= dt
	if _gate_open_for <= 0.0:
		_outgoing.clear()
		return
	# Downsample by averaging each window (a simple low-pass), instead of skipping samples (harsh aliasing).
	var step := AudioServer.get_mix_rate() / VOICE_RATE
	var i := 0.0
	while i + step <= buf.size():
		var acc := 0.0
		var n := 0
		for k in range(int(i), int(i + step)):
			acc += (buf[k].x + buf[k].y) * 0.5
			n += 1
		var v := int(clampf(acc / maxf(1, n), -1.0, 1.0) * 32000.0)
		_outgoing.append(v & 0xFF)
		_outgoing.append((v >> 8) & 0xFF)
		i += step
	if _outgoing.size() >= VOICE_RATE * 2 * 6 / 100:
		_send({"t": "voice", "to": call_with, "pcm": Marshalls.raw_to_base64(_outgoing)})
		_outgoing.clear()


func _play_voice(b64: String) -> void:
	if _playback == null:
		return
	var raw := Marshalls.base64_to_raw(b64)
	var n := raw.size() / 2
	for k in n:
		var v := raw.decode_s16(k * 2) / 32000.0
		_jitter.append(Vector2(v, v))
	# Too far behind: drop the oldest audio rather than drifting into a delay.
	if _jitter.size() > VOICE_RATE:
		_jitter = _jitter.slice(_jitter.size() - VOICE_RATE / 4)


## Feed buffered voice to the speaker; wait for a small cushion first so hiccups don't crackle.
func _drain_voice() -> void:
	if _playback == null:
		return
	if not _jitter_started:
		if _jitter.size() < int(VOICE_RATE * JITTER_START):
			return
		_jitter_started = true
	var room := _playback.get_frames_available()
	var take := mini(room, _jitter.size())
	if take > 0:
		_playback.push_buffer(_jitter.slice(0, take))
		_jitter = _jitter.slice(take)
	if _jitter.is_empty():
		_jitter_started = false


func request_photos(handle: String) -> void:
	_send({"t": "photos", "handle": handle})


## A real player, in the same shape as a simulated person so every screen can show them.
func person_for(handle: String) -> Dictionary:
	var pl: Dictionary = players.get(handle, {})
	var prof: Dictionary = pl.get("profile", {})
	var cfg := {}
	for k in prof.get("avatar", {}):
		cfg[k] = int(prof.avatar[k])
	return {
		"id": person_id(handle), "real": true, "handle": handle, "name": str(prof.get("name", handle)),
		"pronouns": str(prof.get("pronouns", "")), "age": int(prof.get("age", 0)), "cfg": cfg,
		"cats": prof.get("cats", []), "interests": prof.get("interests", []), "intent": str(prof.get("intent", "")),
		"prompts": prof.get("prompts", []), "traits": [], "facts": [], "job": "", "home": "",
		"orientation": str(prof.get("orientation", "")), "show_me": prof.get("show_me", []),
		"bio": "A real person, here right now.",
	}


func players_where(screen: String, place := "", spot := "") -> Array:
	var out := []
	for h in players:
		var pr: Dictionary = players[h].get("presence", {})
		if pr.get("screen", "") == screen and (place == "" or pr.get("place", "") == place) and (spot == "" or pr.get("spot", "") == spot):
			out.append(h)
	return out


func _receive(msg: Dictionary) -> void:
	match str(msg.get("t", "")):
		"invite":
			invited.emit(str(msg.get("from", "")), str(msg.get("venue", "")), int(msg.get("seed", 0)))
		"invite_reply":
			invite_answered.emit(str(msg.get("from", "")), bool(msg.get("yes", false)), int(msg.get("seed", 0)))
		"play":
			play_received.emit(str(msg.get("from", "")), int(msg.get("round", 0)), int(msg.get("choice", 0)))
		"welcome":
			_set_status("online")
			# A fresh connection: tell the server where we are again, or friends see us nowhere.
			_presence_dirty = true
			_presence_clock = 0.0
			_refollow()
			for r in msg.get("roster", []):
				players[r.handle] = {"profile": r.profile, "presence": r.presence, "photos": []}
			roster_changed.emit()
			_toast("You're connected. %d friend%s here." % [players.size(), "" if players.size() == 1 else "s"])
		"error":
			_set_status("offline")
			_toast(str(msg.get("msg", "Couldn't join.")))
		"joined":
			players[msg.handle] = {"profile": msg.profile, "presence": {}, "photos": []}
			# They may be a match who reconnected: re-follow so chat flows again.
			var mid := person_id(msg.handle)
			if Profile.data.matches.has(mid) and not Profile.data.matches[mid].get("closed", false):
				follow(msg.handle)
			roster_changed.emit()
			_toast("%s (@%s) just joined." % [msg.profile.get("name", ""), msg.handle])
		"left":
			players.erase(msg.handle)
			roster_changed.emit()
		"presence":
			if players.has(msg.handle):
				players[msg.handle].presence = msg.presence
		"photos":
			if players.has(msg.handle):
				var texs := []
				for b64 in msg.get("photos", []):
					var img := Image.new()
					if img.load_jpg_from_buffer(Marshalls.base64_to_raw(b64)) == OK:
						texs.append(ImageTexture.create_from_image(img))
				players[msg.handle].photos = texs
				roster_changed.emit()
		"unmatched":
			Profile.closed_by_them(person_id(str(msg.get("from", ""))))
		"match":
			if Profile.data.matches.has(person_id(msg.handle)):
				return # Already matched: this is just a re-follow after reconnecting.
			var person := person_for(msg.handle)
			var where: String = Profile.data.get("following", {}).get(person.id, {}).get("where", "Somewhere")
			Profile.add_match(person, where)
			Profile.data.following.erase(person.id)
			Profile.save()
			Profile.string_returned.emit(person)
		"quest":
			var id := person_id(msg.from)
			if Profile.data.matches.has(id) and not Profile.Quests.find(str(msg.template)).is_empty():
				Profile.receive_quest(id, str(msg.template), str(msg.qid))
				_toast("%s proposed a quest!" % Profile.data.matches[id].person.name)
		"quest_reply":
			if bool(msg.get("accept", false)):
				Profile.accept_quest(str(msg.qid))
			else:
				Profile.decline_quest(str(msg.qid))
		"call":
			if call_state == "idle" and Profile.data.matches.has(person_id(msg.from)):
				call_with = msg.from
				_set_call("ringing_in")
				call_incoming.emit(msg.from)
			else:
				_send({"t": "call_end", "to": msg.from})
		"call_accept":
			if call_state == "ringing_out" and msg.from == call_with:
				_begin_audio()
				_set_call("active")
		"call_end":
			if msg.from == call_with:
				_stop_audio()
				call_with = ""
				_set_call("idle")
		"voice":
			if call_state == "active" and msg.from == call_with:
				_play_voice(str(msg.pcm))
		"chat":
			var id := person_id(msg.from)
			# Closed conversations receive nothing, even if the other side keeps sending.
			if Profile.data.matches.has(id) and not Profile.data.matches[id].get("closed", false):
				var text := str(msg.text).left(Validate.MAX_MESSAGE)
				Profile.add_message(id, false, text)
				chat_received.emit(id, text)
				if text == Profile.CLOSE_KINDLY_TEXT:
					Profile.closed_by_them(id)
					_closed_card(Profile.data.matches[id].person)


## Make sure a goodbye is seen, not buried in a chat list.
func _closed_card(person: Dictionary) -> void:
	var app := get_tree().root.get_node_or_null("App")
	if app == null or app.current == null:
		return
	var overlay := Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	app.current.add_child(overlay)
	UI.scrim(overlay)
	var card := PanelContainer.new()
	card.theme_type_variation = "Card"
	card.anchor_left = 0.5
	card.anchor_right = 0.5
	card.anchor_top = 0.5
	card.anchor_bottom = 0.5
	card.offset_left = -260
	card.offset_right = 260
	card.offset_top = -170
	card.offset_bottom = 170
	overlay.add_child(card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	card.add_child(v)
	v.add_child(UI.eyebrow("A kind goodbye", UI.GOLD))
	v.add_child(UI.title("%s closed your conversation" % person.get("name", "Someone"), 28))
	v.add_child(UI.label("\"%s\"" % Profile.CLOSE_KINDLY_TEXT, 15, UI.CREAM))
	v.add_child(UI.label("It isn't about you being wrong for anyone. The chat is now closed on both sides.", 13, UI.MUTED))
	var ok := UI.button("Okay", "PrimaryButton")
	ok.pressed.connect(overlay.queue_free)
	v.add_child(ok)


func _toast(text: String) -> void:
	var app := get_tree().root.get_node_or_null("App")
	if app and app.has_method("toast"):
		app.toast(text)


var _retry_in := 3.0
var _ping_in := 20.0


## Where a friend is right now, in words.
func where_text(handle: String) -> String:
	var pr: Dictionary = players.get(handle, {}).get("presence", {})
	var place := str(pr.get("place", ""))
	var spot := str(pr.get("spot", ""))
	var at := ""
	match str(pr.get("screen", "")):
		"venue": at = "at %s, %s" % [spot, place]
		"district": at = ("in %s, %s" % [spot, place]) if spot != "" else "walking around %s" % place
		"map": at = "looking at the map"
		"shore": at = "at the Shore"
		_: at = "just arrived"
	if bool(pr.get("resting", false)):
		at = "resting at the Shore" + ("" if str(pr.get("screen", "")) in ["shore", ""] else " (last seen %s)" % at)
	return at


## The screen and params that put you right next to a friend, or [] if there's nowhere to go.
func go_to(handle: String) -> Array:
	var pr: Dictionary = players.get(handle, {}).get("presence", {})
	var place := str(pr.get("place", ""))
	match str(pr.get("screen", "")):
		"venue":
			if place == "" or str(pr.get("type", "")) == "":
				return []
			var p := {"place": place, "venue": str(pr.get("spot", "")), "type": str(pr.type), "door": int(pr.get("door", 0))}
			if str(pr.get("mall", "")) != "":
				p.mall = str(pr.mall)
			return ["venue", p]
		"district":
			if place == "":
				return []
			var d := {"place": place}
			if str(pr.get("spot", "")) != "":
				d.mall = str(pr.spot)
			return ["district", d]
		"map":
			return ["map", {}]
	return []


## Seat index a friend is sitting in at this venue (-1 standing).
func seat_of(handle: String) -> int:
	return int(players.get(handle, {}).get("presence", {}).get("seat", -1))


func _process(delta: float) -> void:
	if is_hosting():
		_serve()
	# Online server configured: keep trying to (re)connect, e.g. while the free server wakes up.
	if _client == null and server_url() != "" and not "--relay" in OS.get_cmdline_user_args():
		_retry_in -= delta
		if _retry_in <= 0.0:
			_retry_in = 5.0
			join(server_url())
	if _client == null:
		return
	_client.poll()
	match _client.get_ready_state():
		WebSocketPeer.STATE_OPEN:
			if not _said_hello and Profile.has_profile() and Profile.data.get("handle", "") != "":
				_hello()
			while _client.get_available_packet_count() > 0:
				var msg = JSON.parse_string(_client.get_packet().get_string_from_utf8())
				if typeof(msg) == TYPE_DICTIONARY:
					_receive(msg)
			if call_state == "active":
				_pump_voice()
				_drain_voice()
			# Keep the connection warm so hosting proxies don't drop quiet players.
			_ping_in -= delta
			if _ping_in <= 0.0:
				_ping_in = 20.0
				_send({"t": "ping"})
			_presence_clock -= delta
			if _presence_dirty and _presence_clock <= 0.0 and status == "online":
				_send({"t": "presence", "presence": _presence})
				_presence_dirty = false
				_presence_clock = 0.1
		WebSocketPeer.STATE_CLOSED:
			if call_state != "idle":
				_stop_audio()
				call_with = ""
				_set_call("idle")
			if status == "online":
				_toast("Lost connection. Reconnecting…")
			_client = null
			players.clear()
			_set_status("offline")
			roster_changed.emit()
