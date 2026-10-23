extends SceneTree
## Unit tests for /game/core. No plugin needed.
## Run: godot --headless --path . -s res://tests/test_core.gd
## Exits 0 when every check passes, 1 otherwise.

const GameState := preload("res://game/core/game_state.gd")
const DuelRules := preload("res://game/core/duel_rules.gd")
const Inheritance := preload("res://game/core/inheritance.gd")
const StoryEngine := preload("res://game/core/story_engine.gd")
const Strings := preload("res://game/core/strings.gd")
const DataLoader := preload("res://game/core/data_loader.gd")

var _checks := 0
var _failures := 0


func _init() -> void:
	_test_duel()
	_test_reputation()
	_test_state()
	_test_strings()
	_test_chapter_graph()
	_test_upright_playthrough()
	_test_faithful_playthrough()
	_test_broken_duel_playthrough()
	print("%d checks, %d failed" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)


func _check(ok: bool, what: String) -> void:
	_checks += 1
	if not ok:
		_failures += 1
		printerr("FAIL: " + what)


func _eq(actual: Variant, expected: Variant, what: String) -> void:
	_check(actual == expected, "%s: expected %s, got %s" % [what, expected, actual])


func _test_duel() -> void:
	var r := DuelRules.evaluate(["willow", "crane", "step"])
	_eq(r["links"], 2, "full chain links")
	_eq(r["technique"], "crane_takes_flight", "technique is the last link")
	_eq(r["wound"], false, "full chain leaves no wound")

	r = DuelRules.evaluate(["water", "willow", "crane"])
	_eq(r["links"], 2, "chain wraps from water to willow")
	_eq(r["technique"], "willow_breaks_stone", "wrapped chain technique")

	r = DuelRules.evaluate(["willow", "crane", "willow"])
	_eq(r["links"], 1, "one link")
	_eq(r["technique"], "willow_breaks_stone", "one link technique")
	_eq(r["wound"], true, "one link wounds")

	r = DuelRules.evaluate(["step", "water", "water"])
	_eq(r["links"], 1, "link then repeat")
	_eq(r["technique"], "mist_behind_the_blade", "link then repeat technique")

	r = DuelRules.evaluate(["crane", "willow", "water"])
	_eq(r["links"], 0, "counter-clockwise makes no links")
	_eq(r["technique"], "stumbling_form", "no links gives the fallback technique")
	_eq(r["wound"], true, "no links wounds")

	_eq(DuelRules.evaluate(["step", "step", "step"])["links"], 0, "repeats are not links")
	_eq(DuelRules.link_between("water", "willow"), "ripple_returns", "water to willow")
	_eq(DuelRules.link_between("willow", "water"), "", "willow to water is backwards")


func _test_reputation() -> void:
	_eq(Inheritance.reputation({"honor": 0, "ruth": 0, "bond": 0}), "upright", "all zero")
	_eq(Inheritance.reputation({"honor": 2, "ruth": 2, "bond": 0}), "upright", "honor wins tie with ruth")
	_eq(Inheritance.reputation({"honor": 1, "ruth": 0, "bond": 1}), "upright", "honor wins tie with bond")
	_eq(Inheritance.reputation({"honor": 0, "ruth": 2, "bond": 2}), "cold", "ruth wins tie with bond")
	_eq(Inheritance.reputation({"honor": 0, "ruth": 1, "bond": 2}), "faithful", "bond highest")
	_eq(Inheritance.reputation({"honor": -1, "ruth": -2, "bond": -3}), "upright", "negative stats")


func _test_state() -> void:
	var s := GameState.new()
	s.apply_effects({"honor": 1, "bond": 2.0})
	s.apply_effects({"honor": -3})
	_eq(s.stats["honor"], -2, "stats go negative")
	_eq(s.stats["bond"], 2, "float effects from JSON become ints")
	s.set_flags({"gu": "spared"})
	s.links = 1
	_eq(s.lookup("gu"), "spared", "lookup flag")
	_eq(s.lookup("bond"), 2, "lookup stat")
	_eq(s.lookup("links"), 1, "lookup links")
	_eq(s.lookup("nothing"), null, "lookup missing")

	var copy := GameState.new()
	copy.load_dict(JSON.parse_string(JSON.stringify(s.to_dict())))
	_eq(copy.stats, s.stats, "stats survive a JSON round trip")
	_eq(copy.flags, s.flags, "flags survive a JSON round trip")
	_eq(copy.links, 1, "links survive a JSON round trip")


func _test_strings() -> void:
	var strings := Strings.new({"a": "Move {n} of 3"}, {"a": "x", "b": "fallback"})
	_eq(strings.text("a", {"n": 2}), "Move 2 of 3", "placeholder")
	_eq(strings.text("b"), "fallback", "falls back to English")
	_eq(strings.text("missing"), "missing", "missing key shows the key")


func _chapter() -> Dictionary:
	return DataLoader.load_json("res://data/chapters/ch1.json")


func _engine() -> StoryEngine:
	return StoryEngine.new(_chapter(), GameState.new())


func _test_chapter_graph() -> void:
	var chapter := _chapter()
	var scenes: Dictionary = chapter["scenes"]
	_check(scenes.has(chapter["start"]), "start scene exists")
	for id in scenes:
		var scene: Dictionary = scenes[id]
		if scene.has("next"):
			_check(scenes.has(scene["next"]), "%s.next exists" % id)
		for choice in scene.get("choices", []):
			if not choice.has("action"):
				_check(scenes.has(choice["next"]), "%s choice next exists" % id)


func _pick(engine: StoryEngine, text_key: String) -> void:
	var choices := engine.choices()
	for i in choices.size():
		if choices[i]["text"] == text_key:
			engine.choose(i)
			return
	_check(false, "choice %s in scene %s" % [text_key, engine.scene_id])


func _test_upright_playthrough() -> void:
	var e := _engine()
	_eq(e.scene_id, "ferry", "starts at the inn")
	_eq(e.state.character, "yan_ruo", "plays Yan Ruo")
	_pick(e, "ch1.ferry.c_pour")
	_eq(int(e.last_delta["honor"]), 1, "honor delta from pouring wine")
	_eq(int(e.last_delta["bond"]), 1, "bond delta from pouring wine")
	_eq(e.paragraphs()[0], "ch1.bandits.beggar_friend", "old man remembers the wine")
	_pick(e, "ch1.bandits.c_sword")
	_eq(e.scene_type(), "duel", "duel follows the bandits")
	_eq(e.resolve(e.scene()["intro"]), "ch1.duel.intro_sword", "intro follows approach")
	e.resolve_duel(["willow", "crane", "step"])
	e.advance()
	_eq(e.paragraphs()[0], "ch1.after.links_2", "aftermath follows link count")
	_pick(e, "ch1.after.c_spare")
	_pick(e, "ch1.letter.c_deliver")
	_eq(e.scene_type(), "scroll", "scroll after the letter")
	_eq(e.state.stats, {"honor": 4, "ruth": 0, "bond": 2}, "final stats")
	_eq(e.resolve(e.scene()["title"]), "reputation.upright", "upright reputation")
	var fields: Array = e.scene()["fields"]
	_eq(e.resolve(fields[0]["value"]), "technique.crane_takes_flight", "scroll technique")
	_eq(e.resolve(fields[1]["value"]), "scroll.mark.clean", "scroll mark")
	_eq(e.resolve(fields[2]["value"]), "ch1.debt.spared", "scroll debt")
	e.advance()
	_eq(e.state.character, "shen_mo", "epilogue passes to Shen Mo")
	_eq(e.text_params()["technique_short"], "technique.crane_takes_flight.short", "technique param")


func _test_faithful_playthrough() -> void:
	var e := _engine()
	_pick(e, "ch1.ferry.c_pour")
	_pick(e, "ch1.bandits.c_silver")
	e.resolve_duel(["water", "willow", "crane"])
	e.advance()
	_pick(e, "ch1.after.c_spare")
	_pick(e, "ch1.letter.c_read")
	_eq(e.resolve("$reputation"), "reputation.faithful", "faithful reputation is reachable")


func _test_broken_duel_playthrough() -> void:
	var e := _engine()
	_pick(e, "ch1.ferry.c_question")
	_pick(e, "ch1.bandits.c_decoy")
	e.resolve_duel(["crane", "willow", "water"])
	e.advance()
	_eq(e.paragraphs()[0], "ch1.after.links_0", "broken chain aftermath")
	_pick(e, "ch1.after.c_kill")
	_pick(e, "ch1.letter.c_burn")
	_eq(e.resolve("$reputation"), "reputation.cold", "cold reputation")
	var fields: Array = e.scene()["fields"]
	_eq(e.resolve(fields[0]["value"]), "technique.stumbling_form", "fallback technique on the scroll")
	_eq(e.resolve(fields[1]["value"]), "scroll.mark.wound", "wound on the scroll")
