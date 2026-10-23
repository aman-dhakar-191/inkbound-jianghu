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

## Tone: wuxia or xianxia?

The owner mentioned The Untamed (陈情令) as a style reference. That drama is
xianxia: cultivation sects, spirits and resentful ghosts, music as a weapon
(guqin, dizi), swords that fly, sect robes and forehead ribbons. The current
spec and Chapter 1 are grounded wuxia: inns, bandits, sabres, letters.

The placeholder art leans toward that look (misty peaks, pale robes, the title
figure's forehead ribbon and long hair). The story text is unchanged from the
prototype. Open question for the owner: keep Chapter 1 grounded and grow
toward the supernatural later, or rewrite it as xianxia now. The inheritance
chain works for either.

Use the style only. Do not reuse names, sects or plot from The Untamed or the
novel it adapts (Mo Dao Zu Shi); both are copyrighted.
