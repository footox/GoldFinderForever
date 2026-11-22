# gather-db

Objective: a separate data addon that records points of interest (ore veins, herbs and others) from what players gather, merges them, shares them between players in the game, and exposes them to GoldFinder (and any other addon) through a small stable API.
Branch / repository: a NEW addon with its own project and versions (name to decide); GoldFinder only consumes it as an optional dependency | Delivery: ask-on-risk | Test runner: `lua.exe tests\*.lua` (Lua 5.1) + `luac -p`

## Specs

- S1 Request: "con eso si podemos ir haciendo nuestra base de datos por ejemplo de menas, plantas, y otros puntos de interes." and "Se crea un addon de bd y este comparte entre ellos,no?" and "O seria un addon nuevo para no sobrecargar este." (user, 2026-11-22).
- S2 Separate addon, optional for GoldFinder: the data addon records, merges and shares; GoldFinder lists it under `OptionalDeps` and, when present, reads it through the API, exactly like QuestieDB today. Without it nothing in GoldFinder changes. Reason (measured 2026-11-22): GoldFinder is 828 KB in 40 files; a node database plus continuous recording and syncing would add memory and background work that not every GoldFinder user wants.
- S3 Recording: on a successful gather (Mining, Herbalism, and later others) the addon stores node type, item, zone and map position (`C_Map.GetPlayerMapPosition`; verify that it works where nodes are gathered in the Forever client). Nearby points of the same type are merged into one (a distance threshold), so the store does not fill with duplicates.
- S4 Sharing: reuses the in-game addon-message channel designed in `share-prices` (opt-in, trust list, validation, rate limits). Only new or changed points are sent (a delta), with a cap per minute, because a node map is thousands of points and the messages are small. The sync protocol is versioned from day one.
- S5 Public API: a small, documented, stable table, for example `GetNodes(zone, type)`, `GetNearest(type, x, y)` and a change subscription. Anything else is internal. The API is designed and written down before the code, because other addons would depend on it.
- S6 Data origin and licence: only points recorded by the players of this addon (and shared by them). Nothing is copied from GatherMate2, Questie or any other database. Reading another installed addon's data through its public API may be offered later as an option.
- S7 Use in GoldFinder: the guide's gathering steps show "places you or your friends have found" next to the zone text. Map pins are a separate, later piece of work and are NOT part of the first version.
- S8 Verification: offline tests for merging, distance threshold, delta building, validation of received points and API results; in-game tests with two clients following a checklist under `odd/validation/`.
- S9 Scope against existing addons (2026-11-22): GatherMate2 already covers herb, mining and timber nodes for WoW Forever, with a separate GatherMate2_Data addon (user reports and the project pages; coverage may still be thin). This addon does NOT record those nodes a second time: when GatherMate2 is installed it reads them through its public interface (to verify: which functions it offers and that its data is readable in Forever); without it, node recording stays off. What this addon records and shares itself are the point types nobody else offers: trainers and vendors, where recipe items are sold or dropped, fishing spots and any point GoldFinder's guide needs. The name "gather-db" is kept for this spec; the addon's own name should say "points of interest".
- S10 Using the data: "Y poder utilizarla." (user, 2026-11-22). Two ways. For other addons, GoldFinder first: the public API of S5. For the player, in the game: a simple command to query the base by type and zone (for example `/poi near` for the closest points, or `/poi where <item>` for where something is sold or dropped), printing a short list in the chat. Map pins stay a later phase and are not promised. Export of the player's own recorded points as text is a possible later addition.

## Tasks

- [x] T0 write the API contract (S5) and the sync message format (S4) before any code | route: delegated to a peer session | commit: POI-1 (J:\Repository\poi-db)
- [x] T1 (S3, pure part) skeleton and pure core: model, merge, protocol parse/encode, deltas, rate limiter, queries; 348 checks pass (reviewed 2026-11-22) | route: delegated to a peer session | commit: POI-2..POI-7 in J:\Repository\poi-db
- [ ] T2 (S5,S10) public API, the player's query command and their tests | route: inline | commit: -
- [ ] T3 (S4) sharing over the `share-prices` channel, with deltas and limits | route: inline | commit: -
- [ ] T4 (S7) GoldFinder reads the API and shows the found places in the guide | route: inline | commit: -
- [ ] T5 (S8) in-game validation with two clients | route: inline | commit: -

Order: this starts after GoldFinder's current in-game validation and after `share-prices` is built and tested, because T3 reuses its channel and limits.

Risk: item 3 (a public API others would depend on, and a message format between clients), item 5 (a new project to build, package and publish) and item 6 for everything that touches the game.

## Log

- L1 (2026-11-22, user): "Entonces, con eso si podemos ir haciendo nuestra base de datos por ejemplo de menas, plantas, y otros puntos de interes."
- L2 (2026-11-22, user): "Se crea un addon de bd y este comparte entre ellos,no?"
- L3 (2026-11-22, user): "O seria un addon nuevo para no sobrecargar este." -> decision: a separate addon from the start (assistant had first suggested a module inside GoldFinder to extract later; the user's reason about load and optionality wins).
- L4 (2026-11-22, user): "Sí, anótala y seguimos con la validación" -> registered as a spec; work starts after the current validation and share-prices.
- L5 (2026-11-22, user): "Pero seria bueno tener un addon solo para la bd" -> kept as a separate addon; scope set by S9 so it adds what GatherMate2 does not and reads its nodes instead of duplicating them.
- L6 (2026-11-22, user): "Y poder utilizarla." -> added S10: usable by other addons through the API and by the player through a simple in-game query command; pins later.
- L7 (2026-11-22): T0 and the pure part of T1 delivered by a peer session in J:\Repository\poi-db, independently re-run: 348 PASS, 0 FAIL, luac clean, GoldFinder untouched. T2a (SavedVariables, global API table, /poi command, with fakes) assigned; event recorders (T2b) and sharing (T3) not started.
