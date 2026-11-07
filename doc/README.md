# Realmrise Tactics docs

Start here. Everything design-related lives in `doc/`. Agent conventions stay in `/AGENT_NOTES.md`.

| File | What it is | Changes how often |
|------|------------|-------------------|
| [`summary.md`](summary.md) | One-page overview: what the project is, where it stands, what's next | Each milestone |
| [`roadmap.md`](roadmap.md) | **Living board:** bugs, milestones 0.1 → 0.5 and later, needed icons and sounds | Constantly |
| [`open_questions.md`](open_questions.md) | Design and scope decisions that are still open, plus the ones already made | When a decision is made |
| [`codebase.md`](codebase.md) | Architecture map, code review findings, refactor backlog | After big refactors |
| [`design/vision.md`](design/vision.md) | What the final game wants to be; pillars; inspirations | Rarely |
| [`design/combat.md`](design/combat.md) | Current combat and action rules + the full effects catalogue | Each effect added |
| [`design/ai.md`](design/ai.md) | Utility AI direction, parameter optimisation, dev flow per effect | 0.1 |
| [`design/progression.md`](design/progression.md) | Science tree, unit tiers, tech game modes | Pre-economy |
| [`design/economy.md`](design/economy.md) | Capital, builders, buildings, resources, food soft cap | Pre-economy |
| [`design/exploration.md`](design/exploration.md) | Ruins, neutrals, mercenaries, map objects | Pre-economy |
| [`design/modes.md`](design/modes.md) | Skirmish, competitive 1v1 (clock), battle royale / moving factory | Pre-economy |
| [`journal.md`](journal.md) | Your original dated design notes, kept as written (source material) | Append only |
| [`assets_archive.md`](assets_archive.md) | What lives in `assets/_archive/` and why | Rarely |
| [`archive/missions_v0.1.md`](archive/missions_v0.1.md) | The old v0.1 mission board (Epics U/T/P). Mostly done; open items moved to the roadmap | Frozen |

## Conventions

- **Roadmap is the single source of truth for "what next".** Design docs explain *why* and *how*; they don't carry checkboxes.
- Add new raw thoughts to `journal.md` with a date header, then move the decisions into the matching design doc.
- When you decide an open question, move it to the "Decided" section of `open_questions.md` with the date.
