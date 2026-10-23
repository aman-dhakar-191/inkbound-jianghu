# CLAUDE.md: Inkbound Jianghu

Read this file first in every session. Keep it updated when decisions change.

## 1. What we are building
A mobile-first (Android) wuxia story game. The player plays a **chain of characters** across one saga. Each character's final choices become the **inheritance** (grudges, debts, secrets, techniques) that the next character receives. Chinese wuxia theme: grudge and gratitude (恩怨), oaths, sects, martial arts.

Working title: **Jianghu Chain** (江湖鏈). Repo: `inkbound-jianghu`.

Start small. Ship Chapter 1 (about 5 minutes of play), then expand chapter by chapter.

## 2. Tech decisions
- **Engine:** Godot 4.x (latest stable), GDScript. Chosen for Android export, 2D skeletal animation, shaders and long-term expansion.
- **Target:** Android, portrait, phone first. Also runs on desktop for testing.
- **Render:** 2D only. Mobile renderer.
- **Do not** add heavy plugins or C# without asking. Keep the project dependency-light.
- **Open decisions** (ask the owner, do not assume): final character art style, video format, monetization, Play Store release plan, project license, whether to bundle fonts, and tone (grounded wuxia vs. The Untamed-style xianxia, see `/docs/DESIGN_NOTES.md`).

## 3. Reference prototype
A working HTML/canvas prototype lives in `/prototype/jianghu-chain-v2.html`. It is the design reference for story, choices, stats, the duel mechanic and the scroll mechanic. Port the **logic and content**, not the code. Do not edit the prototype.

## 4. Architecture rules
1. **Data-driven.** Story, scenes, choices and characters live in JSON under `/data`. The engine only plays them. Adding a chapter must not need code changes.
2. **Separate logic from visuals.** `/game/core` (state, chain/inheritance, duel rules) must have no scene-node dependencies, so it can be unit tested.
3. **Scenes are composed of layers.** Each scene JSON lists a background, parallax layers, characters and effects. (For now a scene names one `backdrop` preset drawn in code by `/game/fx/backdrop.gd`; split it into layers when real art arrives.)
4. **All player-facing text goes through localization** (`/data/i18n/en.json`, `zh.json`). Never hardcode strings in scripts.
5. **Save/load** serializes the game state to JSON in `user://`.

## 5. Folder layout
```
/prototype          reference HTML prototype (read-only)
/data
  /chapters         chapter JSON (scenes, choices, effects)
  /characters       character definitions and stats
  /i18n             en.json, zh.json
/game
  /core             state, inheritance chain, duel rules (pure logic)
  /scenes           Godot scenes (.tscn)
  /ui               story panel, choice buttons, stat bar, scroll view
  /fx               rain, mist, slash arcs, sparks, ink-wipe transition
  /audio            sound manager
/assets
  /art  /video  /audio  /fonts
/docs               design notes, story bible
/tests              unit tests for core logic
/tools              data validator (Python, runs without Godot)
```

Chapter JSON format: see the header comment in `/game/core/story_engine.gd`. Text entries are i18n keys, `$reputation` / `$technique`, or `{"by": fact, "cases": {...}}` lookups.

## 6. Core systems (spec)
**State**
- Stats: `honor`, `ruth` (ruthlessness), `bond`. Integers, can go negative.
- `flags`: dictionary of story facts (e.g. `gu: spared | killed | token`, `letter: read | sealed | burned`, `beggar: friend | cold | tested`, `approach`, `wound`).
- `technique`: string name earned in the duel.

**Inheritance scroll** (written at the end of each character's chapter, read by the next):
reputation title, technique, mark/scar, debt or grudge, secret, witness. Reputation = highest stat: honor -> "The Upright Blade", ruth -> "The Cold Blade", bond -> "The Faithful Blade".

**Chain duel** (mini-game)
- Four moves in a clockwise cycle: Willow 柔 -> Crane 剛 -> Step 步 -> Water 靜 -> back to Willow.
- Player picks 3 moves. A pair is a **link** if it follows the cycle.
- Link names: Willow Breaks Stone, Crane Takes Flight, Mist Behind the Blade, Ripple Returns.
- Result: 2 links = clean win, no wound. 1 link = win with a scar. 0 links = win, scar, technique "Stumbling Form (unfinished)". The player never fails out of the story; consequences carry forward instead.
- Technique earned = name of the last link achieved.
- Link pairs: Willow->Crane = Willow Breaks Stone, Crane->Step = Crane Takes Flight, Step->Water = Mist Behind the Blade, Water->Willow = Ripple Returns. Repeating a move is allowed and is never a link.
- The duel sets `links` (0-2), `technique` and the boolean flag `wound` (true when links < 2). "Scar" is only the scroll's wording for `wound`.

**Reputation ties** break honor > ruth > bond. All zeros gives "The Upright Blade".

**Chapter 1 outline** (Yan Ruo, swordswoman): inn at Pine Ferry -> old man (pour wine / ignore / question) -> bandits burst in, leader Gu Tie (draw sword / offer silver / forged letter) -> chain duel -> aftermath (spare / kill / take jade token) -> the sealed letter (read / deliver / burn) -> scroll written -> Chapter 2 preview with Shen Mo, a ferryman's apprentice, who inherits the scroll.

## 7. Art and animation direction
- **Current phase:** placeholders only (simple silhouettes and shapes). Do not spend time on final art.
- **Target look (to be confirmed):** painted, ink-wash-influenced, semi-realistic characters in layered 2D scenes with parallax.
- **Animation approach:** skeletal / cut-out animation (Godot Skeleton2D and AnimationPlayer, or a Spine-style runtime if the owner approves), idle loops, tween-driven moves, particle and shader effects for rain, mist, slashes and sparks.
- Realistic characters with fluid animation are the most expensive part of this project. Flag any scope risk early. Prefer reusing parts and layers over frame-by-frame animation.
- **Video:** only for short cinematic moments. Verify which video formats the chosen Godot version plays natively before adding any clip (Godot has historically supported Ogg Theora only). Keep clips short and compressed.
- Respect reduced-motion and sound-off settings.

## 8. UI rules
- Portrait, one-handed play. Touch targets at least 48dp. Respect safe areas and notches.
- Scene art in the top ~40% of the screen, text and choices below. Duel scenes keep the move ring and the fighters visible together.
- Fonts: Noto Serif SC for body, Ma Shan Zheng for display (verify the license before bundling).

## 9. Workflow rules for Claude Code
- Work in small steps. One feature per commit. Clear commit messages.
- Before coding a feature, state the plan in 3-5 lines. After coding, say how to test it.
- Run tests for `/game/core` after changing logic. Add a test for every new rule.
  - `godot --headless --path . -s res://tests/test_core.gd` (plain SceneTree script, no test plugin)
  - `python3 tools/validate_data.py` after changing anything in `/data`
- Never commit secrets, keystores or signing keys. Keep `.gitignore` current.
- Large binary assets (video, audio, big images) use **Git LFS**.
- The repo is **public**. Only commit assets we have the rights to. Record every asset's source and license in `/docs/ASSETS.md`.
- You cannot see the running game. After UI or animation changes, tell the owner exactly what to check on a device or emulator.
- Do not guess at current Godot or Google Play rules. Check the official docs.
- Ask before changing the architecture or adding dependencies.

## 10. Milestones
1. **M0:** Godot project, folder layout, `.gitignore`, Git LFS, README, license, empty main scene runs on desktop.
2. **M1:** Core state and inheritance logic with unit tests. Load Chapter 1 from JSON. Text-only playable version.
3. **M2:** Story UI (text panel, choice buttons, stat bar), scene transitions, localization (en first).
4. **M3:** Placeholder animated scenes (parallax, rain, mist, lantern), ink-wipe transition, sound manager.
5. **M4:** Chain duel mini-game with placeholder fighters, slash and spark effects.
6. **M5:** Inheritance scroll screen and Chapter 2 hook. Save/load.
7. **M6:** First Android export, tested on a real device. Document the build steps in `/docs/BUILD.md`.
8. **M7:** Decide final art style, then replace placeholders.

## 11. Out of scope for now
Monetization, multiplayer, accounts, analytics, ads, cloud saves, iOS.
