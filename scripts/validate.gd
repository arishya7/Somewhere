extends RefCounted
## Data boundaries for everything a person types in. Each check returns "" when the value
## is fine, or a short, kind message saying what to change. The relay server uses these too.

const RESERVED_HANDLES := ["admin", "somewhere", "breeze", "support", "help", "official", "moderator", "staff", "system", "null"]

## Expected national number length (without the leading 0) for each dial code.
const PHONE_LENGTHS := {
	"+65": [8, 8], "+1": [10, 10], "+44": [10, 10], "+61": [9, 9], "+91": [10, 10], "+60": [9, 10],
	"+62": [9, 12], "+63": [10, 10], "+66": [9, 9], "+84": [9, 10], "+81": [10, 10], "+82": [9, 10],
	"+86": [11, 11], "+852": [8, 8], "+49": [10, 11], "+33": [9, 9], "+34": [9, 9], "+39": [9, 10],
	"+31": [9, 9], "+971": [9, 9], "+55": [10, 11], "+52": [10, 10], "+27": [9, 9], "+234": [10, 10], "+64": [8, 10],
}

const MAX_NAME := 30
const MAX_EMAIL := 254
const MAX_PROMPT := 150
const MAX_MESSAGE := 1000
const MAX_PHOTO_BYTES := 20 * 1024 * 1024
const MIN_PHOTO_SIDE := 300


static func name_error(s: String) -> String:
	var t := s.strip_edges()
	if t.is_empty():
		return "Add your first name."
	if t.length() > MAX_NAME:
		return "Keep it under %d characters." % MAX_NAME
	if RegEx.create_from_string("^[\\p{L}][\\p{L}\\p{M}' \\-]*$").search(t) == null:
		return "Use letters only (spaces, hyphens and apostrophes are fine)."
	return ""


static func handle_error(h: String) -> String:
	if h.length() < 3:
		return "At least 3 characters."
	if h.length() > 20:
		return "20 characters at most."
	if RegEx.create_from_string("^[a-z0-9_.]+$").search(h) == null:
		return "Lowercase letters, numbers, dots and underscores only."
	if h.begins_with(".") or h.ends_with(".") or ".." in h:
		return "Dots can't be at the start, the end, or next to each other."
	if h in RESERVED_HANDLES:
		return "That one's reserved. Try another."
	return ""


## Returns the national number with any leading trunk 0 removed.
static func normalise_phone(digits: String) -> String:
	return digits.trim_prefix("0") if digits.begins_with("0") else digits


static func phone_error(dial: String, digits: String) -> String:
	var n := normalise_phone(digits)
	var lens: Array = PHONE_LENGTHS.get(dial, [6, 15])
	if n.length() < lens[0] or n.length() > lens[1]:
		if lens[0] == lens[1]:
			return "Numbers for %s have %d digits." % [dial, lens[0]]
		return "Numbers for %s have %d to %d digits." % [dial, lens[0], lens[1]]
	return ""


static func email_error(e: String) -> String:
	if e.length() > MAX_EMAIL:
		return "That email is too long."
	var at := e.find("@")
	if at < 1 or at > 64:
		return "That doesn't look like an email yet."
	if RegEx.create_from_string("^[a-z0-9._%+\\-]+@[a-z0-9\\-]+(\\.[a-z0-9\\-]+)*\\.[a-z]{2,}$").search(e) == null:
		return "That doesn't look like an email yet."
	return ""


static func days_in_month(m: int, y: int) -> int:
	if m == 2:
		return 29 if (y % 4 == 0 and y % 100 != 0) or y % 400 == 0 else 28
	return 30 if m in [4, 6, 9, 11] else 31


## Age for a birthday, or -1 if it isn't a real date in the past.
static func age(d: int, m: int, y: int) -> int:
	var now := Time.get_date_dict_from_system()
	if m < 1 or m > 12 or y < 1900 or d < 1 or d > days_in_month(m, y):
		return -1
	var years: int = now.year - y
	if now.month < m or (now.month == m and now.day < d):
		years -= 1
	return years if years >= 0 else -1


static func birthday_error(d: String, m: String, y: String) -> String:
	if d.length() == 0 or m.length() == 0 or y.length() < 4:
		return ""
	var a := age(int(d), int(m), int(y))
	if a < 0:
		return "That date doesn't exist."
	if a < 18:
		return "You need to be 18 or older to join Somewhere."
	if a > 99:
		return "Double-check the year."
	return ""


static func text_error(t: String, max_len: int) -> String:
	if t.length() > max_len:
		return "Keep it under %d characters." % max_len
	return ""
