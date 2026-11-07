# Realmrise Tactics: summary

*Updated 2026-11-07 after the planning session. Details: [`roadmap.md`](roadmap.md), decisions: [`open_questions.md`](open_questions.md).*

## The game in one paragraph

**Realmrise Tactics** is a turn-based hex strategy game for desktop (Godot 4.6). You command **legions** (stacks of units) and fight Civ-style battles where many legions manoeuvre on one map. The fun is **outplaying the opponent with less value on the board** and **watching big armies clash**. It's the tactical core of a possible future full *Realmrise* (diplomacy, deep economy).

## The plan

**1. Ship the skirmish first.** Draft an army with gold, fight to the last unit, against a good AI or a friend (hotseat). Release it as a beta on itch.

**2. Then the economy mode.** A fixed capital (lose it, lose the game) that produces units. Builders construct farms and mines, and there are neutral buildings on the map to capture. Enemy buildings can be claimed or burned. Resources are gold, food (a soft cap: an oversized army slows production instead of being blocked) and science (time-gated, a randomised tree where higher nodes need both parents).

**Parked until after the beta:** battle royale / walking factory, factions, campaign & tutorial, online multiplayer (1v1 with a chess clock).

## Where it stands

A complete, playable skirmish loop: menu → setup (Vs AI / Hotseat / AI vs AI, map size, difficulty, **choice of opponent AI**) → draft → battle → victory screen → rematch. The game has 15 unit types, six actions (move, melee, ranged, self-heal, heal ally, teleport) with cooldowns, a live battle log, attack previews, tooltips, and a legion strip with sidebar HP bars.

- **AI:** a utility AI that judges fights by simulating them with the real combat code. It beats the old cascade AI. Three selectable opponents: Evolved, Hand-tuned (default), Cascade. **Weak spot:** the AI drafts its army at random, and the draft decides most games. That's a known item for the balance milestone.
- **Engine:** game state updates first and animations replay it afterwards. One seeded RNG per match. 38 headless test suites, CI on GitHub, and a click-through UI test that plays real matches on a virtual screen.

## Roadmap

| Milestone | Content |
|---|---|
| **0.1 AI (finish)** | Focus fire within a turn · legion ordering (ranged/support first, melee finishes, tank swaps forward) |
| **0.1.5 Foundations** | Mixed-legion data model · counter tags on every unit · status-effect framework (model, combat hooks, icons, log) |
| **0.2 Effects** | Regeneration · lifesteal · pierce · attack buff/debuff · poison (ticks at turn start) |
| **0.3 Terrain** | New terrains · map generation · line of sight · **flying** · fog of war (AI sees through it at first) · terrain affinities |
| **0.4 Mixing UI** | Building mixed legions in the draft · freeze, scare, summon, merge |
| **0.5 Beta** | Balance · **smart AI draft** · better player draft · UX polish · save/load · itch release |
| **After the beta** | Economy prototype · sounds & music |

**Open UX bugs from the autopilot** (in the roadmap): the attack preview covers the target tile; the comparison bar runs under the battle log; the battle log is wide; the draft camera doesn't show your deploy zone.

## Key decisions (2026-11-07)

Skirmish first · legions will mix (data model before effects) · random targeting inside a legion, with control from effects · fixed capital is the main mode · counter tags now · flying moves to 0.3 · poison ticks at turn start · fog: AI cheats at first · AI: focus fire + ordering now, smart draft after balance · economy has map buildings *and* builders · title Realmrise Tactics · desktop only · no separate "complexity tiers".

## Still open

Differentiator vs KingdomHex in one sentence · real difficulty levels (before the beta) · production as a 4th resource? · food-deficit formula · science-tree size/generator rules · smallest economy prototype · multiplayer determinism and out-of-turn economy (after the beta).
