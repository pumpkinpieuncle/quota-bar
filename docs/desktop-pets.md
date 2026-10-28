# Desktop pets

Each provider has an independent paw button in its card, compact row, and the provider manager. All pets start off. Open pets and their positions persist across launches; hiding a provider card or the quota panel does not hide its pet. Drag the character to move it; click to wave hello. Right-click to select an action or hide it.

Hover over a pet to show a speech bubble with its current activity, actual remaining quota, reset times, balances, refresh timestamp, and paused-refresh status. It uses the same quota-window preference as the main panel and explains when data is unavailable. The bubble stays within the visible screen, appears below pets near the top edge, and never takes keyboard focus.

The Antigravity provider uses the Gemini character. Codex uses the gallery's main GPT dragon character. These are display choices, not additional quota providers.

## Artwork and animation

- DeepSeek: the user's installed `PC2005-cloud/dsh-pet` **0.3.8** artwork, imported from 14 transparent WebM clips as 10 fps PNG atlases. Includes idle, thinking, working, waiting, attention, sleeping, waving, stretching, eating, dancing, playing with a cube, magic, looking around, and jumping. The original blue-haired whale-maid appearance is preserved.
- Codex, Claude, Kimi, Grok, Gemini: generated 2D chibi characters based on the [character gallery](https://genderswapai.com/zh-CN/ai-gijinka/gallery), matching the installed DeepSeek pet's compact proportions and outlines. Each has 32 drawn frames covering eight actions: blinking, waving, thinking, reading, stretching, eating, dancing, and sleeping. Core and extra sheets share a scale and bottom-center anchor. These use four key poses per action; DeepSeek's source animations have more frames.
- Generated artwork uses the built-in `image_gen` tool. Exact prompts and reference URLs are in [`artwork.json`](../Sources/QuotaBar/Resources/Pets/artwork.json). All selected assets live in `Sources/QuotaBar/Resources/Pets/`.

DeepSeek animation source: [PC2005-cloud/dsh-pet](https://github.com/PC2005-cloud/dsh-pet). Its included license is preserved as `DSH-PET-LICENSE.txt`. The gallery credits the model character illustrations to **ZipZipPipe**, and the original DeepSeek character to **上善无形** (the gallery marks DeepSeek derivatives CC BY-NC-SA 4.0). These third-party character assets are distinct from Quota Bar's own MIT-licensed code; retain the source credits with distributions.

Reimport DeepSeek assets from an installed package with FFmpeg available:

```sh
zsh scripts/import-deepseek-pet.sh /path/to/node_modules/dsh-pet
```

## Runtime

`DesktopPetController` owns one nonactivating transparent `NSPanel` per provider and observes `AppPreferences.desktopPets`. Each view observes existing provider snapshots. Pets make no model calls, start no extra polling, and do not depend on DSH being running or installed after build. Only the active animation atlas is retained per pet. Reduced Motion freezes animation. Disconnecting a monitor brings its pets onto a remaining screen.

Idle and disconnected pets alternate their idle animation with leisure actions every 6–10 seconds. Working, thinking, and approval states select corresponding animations. A click or context-menu selection temporarily plays the requested action before returning to the current activity. Offline status is explained in the bubble while the companion stays animated.

The SwiftPM `QuotaBar_QuotaBar.bundle` is copied into the app's resources by `scripts/build-app.sh`.

## Validation

```sh
swift test --skip 'live'
QUOTABAR_PET_PREVIEW_DIR="$PWD/dist/pet-preview" swift test --filter desktopPetWindows
./scripts/build-app.sh
```

The window test uses isolated preferences and mock snapshots without starting collectors. It verifies independent windows, closing, and focus preservation. The optional environment variable exports UI captures for visual inspection.
