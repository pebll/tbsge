# AI

## Direction (decided)

- **Utility AI**: score every legal action in context and pick the best. RL / learning agents are out of scope.
- The scoring weights are **parameters, not magic numbers**: collect them in one place so an optimiser (evolutionary algorithm) can tune them headless.
- Build each new effect with its AI scoring in the same slice (see dev flow below).

## Where it stands (code)

- `scripts/ai/behaviors/attack_nearest_enemy.gd` (~730 lines): legion ordering, heal gating, flanking, teleport-to-engage, stand goals, soft-path walking.
- `scripts/ai/ai_action_scorer.gd`: a net-HP heuristic (`enemy_hp_lost + own_hp_gained - own_hp_lost`) with its **own** simplified combat simulation.
- `scripts/battle/battle_expectation_estimator.gd`: a Monte Carlo estimator used by the UI preview (min–max damage/losses).
- `scripts/balance/ai_duel_runner.gd`: headless AI-vs-AI runs with CSV reports. This is the natural fitness function for the EA.

### Gaps that 0.1 should close
1. **Two combat models.** The AI scorer ignores shields, assumes strikes hit the front unit (real combat targets randomly), and doesn't value kills. The UI estimator is closer to the truth. → The AI should call the same estimator (fewer sims + cache), or a deterministic expected-value version of it, so that one rule change updates the resolver, the preview and the AI together.
2. **Constants are scattered** (`HEAL_CRITICAL_RATIO`, `FLANK_OPPORTUNITY_TAX`, scorer bonuses like `+20`, `+5`, `4/hp`…). → Move them into `AiParams` (a Resource) and pass it in. EA genomes = `AiParams` instances.
3. **Hypothetical positions by mutating the grid.** `_score_teleport` temporarily moves the legion on the live grid to ask for targets. → Give the targeting helpers a "from coords" parameter, or score on a cloned `BattleState`.
4. **Greedy, one legion at a time.** No notion of the turn as a whole (who attacks first to set up a kill, who stays back). A cheap upgrade: re-score after each action (already done), plus a "kill potential this turn" term and a threat map of where enemies can hit next turn.

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
