extends RefCounted
## Procedural, layered avatars: semi-realistic proportions with soft painted shading.
## Origin is at the feet and a figure is about 300 units tall; callers pass a scale.

const SKIN := [
	Color("#F9E1CF"), Color("#F1CBB0"), Color("#E6B595"), Color("#D59E7C"), Color("#C08463"),
	Color("#A86E4C"), Color("#8A573A"), Color("#6C422B"), Color("#52301F"), Color("#3B2318"),
]
const HAIR := [
	Color("#16110F"), Color("#33231A"), Color("#5C3A24"), Color("#8A4B2A"), Color("#B5652F"), Color("#D2A86A"),
	Color("#E9DDC2"), Color("#9B9693"), Color("#D98AA6"), Color("#5468B8"), Color("#9C86D1"),
]
const EYES := [Color("#4A2E1C"), Color("#24170F"), Color("#7A6030"), Color("#4F7A4C"), Color("#4C7AB3"), Color("#7C8995")]
const CLOTH := [
	Color("#F3EEE6"), Color("#22222A"), Color("#2F4C7A"), Color("#8DB3DA"), Color("#B8352F"), Color("#E5A2B5"), Color("#EEC05A"),
	Color("#5E8C61"), Color("#2C4A3B"), Color("#7A5C99"), Color("#C9733C"), Color("#8A8A8F"), Color("#D8C4A5"), Color("#1F2D4A"),
]

const OPTIONS := {
	"body": ["Slim", "Average", "Broad", "Athletic", "Plus"],
	"height": ["Shorter", "Medium", "Taller"],
	"shape": ["Straight", "Curvy", "V-shape"],
	"face": ["Oval", "Round", "Square", "Heart"],
	"eyes": ["Almond", "Round", "Soft", "Wide"],
	"brows": ["Natural", "Arched", "Bold", "Straight"],
	"nose": ["Button", "Straight", "Broad"],
	"mouth": ["Smile", "Soft", "Grin", "Calm"],
	"hair": ["Bald", "Buzz", "Short", "Side part", "Curly", "Afro", "Bob", "Long", "Wavy", "Bun", "Ponytail", "Braids",
		"Crew cut", "Fade", "Quiff", "Curtains", "Slick back", "Man bun", "Locs", "Cornrows", "Twists", "Mullet"],
	"top": ["Tee", "Hoodie", "Shirt", "Tank", "Jacket", "Dress", "Sweater"],
	"bottom": ["Jeans", "Trousers", "Shorts", "Skirt"],
	"facial_hair": ["None", "Stubble", "Moustache", "Beard", "Goatee", "Full beard", "Long beard", "Chin strap"],
	"glasses": ["None", "Round", "Square"],
	"freckles": ["None", "Some"],
}
const COLOR_KEYS := {
	"skin": SKIN, "hair_color": HAIR, "eye_color": EYES, "brow_color": HAIR,
	"top_color": CLOTH, "bottom_color": CLOTH, "shoe_color": CLOTH,
}

const HEAD := Vector2(0, -252)
const CHEST := Vector2(0, -190)
## Grown-up, doll-like proportions: a head about a seventh of the height on a long adult body (feet at y = 0).
const HEAD_SCALE := 0.8
const NECK_Y := -224.0
const LIGHT := Vector2(-0.55, -0.83)
const NONE := Color(0, 0, 0, 0)


## A plain, unisex starting point: you shape it from here.
static func default_config() -> Dictionary:
	return {
		"body": 1, "height": 1, "face": 0, "eyes": 1, "brows": 0, "nose": 0, "mouth": 1, "hair": 1, "top": 0, "bottom": 1,
		"facial_hair": 0, "glasses": 0, "freckles": 0, "skin": 3, "hair_color": 1, "eye_color": 0,
		"top_color": 12, "bottom_color": 11, "shoe_color": 0,
	}


## presentation: "woman", "man" or "" (anyone). Keeps people reading the way they identify.
static func random_config(rng: RandomNumberGenerator = null, presentation := "") -> Dictionary:
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()
	var c := {}
	for k in OPTIONS:
		c[k] = rng.randi() % OPTIONS[k].size()
	for k in COLOR_KEYS:
		c[k] = rng.randi() % COLOR_KEYS[k].size()
	match presentation:
		"man":
			c.shape = [0, 2, 2][rng.randi() % 3]
			c.hair = [0, 1, 2, 3, 4, 5, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21][rng.randi() % 16]
			c.top = [0, 1, 2, 4, 6, 3][rng.randi() % 6]
			c.bottom = [0, 1, 2][rng.randi() % 3]
			c.brows = [0, 2, 3][rng.randi() % 3]
			if rng.randf() < 0.45: c.facial_hair = 0
		"woman":
			c.shape = [1, 1, 0][rng.randi() % 3]
			if c.top == 4 and rng.randf() < 0.5: c.top = 5
			c.hair = [4, 5, 6, 7, 8, 9, 10, 11, 7, 8, 15, 18, 20][rng.randi() % 13]
			c.facial_hair = 0
			c.brows = [0, 1, 1, 3][rng.randi() % 4]
		_:
			if rng.randf() < 0.7: c.facial_hair = 0
	if rng.randf() < 0.65: c.facial_hair = 0
	if rng.randf() < 0.7: c.glasses = 0
	if rng.randf() < 0.8: c.freckles = 0
	if rng.randf() < 0.8: c.hair_color = rng.randi() % 7
	if c.hair == 0 and rng.randf() < 0.7: c.hair = 2
	if c.top_color == c.bottom_color: c.bottom_color = (c.bottom_color + 3) % CLOTH.size()
	c.erase("brow_color") # brows follow the hair unless someone picks a colour in the studio
	return c


static func value(cfg: Dictionary, key: String) -> int:
	return int(cfg.get(key, 0))


static func color(cfg: Dictionary, key: String) -> Color:
	var arr: Array = COLOR_KEYS[key]
	return arr[clampi(value(cfg, key), 0, arr.size() - 1)]


# --- Public drawing -------------------------------------------------------

## Full figure. opts: "mono" (silhouette colour), "stride" (-1..1 walk pose).
static func draw(ci: CanvasItem, cfg: Dictionary, pos: Vector2, scale: float, t := 0.0, opts := {}) -> void:
	var mono: Color = opts.get("mono", NONE)
	var stride: float = opts.get("stride", 0.0)
	scale *= [0.95, 1.0, 1.05][clampi(value(cfg, "height"), 0, 2)]
	if mono.a == 0.0:
		ci.draw_set_transform(pos, 0.0, Vector2(scale, scale * 0.28))
		ci.draw_circle(Vector2.ZERO, 44.0, Color(0.12, 0.03, 0.1, 0.24))
	var bob := sin(t * 1.8) * 1.2
	# A big, friendly head: drawn in head space and scaled up onto the shoulders.
	var dims := _face_dims(cfg)
	var target := Vector2(0, NECK_Y - 3.0 - dims.y * HEAD_SCALE + bob * 0.4)
	var head_origin := pos + scale * (target - HEAD * HEAD_SCALE)
	# Hair that hangs down the back goes behind the body.
	ci.draw_set_transform(head_origin, 0.0, Vector2(scale, scale) * HEAD_SCALE)
	_hair(ci, cfg, HEAD, dims, "back", mono, false, t)
	ci.draw_set_transform(pos, 0.0, Vector2(scale, scale))
	_body(ci, cfg, t, stride, mono)
	ci.draw_set_transform(head_origin, 0.0, Vector2(scale, scale) * HEAD_SCALE)
	_head(ci, cfg, HEAD, dims, t, mono)
	_hair(ci, cfg, HEAD, dims, "front", mono, false, t)
	if mono.a == 0.0:
		_glasses(ci, cfg, HEAD, dims)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Seen from behind, sitting on a ledge: origin is the seat, legs hang out of view.
static func draw_back_sitting(ci: CanvasItem, cfg: Dictionary, pos: Vector2, scale: float, t := 0.0) -> void:
	ci.draw_set_transform(pos, 0.0, Vector2(scale, scale))
	var b := value(cfg, "body")
	var sw: float = [33.0, 38.0, 44.0, 46.0, 44.0][b]
	var hp: float = [30.0, 33.0, 36.0, 32.0, 43.0][b]
	var arm_w: float = [14.0, 16.0, 19.0, 19.0, 21.0][b]
	var skin := color(cfg, "skin")
	var tc := color(cfg, "top_color")
	var hc := color(cfg, "hair_color")
	var breathe := sin(t * 1.4) * 1.2
	var top := value(cfg, "top")
	# Hips and the bottoms on the ledge.
	_fill(ci, PackedVector2Array([Vector2(-hp - 4, -18), Vector2(hp + 4, -18), Vector2(hp + 8, 4), Vector2(-hp - 8, 4)]), color(cfg, "bottom_color"), 0.15)
	# Back.
	var back := PackedVector2Array([
		Vector2(-sw + 8, -118 + breathe), Vector2(sw - 8, -118 + breathe), Vector2(sw, -108 + breathe), Vector2(sw - 3, -80),
		Vector2(hp - 2, -40), Vector2(hp + 2, -14), Vector2(-hp - 2, -14), Vector2(-hp + 2, -40), Vector2(-sw + 3, -80), Vector2(-sw, -108 + breathe),
	])
	_fill(ci, back if top != 3 else back, tc if top != 3 else tc, 0.14)
	if top == 1:
		_fill(ci, _ell(Vector2(0, -112 + breathe), 22, 12), tc.darkened(0.15), 0.12)
	ci.draw_line(Vector2(0, -110 + breathe), Vector2(0, -24), Color(tc.darkened(0.25), 0.35), 1.5, true)
	# Arms resting back on the ledge.
	for s in [-1.0, 1.0]:
		var sh := Vector2(s * (sw - 6), -110 + breathe)
		var hand := Vector2(s * (sw + 16), -6)
		var sleeve_end: Vector2 = sh.lerp(hand, 0.45) if top in [0, 3, 5] else hand + Vector2(0, -8)
		_fill(ci, _limb(sh, hand, arm_w, arm_w * 0.75), skin, 0.12)
		if top != 3:
			_fill(ci, _limb(sh, sleeve_end, arm_w + 2, arm_w + 1), tc, 0.1)
		_fill(ci, _ell(hand + Vector2(0, 2), 7, 5, 14), skin.darkened(0.05), 0.15)
	# Neck and the back of the head.
	_fill(ci, _limb(Vector2(0, -140 + breathe), Vector2(0, -114 + breathe), 16, 19), skin.darkened(0.08), 0.1)
	var c := Vector2(0, -160 + breathe)
	var dims := _face_dims(cfg)
	# Same big, friendly head as standing: scale it up around the neck.
	var hk := 0.95
	var target := Vector2(0, -158 + breathe)
	ci.draw_set_transform(pos + scale * (target - c * hk), 0.0, Vector2(scale, scale) * hk)
	for s in [-1.0, 1.0]:
		_fill(ci, _ell(c + Vector2(s * (dims.x - 1.0), 4), 5.0, 8.0, 14), skin.darkened(0.08), 0.15)
	_fill(ci, _ell(c, dims.x, dims.y, 32), skin.darkened(0.04), 0.12)
	var style := value(cfg, "hair")
	if style != 0:
		_hair(ci, cfg, c, dims, "back", NONE, false, t)
		var cover := 0.55 if style == 1 else 0.85
		var pts := PackedVector2Array()
		for i in 25:
			var a := lerpf(PI - 0.35, TAU + 0.35, i / 24.0)
			pts.append(c + Vector2(cos(a) * (dims.x + 5), sin(a) * (dims.y + 5)))
		pts.append(c + Vector2(dims.x * 0.95, dims.y * cover))
		pts.append(c + Vector2(0, dims.y * (cover + 0.12)))
		pts.append(c + Vector2(-dims.x * 0.95, dims.y * cover))
		_fill(ci, pts, hc, 0.22)
		if style == 9:
			_fill(ci, _ell(Vector2(c.x, c.y - dims.y + 2), 15, 13, 20), hc, 0.3)
		ci.draw_arc(c, dims.y * 0.8, 1.15 * PI, 1.5 * PI, 10, Color(hc.lightened(0.4), 0.35), 3.0, true)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Head-and-shoulders disc, for map pins, toasts and profile chips.
static func draw_portrait(ci: CanvasItem, cfg: Dictionary, center: Vector2, radius: float, ring := Color(1, 1, 1, 0.85), t := 0.0) -> void:
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if ring.a > 0.0:
		ci.draw_circle(center, radius + maxf(1.5, radius * 0.1), ring)
	ci.draw_circle(center, radius, color(cfg, "top_color").darkened(0.45).lerp(Color("#2A1F3D"), 0.55))
	var sc := radius / 46.0
	ci.draw_set_transform(center - HEAD * sc + Vector2(0, radius * 0.08), 0.0, Vector2(sc, sc))
	var dims := _face_dims(cfg)
	var skin := color(cfg, "skin")
	_hair(ci, cfg, HEAD, dims, "back", NONE, true, t)
	_fill(ci, _limb(Vector2(0, -232), Vector2(0, -206), 14, 17), skin.darkened(0.12), 0.1)
	_head(ci, cfg, HEAD, dims, t, NONE)
	_hair(ci, cfg, HEAD, dims, "front", NONE, true, t)
	_glasses(ci, cfg, HEAD, dims)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# --- Geometry helpers -----------------------------------------------------

static func _ell(c: Vector2, rx: float, ry: float, n := 28) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var a := TAU * i / n
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	return pts


## A tapered capsule from a to b: limbs, sleeves, necks.
static func _limb(a: Vector2, b: Vector2, wa: float, wb: float) -> PackedVector2Array:
	var d := (b - a).normalized()
	var n := Vector2(-d.y, d.x)
	var pts := PackedVector2Array()
	var base := d.angle()
	for i in 9:
		var ang := base - PI / 2.0 + PI * i / 8.0
		pts.append(b + Vector2(cos(ang), sin(ang)) * wb * 0.5)
	for i in 9:
		var ang := base + PI / 2.0 + PI * i / 8.0
		pts.append(a + Vector2(cos(ang), sin(ang)) * wa * 0.5)
	return pts


## Fill with soft directional shading baked into the vertex colours.
static func _fill(ci: CanvasItem, pts: PackedVector2Array, col: Color, shade := 0.16, mono := NONE) -> void:
	if pts.size() < 3:
		return
	if mono.a > 0.0:
		ci.draw_colored_polygon(pts, mono)
		return
	var c := Vector2.ZERO
	for p in pts:
		c += p
	c /= pts.size()
	var r := 0.001
	for p in pts:
		r = maxf(r, (p - c).length())
	var l := LIGHT.normalized()
	var cols := PackedColorArray()
	for p in pts:
		var k := (p - c).dot(l) / r
		cols.append(col.lightened(k * shade) if k > 0.0 else col.darkened(-k * shade * 1.3))
	ci.draw_polygon(pts, cols)
	# A hairline anti-aliased edge in the same colours keeps every shape smooth.
	var edge := pts.duplicate()
	edge.append(pts[0])
	var edge_cols := cols.duplicate()
	edge_cols.append(cols[0])
	ci.draw_polyline_colors(edge, edge_cols, 1.2, true)


static func _face_dims(cfg: Dictionary) -> Vector2:
	return [Vector2(23.5, 30.5), Vector2(25, 29.5), Vector2(24.5, 30), Vector2(24, 30.5)][value(cfg, "face")]


static func _face_pts(c: Vector2, dims: Vector2, shape: int, n := 56) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var a := TAU * i / n
		var x := cos(a)
		var y := sin(a)
		if y > 0.0:
			match shape:
				0: x *= 1.0 - 0.34 * pow(y, 2.2)
				1: x *= 1.0 - 0.2 * pow(y, 2.0)
				2: x = signf(x) * pow(absf(x), 0.8) * (1.0 - 0.26 * pow(y, 3.0))
				3: x *= 1.0 - 0.46 * pow(y, 1.8)
		else:
			x *= 1.0 + 0.04 * y # a touch wider at the temples
		pts.append(c + Vector2(x * dims.x, y * dims.y))
	return pts


# --- Body -----------------------------------------------------------------

## 3D-style shading: a darker base, a lit middle and a soft highlight, offset toward the light.
## Gives every piece a rounded, lit-from-the-left look.
static func _shaded(ci: CanvasItem, pts: PackedVector2Array, col: Color, mono := NONE) -> void:
	if pts.size() < 3:
		return
	if mono.a > 0.0:
		ci.draw_colored_polygon(pts, mono)
		return
	var lo := pts[0]
	var hi := pts[0]
	for p in pts:
		lo = Vector2(minf(lo.x, p.x), minf(lo.y, p.y))
		hi = Vector2(maxf(hi.x, p.x), maxf(hi.y, p.y))
	var cx := (lo.x + hi.x) / 2.0
	var w := hi.x - lo.x
	# Many thin, faint layers build a smooth round gradient (no visible bands).
	ci.draw_colored_polygon(pts, col.darkened(0.16))
	for k in 8:
		var f := 0.94 - k * 0.11
		var inner := PackedVector2Array()
		for p in pts:
			inner.append(Vector2(cx + (p.x - cx) * f - w * 0.022 * k, p.y))
		ci.draw_colored_polygon(inner, Color(col.lightened(0.022 * k), 0.42 if k > 0 else 1.0))
	var edge := pts.duplicate()
	edge.append(pts[0])
	ci.draw_polyline(edge, Color(col.darkened(0.4), 0.35), 1.0, true)


## A shaded limb from a to b (widths at each end), lit from the left.
static func _shaded_limb(ci: CanvasItem, a: Vector2, b: Vector2, wa: float, wb: float, col: Color, mono := NONE) -> void:
	if mono.a > 0.0:
		ci.draw_colored_polygon(_limb(a, b, wa, wb), mono)
		return
	var d := (b - a).normalized()
	var n := Vector2(-d.y, d.x)
	if n.x > 0.0:
		n = -n # toward the light (left)
	# No outline, so joints (knees, elbows) blend into one smooth limb.
	ci.draw_colored_polygon(_limb(a, b, wa, wb), col.darkened(0.16))
	for k in 6:
		var f := 0.88 - k * 0.14
		var off := 0.03 * k
		ci.draw_colored_polygon(_limb(a + n * wa * off, b + n * wb * off, wa * f, wb * f), Color(col.lightened(0.025 * k), 0.45 if k > 0 else 1.0))


## One continuous limb through a joint (hip-knee-ankle, shoulder-elbow-wrist): no seam at the joint.
static func _limb3(a: Vector2, b: Vector2, c: Vector2, wa: float, wb: float, wc: float) -> PackedVector2Array:
	var n1 := (b - a).normalized().orthogonal()
	var n2 := (c - b).normalized().orthogonal()
	var nb := (n1 + n2).normalized()
	var pts := PackedVector2Array()
	var left := [a + n1 * wa * 0.5, a.lerp(b, 0.5) + n1 * (wa + wb) * 0.25, b + nb * wb * 0.5, b.lerp(c, 0.5) + n2 * (wb + wc) * 0.25, c + n2 * wc * 0.5]
	for p in left:
		pts.append(p)
	var base := (c - b).angle()
	for i in range(1, 8):
		var ang := base - PI / 2.0 + PI * i / 8.0
		pts.append(c + Vector2(cos(ang), sin(ang)) * wc * 0.5)
	var right := [c - n2 * wc * 0.5, b.lerp(c, 0.5) - n2 * (wb + wc) * 0.25, b - nb * wb * 0.5, a.lerp(b, 0.5) - n1 * (wa + wb) * 0.25, a - n1 * wa * 0.5]
	for p in right:
		pts.append(p)
	var top := (a - b).angle()
	for i in range(1, 8):
		var ang := top - PI / 2.0 + PI * i / 8.0
		pts.append(a + Vector2(cos(ang), sin(ang)) * wa * 0.5)
	return pts


static func _shaded_limb3(ci: CanvasItem, a: Vector2, b: Vector2, c: Vector2, wa: float, wb: float, wc: float, col: Color, mono := NONE) -> void:
	if mono.a > 0.0:
		ci.draw_colored_polygon(_limb3(a, b, c, wa, wb, wc), mono)
		return
	var n := Vector2(-1, 0) # light from the left
	ci.draw_colored_polygon(_limb3(a, b, c, wa, wb, wc), col.darkened(0.16))
	for k in 6:
		var f := 0.88 - k * 0.14
		var off := n * 0.03 * k
		ci.draw_colored_polygon(_limb3(a + off * wa, b + off * wb, c + off * wc, wa * f, wb * f, wc * f), Color(col.lightened(0.025 * k), 0.45 if k > 0 else 1.0))


## The torso outline from shoulders to the given hem.
## Rounds off a polygon's corners (Chaikin): smooth curves instead of sharp notches.
static func _smooth(pts: PackedVector2Array, passes := 2) -> PackedVector2Array:
	var out := pts
	for _p in passes:
		var nxt := PackedVector2Array()
		for i in out.size():
			var p0 := out[i]
			var p1 := out[(i + 1) % out.size()]
			nxt.append(p0.lerp(p1, 0.25))
			nxt.append(p0.lerp(p1, 0.75))
		out = nxt
	return out


## Torso outline: sloping shoulders, chest, waist, hips. `flare` turns it into a dress to the knee.
static func _torso_pts(sw: float, chest: float, waist: float, hp: float, sh_y: float, bottom_y: float, flare := false) -> PackedVector2Array:
	var right := [Vector2(8, sh_y - 2), Vector2(sw * 0.6, sh_y + 3), Vector2(sw - 2, sh_y + 10), Vector2(sw, sh_y + 20),
		Vector2(sw - 3, sh_y + 34), Vector2(chest, sh_y + 46)]
	if flare:
		right.append_array([Vector2(waist, -160), Vector2(hp + 2, -134), Vector2(hp + 9, -100), Vector2(hp + 16, -66)])
	else:
		for q in [Vector2(waist + 0.5, -166), Vector2(waist, -158), Vector2(waist + (hp - waist) * 0.55, -146), Vector2(hp, -132)]:
			if q.y < bottom_y:
				right.append(q)
		var last: Vector2 = right[-1]
		right.append(Vector2(last.x, bottom_y))
	var pts := PackedVector2Array()
	for q in right:
		pts.append(q)
	for i in range(right.size() - 1, -1, -1):
		pts.append(Vector2(-right[i].x, right[i].y))
	return _smooth(pts)


static func _body(ci: CanvasItem, cfg: Dictionary, t: float, stride: float, mono: Color) -> void:
	var b := value(cfg, "body")
	var shape := value(cfg, "shape")
	var sw: float = [27.0, 30.0, 35.0, 36.0, 35.0][b] + [0.0, -2.0, 3.0][shape]
	var waist: float = [17.0, 20.0, 25.0, 21.0, 31.0][b] + [0.0, -2.5, -1.0][shape]
	var hp: float = [21.0, 24.0, 27.0, 24.0, 34.0][b] + [0.0, 5.0, -2.0][shape]
	var chest: float = sw - 4.0 + [0.0, 1.5, -2.0][shape]
	var arm_w: float = [11.5, 12.5, 14.5, 15.5, 16.5][b]
	var thigh: float = [16.0, 18.0, 20.0, 20.0, 25.0][b] + [0.0, 2.0, 0.0][shape]
	var skin := color(cfg, "skin")
	var top := value(cfg, "top")
	var tc := color(cfg, "top_color")
	var bottom := value(cfg, "bottom")
	var bc := color(cfg, "bottom_color")
	var shoe_c := color(cfg, "shoe_color")
	var breathe := sin(t * 1.6) * 0.6
	var sh_y := NECK_Y + 2.0 + breathe

	# Legs: hip, knee, ankle. Long and adult.
	var legs := []
	for s in [-1.0, 1.0]:
		var hip := Vector2(s * hp * 0.48, -122)
		var knee := Vector2(s * hp * 0.4 + stride * s * 5.0, -64)
		var ankle := Vector2(s * hp * 0.36 + stride * s * 10.0, -12)
		legs.append([hip, knee, ankle, s])
	for L in legs:
		_shaded_limb3(ci, L[0], L[1], L[2], thigh, thigh * 0.6, thigh * 0.42, skin, mono)
	# Skin under the clothes (shows at the neckline and around a tank top).
	_shaded(ci, _torso_pts(sw, chest, waist, hp, sh_y, -124.0), skin, mono)
	match bottom:
		0, 1:
			for L in legs:
				_shaded_limb3(ci, L[0] + Vector2(0, -6), L[1], L[2] + Vector2(0, -3), thigh + 4, thigh * 0.74, thigh * (0.62 if bottom == 0 else 0.72), bc, mono)
			_shaded(ci, PackedVector2Array([Vector2(-hp - 1, -140), Vector2(hp + 1, -140), Vector2(hp + 1, -120), Vector2(0, -108), Vector2(-hp - 1, -120)]), bc, mono)
			if mono.a == 0.0:
				ci.draw_line(Vector2(-hp - 1, -138), Vector2(hp + 1, -138), Color(bc.darkened(0.35), 0.6), 1.5, true)
		2:
			for L in legs:
				_shaded_limb(ci, L[0] + Vector2(0, -6), L[0].lerp(L[1], 0.55), thigh + 5, thigh + 1, bc, mono)
			_shaded(ci, PackedVector2Array([Vector2(-hp - 1, -140), Vector2(hp + 1, -140), Vector2(hp + 2, -118), Vector2(0, -108), Vector2(-hp - 2, -118)]), bc, mono)
		3:
			_shaded(ci, PackedVector2Array([Vector2(-waist - 1, -156), Vector2(waist + 1, -156), Vector2(hp + 2, -132), Vector2(hp + 12, -72), Vector2(0, -69), Vector2(-hp - 12, -72), Vector2(-hp - 2, -132)]), bc, mono)
	# Shoes, seen from the front.
	for L in legs:
		var ank: Vector2 = L[2]
		var shoe := PackedVector2Array()
		for i in 20:
			var a := TAU * i / 20.0
			shoe.append(ank + Vector2(L[3] * 2.0, 4) + Vector2(cos(a) * 9.5, sin(a) * (5.5 if sin(a) < 0.0 else 4.0)))
		_shaded(ci, shoe, shoe_c, mono)
		if mono.a == 0.0:
			ci.draw_line(ank + Vector2(L[3] * 2.0 - 9, 8), ank + Vector2(L[3] * 2.0 + 9, 8), Color(1, 1, 1, 0.5), 1.4, true)

	# Hood behind the neck.
	if top == 1:
		_shaded(ci, _ell(Vector2(0, sh_y + 1), 19, 9), tc.darkened(0.12), mono)

	# Arms first, so the torso's shoulders sit over the tops of the sleeves (no puffy balls).
	var hem := -116.0 if top in [0, 1, 2, 4, 6] else -122.0
	if bottom == 3 and top in [0, 2, 3, 6]:
		hem = -152.0 # tucked into the skirt
	for s in [-1.0, 1.0]:
		var shp := Vector2(s * (sw - 7), sh_y + 14)
		var el := Vector2(s * (waist + arm_w * 0.55 + 5.0), -166) + Vector2(stride * s * 2.0, 0)
		var wr := Vector2(s * (hp + arm_w * 0.4 + 3.0), -124) + Vector2(-stride * 5.0, 0)
		_shaded_limb3(ci, shp, el, wr, arm_w, arm_w * 0.82, arm_w * 0.62, skin, mono)
		match top:
			0, 5:
				_shaded_limb(ci, shp + Vector2(0, 2), shp.lerp(el, 0.5 if top == 0 else 0.28), arm_w + 2.5, arm_w + 2.5, tc, mono)
			1, 2, 4, 6:
				_shaded_limb3(ci, shp + Vector2(0, 2), el, wr + Vector2(0, -3), arm_w + 2.5, arm_w + 2, arm_w + 1, tc, mono)
				if mono.a == 0.0:
					ci.draw_line(wr + Vector2(-arm_w * 0.5, -3), wr + Vector2(arm_w * 0.5, -3), Color(tc.darkened(0.3), 0.6), 1.2, true)
		# Hand: slim, a little longer than wide, thumb side forward.
		var hand := PackedVector2Array()
		for i in 18:
			var a := TAU * i / 18.0
			var r := Vector2(4.2 if sin(a) < 0.3 else 3.4, 7.5)
			hand.append(wr + Vector2(s * 0.5, 6.5) + Vector2(cos(a) * r.x, sin(a) * r.y))
		_shaded(ci, hand, skin, mono)

	# Neck, behind the neckline.
	_shaded_limb(ci, Vector2(0, NECK_Y - 10), Vector2(0, sh_y + 4), 12.5, 14.5, skin.darkened(0.03), mono)

	# Torso: skin first (shows at the neckline and under a tank), then the top.
	var torso := _torso_pts(sw, chest, waist, hp, sh_y, hem)
	if top == 3:
		var tank := PackedVector2Array()
		for q in torso:
			tank.append(q if q.y > sh_y + 16 else Vector2(q.x * 0.7, maxf(q.y, sh_y + 6)))
		_shaded(ci, tank, tc, mono)
		for side in [-1.0, 1.0]:
			_shaded_limb(ci, Vector2(side * (sw * 0.42), sh_y + 1), Vector2(side * (sw * 0.55), sh_y + 16), 4.5, 4.5, tc, mono)
	elif top == 5:
		_shaded(ci, _torso_pts(sw, chest, waist, hp, sh_y, -66.0, true), tc, mono)
		if mono.a == 0.0:
			ci.draw_line(Vector2(-waist, -159), Vector2(waist, -159), Color(tc.darkened(0.25), 0.5), 1.5, true)
	else:
		_shaded(ci, torso, tc, mono)
	if mono.a == 0.0:
		_neckline(ci, top, tc, skin, sh_y, hem, sw)
		if top == 6:
			ci.draw_line(Vector2(-hp + 4, hem - 1), Vector2(hp - 4, hem - 1), Color(tc.darkened(0.3), 0.6), 2.0, true)


static func _neckline(ci: CanvasItem, top: int, tc: Color, skin: Color, sh_y: float, hem: float, _sw: float) -> void:
	var line := Color(tc.darkened(0.35), 0.75)
	match top:
		0, 5, 6:
			ci.draw_colored_polygon(_ell(Vector2(0, sh_y + 1), 9, 6, 20), skin)
			ci.draw_arc(Vector2(0, sh_y + 1), 9.5, 0.1, PI - 0.1, 12, line, 1.8, true)
		1:
			ci.draw_line(Vector2(-4, sh_y + 6), Vector2(-5, sh_y + 30), Color(1, 1, 1, 0.85), 1.4, true)
			ci.draw_line(Vector2(4, sh_y + 6), Vector2(5, sh_y + 28), Color(1, 1, 1, 0.85), 1.4, true)
			ci.draw_line(Vector2(-16, hem - 26), Vector2(16, hem - 26), line, 1.4, true)
		2:
			ci.draw_colored_polygon(PackedVector2Array([Vector2(-10, sh_y), Vector2(0, sh_y + 12), Vector2(-3, sh_y)]), tc.lightened(0.3))
			ci.draw_colored_polygon(PackedVector2Array([Vector2(10, sh_y), Vector2(0, sh_y + 12), Vector2(3, sh_y)]), tc.lightened(0.3))
			ci.draw_line(Vector2(0, sh_y + 12), Vector2(0, hem), line, 1.0, true)
			for y in [sh_y + 26, sh_y + 46, sh_y + 66, sh_y + 86]:
				ci.draw_circle(Vector2(0, y), 1.4, tc.lightened(0.45))
		3:
			ci.draw_arc(Vector2(0, sh_y + 8), 11.0, 0.15, PI - 0.15, 12, line, 1.5, true)
		4:
			ci.draw_colored_polygon(PackedVector2Array([Vector2(-8, sh_y), Vector2(8, sh_y), Vector2(5, hem), Vector2(-5, hem)]), CLOTH[0])
			ci.draw_line(Vector2(-9, sh_y), Vector2(-3, sh_y + 50), line, 1.8, true)
			ci.draw_line(Vector2(9, sh_y), Vector2(3, sh_y + 50), line, 1.8, true)


# --- Head and face --------------------------------------------------------

static func _head(ci: CanvasItem, cfg: Dictionary, c: Vector2, dims: Vector2, t: float, mono: Color) -> void:
	var skin := color(cfg, "skin")
	var rx := dims.x
	for s in [-1.0, 1.0]:
		_fill(ci, _ell(c + Vector2(s * (rx + 0.5), 3), 4.2, 7.0, 16), skin.darkened(0.08), 0.15, mono)
		if mono.a == 0.0:
			var a0 := -PI * 0.5 if s > 0.0 else PI * 0.5
			ci.draw_arc(c + Vector2(s * (rx + 0.8), 3), 2.4, a0, a0 + PI, 8, Color(skin.darkened(0.35), 0.4), 1.0, true)
	var fshape := _face_pts(c, dims, value(cfg, "face"))
	if mono.a > 0.0:
		ci.draw_colored_polygon(fshape, mono)
		return
	# Skin with soft form: shadowed right side, lit left cheek and forehead.
	ci.draw_colored_polygon(fshape, skin.darkened(0.1))
	for k in 6:
		var f := 0.95 - k * 0.12
		var lit := PackedVector2Array()
		for p in fshape:
			lit.append(Vector2(c.x + (p.x - c.x) * f - dims.x * 0.035 * k, c.y + (p.y - c.y) * (0.98 - k * 0.03) - k * 0.4))
		ci.draw_colored_polygon(lit, Color(skin.lightened(0.015 * k), 0.5 if k > 0 else 1.0))
	var edge := fshape.duplicate()
	edge.append(fshape[0])
	ci.draw_polyline(edge, Color(skin.darkened(0.35), 0.4), 1.0, true)
	# Shadow along the jaw where it meets the neck.
	var jaw := PackedVector2Array()
	for i in range(int(fshape.size() * 0.1), int(fshape.size() * 0.4)):
		jaw.append(fshape[i])
	ci.draw_polyline(jaw, Color(skin.darkened(0.3), 0.25), 2.2, true)
	for s in [-1.0, 1.0]:
		for k in 4:
			ci.draw_circle(c + Vector2(s * 13.0, 11), 5.5 - k * 1.2, Color(0.95, 0.45, 0.48, 0.035))
	if value(cfg, "freckles") == 1:
		var spots := [Vector2(-14, 9), Vector2(-10, 11), Vector2(-15, 12), Vector2(-12, 7), Vector2(14, 9), Vector2(10, 11), Vector2(15, 12), Vector2(12, 7), Vector2(-3, 9), Vector2(3, 9)]
		for p in spots:
			ci.draw_circle(c + p, 0.75, Color(skin.darkened(0.3), 0.4 if skin.get_luminance() > 0.45 else 0.18))

	_eyes(ci, cfg, c, skin, t)
	_brows(ci, cfg, c, skin)
	_nose(ci, cfg, c, skin)
	var fh := value(cfg, "facial_hair")
	var hc := _brow_color(cfg, skin)
	if fh in [1, 3, 5, 6]:
		# Beard: follows the jaw from ear to ear, starts below the cheekbones, mouth stays visible.
		var outline := _face_pts(c, dims * (1.05 if fh >= 5 else 1.0), value(cfg, "face"), 60)
		var beard := PackedVector2Array()
		for i in range(2, 29):
			var p := outline[i]
			if fh == 6:
				var k := clampf((p.y - c.y) / dims.y, 0.0, 1.0)
				p += Vector2(0, 10.0 * k * k)
			beard.append(p)
		var top := 9.0
		# Upper edge: from the sideburn, down the cheek to the corners of the mouth, across under the nose.
		var rxo := dims.x * (1.05 if fh >= 5 else 1.0)
		for q in [Vector2(-rxo, 0.0), Vector2(-rxo * 0.82, 7.0), Vector2(-11.5, 13.5), Vector2(-6.5, 16.0), Vector2(0, 15.6), Vector2(6.5, 16.0), Vector2(11.5, 13.5), Vector2(rxo * 0.82, 7.0), Vector2(rxo, 0.0)]:
			beard.append(c + q)
		if fh == 1:
			ci.draw_colored_polygon(beard, Color(hc, 0.2))
			for i in 60:
				var rng_x := fmod(i * 7.31, 1.0) * 2.0 - 1.0
				var rng_y := fmod(i * 3.77, 1.0)
				ci.draw_circle(c + Vector2(rng_x * dims.x * 0.8, top + 4.0 + rng_y * (dims.y - top - 2.0) * (1.0 - absf(rng_x) * 0.4)), 0.45, Color(hc, 0.35))
		else:
			_fill(ci, beard, hc, 0.18)
			for i in 18:
				var x: float = lerpf(-dims.x * 0.8, dims.x * 0.8, i / 17.0)
				ci.draw_line(c + Vector2(x, top + 6.0), c + Vector2(x * 0.85, dims.y * 0.9 + (8.0 if fh == 6 else 0.0)), Color(hc.lightened(0.25), 0.15), 1.0, true)
	elif fh == 4:
		_fill(ci, PackedVector2Array([Vector2(c.x - 6, c.y + 24), Vector2(c.x + 6, c.y + 24), Vector2(c.x + 5, c.y + 31), Vector2(c.x, c.y + 33), Vector2(c.x - 5, c.y + 31)]), hc, 0.2)
	elif fh == 7:
		var jaw_line := _face_pts(c, dims * 1.01, value(cfg, "face"), 60)
		var strap := PackedVector2Array()
		for i in range(3, 28):
			strap.append(jaw_line[i])
		ci.draw_polyline(strap, hc, 3.0, true)
	_mouth(ci, cfg, c, skin)
	if fh in [2, 3, 4, 5, 6]:
		var my := c.y + 19.0
		_fill(ci, PackedVector2Array([
			Vector2(c.x - 10, my - 1.5), Vector2(c.x - 4, my - 5), Vector2(c.x, my - 4), Vector2(c.x + 4, my - 5),
			Vector2(c.x + 10, my - 1.5), Vector2(c.x + 6, my - 2), Vector2(c.x, my - 2.4), Vector2(c.x - 6, my - 2),
		]), hc, 0.15)


static func _brow_color(cfg: Dictionary, skin: Color) -> Color:
	# Brows have their own colour once you pick one; until then they follow your hair.
	if cfg.has("brow_color"):
		return color(cfg, "brow_color").darkened(0.12)
	if value(cfg, "hair") == 0:
		return skin.darkened(0.55)
	return color(cfg, "hair_color").darkened(0.12)


static func _eye_geom(style: int) -> Array:
	# [half width, upper height, lower height, outer tilt]
	return [[6.0, 3.4, 2.4, 1.1], [5.6, 3.9, 2.9, 0.2], [5.8, 2.8, 2.3, 0.4], [6.4, 3.8, 2.7, 0.6]][style]


static func _eye_upper(x: float, g: Array, s: float) -> float:
	var u := clampf((x / g[0] + 1.0) / 2.0, 0.0, 1.0)
	return -g[1] * pow(sin(u * PI), 0.75) - g[3] * (u if s > 0.0 else 1.0 - u)


static func _eye_lower(x: float, g: Array, s: float) -> float:
	var u := clampf((x / g[0] + 1.0) / 2.0, 0.0, 1.0)
	return g[2] * pow(sin(u * PI), 0.9) - g[3] * 0.5 * (u if s > 0.0 else 1.0 - u)


## A circle clipped to the eye opening, so the lids cover the iris naturally.
static func _clip_eye(center: Vector2, r: float, ec: Vector2, g: Array, s: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 28:
		var a := TAU * i / 28.0
		var p: Vector2 = center + Vector2(cos(a), sin(a)) * r - ec
		p.x = clampf(p.x, -g[0], g[0])
		p.y = clampf(p.y, _eye_upper(p.x, g, s), _eye_lower(p.x, g, s))
		if pts.is_empty() or pts[-1].distance_to(ec + p) > 0.05:
			pts.append(ec + p)
	if pts.size() > 2 and pts[0].distance_to(pts[-1]) < 0.05:
		pts.remove_at(pts.size() - 1)
	return pts


static func _eyes(ci: CanvasItem, cfg: Dictionary, c: Vector2, skin: Color, t: float) -> void:
	var style := value(cfg, "eyes")
	var g := _eye_geom(style)
	var seed := float(value(cfg, "skin")) * 0.37 + float(value(cfg, "hair")) * 0.61
	var period := 3.4 + fmod(seed, 1.6)
	var blink := fmod(t + seed, period) < 0.13
	var gaze := Vector2(sin(t * 0.45 + seed) * 0.9 + sin(t * 1.3 + seed * 2.0) * 0.3, sin(t * 0.33 + seed) * 0.3)
	var lash := Color("#1E1414").lerp(skin.darkened(0.7), 0.4)
	var iris := color(cfg, "eye_color")
	for s in [-1.0, 1.0]:
		var ec := Vector2(c.x + s * 9.6, c.y + 1.5)
		# Soft socket shadow above the eye.
		ci.draw_colored_polygon(_ell(ec + Vector2(0, -2.5), g[0] + 1.5, g[1] + 1.2, 20), Color(skin.darkened(0.25), 0.16))
		if blink:
			var shut := PackedVector2Array()
			for i in 13:
				var x: float = lerpf(-g[0], g[0], i / 12.0)
				shut.append(ec + Vector2(x, _eye_lower(x, g, s) * 0.35))
			ci.draw_polyline(shut, lash, 1.7, true)
			continue
		var white := PackedVector2Array()
		for i in 15:
			var x: float = lerpf(-g[0], g[0], i / 14.0)
			white.append(ec + Vector2(x, _eye_upper(x, g, s)))
		for i in range(13, 0, -1):
			var x: float = lerpf(-g[0], g[0], i / 14.0)
			white.append(ec + Vector2(x, _eye_lower(x, g, s)))
		ci.draw_colored_polygon(white, Color(0.95, 0.93, 0.91))
		var ic := ec + Vector2(0, 0.2) + gaze
		var r: float = g[1] * 0.98
		ci.draw_colored_polygon(_clip_eye(ic, r, ec, g, s), iris.darkened(0.3))
		ci.draw_colored_polygon(_clip_eye(ic, r * 0.8, ec, g, s), iris)
		ci.draw_colored_polygon(_clip_eye(ic + Vector2(0, 0.3), r * 0.42, ec, g, s), Color(0.05, 0.03, 0.03))
		# Shadow the lid casts on the top of the eye.
		var lid_shadow := PackedVector2Array()
		for i in 15:
			var x: float = lerpf(-g[0], g[0], i / 14.0)
			lid_shadow.append(ec + Vector2(x, _eye_upper(x, g, s)))
		for i in range(14, -1, -1):
			var x: float = lerpf(-g[0], g[0], i / 14.0)
			lid_shadow.append(ec + Vector2(x, _eye_upper(x, g, s) + 1.3))
		ci.draw_colored_polygon(lid_shadow, Color(0, 0, 0, 0.18))
		ci.draw_circle(ic + Vector2(-r * 0.32, -r * 0.3), r * 0.24, Color(1, 1, 1, 0.92))
		# Upper lash line, thicker toward the outer corner, with a small flick.
		var upper := PackedVector2Array()
		for i in 15:
			var x: float = lerpf(-g[0] - 0.3, g[0] + 0.3, i / 14.0)
			upper.append(ec + Vector2(x, _eye_upper(x, g, s) - 0.2))
		ci.draw_polyline(upper, lash, 1.6, true)
		if style == 0:
			var outer := ec + Vector2(s * g[0], _eye_upper(s * g[0], g, s))
			ci.draw_line(outer, outer + Vector2(s * 1.6, -1.0 - g[3] * 0.3), lash, 1.3, true)
		# Faint lower lid and the crease above.
		var lower := PackedVector2Array()
		for i in 11:
			var x: float = lerpf(-g[0] * 0.8, g[0] * 0.95, i / 10.0) * s
			lower.append(ec + Vector2(x, _eye_lower(x, g, s) + 0.4))
		ci.draw_polyline(lower, Color(skin.darkened(0.45), 0.35), 1.0, true)
		var crease := PackedVector2Array()
		for i in 11:
			var x: float = lerpf(-g[0] * 0.75, g[0] * 0.9, i / 10.0)
			crease.append(ec + Vector2(x, _eye_upper(x, g, s) * (1.35 if style != 2 else 1.05) - 1.6))
		ci.draw_polyline(crease, Color(skin.darkened(0.4), 0.3), 1.0, true)


static func _brows(ci: CanvasItem, cfg: Dictionary, c: Vector2, skin: Color) -> void:
	var style := value(cfg, "brows")
	var thick: float = [2.3, 2.0, 3.0, 2.3][style]
	var arch: float = [2.0, 3.2, 2.2, 0.8][style]
	var col := Color(_brow_color(cfg, skin), 0.92)
	var by := c.y - 6.5
	for s in [-1.0, 1.0]:
		var top := PackedVector2Array()
		var bot := PackedVector2Array()
		for i in 11:
			var u := i / 10.0
			var x: float = c.x + s * lerpf(4.0, 16.0, u)
			var y: float = by - arch * sin(minf(u * 1.35, 1.0) * PI * 0.5) * (1.0 - maxf(0.0, u - 0.74) * 2.2) + u * 0.8
			var w: float = thick * (1.0 - u * 0.65)
			top.append(Vector2(x, y - w * 0.5))
			bot.append(Vector2(x, y + w * 0.5))
		var poly := top
		for i in range(bot.size() - 1, -1, -1):
			poly.append(bot[i])
		ci.draw_colored_polygon(poly, col)
		var edge := poly.duplicate()
		edge.append(poly[0])
		ci.draw_polyline(edge, Color(col, 0.5), 0.8, true)


static func _nose(ci: CanvasItem, cfg: Dictionary, c: Vector2, skin: Color) -> void:
	var wide: float = [3.4, 3.0, 4.4][value(cfg, "nose")]
	var ny := c.y + 13.0
	var shade := skin.darkened(0.32)
	# A soft shadow down the side of the bridge (light comes from the left).
	ci.draw_colored_polygon(PackedVector2Array([Vector2(c.x + 1.5, c.y + 1.0), Vector2(c.x + 3.0, c.y + 1.5), Vector2(c.x + wide + 0.8, ny - 1.0), Vector2(c.x + 1.0, ny - 2.5)]), Color(shade, 0.22))
	# Tip highlight, nostrils and the shadow under the nose.
	ci.draw_circle(Vector2(c.x - 0.6, ny - 2.2), 1.6, Color(1, 1, 1, 0.14))
	for s in [-1.0, 1.0]:
		ci.draw_arc(Vector2(c.x + s * (wide - 0.6), ny - 0.4), 1.6, PI * (0.1 if s > 0.0 else 0.4), PI * (0.6 if s > 0.0 else 0.9), 6, Color(shade, 0.65), 1.1, true)
		ci.draw_circle(Vector2(c.x + s * (wide * 0.45), ny + 0.4), 0.85, Color(shade.darkened(0.3), 0.5))
	ci.draw_arc(Vector2(c.x, ny - 1.5), wide * 0.7, 0.2 * PI, 0.8 * PI, 8, Color(shade, 0.35), 1.0, true)


static func _mouth(ci: CanvasItem, cfg: Dictionary, c: Vector2, skin: Color) -> void:
	var style := value(cfg, "mouth")
	var my := c.y + 20.0
	var hw: float = [7.6, 7.0, 8.0, 6.6][style]
	var curve: float = [1.6, 0.4, 2.2, 0.2][style] # corners lift when smiling
	# Natural lips: a little deeper and warmer than the skin, not lipstick pink.
	var lip := skin.lerp(Color("#9E5458"), 0.3)
	var line := lip.darkened(0.45)
	var upper_h: float = [1.9, 2.1, 1.6, 1.6][style]
	var lower_h: float = [2.6, 3.0, 2.2, 2.3][style]
	var open: float = 2.2 if style == 2 else 0.0
	# Parting line: corners up a little for a smile.
	var part := PackedVector2Array()
	for i in 15:
		var x: float = lerpf(-hw, hw, i / 14.0)
		part.append(Vector2(c.x + x, my - curve * pow(x / hw, 2) + 0.4 * (1.0 - pow(x / hw, 2))))
	# Upper lip with a gentle cupid's bow.
	var up := PackedVector2Array()
	for i in range(1, 14):
		var x: float = lerpf(-hw, hw, i / 14.0)
		var k := 1.0 - pow(x / hw, 2)
		var bow := -0.7 * exp(-pow((absf(x) - hw * 0.25) / (hw * 0.18), 2)) + 0.35 * exp(-pow(x / (hw * 0.12), 2))
		up.append(Vector2(c.x + x, my - curve * pow(x / hw, 2) - upper_h * pow(k, 0.6) + bow))
	for i in range(14, -1, -1):
		up.append(part[i])
	ci.draw_colored_polygon(up, lip.darkened(0.08))
	if open > 0.0:
		var gap := PackedVector2Array()
		for i in 13:
			var x: float = lerpf(-hw * 0.82, hw * 0.82, i / 12.0)
			gap.append(Vector2(c.x + x, my - curve * pow(x / hw, 2) + 0.3))
		for i in range(11, 0, -1):
			var x: float = lerpf(-hw * 0.82, hw * 0.82, i / 12.0)
			gap.append(Vector2(c.x + x, my - curve * pow(x / hw, 2) + 0.3 + open * (1.0 - pow(x / (hw * 0.82), 2))))
		ci.draw_colored_polygon(gap, Color(0.32, 0.1, 0.12))
		var teeth := PackedVector2Array()
		for i in 11:
			var x: float = lerpf(-hw * 0.7, hw * 0.7, i / 10.0)
			teeth.append(Vector2(c.x + x, my - curve * pow(x / hw, 2) + 0.4))
		for i in range(9, 0, -1):
			var x: float = lerpf(-hw * 0.7, hw * 0.7, i / 10.0)
			teeth.append(Vector2(c.x + x, my - curve * pow(x / hw, 2) + 0.4 + open * 0.55 * (1.0 - pow(x / (hw * 0.7), 2))))
		ci.draw_colored_polygon(teeth, Color(0.97, 0.95, 0.92))
	# Fuller lower lip.
	var low := PackedVector2Array()
	for i in 15:
		var x: float = lerpf(-hw * 0.92, hw * 0.92, i / 14.0)
		low.append(Vector2(c.x + x, my - curve * pow(x / hw, 2) + open * (1.0 - pow(x / hw, 2)) * 0.9))
	for i in range(13, 0, -1):
		var x: float = lerpf(-hw * 0.92, hw * 0.92, i / 14.0)
		var k := 1.0 - pow(x / (hw * 0.92), 2)
		low.append(Vector2(c.x + x, my - curve * pow(x / hw, 2) + open + lower_h * pow(k, 0.55)))
	ci.draw_colored_polygon(low, lip)
	ci.draw_circle(Vector2(c.x - hw * 0.15, my + open + lower_h * 0.45), lower_h * 0.35, Color(1, 1, 1, 0.16))
	ci.draw_polyline(part, line, 1.1, true)
	# Shadow under the lower lip.
	ci.draw_arc(Vector2(c.x, my + open + lower_h + 1.8), hw * 0.4, 0.25 * PI, 0.75 * PI, 8, Color(skin.darkened(0.3), 0.25), 1.2, true)
	if curve > 1.0:
		for s in [-1.0, 1.0]:
			ci.draw_arc(Vector2(c.x + s * (hw + 0.5), my - curve - 0.5), 1.8, PI * (0.6 if s > 0.0 else -0.1), PI * (1.1 if s > 0.0 else 0.4), 5, Color(skin.darkened(0.3), 0.35), 0.9, true)


static func _glasses(ci: CanvasItem, cfg: Dictionary, c: Vector2, dims: Vector2) -> void:
	var style := value(cfg, "glasses")
	if style == 0:
		return
	var gc := Color(0.12, 0.09, 0.09)
	for s in [-1.0, 1.0]:
		var ec := Vector2(c.x + s * 9.6, c.y + 1.0)
		ci.draw_circle(ec, 7.5, Color(1, 1, 1, 0.07))
		if style == 1:
			ci.draw_arc(ec, 8.0, 0.0, TAU, 24, gc, 1.6, true)
		else:
			ci.draw_rect(Rect2(ec - Vector2(8.5, 6.5), Vector2(17, 13)), gc, false, 1.7)
		ci.draw_line(Vector2(c.x + s * 17.5, c.y + 0.5), Vector2(c.x + s * (dims.x + 0.5), c.y + 2.5), gc, 1.5, true)
	ci.draw_arc(Vector2(c.x, c.y + 2.5), 3.0, PI + 0.3, TAU - 0.3, 6, gc, 1.5, true)


# --- Hair -----------------------------------------------------------------

## The hair "cap": over the crown, framing the face down to the hairline.
static func _cap(c: Vector2, dims: Vector2, hairline: float, side: float, puff: float) -> PackedVector2Array:
	var rx := dims.x
	var ry := dims.y
	var pts := PackedVector2Array()
	var n := 26
	for i in n + 1:
		var a := lerpf(PI - side, TAU + side, float(i) / n)
		pts.append(c + Vector2(cos(a) * (rx + puff), sin(a) * (ry + puff)))
	# A soft, rounded hairline: the face shows through an oval, not a square window.
	var top_in := ry * hairline
	for i in n + 1:
		var a := lerpf(TAU + side, PI - side, float(i) / n)
		var sy := sin(a)
		var yr := top_in if sy < 0.0 else ry * 0.97
		pts.append(c + Vector2(cos(a) * rx * 0.97, sy * yr))
	return pts


## Fine strands from the crown out to the edge of the hair: texture instead of a flat helmet.
static func _strands(ci: CanvasItem, shape: PackedVector2Array, crown: Vector2, hc: Color, c := Vector2.ZERO, dims := Vector2.ZERO) -> void:
	var step := maxi(1, shape.size() / 22)
	for i in range(0, shape.size(), step):
		var tip := shape[i]
		if dims != Vector2.ZERO:
			var rel := (tip - c) / dims
			if rel.length() < 1.04 or tip.y > c.y + dims.y * 0.15:
				continue
		var a := crown.lerp(tip, 0.18)
		var b := crown.lerp(tip, 0.9)
		var mid := a.lerp(b, 0.5) + (b - a).orthogonal().normalized() * 1.5
		var line := PackedVector2Array([a, mid, b])
		var light := (i / step) % 2 == 0
		ci.draw_polyline(line, Color(hc.lightened(0.3), 0.22) if light else Color(hc.darkened(0.35), 0.22), 1.1, true)


static func _long_back(c: Vector2, dims: Vector2, length: float, wavy: bool, t: float) -> PackedVector2Array:
	var rx := dims.x + 9.0
	var ry := dims.y + 8.0
	var pts := PackedVector2Array()
	for i in 17:
		var a := lerpf(PI, TAU, i / 16.0)
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	for k in range(1, 9):
		var u := k / 8.0
		var wave := sin(u * 9.0 + t * 1.2) * 3.5 if wavy else 0.0
		pts.append(Vector2(c.x + rx + 3.0 * u + wave, c.y + length * u))
	pts.append(Vector2(c.x + rx * 0.4, c.y + length + 6.0))
	pts.append(Vector2(c.x - rx * 0.4, c.y + length + 6.0))
	for k in range(8, 0, -1):
		var u := k / 8.0
		var wave := sin(u * 9.0 + t * 1.2 + 1.5) * 3.5 if wavy else 0.0
		pts.append(Vector2(c.x - rx - 3.0 * u + wave, c.y + length * u))
	return pts


static func _hair(ci: CanvasItem, cfg: Dictionary, c: Vector2, dims: Vector2, layer: String, mono: Color, portrait: bool, t: float) -> void:
	var style := value(cfg, "hair")
	var hc := color(cfg, "hair_color")
	var rx := dims.x
	var ry := dims.y
	var length := 42.0 if portrait else 62.0
	if layer == "back":
		match style:
			4:
				for i in 15:
					var a := lerpf(PI * 0.8, PI * 2.2, i / 14.0)
					_fill(ci, _ell(c + Vector2(cos(a) * (rx + 4), sin(a) * (ry + 4)), 10.5, 10.5, 14), hc, 0.25, mono)
			5:
				var center := c + Vector2(0, -10)
				_fill(ci, _ell(center, rx + 24, ry + 20, 36), hc, 0.22, mono)
				for i in 20:
					var a := TAU * i / 20.0
					_fill(ci, _ell(center + Vector2(cos(a) * (rx + 22), sin(a) * (ry + 18)), 9.5, 9.5, 12), hc, 0.22, mono)
			6:
				var bob := PackedVector2Array()
				for i in 17:
					var a := lerpf(PI, TAU, i / 16.0)
					bob.append(c + Vector2(cos(a) * (rx + 8), sin(a) * (ry + 8)))
				bob.append(Vector2(c.x + rx + 9, c.y + ry * 0.5))
				bob.append(Vector2(c.x + rx + 6, c.y + ry * 0.85))
				bob.append(Vector2(c.x - rx - 6, c.y + ry * 0.85))
				bob.append(Vector2(c.x - rx - 9, c.y + ry * 0.5))
				_fill(ci, bob, hc, 0.22, mono)
			7, 8:
				var back := _long_back(c, dims, length, style == 8, t)
				_fill(ci, back, hc, 0.22, mono)
				if mono.a == 0.0:
					for k in 14:
						var x: float = lerpf(-rx - 6.0, rx + 6.0, k / 13.0)
						var wave := 2.5 if style == 8 else 0.0
						var line := PackedVector2Array()
						for j in 9:
							var u := j / 8.0
							line.append(Vector2(c.x + x * (1.0 + u * 0.08) + sin(u * 7.0 + k + t) * wave, c.y + lerpf(-ry * 0.2, length, u)))
						ci.draw_polyline(line, Color(hc.lightened(0.25), 0.18) if k % 2 == 0 else Color(hc.darkened(0.3), 0.2), 1.1, true)
			10:
				var tail := PackedVector2Array([
					Vector2(c.x + rx * 0.4, c.y - ry * 0.75), Vector2(c.x + rx + 14, c.y - ry * 0.3), Vector2(c.x + rx + 20, c.y + (24.0 if portrait else 32.0)),
					Vector2(c.x + rx + 12, c.y + (30.0 if portrait else 54.0)), Vector2(c.x + rx + 4, c.y + (20.0 if portrait else 32.0)), Vector2(c.x + rx * 0.7, c.y - ry * 0.05),
				])
				_fill(ci, tail, hc, 0.25, mono)
			11:
				for s in [-1.0, 1.0]:
					for k in (3 if portrait else 5):
						_fill(ci, _ell(Vector2(c.x + s * (rx + 3.0 - k * 0.6), c.y + 6.0 + k * 11.0), 7.0, 6.5, 14), hc, 0.3, mono)
			18:
				var reach := 40.0 if portrait else 58.0
				for k in 13:
					var x: float = lerpf(-rx - 6.0, rx + 6.0, k / 12.0)
					_fill(ci, _limb(Vector2(c.x + x * 0.9, c.y - ry * 0.4), Vector2(c.x + x * 1.12, c.y + reach - absf(x) * 0.4), 8.0, 6.0), hc.darkened(0.05 * (k % 3)), 0.25, mono)
			20:
				for i in 17:
					var a := lerpf(PI * 0.85, PI * 2.15, i / 16.0)
					var base := c + Vector2(cos(a) * (rx + 2), sin(a) * (ry + 2))
					_fill(ci, _limb(base, base + Vector2(cos(a), sin(a)) * 8.0, 9.0, 7.0), hc, 0.3, mono)
			21:
				_fill(ci, PackedVector2Array([
					Vector2(c.x - rx - 4, c.y - ry * 0.2), Vector2(c.x + rx + 4, c.y - ry * 0.2), Vector2(c.x + rx + 2, c.y + (24.0 if portrait else 42.0)),
					Vector2(c.x + 10, c.y + (30.0 if portrait else 52.0)), Vector2(c.x - 10, c.y + (30.0 if portrait else 52.0)), Vector2(c.x - rx - 2, c.y + (24.0 if portrait else 42.0)),
				]), hc, 0.25, mono)
		return

	var cap := PackedVector2Array()
	var puff := 6.0
	match style:
		0:
			if mono.a == 0.0:
				ci.draw_arc(c, ry * 0.85, 1.2 * PI, 1.5 * PI, 10, Color(1, 1, 1, 0.12), 3.0, true)
			return
		1:
			puff = 1.5
			cap = _cap(c, dims, 0.52, 0.2, puff)
		2:
			cap = _cap(c, dims, 0.5, 0.3, puff)
		3:
			puff = 8.0
			cap = _cap(c, dims, 0.45, 0.35, puff)
		4, 5:
			cap = _cap(c, dims, 0.52, 0.35, puff)
		6:
			puff = 9.0
			cap = _cap(c, dims, 0.28, 0.95, puff)
		7, 8:
			puff = 9.0
			cap = _cap(c, dims, 0.4, 1.0, puff)
		9, 10:
			puff = 4.0
			cap = _cap(c, dims, 0.48, 0.3, puff)
		11:
			puff = 4.0
			cap = _cap(c, dims, 0.45, 0.5, puff)
		12:
			puff = 3.0
			cap = _cap(c, dims, 0.55, 0.2, puff)
		13:
			puff = 5.0
			cap = _cap(c, dims, 0.52, -0.05, puff)
			_fill(ci, _cap(c, dims, 0.62, 0.28, 1.0), Color(hc, 0.45) if mono.a == 0.0 else mono, 0.1, mono)
		14:
			puff = 4.0
			cap = _cap(c, dims, 0.52, 0.2, puff)
		15:
			puff = 6.0
			cap = _cap(c, dims, 0.3, 0.55, puff)
		16:
			puff = 5.0
			cap = _cap(c, dims, 0.62, 0.25, puff)
		17:
			puff = 3.0
			cap = _cap(c, dims, 0.58, 0.3, puff)
		18:
			puff = 6.0
			cap = _cap(c, dims, 0.45, 0.6, puff)
		19:
			puff = 1.5
			cap = _cap(c, dims, 0.55, 0.25, puff)
		20:
			puff = 6.0
			cap = _cap(c, dims, 0.5, 0.35, puff)
		21:
			puff = 4.0
			cap = _cap(c, dims, 0.5, 0.3, puff)
	_fill(ci, cap, hc, 0.25, mono)
	if mono.a == 0.0 and cap.size() > 6:
		_strands(ci, cap, c + Vector2(0, -ry - puff * 0.6), hc, c, dims)

	match style:
		2:
			# A soft, textured crop: a raised quiff swept to one side.
			_fill(ci, PackedVector2Array([
				Vector2(c.x - rx * 0.75, c.y - ry * 0.55), Vector2(c.x - rx * 0.5, c.y - ry - 8), Vector2(c.x + rx * 0.1, c.y - ry - 12),
				Vector2(c.x + rx * 0.7, c.y - ry - 6), Vector2(c.x + rx * 0.95, c.y - ry * 0.45), Vector2(c.x + rx * 0.3, c.y - ry * 0.62),
				Vector2(c.x - rx * 0.2, c.y - ry * 0.58),
			]), hc.lightened(0.04), 0.25, mono)
			if mono.a == 0.0:
				for k in 5:
					var x: float = lerpf(-rx * 0.5, rx * 0.6, k / 4.0)
					ci.draw_line(Vector2(c.x + x - 4, c.y - ry - 4), Vector2(c.x + x + 6, c.y - ry * 0.62), Color(hc.darkened(0.3), 0.5), 1.2, true)
		3:
			_fill(ci, PackedVector2Array([
				Vector2(c.x - rx * 0.35, c.y - ry - 8), Vector2(c.x + rx * 0.6, c.y - ry - 4), Vector2(c.x + rx + 6, c.y - ry * 0.35),
				Vector2(c.x + rx * 0.5, c.y - ry * 0.55), Vector2(c.x - rx * 0.1, c.y - ry * 0.62), Vector2(c.x - rx * 0.5, c.y - ry * 0.72),
			]), hc.lightened(0.05), 0.25, mono)
		4:
			for i in 7:
				var x: float = lerpf(-rx * 0.85, rx * 0.85, i / 6.0)
				_fill(ci, _ell(Vector2(c.x + x, c.y - ry * 0.52 - 3.0 * cos(x / rx * 1.57)), 6.0, 6.0, 12), hc.lightened(0.06), 0.3, mono)
		9:
			_fill(ci, _ell(Vector2(c.x, c.y - ry - 9), 15, 13, 20), hc, 0.3, mono)
			if mono.a == 0.0:
				ci.draw_arc(Vector2(c.x, c.y - ry + 2), 7, PI + 0.4, TAU - 0.4, 8, hc.darkened(0.35), 2.0, true)
		14:
			_fill(ci, PackedVector2Array([
				Vector2(c.x - rx * 0.7, c.y - ry * 0.6), Vector2(c.x - rx * 0.45, c.y - ry - 7), Vector2(c.x + rx * 0.15, c.y - ry - 11),
				Vector2(c.x + rx * 0.75, c.y - ry - 5), Vector2(c.x + rx * 0.85, c.y - ry * 0.55), Vector2(c.x, c.y - ry * 0.7),
			]), hc.lightened(0.06), 0.3, mono)
		15:
			for side in [-1.0, 1.0]:
				_fill(ci, PackedVector2Array([
					Vector2(c.x, c.y - ry - 4), Vector2(c.x + side * rx * 0.7, c.y - ry * 0.75), Vector2(c.x + side * (rx + 4), c.y - ry * 0.05),
					Vector2(c.x + side * rx * 0.8, c.y - ry * 0.2), Vector2(c.x + side * rx * 0.35, c.y - ry * 0.45), Vector2(c.x + side * 3, c.y - ry * 0.55),
				]), hc, 0.25, mono)
		16:
			if mono.a == 0.0:
				for k in 6:
					var x: float = lerpf(-rx * 0.6, rx * 0.6, k / 5.0)
					ci.draw_line(Vector2(c.x + x, c.y - ry * 0.6), Vector2(c.x + x * 0.8, c.y - ry - 3), Color(hc.lightened(0.25), 0.45), 1.3, true)
		17:
			_fill(ci, _ell(Vector2(c.x, c.y - ry - 6), 11, 9, 18), hc, 0.3, mono)
		18:
			for side in [-1.0, 1.0]:
				_fill(ci, _limb(Vector2(c.x + side * rx * 0.95, c.y - ry * 0.45), Vector2(c.x + side * (rx + 5), c.y + 18), 6.0, 5.0), hc, 0.25, mono)
		19:
			if mono.a == 0.0:
				for k in 7:
					var x: float = lerpf(-rx * 0.75, rx * 0.75, k / 6.0)
					var row := PackedVector2Array()
					for i in 8:
						var u := i / 7.0
						row.append(Vector2(c.x + x * (1.0 - u * 0.3), lerpf(c.y - ry * 0.55, c.y - ry - 1, u)))
					ci.draw_polyline(row, hc.darkened(0.45), 1.6, true)
		20:
			for i in 9:
				var x: float = lerpf(-rx * 0.85, rx * 0.85, i / 8.0)
				var base := Vector2(c.x + x, c.y - ry * 0.55 - 2.0 * cos(x / rx * 1.57))
				_fill(ci, _limb(base, base + Vector2(x * 0.08, 9), 6.0, 4.5), hc.lightened(0.05), 0.3, mono)
	if mono.a > 0.0:
		return
	if style in [7, 8, 11]:
		ci.draw_line(Vector2(c.x, c.y - ry - puff + 3), Vector2(c.x - 1, c.y - ry * 0.5), Color(hc.darkened(0.3), 0.45), 1.0, true)
	ci.draw_arc(c + Vector2(0, 2), ry + puff - 4.0, 1.2 * PI, 1.45 * PI, 10, Color(hc.lightened(0.45), 0.4), 3.0, true)
