# Changelog

## 2.4.0

### Fixes
- The Scan button of the main window no longer shows a Lua error when the auction house is closed: it tells you to open the auction house first (Auctionator only scans from there).
- The summary window had four titles written in Spanish whatever the game language ("To sell", "To keep", the leather session and "What to do now"); they are now translated.

### Features
- No scan yet? Now it says what to do: the tooltip says "no auction prices yet: open the auction house and press Scan" (instead of a bare "scan"), the main window status line says the same, and one chat line at login reminds you while Auctionator has no scan on record. One scan fills the prices of every item.
- Penguin winks: a short penguin line in the chat now and then at login (one login in four, never the first time) and when a scan starts, plus a small hidden command. You can switch them off in the options ("Penguin winks") for plain messages.
- Waylaid Crates are never advised for sale: the addon keeps them and says they serve Favor, whatever they would fetch at the auction house or the vendor.
- The addon has an icon of its own: the penguin with its treasure shows in the game's addon list and in the main window, and the minimap button has a closer picture of the penguin's face, because the full picture is lost at that size. It replaces the generic coin.
- The profession guide has a search box (top right): type part of a material's name, such as "thread" or "heavy leather", and the guide shows only the steps whose recipe uses it, with the amount per craft. Esc clears it.
- A recipe's tooltip now also says, whatever the advice is (keep, auction, vendor or no data), which of your own characters already know it ("Already known by: you, Ashes"), and the merchant's recipe box shows the same line. It only reads what the addon saved from your own profession windows; nothing is sent to anyone.
- Next to a profession trainer's window, a small panel lists the recipes it teaches that your guide still needs, with what they cost together, and how many others are not in your guide, so you do not pay for the useless ones. Option: Panel at the profession trainer.
- In the auction house, Materials opens in a window of its own next to it and closes with it, so the GoldFinder tab keeps its space. You can drag it, and it remembers where you left it. Option: Materials window at the auction house.
- The Leather tab is now the Materials tab: leather, cloth, ore and herbs, with their auction price, the value of a stack and the advice. A selector at the top (< and >) changes the category, and it opens on the one of your professions (the one with the highest skill; leather if none).
- Optional data addon support: if GoldFinderForeverData is installed, the guide also says where to get a recipe item from the vendors and drops its players recorded, next to what QuestieDB knows (it fills the gaps, for example recipes QuestieDB does not list).
- /gff data <command> runs a command of the data addon (for example /gff data help or /gff data near vendor).

## 2.3.1

### Fixes
- Equipment with variants (random suffix, item level) is now priced by its own variant at the auction house instead of the generic entry, which could be an old or a much lower price. A staff worth 1 gold 50 was advised for the vendor at 42 silver because the generic entry said 44 silver.
- Equipment whose own variant has no price yet in Auctionator (never scanned) is no longer advised for the vendor on the strength of the generic price alone (the cheapest variant seen): the tooltip says only that price is known and to check yours at the auction house, and the item stays in the Bags list with that note. Equipment with a single entry (no variants) is unaffected.
- When the auction is not recommended because it gains too little, the tooltip now says how much it gains, what the minimum is (the "Minimum auction profit" option) and about how many units would make it worth posting. Before it only said "gains little".
- Options that you never changed are no longer saved as if you had chosen them, so a default that changes in a later version reaches everyone. Only the values that differ from the default are kept.

### Changes
- New option "Minimum margin over the vendor (%)" (default 10, the value that was fixed before): the auction is recommended only if its price, after the cut, beats the vendor price by more than that percentage. It works together with "Minimum auction profit", which is the profit of the whole lot.
- The default minimum auction profit is now 10 silver (it was 20): it weighs less for a player who is still levelling. It is the profit of the whole lot, so more units reach it; change it in Options > AddOns > GoldFinder Forever ("Minimum auction profit"). If you never changed it, the new default applies.

## 2.3.0

### Features
- A welcome window opens once the first time you log in and lists what the addon does and which features are on. Open it again with /gff welcome.

### Changes
- The addon folder is now GoldFinderForever (it was GoldFinder). Delete the old GoldFinder folder after updating.
- Saved data starts fresh: nothing is imported from the old version. Professions are read again by themselves; the keep and hide lists and the options have to be set again.
- On by default now: the next profession step in the objective tracker, the Shopping tab with its List button, and the warning about materials your other characters need. All can be turned off in the options; the mailbox panel stays off by default.
- The main command is now /gff. /gf keeps working only while no other addon uses it.
- The minimap button and the option entries have their own names, so they no longer share them with other addons.

## 2.2.1

### Features
- Auction: when the last scan is older than a set time (10 minutes by default, 0 = never), the first click on Post checks the live lowest price of that item and recalculates; the second click posts. Two clicks because posting needs a direct click.
- Auction: the Post button shows "Checking" while the live price is read and "Posting" while the auction is created, and cannot be clicked twice meanwhile.
- Auction: a collapsible side panel on the right holds the navigation between views and the posting options; the bottom tabs are replaced by it.
- Auction: the Scan button shows the scan percentage and a thin progress bar while Auctionator scans.
- Shopping: a List button sends what is missing (exact names and quantities) to an Auctionator shopping list named GoldFinder, kept after you close the auction house.
- Shopping: each profession row has its own List button, with a list named GoldFinder - <profession>, for when you only care about one.
- Guide: Fishing guide by skill range with zones (from the WoW Forever fishing guides of wow-professions.com and warcrafttavern.com).
- Guide: recipes taught by an item (patterns, plans, formulas), and the optional cheaper recipe of a band, say where to get them, with the vendor or the creature that drops it, its zone and coordinates. Read from QuestieDB when it is installed; nothing changes without it.
- Tracker: new option, off by default, to show the Fishing and Skinning zone for your next skill range, like Mining and Herbalism.

### Changes
- Zone notes of the guides (for example "copper", "tin and silver" or the Fishing tips) are shown in English with an English interface instead of in Spanish.

### Fixes
- The live price check no longer loops when an item has no competing auction: the saved price is used.
- Live results are read in price order.
- Wide state buttons no longer overlap the price column.
- The scan indicator no longer reports a failed scan just because it was quiet for a while.
- A recipe source that could not be read at login is looked up again later.

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
