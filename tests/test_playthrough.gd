extends SceneTree
## Clicks through Chapter 1 in the real main scene, start to finish, so script
## errors in the UI and art code show up without a person playing.
## Run: godot --headless --path . -s res://tests/test_playthrough.gd
## Exits 0 when every step lands where expected. CI also fails on any
## "SCRIPT ERROR" in the output.

const DuelRing := preload("res://game/ui/duel_ring.gd")

## Longer than the fade between scenes (FADE_OUT + FADE_IN in main.gd).
const SCENE_WAIT := 1.2

var _checks := 0
var _failures := 0
var _main: Node


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_main = load("res://game/scenes/main.tscn").instantiate()
	root.add_child(_main)
	await _wait(0.5)
	_check(_main.engine == null, "starts on the title screen")

	_press_last()
	await _wait(SCENE_WAIT)
	_expect_scene("ferry")

	_press_choice(0)
	await _wait(SCENE_WAIT)
	_expect_scene("bandits")

	_press_choice(0)
	await _wait(SCENE_WAIT)
	_expect_scene("duel")

	var ring: Node = _find_ring()
	_check(ring != null, "duel ring is shown")
	if ring != null:
		for move in ["willow", "crane", "step"]:
			ring._pick(move)
			await _wait(1.0)
		await _wait(1.5)
		_check(_main.engine.state.links == 2, "duel scored two links")

	_press_last()
	await _wait(SCENE_WAIT)
	_expect_scene("aftermath")

	_press_choice(0)
	await _wait(SCENE_WAIT)
	_expect_scene("letter")

	_press_choice(1)
	await _wait(SCENE_WAIT)
	_expect_scene("scroll")

	_press_last()
	await _wait(SCENE_WAIT)
	_expect_scene("epilogue")

	_press_choice(0)
	await _wait(SCENE_WAIT)
	_check(_main.engine == null, "play again returns to the title screen")

	print("%d checks, %d failed" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)


func _wait(seconds: float) -> void:
	await create_timer(seconds).timeout


func _check(ok: bool, what: String) -> void:
	_checks += 1
	if not ok:
		_failures += 1
		printerr("FAIL: " + what)


func _expect_scene(id: String) -> void:
	var at: String = _main.engine.scene_id if _main.engine != null else "<title>"
	_check(at == id, "expected scene %s, got %s" % [id, at])


func _buttons(variation: String = "") -> Array:
	var out := []
	for child in _main._content.get_children():
		if child is Button and (variation == "" or child.theme_type_variation == variation):
			out.append(child)
	return out


func _press_choice(index: int) -> void:
	var choices := _buttons("ChoiceButton")
	_check(index < choices.size(), "choice %d exists" % index)
	if index < choices.size():
		choices[index].pressed.emit()


func _press_last() -> void:
	var all := _buttons()
	_check(not all.is_empty(), "a button exists")
	if not all.is_empty():
		all[-1].pressed.emit()


func _find_ring() -> Node:
	for child in _main._content.get_children():
		if child.get_script() == DuelRing:
			return child
	return null
