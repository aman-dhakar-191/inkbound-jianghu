extends RefCounted
## Everything a playthrough has decided so far. Pure data: no nodes and no
## files, so it can be unit tested and saved as JSON.

const STATS: Array[String] = ["honor", "ruth", "bond"]

var stats := {"honor": 0, "ruth": 0, "bond": 0}
var flags := {}
var technique := ""
var links := 0
var character := ""


func apply_effects(effects: Dictionary) -> void:
	for key in effects:
		if stats.has(key):
			stats[key] += int(effects[key])
		else:
			push_warning("Unknown stat in effects: %s" % key)


func set_flags(values: Dictionary) -> void:
	for key in values:
		flags[key] = values[key]


## Reads a story fact by name: flags first, then stats, then duel results.
func lookup(key: String) -> Variant:
	if flags.has(key):
		return flags[key]
	if stats.has(key):
		return stats[key]
	match key:
		"links":
			return links
		"technique":
			return technique
	return null


func to_dict() -> Dictionary:
	return {
		"stats": stats.duplicate(),
		"flags": flags.duplicate(),
		"technique": technique,
		"links": links,
		"character": character,
	}


func load_dict(data: Dictionary) -> void:
	var saved_stats: Dictionary = data.get("stats", {})
	for key in STATS:
		stats[key] = int(saved_stats.get(key, 0))
	var saved_flags: Dictionary = data.get("flags", {})
	flags = saved_flags.duplicate()
	technique = str(data.get("technique", ""))
	links = int(data.get("links", 0))
	character = str(data.get("character", ""))
