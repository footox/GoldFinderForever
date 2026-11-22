# Changelog

## Unreleased

- Shopping tab: each profession row also has its own List button, with a list named GoldFinder - <profession>, for when you only care about one.
- Scan button: shows the scan percentage and a thin progress bar while Auctionator scans.
- Shopping tab: a List button sends what is missing (exact names and quantities) to an Auctionator shopping list named GoldFinder, kept after you close the auction house.
- Auction tab: a collapsible side panel on the right with the navigation between views and the posting options; the bottom tabs are replaced by it.
- Auction: when the last scan is older than a set time (10 minutes by default, 0 = never), the first click on Post checks the live lowest price of that item and recalculates; the second click posts. Two clicks because posting needs a direct click.
- Guide: recipes taught by an item (patterns, plans, formulas) now say where to get it, with the vendor or the creature that drops it, its zone and coordinates, read from QuestieDB when it is installed. Nothing changes without QuestieDB.
- New option (off by default): show the Fishing and Skinning zone for your next skill range in the objective tracker, like Mining and Herbalism.
- Fishing: guide by skill range with zones (from the WoW Forever fishing guides of wow-professions.com and warcrafttavern.com).

## 2.2.0

- English (enUS) and Spanish (esES) interface; it follows the game language, with a language selector in the options.
- The "Fijar" button is now "Guardar" (Keep) and its reasons say "lo guardaste tú".
- Mailbox panel: a checkbox per item to leave it out of this mail (count, mails and value update; resets when the mailbox closes).
- Bags list: an X button per item hides it from the list (per character; a footer row shows or hides them again). Decisions do not change.
- Objective tracker: material icons, the cost of the missing materials, the skill-up chance per craft, and a note when the guide proposes another recipe than the cheapest one.
- Internal refactor: code split into core, adapters, features and ui folders; no behavior change.

## 2.1.2

- QuestieDB is now an optional dependency: the addon loads on characters where Questie is disabled
  (quest-based item needs are simply skipped there).

## 2.1.1

- Merchant prices are read through a compatibility helper that falls back to C_MerchantFrame.GetItemInfo if
  GetMerchantItemInfo disappears in a future client patch.

## 2.1

- No longer uses or ships any Zygor data: own route planner, own profession guide list generated from the game
  tables, trainers recorded when you visit them, leather farming from your own loot.
- Native WoW look: portrait window with bottom tabs, options in Options > AddOns, classic panels.
- Merchant panel: items worth selling to the vendor, each with Sell and Keep buttons.
- Auction house tab: one-click Subastar with a TSM-like price and quantity (min/max, undercut, cap); disabled when
  the price is uncertain (gear variants, no reference, no scan).
- Mailbox: Enviar al banquero sends auction items to your banker character (whole stacks, never reserved units).
- Professions window: Ruta and Fabricar tabs; skill-up chance and cost per point next to each recipe.
- Objective tracker block with your next profession step.
- Protection: profession tools, items reserved for your professions and your alts, and items needed by your quests
  are never suggested for sale.
- Hybrid profession guide (/gf guia) with your real prices on top of a full 1-300 list.

## 2.0

- First version.
