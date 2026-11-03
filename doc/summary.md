# Summary

## The project

**FableQuest** (working toward *Realmrise Tactics*): an isometric, turn-based hex strategy game in Godot 4.6. Players command **legions** (stacks of units on a 6×2 footprint board) and fight Civ-style multi-legion battles. The long-term idea is a fast tactical game with a light, raidable economy, a time-gated science tree, and exploration (ruins, neutrals, mercenaries). It's the tactical core of a possible future full *Realmrise*.

## Where it stands (Nov 2026)

**Playable v0.1 skirmish loop**: main menu → setup (Vs AI / hotseat, names, map size, difficulty) → draft legions with gold onto deploy slots → battle → victory/defeat → rematch.

- **Combat**: alternating strikes with draining, random targets, immediate deaths, shields, melee vs ranged with counter-fire by range, AP + terminal actions, swap-moves, cooldowns.
- **Actions**: move, melee, ranged, self-heal, heal-ally, teleport. Data-driven with per-unit overrides.
- **15 unit types** (8 in the draft pool, each with a distinct role).
- **UX**: legion strip HUD, action bar with disabled reasons, expectation preview (Monte Carlo), live battle log, tooltips and glossary.
- **AI**: greedy heuristic (net-HP scoring, flanking, heal gating, teleport-to-engage) + AI-vs-AI duel runner + headless balance sim.
- **Engine**: model-first command API (`MatchSession.apply`), visual playback afterwards; shared by the minigame and the sandbox mode; a large headless test suite.

## What's next (roadmap)

| Milestone | Focus |
|-----------|-------|
| **0.1** | AI overhaul: utility AI on the real combat estimator, value kills, manoeuvring, weights in one resource tuned by an evolutionary algorithm |
| **0.2** | Effects: status framework + visuals, flying, regeneration, lifesteal, pierce, attack buff/debuff, poison |
| **0.3** | Terrain: new terrains, better map gen, LOS, fog of war, terrain modifiers and unit affinities |
| **0.4** | Legion mixing + freeze, scare, summon, merge |
| **0.5** | Skirmish polish: better draft, UX, AI, balance, save/load → beta on itch |
| Later | Economy mode (capital, builders, science), 1v1 multiplayer with a clock, battle royale experiment, sound/music, content |

## The design in brief (from your notes)

- **Fun** = outplaying the opponent with less value + the spectacle of big armies.
- **Progression** = a 3-tier science lattice: higher nodes need *both* parents, are visible once you have *one*. Researches are randomised (shared, per player, or later factions). Each one unlocks a legion.
- **Economy** = gold / food / science. One capital (lose it, lose the game). The economy is spread over the map: pre-placed buildings and builder-built farms/mines. Claim or burn enemy buildings. A **soft food cap** penalises over-sized armies instead of blocking them.
- **Exploration** = ruins, barbarians, neutrals, mercenaries, statues, spawners, special tiles, mostly guarded.
- **Competitive** = 1v1 with a chess-like clock (bank + delay + increment). Economy management allowed during the opponent's turn.
- **Battle royale idea** = walking factory-cities and a crumbling map to force engagement.
- **AI** = utility scoring with optimised weights; per-effect dev flow (effect → legion → test → AI → AI test).

## This pass

- Docs reorganised into `doc/` (this folder). The original notes are preserved in `journal.md`.
- 7 fixes: the 4 listed bugs, the likely crash, the AI not pausing, a swap/wait exploit. Not yet run in Godot.
- Code review with a prioritised refactor backlog → `codebase.md`.
- 23 open questions → `open_questions.md`. The top 3: is the skirmish the product or a test bed? Will legions mix (decide before 0.2)? What's the smallest economy prototype that proves the fun?
