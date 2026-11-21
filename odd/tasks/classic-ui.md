# classic-ui

Objective: make GoldFinder look like a native classic WoW window instead of the flat modern style.
Branch: `feat/classic-ui`. Delivery: ask-on-risk. Checks: `luac -p` (Lua 5.1), the offline suites in `tests/`,
and in-game screenshots + BugGrabber (UI can only be verified in game).

## Specs

- S1. User request (verbatim): "Incluso el diseño se que lo hizo moderno Cowrok pero me gustaria que se integrase
  mas natural al diseño clasico de wow". Chosen option (verbatim answer "2"): "Rediseño al estilo de las ventanas
  del juego: que GoldFinder se vea como una ventana nativa, con marco tipo ButtonFrameTemplate, pestañas abajo como
  en la ventana de personaje y portada con ícono. Requiere reestructurar CreateUI."
- S2. The main window (`/gf`, `GoldFinderWindow`) uses Blizzard frame templates: portrait frame with icon and title,
  bottom tabs in the character-window style, inset content area, Blizzard fonts and buttons.
- S3. The same `CreateUI` content keeps working inside the auction house tab (LibAHTab host), which already has its
  own Blizzard frame.
- S4. Secondary frames (guide, next-step tracker, mail, bank and vendor panels, export box) use classic Blizzard
  backdrops, fonts and buttons, so the whole addon looks consistent.
- S5. No behaviour change: same tabs, lists, columns, actions and data.
- S6. Each feature lives in the game window where it is used, like SkillUp Forever adds tabs to the professions
  window. User (verbatim): "Lo relacionado a venta, compra a su respestiva venta, asi como la de action house."
  Mapping proposed and kept: professions window = Ruta and Fabricar; merchant window = sell advice; auction house
  tab = what to auction and shopping list; mail and bank = existing panels; `/gf` = Resumen, Cuero, Sesion, Ajustes.
- S7. Merchant window (verbatim): "cuando encuentras un NPC de venta compra, ahi deberia salir una ventana añadida
  con los objetos que te recomienda vender." and (verbatim) "y con su boton." Each recommended item has a button
  that sells it to the vendor on click (the existing `SellItem` path); nothing is sold without a click.

- S8. Settings (verbatim): "La de ajustes deberia ser mas estilo Options de wow". Chosen option (verbatim answer
  "1"): register GoldFinder in the game's Options > AddOns with the native Settings API (same checkboxes, section
  headers, Defaults and search); the Ajustes tab in /gf becomes a shortcut that opens that page.

- S9. Name (verbatim): "y hay que cambiar a GoldFinder Forever". Chosen (verbatim "si" to option 1): only the
  visible name changes (toc Title, window title, Options category, chat prefix); folder, SavedVariables and
  ADDON_LOADED name stay "GoldFinder" so saved data is kept.

## Tasks

| ID | Specs | Route | Status | Commit |
|----|-------|-------|--------|--------|
| U1 | S2, S3, S5 | delegated (context backstop) | done, verified in game (window) | 642153f, b225f3e |
| U2 | S4, S5 | pending | pending | |
| U3 | S6 | pending | pending | |
| U4 | S6, S7 | delegated (context backstop) | done (offline tests), in-game check pending | see Log L11 |
| U5 | S6 | pending | pending | |
| U6 | S8, S5 | delegated (context backstop) | done, verified in game | a0f11da |
| U7 | S9 | inline | done, verified in game | 0ca4681, 40f7164 |

- U1: main window and shared helpers (`Flat`, `Text`, `Btn`, `PAL`, list rows, tabs) in the classic style.
- U2: guide, tracker, mail, bank, vendor and export frames in the classic style.
- U3: Ruta and Fabricar as tabs inside the professions window (PanelTabButtonTemplate on ProfessionsFrame).
- U4: panel attached to the merchant window listing the items recommended to sell to the vendor.
- U5: auction house tab content focused on what to auction and the shopping list.
- U7: visible name "GoldFinder Forever" (toc Title now; window title, Options category, chat prefix after U6).
- U6: settings registered in Options > AddOns (native Settings API); Ajustes tab opens it.

## Log

- L1 (2026-11-20, user, verbatim): "Incluso el diseño se que lo hizo moderno Cowrok pero me gustaria que se
  integrase mas natural al diseño clasico de wow". Then "2" (full native-window redesign).
- L2: `CreateUI(parent)` is hosted by `GoldFinderWindow` (ToggleWindow) and by the auction house tab (BuildTab,
  LibAHTab). The client has the modern auction house, so modern Blizzard templates are expected to exist; this is
  unverified until tested in game.
- L3 (2026-11-20, user, verbatim): "Porque el skillUp se integra a la pestaña de profesiones". Verified:
  SkillUpForever UI/Pages.lua:249 adds PanelTabButtonTemplate tabs to ProfessionsFrame; UI/Shopping.lua:581 notes
  CharacterFrameTabButtonTemplate is not loaded by the Forever client.
- L4 (2026-11-20, user, verbatim): "Lo relacionado a venta, compra a su respestiva venta, asi como la de action
  house." then "cuando encuentras un NPC de venta compra, ahi deberia salir una ventana añadida con los objetos que
  te recomienda vender." Added S6, S7 and tasks U3-U5.
- L5: U1 done by a bounded writer: GoldFinderWindow from ButtonFrameTemplate (coin portrait, title, template close
  button; flat fallback if the template is missing), bottom PanelTabButtonTemplate tabs (Btn fallback), Inset
  content, Text/Btn mapped to Blizzard font objects and UIPanelButtonTemplate, QuestTitleHighlight row hover,
  tooltip-border summary cards. AH host keeps a 30px header without title. luac OK; offline suites 7/23/5/10 PASS.
  Risk: item 6 (visual, only verifiable in game).
- L6 (2026-11-20, user, verbatim): "La de ajustes deberia ser mas estilo Options de wow" and a screenshot of the
  client Options window (Game | AddOns tabs, categories on the left, checkboxes with section headers, Defaults).
  Then "1". Reference implementation on this client: SkillUpForever/UI/Settings.lua (RegisterVerticalLayoutCategory,
  RegisterAddOnSetting, RegisterInitializer + CreateCheckboxInitializer, RegisterProxySetting, sliders).
- L7: U1 follow-up b225f3e: bottom tabs resized with padding 12, min width 70, overlap -8 (were cramped in game).
- L8: U6 done by a bounded writer: RegisterOptions() (category, 4 section headers, checkboxes, sliders for
  minGain/reserve/routeSpan/sellCap, banker as stepped proxy slider because the native dropdown asserts on Forever per
  SkillUp's notes, per-profession proxy checkboxes), opened with securecallfunction(C_SettingsUtil.OpenSettingsPanel)
  then Settings.OpenToCategory; old in-window page kept as fallback; /gf ajustes|config|opciones; /gf ruta|tope go
  through Settings.SetValue. Suites pass.
- L9: U7: visible strings renamed (chat prefix, window title, minimap tooltip and LDB text, Options category).
  Kept as "GoldFinder": folder, SavedVariables, ADDON_LOADED check, Auctionator CALLER id, LDB/LibDBIcon object
  name (minimap position), auction house tab label (narrow).
- L10: In game 2026-11-20 20:51: window title "GoldFinder Forever"; Options > AddOns > GoldFinder Forever shows
  sections, checkboxes, sliders (routeSpan 25, sellCap 5, minGain 20s, banker Ashes Soulbinder) and Defaults; tabs
  relayout when Ruta is toggled; no GoldFinder errors in BugGrabber. AH tab host not yet checked.
- L11: U4 done by a bounded writer: GoldFinderSellPanel attached to MerchantFrame ("Para vender"), rows from
  BagRows()/Decide via pure helper VendorSellRows (markers "-- VENTA AL VENDEDOR: filas del panel" .. "-- FIN DE
  VENTA AL VENDEDOR"), qty limited by SellQty, per-item "Vender" button selling whole stacks with
  C_Container.UseContainerItem only while MerchantFrame is shown (existing SellItem is an auction helper, not a
  vendor sale). Setting sellPanel (default on). tests/sell_panel_test.lua 10 PASS (RED first). Parent review fixed
  single-backslash texture paths (Lua 5.1 drops the backslash in "\D", so the dialog border texture would not load).
- L12 (2026-11-20, user, verbatim): "Bueno, hay items que no se deben vender, como el cozy sleep bag jeje" and
  "Y no se puedes desplazar la lista". Fix: IsUtilityItem (on-use effect, not consumable, not gray) blocks VENDOR in
  Decide (AH still evaluated); tests/utility_item_test.lua 7 PASS (RED first). Sell panel: scrollable list
  (UIPanelScrollFrameTemplate, 12 visible rows, mouse wheel), per-row "Guardar" button pinning the item
  (Char().keep, released from the Bolsas tab), panel width 360.
