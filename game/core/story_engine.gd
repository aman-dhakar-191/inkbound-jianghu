extends RefCounted
## Plays one chapter's JSON against a GameState. Knows nothing about nodes or
## drawing: the UI asks it what to show and tells it what the player picked.
##
## A text entry in chapter JSON is one of:
##   "ch1.ferry.p1"                         an i18n key
##   "$reputation" / "$technique"           a key computed from the state
##   {"by": "beggar", "cases": {...}, "default": "..."}
##                                          a key picked by a flag, stat,
##                                          "links" or "technique"
##   {"key": "ch1.bandits.p3"}             a plain key in object form
## Either object form can carry "speaker": a voices.json id. Lines without
## one are spoken by the narrator.

const GameState := preload("res://game/core/game_state.gd")
const DuelRules := preload("res://game/core/duel_rules.gd")
const Inheritance := preload("res://game/core/inheritance.gd")

var chapter: Dictionary
var state: GameState
var scene_id := ""
## Stat changes from the last choice, shown at the top of the next scene.
var last_delta := {}


func _init(chapter_data: Dictionary, game_state: GameState) -> void:
	chapter = chapter_data
	state = game_state
	goto(str(chapter.get("start", "")))


func scene() -> Dictionary:
	var scenes: Dictionary = chapter.get("scenes", {})
	return scenes.get(scene_id, {})


func scene_type() -> String:
	return str(scene().get("type", "story"))


func resolve(entry: Variant) -> String:
	if entry == null:
		return ""
	if entry is Dictionary and entry.has("key"):
		return resolve(entry["key"])
	if entry is Dictionary:
		var cases: Dictionary = entry.get("cases", {})
		var value := _case_key(state.lookup(str(entry.get("by", ""))))
		return str(cases.get(value, entry.get("default", "")))
	var key := str(entry)
	match key:
		"$reputation":
			return "reputation." + Inheritance.reputation(state.stats)
		"$technique":
			return "technique." + state.technique
	return key


## The current scene's text as spoken lines: {"key": i18n key, "speaker": id}.
func lines() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for entry in scene().get("text", []):
		var key := resolve(entry)
		if key == "":
			continue
		var speaker := "narrator"
		if entry is Dictionary:
			speaker = str(entry.get("speaker", "narrator"))
		out.append({"key": key, "speaker": speaker})
	return out


## Just the keys of lines().
func paragraphs() -> Array[String]:
	var out: Array[String] = []
	for line in lines():
		out.append(line["key"])
	return out


func choices() -> Array:
	return scene().get("choices", [])


## Keys for {placeholders} in story text. The UI translates them.
func text_params() -> Dictionary:
	if state.technique == "":
		return {}
	return {
		"technique": "technique." + state.technique,
		"technique_short": "technique.%s.short" % state.technique,
	}


func choose(index: int) -> void:
	var choice: Dictionary = choices()[index]
	last_delta = choice.get("effects", {})
	state.apply_effects(last_delta)
	state.set_flags(choice.get("set", {}))
	goto(str(choice.get("next", "")))


func resolve_duel(sequence: Array) -> Dictionary:
	var result := DuelRules.evaluate(sequence)
	state.links = result["links"]
	state.technique = result["technique"]
	state.flags["wound"] = result["wound"]
	last_delta = {}
	return result


## Moves on from a scene that has no choices (duel, scroll).
func advance() -> void:
	goto(str(scene().get("next", "")))


func goto(id: String) -> void:
	scene_id = id
	state.character = str(scene().get("character", chapter.get("character", state.character)))


static func _case_key(value: Variant) -> String:
	if value is float and value == floorf(value):
		return str(int(value))
	return str(value)
