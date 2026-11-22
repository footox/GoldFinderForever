# rename-2-3-0

Objective: release 2.3.0 with GoldFinder renamed so it can coexist with any other addon that happens to use the same folder name, keeping the data of everyone who already has 2.2.x.
Branch: feat/rename-2-3-0 (from main) | Delivery: ask-on-risk | Test runner: `lua.exe tests\*.lua` (Lua 5.1) + `luac -p`

## Specs

- S1 Problem (verified 2026-11-22): another published addon uses the same folder name `GoldFinder`, the same SavedVariables `GoldFinderDB`, and registers the same SlashCmdList key `GOLDFINDER` with `/gf`. Installed together, one of them fails or corrupts the other's data.
- S2 Decision (2026-11-22, user): "No creo, vamos por la 2.3.0" -> the rename ships in 2.3.0, not in a 3.0. No contact with anyone: "No, no nos interesa comunicarnos con ellos."
- S3 New names (confirmed by the user 2026-11-22: "Si si" / "Y si esta bien GoldFinderForeverDB"): folder and TOC `GoldFinderForever` (Title stays "GoldFinder Forever"); SavedVariables `GoldFinderForeverDB`; SlashCmdList key `GOLDFINDERFOREVER`; primary command `/gff`; `/gf` is kept only if no other addon already registered it (same "never take over a name" rule as the data addon). The CurseForge project (ID 1820519) stays.
- S4 Data migration (CORRECTED 2026-11-22, verified in WTF/Account/*/SavedVariables: the game keeps ONE file per addon folder, e.g. Auctionator.lua, so a renamed addon cannot read the old file; and declaring `GoldFinderDB` in the new toc would make our file overwrite another addon's variable of that name): the in-game path works only while the old copy is still loaded in the same session; otherwise `tools/migrate_savedvars.py` copies GoldFinder.lua to GoldFinderForever.lua once (dry run by default, never overwrites, only files with our structure). The original text follows. on the first load of 2.3.0, if `GoldFinderForeverDB` is empty and a `GoldFinderDB` exists that is OURS, copy it, keep the original untouched, and mark the migration done. "Ours" is decided by our own schema markers, never by the name alone, because a different addon can write a different structure into the same name: the check must reject foreign data. A copy never overwrites existing new data. Tested with fixtures of both shapes, with corrupt data and with an empty one.
- S5 Old copy still installed: updating through a manager may leave the old `GoldFinder` folder next to the new one. 2.3.0 must detect our own old copy being loaded (our globals such as `GoldFinderRecipes` exist while the new addon loads) and tell the player once, in chat, to delete the old `GoldFinder` folder. It must not disable or overwrite anything on its own. Do NOT ship a stub folder named `GoldFinder`: players who run the other addon would have it overwritten.
- S6 Global names and hooks: audit every global the addon creates (frame names, tables, slash globals) and the Blizzard functions it hooks, against the other addon's, and rename the ones that collide. Frames and tables that are ours alone (`GoldFinderRecipes`, `GoldFinderGuides`...) are renamed only if they collide.
- S7 Data suite: the data addons keep their names (`GoldFinderData`, `GoldFinderDataRecorder`, `GoldFinderDataSync`; no collision, nothing of theirs uses them). If the user wants them renamed to match the new main name, it is a separate decision.
- S8 Docs and release: README, CHANGELOG ("Changes: the addon folder is now GoldFinderForever; your data is migrated automatically; the command is /gff; delete the old GoldFinder folder if it is still there") and the CurseForge description. DO NOT MENTION ANY OTHER ADDON by name anywhere public (changelog, description, README, chat messages, comments): decision of the user, 2026-11-22, "No hay que mencionar el otro addon". The chat warning of S5 speaks only about OUR old copy. Release follows the `curseforge-addon-release` skill, with the code review of everything since 2.2.1.
- S9 Verification: offline tests for the migration (ours, theirs, empty, corrupt, already migrated), the old-copy detection and the slash guard; then in-game: update from 2.2.1 with real saved data, check that the data is intact, that the old folder warning appears, and that both commands work.

## Tasks

- [x] T1 (S3,S6) collision audit and the rename of folder, TOC, SavedVariables, slash | route: inline | commit: GF-104 (audit: the only colliding runtime name was the minimap broker object; frame names do not collide; the Auctionator caller id and shopping list names stay as they are so existing lists keep updating)
- [x] T2 (S4) migration module `core/migrate.lua` with tests | route: inline | commit: GF-104 (tests/migrate_test.lua; two mutants of the module were caught)
- [x] T3 (S5) old-copy detection and the one-time warning | route: inline | commit: GF-104 (detected by our project id in the old folder's toc, never by name; flag oldCopyWarned)
- [ ] T4 (S8) docs, changelog, build and zip (folder name in the zip) | route: inline | commit: -
- [ ] T5 (S9) in-game validation from a real 2.2.1 install | route: inline | commit: -

Risk: item 1 (a change of where persisted data lives: a migration bug loses or mixes users' data), item 3 (the slash command and the folder name that users type and keep) and item 5 (delivery through managers that may leave the old folder). Build and test the migration before touching anything else; keep the original `GoldFinderDB` untouched so it can be recovered.

## Log

- L1 (2026-11-22, user): "Me interesa revisar el codigo y ver que podemos utilizar." -> reviewed the other addon (MIT); collision confirmed.
- L2 (2026-11-22, user): "No, no nos interesa comunicarnos con ellos." (no contact) and "No creo, vamos por la 2.3.0" -> rename in 2.3.0.
- L3 (2026-11-22, user): "No hay que mencionar el otro addon" -> no public text names it; this spec no longer names its author or project either.
- L4 (2026-11-22): names confirmed. NOTE for T5: the addon folder on disk is still `GoldFinder` (it is this git repo) and now has `GoldFinderForever.toc`, so the game no longer loads it from there; in-game validation needs the built zip unpacked as `GoldFinderForever` and the dev folder moved out of AddOns.
- L5 (2026-11-22): found that S4 as first written could not work for players who already deleted the old folder (one SavedVariables file per addon). Fixed: toc declares only GoldFinderForeverDB; tool + README/CHANGELOG instructions added. A player who updates with an app that removes the old folder loses the data unless they copy the file: say so in the release notes to the user.
- L6 (2026-11-22, user): "Como hay poco, es mejor utilizar otro nombre" and, about the saved data, "Si justo que se reinicie" -> NO migration: saved data starts fresh. S4 and S5 are DROPPED (module, tool and notices removed in GF-107; only the /gf guard stays in core/slash.lua). The folder/variable/command names stay provisional (GoldFinderForever, GoldFinderForeverDB, /gff) until the user gives the final name.
- L7 (2026-11-22, user): "Si el que gff y su adecuacion" -> the names are FINAL: GoldFinderForever, GoldFinderForeverDB, /gff (+ /gf only if free). Next: T5 in-game validation (needs the dev folder renamed to GoldFinderForever, game closed).
