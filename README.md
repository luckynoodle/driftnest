# Driftnest

A cozy creature-raising game made with **Godot 4.3**, built for **iOS**, with a **web build on GitHub Pages** for quick testing.

You're the new Keeper of a floating sky island. You start with a Dawn Egg on your back. Doing chores around the island warms the egg until it hatches into a creature — a real animal or a mythical one — that follows you around, grows as you work together, and joins your collection.

## How it plays

| Thing | How it works |
|---|---|
| **Eggs & warmth** | The egg you carry gains warmth from every chore. Full warmth = it hatches. |
| **Chores** | Stand in a spot until the ring fills: *Moonberry Grove*, *Tidepool*, *Cloudmill*, *The Nest* (nap). Two are errands: *Starmail* (pick up at the Star Post, follow the arrow to a glowing mailbox) and *Lantern Ridge* (light all three lanterns). |
| **Glimmer** | The currency. Earned from chores, spent at the **Egg Kiosk**. |
| **Wishes** | Your companion has a thought bubble showing the chore it wants. Grant it for 2× XP and +10 glimmer. |
| **Habitats** | Meadow, Tide, Ember, Aurora. A companion is 50% faster at chores from its own habitat, and +8% faster per level. |
| **Growth** | Sprout → Fledgling → Bloom → Elder → Radiant (Lv 1–5). Creatures get bigger, Elders get orbiting sparkles, Radiants get a halo and aura. Kitsune grow extra tails (up to 9). |
| **Collecting** | 20 species across 4 buyable eggs, rarities Common → Legendary, and a 1-in-25 **Prismatic** colour variant. Undiscovered species show as `???` and silhouettes in the Bestiary. |

Controls: WASD / arrow keys, or the on-screen stick (touch or mouse-drag). Progress auto-saves (browser storage on web, app sandbox on iOS).

## Project layout

```
project.godot            landscape 1280×720, expand stretch, GL Compatibility renderer
scenes/main.tscn         single entry scene
scripts/data.gd          ALL content: species, eggs, chores, rarity, stages  ← start here to add creatures
scripts/game.gd          autoload "Game": state, rewards, hatching, save/load
scripts/main.gd          world layout, movement, chore logic
scripts/hud.gd           all UI (built in code): cards, Egg Kiosk, Pets/Bestiary, Eggs, Help, hatch reveal
scripts/pet_art.gd       procedural creature + egg drawing (no image assets)
scripts/player.gd, pet_follower.gd, prop.gd, terrain.gd, sky.gd, overlay.gd, joystick.gd, portrait.gd
tests/smoke.gd           automated play-through used by CI
export_presets.cfg       "Web" and "iOS" presets
.github/workflows/deploy-web.yml
```

All art is drawn with code, so there are no assets to import and the web build is small. When you're ready for real art, swap `PetArt.draw_pet` for sprites per species — the rest of the game doesn't care how creatures are drawn.

### Adding a creature
1. Add an entry to `SPECIES` in `scripts/data.gd` (pick body/accent colours and an `ears`/`tail`/`extra` combo) and add its id to `SPECIES_ORDER`.
2. Add `["your_id", weight]` to an egg's `pool`.

## Web test build on GitHub Pages

1. Push this folder to a GitHub repo (branch `main`).
2. In the repo: **Settings → Pages → Build and deployment → Source: GitHub Actions**.
3. Every push to `main` runs the workflow: imports the project, runs the smoke test, exports the **Web** preset and publishes it. The URL appears on the workflow run and in Settings → Pages.

The Web preset uses Godot's **no-threads** template, so it runs on GitHub Pages without the special cross-origin headers threaded builds need, and it works in iOS Safari.

## iOS build

You need a Mac with Xcode and an Apple Developer account.

1. Open the project in Godot 4.3, then **Editor → Manage Export Templates → Download and Install**.
2. **Project → Export → iOS**: fill in **App Store Team ID**, check the **Bundle Identifier** (`com.loworld.driftnest` — change it to one you own), and add app icons under *Icons* (1024×1024 at minimum).
3. Export. Godot writes an Xcode project into `build/ios/`; open it in Xcode, pick your device and run (or Archive → TestFlight).

The game is landscape-only (sensor landscape) and uses the GL Compatibility renderer, which runs on every iPhone that supports iOS 12+.

## Running the tests locally

```
godot --headless --path . -- --smoke
```
Prints `SMOKE OK` and exits 0 if hatching, every chore, the shop, levelling to Radiant and save/load all work. Drop `--headless` to watch it play and get screenshots in Godot's user data folder (`shots/`).

## Ideas for next steps
- Trading / gifting between friends (needs a backend — e.g. Firebase or Nakama)
- Customisable Keeper house on a second island
- Fusing four of the same creature into a guaranteed Prismatic
- Day/night cycle where Aurora chores only appear at night
- Sound and music
