# Design notes

## Reputation balance in Chapter 1

`tools/validate_data.py` walks all 81 choice paths (3 choices at each of 4
story beats; the duel does not change stats). With the prototype's numbers:

| Reputation | Paths |
|---|---|
| The Cold Blade | 52 |
| The Upright Blade | 26 |
| The Faithful Blade | 3 |

Bond can only reach 2 ("pour wine" and "spare Gu Tie"), and both of those
choices also give +1 honor, which wins ties. Faithful needs pour, offer
silver, spare, read the letter (or close variants). Options, not yet decided:

- add bond to more choices (for example "deliver it unread")
- remove the honor bonus from "pour him a cup"
- change the tie-break order

## Duel difficulty

The rule line under the ring states the cycle, and Gu Tie's moves do not
affect the result, so a player who reads it always gets 2 links. Decide whether
the duel is a short action beat (fine as is) or a skill test (needs an opponent
read, a timer, or a hidden cycle per opponent).

## Tone: Untamed-style xianxia (decided)

The owner chose The Untamed (陈情令) as the style reference. Chapter 1 was
rewritten to match: Yan Ruo is an outer disciple of the Tingyu Pavilion, the
letter is a sealed jade slip, Gu Tie's Black Willow cultivators walk the
crooked path with resentful energy, and the old man at Pine Ferry is hinted
to be something other than a man. Stats, choices, effects and flags are
unchanged from the prototype.

Use the style only. Do not reuse names, sects or plot from The Untamed or the
novel it adapts (Mo Dao Zu Shi); both are copyrighted. All names in this game
(Tingyu Pavilion, Iron Crane Sect, Black Willow, Pine Ferry) are original or
from the prototype.

Ideas for later chapters: the old man's true nature, music cultivation
(guqin, dizi) as a duel style, sword flying for travel scenes, a sworn-brother
bond that carries across the chain.
