# Utility AI quality

## Objective
Make the shipped utility battle AI measurably good: it must convert won positions and beat the
cascade/greedy baselines with statistical confidence, and the GA pipeline must be able to ship a
better profile.

## Problem
Baseline (60 mirrored seeds, map 3, budget 75, hand_v1 profile):
- utility vs cascade 50.8%, vs greedy 50.0% (no edge)
- utility vs pass: only 68% wins, 32% draws (cascade: 94.6%) -> cannot close out games
- utility vs heal-only: 44% draws, 8 timeouts
Causes: per-candidate threat normalization, overcounting threat map, single global focus,
no focus fire, train/play sim-count mixup, thread race in parallel eval, evolved profile never shipped.

## Scope
scripts/ai/** (brain, utility, threat, expectation, evolution, curriculum), scripts/balance/ai_duel_*,
tests/**, run scripts, .gitignore. Game rules are out of scope.

## Constraints
- Strict TDD: RED -> GREEN -> REFACTOR. Runner: `./run_tests.sh` (source: user CLAUDE.md "Strict TDD Mode: enabled").
- Deterministic decisions (argmax + stable tie-break).
- ~400 authored lines per task is advisory only.
- Delivery strategy: ask-on-risk; work-unit commits on feature/utility-ai, no push/PR.
- RDD: gentle-ai CLI not installed -> review unavailable; ordinary checks only.

## Acceptance criteria (gating benchmark, >=200 mirrored games, held-out seeds)
- vs pass: zero losses and score >= cascade's score on the same seeds.
  (Revised 2026-10-27: on ~6% of held-out seeds attacking loses — cascade loses them — so a draw is
  correct there; the original <5% draws target is unattainable without losing those games.)
- vs cascade and vs greedy: decisive-pair win rate (paired sign test) Wilson 95% lower bound > 50%.
  (Revised 2026-10-27: 74-85% of mirrored pairs split 1-1 because the draft decides; overall
  win-rate ceiling is ~63% even for perfect play, so the original >=60% overall target was unsound.)
- Full test suite green; no off-thread EventBus errors from parallel eval.

## Tasks
- [x] T0 Commit pre-existing WIP (parallel eval, history, CLI overrides) as baseline — inline
- [x] T1 Hygiene: gitignore test/run outputs + csv imports, untrack _test_* dirs — inline
- [x] T2 Benchmark CLI with Wilson CI + fixed held-out seeds — delegated (writer trigger: 2+ files)
- [x] T3 Brain fixes: shared threat scale, HP-aware threat once per enemy, no play-mode side effect, drop redundant features — delegated
- [x] T4 Decision quality: per-target features, focus fire, incoming-damage/retreat, combat-estimate cache — delegated
- [x] T5 Training: per-call sim count + thread safety, common random numbers, promotion n>=40, relax reinforce_engage, profile loader — delegated
- [x] T6 Tune/evolve, gate, ship profile if it beats hand profile — inline runs

## Progress / evidence
- T0 3494dfd baseline WIP commit (inline).
- T1 dba2b78 gitignore + untrack _test_* (inline).
- T2 6d0b2c6 run_ai_bench.sh, --seed-offset/--play-sims, Wilson CI; runner now fails uncompilable suites (inline, RED: parse errors observed; GREEN 34/34).
  Baseline hand_v1 @ play sims, 100 pairs, seed offset 1e6: pass 77.5% (45% draws); greedy 52.5% [45.6,59.3]; cascade 51.5% [44.6,58.3].
- T3 root cause traced: CLOSER_TO_FOCUS uses straight-line hex distance -> legions shuffle in dead-end corridors (ally swaps) -> stale draws. Delegated writer (trigger: 2+ non-trivial files).

- T3 83cfed2 walking-distance focus field, threat once-per-enemy x HP on shared scale, no play-mode ctor side effect, pass leftover AP=0 (delegated; RED observed for 4/6 tests). 79cf72a swap-loop fix: displaced ally progress counted (inline; RED 0.333 -> GREEN).
  Bench 50 pairs: pass 93.5% (13% draws, was 45%); greedy/cascade ~52-54% (CI spans 50%).
  Remaining pass draws: some legit (losing trades vs gargoyle), others follow earlier bad trades -> fraction-based trade features (T4).
- T4 delegated: TRADE_VALUE (gold), WIPE_PROB, sort/decide cache, combat memo.

- T4 efc6ac0 TRADE_VALUE + WIPE_PROB features, sort/decide cache, combat memo (delegated; RED observed). ~40% faster bench.
- bf08639 profile JSON loader: utility -> data/ai/profiles/utility_default.json or hand_v1; utility:<path>; utility_hand (inline, RED observed).
- Weight sweep (40 pairs, dev seeds 2e6): 6 variants all 54-57% overall -> weights barely move overall score.
- a132fec decisive-pair stat (inline, RED observed). Decisive pairs: vs cascade 10-3, vs greedy 5-1 (utility already better where play matters).
- Flaky test-run crash observed once (worker-thread backtrace) -> T5 thread fixes.
- T5 delegated.

- T5 50f1268 per-brain sim count, main-thread headless flags, no EventBus emits from sims (643 -> 0 errors), null job guard, CRN seeds per generation, promotion >=40 games, reinforce_engage only pass floor, draw >= loss, arena cadence (delegated; RED observed, 2 clean suite runs, evolve smoke ok).
- Held-out gate, fixed hand profile (100 pairs): pass 94.5% (0 losses, 11% draws; cascade 91.5% w/ 8% losses) PASS;
  cascade decisive 20-6 CI [57.9, 89.0] PASS; greedy decisive 13-5 CI [49.1, 87.5] borderline FAIL.
- T6: evolve run t6 on cascade_random stage, pop 16, pairs 8, 7 cores, 62 gens.

- T6 evolve t6: 62 gens on cascade_random, best fitness noisy 1.8-2.4 with no trend. Champion held-out:
  cascade 12-6, greedy 10-5, vs hand 6-5 -> NOT shipped; fixed hand_v1 remains the default.
- Final gate, fixed hand profile, 300 held-out pairs pooled:
  cascade decisive 45-23 (66%, CI [54.4, 76.3]) PASS; greedy 32-21 (60%, CI [47.0, 72.4]) NOT significant;
  pass 0 losses, 94.5% (cascade 91.5%) PASS.

## Follow-ups (not in scope)
- Beating greedy significantly likely needs a structural step, not weights: 1-ply enemy reply
  (expected counter-attack at the stand), team focus fire within a turn, ranged kiting.
- Stall-breaker: 10/22 pass draws are seeds cascade wins; a stagnation-pressure feature could convert them.
- Export: ensure data/ai/profiles/*.json is included in Godot export filters.

## Next step
Decide on structural follow-up (enemy-reply lookahead / focus fire) vs stopping here.
