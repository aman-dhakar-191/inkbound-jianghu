#!/usr/bin/env python3
"""Checks chapter and i18n data without Godot.

- every "next" points at a real scene, every scene is reachable
- every text key used by a chapter exists in en.json
- every zh.json key exists in en.json with the same {placeholders}
- every playthrough (all choices x all duel results) resolves each
  {"by": ...} lookup to a case, and reports the reputation spread

Run: python3 tools/validate_data.py
Exits non-zero on any error.
"""
import itertools
import json
import re
import sys
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DATA = ROOT / "data"
STATS = ("honor", "ruth", "bond")
# Keys the code builds at runtime instead of reading from chapter JSON.
CODE_KEYS = (
    ["title.main", "title.en", "title.sub", "ui.begin", "ui.continue", "ui.chapter", "ui.move_count",
     "duel.instruction", "duel.rule", "duel.form", "duel.no_form", "scroll.seal"]
    + [f"stat.{s}" for s in STATS] + [f"stat.{s}.glyph" for s in STATS]
    + [f"duel.move.{m}" for m in ("willow", "crane", "step", "water")]
    + [f"duel.move.{m}.glyph" for m in ("willow", "crane", "step", "water")]
    + [f"duel.result.{n}" for n in (0, 1, 2)]
    + [f"reputation.{r}" for r in ("upright", "cold", "faithful")]
)
TECHNIQUES = ("willow_breaks_stone", "crane_takes_flight", "mist_behind_the_blade",
              "ripple_returns", "stumbling_form")
# One sequence per possible duel outcome: 2, 1 and 0 links.
DUEL_OUTCOMES = {
    2: {"links": 2, "technique": "crane_takes_flight", "wound": False},
    1: {"links": 1, "technique": "willow_breaks_stone", "wound": True},
    0: {"links": 0, "technique": "stumbling_form", "wound": True},
}

errors = []


def err(msg):
    errors.append(msg)


def text_keys(node):
    """Every string leaf containing a dot is an i18n key."""
    if isinstance(node, dict):
        for k, v in node.items():
            if k in ("cases",):
                yield from text_keys(list(v.values()))
            else:
                yield from text_keys(v)
    elif isinstance(node, list):
        for v in node:
            yield from text_keys(v)
    elif isinstance(node, str) and "." in node and not node.startswith("$"):
        yield node


def placeholders(s):
    return set(re.findall(r"\{(\w+)\}", s))


def reputation(stats):
    h, r, b = stats["honor"], stats["ruth"], stats["bond"]
    if h >= r and h >= b:
        return "upright"
    if r >= b:
        return "cold"
    return "faithful"


def lookup(state, key):
    if key in state["flags"]:
        return state["flags"][key]
    if key in state["stats"]:
        return state["stats"][key]
    return state.get(key)


def case_key(v):
    if isinstance(v, bool):
        return "true" if v else "false"
    return str(v)


def resolve(entry, state, where):
    if isinstance(entry, dict):
        value = case_key(lookup(state, entry.get("by", "")))
        if value in entry.get("cases", {}):
            return entry["cases"][value]
        if "default" in entry:
            return entry["default"]
        err(f"{where}: no case for {entry.get('by')}={value}")
        return ""
    if entry == "$reputation":
        return "reputation." + reputation(state["stats"])
    if entry == "$technique":
        return "technique." + state["technique"]
    return entry


def entries_of(scene):
    out = list(scene.get("text", []))
    for k in ("intro", "title", "heading"):
        if k in scene:
            out.append(scene[k])
    out += [f["value"] for f in scene.get("fields", [])]
    return out


def play(chapter, en, picks, duel_links):
    """Walks one playthrough. picks are choice indexes for story scenes."""
    state = {"stats": dict.fromkeys(STATS, 0), "flags": {}, "technique": "", "links": 0}
    scenes = chapter["scenes"]
    sid, picks = chapter["start"], list(picks)
    for _ in range(100):
        scene = scenes[sid]
        for e in entries_of(scene):
            key = resolve(e, state, f"{chapter['id']}.{sid}")
            if key and key not in en:
                err(f"{chapter['id']}.{sid}: resolved key '{key}' missing from en.json")
        kind = scene.get("type", "story")
        if kind == "duel":
            outcome = DUEL_OUTCOMES[duel_links]
            state.update(links=outcome["links"], technique=outcome["technique"])
            state["flags"]["wound"] = outcome["wound"]
            sid = scene["next"]
        elif kind == "scroll":
            sid = scene["next"]
        else:
            choice = scene["choices"][picks.pop(0) if len(scene["choices"]) > 1 else 0]
            if choice.get("action") == "restart":
                return state
            for k, v in choice.get("effects", {}).items():
                state["stats"][k] += v
            state["flags"].update(choice.get("set", {}))
            sid = choice["next"]
    err(f"{chapter['id']}: playthrough did not end")
    return state


def check_chapter(path, en):
    chapter = json.loads(path.read_text(encoding="utf-8"))
    cid, scenes = chapter["id"], chapter["scenes"]
    if chapter["start"] not in scenes:
        err(f"{cid}: start '{chapter['start']}' is not a scene")
    reached, todo = set(), [chapter["start"]]
    for sid, scene in scenes.items():
        nexts = [c.get("next") for c in scene.get("choices", []) if "action" not in c]
        if "next" in scene:
            nexts.append(scene["next"])
        for n in nexts:
            if n not in scenes:
                err(f"{cid}.{sid}: next '{n}' is not a scene")
        for c in scene.get("choices", []):
            for stat in c.get("effects", {}):
                if stat not in STATS:
                    err(f"{cid}.{sid}: unknown stat '{stat}'")
    while todo:
        sid = todo.pop()
        if sid in reached or sid not in scenes:
            continue
        reached.add(sid)
        s = scenes[sid]
        todo += [c["next"] for c in s.get("choices", []) if "next" in c]
        if "next" in s:
            todo.append(s["next"])
    for sid in set(scenes) - reached:
        err(f"{cid}: scene '{sid}' is unreachable")
    for key in text_keys(chapter):
        if key not in en:
            err(f"{cid}: key '{key}' missing from en.json")

    choice_scenes = [s for s in scenes.values() if s.get("type", "story") == "story" and len(s.get("choices", [])) > 1]
    reps = Counter()
    paths = 0
    for picks in itertools.product(*[range(len(s["choices"])) for s in choice_scenes]):
        for links in DUEL_OUTCOMES:
            state = play(chapter, en, picks, links)
            if links == 2:
                reps[reputation(state["stats"])] += 1
                paths += 1
    print(f"{cid}: {len(scenes)} scenes, {paths} choice paths, reputation spread {dict(reps)}")


def main():
    en = json.loads((DATA / "i18n" / "en.json").read_text(encoding="utf-8"))
    for key in CODE_KEYS + [f"technique.{t}" for t in TECHNIQUES] + [f"technique.{t}.short" for t in TECHNIQUES]:
        if key not in en:
            err(f"en.json: missing '{key}' used by code")
    for lang in sorted((DATA / "i18n").glob("*.json")):
        if lang.name == "en.json":
            continue
        table = json.loads(lang.read_text(encoding="utf-8"))
        for key, value in table.items():
            if key not in en:
                err(f"{lang.name}: '{key}' not in en.json")
            elif placeholders(value) != placeholders(en[key]):
                err(f"{lang.name}: '{key}' placeholders differ from en.json")
    for path in sorted((DATA / "chapters").glob("*.json")):
        check_chapter(path, en)
    for path in sorted((DATA / "characters").glob("*.json")):
        char = json.loads(path.read_text(encoding="utf-8"))
        if char.get("name") not in en:
            err(f"{path.name}: name key '{char.get('name')}' missing from en.json")
    for e in errors:
        print("ERROR:", e)
    print("OK" if not errors else f"{len(errors)} error(s)")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
