extends RefCounted
## The chain duel. Four moves in a clockwise cycle:
## Willow -> Crane -> Step -> Water -> Willow.
## Two picks in a row form a link when the second follows the first on the cycle.

const MOVES: Array[String] = ["willow", "crane", "step", "water"]
const MOVES_PER_DUEL := 3
const FALLBACK_TECHNIQUE := "stumbling_form"
const LINKS := {
	"willow>crane": "willow_breaks_stone",
	"crane>step": "crane_takes_flight",
	"step>water": "mist_behind_the_blade",
	"water>willow": "ripple_returns",
}


## The technique id for the link a -> b, or "" when b does not follow a.
static func link_between(a: String, b: String) -> String:
	return str(LINKS.get(a + ">" + b, ""))


## Scores a finished sequence of move ids. The player never loses the story:
## fewer links only mean a wound and a weaker technique.
static func evaluate(sequence: Array) -> Dictionary:
	var links := 0
	var technique := ""
	for i in range(1, sequence.size()):
		var link := link_between(str(sequence[i - 1]), str(sequence[i]))
		if link != "":
			links += 1
			technique = link
	if technique == "":
		technique = FALLBACK_TECHNIQUE
	return {"links": links, "technique": technique, "wound": links < 2}
