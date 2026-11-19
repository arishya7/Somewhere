extends SceneTree
## Bakes the synth music into res://audio/*.wav so the web build doesn't build sound live.
## Run: godot --headless --path . --script res://tools/bake_audio.gd

const Synth = preload("res://scripts/synth.gd")
const Activities = preload("res://scripts/ui/activities.gd")


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://audio"))
	for i in Activities.RECORDS.size():
		var r: Array = Activities.RECORDS[i]
		Synth.melody(r[4], r[2], r[3]).save_to_wav("res://audio/record_%d.wav" % i)
	Synth.beat(120.0, 22.0).save_to_wav("res://audio/club_beat.wav")
	print("baked ", Activities.RECORDS.size() + 1, " files")
	quit()
