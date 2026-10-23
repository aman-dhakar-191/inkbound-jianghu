# CLAUDE.md: Inkbound Jianghu

Read this file first in every session. Keep it updated when decisions change.

## 1. What we are building
A mobile-first (Android) xianxia story game. The player plays a **chain of characters** across one saga. Each character's final choices become the **inheritance** (grudges, debts, secrets, techniques) that the next character receives.

**Tone (decided):** in the style of the drama The Untamed: cultivation sects, spiritual power and golden cores, the righteous path against the crooked path, resentful energy and spirits, misty mountains, pale sect robes, grudge and gratitude (恩怨), oaths and sworn bonds. Style only: never reuse names, sects, characters or plot from The Untamed or Mo Dao Zu Shi.

Working title: **Jianghu Chain** (江湖鏈). Repo: `inkbound-jianghu`.

Start small. Ship Chapter 1 (about 5 minutes of play), then expand chapter by chapter.

## 2. Tech decisions
- **Engine:** Godot 4.x (latest stable), GDScript. Chosen for Android export, 2D skeletal animation, shaders and long-term expansion.
- **Target:** Android, portrait, phone first. Also runs on desktop for testing.
- **Distribution:** the owner's private app store (`aman-dhakar-191/private-app-store`), not Google Play. Each version is a GitHub release with one signed APK, made by the `Release` workflow. Rules and setup: `/docs/BUILD.md`. Package name `io.github.amandhakar.jianghuchain` must never change.
- **Render:** 2D only. Mobile renderer.
- **Do not** add heavy plugins or C# without asking. Keep the project dependency-light.
- **Open decisions** (ask the owner, do not assume): final character art style, video format, monetization, project license, whether to bundle fonts, recorded voice acting (who records or which voice service, and its license) versus the phone's text-to-speech.

## 3. Reference prototype
A working HTML/canvas prototype lives in `/prototype/jianghu-chain-v2.html`. It is the design reference for story, choices, stats, the duel mechanic and the scroll mechanic. Port the **logic and content**, not the code. Do not edit the prototype.

## 4. Architecture rules
1. **Data-driven.** Story, scenes, choices and characters live in JSON under `/data`. The engine only plays them. Adding a chapter must not need code changes.
2. **Separate logic from visuals.** `/game/core` (state, chain/inheritance, duel rules) must have no scene-node dependencies, so it can be unit tested.
3. **Scenes are composed of layers.** Each scene JSON lists a background, parallax layers, characters and effects. (For now a scene names one `backdrop` preset drawn in code by `/game/fx/backdrop.gd`; split it into layers when real art arrives.)
4. **All player-facing text goes through localization** (`/data/i18n/en.json`, `zh.json`). Never hardcode strings in scripts.
5. **Save/load** serializes the game state to JSON in `user://`.
6. **Voice and subtitles.** Story scenes play line by line: each line is voiced and shown as a subtitle; choices appear after the last line. Text entries may name a `speaker` (an id in `/data/voices.json`, which sets the speaker's display name, pitch and rate). `/game/audio/voice.gd` plays a recorded clip at `/assets/audio/voice/<lang>/<i18n key>.ogg` when one exists, otherwise the phone's text-to-speech, otherwise nothing (lines then advance on a reading timer). Recorded voice is an open decision; adding clips needs no code changes. Never call `DisplayServer.tts_get_voices*()`: it crashed the app on Android (v0.1.1). Text-to-speech always uses the phone's default voice, and a crash guard turns voice off after a crash during speech.

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
  /audio            voice player (recorded clips or text-to-speech)
/assets
  /art  /video  /audio  /fonts
/docs               design notes, story bible
/tests              unit tests for core logic
/tools              data validator (Python, runs without Godot)
/scripts            release version script (shared with the app store repo)
/.github            CI (tests, test APK) and Release (signed APK) workflows
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

**Chapter 1 outline** (Yan Ruo, outer disciple of the Tingyu Pavilion, carrying a sealed jade slip to the Iron Crane Sect): inn at Pine Ferry -> an old man whose shadow falls the wrong way (pour wine / ignore / ask what he is) -> Black Willow cultivators of the crooked path, leader Gu Tie (draw sword / offer spirit stones / forged slip) -> chain duel -> aftermath (spare / kill / take his ghost-binding token) -> the cracked jade slip (read / deliver / burn with a talisman) -> scroll written -> Chapter 2 preview with Shen Mo, a ferryman's apprentice with no spiritual roots, who inherits the scroll. Flag ids keep their prototype names (`letter`, `beggar`, `approach: silver`) so saves and tests stay stable.

## 7. Art and animation direction
- **Current phase:** placeholders only (simple silhouettes and shapes). Do not spend time on final art.
- **Target look (to be confirmed):** painted, ink-wash-influenced, semi-realistic characters in layered 2D scenes with parallax.
- **Animation approach:** skeletal / cut-out animation (Godot Skeleton2D and AnimationPlayer, or a Spine-style runtime if the owner approves), idle loops, tween-driven moves, particle and shader effects for rain, mist, slashes and sparks.
- Realistic characters with fluid animation are the most expensive part of this project. Flag any scope risk early. Prefer reusing parts and layers over frame-by-frame animation.
- **Video:** only for short cinematic moments. Verify which video formats the chosen Godot version plays natively before adding any clip (Godot has historically supported Ogg Theora only). Keep clips short and compressed.
- Respect reduced-motion and sound-off settings. The voice on/off toggle in the top bar is saved in `user://settings.cfg`.

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
  - `godot --headless --path . -s res://tests/test_playthrough.gd` after UI changes (clicks through Chapter 1)
  - CI runs all of these on every pull request and fails on any Godot script error.
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
7. **M6:** First Android export, tested on a real device, released through the private app store. Build steps are in `/docs/BUILD.md`.
8. **M7:** Decide final art style, then replace placeholders.

## 11. Out of scope for now
Monetization, multiplayer, accounts, analytics, ads, cloud saves, iOS.
