extends RefCounted
## A tiny synthesiser: renders short melodies and beats into playable audio streams.

const RATE := 22050


static func _wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		bytes.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 30000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = bytes
	return w


static func _osc(wave: String, phase: float) -> float:
	match wave:
		"square":
			return 0.6 if fmod(phase, 1.0) < 0.5 else -0.6
		"triangle":
			return 4.0 * absf(fmod(phase, 1.0) - 0.5) - 1.0
		"saw":
			return 2.0 * fmod(phase, 1.0) - 1.0
	return sin(phase * TAU)


## notes: [[midi_note or -1 for rest, beats], ...]
static func melody(notes: Array, bpm: float, wave := "sine", volume := 0.35) -> AudioStreamWAV:
	var beat := 60.0 / bpm
	var total := 0.0
	for n in notes:
		total += n[1] * beat
	var out := PackedFloat32Array()
	out.resize(int(total * RATE) + RATE / 4)
	var at := 0
	for n in notes:
		var length := int(n[1] * beat * RATE)
		if n[0] >= 0:
			var freq := 440.0 * pow(2.0, (n[0] - 69) / 12.0)
			for i in length:
				var t := float(i) / RATE
				var env := minf(1.0, t / 0.01) * exp(-t * 2.5)
				out[at + i] += _osc(wave, t * freq) * env * volume
				out[at + i] += sin(t * freq * 0.5 * TAU) * env * volume * 0.25
		at += length
	return _wav(out)


## A simple four-on-the-floor beat with hats, for the dance floor.
static func beat(bpm: float, seconds: float) -> AudioStreamWAV:
	var out := PackedFloat32Array()
	out.resize(int(seconds * RATE))
	var step := 60.0 / bpm
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var t0 := 0.0
	var n := 0
	while t0 < seconds:
		var start := int(t0 * RATE)
		for i in int(0.18 * RATE):
			if start + i >= out.size():
				break
			var t := float(i) / RATE
			var f := lerpf(110.0, 40.0, minf(1.0, t / 0.12))
			out[start + i] += sin(t * f * TAU) * exp(-t * 18.0) * 0.8
		var hat := int((t0 + step / 2.0) * RATE)
		for i in int(0.04 * RATE):
			if hat + i >= out.size():
				break
			out[hat + i] += rng.randf_range(-1.0, 1.0) * exp(-float(i) / RATE * 90.0) * 0.18
		if n % 4 == 2:
			for i in int(0.12 * RATE):
				if start + i >= out.size():
					break
				out[start + i] += rng.randf_range(-1.0, 1.0) * exp(-float(i) / RATE * 30.0) * 0.25
		t0 += step
		n += 1
	return _wav(out)
