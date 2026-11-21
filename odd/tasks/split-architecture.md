# split-architecture

Objective: split GoldFinder.lua (7.3k lines, 129 of 190 file-level locals shared across sections) into a light hexagonal layout with feature folders, with safe, robust code. Behavior must not change.
Branch: refactor/split-architecture | Delivery: ask-on-risk | Test runner: `lua.exe tests\*.lua` (Lua 5.1) + `luac -p`

## Specs

- S1 Layout: `core/` pure domain (decision, route planner, pricing; no WoW globals, dependencies injected), `adapters/` (WoW API with fallbacks, Auctionator, QuestieDB, TSM, SkillUp Forever), `features/` (vendor, auction, mail, professions, guide; each with its container), `ui/` (presentational components, no logic), `data/` (Recipes, Routes, Guides, Trainers). Shared namespace via `local _, GF = ...`; load order lives in the .toc.
- S2 Safe code: every WoW/third-party API call goes through an adapter with a nil-safe fallback (pattern: GF-10 `MerchantItemInfo`); `pcall` at event, hook and UI-callback boundaries so one failure never breaks the rest; SavedVariables input is validated and migrated, never trusted; no new globals (frames keep the `GoldFinder` prefix); no taint of secure frames or protected actions; the existing guarantee stays: "Nada se vende ni se publica sin tu clic".
- S3 No behavior change: same UI, commands, SavedVariables keys and options; the offline suites keep passing, updated to the new paths, never weakened.
- S4 Verification per slice: `luac -p` on every file, all `tests/*.lua`, `wow_lua_lint` (0 errors, no new warnings), `wow_toc_validate`, and the user's `/reload` in game.
- S6 Localization: full enUS support next to the current Spanish. `locales/` holds `enUS.lua` (base and fallback) and `esES.lua`/`esMX.lua`; the locale comes from `GetLocale()` with an option to override; every user-facing string goes through one lookup (`GF.L[key]`) with enUS fallback, never hard-coded in features or ui. Internal tokens (verdicts VENDOR/AH/KEEP, SavedVariables keys) stay language-neutral. Slash commands keep the Spanish ones (`/gf guia`, `/gf ajustes`, `/gf ruta`, `/gf tope`) and gain English aliases (`/gf guide`, `/gf options`, `/gf route`, `/gf cap`). Layout must cope with longer English text. Language option in Options: Automatic / English / Español (default Automatic; new SavedVariables key only). Lookups by game data use IDs, never localized names.
- S5 Delivery: one reviewable commit per slice (about 400 authored lines), commit subject `GF-N - task`; push/PR stay the user's decision.

## Tasks

- [x] T1 (S1,S2) Namespace + `core/` utilities (Print, Money, ShortMoney, Cfg, Char) | route: inline | commit: GF-15 (in-game /reload OK)
- [x] T2 (S2) `adapters/wow.lua`: merchant, bags, quests, spells, addons with fallbacks and pcall helper | route: inline | commit: GF-16 (in-game /reload OK; write actions PickupContainerItem/UseContainerItem and quest/auction adapters move with their features)
- [x] T3 (S1,S3) Decision logic to `core/decision.lua` | route: inline + quest need (core/quest_need.lua, adapters/quests.lua) | commit: GF-17 (in-game /reload OK)
- [x] T4 (S1,S3) Route planner to `core/routeplanner.lua` | route: inline | commit: GF-18 (in-game /reload pending)
- [ ] T5 (S1) Features one by one: vendor, mail, auction, professions, guide (each its own commit) | route: inline | commit: -
- [ ] T6 (S1) `ui/` presentational components | route: inline | commit: -
- [ ] T7 (S6) Localization: `locales/` + `GF.L`, extract all Spanish strings, enUS base, command aliases, language option | route: inline | commit: -
- [ ] T8 (S3,S4) Update tests to new paths and add locale tests, final lint, TOC, README/CHANGELOG, package | route: inline | commit: -

Risk: item 6 (UI is not covered by offline tests); mitigated by the in-game `/reload` per slice.

## Log

- L1 (2026-11-21, user): "Puedes validar si hay mejoras que realizar en el adddon" -> chose item 4 of the list: "La 4" (split GoldFinder.lua).
- L2 (2026-11-21, user): "Imagino, se puede implementar un patron de arquitectura."
- L3 (2026-11-21, user): "ASi como codigo seguro etc."
- L4 Analysis: 190 top-level locals, 129 used outside their own section (Cfg and Char in 19 sections each, Print and Money in 11); 17 tests extract code from GoldFinder.lua by text markers. Engram mirror `odd/split-architecture/tasks`: pending.
- L5 (2026-11-21, user): "Asi como el soporte de Ingles US" -> added S6 and T7 (localization); Spanish stays supported. After release, update the CurseForge description line "The interface is in Spanish" and the .toc Notes.
