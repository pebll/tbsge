# Game modes

## 1. Skirmish (current, polished in 0.5)

- Draft legions with a gold budget onto deploy slots, then fight until one side has no units left.
- Pure tactics; good for competitive "tactics only" matches.
- Weakness: you can't react to the opponent's army after the draft. 0.5 ideas: pick 1 of 3, or draft from a random set of legions.
- Implemented: Vs AI / hotseat / AI vs AI, setup → draft → battle → win/lose → rematch.

## 2. Economy mode (1v1 competitive target)

- One capital each (the "king"), production, builders, map economy, science tree, food soft cap (see `economy.md`, `progression.md`, `exploration.md`).
- Rush vs economy should be a real choice (MTG-like).
- **Online play is realistically 1v1**: turns are sequential, so you wait out the opponent's turn. Matches should be fast (chess / SAP pace).

### Clock (proposal)
- Chess-style with a delay: e.g. **3 min bank, 30 s delay per turn, +10 s increment**. Long turns are possible; you're never forced to blitz.
- **"Your turn: tactics, their turn: economy."** You can manage the science tree and production queue during the opponent's turn, so the game feels more simultaneous.
  - Engine impact: economy commands must be accepted out of turn without affecting the board state the opponent is acting on (or applied at your turn start). Decide which.

## 3. Battle royale / Hunger Games (experimental)

**Problem:** in free-for-all without diplomacy, the player who watches two others fight wins. There's no incentive to fight.

**Candidate fixes:**
- Lots of valuable map objects → expanding pays off → contested points create conflict. Turtling gets out-scaled.
- **Walking factory**: each player's capital is a mobile factory-city (capital + production + economy + tech) that moves ~1 hex/turn. Combined with **crumbling tiles / a shrinking zone**, this forces movement, and exploration doesn't mean abandoning the base.
  - Tech tree merges unit unlocks with factory upgrades (HP, gold, science, food, a bit of attack).
  - The factory can defend itself a little but must not become a real combat unit.

**Tension to resolve:** the walking factory contradicts the "ring your capital with farms" economy of mode 2. They might simply be different modes; don't build one engine path that has to serve both early on. See `open_questions.md`.
