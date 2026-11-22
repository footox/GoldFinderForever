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

## Tasks

- [ ] T0 write the API contract (S5) and the sync message format (S4) before any code | route: inline | commit: -
- [ ] T1 (S3) addon skeleton, node recorder and merge (`core/` pure + tests) | route: inline | commit: -
- [ ] T2 (S5) public API and its tests | route: inline | commit: -
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
