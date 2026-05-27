## Agent notes (project conventions + learnings)

### Workflow
- **Always run unit tests** after code changes: `./run_tests.sh`.
- **Add tests first** when implementing new behavior (especially combat rules / edge cases).
- Prefer **headless, CLI-only** workflows for CI.
- Avoid flaky tests by controlling randomness (seed RNG or force deterministic state).

### Test harness conventions
- Tests live in `res://tests/` and are executed by `tests/run_tests.gd`.
- Test runner must print a clear summary and exit **0 on pass**, **non-zero on fail**.
- Prefer **logic-level unit tests** (no scenes) unless visuals/nodes are required.

### Terrain/spawn/move test constraints
- Spawn/move behavior depends on `Tile.walkable`; tests must not fail due to random terrain.
- In tests, force tiles to a deterministic walkable state (e.g. `terrain_type="GRASS"`, `walkable=true`).

### UI panel requirements + style
- UI must be **scalable/adaptable**: render sections depending on tile contents (initially only legion info).
- Style direction: **simple shapes**, **beige**, **rounded corners**, **thicker borders**, **large text**.
- Panel is **fixed width** and **anchored to the right side**.
- Final behavior: **right-click only** opens the panel; **hover does not trigger** it; panel hides on leaving the tile that opened it.
- Legion units list: **no “Unit 1/2 …” labels**; show **unit image + health bar** per unit.

### Data-driven unit stats
- Use Godot `Resource`-based unit definitions:
  - `UnitDefinition` per unit type (id, display_name, max_health, attack, icon; extend later).
  - `UnitDatabase` holds all definitions and provides lookup.
  - `UnitDefs` autoload provides `UnitDefs.get_def(id)` globally (models + UI + headless tests).
- `Unit` stats come from the DB; keep safe defaults if definition missing.
- Resource loading must work headless; `.tres` should be compatible with script-attached resources.

### Combat logic (current rules)
- Attacking legion **hits first**.
- Each unit **hits at most once per combat**.
- **Deaths are immediate**: dead units are removed and do not hit later.
- Hit order is **alternate-then-drain**:
  - alternate hits between legions while both have eligible attackers;
  - once one side is out of eligible attackers, the other side continues with remaining attackers.
- Print each hit for terminal inspection.
- Combat resolver returns ordered hit/death logs for driving visuals.

### Combat visuals requirements (current)
- Animations are **sequential** with a fixed delay between hits (currently **0.3s**).
- Only the **attacking unit** animates attack and only the **target unit** animates being hit.
- Before combat begins, **both legions face each other**.
- When a unit dies, update the **legion visu immediately** (remove unit visu, re-pack).
- After combat, remaining units should **tween** into their re-packed positions (no snapping).

