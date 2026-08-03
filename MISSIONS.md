# FableQuest missions

Living checklist. Update as items are done; keep **short-term** small and shippable.  
You own git — agents should not commit unless you ask.

---

## Status snapshot

**Done recently**
- Engine vs modes refactor; shared battle host wiring; asset archive; icon batch (`range` / `size` wired).
- Combat basics: melee, ranged, self-heal, shield, terminal vs non-terminal AP.

**Next focus (order)**
1. **UX foundations** — general tooltips, then a left-side **action log** (before stacking more skills).  
2. **Tactical skill variety** — ally heal → cooldowns/teleport → terrain → statuses → more actions.  
3. **Unit complexity tiers** — teach the player; gate complicated kits via missions/unlocks later.

**Parked**
- Full SFX content pass.
- Manual smoke (see below).
- Optional delete of `assets/_archive/` piles.

---

## Short-term missions

### Done
- [x] Refactor slices A–E; missions board; music → `assets/music/`
- [x] Range + size icons from batch3

### Still open (your side)
- [ ] Manual smoke — report ok / what failed (see below)
- [ ] Later: approve delete list from `assets/_archive/`

---

## How manual smoke works

1. **1-hex move re-highlight** — select → move adjacent → new tile keeps selection + highlights.  
2. **Attack-choice popup** — melee+ranged same enemy → sword/bow popup; outside click dismisses.  
3. **Wipe-tile ally** (optional) — ally on vacated waited tile can still act.

Reply e.g. `smoke: 1 ok, 2 ok, 3 skipped`.

---

## Epic U — UX foundations (do before more skills)

New actions will fail if players can’t **discover** what they do. Right-click already inspects tiles/units; generalize that into a **tooltip system**, then tighten the action bar / panel so numbers aren’t a wall.

### Design: per-unit action parameters (without UX hell)

**Problem:** Heal range, teleport CD, ability damage differ per unit — but we don’t want a spreadsheet on screen.

**Approach — “shared verb, unit overrides, progressive disclosure”**

1. **One action id per verb** (`heal_ally`, `teleport`, …) with **defaults** on `ActionDefinition` (base range, base heal, base CD).  
2. **Unit overrides** on `UnitDefinition` (small dict or typed fields), e.g. `action_params: { "heal_ally": { "range": 2, "heal": 4 } }`. Resolver/targeting always: `unit override ?? action default`.  
3. **UI shows almost no raw numbers by default** — icon + short name on the bar.  
4. **Details live in tooltips** (right-click or long-press): 2–4 lines max, plain language.  
   - Good: “Heal an ally within 2 hexes. Ends this legion’s turn.”  
   - Bad: “PWR 4 RNG 2 CD 0 TERM 1 AP 1 HEAL_MODE STACK…”  
5. **Keywords** (`Terminal`, `Cooldown`, `Through mountains?`) are short tags; right-click a keyword for a one-liner definition (shared glossary).  
6. Optional later: **simple / detailed** inspect mode — beginners see flavor + effect sentence; advanced shows the few numbers.

Do **not** invent a separate action resource per unit tier (`heal_ally_mage_r2`) unless the verb itself changes — that explodes content and AI.

### Design: unit complexity tiers

| Tier | Kit | When the player meets them |
|------|-----|----------------------------|
| **I — Basic** | Move, melee (maybe self-heal). One job. | Tutorial / first missions |
| **II — Specialty** | + ranged **or** shield **or** one simple skill (ally heal). | Early campaign |
| **III — Tactical** | Cooldown skill (teleport), terrain-aware kit, 1 status. | Mid |
| **IV — Complex** | Multi-skill mage-style; buffs/debuffs; keywords matter. | Late / optional unlocks |

- Draft UI / unit picker can show a **complexity pip** (I–IV), not a stat dump.  
- Missions unlock tiers so the learning curve is paced.  
- Same engine for all tiers — only `action_ids` + overrides + presentation differ.

### Phase U1 — General tooltip component

Reusable popup (not unit-panel-only):

- [x] `TooltipPopup` / presenter: title, body (rich text or labeled lines), optional icon, keyword chips  
- [x] **Right-click** (and optional hover-delay later) on: action bar buttons, stat icons, keywords, terrain, statuses  
- [x] Shared **glossary** resource (`Terminal`, `Cooldown`, `LOS`, `Forest cover`, …)  
- [x] Anchor near cursor / control; click-outside or second right-click dismisses (match attack-choice feel)  
- [x] Hook action bar + tile info stats first; units keep current panel but can open glossary from keywords  
- [x] Headless: glossary lookup + “params resolve” helper tests (no scene required for logic)

### Phase U1b — Battle action log (Hearthstone-style)

Ship early so every new feature emits a clear, modular event the UI can render — not a one-off print to stdout.

**UX**
- Fixed strip on the **left** of the battle UI (scrollable).
- Newest entry at the bottom (or top — pick one and stick to it; recommend **newest at bottom**, auto-scroll).
- Each line: **caster** → **action** → **target** (if any) → **short result** (e.g. “healed 4”, “hit for 3”, “moved”, “teleported”, “waited”).
- Optional: small icons (unit portrait / action icon); click/right-click entry to inspect via tooltip (U1).
- Hide or collapse in draft; show in battle (+ optional sandbox).

**Engine contract (modular)**
- [x] Structured log entries from the session/resolver path (not only `print`):  
  `{ turn, team, action_id, from, to, caster_summary, target_summary, result_summary, payload? }`  
- [x] Append on successful `use_action` / pass / end_turn / combat resolution (one entry per player-facing beat; combat can be one summary line or expand later).  
- [x] Cap length (e.g. last 50–100) so memory stays bounded.  
- [x] EventBus or session callback so UI/AI/tests subscribe without coupling to `CombatResolver` prints.  
- [x] Headless tests: apply move/attack/heal → log contains expected fields.

**Why before ally heal**
- New skills only need to fill the same entry shape.  
- Debugging and teaching (“what just happened?”) stay consistent as tactics grow.

### Phase U2 — Action bar clarity

- [ ] Disabled reason in tooltip (“On cooldown: 1 turn”, “No wounded ally in range”)  
- [ ] Cooldown badge when T2 exists  
- [ ] Terminal actions: small skull/end-turn mark **or** only in tooltip (prefer tooltip-first to avoid clutter)  
- [ ] Selected action: one-line hint under bar (“Choose a wounded ally”)

### Phase U3 — Tile / terrain / draft UX

- [ ] Right-click empty tile → terrain name + effects (once T3 exists)  
- [ ] Draft picker: tier pip + 1-line role (“Healer”, “Frontline”) via tooltip  
- [ ] Consistent right-click language everywhere: “Inspect”

### Phase U4 — Other UX improvements (backlog)

- [ ] **Confirm dangerous terminal** optional (first time / settings)  
- [ ] **Ghost preview** on hover target (heal amount estimate, damage band — keep fuzzy: “strong / weak”)  
- [ ] **AP / turn strip** always visible: remaining AP on selected legion  
- [ ] **Keyboard hints** in tooltip footer (Tab cycle, Space wait)  
- [ ] **Colorblind-safe** overlays (icons + patterns, not only red/green)  
- [ ] **Undo last action** (sandbox / optional) — huge for learning  
- [ ] **Battle log** — see **U1b** (primary); keep this as “polish depth” only if needed (filters, export)
- [ ] **First-time coach marks** when a new keyword appears (“This action is Terminal”)  
- [ ] Minimap / turn order list when multi-legion gets busy  

---

## Epic: Tactical actions, terrain & status effects

Units are still too similar. Shield + ranged help; we need **asymmetric actions**, **terrain**, **buffs/debuffs**. Prefer shipping **U1 tooltips** before or with the first new action so heal/teleport are teachable.

### Design pillars
- Actions data-driven (`ActionDefinition` + targeting + resolver + playback).  
- Per-unit **param overrides**, not duplicate action ids.  
- Terminal vs AP-only explicit; cooldowns first-class.  
- Terrain / visibility in shared targeting helpers (AI + UI).  
- Headless tests per action before juice.

---

### Phase T1 — Ally heal (`heal_ally`)

| Spec | Choice |
|------|--------|
| Targeting | Allied legion in range (`ALLY_IN_RANGE`) |
| Params | Default range/heal on action; **overrides per unit** |
| Effect | Heal units in target legion |
| Cost | Terminal |
| Visual | Bandage projectile → heal FX |
| UX | Tooltip explains range/heal in words; bar stays clean |

Checklist:
- [ ] Param-resolve helper (`override ?? default`) used by targeting/resolver  
- [ ] `heal_ally` def + targeting + resolver  
- [ ] Playback: bandage projectile  
- [ ] Assign to support units (Mage / …) with tier II+  
- [ ] Tooltips for action (depends on U1)  
- [ ] Tests: heal, invalid targets, terminal wait, override range

---

### Phase T2 — Action cooldowns + teleport

**Cooldowns**
- [ ] Per-legion cooldown map; tick on team turn start  
- [ ] `can_use` + action-bar badge + tooltip “Ready in N turns”  
- [ ] Tests

**Teleport**
- Visible empty walkable tiles (fog later); recommend terminal + 1-turn CD (overridable per unit).  
- Exit/appear VFX.  
- Checklist: action, CD, visu, tests.

---

### Phase T3 — Terrain tactics

| Terrain | Move | Ranged / thrown | Other |
|---------|------|-----------------|-------|
| Mountain | Blocked | **Blocks LOS** | — |
| Water | Blocked | Open | — |
| Forest | OK | Open (or soft block — decide) | **+defense** |
| Desert / Grass | OK | Open | Baseline / later spice |

- [ ] LOS helper; apply to ranged + heal_ally  
- [ ] Forest DR in combat  
- [ ] Terrain tooltip (U3)  
- [ ] Tests

---

### Phase T4 — Buffs & debuffs

- [ ] Status model, tick, modifiers, icons, glossary entries  
- [ ] Tests

---

### Phase T5 — More special actions

Push, poison DoT, guard, root first; then charge, cleave, pierce, execute, cleanse, rally, smoke, channel.  
Assign by **tier** so Basic units stay readable.

---

### Suggested build order

1. **U1 Tooltip component** (+ glossary)  
2. **U1b Battle action log** (left strip + structured session events)  
3. **T1 Ally heal** (param overrides + tooltips + log lines)  
4. **U2 Action bar clarity** (as cooldowns arrive)  
5. **T2 Cooldowns → teleport**  
6. **T3 Terrain** + **U3** terrain inspect  
7. **T4 Statuses** → **T5** more skills  
8. Fog of war; unit unlocks by tier in campaign  

---

## Other next features

1. SFX content pass  
2. Pluggable AI (uses new actions)  
3. Fog / visibility  
4. More units from `done/` art (tier-labeled)  
5. Second mode, campaign unlocks by tier, persistence, balance UI  

### Stretch
- Battle music from archive  
- CI on `./run_tests.sh`  
- Undo / battle log (also listed under U4)

---

## How to use this board

- **UX epic before dumping skills** — tooltips, then action log, then new verbs.  
- Short-term stays smoke / tiny fixes.  
- Engine-first + tests; numbers live in data + tooltips, not on the permanent HUD.
