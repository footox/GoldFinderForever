# Changelog

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
