# Driftnest

A cozy pet-town game made with **Godot 4.3**, built for **iOS**, with a **web build on GitHub Pages** for quick testing.

You're the new Keeper of a little town in the meadows. Hatch pets from eggs, give them tools and jobs, and grow the town together: chop wood, dig stone, catch fish, build houses and push the town border out towards the lake and the crystal hills.

## The loop

1. **Hatch.** The egg you carry warms up over time (the Nest warms more at half speed, even while you're away). Each hatch is a random real or mythical creature from that egg's pool.
2. **Equip.** A pet's **tool** decides its job: Axe → woodcutting, Basket → foraging, Pickaxe → mining, Fishing Rod → fishing, Hammer → building, Compass → exploring.
3. **Assign.** Send it to a matching workplace. It walks there and starts producing.
4. **Build.** Spend resources to place buildings anywhere inside the town border. Builder pets at the Builder's Hut put them up, and you can help by hand.
5. **Grow.** Houses raise the pet cap. Upgrading the Town Hall widens the border and unlocks new buildings. Decorations add **charm** (+1% to all production per point, up to +50%).

## Pets, talents and skills

| | |
|---|---|
| **Talents** | Every species has 1–2 natural talents (e.g. Capybara: Fishing + Foraging, Qilin: Building + Foraging). Talented work is **x1.5**. Shown in the Pet Log once discovered. |
| **Tools** | Crafted at the Workshop. Wooden x1, Stone x1.5, Crystal x2.2. |
| **Pet level** (1–10) | Gained by working, or by feeding berries (+4 xp) and fish (+12 xp). Growth stages: Sprout, Fledgling, Bloom, Elder, Radiant. |
| **Job skills** | Each job has its own skill that rises while the pet works it, **capped at the pet's level**. Each skill level is +15% speed. |
| **Explorers** | Go on trips and bring back glimmer, supplies and, about 12% of the time, a new egg. |

Pets keep working while the game is closed, for up to **8 hours**. You get a "welcome back" summary when you return. A hidden browser tab or a backgrounded iOS app catches up the same way.

## Buildings

| Building | Town Hall | Notes |
|---|---|---|
| House | 1 | +2 pet capacity, small glimmer income |
| Lumber Camp | 1 | Wood. Needs 3 trees nearby (Planted Trees count) |
| Berry Farm | 1 | Berries |
| Quarry | 1 | Stone. Needs 2 rocks nearby |
| Workshop | 1 | Craft tools |
| Market | 1 | Sell resources for glimmer |
| Fishing Dock | 2 | Fish. Must touch the lake |
| Explorer's Lodge | 2 | Glimmer, supplies, eggs |
| Crystal Mine | 3 | Crystal. Needs a crystal outcrop nearby |
| Path, Flower Bed, Planted Tree, Lamp Post | 1 | Decorations / charm |
| Fountain / Pet Statue | 3 / 4 | Big charm |

The map is an open 80×80-tile meadow: forest to the west, rocks to the north, a berry patch, a lake to the south-east, and crystal hills to the east. There's a tutorial goal chain in the top-left that walks new players through all of it.

The town is 3D by default (Settings > 3D town switches back to the classic 2D view; same save).

Controls: WASD / arrows or the on-screen stick to walk. Tap pets and buildings to manage them. Hold the action button near trees, rocks, bushes, water or construction sites to gather or help. Zoom with +/-, the mouse wheel or a pinch. In 3D, turn the camera with the < > buttons, Q / E, right-drag, or a two-finger twist; drag one finger to look around.

## Project layout

```
scripts/data.gd          ALL content: species + talents, eggs, jobs, tools, buildings, town levels, goals  ← tune here
scripts/game.gd          autoload "Game": state, simulation tick, offline catch-up, actions, save/load
scripts/world_map.gd     seeded map generation (trees, rocks, lake, crystals) on a tile grid
scripts/boot.gd          starts the 3D or classic 2D town (Settings > 3D town)
scripts/main.gd          world scene, Keeper movement, taps, building placement, Keeper actions
scripts/world3d/         the 3D view: main3d.gd (camera, taps, placement), terrain3d.gd (ground, water,
                         nature), models3d.gd (every model), actors3d.gd (buildings, pets, Keeper),
                         mesh_kit.gd (merges shapes into one mesh), overlay3d.gd (badges, reward text)
scripts/hud.gd           all UI (built in code): resource bar, goals, Build menu, building panels, pets, Pet Log, eggs
scripts/building_view.gd procedural building art (+ construction + placement ghost)
scripts/pet_actor.gd     pets walking to work / wandering
scripts/pet_art.gd       procedural creatures, eggs and tool icons
scripts/nature_prop.gd, terrain.gd, ambient.gd, overlay.gd, player.gd, portrait.gd, joystick.gd
shaders/                 ground, water and screen post-processing
fonts/                   Nunito (OFL)
tests/smoke.gd           automated play-through used by CI
```

### Art style ("storybook 3D")

Everything is still drawn in code, but in a 3/4 view with one light source from the top-left:

- `pet_art.gd` is the shared toolkit: lit vertex-colour gradients, ink outlines, specular dots, rim light, soft contact and cast shadows. It also draws the creatures, eggs and tool icons. Animated things use fast triangle fans, so a pet costs well under 1 ms to draw.
- `building_view.gd` draws buildings with a lit front wall, a shaded side wall and roofs seen from above. Its static body is redrawn only when something changes; smoke, flags, lamp glow, fountain spray and nest eggs sit on a small animated layer.
- `shaders/ground.gdshader` paints the meadow. `shaders/water.gdshader` animates the sunken lake: depth colour, ripples, glints and shore foam. `shaders/post.gdshader` adds the miniature-model finish: tilt-shift blur at the top and bottom, a warm sun wash, a vignette and paper grain.
- `ambient.gd` adds butterflies and drifting pollen. The UI font is Nunito (SIL Open Font License, `fonts/OFL.txt`).
- `godot --path . -- --showcase` builds a busy town and saves screenshots. `godot --path . res://tests/gallery.tscn` renders every creature, egg and tool.

To add a creature, add it to `SPECIES` (with `talents`) and `SPECIES_ORDER` in `data.gd`, then add it to an egg's `pool`. To add a building, add it to `BUILDINGS` + `BUILD_ORDER` and give it a drawing in `building_view.gd`.

## Web test build on GitHub Pages

Every push to `main` runs `.github/workflows/deploy-web.yml`. It imports the project, runs the smoke test, exports the **Web** preset (no-threads, so it works on Pages and iPhone Safari) and publishes it.

One-time setup: **Settings → Pages → Source: GitHub Actions**.

## iOS build

You need a Mac with Xcode and an Apple Developer account. In Godot 4.3: install export templates, then **Project → Export → iOS**. Set your Team ID, a bundle ID you own (placeholder: `com.loworld.driftnest`) and app icons, then export and run from Xcode.

## Tests

```
godot --headless --path . -- --smoke
```
Plays through hatching, building, every job, crafting, feeding, buying eggs, Town Hall upgrades, skill caps, an offline hour and save/load. It prints `SMOKE OK` on success. Drop `--headless` to watch it and get screenshots in Godot's user data folder (`shots/`).

Saves from the earlier sky-island version aren't compatible, so they start a fresh town.
