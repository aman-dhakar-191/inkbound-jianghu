# Assets and licenses

Every third-party asset in this repo must be listed here with its source and
license before it is committed. The repo is public.

| File | Source | License | Notes |
|---|---|---|---|
| `icon.svg` | Made for this project | Same as the project | Placeholder |

No fonts, images, audio or video are bundled yet. Voices come from the phone's
text-to-speech at runtime. Recorded voice clips, when added, go in
`assets/audio/voice/<lang>/<i18n key>.ogg` (Git LFS) and must be listed here
with who recorded or generated them and under what license. All scene art is drawn in
code (`game/fx/backdrop.gd`).

Candidates still to check before bundling:

- Noto Serif SC (body text): believed to be SIL Open Font License. Large
  file; consider subsetting to the characters the game uses.
- Ma Shan Zheng (display): believed to be SIL Open Font License.
