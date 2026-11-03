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

### 0.1 — AI overhaul
Goal: the AI feels smart and isn't easy to exploit. See [`design/ai.md`](design/ai.md) and the task log [`utility-ai-quality.md`](../odd/tasks/utility-ai-quality.md).
- [x] Utility AI: candidates scored by named, weighted features (`AiProfile`, JSON profiles) — PR #4
- [x] Uses Monte Carlo expectation over the real resolver; values trades by gold and wipe chance — PR #4
- [x] Threat map / safety, walking-distance focus — PR #4
- [x] GA + MAP-Elites tuning, held-out gating bench with Wilson CI — PR #4
- [ ] Beat `greedy` with statistical significance (needs structure, not weights: 1-ply enemy reply, team focus fire within a turn, ranged kiting)
- [ ] Stall-breaker for draws the baseline converts
- [ ] Define "not exploitable" as tests: tactical puzzles + known-cheese list

### 0.2 — More effects
Follow the per-effect dev flow (effect → legion → test → AI → AI test). See [`design/combat.md`](design/combat.md).
- [ ] Status-effect framework + visualisation (icons on legion and strip, tooltip, battle log).
- [ ] Flying
- [ ] Regeneration
- [ ] Lifesteal
- [ ] Pierce (break shield)
- [ ] Attack buff / debuff
- [ ] Poison

### 0.3 — Terrain
- [ ] More terrains: swamp, hill?, badlands, flower grass, jungle, tundra
- [ ] Better map generation
- [ ] Line of sight helper (mountains block ranged + heal_ally) — from the old T3 plan
- [ ] Fog of war (decide: does the AI cheat? see open questions)
- [ ] Forest: shield/defence + slower + lower vision
- [ ] Swamp: slower
- [ ] Unit terrain affinities (e.g. scorpion faster on desert)
- [ ] Right-click an empty tile → terrain name + effects (old U3)
- [ ] Water units?

### 0.4 — Legion mixing
- [ ] Allow mixed legions + all UI/UX and logic (big refactor: see `codebase.md` → "Homogeneous-legion assumptions")
- [ ] New effects: Freeze, Scare, Summon, Merge

### 0.5 — Skirmish polish
Goal: release a working and fun skirmish mode.
- [ ] Better drafting (pick 1 of 3, or a random set of legions to draft from)
- [ ] Polish all UX
- [ ] Polish AI
- [ ] Polish UI / tooltips / clarity / rules
- [ ] Balance
- [ ] Save / load
- [ ] Performance pass (if needed)

### Later (unordered)
- [ ] First beta on itch + a testing & feedback setup
- [ ] Economy / battle royale mode: capital/factory, production, science (see `design/economy.md`, `progression.md`, `modes.md`)
- [ ] Sounds & music
- [ ] Multiplayer (1v1 first, with a clock)
- [ ] Content: more units, campaign?, tutorial?

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
