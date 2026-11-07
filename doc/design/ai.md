# AI

## Direction (decided)

- **Utility AI**: score every legal action in context and pick the best. RL / learning agents are out of scope.
- The scoring weights are **parameters, not magic numbers**: collect them in one place so an optimiser (evolutionary algorithm) can tune them headless.
- Build each new effect with its AI scoring in the same slice (see dev flow below).

## Where it stands (code, after PR #4)

- **Shipped brain: `utility`** (`scripts/ai/brains/utility_brain.gd`): candidate generation → feature extraction → linear score with an `AiProfile`. The game loads `data/ai/profiles/utility_default.json` if present, but no tuned profile has been shipped, so **in-game it plays the hand-tuned `hand_v1` weights**, argmax (temperature 0), 12 Monte Carlo sims per fight.
- **Opponent choice** (Play setup → "AI"): *Evolved* (`utility_evolved`, weights from GA run `cur2`, shipped in `data/ai/profiles/utility_evolved.json`), *Hand-tuned* (`utility_hand`, default), *Cascade* (the older rule-based AI). Benchmarks 2026-11-07 (held-out seeds): evolved vs hand 50.0% over 30 mirrored pairs (28 pairs split, the draft decides); vs cascade: hand 57.5%, evolved 55.6% over 40 pairs. The evolved profile is a curiosity, not a stronger AI.
- **Difficulty** only scales the AI's draft gold (Easy ×0.75 … Impossible ×2); tactics are identical on every level. Real difficulty levels (temperature, fewer sims, weaker profiles) are still to do.
- **Combat features** come from `CombatExpectation`, Monte Carlo over the real `CombatResolver` via the shared `CombatSampler` (same sampler as the UI preview). Shields, random targets, kills and wipe odds are all included.
- **Threat map** + safety features, walking-distance focus field.
- **Tuning:** GA + MAP-Elites + curriculum (`scripts/ai/evolution`, `run_ai_evolve.sh`), held-out gating bench (`run_ai_bench.sh`, Wilson CI, paired sign test).
- **Baselines:** `cascade` (the old `AttackNearestEnemyBehavior`), `greedy`, `heal_only`, `pass`, used as fixed opponents.
- Results so far and next steps: see `odd/tasks/utility-ai-quality.md`. Utility beats cascade significantly; vs greedy it's not yet significant. The proposed next step is structural (1-ply enemy reply, focus fire within a turn, kiting), not more weight tuning.

## Proposed considerations (a starting set to tune)

Per candidate action, score = Σ weightᵢ · considerationᵢ:
- Expected enemy value removed (HP **and** kills, weighting kills by unit cost)
- Expected own value lost
- Kill probability for the target legion (a wipe removes a whole action from the enemy next turn)
- Focus value of the target (support / ranged / low HP / high threat)
- Threat at the destination next turn (enemy damage that can reach this tile)
- Protection of soft allies (stay between enemies and healers/ranged)
- Tempo: progress toward engagement for far legions
- Heal efficiency (HP actually restored vs the opportunity cost of not attacking)

## Optimisation loop (EA)

1. Genome = `AiParams`. Population ~16–32.
2. Fitness = win rate + margin over N seeded duels against (a) the current champion and (b) a fixed set of older/baseline AIs, on mirrored drafts so the draft doesn't decide the result.
3. Keep a **hall of fame** to avoid cycling (A beats B beats C beats A).
4. Requirements: seeded match RNG (`randi()` is currently used directly in several places), faster headless battles (no `print` per hit: `CombatResolver.quiet`), and an AI that is a pure function of `(state, params, rng)`.

## "Feels smart and not exploitable": make it testable

- **Tactical puzzle tests**: small hand-built boards with one clearly right move (finish the wounded archer, don't walk the healer into melee, swap the tank forward). These already exist in part in `tests/test_ai_attack_nearest.gd`; grow that into a suite.
- **Exploit list**: keep a list of cheese you find in playtests (baiting, kiting the AI's melee with ranged, etc.) and add a test for each.
- **Version ladder**: a new AI must beat the previous one by more than X% across seeds before merging.

## Dev flow per effect

1. Implement the effect / feature (engine + tests)
2. Add legion(s) that use it
3. Test the effect
4. Add its utility-AI consideration(s)
5. Test that the AI uses it (puzzle test)

The goal is many legions with distinct effects **before** building tech and tiers.
