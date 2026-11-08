# Roadmap

The living board: what's next, in order. Design reasoning lives in `design/`; open decisions live in `open_questions.md`.

Legend: `[x]` done (bug fixes verified by tests; still give them one in-editor look) · `[ ]` open

---

## Bugs / UX notes

- [x] **Battle log losses stop at 1.** The live death counter was overwritten instead of added to (`battle_action_log_panel.gd`, `cumulative=false`). Now adds up.
- [x] **Loss & damage should pop separately.** The killing hit now emits the damage tick first and the loss tick ~0.22 s later, so each chip bumps on its own (`action_playback.gd`, `LOG_DEATH_POP_DELAY`). The overall hit rhythm is unchanged.
- [x] **Keep selection when starting a combat** so you can watch it live in the legion strip. Human turns now keep the attacker selected during playback (targeting overlays are cleared) and still inspected afterwards. If the attacker is wiped, the selection is cleared. AI turns still deselect.
- [x] **Action bar a bit higher** so it doesn't touch the legion stat box: raised 20 px (`scenes/ui/battle_action_bar.tscn`). Adjust `offset_top/bottom` if you want more room.
- [x] **Crashing bug** — no repro given. Most likely cause found and fixed: the AI turn loop and combat playback kept running after leaving the battle scene (pause → abandon, or game over → menu) and touched freed nodes. All those coroutines now stop when the scene is gone. **If you still crash, note what you were doing** (AI turn? abandon? rematch?) and copy the Godot error line here.
- [x] **Pause menu didn't pause the AI**: the AI kept acting under the pause box. It now holds between actions while the menu is open.
- [x] **Swap exploit:** wait a legion, then swap another legion with it → the waited legion could act again. It now stays waited (test added).

Found by the click-through autopilot (`tools/run_ui_autopilot.sh`, 2026-11-03):
- [x] **Draft panel script error**: `MinigameSetupPanel.show_for_team` set `.disabled` on a `GameButton` (it has `button_disabled`), which aborted the function on every draft refresh, so the Random team / Ready buttons were never disabled when they should be.
- [ ] **Attack preview covers its own target**: hovering an enemy in the lower part of the screen opens the comparison bar (attacker | VS | defender) on top of that hex, so the click hits the panel instead of attacking. Options: put the preview at the top of the screen when the target is low, make the bar ignore the mouse (`MOUSE_FILTER_IGNORE`), or shrink it.
- [ ] **Comparison bar runs under the battle log**: the 3-part preview is wider than the free space; its attacker strip slides under the left log panel.
- [ ] **Battle log panel is wide and opaque** (~540 px of 1920) and starts empty. Consider a narrower/translucent panel or starting collapsed.
- [ ] **Draft camera doesn't frame your deploy zone** at 1920×1080: after "Random team" most of your legions are off-screen.

Carried over from the v0.1 board:
- [ ] Turn clarity: whose turn it is and how to end it should be obvious (`TurnHud` + discoverable wait/pass).
- [ ] Label **Dev Test** as "Advanced / Lab".
- [ ] Delete local `git replace` refs if any reappear (`git replace -l`).

---

## Milestones

Decisions behind this order: `open_questions.md` → Decided (2026-11-07). Skirmish ships first; the economy mode comes after the beta.

### 0.1 — AI overhaul (finish)
Goal: the AI feels smart in battle. See [`design/ai.md`](design/ai.md) and [`utility-ai-quality.md`](../odd/tasks/utility-ai-quality.md).
- [x] Utility AI with weighted features, Monte Carlo expectation over the real resolver, threat map, GA/MAP-Elites tuning, held-out benchmark (PR #4)
- [x] Opponent choice in Play setup: Evolved / Hand-tuned / Cascade (PR #5)
- [x] **Focus fire within a turn**: legions coordinate on one target until it's wiped (`team_finish` feature; benchmark: neutral to a slight lean, see `design/ai.md`)
- [x] **Legion ordering within a turn**: ranged/support act first, melee finishes, tank swaps forward (stationary shots/heals first, `cover_ally` feature; strict role tiers measured worse)
- [x] **Whole-turn planning**: try the strongest first moves on a copy of the board, finish the turn with the utility policy, keep the best; runs on a worker thread in-game. Clear win over the greedy AI (see `design/ai.md`)
- [x] `--draft mirror` for `run_ai_duel.sh` (same army both sides; measures play, not the draft) + `utility_v0` reference brain
- *Later (not 0.1):* smart AI draft (after balance), enemy-reply lookahead, ranged kiting, stall-breaker, exploit tests

### 0.1.5 — Foundations before effects
- [ ] **Mixed-legion data model**: a legion is any set of units; visuals, draft cost, SFX, stats and the legion strip read per-unit identity instead of `Legion.unit_type` (UI to create mixed legions stays in 0.4)
- [ ] **Counter tags** on every unit (fixed list: armored, flyer, swarm, shielded, ranged, support, …), shown in tooltips
- [ ] Status-effect framework: `StatusEffect` model + pre-strike / on-hit / on-death / turn-start hooks in `CombatResolver`, icons on legion and strip, tooltip, battle-log line

### 0.2 — More effects
Per-effect dev flow: effect → legion → test → AI → AI test. See [`design/combat.md`](design/combat.md).
- [ ] Regeneration
- [ ] Lifesteal
- [ ] Pierce (break shield)
- [ ] Attack buff / debuff
- [ ] Poison (ticks at the poisoned legion's turn start, N turns)

### 0.3 — Terrain
- [ ] More terrains: swamp, hill?, badlands, flower grass, jungle, tundra
- [ ] Better map generation
- [ ] Line of sight (mountains block ranged + heal_ally)
- [ ] **Flying** (moved here from 0.2 so it ships complete with terrain; exact rules to design then)
- [ ] Fog of war (AI sees through fog at first)
- [ ] Forest: defence + slower + lower vision · Swamp: slower
- [ ] Unit terrain affinities (e.g. scorpion faster on desert)
- [ ] Right-click an empty tile → terrain name + effects
- [ ] Water units?

### 0.4 — Legion mixing (UI/UX)
- [ ] Build mixed legions in the draft + all UX (data model already done in 0.1.5)
- [ ] New effects: Freeze, Scare, Summon, Merge

### 0.5 — Skirmish polish → beta
- [ ] Balance pass (uses the duel stats + counter tags)
- [ ] **Smart AI draft** (value/role/counter-based, needs the balance pass first)
- [ ] Better drafting for players (pick 1 of 3, or a random set to draft from)
- [ ] Polish UX / UI / tooltips / rules (see the autopilot findings above)
- [ ] Real difficulty levels? (see open question 3)
- [ ] Save / load
- [ ] Performance pass (if needed)
- [ ] Release **Realmrise Tactics** beta on itch (desktop) + a testing & feedback setup

### After the beta
- [ ] Economy mode prototype: fixed capital, builders + map-placed buildings, gold/food/science (see `design/economy.md`, `progression.md`, `exploration.md`)
- [ ] Sounds & music

### Parked (no work until after the beta)
- Battle royale / walking factory · Factions · Campaign & tutorial · Online multiplayer (1v1 with clock)

### Release checklist (when an export preset exists)
- [ ] Add `*.json` to the export include filter, or `data/ai/profiles/*.json` won't ship and "Evolved" silently falls back to hand-tuned.

### Tech/infra backlog (no milestone yet)
- [x] CI that runs `./run_tests.sh` headless (`.github/workflows/tests.yml`, `tools/get_godot.sh`)
- [x] Seeded match RNG (`MatchSession.rng`)
- [x] Wait state on the legion; capability aggregation; shared combat sampler (see `codebase.md`)
- [ ] Repo slimming: archive delete list, evolve run data (see `codebase.md` #14/#15)
- [ ] Parallel evolve worker silently failing a job (`eval job N returned no result`)

---

## Assets

### Icons
- [x] Coin · [x] Heal · [x] Damage · [x] Size · [x] Range
- [ ] One icon per status effect (comes with 0.2)

### Sounds
- [ ] Death
- [ ] Shield block
- [ ] Shield break

---

## UX backlog (from the old U4 list, not scheduled)
- Optional confirm for dangerous terminal actions
- Always-visible remaining AP on the selected legion
- Keyboard hints in tooltip footers (Tab cycle, Space wait)
- Colour-blind-safe overlays (icons + patterns)
- Undo last action (sandbox / learning)
- Coach marks the first time a keyword appears (parked until tutorial)
- Turn-order / legion list when a battle gets busy
- Draft picker: tier pip + one-line role
