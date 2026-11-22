# ah-hub

Objective: an auction-house hub of our own (option A): one window with a side menu whose sections are registered, plus a companion addon for the sections that carry risk. PLAN ONLY: nothing is built yet.
Branch: one per phase, from develop | Delivery: ask-on-risk | Test runner: `lua.exe tests\*.lua` (Lua 5.1) + `luac -p`

## Specs

- S1 Scope. User, 2026-11-22: "Haz la planeacion de la opcion A" (the full own hub, not only the extra Materials window, which is option B and already exists). The hub reorganises what exists and adds sections; it is not a new auction house.
- S2 Own design. The behaviour is described in our own words; the code of Auction Assistant (all rights reserved) is never opened while writing. Ideas and facts are free, code and data are not copied.
- S3 Phase 0, skeleton. A section registry in GoldFinderForever (`name, icon, builder`) and a side menu that lists the registered sections. No new feature. The registry is the extension point the companion addon uses.
- S4 Phase 1, migrate what exists. Bags, Shopping and Materials become sections of the hub. The separate Materials window stays as an option ("detach"). Risk: those views live inside GoldFinder.lua (about 4700 lines).
- S5 Phase 2, Posting. A section with the posting options that today are in the collapsible side panel (same limits, same saved variables).
- S6 Companion addon (working name `GoldFinderForeverAuction`), optional, separate folder and CurseForge project, like GoldFinderForeverData. It registers its sections only when installed and loads nothing when it is not. User, 2026-11-22: "Si, dejalo asi en el plan".
- S7 Companion section "My auctions" (phase 3). List what the player has posted and cancel it. HIGH RISK (irreversible action): confirmation before each cancel, never in bulk without a click, independent verification before it ships.
- S8 Companion section "Snipes" (phase 4; the user wants the English word). A list of auctions priced below the player's reference price. It only tells; it never buys.
- S9 Phase 5, Settings inside the hub, same options and limits as the settings page.
- S10 Auction throttling. Before phases 3 and 4, say "the auction house is busy" when another addon is scanning, instead of waiting until the live price check times out.
- S11 Rules. Offline tests per phase with deliberate breakage of the logic; the real auction-house frames of WoW Forever are verified in game, never assumed from Retail; nothing is pushed until the player has tested it in game.

## Tasks

- [ ] P0 (S3) section registry and side menu | route: inline | commit: -
- [ ] P1 (S4) migrate Bags, Shopping, Materials | route: inline | commit: -
- [ ] P2 (S5) Posting section | route: inline | commit: -
- [ ] P3 (S7, S6) companion addon and My auctions | route: delegated writer for the addon (own folder) | Risk: item 1 (irreversible cancel) | commit: -
- [ ] P4 (S8, S10) Snipes and the busy-auction notice | route: inline | commit: -
- [ ] P5 (S9) Settings inside the hub | route: inline | commit: -

Recommended order: P0 and P1 first (they change the structure and add no money risk); decide P3 and P4 after seeing them.

## Log

- L1 (2026-11-22, user): "Haz la planeacion de la opcion B." then, corrected: "Perdon es la A".
- L2 (2026-11-22, user): "Que podria ser un complemento 'Assits HA' del nuestro Addon, no?" -> answered: yes, fits the pattern of the data addon; the registry of phase 0 is what makes it possible.
- L3 (2026-11-22, user): "Si, dejalo asi en el plan" -> the companion addon takes My auctions and Snipes; the main addon keeps the registry, Bags, Shopping and Materials.
