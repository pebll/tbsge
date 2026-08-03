# Assets archive (1B — moved, not deleted)

Unused or pipeline-only assets were moved under `assets/_archive/` so the runtime `assets/` tree stays lean. **Nothing here was permanently deleted.** Approve a delete list later if you want the disk space back.

Approx size of archive: ~53M (plus large unused piles still in `assets_raw/` music/speech — left in place because they are source packs, not under `assets/`).

## What moved

| Archive path | Why |
|--------------|-----|
| `sfx/move_stone.wav` | Duplicate of referenced `assets/sfx/unit/move_stone.mp3` |
| `sfx/air_move.wav` | Unreferenced |
| `sfx/impact_-_starninjas.zip` | Archive zip, not loaded |
| `icons/batch3_*`, `batch2.png` | Zero runtime references |
| `icons/base_unused/{heal,hat,necromance,spell,weak}.png` | Unused base icon slices |
| `icons/base_icons.png` | Source atlas; game loads slices |
| `tiles/` beige piles, spritesheets, flat terrain duplicates, `tiles_1_2.png` | Not used by `tile_visu` (loads `tiles_terrain/`) |
| `units_sliced_tree/` | Legacy v1 unit art; gameplay uses `units_v2/done` |
| `units_v2_pipeline/{uncut,transparent}` | Slice pipeline intermediates |
| `projectiles/{bolt,dart,rock,bandage,projectiles}.png` | No `projectile_id` / atlas only |
| `banners/` masters, zip, `banners_0_3` | Unused beyond `banners_0_0..2` |
| `raw/random deletable`, tortoise wav | Labeled junk / unreferenced |

## Still in `assets_raw/` (not archived this pass)

- `music/CCBY battlemusic/` (~79M) — unused battle themes
- `speech_*` packs — unused
- `resources/sfx_monster/` — unused
- **Keep:** `assets_raw/music/bgmusic_menu.wav` (menu music)

## Runtime keepers (do not archive)

- `assets/units_v2/done/**` referenced by `data/units/*.tres`
- `assets/tiles_sliced/tiles_terrain/{grass,desert,forest,mountain,water}.png` + `tiles_bottom/base.png`
- Used icons in `base_icons_sprites/`
- Used SFX under `sfx/{defaults,ui,combat,unit/move_stone.mp3}`
- Projectiles: `arrow`, `spit`, `magicball`, `fireball`
- Banners `banners_0_0` … `banners_0_2`

## Scene fix paired with this move

- Removed hidden dragon placeholder texture from `scenes/legion.tscn` (was the only `units_sliced` reference).
