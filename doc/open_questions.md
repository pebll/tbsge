# Open questions

Critical questions to answer before (or during) the next milestones. Each has the reason it matters. Move answered ones to **Decided** with a date.

## Direction & scope

1. **Is the skirmish the product, or a test bed for the economy game?** Milestones 0.1–0.5 polish the draft skirmish (AI tuned to it, balance for it, save/load for it), but every journal entry since August describes a different core loop (capital, production, science, builders). Balance and AI tuned for a no-economy draft only partly carry over. If the skirmish is a stepping stone, consider cutting 0.5 down to "fun enough to playtest" and moving to a minimal economy prototype sooner.
2. **What is the smallest prototype that proves the economy loop is fun?** E.g. capital + 1 builder type + 2 buildings + gold only + a 3-node science tree, no food, no exploration. Without this you could spend months on effects for a game whose structure isn't validated.
3. **Solo dev vs scope.** KingdomHex has two people and is still in development. Which half of the long list are you willing to cut? (Candidates: battle royale, factions, water units, mind control, campaign.)
4. **Working title**: FableQuest / Fable Quest / Realmrise Tactics / tbsge? It affects the itch page, the save paths and the project name.
5. **What's the differentiator from KingdomHex, in one sentence a player would understand?** "Civ-style multi-legion combat" is the claim. Is that visible in a 2-minute video of the game today?

## Combat & content

6. **Will legions mix? Decide now, not in 0.4.** The code assumes one unit type per legion in targeting, range, actions and cost. Every effect written in 0.2 and 0.3 under that assumption is more rework later. If yes, do the data-model change before 0.2.
7. **Random targets vs player control.** Combat targets are random within a legion. That's good for "big armies clash", but it fights against "outplay with less value" (you can't focus the healer inside a stack). Do you want snipe-style effects to be the only way to target, or some deterministic rule (front row first)?
8. **Counters and hard counters need a vocabulary.** Do legions get tags (armored, flyer, swarm, shielded, ranged, support) so the draft, the tech generator and the AI can reason about counters? That's cheap to add now and very useful later.
9. **Flying** (0.2) before **terrain** (0.3): flying is mostly defined by terrain (ignores water/mountains, LOS?). Should the order be swapped, or flying limited to "can only be melee'd by flyers/ranged" for now?
10. **Poison**: per turn or per move? (They lead to very different play: per-move punishes kiting.)

## AI

11. **What does "not exploitable" mean concretely?** Proposal: a growing list of known cheese, each with a test; a new AI must beat the old one on win rate over N seeded mirrored matches.
12. **With fog of war (0.3), does the AI cheat** (sees everything) or does it get a memory model? Honest fog AI is much more work.
13. **EA fitness:** against whom? (Self-play alone tends to cycle; keep a hall of fame of older champions plus scripted baselines.)
14. **How strong should the AI be at each difficulty?** Weight tuning gives one "best" AI; difficulties need deliberate handicaps (noise, shorter look-ahead, fewer considerations).

## Economy & progression

15. **Fixed capital with a farm ring vs walking factory**: these two ideas pull in opposite directions (20/08 vs 11/08). Is the walking factory only for battle royale, or still a candidate for the main mode?
16. **Map-placed vs player-built economy**: the 11/08 notes lean towards HoMM-style pre-placed outposts (no founding); the 20/08 notes add builders that construct. Both, or one? Builders add a whole unit class plus build UX.
17. **Is "production" a fourth resource** or the same as gold? (The mine gives "+prod".)
18. **Food deficit formula**: linear reduction? Can production reach 0? Does it slow science too? What stops a player from going far over the cap for one all-in?
19. **Science tree size and generator rules**: how many nodes per tier, and what guarantees that every random pool can answer every archetype?
20. **Tier naming**: are science tiers (0–III) the same as the UX complexity tiers (I–IV in `design/combat.md`)? Aligning them would make "tier" mean one thing.

## Competitive / multiplayer

21. **Determinism**: online 1v1 with a clock implies lockstep or server-authoritative play. The command model already fits; the RNG must be seeded per match. Who rolls the dice: the server or a shared seed?
22. **Out-of-turn economy commands** ("their turn: economy"): applied immediately or queued for your turn start? Immediate is simpler to reason about only if economy can never affect the board during the opponent's turn.
23. **Target platform**: `project.godot` uses the **Mobile** renderer. Desktop / itch only, or mobile too? This affects UI scale and input (right-click inspect, hover previews).

---

## Decided

- *(2026-08-11)* AI = utility AI with optimised weights; no RL.
- *(2026-08-11)* Science accumulates over time; no buying research with gold.
- *(2026-08-20)* Online multiplayer will be 1v1.
- *(2026-08-20)* Food is a soft cap (production penalty), not a hard cap.
- *(2026-08-20)* Enemy buildings: Claim (2 AP, terminal) or Burn (1 AP, terminal).
