# drop-zygor

Objective: remove every dependency on Zygor data (GoldFinderData.lua) and replace each section with own sources.
Branch: `feat/drop-zygor`. Delivery: ask-on-risk. Test runner: none (no Lua test harness); checks are
`luac -p` (Lua 5.1, `C:\Program Files (x86)\Lua\5.1\luac.exe`), offline Lua 5.1 probes of pure logic, and in-game `/reload` + BugGrabber.

## Specs

- S1. User goal (verbatim): "Que la idea es dejar de depender de zygor." GoldFinder must work with no Zygor
  installed and ship no data derived from Zygor guides.
- S2. `steps` (what to craft per skill band) is replaced by the own route planner (Ruta tab), extended with
  recipes the character can still learn from a trainer.
- S3. `levelmats` (materials to keep for levelling) is replaced by the materials the route planner computes.
- S4. `train` (rank trainer per profession, zone, coords) is replaced by `GoldFinderTrainers.lua` (Icy Veins facts).
- S5. `learn` (where to get each recipe): trainer recipes come from the character's trainer (recorded in game);
  vendor recipes come from QuestieDB at runtime when it is installed (`ItemDB.teachesSpell`, `ItemDB.vendors`,
  `NpcDB.name/spawns/zoneID`), otherwise from vendors the player visited. QuestieDB data is never copied into
  GoldFinder (its licence is GPLv3 / partly "all rights reserved"); it is an optional runtime dependency.
- S6. `farm` (where to farm each leather) is replaced by the player's own skinning loot stats per zone.
  Accepted loss: no recommendation until the player has skinned there.
- S7. Discovery (2026-11-20): game client tables do not expose recipe skill requirement nor acquisition source
  (`MinSkillLineRank` is 1 for all; effect 36 is used by trainer and item teach spells alike). Trainer recipe
  requirements and costs are recorded in game from the trainer window (`GetTrainerServiceInfo`,
  `GetTrainerServiceSkillReq`, `GetTrainerServiceCost`).

## Tasks

| ID | Specs | Route | Status | Commit |
|----|-------|-------|--------|--------|
| T1 | S5, S7 | inline | done, in-game check pending | 981becc |
| T2 | S2 | inline | done (offline tests), in-game check pending | see Log L6 |
| T3 | S2, S3 | inline | pending | |
| T4 | S4, S5 | inline | pending | |
| T5 | S6 | inline | pending | |
| T6 | S1 | inline | pending | |

- T1: record trainer offerings per profession (recipe, required skill, cost, trainer, zone) on trainer window open.
- T2: route planner also considers recorded learnable trainer recipes and adds a "learn" step with its cost.
- T3: switch every `levelmats`/`steps` consumer (keep-for-profession advice, next-step tracker, guide window,
  shopping, ready alert) to the route planner output.
- T4: switch `train`/`learn` consumers to GoldFinderTrainers and recorded trainer/vendor recipe data.
- T5: switch `farm` consumers to own loot-per-zone stats.
- T6: remove GoldFinderData.lua from the .toc and repo, purge remaining Zygor references, update Notes/help.

Route evidence: every unit edits the same file (GoldFinder.lua) and depends on the previous one, so no
parallel-writer reason exists; all inline.

## Log

- L1 (2026-11-20, user, verbatim): "Que la idea es dejar de depender de zygor." Then, on the proposed
  per-section replacement plan: "si, arranca".
- L2: GoldFinderData.lua sections and consumers: farm (2 refs), levelmats (5), steps (5), learn (2), train (3)
  in GoldFinder.lua. Its `kill` strings are verbatim Zygor guide text.
- L4 (2026-11-20, user, verbatim): "Pero creo Questies tiene esos datos". Verified in QuestieDB 1.1.3:
  items expose `vendors`, `teachesSpell`, `npcDrops`; NPCs expose `spawns`, `zoneID`, `minLevel/maxLevel`,
  `npcFlags`, `subName`. No recipe skill requirement and no skinning loot. S5 rewritten to use it at runtime.
  T1 stays: trainer skill requirement and cost only exist in the trainer window.
- L5: T1 implemented: `RecordTrainer` on TRAINER_SHOW stores `GoldFinderDB.trainerRecipes[faction][skill][recipe]`
  = { n, req, cost, npc, zone, x, y, seen }; temporarily enables all trainer filters and restores them.
  `luac -p` OK. Pending in-game check.
- L6: T2 implemented: PlanRoute adds recorded trainer recipes the character does not know as candidates,
  usable from their required skill; the learn cost is paid once (amortized per remaining point in the greedy
  choice, added once to the total) and shown as "Aprender X" rows. Offline tests `tests/plan_route_test.lua`
  (7 cases) pass; against the previous commit they fail (`learns` is nil), which is the RED evidence.
- L7 (2026-11-20, user, verbatim, new request, separate from this feature): "Incluso el diseño se que lo hizo
  moderno Cowrok pero me gustaria que se integrase mas natural al diseño clasico de wow".
- L3: Engram mirror pending: the Engram server only resolves project `repository` (its cwd is J:\Repository),
  so `goldfinder` cannot be written yet.
