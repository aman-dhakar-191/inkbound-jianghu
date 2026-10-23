extends Control
## Placeholder scene art drawn in code: ink-wash peaks, mist, rain, lantern
## light, silhouette figures and duel slashes. Ported from the prototype's
## canvas. Final art replaces this at milestone M7.
##
## Coordinates follow the prototype: a 400-unit-wide stage scaled by _u(),
## with the ground line just above the story panel.

const INK := Color("1b2428")
const SEAL := Color("a8322d")
## Yan Ruo wears her sect's pale robes.
const YAN_ROBE := Color("dfe7ea")
const SECT_WHITE := Color("e6ecee")
const OLD_ROBE := Color("5a4a3a")
const GU_ROBE := Color("1b1517")
const BANDIT := Color("14101a")
const SKIN := Color("8a6f5a")
const HAIR := Color("0c0a09")
const BLADE := Color("dbe5e2")

const SKIES := {
	"mist": [Color("b4c3bb"), Color("e0e6dc")],
	"dawn": [Color("8da2aa"), Color("e3dccd")],
	"day": [Color("a8bdb8"), Color("e6ece3")],
}
const RIDGES := {
	"mist": [Color("a7b8ad"), Color("889e91"), Color("66806f")],
	"dawn": [Color("8da09f"), Color("6f8683"), Color("506b66")],
	"day": [Color("a9bbb0"), Color("8ba094"), Color("6c8577")],
}
const SUNS := {
	"mist": [Vector2(0.74, 0.45), 44.0, Color(0.96, 0.94, 0.88)],
	"dawn": [Vector2(0.28, 0.8), 52.0, Color(0.93, 0.69, 0.47)],
	"day": [Vector2(0.24, 0.5), 36.0, Color(0.98, 0.97, 0.93)],
}
## door: 0 closed, 1 open, -1 bursts open with thunder.
const PRESETS := {
	"title_peaks": {"outdoor": true, "sky": "mist", "figure": "title"},
	"inn_rain": {"door": 0, "figure": "ferry"},
	"inn_bandits": {"door": -1, "figure": "bandits"},
	"duel": {"door": 1, "figure": "duel", "art_share": 0.33},
	"inn_after": {"door": 1, "figure": "after"},
	"river_dawn": {"outdoor": true, "sky": "dawn", "water": true, "figure": "letter"},
	"river_depart": {"outdoor": true, "sky": "dawn", "water": true, "figure": "depart"},
	"ferry_day": {"outdoor": true, "sky": "day", "water": true, "figure": "boat"},
}
## Start and end angle (radians) and radius of each move's slash arc.
const SLASHES := {
	"willow": [-2.7, -0.3, 62.0],
	"crane": [-2.2, 0.6, 46.0],
	"step": [0.2, 2.6, 56.0],
	"water": [-3.1, -0.1, 40.0],
}

## Height of the art area. The story panel covers everything below it.
var horizon := 500.0
## Freezes idle motion (sway, drifting mist, rain) for reduced-motion players.
var reduced_motion := false
## The GameState being played, read for details like the wound. May be null.
## Left untyped so the art layer does not depend on core.
var state = null

var _preset: Dictionary = PRESETS["title_peaks"]
var _time := 0.0
var _since := 0.0
var _flash := 0.0
var _shake := 0.0
var _offset := Vector2.ZERO
var _thundered := false
var _next_thunder := 0.0
var _move := ""
var _move_at := -10.0
var _move_linked := false
var _sparked := false
var _duel_links := -1
var _duel_end_at := 0.0
var _slashes := []
var _sparks := []
var _embers := []


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE


func set_preset(id: String) -> void:
	_preset = PRESETS.get(id, PRESETS["title_peaks"])
	_since = 0.0
	_flash = 0.0
	_shake = 0.0
	_thundered = false
	_next_thunder = randf_range(6.0, 9.0)
	_move = ""
	_duel_links = -1
	_slashes.clear()
	_sparks.clear()
	_embers.clear()
	queue_redraw()


## Fraction of the screen height the art takes in this preset.
func art_share() -> float:
	return float(_preset.get("art_share", 0.4))


## Plays one duel move. Linked moves hit harder and spark red.
func strike(move_id: String, linked: bool) -> void:
	_move = move_id
	_move_at = _since
	_move_linked = linked
	_sparked = false


func finish_duel(links: int) -> void:
	_duel_links = links
	_duel_end_at = _since
	_move = ""


func _u() -> float:
	return minf(size.x / 400.0, size.y / 700.0)


func _x(l: float) -> float:
	return size.x / 2.0 + (l - 200.0) * _u()


func _ground() -> float:
	return horizon - size.y * 0.03


func _process(delta: float) -> void:
	_since += delta
	if not reduced_motion:
		_time += delta
	_flash *= exp(-delta * 5.0)
	_shake *= exp(-delta * 9.0)
	for s in _slashes:
		s["age"] += delta
	_slashes = _slashes.filter(func(s): return s["age"] < s["dur"])
	for list in [_sparks, _embers]:
		for p in list:
			p["age"] += delta
			if p["gravity"]:
				p["vel"] += Vector2(0.0, 520.0 * _u() * delta)
			p["pos"] += p["vel"] * delta
	_sparks = _sparks.filter(func(p): return p["age"] < p["life"])
	_embers = _embers.filter(func(p): return p["age"] < p["life"])
	queue_redraw()


func _draw() -> void:
	_offset = Vector2.ZERO
	if _shake > 0.3 and not reduced_motion:
		_offset = Vector2(randf() - 0.5, randf() - 0.5) * _shake
	draw_set_transform(_offset)
	if _preset.get("outdoor", false):
		_draw_outdoor()
	else:
		_draw_inn()
	_draw_slashes()
	_draw_particles()
	draw_set_transform(Vector2.ZERO)
	if _flash > 0.01:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.86, 0.92, 1.0, _flash * 0.5))


# ---------------------------------------------------------------- outdoor

func _draw_outdoor() -> void:
	var u := _u()
	var gy := _ground()
	var t := _time
	var sky_id: String = _preset.get("sky", "mist")
	var sky: Array = SKIES[sky_id]
	_gradient(Rect2(0.0, 0.0, size.x, gy + 40.0 * u), sky[0], sky[1])
	var sun: Array = SUNS[sky_id]
	var sun_at: Vector2 = sun[0]
	var sun_r: float = sun[1] * u
	var sun_color: Color = sun[2]
	var sun_pos := Vector2(size.x * sun_at.x, gy * sun_at.y)
	for i in 8:
		var k := 1.0 - i / 8.0
		draw_circle(sun_pos, sun_r * 3.2 * k, Color(sun_color, 0.06 + 0.05 * i / 8.0))
	draw_circle(sun_pos, sun_r * 0.6, Color(sun_color, 0.8))
	var ridge: Array = RIDGES[sky_id]
	_ridge(gy - 40.0 * u, 130.0 * u, 0.012, 1.0, 2.0, ridge[0])
	_ridge(gy - 5.0 * u, 95.0 * u, 0.017, 4.0, 4.0, ridge[1])
	_ridge(gy + 25.0 * u, 60.0 * u, 0.024, 2.0, 7.0, ridge[2])
	_mist(gy, 0.2)
	if _preset.get("water", false):
		_gradient(Rect2(0.0, gy, size.x, size.y - gy), Color("5f7a78"), Color("2c4543"))
		for i in 14:
			var yy := gy + (6.0 + i * 7.0) * u
			var xx := float((i * 97) % 360) / 360.0 * size.x + sin(t * 0.6 + i) * 8.0 * u
			var a := 0.14 + 0.1 * sin(t * 1.2 + i)
			draw_line(Vector2(xx, yy), Vector2(xx + (20.0 + (i % 4) * 12.0) * u, yy), Color(1, 1, 1, a), 1.6 * u)
	else:
		var ground := PackedVector2Array([Vector2(0, size.y), Vector2(0, gy + 20.0 * u)])
		ground.append_array(_quad(Vector2(0, gy + 20.0 * u), Vector2(size.x / 2.0, gy - 6.0 * u), Vector2(size.x, gy + 14.0 * u), 16))
		ground.append(Vector2(size.x, size.y))
		draw_colored_polygon(ground, Color("3d5648"))
	var bc := Color("2f4a40")
	_bamboo(_x(-6.0), 250.0 * u, 10.0 * u, t, bc)
	_bamboo(_x(14.0), 200.0 * u, 8.0 * u, t + 1.0, bc)
	_bamboo(_x(412.0), 240.0 * u, -10.0 * u, t + 2.0, bc)
	_bamboo(_x(390.0), 190.0 * u, -8.0 * u, t + 3.0, bc)

	var fy := gy + 12.0 * u
	var h := 128.0 * u
	match _preset.get("figure", ""):
		"title":
			_person(_x(250.0), fy + 4.0 * u, h, {"facing": -1.0, "color": SECT_WHITE, "rim": INK, "hair": "long", "ribbon": true, "sword": "sheath", "windy": 2.2})
		"letter":
			_person(_x(130.0), fy, h, {"color": YAN_ROBE, "hair": "tail", "arm": 0.2, "paper": 1.0, "windy": 1.6})
		"depart":
			var walk := minf(_since, 14.0)
			var paper := maxf(0.0, 1.0 - _since / 2.8)
			var look := {"color": YAN_ROBE, "hair": "tail", "arm": 0.5, "paper": paper, "windy": 1.6, "wound": _flag("wound") == true}
			if _since < 14.0:
				look["walk"] = _since * 5.0
			var hand := _person(_x(130.0 + walk * 9.0), fy, h, look)
			if _flag("letter") == "burned" and _since < 2.8 and not reduced_motion:
				for i in 2:
					_embers.append({"pos": hand + Vector2(randf_range(-4, 4) * u, 0), "vel": Vector2(randf_range(-10, 14), randf_range(-110, -60)) * u, "age": 0.0, "life": randf_range(1.0, 1.8), "gravity": false, "color": Color(1.0, 0.6, 0.25)})
		"boat":
			_draw_boat(gy, h, u, t)
	_petals(gy, u, t)


func _draw_boat(gy: float, h: float, u: float, t: float) -> void:
	var bob := sin(t * 1.4) * 2.0 * u
	var bx := _x(120.0)
	var by := gy + 16.0 * u + bob
	_person(_x(195.0), by - 4.0 * u, h * 0.95, {"color": Color("4a3d2e"), "hat": true, "pole": true, "arm": 0.9, "skin": Color("7d6552")})
	var hull := _quad(Vector2(bx, by), Vector2(bx + 20.0 * u, by + 26.0 * u), Vector2(bx + 75.0 * u, by + 26.0 * u), 8)
	hull.append_array(_quad(Vector2(bx + 75.0 * u, by + 26.0 * u), Vector2(bx + 130.0 * u, by + 26.0 * u), Vector2(bx + 150.0 * u, by), 8))
	draw_colored_polygon(hull, Color("3a2c20"))
	# The scroll floating in the reeds, with its red seal.
	var sc := Vector2(_x(300.0), gy + 26.0 * u + sin(t * 1.8 + 1.0) * 1.5 * u)
	_ellipse(sc, 14.0 * u, 4.5 * u, Color("e8e2d2"))
	draw_circle(sc, 2.6 * u, SEAL)
	var rp := fmod(t * 0.5, 1.0)
	_ellipse_outline(sc + Vector2(0, 2.0 * u), (14.0 + rp * 30.0) * u, (4.0 + rp * 8.0) * u, Color(1, 1, 1, 0.4 * (1.0 - rp)), 1.4 * u)


func _ridge(base: float, amp: float, freq: float, phase: float, drift: float, color: Color) -> void:
	var f := freq / _u()
	var pts := PackedVector2Array([Vector2(0, size.y)])
	var x := 0.0
	while x <= size.x + 6.0:
		var xx := x + _time * drift
		var v := 0.5 + 0.5 * sin(xx * f + phase)
		var v2 := 0.25 * sin(xx * f * 2.7 + phase * 2.0)
		pts.append(Vector2(x, base - amp * (v * 0.8 + v2 * 0.5 + 0.15)))
		x += 6.0
	pts.append(Vector2(size.x, size.y))
	draw_colored_polygon(pts, color)


func _mist(gy: float, alpha: float) -> void:
	var u := _u()
	for i in 6:
		var x := fmod(i * 0.23 * size.x + _time * (6.0 + i * 3.0), size.x + 320.0 * u) - 160.0 * u
		var y := gy - 25.0 * u + sin(i * 2.1) * 22.0 * u
		for k in 5:
			draw_circle(Vector2(x, y), 170.0 * u * (1.0 - k * 0.18), Color(1, 1, 1, alpha * 0.22))


func _bamboo(x: float, height: float, sway: float, t: float, color: Color) -> void:
	var u := _u()
	var gy := _ground()
	var pts := PackedVector2Array()
	for i in 9:
		var q := i / 8.0
		pts.append(Vector2(x + sin(t * 0.8 + x * 0.1) * sway * q * q, gy + 40.0 * u - height * q))
	draw_polyline(pts, color, 5.0 * u, true)
	for i in range(1, 9):
		draw_line(pts[i] - Vector2(5.0 * u, 0), pts[i] + Vector2(5.0 * u, 0), color, 2.0 * u)
		if i > 3:
			var dir := -1.0 if i % 2 else 1.0
			var leaf := Vector2(dir * 30.0 * u, 0).rotated(dir * (0.7 + 0.1 * sin(t * 1.3 + i)))
			var side := leaf.orthogonal().normalized() * 3.2 * u
			draw_colored_polygon(PackedVector2Array([pts[i], pts[i] + leaf * 0.5 + side, pts[i] + leaf, pts[i] + leaf * 0.5 - side]), color)


## Pale petals drifting across the art area.
func _petals(gy: float, u: float, t: float) -> void:
	for i in 12:
		var tt := t * (0.35 + i * 0.02) + i * 7.3
		var x := size.x + 20.0 - fmod(tt * 40.0 * u + i * 97.0, size.x + 40.0)
		var y := fmod(tt * 22.0 * u + i * 53.0, gy)
		var p := Vector2(x + sin(tt * 2.0) * 10.0 * u, y)
		_ellipse(p, 4.0 * u, 2.0 * u, Color(0.96, 0.9, 0.92, 0.8), tt)


# ---------------------------------------------------------------- inn

func _draw_inn() -> void:
	var u := _u()
	var gy := _ground()
	var t := _time
	var fy := gy + 14.0 * u
	var h := 120.0 * u
	var floor_y := gy - 20.0 * u
	_gradient(Rect2(0, 0, size.x, floor_y), Color("17120e"), Color("34291f"))
	for l in [-30.0, 168.0, 372.0]:
		draw_rect(Rect2(_x(l) - 5.0 * u, 0, 10.0 * u, floor_y), Color("120d0a"))
	_gradient(Rect2(0, floor_y, size.x, size.y - floor_y), Color("241b15"), Color("120d0a"))
	for i in range(1, 6):
		var py := floor_y + i * i * 5.0 * u
		draw_line(Vector2(0, py), Vector2(size.x, py), Color(0, 0, 0, 0.35), 1.5)

	# Window with rain; it lights up when thunder flashes.
	var win := Rect2(_x(22.0), gy - 215.0 * u, 88.0 * u, 96.0 * u)
	var fl := minf(1.0, _flash)
	draw_rect(win, Color8(int(22 + fl * 190), int(36 + fl * 190), int(44 + fl * 200)))
	_rain(win, 26, 520.0 * u, Color(0.75, 0.82, 0.86, 0.55))
	draw_rect(win, Color("120d0a"), false, 3.0 * u)
	draw_line(Vector2(win.get_center().x, win.position.y), Vector2(win.get_center().x, win.end.y), Color("120d0a"), 3.0 * u)
	draw_line(Vector2(win.position.x, win.get_center().y), Vector2(win.end.x, win.get_center().y), Color("120d0a"), 3.0 * u)
	_draw_door(u, gy)

	# Hanging lantern.
	var door: int = _preset.get("door", 0)
	var sway := sin(t * 1.3) * 0.03
	if door == -1:
		sway += maxf(0.0, 1.0 - _since) * 0.12 * sin(_since * 9.0)
	var pivot := Vector2(_x(200.0), 0)
	var lantern := pivot + Vector2(0, gy - 175.0 * u).rotated(sway)
	draw_line(pivot, lantern, Color("0c0907"), 2.0 * u)
	_ellipse(lantern, 13.0 * u, 17.0 * u, Color("8f2c24"))
	_ellipse(lantern, 8.0 * u, 12.0 * u, Color(1.0, 0.78, 0.43, 0.95))

	match _preset.get("figure", ""):
		"ferry":
			_person(_x(125.0), fy, h, {"sit": true, "color": YAN_ROBE, "hair": "tail", "letter": true, "arm": 1.1, "lean": 0.03 * sin(t * 1.2)})
			_person(_x(255.0), fy, h, {"facing": -1.0, "sit": true, "color": OLD_ROBE, "hair": "wisp", "arm": 1.1, "lean": 0.06 + 0.02 * sin(t * 0.9)})
			_draw_table(fy, h, u)
		"bandits":
			_person(_x(55.0), fy, h * 0.92, {"sit": true, "color": OLD_ROBE, "hair": "wisp", "lean": 0.04})
			_person(_x(120.0), fy, h, {"color": YAN_ROBE, "hair": "tail", "sword": "sheath", "arm": 1.2, "lean": 0.02 * sin(t * 1.8), "letter": true})
			var appear := clampf((_since - 0.8) / 0.5, 0.0, 1.0)
			if appear > 0.0:
				var gx := 330.0 - 40.0 * _ease_out(clampf((_since - 0.8) / 1.2, 0.0, 1.0))
				var cloak := {"facing": -1.0, "color": BANDIT, "hat": true, "sword": "sabre", "arm": 0.6, "alpha": appear, "rim": Color(0.63, 0.75, 0.86, 0.35), "resent": 0.7}
				cloak["sword_angle"] = -0.4
				_person(_x(356.0), fy - 8.0 * u, h * 0.86, cloak)
				cloak["sword_angle"] = -0.5
				_person(_x(335.0), fy - 3.0 * u, h * 0.93, cloak)
				_person(_x(gx), fy, h * 1.02, {"facing": -1.0, "color": GU_ROBE, "sash": SEAL, "hair": "bun", "sword": "sabre", "arm": 0.7, "sword_angle": -0.3, "alpha": appear, "skin": Color("7a5f4c"), "resent": 1.0})
		"after":
			_person(_x(55.0), fy, h * 0.92, {"sit": true, "color": OLD_ROBE, "hair": "wisp", "lean": 0.04})
			_person(_x(120.0), fy, h, {"color": YAN_ROBE, "hair": "tail", "sword": "draw", "arm": 0.65, "sword_angle": 0.95, "lean": 0.03 + 0.015 * sin(t * 2.4), "wound": _flag("wound") == true})
			draw_rect(Rect2(_x(300.0), gy - 70.0 * u, 50.0 * u, 84.0 * u), Color("3a3733"))
			draw_rect(Rect2(_x(308.0), gy - 40.0 * u, 34.0 * u, 7.0 * u), Color(1.0, 0.55, 0.24, 0.5 + 0.25 * sin(t * 6.0)))
			_person(_x(270.0), fy, h, {"facing": -1.0, "sit": true, "color": GU_ROBE, "sash": SEAL, "hair": "bun", "lean": 0.3, "arm": 1.3, "skin": Color("7a5f4c"), "resent": 0.3})
			draw_line(Vector2(_x(215.0), fy + 2.0 * u), Vector2(_x(165.0), fy + 6.0 * u), Color("c9d3d0"), 2.5 * u)
		"duel":
			_draw_duel(fy, h, u)

	# Warm lantern glow over everything.
	var flicker := 0.86 + 0.1 * sin(t * 9.3) + 0.05 * sin(t * 14.7 + 1.3)
	for i in 10:
		var k := 1.0 - i / 10.0
		draw_circle(lantern, 270.0 * u * k, Color(1.0, 0.7, 0.35, 0.03 * flicker))

	# Thunder: once as the door bursts, then now and then during the duel.
	if door == -1 and not _thundered and _since > 0.2:
		_thundered = true
		_flash = 1.0
		_shake = 6.0
	if _preset.get("figure", "") == "duel" and not reduced_motion and _since > _next_thunder:
		_flash = 0.6
		_next_thunder = _since + randf_range(7.0, 11.0)

	# Vignette at the edges of the art.
	for i in 6:
		var w := (6 - i) * 14.0 * u
		draw_rect(Rect2(0, 0, w, gy + 40.0 * u), Color(0, 0, 0, 0.06))
		draw_rect(Rect2(size.x - w, 0, w, gy + 40.0 * u), Color(0, 0, 0, 0.06))


func _draw_door(u: float, gy: float) -> void:
	var door := Rect2(_x(285.0), gy - 235.0 * u, 80.0 * u, 215.0 * u)
	var kind: int = _preset.get("door", 0)
	var open := 0.0
	if kind == 1:
		open = 1.0
	elif kind == -1:
		open = _ease_out(clampf((_since - 0.25) / 0.4, 0.0, 1.0))
	if open > 0.0:
		_gradient(door, Color("2d3d46"), Color("101a20"))
		_rain(door, 30, 620.0 * u, Color(0.75, 0.82, 0.86, 0.5))
	var pw := door.size.x * (1.0 - open * 0.92)
	var panel := Rect2(door.end.x - pw, door.position.y, pw, door.size.y)
	draw_rect(panel, Color("2b1d13"))
	for i in range(1, 4):
		var px := panel.position.x + pw * i / 4.0
		draw_line(Vector2(px, panel.position.y), Vector2(px, panel.end.y), Color(0, 0, 0, 0.4), 1.5)
	draw_rect(door, Color("0f0a07"), false, 5.0 * u)


func _draw_table(fy: float, h: float, u: float) -> void:
	var ty := fy - 0.46 * h
	draw_rect(Rect2(_x(100.0), ty, 200.0 * u, 8.0 * u), Color("3b2a1c"))
	draw_rect(Rect2(_x(108.0), ty + 8.0 * u, 8.0 * u, fy - ty), Color("2a1d13"))
	draw_rect(Rect2(_x(284.0), ty + 8.0 * u, 8.0 * u, fy - ty), Color("2a1d13"))
	_ellipse(Vector2(_x(200.0), ty - 14.0 * u), 10.0 * u, 14.0 * u, Color("5a3b24"))
	draw_rect(Rect2(_x(200.0) - 4.0 * u, ty - 32.0 * u, 8.0 * u, 8.0 * u), Color("3a2615"))
	_ellipse(Vector2(_x(165.0), ty - 2.0 * u), 6.0 * u, 3.0 * u, Color("d8cfc0"))
	_ellipse(Vector2(_x(235.0), ty - 2.0 * u), 6.0 * u, 3.0 * u, Color("d8cfc0"))


## Rain streaks inside a rect. Positions come from a hash of the drop index,
## so there is no per-drop state to keep.
func _rain(area: Rect2, count: int, speed: float, color: Color) -> void:
	var u := _u()
	for i in count:
		var seed_x := fposmod(sin(i * 12.9898) * 43758.5453, 1.0)
		var seed_y := fposmod(sin(i * 78.233) * 12543.123, 1.0)
		var v := 0.8 + 0.5 * fposmod(seed_x * 7.0, 1.0)
		var y := fposmod(seed_y + _time * v * speed / area.size.y, 1.0)
		var p := area.position + Vector2(seed_x * area.size.x, y * area.size.y)
		var length := 14.0 * u * v
		var end := Vector2(p.x - length * 0.18, minf(p.y + length, area.end.y))
		draw_line(p, end, color, maxf(1.0, 1.2 * u))


# ---------------------------------------------------------------- duel

func _yan_pose(id: String, p: float) -> Dictionary:
	var u := _u()
	var b := sin(PI * clampf(p, 0.0, 1.0))
	match id:
		"willow":
			return {"dx": 8.0 * u * b, "lean": -0.12 * b, "arm": 0.2, "sword": -1.0 + 1.5 * _ease_io(clampf(p, 0.0, 1.0))}
		"crane":
			var q := _ease_out(clampf(p / 0.5, 0.0, 1.0))
			return {"dx": 36.0 * u * b, "lean": 0.12 * b, "arm": -0.8 + 1.2 * q, "sword": -1.6 + 2.1 * q}
		"step":
			return {"dx": -30.0 * u * b, "lean": -0.05 * b, "arm": 0.5, "sword": -0.5}
		"water":
			return {"dx": 0.0, "lean": 0.0, "arm": 0.9, "sword": 0.9 - 0.2 * b}
	return {"dx": 0.0, "lean": 0.0, "arm": 0.4, "sword": -0.35}


func _gu_pose(p: float, linked: bool) -> Dictionary:
	var u := _u()
	var pp := clampf(p, 0.0, 1.0)
	if pp < 0.5:
		return {"dx": -24.0 * u * _ease_out(pp / 0.5), "lean": 0.0, "arm": 0.5, "sword": -1.5 + 2.1 * _ease_out(clampf((pp - 0.2) / 0.3, 0.0, 1.0))}
	var r := _ease_out((pp - 0.5) / 0.5)
	if linked:
		return {"dx": -24.0 * u + 40.0 * u * r, "lean": -0.2 * r, "arm": 0.5, "sword": 0.6 + 0.5 * r}
	return {"dx": -24.0 * u + 30.0 * u * r, "lean": -0.06 * r, "arm": 0.5, "sword": 0.6}


func _draw_duel(fy: float, h: float, u: float) -> void:
	var t := _time
	var yan_x := _x(135.0)
	var gu_x := _x(265.0)
	var yp := {"dx": 0.0, "lean": 0.02 * sin(t * 1.8), "arm": 0.4, "sword": -0.35}
	var gp := {"dx": 0.0, "lean": 0.015 * sin(t * 1.6 + 1.0), "arm": 0.5, "sword": -0.3}
	var hit := Vector2(_x(200.0), fy - h * 0.55)
	if _move != "":
		var p := _since - _move_at
		var w := 1.0 if p <= 1.0 else clampf(1.0 - (p - 1.0) / 0.45, 0.0, 1.0)
		yp = _mix(yp, _yan_pose(_move, minf(p, 1.0)), w)
		gp = _mix(gp, _gu_pose(minf(p, 1.0), _move_linked), w)
		if p >= 0.5 and not _sparked:
			_sparked = true
			_spawn_hit(hit + Vector2(6.0 * u if _move == "crane" else 0.0, 0.0), u)
		if _move == "water" and p < 1.0:
			_ellipse_outline(Vector2(yan_x, fy + 2.0 * u), (20.0 + p * 70.0) * u, (6.0 + p * 16.0) * u, Color(0.78, 0.88, 0.9, 0.6 * (1.0 - p)), 2.0 * u)
		if _move == "step" and p > 0.0 and p < 1.0:
			for i in [1, 2]:
				var ghost_p: float = p - 0.07 * i
				if ghost_p > 0.0:
					var g := _yan_pose("step", ghost_p)
					_person(yan_x + g["dx"], fy, h, {"color": YAN_ROBE, "hair": "tail", "sword": "draw", "arm": g["arm"], "sword_angle": g["sword"], "lean": g["lean"], "alpha": 0.2 / i})

	var yan_wound := false
	var gu_sit := false
	var gu_sword := "sabre"
	var sword_fly := -1.0
	if _duel_links >= 0:
		var fp := clampf((_since - _duel_end_at) / 1.3, 0.0, 1.0)
		var e := _ease_out(fp)
		match _duel_links:
			2:
				yp = {"dx": 12.0 * u * e, "lean": 0.0, "arm": -0.5, "sword": -1.3}
				gp = {"dx": 10.0 * u * e, "lean": 0.15 * e, "arm": 0.8, "sword": 0.0}
				sword_fly = clampf((_since - _duel_end_at) / 1.1, 0.0, 1.0)
			1:
				yp = {"dx": 0.0, "lean": 0.07 * e, "arm": 0.7, "sword": 0.6}
				gp = {"dx": 14.0 * u * e, "lean": 0.3 * e, "arm": 0.8, "sword": 0.0}
				yan_wound = fp > 0.5
			_:
				yp = {"dx": -6.0 * u * e, "lean": 0.14 * e, "arm": 0.6, "sword": 0.8}
				gp = {"dx": 16.0 * u * e, "lean": -0.5 * e, "arm": 0.8, "sword": 0.0}
		gu_sit = fp > 0.3
		gu_sword = ""
		if _duel_links < 2:
			draw_line(Vector2(gu_x + 40.0 * u, fy + 4.0 * u), Vector2(gu_x + 90.0 * u, fy + 8.0 * u), Color("c9d3d0"), 2.5 * u)

	_person(yan_x + yp["dx"], fy, h, {"color": YAN_ROBE, "hair": "tail", "sword": "draw", "arm": yp["arm"], "sword_angle": yp["sword"], "lean": yp["lean"], "letter": true, "wound": yan_wound})
	_person(gu_x + gp["dx"], fy, h, {"facing": -1.0, "color": GU_ROBE, "sash": SEAL, "hair": "bun", "sword": gu_sword, "sit": gu_sit, "arm": gp["arm"], "sword_angle": gp["sword"], "lean": gp["lean"], "skin": Color("7a5f4c"), "resent": 1.0 if _duel_links < 0 else 0.3})
	if sword_fly >= 0.0:
		var s := sword_fly
		var pos := Vector2(gu_x + 10.0 * u + s * 150.0 * u, fy - h * 0.6 - 90.0 * u * sin(PI * s) + 70.0 * u * s * s)
		var dir := Vector2.RIGHT.rotated(s * 11.0 if s < 1.0 else 1.35) * 34.0 * u
		draw_line(pos - dir, pos + dir, BLADE, 2.5 * u)


func _spawn_hit(at: Vector2, u: float) -> void:
	var arc: Array = SLASHES[_move]
	_slashes.append({"pos": at, "from": arc[0], "to": arc[1], "r": arc[2] * u, "age": 0.0, "dur": 0.5, "linked": _move_linked})
	var spark_color := Color(1.0, 0.67, 0.43) if _move_linked else Color(1.0, 0.92, 0.75)
	for i in (22 if _move_linked else 12):
		_sparks.append({"pos": at, "vel": Vector2(randf_range(-220, 220), randf_range(-260, 40)) * u, "age": 0.0, "life": randf_range(0.25, 0.6), "gravity": true, "color": spark_color})
	_shake = 9.0 if _move_linked else 4.0


func _draw_slashes() -> void:
	for s in _slashes:
		var q: float = s["age"] / s["dur"]
		var a0: float = s["from"]
		var a1: float = s["to"]
		var head := a0 + (a1 - a0) * _ease_out(minf(q * 1.6, 1.0))
		var tail := a0 + (a1 - a0) * _ease_out(maxf(0.0, q * 1.6 - 0.6))
		if absf(head - tail) < 0.01:
			continue
		var color := Color("c8422f") if s["linked"] else Color("d6dede")
		var width := (11.0 if s["linked"] else 5.0) * _u()
		draw_arc(s["pos"], s["r"], tail, head, 24, Color(color, 1.0 - q), width, true)


func _draw_particles() -> void:
	for p in _sparks:
		var a: float = 1.0 - p["age"] / p["life"]
		var pos: Vector2 = p["pos"]
		var vel: Vector2 = p["vel"]
		var color: Color = p["color"]
		draw_line(pos, pos - vel * 0.03, Color(color, a), 2.0 * _u())
	for p in _embers:
		var a: float = 1.0 - p["age"] / p["life"]
		draw_circle(p["pos"], 2.2 * _u() * a + 0.6, Color(1.0, (120.0 + 80.0 * a) / 255.0, 0.24, a))


# ---------------------------------------------------------------- figures

## A silhouette figure standing (or sitting) at x with feet on fy, h tall.
## Returns the front hand's position, for effects like embers.
## Options: facing, sit, color, rim, sash, skin, hair (tail, bun, wisp, long),
## ribbon, hat, arm, sword (draw, sheath, sabre), sword_angle, lean, alpha,
## walk, windy, wound, letter, paper, pole, resent (0-1 dark mist).
func _person(x: float, fy: float, h: float, o: Dictionary = {}) -> Vector2:
	var f: float = o.get("facing", 1.0)
	var sit: bool = o.get("sit", false)
	var alpha: float = o.get("alpha", 1.0)
	var col: Color = o.get("color", INK)
	col.a *= alpha
	var windy: float = o.get("windy", 1.0)
	var lean: float = o.get("lean", 0.0)
	var t := _time
	var sh_y := -h * 0.6 if sit else -h * 0.8
	var hip_y := -h * 0.3 if sit else -h * 0.44
	var hr := h * 0.07
	var head_y := sh_y - h * 0.09
	var sw := sin(t * 1.6 + x * 0.05) * h * 0.012 * windy
	var arm_a: float = o.get("arm", 1.0 if sit else 1.4)

	# Mirror with scale, then lean. Rotation is flipped with the scale so a
	# positive lean always tips the figure forward.
	draw_set_transform(_offset + Vector2(x, fy), lean * f, Vector2(f, 1.0))

	var resent: float = o.get("resent", 0.0)
	if resent > 0.0:
		_resentment(h, resent * alpha)

	if sit:
		draw_polyline(PackedVector2Array([Vector2(0, hip_y), Vector2(h * 0.2, hip_y + h * 0.03), Vector2(h * 0.2, -h * 0.01)]), col, h * 0.085, true)
	else:
		var a1 := 0.05
		var a2 := -0.06
		if o.get("walk") != null:
			var walk: float = o["walk"]
			a1 = sin(walk) * 0.45
			a2 = -sin(walk) * 0.45
		var leg := -hip_y
		draw_line(Vector2(h * 0.03, hip_y), Vector2(h * 0.03 + sin(a1) * leg, hip_y + cos(a1) * leg), col, h * 0.085, true)
		draw_line(Vector2(-h * 0.03, hip_y), Vector2(-h * 0.03 + sin(a2) * leg, hip_y + cos(a2) * leg), col, h * 0.085, true)

	# Robe: shoulders flaring out to a hem that sways in the wind.
	var hem := hip_y + h * 0.12 if sit else -h * 0.14
	var mid := (sh_y + hem) / 2.0
	var robe := PackedVector2Array()
	robe.append_array(_quad(Vector2(h * 0.12, sh_y), Vector2(h * 0.17, mid), Vector2(h * 0.21 + sw, hem), 6))
	robe.append_array(_quad(Vector2(-h * 0.21 + sw, hem), Vector2(-h * 0.17, mid), Vector2(-h * 0.12, sh_y), 6))
	draw_colored_polygon(robe, col)
	# Pale robes get an ink outline so they read against mist and sky.
	var pale := (col.r + col.g + col.b) / 3.0 > 0.6
	var rim: Color = o.get("rim", Color(INK, 0.6) if pale else Color(0.94, 0.75, 0.43, 0.35))
	rim.a *= alpha
	var outline := robe.duplicate()
	outline.append(robe[0])
	draw_polyline(outline, rim, maxf(1.0, h * 0.012), true)
	var sash: Color = o.get("sash", Color(1, 1, 1, 0.14))
	sash.a *= alpha
	draw_line(Vector2(-h * 0.15, hip_y - h * 0.02), Vector2(h * 0.15, hip_y - h * 0.02), sash, h * 0.03)
	if o.get("letter", false):
		draw_circle(Vector2(h * 0.08, sh_y + h * 0.15), h * 0.024, Color(SEAL, (0.6 + 0.4 * sin(t * 3.0)) * alpha))

	# Back arm and head.
	draw_line(Vector2(-h * 0.08, sh_y + h * 0.03), Vector2(-h * 0.1, hip_y + h * 0.02), col, h * 0.06, true)
	var skin: Color = o.get("skin", SKIN)
	skin.a *= alpha
	var head := Vector2(0, head_y)
	draw_circle(head, hr, skin)
	var hair_col := Color(HAIR, alpha)
	var hair: String = o.get("hair", "")
	var hs := sin(t * 2.2) * h * 0.03 * windy
	match hair:
		"tail", "bun", "long":
			_half_disc(head, hr * 1.06, hair_col)
			draw_circle(head + Vector2(-h * 0.01, -hr * 1.2), hr * 0.45, hair_col)
			if hair == "tail":
				draw_polyline(_quad(head + Vector2(-h * 0.04, -hr * 0.4), Vector2(-h * 0.2 + hs, head_y + h * 0.02), Vector2(-h * 0.17 + hs * 1.4, head_y + h * 0.22), 8), hair_col, h * 0.035, true)
			elif hair == "long":
				# Long loose hair down the back, cultivator style.
				var tip := Vector2(-h * 0.1 + hs * 1.6, sh_y + h * 0.32)
				var hair_pts := _quad(head + Vector2(-hr, 0), Vector2(-h * 0.16 + hs, sh_y + h * 0.05), tip, 10)
				hair_pts.append_array(_quad(tip, Vector2(-h * 0.04 + hs * 0.5, sh_y + h * 0.1), head + Vector2(hr * 0.4, hr * 0.2), 10))
				draw_colored_polygon(hair_pts, hair_col)
		"wisp":
			var white := Color(0.81, 0.82, 0.81, alpha)
			_half_disc(head, hr * 1.06, white)
			draw_colored_polygon(PackedVector2Array([head + Vector2(-hr * 0.6, hr * 0.5), head + Vector2(hr * 0.6, hr * 0.5), head + Vector2(0, hr * 2.1)]), white)
	if o.get("ribbon", false):
		# Forehead ribbon with long tails streaming in the wind.
		var band := Color(0.93, 0.95, 0.97, alpha)
		draw_line(head + Vector2(-hr, -hr * 0.35), head + Vector2(hr, -hr * 0.35), band, h * 0.018)
		for k in 2:
			var start := head + Vector2(-hr, -hr * 0.3)
			var end := start + Vector2(-h * (0.32 + k * 0.06) + hs * 2.0, h * (0.1 + k * 0.05))
			var ctrl := start + Vector2(-h * 0.15, -h * 0.04 + sin(t * 2.6 + k) * h * 0.04 * windy)
			draw_polyline(_quad(start, ctrl, end, 10), band, h * 0.012, true)
	if o.get("hat", false):
		draw_colored_polygon(PackedVector2Array([head + Vector2(-h * 0.17, -hr * 0.3), head + Vector2(0, -hr * 2.2), head + Vector2(h * 0.17, -hr * 0.3)]), Color(Color("2b2a22"), alpha))

	# Front arm and whatever it holds.
	var shoulder := Vector2(h * 0.09, sh_y + h * 0.03)
	var hand := shoulder + Vector2(cos(arm_a), sin(arm_a)) * h * 0.28
	draw_line(shoulder, hand, col, h * 0.065, true)
	if o.get("wound", false):
		var m := shoulder + Vector2(cos(arm_a), sin(arm_a)) * h * 0.15
		draw_line(m + Vector2(-h * 0.03, -h * 0.02), m + Vector2(h * 0.03, h * 0.03), Color(SEAL, alpha), h * 0.028)
	var sa: float = o.get("sword_angle", -0.1)
	match o.get("sword", ""):
		"draw":
			var tip := hand + Vector2(cos(sa), sin(sa)) * h * 0.8
			draw_line(hand, tip, Color(BLADE, alpha), h * 0.022, true)
			var guard := Vector2(-sin(sa), cos(sa)) * h * 0.05
			draw_line(hand - guard, hand + guard, Color(Color("3b3128"), alpha), h * 0.035)
		"sheath":
			draw_line(Vector2(-h * 0.05, hip_y), Vector2(-h * 0.3, hip_y + h * 0.1), Color(Color("2a1d14"), alpha), h * 0.04)
		"sabre":
			var ctrl := hand + Vector2(cos(sa), sin(sa)) * h * 0.4 - Vector2(0, h * 0.06)
			var end := hand + Vector2(cos(sa + 0.15), sin(sa + 0.15)) * h * 0.7
			draw_polyline(_quad(hand, ctrl, end, 8), Color(Color("c9d3d0"), alpha), h * 0.03, true)
	var paper: float = o.get("paper", 0.0)
	if paper > 0.0:
		var c := hand
		var r := Vector2(h * 0.07, h * 0.05) * paper
		var rot := Transform2D(-0.3, Vector2.ZERO)
		var sheet := PackedVector2Array([c + rot * Vector2(-r.x, -r.y), c + rot * Vector2(r.x, -r.y), c + rot * Vector2(r.x, r.y), c + rot * Vector2(-r.x, r.y)])
		draw_colored_polygon(sheet, Color(Color("e8e2d2"), alpha))
		draw_circle(c, h * 0.016 * paper, Color(SEAL, alpha))
	if o.get("pole", false):
		draw_line(hand + Vector2(0, -h * 0.5), Vector2(hand.x + h * 0.35, h * 0.12), Color(Color("6b5238"), alpha), h * 0.03)

	draw_set_transform(_offset)
	return Vector2(x, fy) + Vector2(f * hand.x, hand.y).rotated(lean * f)


## Resentful energy: dark mist rising off a figure, drawn in its local space.
func _resentment(h: float, strength: float) -> void:
	for i in 7:
		var q := fposmod(_time * 0.35 + i / 7.0, 1.0)
		var p := Vector2(sin(_time * 1.3 + i * 1.7) * h * 0.22, -h * 0.1 - q * h * 0.9)
		draw_circle(p, h * (0.05 + 0.05 * q), Color(0.16, 0.07, 0.2, 0.45 * (1.0 - q) * strength))


# ---------------------------------------------------------------- helpers

func _flag(key: String) -> Variant:
	if state == null:
		return null
	return state.lookup(key)


func _gradient(rect: Rect2, top: Color, bottom: Color) -> void:
	var pts := PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)])
	draw_polygon(pts, PackedColorArray([top, top, bottom, bottom]))


## Points along a quadratic Bezier curve from a to c, bending toward b.
func _quad(a: Vector2, b: Vector2, c: Vector2, steps: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in steps + 1:
		var q := float(i) / steps
		pts.append(a.lerp(b, q).lerp(b.lerp(c, q), q))
	return pts


func _ellipse(center: Vector2, rx: float, ry: float, color: Color, angle := 0.0) -> void:
	var pts := PackedVector2Array()
	for i in 24:
		var a := TAU * i / 24.0
		pts.append(center + Vector2(cos(a) * rx, sin(a) * ry).rotated(angle))
	draw_colored_polygon(pts, color)


func _ellipse_outline(center: Vector2, rx: float, ry: float, color: Color, width: float) -> void:
	var pts := PackedVector2Array()
	for i in 33:
		var a := TAU * i / 32.0
		pts.append(center + Vector2(cos(a) * rx, sin(a) * ry))
	draw_polyline(pts, color, width, true)


## Top half of a circle, used for hair.
func _half_disc(center: Vector2, r: float, color: Color) -> void:
	var pts := PackedVector2Array()
	for i in 13:
		var a := PI * 1.02 + PI * i / 12.0
		pts.append(center + Vector2(cos(a), sin(a)) * r)
	draw_colored_polygon(pts, color)


func _mix(a: Dictionary, b: Dictionary, w: float) -> Dictionary:
	var out := {}
	for k in b:
		out[k] = lerpf(a.get(k, b[k]), b[k], w)
	return out


func _ease_out(x: float) -> float:
	return 1.0 - pow(1.0 - x, 3.0)


func _ease_io(x: float) -> float:
	return 4.0 * x * x * x if x < 0.5 else 1.0 - pow(-2.0 * x + 2.0, 3.0) / 2.0
