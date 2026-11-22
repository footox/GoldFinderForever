# modular-split

Objective: evaluate splitting GoldFinder into a small core plus optional modules, the way the EllesmereUI suite is built, so users load only what they use. This is an evaluation, not a committed change.

## Specs

- S1 Prompt: "Por ejemplo, el addon de Ellesmere divide por subcategorias" (user, 2026-11-22), after the discussion of keeping addons light ("para no sobrecargar este").
- S2 What was observed (the user's own install, 2026-11-22): EllesmereUI is a base addon (33 MB) plus 22 small modules (about 0.5-1 MB each: Bags, Chat, ActionBars...). Each module declares `## Dependencies: EllesmereUI`; its options module also uses `## LoadOnDemand: 1`.
- S3 Current GoldFinder (measured 2026-11-22): 40 files, about 828 KB, roughly 12.5k lines; GoldFinderRecipes.lua alone is 348 KB. The code is already organised in `core/`, `adapters/`, `features/` and `ui/` folders.
- S4 Candidate modules (to evaluate, not decided): a core (decisions, prices, locale, window), Auction (post, tab, side panel, scan progress, shopping lists), Professions and guide (recipes, routes, guide, tracker), Mail and bank (panels). Data files (recipes, guides, routes) could ship with the module that uses them.
- S5 Costs to weigh: a shared API between modules, several folders in one zip (one CurseForge project can ship several addon folders), more load-order rules, more support surface, and a one-time refactor with the same in-game validation as every other change. Benefit to weigh: lower memory and load time for users who skip a module, and features that can be switched off by not installing them.
- S6 Decision rule: split only if a measured benefit (memory or load time) or a user request justifies the refactor. Measure first: addon memory per feature with `UpdateAddOnMemoryUsage` in game.

## Tasks

- [ ] T1 measure the in-game memory and load time of GoldFinder today (S6) | route: inline | commit: -
- [ ] T2 sketch the module boundaries and the shared API if T1 shows a benefit | route: inline | commit: -

## Log

- L1 (2026-11-22, user): "Por ejemplo, el addon de Ellesmere divide por subcategorias"
- L2 (2026-11-22, user): "si" -> recorded as a separate evaluation; nothing changes now. The separate points-of-interest addon (gather-db) already follows this pattern.
