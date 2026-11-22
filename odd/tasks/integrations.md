# integrations

Objective: implement as FEATURES the six candidates of the value evaluation of 2026-11-22 (ideas seen in other addons), with our own code.
Branch: feat/guide-integrations (stacked on feat/materials-tab so the game loads everything together) | Delivery: ask-on-risk | Test runner: `lua.exe tests\*.lua` (Lua 5.1) + `luac -p`

## Specs

- S1 Scope and rule. User, 2026-11-22: "Ok, hay que implementarlos como feature." The six candidates, in the ranked order of the evaluation. Each is written from the IDEA with our own code: nothing is copied from addons under another licence (GPL ones, or ones that reserve all rights). Behaviour is learned by describing it in our own words, never with their code open while writing. The licence stays MIT: the evaluation found that none of the six needs copyleft code. No new public text names another addon.
- S2 Trainer marks (T1). In the trainer window, mark which of the listed recipes the player's route or guide uses, so useless recipes are not paid for. It reuses what the addon already reads from the trainer window; it hooks, never replaces, Blizzard frames; no new global frame names without our prefix.
- S3 Buy what the route needs (T2). User's wording of the idea: buy what the current route needs from an open merchant in two clicks, never more than needed. First click shows what and how much it costs; the second buys. Only items the merchant sells and the current step needs, minus what the player already carries; never more than needed; nothing is bought without the click; stacks and limited stock are respected.
- S4 Waylaid Crates (T3). Recognise the crate items; do not advise selling a crate or the materials that fill it (reserve them), and say it serves Favor. The gold-per-Favor ranking window is OUT of this phase.
- S5 Recipe sources table (T4). Where to get recipe items that QuestieDB and the data addon do not know: our own seed table of facts (vendor or drop, zone, coordinates), verified in game with the data addon, as a third source in GF.MergeSourceApis. Facts are free; compiled GPL tables are not copied. MIT sources (AllTheThings) may be used keeping their notice.
- S6 Who already knows a recipe (T5). Among the player's own characters only: say which of them already know the recipe. No messages are sent (the README promises it).
- S7 Search by material in the guide (T6). "What do I use this material for": a search box in the guide that lists the recipes using a material.
- S8 Out of scope: the gold-per-Favor ranking, guild crafters (needs messages), a recipe-browser window, buffs and crafted-gear tabs.
- S10 Optional interface-manager support (T7). User, 2026-11-22: it is "como opcion de feature": something the player can switch on, never imposed. What it covers (skin, registration, frame positions) depends on the manager's extension points and licence, to be evaluated before building anything.
- S9 Verification. Offline tests for every pure part; the pieces that touch Blizzard frames or functions marked "not verified" in the evaluation (trainer frame names, BuyMerchantItem signature, crate tooltip, Favor as a currency) are verified IN GAME with a screenshot before they count as done.

## Tasks

- [x] T1 (S2) trainer marks: a panel next to the trainer window (not marks on Blizzard's rows: the frame structure is not verified); core/trainer_marks.lua, features/trainer/marks.lua | route: inline | commit: GF-129 (offline done; IN-GAME check pending: where the panel falls, that it wraps, that the trainer is recognised)
- [ ] T2 (S3) buy what the route needs | route: inline | commit: - | Risk: item 1 (spends the player's gold: an irreversible effect), so it gets an independent verification before release
- [ ] T3 (S4) Waylaid Crates | route: inline | commit: -
- [ ] T4 (S5) recipe sources table | route: inline | commit: -
- [ ] T5 (S6) who already knows a recipe | route: inline | commit: -
- [ ] T6 (S7) search by material in the guide | route: inline | commit: -

- [ ] T7 (S10) optional support for a popular interface manager (EllesmereUI): to evaluate first | route: inline | commit: -

## Log

- L1 (2026-11-22, user): "Hay que ajustar nuestra licencia?" -> goal: "E integrar esas funcionalidades? que realmente aporten valor?" -> value evaluation done by a read-only analyst, checked by the parent: no candidate needs GPL, licence stays MIT.
- L2 (2026-11-22, user): "Ok, hay que implementarlos como feature."
- L3 (2026-11-22, user): about EllesmereUI becoming a popular interface manager: "quizas podamos dar soporte para integrarnos a el" and "Pero es como opcion de feature" -> candidate T7: optional support for that interface manager, switchable by an option; to be evaluated (its extension points and licence) before any work.
