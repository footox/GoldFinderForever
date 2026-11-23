# ah-hub

Objective: an auction-house hub of our own (option A): one window with a side menu whose sections are registered, built as a MODULAR addon system (the way EllesmereUI ships): a core plus modules in separate folders, delivered in ONE package. PLAN ONLY: nothing is built yet.
Branch: one per phase, from develop | Delivery: ask-on-risk | Test runner: `lua.exe tests\*.lua` (Lua 5.1) + `luac -p`

## Specs

- S1 Scope. User, 2026-11-22: "Haz la planeacion de la opcion A" (the full own hub, not only the extra Materials window, which is option B and already exists). The hub reorganises what exists and adds sections; it is not a new auction house.
- S2 Own design. The behaviour is described in our own words; the code of Auction Assistant (all rights reserved) is never opened while writing. Ideas and facts are free, code and data are not copied.
- S3 Phase 0, skeleton and contract. A section registry in GoldFinderForever (`name, icon, builder`) and a side menu that lists the registered sections. No new feature. The registry is the extension point every module uses, so it is designed for modules that are independent of each other: it defines what a section receives (decision, reserves, prices, configuration) and what it offers.
- S4 Phase 1, migrate what exists. Bags, Shopping and Materials become sections of the hub. The separate Materials window stays as an option ("detach"). Risk: those views live inside GoldFinder.lua (about 4700 lines).
- S5 Phase 2, Posting. A section with the posting options that today are in the collapsible side panel (same limits, same saved variables).
- S6 Modules. Each module is a folder of its own that depends on the core and can be switched on or off in the game's addon list; the core works without any of them. The first new module is `GoldFinderForeverAuction` (working name): My auctions and Snipe. User, 2026-11-22: "Si, dejalo asi en el plan", then "Pero solo descargas un paquete".
- S6b One package. All modules travel in ONE CurseForge package with several addon folders (the way EllesmereUI does: only its core has a project id, its modules have none), using `move-folders` in `.pkgmeta`. So the player downloads once and enables what they want. Versions of core and modules move together, which removes the compatibility worry. To be verified with a real package build before any release; nothing is published without the player's yes.
- S7 Companion section "My auctions" (phase 3). List what the player has posted and cancel it. HIGH RISK (irreversible action): confirmation before each cancel, never in bulk without a click, independent verification before it ships.
- S8 Companion section "Snipe" (phase 4; the section name is the English word "Snipe", chosen by the user; each auction found is "a snipe"). A list of auctions priced below the player's reference price. It only tells; it never buys.
- S9 Phase 5, Settings inside the hub, same options and limits as the settings page.
- S10 Auction throttling. Before phases 3 and 4, say "the auction house is busy" when another addon is scanning, instead of waiting until the live price check times out.
- S11 Rules. Offline tests per phase with deliberate breakage of the logic; the real auction-house frames of WoW Forever are verified in game, never assumed from Retail; nothing is pushed until the player has tested it in game.

## Tasks

- [ ] P0 (S3) section registry, contract and side menu | route: inline | commit: -
- [ ] P0b (S6b) one package with several addon folders (`.pkgmeta` move-folders), checked by building the zip | route: inline | commit: -
- [ ] P1 (S4) migrate Bags, Shopping, Materials | route: inline | commit: -
- [ ] P2 (S5) Posting section | route: inline | commit: -
- [ ] P3 (S7, S6) first module GoldFinderForeverAuction and My auctions | route: delegated writer for the addon (own folder) | Risk: item 1 (irreversible cancel) | commit: -
- [ ] P4 (S8, S10) Snipe and the busy-auction notice | route: inline | commit: -
- [ ] P5 (S9) Settings inside the hub | route: inline | commit: -

Recommended order: P0 (core registry and contract), P0b (one package), P3 and P4 as the first real module, then P1 and the separation of Bags, Shopping and Materials one by one and only if it pays off (they share state: the sell-or-keep decision, reserves and prices). P2 and P5 follow.

## Log

- L1 (2026-11-22, user): "Haz la planeacion de la opcion B." then, corrected: "Perdon es la A".
- L2 (2026-11-22, user): "Que podria ser un complemento 'Assits HA' del nuestro Addon, no?" -> answered: yes, fits the pattern of the data addon; the registry of phase 0 is what makes it possible.
- L3 (2026-11-22, user): "Si, dejalo asi en el plan" -> the companion addon takes My auctions and Snipe; the main addon keeps the registry, Bags, Shopping and Materials.
- L4 (2026-11-22, user): "Pero espera, asi lo maneja EllesmereUI?" -> verified in its folder: a core plus 22 addons with `## Dependencies: EllesmereUI`, options loaded on demand, `RegisterPlugin` as extension point. User: "Lo vi como submodulo." and pasted its description: "Modular Addon System: Each component of EllesmereUI is a standalone module, allowing you to enable only what you want".
- L5 (2026-11-22, user): "Pero solo descargas un paquete" -> verified: only the EllesmereUI core has an X-Curse-Project-ID; its modules have none, so they ship together. The cost I had listed (two downloads) does not exist. Decision: modular from the start, one package.
- L6 (2026-11-22, user): "Si, actualiza el plan".
- L7 (2026-11-22, user): "Pero no lo llames Chollos", "Era Snipers?", then "Snipe esta bien, no?" -> the section is named "Snipe" (TradeSkillMaster calls its own tool "Sniper"; ours stays "Snipe" to avoid the confusion).
