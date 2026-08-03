# FableQuest missions

Living checklist. Update as items are done; keep **short-term** small and shippable.  
You own git — agents should not commit unless you ask.

---

## Status snapshot

**In good shape**
- Engine vs modes: shared `BattleHostWiring` / `BattleInputLock`; minigame + sandbox both modes.
- `use_action` command surface; wait-stain fixes (move + swap); AI debug off (Dev Test toggle).
- Menu music at `assets/music/bgmusic_menu.wav`; unused media under `assets/_archive/` (speeches deleted).
- Headless suite green (17). Unused `done/` art kept for future units.

**Parked / later**
- Real default + per-unit SFX pass (see Next features).
- Manual smoke checklist (you play; see below).
- Optional delete of `assets/_archive/` piles when you’re ready.

---

## Short-term missions

### Done
- [x] AI debug off + Dev Test toggle; clearer Dev Test labels
- [x] Range icon; Gargoyle `air_move`
- [x] Wait-stain tests + swap clears stains; ARCHER balance / AI ranged-no-return tests
- [x] Menu music → `assets/music/`; unused raw → `assets/_archive/`; speeches deleted
- [x] Keep unused `done/` sprites for future units
- [x] Keep placeholder SFX for now
- [x] Document ObjectDB test-exit noise in `AGENT_NOTES.md`

### Still open (your side)
- [ ] **Manual smoke** (see “How manual smoke works” below) — report ok / what failed
- [ ] Later: approve delete list from `assets/_archive/` if you want disk space back

---

## How manual smoke works

No special harness — you run the game and poke three flows. ~5 minutes.

1. **1-hex move re-highlight**  
   Main menu → Dev Test → Sandbox or Duel. Select a legion, click an adjacent blue/move tile. After the move tween, the **new** tile should stay selected and show move/attack highlights again (not a blank board).

2. **Attack-choice popup**  
   Need a unit that can melee **and** range the same enemy (e.g. Spider or Archer next to a foe). Select it; click the enemy hex that shows the pink/choice overlay. Popup with sword/bow should appear; picking one fires that action; clicking outside should dismiss without acting.

3. **Wipe-tile ally can still act**  
   Harder to force in free play; automated tests cover it. Optional: fight until an attacker dies on a tile, move another ally onto that hex same turn / next actions — they should still get highlights and be able to attack. If anything rejects with “cannot use …”, note the log line.

Reply with e.g. `smoke: 1 ok, 2 ok, 3 skipped` or what broke.

---

## Next features missions

### Near-medium
1. **SFX content pass** — replace defaults; per-unit select/move/hit/death (Demon, Spider, Archer templates first); wire more from archive/raw as needed.
2. **Pluggable AI behaviors** — registry; hold / kite / focus wounded.
3. **Second mode vertical slice** — skirmish without draft (or similar) on the shared engine.
4. **Ranged LOS / blocking** — optional; keep no-LOS arcade flag.
5. **Action set expansion** — charge, push, defend, wait-as-action, `action_ids` on defs.
6. **Match persistence** — save/load / command log replay.
7. **More units from existing `done/` art** — axeman, treant, mummy, rat_mage, etc.

### Larger
8. Campaign / map graph  
9. Economy / production (only if that fantasy returns)  
10. Hotseat / fog polish  
11. Content pipeline docs + unreferenced-sprite script  
12. Balance tooling UI  

### Stretch
- Battle music playlist from archived CCBY pack  
- CI on `./run_tests.sh`  

---

## How to use this board

- Check off short-term items; don’t grow short-term with epic work — promote to Next features.
- Prefer engine-first changes + a headless test before UI.
