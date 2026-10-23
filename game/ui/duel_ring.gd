extends Control
## The four-move ring for the chain duel. Draws a line between picks: solid red
## for a link, dashed grey for a break. Emits each pick; scoring lives in core.

signal move_picked(sequence: Array, linked: bool)

const DuelRules := preload("res://game/core/duel_rules.gd")
const UiTheme := preload("res://game/ui/ui_theme.gd")
const Strings := preload("res://game/core/strings.gd")

const RING := 440.0
const NODE := 132.0
## Pause between picks so each move's animation can play.
const PICK_LOCK := 0.9

var sequence: Array[String] = []
var _segments: Array = []
var _buttons := {}
var _locked := false


func setup(strings: Strings) -> void:
	custom_minimum_size = Vector2(RING, RING)
	size_flags_horizontal = SIZE_SHRINK_CENTER
	for id in DuelRules.MOVES:
		var b := Button.new()
		b.theme_type_variation = "MoveButton"
		b.text = "%s\n%s" % [strings.text("duel.move.%s.glyph" % id), strings.text("duel.move.%s" % id)]
		b.tooltip_text = strings.text("duel.move.%s" % id)
		b.size = Vector2(NODE, NODE)
		b.position = _center(id) - Vector2(NODE, NODE) / 2.0
		b.pressed.connect(_pick.bind(id))
		add_child(b)
		_buttons[id] = b


func _center(id: String) -> Vector2:
	match id:
		"willow":
			return Vector2(RING / 2.0, NODE / 2.0)
		"crane":
			return Vector2(RING - NODE / 2.0, RING / 2.0)
		"step":
			return Vector2(RING / 2.0, RING - NODE / 2.0)
	return Vector2(NODE / 2.0, RING / 2.0)


func _pick(id: String) -> void:
	if _locked or sequence.size() >= DuelRules.MOVES_PER_DUEL:
		return
	var linked := false
	if not sequence.is_empty():
		var prev: String = sequence[-1]
		linked = DuelRules.link_between(prev, id) != ""
		_segments.append([prev, id, linked])
	sequence.append(id)
	var picked: Button = _buttons[id]
	picked.add_theme_color_override("font_color", UiTheme.SEAL)
	if sequence.size() >= DuelRules.MOVES_PER_DUEL:
		for b in _buttons.values():
			b.disabled = true
	else:
		_locked = true
		get_tree().create_timer(PICK_LOCK).timeout.connect(_unlock)
	queue_redraw()
	move_picked.emit(sequence.duplicate(), linked)


func _unlock() -> void:
	_locked = false


func _draw() -> void:
	var c := Vector2(RING, RING) / 2.0
	var r := RING / 2.0 - NODE / 2.0
	for i in 48:
		var a := TAU * i / 48.0
		draw_circle(c + Vector2(cos(a), sin(a)) * r, 2.0, UiTheme.LINE)
	for seg in _segments:
		var a: Vector2 = _center(seg[0])
		var b: Vector2 = _center(seg[1])
		if seg[2]:
			draw_line(a, b, UiTheme.SEAL, 8.0, true)
		else:
			draw_dashed_line(a, b, UiTheme.SOFT, 3.0, 10.0)
