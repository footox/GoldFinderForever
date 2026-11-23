# gear-variants

Objective: price equipment by its own variant (random suffix, item level) everywhere the addon reads an auction price, not only in the sell-or-keep advice. Phase 1 (GF-144, GF-146) is done; the points below are the backlog agreed for a later version.
Branch: one per point, from develop | Test runner: `lua.exe tests\*.lua` (Lua 5.1) + `luac -p`

## Specs

- S1 Cause (verified by reading Auctionator and, independently, by a second review). On the Forever client Auctionator keys equipment twice: `gr:<id>:<suffix>` (the variant) and `<id>` (generic). The generic entry keeps the cheapest variant seen in the last scan; asking by item id reads it, asking by link reads the variant. Non-gear has one key, so materials and consumables were never affected.
- S2 Done in 2.3.1 (GF-144, GF-146): weapons and armor are priced by link in the bag rows and in the tooltip, with the id price as the fallback; `GF.TooltipItemLink` reads the link from the tooltip data or from `GameTooltip:GetItem()` (name first, link second).
- S3 Backlog 1, bag rows. `BagRows` aggregates slots by item id, so two variants of the same item become one row priced with the first slot's link and its `bound` flag. Price each slot, or aggregate by id plus link for gear.
- S4 Backlog 2, posting plan. `features/auction/post.lua` (lines about 68 and 217) still reads the price by id: the advice can say auction at the variant price while the plan is built on the generic one. Pass the link into the plan.
- S5 Backlog 3, stale variant prices. A `gr:` entry is only refreshed when that exact variant is listed, with no age check, so an old or absurd listing can become the price and recommend an auction where the generic minimum was prudent. Use `GetAuctionAgeByItemLink` and skip or lower trust when it is old.
- S6 Backlog 4, "low price, wait" rule. It compares the variant price with `RefPrice(id)`, which is keyed by id: mixed units. Skip or adapt it for gear.
- S7 Minor: Auctionator's modern `IsEquipment` also counts the Profession class; the fix handles classes 2 and 4 only. Other places that read gear prices by id (session value, route planner, crafted gear) are listed in the review and are lower priority.
- S8 To confirm in the running game: that the tooltip data carries `hyperlink` on this client; the variant price versus the id price for the reported staff (about 15000 versus 4400 copper); the first tooltip after login (the suffix table loads asynchronously); two different suffixes of the same item in the bags.

## Tasks

- [x] G1 (S2) price equipment by link in bag rows and tooltip | commit: GF-144, GF-146 | in-game check pending
- [ ] G2 (S3) bag rows per variant | route: inline | commit: -
- [ ] G3 (S4) posting plan by link | route: inline | commit: -
- [ ] G4 (S5, S6) age of the variant price and the low-price rule | route: inline | commit: -

## Log

- L1 (2026-11-22, user, relaying a friend who uses the published addon): the staff "Báculo de ámbar de anciano del hierofante" is advised for the vendor (42 silver 10) while the auction shows 1 gold 50; he also noted "pero el baculo sigue igual" because he runs 2.3.0, which does not have the fix.
- L2 (2026-11-22, user): "Puedes analizar con Fable este escenario" -> "El del baculo": independent read-only analysis confirmed the cause and found a defect in the first fix (the item name was read as the link), fixed in GF-146.
- L3 (2026-11-22, user): "Sí, de acuerdo" -> 2.3.1 takes what is done; backlog points 1 and 2 (bag rows, posting plan) go to a later version.
