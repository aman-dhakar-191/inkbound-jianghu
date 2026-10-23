extends Control
## Plays a chapter from /data. Scene art fills the top of the screen and the
## story panel sits below it. The UI is built in code so chapters stay pure
## data: this script only knows the scene types "story", "duel" and "scroll".
##
## Story scenes play like a film: each line is voiced (game/audio/voice.gd)
## and shown as a subtitle, one at a time. Tapping the art or the subtitle
## finishes the line's text, then moves to the next line; Skip jumps to the
## choices, which appear after the last line.

const GameState := preload("res://game/core/game_state.gd")
const StoryEngine := preload("res://game/core/story_engine.gd")
const DuelRules := preload("res://game/core/duel_rules.gd")
const Strings := preload("res://game/core/strings.gd")
const DataLoader := preload("res://game/core/data_loader.gd")
const Backdrop := preload("res://game/fx/backdrop.gd")
const UiTheme := preload("res://game/ui/ui_theme.gd")
const DuelRing := preload("res://game/ui/duel_ring.gd")
const Voice := preload("res://game/audio/voice.gd")

## Only English is complete. zh.json covers UI labels and falls back to English.
const LANGUAGE := "en"
const FIRST_CHAPTER := "res://data/chapters/ch1.json"
## Seconds the screen takes to fade out and back in between scenes.
const FADE_OUT := 0.35
const FADE_IN := 0.45
## Delay between paragraphs appearing.
const STAGGER := 0.3
## Story scenes give more of the screen to the art; subtitles need little room.
const STORY_ART_SHARE := 0.56
const TITLE_ART_SHARE := 0.4
## Subtitle characters revealed per second.
const REVEAL_SPEED := 45.0
## Reading speed, in characters per second, for timing lines that aren't voiced.
const READ_SPEED := 16.0
## Pause after a voiced line before the next one starts.
const LINE_PAUSE := 0.5
const SETTINGS_PATH := "user://settings.cfg"

var strings: Strings
var engine: StoryEngine
var chapter: Dictionary

var _backdrop: Backdrop
var _safe_area: MarginContainer
var _bar: PanelContainer
var _bar_name: Label
var _bar_stats: Label
var _spacer: Control
var _scroll: ScrollContainer
var _content: VBoxContainer
var _veil: ColorRect
var _busy := false
var _appear_count := 0
var _duel_chain: Label
var _duel_count: Label
var _voice: Voice
var _voice_button: Button
var _art_share := TITLE_ART_SHARE

# Story scene playback.
var _lines: Array[Dictionary] = []
var _line_index := -1
## Bumped whenever the current line changes, so stale timers do nothing.
var _line_token := 0
var _lines_active := false
var _subtitle_name: Label
var _subtitle_text: Label
var _skip_button: Button
var _reveal_tween: Tween


func _ready() -> void:
	theme = UiTheme.build()
	var en: Dictionary = DataLoader.load_json("res://data/i18n/en.json")
	var table := en
	if LANGUAGE != "en":
		table = DataLoader.load_json("res://data/i18n/%s.json" % LANGUAGE)
	strings = Strings.new(table, en)
	chapter = DataLoader.load_json(FIRST_CHAPTER)
	_voice = Voice.new()
	_voice.language = LANGUAGE
	var speakers: Dictionary = DataLoader.load_json("res://data/voices.json")
	_voice.speakers = speakers
	_voice.line_finished.connect(_on_voice_finished)
	add_child(_voice)
	_load_settings()
	if _voice.crashed_last_time:
		# Speech crashed the game last time: stay on subtitles until the player
		# turns voice back on in the top bar.
		_voice.enabled = false
		_save_settings()
	_build_layout()
	get_viewport().size_changed.connect(_on_resized)
	_show_title()
	_on_resized.call_deferred()


func _build_layout() -> void:
	set_anchors_preset(PRESET_FULL_RECT)
	_backdrop = Backdrop.new()
	_backdrop.set_anchors_preset(PRESET_FULL_RECT)
	add_child(_backdrop)

	_safe_area = MarginContainer.new()
	_safe_area.set_anchors_preset(PRESET_FULL_RECT)
	add_child(_safe_area)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 0)
	_safe_area.add_child(column)

	_bar = PanelContainer.new()
	_bar.theme_type_variation = "TopBar"
	var bar_row := HBoxContainer.new()
	_bar.add_child(bar_row)
	_bar_name = Label.new()
	_bar_name.theme_type_variation = "BarName"
	_bar_name.size_flags_horizontal = SIZE_EXPAND_FILL
	_bar_name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bar_row.add_child(_bar_name)
	_bar_stats = Label.new()
	_bar_stats.theme_type_variation = "BarStats"
	_bar_stats.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bar_row.add_child(_bar_stats)
	_voice_button = Button.new()
	_voice_button.theme_type_variation = "QuietButton"
	_voice_button.custom_minimum_size.y = UiTheme.TOUCH_MIN
	_voice_button.focus_mode = FOCUS_NONE
	_voice_button.pressed.connect(_toggle_voice)
	bar_row.add_child(_voice_button)
	_update_voice_button()
	column.add_child(_bar)

	# The art area above the panel: tapping it moves the subtitles on.
	_spacer = Control.new()
	_spacer.gui_input.connect(_on_tap_input)
	column.add_child(_spacer)

	var panel := PanelContainer.new()
	panel.theme_type_variation = "StoryPanel"
	panel.size_flags_vertical = SIZE_EXPAND_FILL
	column.add_child(panel)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(_scroll)
	_content = VBoxContainer.new()
	_content.size_flags_horizontal = SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 26)
	_scroll.add_child(_content)

	_veil = ColorRect.new()
	_veil.color = UiTheme.INK_DARK
	_veil.set_anchors_preset(PRESET_FULL_RECT)
	_veil.mouse_filter = MOUSE_FILTER_IGNORE
	_veil.modulate.a = 0.0
	add_child(_veil)


func _on_resized() -> void:
	_apply_safe_area()
	var view := get_viewport_rect().size
	var art := view.y * _art_share
	var bar_h := _bar.size.y if _bar.visible else 0.0
	_spacer.custom_minimum_size.y = maxf(100.0, art - bar_h - _safe_area.get_theme_constant("margin_top"))
	_backdrop.horizon = art


## Keeps the bar and buttons clear of notches and gesture bars on phones.
func _apply_safe_area() -> void:
	if not OS.has_feature("mobile"):
		return
	var window := Vector2(DisplayServer.window_get_size())
	if window.x <= 0.0 or window.y <= 0.0:
		return
	var safe := Rect2(DisplayServer.get_display_safe_area())
	var to_view := get_viewport_rect().size / window
	_safe_area.add_theme_constant_override("margin_top", int(maxf(0.0, safe.position.y) * to_view.y))
	_safe_area.add_theme_constant_override("margin_bottom", int(maxf(0.0, window.y - safe.end.y) * to_view.y))
	_safe_area.add_theme_constant_override("margin_left", int(maxf(0.0, safe.position.x) * to_view.x))
	_safe_area.add_theme_constant_override("margin_right", int(maxf(0.0, window.x - safe.end.x) * to_view.x))


# ---------------------------------------------------------------- flow

## Fades to ink, runs the change, fades back. Ignores taps while fading.
func _transition(change: Callable) -> void:
	if _busy:
		return
	_busy = true
	_veil.mouse_filter = MOUSE_FILTER_STOP
	var tween := create_tween()
	tween.tween_property(_veil, "modulate:a", 1.0, FADE_OUT)
	tween.tween_callback(change)
	tween.tween_property(_veil, "modulate:a", 0.0, FADE_IN)
	tween.tween_callback(_end_transition)


func _end_transition() -> void:
	_busy = false
	_veil.mouse_filter = MOUSE_FILTER_IGNORE


func _show_title() -> void:
	engine = null
	_clear()
	_backdrop.state = null
	_backdrop.set_preset("title_peaks")
	_art_share = TITLE_ART_SHARE
	_bar.visible = false
	var glyph := _label(strings.text("title.main"), "TitleGlyph")
	glyph.autowrap_mode = TextServer.AUTOWRAP_OFF
	_label(strings.text("title.en"), "TitleLatin")
	_label(strings.text("title.sub"), "Muted")
	for stat in GameState.STATS:
		_label("%s   %s" % [strings.text("stat.%s.glyph" % stat), strings.text("stat.%s" % stat)], "Muted")
	_button(strings.text("ui.begin"), "PrimaryButton", _transition.bind(_start_chapter))
	_on_resized()


func _start_chapter() -> void:
	engine = StoryEngine.new(chapter, GameState.new())
	_render()


func _render() -> void:
	_clear()
	var scene := engine.scene()
	_backdrop.state = engine.state
	_backdrop.set_preset(str(scene.get("backdrop", "")))
	_bar.visible = true
	var number := int(scene.get("chapter_number", chapter.get("number", 1)))
	var status := str(scene.get("status", "ui.chapter"))
	_bar_name.text = "%s  ·  %s" % [strings.text("character." + engine.state.character), strings.text(status, {"n": number})]
	_bar_stats.text = "" if scene.get("hide_stats", false) else _stats_text()
	_art_share = STORY_ART_SHARE if engine.scene_type() == "story" else _backdrop.art_share()
	if not engine.last_delta.is_empty():
		_label(_delta_text(engine.last_delta), "Delta")
		engine.last_delta = {}
	match engine.scene_type():
		"duel":
			_render_duel(scene)
		"scroll":
			_render_scroll(scene)
		_:
			_render_story(scene)
	_on_resized()


func _render_story(scene: Dictionary) -> void:
	if scene.has("heading"):
		_label(_t(str(scene["heading"])), "Heading")
	var box := PanelContainer.new()
	box.theme_type_variation = "SubtitleBox"
	box.custom_minimum_size.y = 220
	box.gui_input.connect(_on_tap_input)
	var lines_box := VBoxContainer.new()
	box.add_child(lines_box)
	_subtitle_name = _make_label("", "SpeakerName")
	lines_box.add_child(_subtitle_name)
	_subtitle_text = _make_label("", "Subtitle")
	lines_box.add_child(_subtitle_text)
	_content.add_child(box)
	_lines = engine.lines()
	_line_index = -1
	_lines_active = true
	if _lines.size() > 1:
		_skip_button = _button(strings.text("ui.skip"), "QuietButton", _finish_lines)
		_skip_button.size_flags_horizontal = SIZE_SHRINK_END
	_next_line()


## Shows (and voices) the next line, or the choices after the last one.
func _next_line() -> void:
	_line_token += 1
	_line_index += 1
	if _line_index >= _lines.size():
		_show_choices()
		return
	var line: Dictionary = _lines[_line_index]
	var text := _show_line(line)
	var spoken := _voice.say(str(line["key"]), text, str(line["speaker"]))
	var wait := _reading_time(text)
	if spoken:
		# Only a safety net: the voice reporting its end normally moves on first.
		wait = wait * 2.0 + 3.0
	get_tree().create_timer(wait).timeout.connect(_on_line_timeout.bind(_line_token))


## Puts a line in the subtitle box and starts revealing it. Returns its text.
func _show_line(line: Dictionary) -> String:
	var speaker: Dictionary = _voice.speakers.get(str(line["speaker"]), {})
	_subtitle_name.text = strings.text(str(speaker["name"])) if speaker.has("name") else ""
	_subtitle_name.visible = _subtitle_name.text != ""
	var text := _t(str(line["key"]))
	_subtitle_text.text = text
	if _reveal_tween != null:
		_reveal_tween.kill()
	if _backdrop.reduced_motion:
		_subtitle_text.visible_ratio = 1.0
	else:
		_subtitle_text.visible_ratio = 0.0
		_reveal_tween = create_tween()
		_reveal_tween.tween_property(_subtitle_text, "visible_ratio", 1.0, text.length() / REVEAL_SPEED)
	return text


func _reading_time(text: String) -> float:
	return clampf(text.length() / READ_SPEED, 2.0, 12.0) + 0.6


func _on_line_timeout(token: int) -> void:
	if _lines_active and token == _line_token:
		_next_line()


func _on_voice_finished() -> void:
	if not _lines_active:
		return
	var token := _line_token
	await get_tree().create_timer(LINE_PAUSE).timeout
	if _lines_active and token == _line_token:
		_next_line()


func _on_tap_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
		_on_tap()


## First tap finishes revealing the line; the next one moves on.
func _on_tap() -> void:
	if not _lines_active or _busy:
		return
	if _reveal_tween != null and _reveal_tween.is_running():
		_reveal_tween.kill()
		_subtitle_text.visible_ratio = 1.0
		return
	_voice.stop()
	_next_line()


## Skip: stops the voice, shows the last line and the choices.
func _finish_lines() -> void:
	if not _lines_active:
		return
	_voice.stop()
	if not _lines.is_empty():
		_line_index = _lines.size() - 1
		_show_line(_lines[_line_index])
	_show_choices()


func _show_choices() -> void:
	_lines_active = false
	_line_token += 1
	if _reveal_tween != null:
		_reveal_tween.kill()
	if _subtitle_text != null:
		_subtitle_text.visible_ratio = 1.0
	if _skip_button != null:
		_content.remove_child(_skip_button)
		_skip_button.queue_free()
		_skip_button = null
	_appear_count = 0
	var choices := engine.choices()
	for i in choices.size():
		var choice: Dictionary = choices[i]
		_button(_t(str(choice.get("text", ""))), "ChoiceButton", _on_choice.bind(i))
	await get_tree().process_frame
	if _content.get_child_count() > 0:
		_scroll.ensure_control_visible(_content.get_child(_content.get_child_count() - 1))


func _toggle_voice() -> void:
	_voice.enabled = not _voice.enabled
	_update_voice_button()
	_save_settings()
	if not _voice.enabled and _lines_active and _line_index >= 0 and _line_index < _lines.size():
		# The line in progress loses its voice: time it like an unvoiced one.
		_voice.stop()
		_line_token += 1
		var text := _t(str(_lines[_line_index]["key"]))
		get_tree().create_timer(_reading_time(text)).timeout.connect(_on_line_timeout.bind(_line_token))


func _update_voice_button() -> void:
	_voice_button.text = strings.text("ui.voice_on" if _voice.enabled else "ui.voice_off")


func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		_voice.enabled = bool(cfg.get_value("audio", "voice", true))


func _save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)
	cfg.set_value("audio", "voice", _voice.enabled)
	cfg.save(SETTINGS_PATH)


func _on_choice(index: int) -> void:
	var choice: Dictionary = engine.choices()[index]
	if choice.get("action", "") == "restart":
		_transition(_show_title)
		return
	_transition(_choose_and_render.bind(index))


func _choose_and_render(index: int) -> void:
	engine.choose(index)
	_render()


func _render_duel(scene: Dictionary) -> void:
	var intro_key := engine.resolve(scene.get("intro"))
	var intro := _t(intro_key)
	_label("%s %s" % [intro, strings.text("duel.instruction")])
	_voice.say(intro_key, intro, "narrator")
	var ring := DuelRing.new()
	ring.setup(strings)
	ring.move_picked.connect(_on_move_picked)
	_appear(ring)
	_duel_chain = _label(" ", "ChainLabel")
	_duel_chain.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_duel_count = _label(strings.text("ui.move_count", {"n": 1}), "Muted")
	_duel_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label(strings.text("duel.rule"), "Rule")


func _on_move_picked(sequence: Array, linked: bool) -> void:
	_backdrop.strike(sequence[-1], linked)
	var glyphs := PackedStringArray()
	for id in sequence:
		glyphs.append(strings.text("duel.move.%s.glyph" % id))
	_duel_chain.text = " → ".join(glyphs)
	if sequence.size() < DuelRules.MOVES_PER_DUEL:
		_duel_count.text = strings.text("ui.move_count", {"n": sequence.size() + 1})
		return
	_duel_count.text = ""
	get_tree().create_timer(1.3).timeout.connect(_finish_duel.bind(sequence))


func _finish_duel(sequence: Array) -> void:
	if engine == null:
		return
	var result := engine.resolve_duel(sequence)
	var links: int = result["links"]
	_backdrop.finish_duel(links)
	_bar_stats.text = _stats_text()
	_appear_count = 0
	var heading := strings.text("duel.result.%d" % links)
	var form := strings.text("duel.no_form")
	if links > 0:
		form = strings.text("duel.form", {"technique": strings.text("technique." + str(result["technique"]))})
	_label(heading, "Heading")
	_label(form)
	_voice.say("duel.result.%d" % links, "%s. %s" % [heading, form], "narrator")
	_button(strings.text("ui.continue"), "PrimaryButton", _transition.bind(_advance_and_render))
	await get_tree().process_frame
	_scroll.ensure_control_visible(_content.get_child(_content.get_child_count() - 1))


func _render_scroll(scene: Dictionary) -> void:
	var intro_key := engine.resolve(scene.get("intro"))
	var intro := _t(intro_key)
	_label(intro)
	_voice.say(intro_key, "%s %s." % [intro, _t(engine.resolve(scene.get("title")))], "narrator")
	var sheet := PanelContainer.new()
	sheet.theme_type_variation = "ScrollSheet"
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	sheet.add_child(box)
	box.add_child(_make_label(strings.text("scroll.seal"), "ScrollSeal", HORIZONTAL_ALIGNMENT_RIGHT))
	box.add_child(_make_label(_t(engine.resolve(scene.get("title"))), "ScrollTitle"))
	for field in scene.get("fields", []):
		var gap := Control.new()
		gap.custom_minimum_size.y = 14
		box.add_child(gap)
		box.add_child(_make_label(strings.text(str(field["label"])), "FieldLabel"))
		box.add_child(_make_label(_t(engine.resolve(field["value"]))))
	_appear(sheet)
	_button(strings.text(str(scene.get("button", "ui.continue"))), "PrimaryButton", _transition.bind(_advance_and_render))


func _advance_and_render() -> void:
	engine.advance()
	_render()


# ---------------------------------------------------------------- widgets

func _clear() -> void:
	_lines_active = false
	_line_token += 1
	_skip_button = null
	_voice.stop()
	for child in _content.get_children():
		_content.remove_child(child)
		child.queue_free()
	_appear_count = 0
	_scroll.scroll_vertical = 0


func _make_label(text: String, variation := "", align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = SIZE_EXPAND_FILL
	l.horizontal_alignment = align
	if variation != "":
		l.theme_type_variation = variation
	return l


func _label(text: String, variation := "") -> Label:
	var l := _make_label(text, variation)
	_appear(l)
	return l


func _button(text: String, variation: String, on_press: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.theme_type_variation = variation
	b.custom_minimum_size.y = UiTheme.TOUCH_MIN
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if variation == "ChoiceButton":
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	else:
		b.size_flags_horizontal = SIZE_SHRINK_BEGIN
	b.pressed.connect(on_press)
	_appear(b)
	return b


## Adds a control to the story panel and fades it in after the ones before it.
func _appear(node: Control) -> void:
	_content.add_child(node)
	if _backdrop.reduced_motion:
		return
	node.modulate.a = 0.0
	var tween := node.create_tween()
	tween.tween_interval(_appear_count * STAGGER)
	tween.tween_property(node, "modulate:a", 1.0, 0.8)
	_appear_count += 1


## Translates a key, filling {technique} and similar from the game state.
func _t(key: String) -> String:
	var params := {}
	if engine != null:
		var raw := engine.text_params()
		for param in raw:
			params[param] = strings.text(str(raw[param]))
	return strings.text(key, params)


func _stats_text() -> String:
	var parts := PackedStringArray()
	for stat in GameState.STATS:
		parts.append("%s %d" % [strings.text("stat.%s.glyph" % stat), engine.state.stats[stat]])
	return "   ".join(parts)


func _delta_text(delta: Dictionary) -> String:
	var parts := PackedStringArray()
	for stat in delta:
		var amount := int(delta[stat])
		if amount != 0:
			parts.append("%s %s%d" % [strings.text("stat." + str(stat)), "+" if amount > 0 else "−", absi(amount)])
	return "  ·  ".join(parts)
