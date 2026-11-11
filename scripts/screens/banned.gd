extends Control
## Shown when an account reaches three ghosting strikes.

const UI = preload("res://scripts/ui.gd")
const Background = preload("res://scripts/background.gd")

var params := {}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(Background.new())
	var v := VBoxContainer.new()
	v.anchor_left = 0.5
	v.anchor_right = 0.5
	v.anchor_top = 0.5
	v.anchor_bottom = 0.5
	v.offset_left = -300
	v.offset_right = 300
	v.offset_top = -180
	v.offset_bottom = 180
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 14)
	add_child(v)
	v.add_child(UI.eyebrow("Account closed", UI.ROSE))
	v.add_child(UI.title("Three strikes.", 46))
	v.add_child(UI.label("People were left waiting without a reply three times, even after reminders. To keep Somewhere kind for everyone, this account has been closed.", 16, UI.MUTED))
	v.add_child(UI.label("If you think this was a mistake, contact support from the website.", 14, UI.FAINT))
