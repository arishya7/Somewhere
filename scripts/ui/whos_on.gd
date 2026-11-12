extends Control
## Who's on: every real player connected right now, where they are, and a button to go to them.

const UI = preload("res://scripts/ui.gd")
const Portrait = preload("res://scripts/portrait.gd")

var _host: Control
var _list: VBoxContainer
var _note: Label


static func open(host: Control) -> Control:
	var w = load("res://scripts/ui/whos_on.gd").new()
	w._host = host
	host.add_child(w)
	return w


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	UI.scrim(self)
	var card := PanelContainer.new()
	card.theme_type_variation = "Card"
	card.anchor_left = 0.5
	card.anchor_right = 0.5
	card.anchor_top = 0.5
	card.anchor_bottom = 0.5
	card.offset_left = -300
	card.offset_right = 300
	card.offset_top = -280
	card.offset_bottom = 280
	add_child(card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	card.add_child(v)
	var head := HBoxContainer.new()
	v.add_child(head)
	var titles := VBoxContainer.new()
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(titles)
	titles.add_child(UI.eyebrow("Online now", UI.GOLD))
	titles.add_child(UI.title("Who's on", 32))
	var close := UI.button("×", "TextButton")
	close.pressed.connect(queue_free)
	head.add_child(close)
	_note = UI.label("", 14, UI.MUTED)
	v.add_child(_note)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 10)
	scroll.add_child(_list)
	_rebuild()
	Net.roster_changed.connect(_rebuild)
	Net.status_changed.connect(_on_status)
	tree_exiting.connect(func() -> void:
		Net.roster_changed.disconnect(_rebuild)
		Net.status_changed.disconnect(_on_status))
	# Presence changes don't fire roster_changed, so refresh where people are now and then.
	var timer := Timer.new()
	timer.wait_time = 2.0
	timer.autostart = true
	timer.timeout.connect(_rebuild)
	add_child(timer)


func _on_status(_s: String) -> void:
	_rebuild()


func _unhandled_key_input(event: InputEvent) -> void:
	if event.pressed and event.keycode == KEY_ESCAPE:
		queue_free()
		get_viewport().set_input_as_handled()


func _rebuild() -> void:
	for c in _list.get_children():
		c.queue_free()
	if not Net.is_online():
		_note.text = "Connecting to the server… If it's been asleep, this can take up to a minute. Keep this tab open."
		return
	var handles := Net.players.keys()
	handles.sort()
	var qp := Profile.real_quest_partner()
	_note.text = "Nobody else is on right now. Send your friends the link!" if handles.is_empty() \
		else "%d other %s on. Tap Go to them to land right where they are." % [handles.size(), "person" if handles.size() == 1 else "people"]
	for h in handles:
		var p := Net.person_for(h)
		var row := PanelContainer.new()
		row.add_theme_stylebox_override("panel", UI.box(Color(1, 1, 1, 0.05), 16, UI.GOLD if h == qp else Color(0, 0, 0, 0), 1, 14, 10))
		_list.add_child(row)
		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 12)
		row.add_child(hb)
		hb.add_child(Portrait.make(p.cfg, 48, UI.GOLD if h == qp else UI.SAGE))
		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.add_theme_constant_override("separation", 2)
		hb.add_child(info)
		var name_line := "%s  ·  @%s" % [p.name, h] + ("  ·  ★ your quest partner" if h == qp else "")
		info.add_child(UI.label(name_line, 16, UI.CREAM, 600))
		info.add_child(UI.label(Net.where_text(h).left(1).to_upper() + Net.where_text(h).substr(1), 13, UI.MUTED))
		var dest := Net.go_to(h)
		var go := UI.button("Go to them", "PrimaryButton")
		go.disabled = dest.is_empty() or _same_spot(h)
		if _same_spot(h):
			go.text = "You're here"
		go.pressed.connect(func() -> void:
			queue_free()
			var app := _host.get_parent()
			app.toast("Heading to @%s…" % h)
			app.go(dest[0], dest[1]))
		hb.add_child(go)


func _same_spot(h: String) -> bool:
	var pr: Dictionary = Net.players.get(h, {}).get("presence", {})
	var mine: Dictionary = Net._presence
	return pr.get("screen", "") == mine.get("screen", "-") and pr.get("place", "") == mine.get("place", "") \
		and pr.get("spot", "") == mine.get("spot", "")
