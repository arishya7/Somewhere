extends PanelContainer
## A small chat beside a live game with a real person, so talking doesn't mean leaving the game.
## Chat only works between matches (consent-first); otherwise it says how to unlock it.

const UI = preload("res://scripts/ui.gd")

var person := {}
var _thread: VBoxContainer
var _scroll: ScrollContainer
var _input: LineEdit


## Attach to a game overlay. Shifts the game card left to make room.
static func attach(overlay: Control, card: Control, who: Dictionary) -> Control:
	var q = load("res://scripts/ui/quick_chat.gd").new()
	q.person = who
	overlay.add_child(q)
	if card:
		card.offset_left -= 170
		card.offset_right -= 170
	return q


func _id() -> String:
	return "net:" + str(person.get("handle", ""))


func _open() -> bool:
	var m: Dictionary = Profile.data.matches.get(_id(), {})
	return not m.is_empty() and not m.get("closed", false)


func _ready() -> void:
	add_theme_stylebox_override("panel", UI.box(Color("#1A1424"), 20, Color(1, 1, 1, 0.12), 1, 16, 14))
	anchor_left = 1.0
	anchor_right = 1.0
	anchor_top = 0.5
	anchor_bottom = 0.5
	offset_left = -340
	offset_right = -20
	offset_top = -300
	offset_bottom = 300
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	add_child(v)
	v.add_child(UI.eyebrow("Chat  ·  @" + str(person.get("handle", "")), UI.GOLD))
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(_scroll)
	_thread = VBoxContainer.new()
	_thread.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_thread.add_theme_constant_override("separation", 6)
	_scroll.add_child(_thread)
	_input = LineEdit.new()
	_input.placeholder_text = "Say something…"
	_input.max_length = 500
	_input.text_submitted.connect(func(_t: String) -> void: _send())
	v.add_child(_input)
	var send := UI.button("Send", "PrimaryButton")
	send.pressed.connect(_send)
	v.add_child(send)
	_render()
	var on_chat := func(id: String, _text: String) -> void:
		if id == _id():
			Profile.data.matches[id].unread = 0
			_render()
	Net.chat_received.connect(on_chat)
	var on_closed := func(id: String) -> void:
		if id == _id():
			_render()
	Profile.closed_changed.connect(on_closed)
	tree_exiting.connect(func() -> void:
		Net.chat_received.disconnect(on_chat)
		Profile.closed_changed.disconnect(on_closed))
	_input.editable = _open()
	send.disabled = not _open()
	if _open():
		_input.grab_focus.call_deferred()


func _render() -> void:
	for c in _thread.get_children():
		c.queue_free()
	if not _open():
		var closed: bool = Profile.data.matches.get(_id(), {}).get("closed", false)
		var note := UI.label("This conversation is closed." if closed else
			"Chat opens once you and @%s both follow each other. After the game, tap their name tag and follow their string." % person.get("handle", ""), 14, UI.MUTED)
		_thread.add_child(note)
		return
	var msgs: Array = Profile.data.matches[_id()].messages
	if msgs.is_empty():
		_thread.add_child(UI.label("Say hi while you play.", 14, UI.FAINT))
	for m in msgs.slice(maxi(0, msgs.size() - 30)):
		if m.has("quest"):
			continue
		var bubble := PanelContainer.new()
		bubble.size_flags_horizontal = Control.SIZE_SHRINK_END if m.me else Control.SIZE_SHRINK_BEGIN
		bubble.add_theme_stylebox_override("panel", UI.box(UI.CREAM if m.me else Color(1, 1, 1, 0.08), 14, Color(0, 0, 0, 0), 0, 12, 8))
		var l := UI.label(str(m.text), 14, UI.INK if m.me else UI.CREAM)
		l.custom_minimum_size.x = mini(240, 18 + str(m.text).length() * 8)
		bubble.add_child(l)
		_thread.add_child(bubble)
	await get_tree().process_frame
	if is_instance_valid(_scroll):
		_scroll.scroll_vertical = int(_scroll.get_v_scroll_bar().max_value)


func _send() -> void:
	var text := _input.text.strip_edges()
	if text == "" or not _open():
		return
	_input.text = ""
	Profile.add_message(_id(), true, text)
	Net.send_chat(person.handle, text)
	_render()
