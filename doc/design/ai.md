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
- **Team play (0.1):**
  - *Focus fire*: the `team_finish` feature. For an attack, it measures how much of what the attack leaves of the target (HP + shields) the other allies that can still act this turn could deal (`scripts/ai/utility/ai_team_plan.gd`: reachable strike stands, raw strike power, melee ×0.8). It is 0 when the attack wipes the target alone, since `wipe_prob` covers that case.
  - *Legion ordering*: `UtilityBrain.role_ordering`. A legion whose best move is a shot or heal **from where it stands** acts first; everyone else follows best score first.
  - *Cover*: the `cover_ally` feature. It rewards a swap that pulls a softer ally (wounded, or ranged/support) out of enemy reach and puts a sturdier legion there.
  - `utility_v0` is the brain from before these changes, kept as the version-ladder reference.
  - **Measured (2026-11-07)**: `./run_ai_duel.sh --draft mirror --play-sims` (same army on both sides) against `utility_v0`.
    - Small maps (r3, 75 gold, 360 pairs): 14–15 decisive, survivor margin −0.07 per pair.
    - Large maps (r4, 150 gold, 200 pairs): 17–13 decisive, margin +0.6 per pair (z ≈ 1).
    - Neutral to a slight lean, not a measurable gain.
    - Strict role tiers (all ranged, then melee, then moves) **lost** on large maps (10–18 decisive, margin −1.8), so only stationary support goes first.
  - **Why so little:** the brain already re-scores after every action, so a wounded target's kill odds rise and the next legion tends to follow up. `team_finish` was non-zero in about 5% of decisions and never changed the chosen action in a 132-decision sample.
- **Whole-turn planning (0.1, shipped in-game):** `scripts/ai/planning/turn_planner.gd`.
  - **How it works:**
    - Before each activation, the planner takes the top 2 candidates of every legion that can act (up to 8 options, the greedy pick first).
    - It plays each option on a `TurnSimSession` copy of the board, lets the plain utility policy (2 sims per fight) finish the turn, and scores the end of the turn.
    - The score is army value (wounded units count 60–100% of their price) minus the enemy's, minus 0.5 × the gold the enemy's best strikes could take next turn.
    - It uses 2 rollouts per option with common random numbers. The real game plays the winning first move, then plans again.
  - **In the game:** the planner thinks on a worker thread (`BattlePhaseController._ai_sort_actionable`) with an 800 ms cap per step. Options are tried strongest first, so the cap only drops long shots.
  - **Thinking time:** average 42 / 156 / 351 ms per step on maps r3 / r4 / r5. The worst case uncapped was 2.5 s on r5.
  - **Which brains plan:** `utility`, `utility_hand` and `utility_evolved` plan. `utility_hand_greedy` is the same brain without planning. Evolution and `utility:<file>` stay greedy, because planning is about 8× slower.
  - **Benchmarks (2026-11-07):**
    | Opponent | Setup | Pairs | Decisive pairs (planner–opponent) | Survivor margin per pair |
    |---|---|---|---|---|
    | `utility_v0` | mirror, small (r3) | 240 | 77–39 | +2.6 (z ≈ 4) |
    | `utility_v0` | mirror, large (r4, 150 gold) | 100 | 38–11 | +7.8 (z ≈ 6) |
    | `utility_hand_greedy` | mirror, small | 120 | 39–23 | +2.2 (z = 3.3) |
    | `utility_hand_greedy` | mirror, r4 at 125 gold | 50 | 18–5 | +6.0 (z = 4.4) |
    | `cascade` | random drafts | 100 | 22–4 | 58.5% score (was 57.5%; decisive-win CI [66.5%, 93.9%]) |
  - The planner overrides the greedy choice in only 10–17% of steps, which is enough. Bigger armies gain more.
  - **Next:** the enemy's reply (score the end of the turn after a greedy enemy turn), more rollouts when time allows, and a planner-aware difficulty (fewer options or rollouts on Easy).
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
