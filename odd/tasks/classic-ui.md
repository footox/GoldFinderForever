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

- S10. Like SkillUp Forever on screen (user verbatim: "Pero Skillup hacia algo en la pantalla", then "Las 2" for
  both options): (a) GoldFinder's next step as a block inside the game's objective tracker (like SkillUp's
  "Profession reagents" block) instead of only the floating panel; (b) per-recipe info in Blizzard's recipe list
  (skill-up chance and cost/gain per point, as SkillUp shows "100% · +2s"), without overlapping SkillUp's own text.

- S11. Auction from the list (user verbatim): "Porque la idea que de lo que se indica que se subaste, en la lista se
  pueda subastar." and "Y la idea es que ya calcule la cantidad y precio recomendado, como lo hace TSM." Each item
  GoldFinder marks for auction has a "Subastar" button in the AH tab that posts it with one click at a computed
  price and quantity (TSM-like operation: market reference, min/normal/max, undercut, post cap), with a tooltip
  showing price, quantity, deposit and the reason; nothing is posted without a click.

## Tasks

| ID | Specs | Route | Status | Commit |
|----|-------|-------|--------|--------|
| U1 | S2, S3, S5 | delegated (context backstop) | done, verified in game (window) | 642153f, b225f3e |
| U2 | S4, S5 | delegated (context backstop) | done, tracker verified in game; guide, mail, bank pending | 7460f3a |
| U3 | S6 | delegated (context backstop) | done, verified in game (Ruta) | 8ee8024, 385f293 |
| U4 | S6, S7 | delegated (context backstop) | done, verified in game | bbd009a, 454b833 |
| U5 | S6 | delegated (context backstop) | done, verified in game | 204ab24 |
| U6 | S8, S5 | delegated (context backstop) | done, verified in game | a0f11da |
| U7 | S9 | inline | done, verified in game | 0ca4681, 40f7164 |
| U8 | S10a | delegated (context backstop) | done, verified in game | c3eab1d, 60be0a1 |
| U9 | S10b | delegated (context backstop) | done, verified in game | c3eab1d |
| U10 | S11 | delegated (context backstop) | done (offline tests), in-game check pending | see Log L25 |

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
- L13: In game 21:07-21:08: sell panel next to Innkeeper Adegwa with scroll bar, Guardar/Vender per row, total;
  sleeping bag no longer listed; a sale happened; Guardar persisted ids in Char().keep (3385, 17058, 3827, 929...);
  no GoldFinder errors in BugGrabber after /reload.
- L14: U3 done by a bounded writer. Forever's ProfessionsFrame has no Blizzard bottom tabs (native tabs are on
  the right side); SkillUp adds a side tab plus bottom tabs only while its page is open. GoldFinder adds "Ruta" and
  "Fabricar" PanelTabButtonTemplate tabs at the bottom-left, anchored after any visible bottom tab; page
  GoldFinderProfessionPage covers the recipe area and hides on any other tab (hooksecurefunc on PanelTemplates_*,
  HookScript on native pages). CreateUI(parent, opts) gains embedded/only/onNav/back and ui.profFilter. Helper
  ProfTabKeys (tests/prof_tabs_test.lua 9 PASS, RED first). Setting profTabs (default on); tabs also require
  craftTab/routeTab, which default to off (on in the user's profile). Open question for sharing: default visibility.
- L15: U2 done by a bounded writer: helper `Skin` (Panel/Head/Close/Icon/Fold/Bar/Quest, guarded with flat
  fallbacks). Guide from ButtonFrameTemplate with PanelTabButtonTemplate profession tabs; tracker with tooltip
  backdrop, title "GoldFinder Forever: siguiente paso", native close, plus/minus and book icon buttons with
  tooltips; mail, bank, vendor recipes and TSM export with dialog backdrops. Suites pass; no single-backslash texture
  paths; no new globals.
- L16: U5 done by a bounded writer: CreateUI(panel, { auction = true }) in BuildTab. AH tab views: Bolsas (AH
  verdict rows first via AHBagOrder), Compras (when `shopping` is on or the current step misses materials), Cuero;
  Ajustes as a header button opening the options page. Helpers AHViewKeys/AHBagOrder between markers
  "-- VISTAS DE LA CASA DE SUBASTAS" .. "-- FIN DE VISTAS DE LA CASA DE SUBASTAS"; tests/ah_tab_test.lua 7 PASS
  (RED first). /gf unchanged.
- L17: In game: tracker restyle visible (title "GoldFinder Forever: siguiente paso", native icons). U3 tabs Ruta and
  Fabricar visible at the bottom-left of the professions window, but clicking showed nothing: the tab got
  selected (so P.current was set and the page was shown) yet the page stayed behind the recipe list. Fix 385f293:
  page on the strata above the window plus SetToplevel. Verified 21:57: Ruta page inside Cooking, filtered to
  Cooking 176>201 with buy rows. No GoldFinder errors (one BugGrabber entry came from a truncated /run test line).
  Pending in game: Fabricar page, hiding on native tabs, U5 AH tab, U2 guide/mail/bank.
- L18 (2026-11-20, user, verbatim): "encendidas". DEFAULTS craftTab and routeTab now true, so Ruta and Fabricar tabs
  (in /gf and in the professions window) are on for new profiles; saved explicit choices are kept.
- L19 (2026-11-20, user, verbatim): "Pero Skillup hacia algo en la pantalla" with screenshots: SkillUp shows a
  "Profession reagents" block in the objective tracker, chance and cost per point next to each recipe in the
  recipe list, and a richer Route page; GoldFinder's Ruta/Fabricar tabs sit after SkillUp's Route/Supply/Buffs
  without overlap. Then "Las 2": tasks U8 (objective tracker block) and U9 (recipe list annotations).
- L20: U8/U9 done by a bounded writer. U8: with SkillUp, a "GoldFinder Forever" section through ForeverCore's
  public TrackerSection API next to "Profession reagents"; without it, a look-alike block GoldFinderObjectives under
  ObjectiveTrackerFrame (anchor only). Fed by NextStepList via UpdateTracker; setting trackerMode
  (objetivos/flotante, stepped slider); still requires nextSteps. U9: notes "NN% · ±money" on recipe rows via
  ScrollUtil.AddInitializedFrameCallback; cost/gain per point from PlanRoute (new plan.eff field, formula
  unchanged); with SkillUp row text on, GoldFinder adds tooltip lines instead; setting recipeNotes.
  tests/objective_notes_test.lua 27 PASS (RED first); all suites pass.
- L21: In game 22:15-22:17 (SkillUp disabled): recipe notes visible ("100% · +6s47c" green, "90% · -1s6c" red).
  Fallback objective block first drawn under the tracker and went off screen with a long quest list; fix 60be0a1
  anchors it left of ObjectiveTrackerFrame, top aligned (like SkillUp). Verified: block "GoldFinder Forever" with
  Cooking 179 > 204 and Leatherworking lines and missing materials. No GoldFinder errors.
- L22: In game 22:19 with Ashes Soulbinder at the Undercity AH: GoldFinder AH tab shows Bolsas (Spider's Silk, Runed
  Copper Rod, VENDEDOR, Fijar) and Cuero tabs, header buttons Exportar a TSM / Ajustes / Escanear; objective block
  shows Ashes' Tailoring 75 train line. Follow-ups: AH window title now "GoldFinder Forever" (LibAHTab tabHeader);
  static trainer fallback prefers the trainer in the current zone (was Orgrimmar for a character in Undercity),
  tests/trainers_test.lua +2 cases (RED first). Ashes' ficha rename not yet observable (saved data predates the
  Ashes session).
- L23: After /reload with Ashes (22:21): saved fichas are "Ashes Soulbinder" and "Twistice Penguin" (old realm key
  renamed on first login). No GoldFinder errors. Still not seen in game: Fabricar page in the professions window,
  /gf guia restyle, mail and bank panels.
- L24 (2026-11-20, user, verbatim): "Realmente no se si es funcional lo que muestra." then the S11 quotes. Current
  "Vender" action in the AH Bolsas rows only prepares the item in Auctionator's Selling tab (two steps). Task U10.
- L25: U10 done by a bounded writer: pure AuctionPlan (markers "-- PLAN DE SUBASTA" .. "-- FIN DE PLAN DE SUBASTA",
  via Skin.Auction): market = TSM DBMarket / DBRegionMarketAvg / RefPrice (lowest if none), min = max(market*60%,
  vendor floor after cut), max = 200%, undercut 1c, cap = 2 days of region sales. "Subastar" button posts with
  C_AuctionHouse.PostCommodity / PostItem (commodity status, duration 12h=1/24h=2 like Auctionator), deposit and
  reason in tooltip, disabled with reason when not worth it, shift-click opens Auctionator. Settings postMinPct,
  postMaxPct, postUndercut, postCapDays, postDuration. tests/auction_plan_test.lua 20 PASS (RED first).
  Risk: real auctions and deposits on click; verify in game.
- L26 (2026-11-20, user, verbatim): "Y despues haz una revisión con Fable de cada funcionalidad.", "Aparte evaluar y
  lleva el seguimiento de items, que debes guardar, subaster, vender para que no pierdas objetos para tus
  profesiones, y si conviene fabricar un objeto porque renta vender o subastarlo." and "Y pues hace el cruce de
  profesiones de tus alts, si llegas a un vendedor incluso en el tooltip de indica que debes comprar esa receta
  para la profesion de ese personaje si aun no la tiene aprendida." Existing code: RecipeForOthers (tooltip and
  vendor box). Next: Fable review by feature area.
