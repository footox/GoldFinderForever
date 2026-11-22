# keep-list

Objective: a "Guardados" tab (whitelist) that lists every item the player marked with Guardar, so it can be reviewed and released.
Branch: feat/keep-list (from main) | Delivery: ask-on-risk | Test runner: `lua.exe tests\*.lua` (Lua 5.1) + `luac -p`

## Specs

- S1 Request: "Falta la pestaña de whitelist, recuerdo que me dijiste que lo que se va como guardar." (user, 2026-11-22). Assistant check: no earlier mention of a whitelist tab exists in the code, docs or memory; the request is registered as a new feature, as a tab listing what was marked Guardar.
- S2 Data: the list is the set of items with a manual keep (`manual` in the decision, verdict GUARDAR/KEEP). Verify where the per-character pins are stored (GoldFinderDB) before writing; never change the stored keys (no migration).
- S3 UI: a new tab "Guardados" in the main window: one row per item with its icon, name and a Soltar button; empty state text; all text through `GF.L` (enUS + esES).
- S4 Behavior: Soltar removes the manual keep with the same function the Bolsas button uses, then refreshes Bolsas, the vendor panel and the mail panel. Nothing is sold, posted or mailed.
- S5 Scope: per character, as the pins are today; show the character the list belongs to. Optional later: a button to release all.
- S6 Verification: offline test for building the list and releasing an item; in-game `/reload` check.

## Tasks

- [ ] T1 (S2,S4) pure list builder + release helper in `core/` with tests | route: inline | commit: -
- [ ] T2 (S3) tab and rows in `features/` + locale strings | route: inline | commit: -

Risk: item 6 (UI not covered by offline tests; mitigated by in-game `/reload`).

## Log

- L1 (2026-11-22, user): "Falta la pestaña de whitelist, recuerdo que me dijiste que lo que se va como guardar."
- L2 (2026-11-22, user): "Ok, guardala igual como feature" -> registered as its own feature after confirming it means a tab listing the items marked Guardar, with a release option.
