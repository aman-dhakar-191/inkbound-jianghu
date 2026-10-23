extends RefCounted
## Colors and the Godot Theme for every screen. Placeholder palette: pale
## sect-robe white, mountain mist, ink and a red seal accent.

const PAPER := Color("eef1ee")
const PARCHMENT := Color("f4efe2")
const INK := Color("1b2428")
const INK_DARK := Color("0c1112")
const SOFT := Color("56676a")
const LINE := Color(0.106, 0.141, 0.157, 0.35)
const SECT_BLUE := Color("5f84a0")
const TINT := Color(0.373, 0.518, 0.627, 0.14)
const SEAL := Color("a8322d")

## 48dp at the 720px-wide design size is about 96px.
const TOUCH_MIN := 96.0


static func build() -> Theme:
	var t := Theme.new()
	t.default_font_size = 30
	t.set_color("font_color", "Label", INK)
	t.set_constant("line_spacing", "Label", 8)

	_label(t, "Muted", 26, SOFT)
	_label(t, "Delta", 24, SECT_BLUE)
	_label(t, "Heading", 46, INK)
	_label(t, "TitleGlyph", 150, INK)
	_label(t, "TitleLatin", 46, INK)
	_label(t, "Rule", 24, SOFT)
	_label(t, "ChainLabel", 42, INK)
	_label(t, "BarName", 36, INK)
	_label(t, "BarStats", 28, SOFT)
	_label(t, "ScrollTitle", 48, INK)
	_label(t, "FieldLabel", 22, SOFT)
	_label(t, "ScrollSeal", 44, SEAL)
	_label(t, "SpeakerName", 26, SECT_BLUE)
	_label(t, "Subtitle", 34, INK)

	t.set_type_variation("StoryPanel", "PanelContainer")
	t.set_stylebox("panel", "StoryPanel", _box(Color(PAPER, 0.96), Color.TRANSPARENT, 0, [40, 28, 40, 80]))
	t.set_type_variation("TopBar", "PanelContainer")
	t.set_stylebox("panel", "TopBar", _box(Color(PAPER, 0.92), LINE, 2, [22, 10, 22, 10]))
	# Holds the current subtitle; a tap target, so it keeps a fixed minimum height.
	t.set_type_variation("SubtitleBox", "PanelContainer")
	t.set_stylebox("panel", "SubtitleBox", _box(Color.TRANSPARENT, Color.TRANSPARENT, 0, [0, 8, 0, 8]))
	t.set_type_variation("ScrollSheet", "PanelContainer")
	t.set_stylebox("panel", "ScrollSheet", _box(PARCHMENT, LINE, 2, [36, 30, 36, 34]))

	# StyleBoxFlat has one border color, so the thick left edge carries the accent.
	var choice := _box(Color.TRANSPARENT, Color(SECT_BLUE, 0.7), 2, [28, 20, 28, 20])
	choice.border_width_left = 8
	_button(t, "ChoiceButton", choice, TINT, INK)

	_button(t, "PrimaryButton", _box(INK, Color.TRANSPARENT, 0, [40, 22, 40, 22]), Color(INK, 0.85), PAPER)

	_button(t, "QuietButton", _box(Color.TRANSPARENT, Color.TRANSPARENT, 0, [16, 8, 16, 8]), TINT, SOFT)
	t.set_font_size("font_size", "QuietButton", 26)

	var move := _box(PAPER, INK, 3, [4, 4, 4, 4])
	move.set_corner_radius_all(66)
	_button(t, "MoveButton", move, Color(SECT_BLUE, 0.25), INK)
	t.set_font_size("font_size", "MoveButton", 30)
	return t


static func _label(t: Theme, variation: String, size: int, color: Color) -> void:
	t.set_type_variation(variation, "Label")
	t.set_font_size("font_size", variation, size)
	t.set_color("font_color", variation, color)


static func _box(bg: Color, border: Color, width: int, margins: Array) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = border
	box.set_border_width_all(width)
	box.set_corner_radius_all(3)
	box.content_margin_left = margins[0]
	box.content_margin_top = margins[1]
	box.content_margin_right = margins[2]
	box.content_margin_bottom = margins[3]
	return box


## Same box for every state, with a tint when pressed or hovered.
static func _button(t: Theme, variation: String, normal: StyleBoxFlat, pressed_bg: Color, font: Color) -> void:
	t.set_type_variation(variation, "Button")
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = pressed_bg
	var focus := normal.duplicate() as StyleBoxFlat
	focus.bg_color = Color.TRANSPARENT
	focus.border_color = SECT_BLUE
	focus.set_border_width_all(4)
	var disabled := normal.duplicate() as StyleBoxFlat
	disabled.bg_color = Color(normal.bg_color, normal.bg_color.a * 0.55)
	t.set_stylebox("normal", variation, normal)
	t.set_stylebox("hover", variation, pressed)
	t.set_stylebox("pressed", variation, pressed)
	t.set_stylebox("hover_pressed", variation, pressed)
	t.set_stylebox("focus", variation, focus)
	t.set_stylebox("disabled", variation, disabled)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		t.set_color(state, variation, font)
	t.set_color("font_disabled_color", variation, Color(font, 0.55))
