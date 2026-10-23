# Jianghu Chain (江湖鏈)

A mobile-first wuxia story game for Android, built with Godot 4. You play a
chain of characters across one saga. Each character's final choices (grudges,
debts, secrets, a technique) become the inheritance the next character
receives.

**Status:** Chapter 1 is playable from start to finish with placeholder art:
the inn at Pine Ferry, the chain duel, the inheritance scroll and a short
Chapter 2 hook. See `CLAUDE.md` for the full spec and milestones.

## Run it

1. Install [Godot 4.3 or newer](https://godotengine.org/download) (standard
   build, not .NET).
2. Open Godot, choose **Import**, and select `project.godot` in this folder.
3. Press **F5** (Run Project). The window opens in portrait.

Chinese characters (the title, stat glyphs, move names) use your system's
fonts. On Linux without a CJK font installed they show as boxes; install
`fonts-noto-cjk` or similar. Bundling a font is an open decision (see
`CLAUDE.md`).

## Test it

Core logic tests (no plugin needed):

```sh
godot --headless --path . -s res://tests/test_core.gd
```

It prints `N checks, 0 failed` and exits 0 when everything passes.

Story data checks (Python 3, no Godot needed). They walk every Chapter 1
playthrough and report which reputation each path earns:

```sh
python3 tools/validate_data.py
```

A scripted playthrough clicks through all of Chapter 1 in the real UI:

```sh
godot --headless --path . -s res://tests/test_playthrough.gd
```

CI runs all of the above on every pull request.

## Release

The game is installed through the private app store, from this repo's GitHub
releases. Run **Actions → Release → Run workflow** on `main`. One-time signing
key setup and the store's rules are in [`docs/BUILD.md`](docs/BUILD.md).

## Layout

```
prototype/   the original HTML prototype (reference only, do not edit)
data/        chapters, characters and text (en.json, zh.json)
game/core/   rules and state with no scene nodes: unit tested
game/scenes/ main scene
game/ui/     theme and duel ring
game/fx/     placeholder scene art drawn in code
tests/       core unit tests
tools/       data validator
scripts/     release version script
docs/        build and release, design notes, asset licenses
```

Adding a chapter means adding a JSON file under `data/chapters/` and its text
to `data/i18n/en.json`. The format is described at the top of
`game/core/story_engine.gd`.
