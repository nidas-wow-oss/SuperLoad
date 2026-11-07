# SuperLoad

Faster logins and loading screens for World of Warcraft 3.3.5a (WotLK), plus a few fixes for the default UI.

## What it does

- **Faster login**: the garbage collector is paused while addons load, and other addons can't force full memory cleanups during login or combat. A single cleanup runs once you are in the world, out of combat. A safety cap still cleans up if memory grows too much during login.
- **Faster loading screens**: noisy events (spell, action bar, talent, map, reputation and achievement updates) are muted while the loading screen is up and restored right after.
- **UI fixes** (only through `hooksecurefunc`, no taint):
  - Dropdown menu buttons no longer appear behind the menu background.
  - `InterfaceOptionsFrame_OpenToCategory` opens and scrolls to the right category on the first call.
  - The minimap ping follows its position while you move and fades out smoothly.

There is nothing to configure: install it and it works.

## Installation

1. Download this repository (**Code → Download ZIP**).
2. Copy the `!!!SuperLoad` folder into `World of Warcraft/Interface/AddOns/`.
3. Keep the `!!!` in the folder name: it makes SuperLoad load before every other addon, which is what lets it speed up the login.

## Requirements

- WotLK 3.3.5a (Interface `30300`)
- No dependencies.

## Author

**Nidhaus**
