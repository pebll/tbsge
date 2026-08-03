# Assets archive (moved, not deleted — except speeches)

Unused or pipeline-only assets live under `assets/_archive/` so runtime `assets/` stays lean.

**Deleted (by request):** `assets_raw/speech_*` (dragon, farmer, ork, soldier, wizard).  
**Removed empty:** `assets_raw/` (everything else relocated).

## Runtime keepers

| Path | Role |
|------|------|
| `assets/music/bgmusic_menu.wav` | Menu / BGM (`AudioManager`) |
| `assets/units_v2/done/**` | Unit icons — **keep unused slices** for future roster |
| `assets/tiles_sliced/tiles_terrain/` + `tiles_bottom/base.png` | Map tiles |
| `assets/icons/base_icons_sprites/` | UI / action icons (incl. `range.png`, `size.png`, `target.png` from batch3) |
| `assets/sfx/{defaults,ui,combat,unit}/` | Game SFX (placeholders OK for now) |
| `assets/projectiles/{arrow,spit,magicball,fireball}.png` | Ranged VFX |
| `assets/banners_sprites/banners_0_0` … `0_2` | Team banners |

## What’s in `assets/_archive/`

| Area | Contents |
|------|----------|
| `music/` | CCBY battle pack, `bgmusic_ambient.wav` |
| `raw/` | Old `resources/` (monster SFX, etc.), tortoise wav, `random deletable` |
| `sfx/` | Duplicate `move_stone.wav`, zip packs, extras |
| `icons/` | batch2/3 sheets + unused slices, base atlas |
| `tiles/` | Beige experiments, spritesheets, flat duplicates |
| `units_sliced_tree/` | Legacy v1 unit art |
| `units_v2_pipeline/` | `uncut/` + `transparent/` intermediates |
| `projectiles/` | Unused projectile PNGs / atlas |
| `banners/` | Unused masters / extra banner slice |

Approve a **delete list** later if you want the disk space; until then archive stays.

## Scene note

- `scenes/legion.tscn` no longer references `units_sliced` (placeholder removed).
