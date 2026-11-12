extends Control
## Onboarding, one question per screen, the way good dating apps do it.
## Verification codes are simulated: a notification banner shows the code.

const UI = preload("res://scripts/ui.gd")
const Background = preload("res://scripts/background.gd")
const Validate = preload("res://scripts/validate.gd")
const People = preload("res://scripts/people.gd")

const STEPS := ["name", "handle", "phone", "phone_code", "email", "email_code", "birthday", "gender", "show_me", "orientation", "intent", "interests", "prompt", "photos"]
const COUNTRIES := [
	["+65", "Singapore"], ["+1", "United States"], ["+44", "United Kingdom"], ["+61", "Australia"], ["+91", "India"],
	["+60", "Malaysia"], ["+62", "Indonesia"], ["+63", "Philippines"], ["+66", "Thailand"], ["+84", "Vietnam"],
	["+81", "Japan"], ["+82", "South Korea"], ["+86", "China"], ["+852", "Hong Kong"], ["+49", "Germany"],
	["+33", "France"], ["+34", "Spain"], ["+39", "Italy"], ["+31", "Netherlands"], ["+971", "UAE"],
	["+55", "Brazil"], ["+52", "Mexico"], ["+1", "Canada"], ["+27", "South Africa"], ["+234", "Nigeria"], ["+64", "New Zealand"],
]
const MAX_INTERESTS := 10

var params := {}
var step := 0
var _valid: Callable = func() -> bool: return true
var _codes := {"phone": "", "email": ""}
var _resend_at := 0.0
var _resend_btn: Button
var _code_edit: LineEdit
var _focus: Control
var _advancing := false

var _column: VBoxContainer
var _title: Label
var _subtitle: Label
var _content: VBoxContainer
var _error: Label
var _continue: Button
var _progress: ProgressBar
var _file_dialog: FileDialog
var _page_scroll: ScrollContainer
var _photo_grid: GridContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(Background.new())

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 36)
	margin.add_theme_constant_override("margin_top", 26)
	margin.add_theme_constant_override("margin_bottom", 26)
	add_child(margin)
	var outer := VBoxContainer.new()
	margin.add_child(outer)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 22)
	outer.add_child(top)
	var back := UI.button("‹  Back", "TextButton")
	back.pressed.connect(_prev)
	top.add_child(back)
	_progress = ProgressBar.new()
	_progress.show_percentage = false
	_progress.max_value = STEPS.size()
	_progress.custom_minimum_size.y = 6
	_progress.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_progress.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(_progress)
	var brand := UI.nowrap(UI.label("Somewhere", 20, UI.MUTED))
	brand.add_theme_font_override("font", UI.serif(400, true))
	top.add_child(brand)

	# The page scrolls when it's taller than the window (small laptops, the browser);
	# Continue stays pinned at the bottom so it's always reachable.
	_page_scroll = ScrollContainer.new()
	_page_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_page_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(_page_scroll)
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_page_scroll.add_child(center)
	_column = VBoxContainer.new()
	_column.custom_minimum_size.x = 580
	_column.add_theme_constant_override("separation", 12)
	center.add_child(_column)
	_title = UI.title("", 42)
	_column.add_child(_title)
	_subtitle = UI.label("", 17, UI.MUTED)
	_column.add_child(_subtitle)
	var gap := Control.new()
	gap.custom_minimum_size.y = 14
	_column.add_child(gap)
	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", 14)
	_column.add_child(_content)
	_error = UI.label("", 15, UI.ROSE.lightened(0.2))
	_column.add_child(_error)
	_continue = UI.button("Continue", "PrimaryButton")
	_continue.custom_minimum_size = Vector2(580, 58)
	_continue.pressed.connect(_next)
	var bottom := CenterContainer.new()
	bottom.custom_minimum_size.y = 72
	outer.add_child(bottom)
	bottom.add_child(_continue)

	_file_dialog = FileDialog.new()
	_file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILES
	_file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_file_dialog.use_native_dialog = true
	_file_dialog.title = "Choose photos"
	_file_dialog.filters = PackedStringArray(["*.png, *.jpg, *.jpeg, *.webp ; Images"])
	_file_dialog.files_selected.connect(_on_photos_chosen)
	_file_dialog.file_selected.connect(func(p: String): _on_photos_chosen(PackedStringArray([p])))
	add_child(_file_dialog)

	step = clampi(int(params.get("step", 0)), 0, STEPS.size() - 1)
	_show_step()


func _process(_delta: float) -> void:
	if _resend_btn and is_instance_valid(_resend_btn):
		var left := ceili(_resend_at - Time.get_ticks_msec() / 1000.0)
		_resend_btn.disabled = left > 0
		_resend_btn.text = "Resend code in %ds" % left if left > 0 else "Didn't get it? Resend code"


# --- Flow -------------------------------------------------------------------

func _show_step() -> void:
	for c in _content.get_children():
		c.queue_free()
	_page_scroll.scroll_vertical = 0
	_error.text = ""
	_resend_btn = null
	_code_edit = null
	_focus = null
	_advancing = false
	_valid = func() -> bool: return true
	_continue.text = "Continue"
	create_tween().tween_property(_progress, "value", step + 1, 0.4)
	call("_step_" + STEPS[step])
	_refresh()
	_column.modulate.a = 0.0
	create_tween().tween_property(_column, "modulate:a", 1.0, 0.35)
	if _focus:
		_focus.call_deferred("grab_focus")


func _refresh(_unused = null) -> void:
	_continue.disabled = not _valid.call()


func _next() -> void:
	if not _valid.call():
		return
	match STEPS[step]:
		"phone": _send_code("phone")
		"email": _send_code("email")
	Profile.save()
	if step == STEPS.size() - 1:
		get_parent().go("map" if params.get("edit", false) else "avatar")
		return
	step += 1
	_show_step()


func _prev() -> void:
	if step == 0 or (params.get("edit", false) and step <= 9):
		get_parent().go("map" if params.get("edit", false) else "landing")
		return
	step -= 1
	if STEPS[step].ends_with("_code"):
		step -= 1
	_show_step()


func _privacy(text: String) -> void:
	var l := UI.label("Private  ·  " + text, 13, UI.FAINT)
	_content.add_child(l)


func _heading(title: String, subtitle: String) -> void:
	_title.text = title
	_subtitle.text = subtitle


func _line(placeholder: String, value: String, on_change: Callable) -> LineEdit:
	var e := LineEdit.new()
	e.placeholder_text = placeholder
	e.text = value
	e.text_changed.connect(func(tx: String) -> void:
		on_change.call(tx)
		_refresh())
	e.text_submitted.connect(func(_tx: String) -> void: _next())
	_content.add_child(e)
	return e


func _chips(options: Array, selected: Array, multi: bool, on_toggle: Callable, stacked := false) -> Container:
	var box: Container
	if stacked:
		box = VBoxContainer.new()
		box.add_theme_constant_override("separation", 10)
	else:
		box = HFlowContainer.new()
		box.add_theme_constant_override("h_separation", 10)
		box.add_theme_constant_override("v_separation", 10)
	var group: ButtonGroup = null if multi else ButtonGroup.new()
	for opt in options:
		var b := UI.chip(opt)
		if group:
			b.button_group = group
		b.button_pressed = opt in selected
		if stacked:
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT
			b.custom_minimum_size.y = 58
			b.add_theme_font_size_override("font_size", 18)
		b.toggled.connect(func(on: bool) -> void:
			on_toggle.call(opt, on)
			_refresh())
		box.add_child(b)
	_content.add_child(box)
	return box


static func _digits(s: String) -> String:
	var out := ""
	for ch in s:
		if ch >= "0" and ch <= "9":
			out += ch
	return out


func _pretty_phone() -> String:
	var p: String = Profile.data.phone
	if p.length() == 8:
		return p.substr(0, 4) + " " + p.substr(4)
	return p


# --- Verification codes (simulated) -------------------------------------------

func _send_code(kind: String) -> void:
	var code := "%06d" % randi_range(0, 999999)
	_codes[kind] = code
	_resend_at = Time.get_ticks_msec() / 1000.0 + 30.0
	var pretty := code.substr(0, 3) + " " + code.substr(3)
	if kind == "phone":
		UI.banner(self, "MESSAGES", "Somewhere: %s is your verification code. Don't share it with anyone." % pretty, _autofill.bind(kind))
	else:
		UI.banner(self, "MAIL  ·  Somewhere", "Confirm your email. Your code is %s" % pretty, _autofill.bind(kind))


func _autofill(kind: String) -> void:
	if _code_edit and is_instance_valid(_code_edit) and STEPS[step] == kind + "_code":
		_code_edit.text = _codes[kind]
		_code_edit.text_changed.emit(_code_edit.text)


func _code_step(kind: String, title: String, subtitle: String) -> void:
	_heading(title, subtitle)
	if _codes[kind] == "":
		_send_code(kind)
	var e := LineEdit.new()
	e.max_length = 6
	e.placeholder_text = "000000"
	e.alignment = HORIZONTAL_ALIGNMENT_CENTER
	e.add_theme_font_size_override("font_size", 42)
	e.add_theme_font_override("font", UI.spaced(500, 16))
	e.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER
	e.text_changed.connect(func(tx: String) -> void:
		var d := _digits(tx)
		if d != tx:
			e.text = d
			e.caret_column = d.length()
		_error.text = "That code doesn't match. Check it and try again." if d.length() == 6 and d != _codes[kind] else ""
		_refresh()
		if d == _codes[kind] and not _advancing:
			_advancing = true
			Profile.data[kind + "_verified"] = true
			_continue.text = "Verified ✓"
			get_tree().create_timer(0.6).timeout.connect(_next))
	_content.add_child(e)
	_code_edit = e
	_focus = e
	_resend_btn = UI.button("Resend code", "TextButton")
	_resend_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_resend_btn.pressed.connect(_send_code.bind(kind))
	_content.add_child(_resend_btn)
	_content.add_child(UI.label("Prototype: codes are simulated. Tap the notification to fill yours in.", 13, UI.FAINT))
	_valid = func() -> bool: return _codes[kind] != "" and e.text == _codes[kind]
	_continue.text = "Verify"


# --- Steps ------------------------------------------------------------------

func _step_name() -> void:
	_heading("What's your first name?", "This is how you'll appear on Somewhere.")
	var e := _line("First name", Profile.data.name, func(tx: String) -> void:
		Profile.data.name = tx.strip_edges()
		_error.text = Validate.name_error(tx) if tx.strip_edges() != "" else "")
	e.max_length = Validate.MAX_NAME
	_focus = e
	_valid = func() -> bool: return Validate.name_error(Profile.data.name) == ""


func _handle_taken(h: String) -> bool:
	for n in People.NAMES:
		if n[0].to_lower() == h:
			return true
	return h in Profile.data.get("taken_handles", [])


func _step_handle() -> void:
	_heading("Pick a handle", "It's how friends find you. Your name stays on your profile; your handle is your address.")
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 0)
	_content.add_child(row)
	var at := UI.label("@", 22, UI.MUTED)
	at.custom_minimum_size.x = 26
	row.add_child(at)
	var e := LineEdit.new()
	e.placeholder_text = "yourname"
	e.max_length = 20
	e.text = Profile.data.get("handle", "")
	e.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(e)
	var status := UI.label("", 15, UI.SAGE)
	_content.add_child(status)
	var check := func(h: String) -> void:
		var err := Validate.handle_error(h)
		status.text = ""
		_error.text = ""
		if h == "":
			return
		if err != "":
			_error.text = err
		elif _handle_taken(h):
			_error.text = "@%s is taken. Try one of these?" % h
		else:
			status.text = "✓  @%s is yours" % h
	e.text_changed.connect(func(tx: String) -> void:
		var clean := tx.to_lower().replace(" ", "")
		if clean != tx:
			e.text = clean
			e.caret_column = clean.length()
		Profile.data.handle = clean
		check.call(clean)
		_refresh())
	e.text_submitted.connect(func(_t: String) -> void: _next())
	_content.add_child(UI.eyebrow("Suggestions"))
	var base: String = Profile.data.name.to_lower().replace(" ", "").replace("'", "").replace("-", "")
	var ideas := [base, base + ".somewhere", base + "_by_the_sea", base + str(randi_range(10, 99)), "its." + base]
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 8)
	flow.add_theme_constant_override("v_separation", 8)
	_content.add_child(flow)
	for idea in ideas:
		if Validate.handle_error(idea) != "" or _handle_taken(idea):
			continue
		var b := UI.button("@" + idea, "Chip")
		b.pressed.connect(func() -> void:
			e.text = idea
			e.text_changed.emit(idea))
		flow.add_child(b)
	_focus = e
	check.call(e.text)
	_valid = func() -> bool:
		var h: String = Profile.data.get("handle", "")
		return Validate.handle_error(h) == "" and not _handle_taken(h)


func _step_phone() -> void:
	_heading("What's your number?", "We'll text you a code to check it's really you. Your number is never shown on your profile.")
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	_content.add_child(row)
	var cc := OptionButton.new()
	cc.custom_minimum_size.x = 150
	cc.fit_to_longest_item = false
	cc.clip_text = true
	for i in COUNTRIES.size():
		cc.add_item("%s   %s" % COUNTRIES[i], i)
	cc.selected = int(Profile.data.dial_index)
	cc.item_selected.connect(func(i: int) -> void:
		Profile.data.dial_index = i
		Profile.data.dial = COUNTRIES[i][0])
	row.add_child(cc)
	var e := LineEdit.new()
	e.placeholder_text = "Phone number"
	e.text = Profile.data.phone
	e.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	e.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_PHONE
	e.max_length = 16
	e.text_changed.connect(func(tx: String) -> void:
		Profile.data.phone = Validate.normalise_phone(_digits(tx))
		_error.text = Validate.phone_error(Profile.data.dial, Profile.data.phone) if _digits(tx).length() >= 6 else ""
		_refresh())
	e.text_submitted.connect(func(_tx: String) -> void: _next())
	row.add_child(e)
	_privacy("Private. Never shown to anyone.")
	_focus = e
	_valid = func() -> bool: return Validate.phone_error(Profile.data.dial, Profile.data.phone) == ""
	_continue.text = "Send code"


func _step_phone_code() -> void:
	_code_step("phone", "Enter your code", "We texted a 6-digit code to %s %s." % [Profile.data.dial, _pretty_phone()])


func _step_email() -> void:
	_heading("What's your email?", "We'll send a code to confirm it. We only email when it matters.")
	var e := _line("you@example.com", Profile.data.email, func(tx: String) -> void: Profile.data.email = tx.strip_edges().to_lower())
	e.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_EMAIL_ADDRESS
	_focus = e
	e.max_length = Validate.MAX_EMAIL
	e.text_changed.connect(func(tx: String) -> void:
		_error.text = Validate.email_error(tx.strip_edges().to_lower()) if "@" in tx and "." in tx.get_slice("@", 1) else "")
	_privacy("Private. Only used to sign in and keep your account safe.")
	_valid = func() -> bool: return Validate.email_error(Profile.data.email) == ""
	_continue.text = "Send code"


func _step_email_code() -> void:
	_code_step("email", "Check your inbox", "We sent a 6-digit code to %s." % Profile.data.email)


func _step_birthday() -> void:
	_heading("When's your birthday?", "Your profile shows your age, never your birthday.")
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	_content.add_child(row)
	var age_label := UI.label("", 16, UI.MUTED)
	var fields := [["d", "DD", 2, 120.0], ["m", "MM", 2, 120.0], ["y", "YYYY", 4, 170.0]]
	var edits: Array[LineEdit] = []
	for f in fields:
		var e := LineEdit.new()
		e.placeholder_text = f[1]
		e.max_length = f[2]
		e.custom_minimum_size.x = f[3]
		e.alignment = HORIZONTAL_ALIGNMENT_CENTER
		e.text = Profile.data.birthday[f[0]]
		e.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER
		row.add_child(e)
		edits.append(e)
	for i in edits.size():
		var e := edits[i]
		var key: String = fields[i][0]
		var max_len: int = fields[i][2]
		e.text_changed.connect(func(tx: String) -> void:
			var d := _digits(tx)
			if d != tx:
				e.text = d
				e.caret_column = d.length()
			Profile.data.birthday[key] = d
			if d.length() == max_len and i < edits.size() - 1:
				edits[i + 1].grab_focus()
			var b: Dictionary = Profile.data.birthday
			_error.text = Validate.birthday_error(b.d, b.m, b.y)
			age_label.text = ""
			if _error.text == "" and Profile.age() >= 18:
				age_label.text = "You're %d." % Profile.age()
			_refresh())
		e.text_submitted.connect(func(_tx: String) -> void: _next())
	_content.add_child(age_label)
	_focus = edits[0]
	_privacy("Private. Only your age is shown.")
	_valid = func() -> bool:
		var b: Dictionary = Profile.data.birthday
		return Profile.age() >= 18 and Validate.birthday_error(b.d, b.m, b.y) == ""


func _step_gender() -> void:
	_heading("Which best describes you?", "Everyone is welcome here. You decide what shows on your profile.")
	var options := ["Woman", "Man", "Non-binary", "I'd rather describe it"]
	var custom := LineEdit.new()
	custom.placeholder_text = "How do you describe your gender?"
	custom.text = Profile.data.gender_custom
	custom.visible = Profile.data.gender == options[3]
	custom.max_length = 30
	custom.text_changed.connect(func(tx: String) -> void:
		Profile.data.gender_custom = tx.strip_edges()
		_refresh())
	_chips(options, [Profile.data.gender], false, func(opt: String, on: bool) -> void:
		if on:
			Profile.data.gender = opt
			custom.visible = opt == options[3])
	_content.add_child(custom)
	var gap := Control.new()
	gap.custom_minimum_size.y = 6
	_content.add_child(gap)
	_content.add_child(UI.eyebrow("Pronouns (optional)"))
	_chips(["she/her", "he/him", "they/them", "ask me"], Profile.data.pronouns, true, func(opt: String, on: bool) -> void:
		if on and not opt in Profile.data.pronouns:
			Profile.data.pronouns.append(opt)
		elif not on:
			Profile.data.pronouns.erase(opt))
	_valid = func() -> bool:
		if Profile.data.gender == "":
			return false
		return Profile.data.gender != options[3] or Profile.data.gender_custom.strip_edges() != ""


func _step_show_me() -> void:
	_heading("Who would you like to meet?", "Somewhere is for every kind of connection. Choose all that apply.")
	var toggle := func(opt: String, on: bool) -> void:
		if on and not opt in Profile.data.show_me:
			Profile.data.show_me.append(opt)
		elif not on:
			Profile.data.show_me.erase(opt)
	_chips(["Women", "Men", "Non-binary people", "Everyone"], Profile.data.show_me, true, toggle, true)
	_valid = func() -> bool: return Profile.data.show_me.size() > 0


func _step_orientation() -> void:
	_heading("Your sexual orientation", "Optional. It helps people know you'd be into them, and you into them.")
	_chips(UI.ORIENTATIONS, [Profile.data.get("orientation", "")], false, func(opt: String, on: bool) -> void:
		if on:
			Profile.data.orientation = opt
			_refresh())
	var gap := Control.new()
	gap.custom_minimum_size.y = 6
	_content.add_child(gap)
	var show := CheckButton.new()
	show.text = "Show my pride flag on my name tag"
	show.button_pressed = Profile.data.get("show_flag", true)
	show.add_theme_font_size_override("font_size", 16)
	show.toggled.connect(func(on: bool) -> void: Profile.data.show_flag = on)
	_content.add_child(show)
	_content.add_child(UI.label("Your flag and pronouns sit above your avatar's head. Turn the flag off any time; you can also skip this.", 13, UI.FAINT))
	_valid = func() -> bool: return true


func _step_intent() -> void:
	_heading("What brings you here?", "This helps the Breeze know which strings to tie. You can change it any time.")
	var pick := func(opt: String, on: bool) -> void:
		if on:
			Profile.data.intent = opt
	_chips(["Something long-term", "Something casual", "New friends", "Still figuring it out"], [Profile.data.intent], false, pick, true)
	_valid = func() -> bool: return Profile.data.intent != ""


func _step_interests() -> void:
	_heading("What are you into?", "Pick 3 to 10 from the list. Search to find them faster. Places that match will glow for you on the map.")
	var search := LineEdit.new()
	search.placeholder_text = "Search: climbing, jazz, dumplings..."
	search.clear_button_enabled = true
	search.add_theme_font_size_override("font_size", 17)
	_content.add_child(search)
	var picked := HFlowContainer.new()
	picked.add_theme_constant_override("h_separation", 6)
	picked.add_theme_constant_override("v_separation", 6)
	_content.add_child(picked)
	var counter := UI.label("", 13, UI.MUTED)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.y = 290
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_content.add_child(scroll)
	var inner := VBoxContainer.new()
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner.add_theme_constant_override("separation", 10)
	scroll.add_child(inner)
	_content.add_child(counter)

	var toggle := func(item: String, on: bool) -> bool:
		_error.text = ""
		if on and Profile.data.interests.size() >= MAX_INTERESTS:
			_error.text = "That's %d. Unselect one to pick another." % MAX_INTERESTS
			return false
		if on and not item in Profile.data.interests:
			Profile.data.interests.append(item)
		elif not on:
			Profile.data.interests.erase(item)
		return true
	# Held in an array so the chips' callbacks always reach the real rebuild (lambdas copy plain variables).
	var rebuild_ref := [null]
	var rebuild := func(query: String) -> void:
		for c in inner.get_children():
			c.queue_free()
		for c in picked.get_children():
			c.queue_free()
		for item in Profile.data.interests:
			var x := UI.button(item + "   ×", "Chip")
			x.add_theme_stylebox_override("normal", UI.box(UI.CREAM, 12, Color(0, 0, 0, 0), 0, 14, 7))
			x.add_theme_color_override("font_color", UI.INK)
			x.add_theme_color_override("font_hover_color", UI.INK)
			x.pressed.connect(func() -> void:
				toggle.call(item, false)
				rebuild_ref[0].call(search.text)
				_refresh())
			picked.add_child(x)
		var q := query.strip_edges().to_lower()
		var found := 0
		for g in Profile.INTEREST_GROUPS:
			var items: Array = g.items.filter(func(i) -> bool: return q == "" or q in i.to_lower() or q in g.title.to_lower())
			if items.is_empty():
				continue
			inner.add_child(UI.eyebrow(g.title, Profile.CATEGORIES[g.cat].color))
			var flow := HFlowContainer.new()
			flow.add_theme_constant_override("h_separation", 8)
			flow.add_theme_constant_override("v_separation", 8)
			inner.add_child(flow)
			for item in items:
				found += 1
				var b := UI.chip(item)
				b.button_pressed = item in Profile.data.interests
				b.toggled.connect(func(on: bool) -> void:
					if not toggle.call(item, on):
						b.set_pressed_no_signal(false)
					rebuild_ref[0].call(search.text)
					_refresh())
				flow.add_child(b)
		if found == 0:
			inner.add_child(UI.label("Nothing matches \"%s\". Try another word; you can pick from the list below once you clear the search." % query.strip_edges(), 14, UI.FAINT))
		var n: int = Profile.data.interests.size()
		counter.text = "%d of %d selected%s" % [n, MAX_INTERESTS, "  ·  pick at least %d more" % (3 - n) if n < 3 else "  ✓"]
		counter.add_theme_color_override("font_color", UI.SAGE if n >= 3 else UI.MUTED)
	rebuild_ref[0] = rebuild
	search.text_changed.connect(func(tx: String) -> void: rebuild.call(tx))
	rebuild.call("")
	_focus = search
	_valid = func() -> bool: return Profile.data.interests.size() >= 3


func _step_prompt() -> void:
	_heading("Give them something to talk about", "Pick a prompt and answer it your way. Totally optional.")
	var opt := OptionButton.new()
	for p in Profile.PROMPT_TEXT:
		opt.add_item(p)
	opt.selected = int(Profile.data.prompt_q)
	opt.item_selected.connect(func(i: int) -> void: Profile.data.prompt_q = i)
	_content.add_child(opt)
	var te := TextEdit.new()
	te.placeholder_text = "Your answer"
	te.custom_minimum_size.y = 140
	te.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	te.text = Profile.data.prompt_a
	te.add_theme_font_size_override("font_size", 19)
	_content.add_child(te)
	var count := UI.label("", 13, UI.FAINT)
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_content.add_child(count)
	var update := func() -> void:
		count.text = "%d / 150" % te.text.length()
		_continue.text = "Continue" if te.text.strip_edges() != "" else "Skip for now"
	te.text_changed.connect(func() -> void:
		if te.text.length() > 150:
			te.text = te.text.left(150)
			te.set_caret_column(150)
		Profile.data.prompt_a = te.text
		update.call())
	update.call()
	_focus = te


func _step_photos() -> void:
	_heading("Add your photos", "Add at least 2. They help shape your avatar, and they're only shared when you choose to follow a string.")
	_photo_grid = GridContainer.new()
	_photo_grid.columns = 3
	_photo_grid.add_theme_constant_override("h_separation", 12)
	_photo_grid.add_theme_constant_override("v_separation", 12)
	_content.add_child(_photo_grid)
	_build_photo_grid()
	_content.add_child(UI.label("Tip: clear, recent photos where we can see your face work best.", 14, UI.FAINT))
	_valid = func() -> bool: return Profile.photos.size() >= 2
	_continue.text = "Create my avatar"


func _build_photo_grid() -> void:
	for c in _photo_grid.get_children():
		c.queue_free()
	for i in Profile.MAX_PHOTOS:
		var slot := Button.new()
		slot.custom_minimum_size = Vector2(185, 220)
		slot.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var empty := UI.box(Color(1, 1, 1, 0.05), 20, Color(1, 1, 1, 0.18), 1)
		for st in ["normal", "pressed", "focus"]:
			slot.add_theme_stylebox_override(st, empty)
		slot.add_theme_stylebox_override("hover", UI.box(Color(1, 1, 1, 0.08), 20, Color(UI.CREAM, 0.5), 1))
		if i < Profile.photos.size():
			var mask := Panel.new()
			mask.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			mask.add_theme_stylebox_override("panel", UI.box(Color.WHITE, 20))
			mask.clip_children = CanvasItem.CLIP_CHILDREN_ONLY
			mask.mouse_filter = Control.MOUSE_FILTER_IGNORE
			slot.add_child(mask)
			var tr := TextureRect.new()
			tr.texture = Profile.photos[i]
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
			tr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
			mask.add_child(tr)
			var remove := UI.button("×")
			remove.add_theme_font_size_override("font_size", 13)
			for st in ["normal", "hover", "pressed"]:
				remove.add_theme_stylebox_override(st, UI.box(Color(0, 0, 0, 0.55), 14, Color(0, 0, 0, 0), 0, 9, 4))
			remove.anchor_left = 1.0
			remove.anchor_right = 1.0
			remove.offset_left = -40
			remove.offset_top = 8
			remove.offset_right = -8
			remove.pressed.connect(func() -> void:
				Profile.remove_photo(i)
				_build_photo_grid()
				_refresh())
			slot.add_child(remove)
			if i == 0:
				var main := UI.pill("Main", UI.CREAM)
				main.position = Vector2(10, 186)
				main.mouse_filter = Control.MOUSE_FILTER_IGNORE
				slot.add_child(main)
		else:
			slot.text = "+"
			slot.add_theme_font_size_override("font_size", 36)
			slot.add_theme_color_override("font_color", Color(UI.CREAM, 0.5))
			slot.pressed.connect(_pick_photos)
		_photo_grid.add_child(slot)


func _pick_photos() -> void:
	if OS.has_feature("web"):
		load("res://scripts/web_files.gd").pick_images(func(bytes: PackedByteArray, mime: String) -> void:
			if not Profile.add_photo_bytes(bytes, mime):
				_error.text = "That photo couldn't be added. Try a JPG or PNG under 15 MB."
			_build_photo_grid()
			_refresh())
	else:
		_file_dialog.popup_centered()


func _on_photos_chosen(paths: PackedStringArray) -> void:
	for p in paths:
		if Profile.photos.size() >= Profile.MAX_PHOTOS:
			break
		if not Profile.add_photo(p):
			_error.text = "We couldn't open %s. Try a JPG or PNG." % p.get_file()
	_build_photo_grid()
	_refresh()
