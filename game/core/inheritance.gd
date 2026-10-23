extends RefCounted
## Rules for the inheritance scroll a character leaves to the next one.


## Reputation id from the highest stat: "upright" (honor), "cold" (ruth) or
## "faithful" (bond). Ties break honor > ruth > bond, as in the prototype.
static func reputation(stats: Dictionary) -> String:
	var honor := int(stats.get("honor", 0))
	var ruth := int(stats.get("ruth", 0))
	var bond := int(stats.get("bond", 0))
	if honor >= ruth and honor >= bond:
		return "upright"
	if ruth >= bond:
		return "cold"
	return "faithful"
