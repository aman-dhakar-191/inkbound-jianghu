extends RefCounted
## Player-facing text by key. Falls back to the English table, then to the key
## itself so a missing string is visible instead of blank.

var table: Dictionary
var fallback: Dictionary


func _init(strings_table: Dictionary, fallback_table: Dictionary = {}) -> void:
	table = strings_table
	fallback = fallback_table


func has(key: String) -> bool:
	return table.has(key) or fallback.has(key)


## Replaces {name} placeholders with values from params.
func text(key: String, params: Dictionary = {}) -> String:
	var s := str(table.get(key, fallback.get(key, key)))
	for param in params:
		s = s.replace("{%s}" % param, str(params[param]))
	return s
