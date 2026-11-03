#!/usr/bin/env sh
# Held-out gating benchmark for a brain: mirrored duels vs the baseline brains,
# on seeds disjoint from evolve training, with the in-game Monte Carlo sim count.
#
# Usage: ./run_ai_bench.sh [BRAIN] [PAIRS] [OPPONENTS...]
#   BRAIN      brain id under test (default: utility)
#   PAIRS      mirrored seed pairs per opponent (default: 100 -> 200 matches)
#   OPPONENTS  default: curriculum_pass curriculum_greedy cascade
#
# Gate: vs pass >=95% wins and <5% draws; vs greedy/cascade the decisive-pair win CI
# (paired sign test; split 1-1 pairs are decided by the draft) has a lower bound > 50%.
set -eu

ROOT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
cd "$ROOT_DIR"

BRAIN="${1:-utility}"
PAIRS="${2:-100}"
if [ "$#" -gt 2 ]; then
  shift 2
  OPPONENTS="$*"
else
  OPPONENTS="curriculum_pass curriculum_greedy cascade"
fi
SEED_OFFSET="${AI_BENCH_SEED_OFFSET:-1000000}"

for opp in $OPPONENTS; do
  echo "== $BRAIN vs $opp ($PAIRS pairs, seed offset $SEED_OFFSET)"
  ./run_ai_duel.sh --games "$PAIRS" --brain-a "$BRAIN" --brain-b "$opp" \
    --seed-offset "$SEED_OFFSET" --play-sims \
    --out-dir "data/ai_duel/bench_${BRAIN}_vs_${opp}" 2>&1 \
    | grep -E "wins:|pair score|CI|Decisive|turns" || true
done
