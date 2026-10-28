# Desktop pets

Each provider has an independent paw button in its card, compact row, and the provider manager. All pets start off. Open pets and their positions persist across launches; hiding a provider card or the quota panel does not hide its pet. Drag the character to move it; click to wave hello and toggle its quota bubble. Right-click to select an action or hide it. Click the name badge below a pet (or choose Rename in its context menu) to give it an independent name. Names support Unicode, are limited to 32 characters, and persist across launches; blank input or Reset name restores the provider name. Renaming only changes the pet badge, not the provider identity or quota source. Ordinary pet interaction does not take keyboard focus; the explicit rename dialog temporarily accepts keyboard input.

Left-click a pet to show a speech bubble with its current activity, actual remaining quota, reset times, balances, refresh timestamp, and paused-refresh status. Click again or elsewhere to dismiss it; clicking a different pet switches to that pet's bubble. Hovering only reveals the close button, and dragging does not open a bubble. It uses the same quota-window preference as the main panel and explains when data is unavailable. The bubble stays within the visible screen, appears below pets near the top edge, and never takes keyboard focus.

The Antigravity provider uses the Gemini character. Codex uses the gallery's main GPT dragon character. These are display choices, not additional quota providers.

## Artwork and animation

- DeepSeek: the user's installed `PC2005-cloud/dsh-pet` **0.3.8** artwork, imported from 14 transparent WebM clips as 10 fps PNG atlases. Includes idle, thinking, working, waiting, attention, sleeping, waving, stretching, eating, dancing, playing with a cube, magic, looking around, and jumping. The original blue-haired whale-maid appearance is preserved.
- Codex, Claude, Kimi, Grok, Gemini now use continuous idle, greeting, working (reading), thinking, stretching, snack, dancing, and sleeping clips at 24 fps, imported from thirty-five Doubao / Seedance 2.0 Mini videos made entirely with daily free quota. Greeting, thinking, stretching, snack, dancing, and sleeping clips each have 235 frames, working clips have 223–235 frames, and idle clips have 34–52 frames. A fixed crop and scale preserve the anchor; chromakey removes the background and a six-frame blend closes each neutral-pose loop. Kimi uses magenta keying to preserve its green accessory. Automatic leisure playback rotates through the continuous greeting, stretching, thinking, snack, dancing, and sleeping clips.
- All eight core pet actions (idle, greeting, working, thinking, stretching, snack, dancing, sleeping) for all five providers are now 100% continuous video-based animations (waiting reuses greeting, attention reuses thinking). None of the core 8 actions rely on legacy 4-frame static sprite sheets anymore. Characters are based on the [character gallery](https://genderswapai.com/zh-CN/ai-gijinka/gallery), with compact chibi proportions; Codex uses the main GPT dragon character.
- Generated artwork uses the built-in `image_gen` tool. Exact prompts and reference URLs are in [`artwork.json`](../Sources/QuotaBar/Resources/Pets/artwork.json). All selected assets live in `Sources/QuotaBar/Resources/Pets/`.

DeepSeek animation source: [PC2005-cloud/dsh-pet](https://github.com/PC2005-cloud/dsh-pet). Its included license is preserved as `DSH-PET-LICENSE.txt`. The gallery credits the model character illustrations to **ZipZipPipe**, and the original DeepSeek character to **上善无形** (the gallery marks DeepSeek derivatives CC BY-NC-SA 4.0). These third-party character assets are distinct from Quota Bar's own MIT-licensed code; retain the source credits with distributions.

Reimport DeepSeek assets from an installed package with FFmpeg available:

```sh
zsh scripts/import-deepseek-pet.sh /path/to/node_modules/dsh-pet
```

Rebuild a reviewed continuous-motion import with `python3 scripts/build-pet-motion.py claude` (or another provider listed in [`pet-motion-imports.json`](pet-motion-imports.json)). The importer checks the source SHA256 before applying its reviewed crop and timing, validates that every frame contains visible pixels, and derives shared geometry from the neutral idle frame. Additional action imports specify a `provider` and a reviewed `calibrationFrame` from the new source, so measuring an action such as stretching cannot accidentally shrink the character. Waiting and attention reuse the corresponding continuous greeting and thinking clips until dedicated clips are provided, matching the original sheet aliases. `build-claude-motion.py /path/to/claude-wave-source.mp4` remains a compatibility entrypoint. Atlas JSON records the source conversation, hash, crop, frame ranges, and seam treatment. Original MP4s are retained locally under `dist/pet-motion/`; the imported atlases work offline.

## Runtime

`DesktopPetController` owns one nonactivating transparent `NSPanel` per provider and observes `AppPreferences.desktopPets`. Each view observes existing provider snapshots. Pets make no model calls, start no extra polling, and do not depend on DSH being running or installed after build. Only the active animation atlas is retained per pet. Reduced Motion freezes animation. Disconnecting a monitor brings its pets onto a remaining screen.

Idle and disconnected pets alternate their idle animation with leisure actions after roughly 6–10 seconds of rest. Continuous clips finish whole idle loops and play one complete leisure clip before returning to idle. When continuous leisure clips are available, automatic playback selects those clips. Working, thinking, and approval states select corresponding animations. A click or context-menu selection temporarily plays the requested action before returning to the current activity. Offline status is explained in the bubble while the companion stays animated.

The SwiftPM `QuotaBar_QuotaBar.bundle` is copied into the app's resources by `scripts/build-app.sh`.

Every provider uses a 150-point visible neutral-pose height and a shared foot baseline. The scale comes from measured alpha bounds, not the padded image's height, and remains fixed across a character's actions. Atlas metadata records `referenceHeight`, `bottomInset`, and optional `horizontalOffset`; older pose sheets use their measured neutral-frame calibration. The transparent viewport leaves room for waving and DeepSeek's existing effects.

The completed idle/greeting video batch is recorded in [`pet-motion-jobs.json`](pet-motion-jobs.json). The 30-item working, thinking, stretching, snack, dancing, and sleeping batch, including its per-item generation, review, installation, and quota status, is tracked separately in [`pet-extra-motion-jobs.json`](pet-extra-motion-jobs.json). The reusable browser workflow is the personal `doubao-video` skill. A prepared reference is not a submitted task, and a downloaded clip is not yet an integrated animation; the batch records those stages separately.

## Validation

```sh
swift test --skip 'live'
QUOTABAR_PET_PREVIEW_DIR="$PWD/dist/pet-preview" QUOTABAR_PET_PREVIEW_ACTIVITY=thinking swift test --filter desktopPetWindows
./scripts/build-app.sh
"dist/Quota Bar.app/Contents/MacOS/QuotaBar" --verify-pet-resources
```

The window test uses isolated preferences and mock snapshots without starting collectors. It verifies independent windows, closing, and focus preservation. The optional environment variable exports UI captures for visual inspection.
