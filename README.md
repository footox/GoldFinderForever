<p align="center"><img src="media/logo.png" width="96" alt=""></p>

<h1 align="center">GoldFinder Forever</h1>

<p align="center">
What to do with what you carry (vendor, auction or keep), and how to level professions cheaply, for WoW: Forever.<br>
<a href="https://github.com/footox/GoldFinderForever/actions/workflows/ci.yml"><img src="https://github.com/footox/GoldFinderForever/actions/workflows/ci.yml/badge.svg" alt="CI"></a>
<a href="https://github.com/footox/GoldFinderForever/tags"><img src="https://img.shields.io/github/v/tag/footox/GoldFinderForever" alt="Latest version"></a>
<a href="https://www.curseforge.com/wow/addons/goldfinder-forever"><img src="https://img.shields.io/curseforge/dt/1820519?label=CurseForge%20downloads" alt="CurseForge downloads"></a>
<a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-blue" alt="MIT license"></a>
</p>

GoldFinder Forever reads your bags and the auction prices and tells you, item by item, whether to vendor, auction or keep it, with the reason. It also plans profession levelling with your own prices. **Nothing is sold, posted or mailed without your click.** The interface is in English and Spanish and follows the game language.

*Versión en español más abajo / [Spanish version below](#español).*

## Features

- **Advice on every item**: vendor, auction or keep, with the reason (used by your profession, an alt or a quest).
- **Merchant panel**: what is worth selling to the vendor, with Sell and Keep buttons.
- **Auction house**: a GoldFinder tab with one-click posting (price and quantity worked out like a TSM operation). If your last scan is old, the first click checks the live price and the second one posts. A collapsible side panel holds the navigation and the posting options, and the Scan button shows its progress.
- **Mailbox** (off by default): send what should be auctioned to your banker character, with a checkbox per item.
- **Bags**: an X button hides an item from the list (per character) and a Show button brings it back.
- **Materials**: leather, cloth, ore and herbs with their auction price, the value of a stack and the advice; it opens on the category of your professions.
- **Shopping**: what you are missing for each profession, with a List button that sends it (exact names and quantities) to an Auctionator shopping list, plus one list per profession.
- **Professions**: Route and Craft tabs in the professions window, skill-up chance and cost per point on each recipe, and a 1-300 guide with your own prices. It includes Fishing and, with QuestieDB or the data addon, where to get the recipes that are taught by an item.
- **Tracking**: your next profession step in the objective tracker, with the icon of each material, the cost of what you are missing and the skill-up chance per craft.
- **Welcome window**: opens once the first time you log in and lists what the addon does and which features are on.

## Requirements and install

| | |
|---|---|
| Client | WoW: Forever (Interface `16001`) |
| Required | [Auctionator](https://www.curseforge.com/wow/addons/auctionator) for auction prices |
| Optional | QuestieDB (quest items and recipe sources), TradeSkillMaster (market prices), GoldFinderForeverData (vendors, trainers and recipe sources recorded by players) |

Install it from [CurseForge](https://www.curseforge.com/wow/addons/goldfinder-forever), or copy the folder **`GoldFinderForever`** (the one that contains `GoldFinderForever.toc`) into `Interface/AddOns`.

Coming from 2.2.x? The folder was renamed, so delete the old `GoldFinder` folder. Saved data starts fresh in 2.3.0: professions are read again by themselves, and the keep and hide lists and the options have to be set again.

## Commands

| Command | What it does |
|---|---|
| `/gff` | Opens the window (`/gf` also works while no other addon uses it) |
| `/gff options` | Opens the options (also in Options > AddOns > GoldFinder Forever) |
| `/gff guide [profession]` | Opens the 1-300 profession guide |
| `/gff route N` | Skill points the Route tab plans, from 5 to 100 |
| `/gff cap N` | Units of each crafted item valued at auction price in the Route |
| `/gff welcome` | Opens the welcome window again |
| `/gff minimap` | Shows or hides the minimap icon |
| `/gff data <command>` | Runs a command of the optional data addon, GoldFinderForeverData (for example `/gff data help`) |

The Spanish aliases (`ajustes`, `guia`, `ruta`, `tope`, `bienvenida`) work too.

## Privacy

Everything the addon knows stays in the saved variables on your PC: your own characters, their professions and what they carry. It sends nothing anywhere and collects no information about other players.

## Feedback and bug reports

Found something wrong, or have an idea? Tell us, it helps a lot:

- **Report a problem or suggest something:** [open an issue on GitHub](https://github.com/footox/GoldFinderForever/issues/new/choose). The form asks for what is useful and takes a minute.
- **Quick comment or question:** the comments of the [CurseForge page](https://www.curseforge.com/wow/addons/goldfinder-forever).

What makes a report easy to act on:

- **The addon version** (the Addons list at the character screen shows it) and, if you know it, the game client version.
- **What you did, what you expected and what happened.** For advice about prices, a screenshot of the item's tooltip with the GoldFinder line visible says almost everything.
- **Any error text** (from BugGrabber or the Lua error window), copied as it is.
- Which of **Auctionator** and **TradeSkillMaster** you have loaded.

Nothing is sent from the game: the addon makes no network calls (see Privacy). Do not post passwords or account data; character names are not needed.

## Known limitations

- It is made for WoW: Forever; other clients are not tested.
- Auction prices come from Auctionator. Without a scan there are no prices to advise with.
- The route planner is greedy: it picks the cheapest useful craft for each skill point, which is not a proven global optimum.
- Fishing zones by skill range come from community guides and are not verified by the addon.
- The live price check at posting time reads the first rows of the auction results only.

## Changelog

<!-- changelog:start -->

### Unreleased

**Features**
- Penguin winks: a short penguin line in the chat now and then at login (one login in four, never the first time) and when a scan starts, plus a small hidden command. You can switch them off in the options ("Penguin winks") for plain messages.
- Waylaid Crates are never advised for sale: the addon keeps them and says they serve Favor, whatever they would fetch at the auction house or the vendor.
- The addon has an icon of its own: the penguin with its treasure shows in the game's addon list, on the minimap button and in the main window, instead of a generic coin.
- The profession guide has a search box (top right): type part of a material's name, such as "thread" or "heavy leather", and the guide shows only the steps whose recipe uses it, with the amount per craft. Esc clears it.
- A recipe's tooltip now also says which of your own characters already know it ("Already known by: you, Ashes"), and the merchant's recipe box shows the same line. It only reads what the addon saved from your own profession windows; nothing is sent to anyone.
- Next to a profession trainer's window, a small panel lists the recipes it teaches that your guide still needs, with what they cost together, and how many others are not in your guide, so you do not pay for the useless ones. Option: Panel at the profession trainer.
- In the auction house, Materials opens in a window of its own next to it and closes with it, so the GoldFinder tab keeps its space. You can drag it, and it remembers where you left it. Option: Materials window at the auction house.
- The Leather tab is now the Materials tab: leather, cloth, ore and herbs, with their auction price, the value of a stack and the advice. A selector at the top (< and >) changes the category, and it opens on the one of your professions (the one with the highest skill; leather if none).
- Optional data addon support: if GoldFinderForeverData is installed, the guide also says where to get a recipe item from the vendors and drops its players recorded, next to what QuestieDB knows (it fills the gaps, for example recipes QuestieDB does not list).
- /gff data <command> runs a command of the data addon (for example /gff data help or /gff data near vendor).

**Changes**
- New option "Minimum margin over the vendor (%)" (default 10, the value that was fixed before): the auction is recommended only if its price, after the cut, beats the vendor price by more than that percentage. It works together with "Minimum auction profit", which is the profit of the whole lot.
- The default minimum auction profit is now 10 silver (it was 20): it weighs less for a player who is still levelling. It is the profit of the whole lot, so more units reach it; change it in Options > AddOns > GoldFinder Forever ("Minimum auction profit"). If you never changed it, the new default applies.

### 2.3.1

**Fixes**
- Equipment with variants (random suffix, item level) is now priced by its own variant at the auction house instead of the generic entry, which could be an old or a much lower price. A staff worth 1 gold 50 was advised for the vendor at 42 silver because the generic entry said 44 silver.
- Equipment whose own variant has no price yet in Auctionator (never scanned) is no longer advised for the vendor on the strength of the generic price alone (the cheapest variant seen): the tooltip says only that price is known and to check yours at the auction house, and the item stays in the Bags list with that note. Equipment with a single entry (no variants) is unaffected.
- When the auction is not recommended because it gains too little, the tooltip now says how much it gains, what the minimum is (the "Minimum auction profit" option) and about how many units would make it worth posting. Before it only said "gains little".
- Options that you never changed are no longer saved as if you had chosen them, so a default that changes in a later version reaches everyone. Only the values that differ from the default are kept.

**Changes**
- New option "Minimum margin over the vendor (%)" (default 10, the value that was fixed before): the auction is recommended only if its price, after the cut, beats the vendor price by more than that percentage. It works together with "Minimum auction profit", which is the profit of the whole lot.
- The default minimum auction profit is now 10 silver (it was 20): it weighs less for a player who is still levelling. It is the profit of the whole lot, so more units reach it; change it in Options > AddOns > GoldFinder Forever ("Minimum auction profit"). If you never changed it, the new default applies.

<details>
<summary>Older versions (2.3.0 to 2.0)</summary>

### 2.3.0

**Features**
- A welcome window opens once the first time you log in and lists what the addon does and which features are on. Open it again with /gff welcome.

**Changes**
- The addon folder is now GoldFinderForever (it was GoldFinder). Delete the old GoldFinder folder after updating.
- Saved data starts fresh: nothing is imported from the old version. Professions are read again by themselves; the keep and hide lists and the options have to be set again.
- On by default now: the next profession step in the objective tracker, the Shopping tab with its List button, and the warning about materials your other characters need. All can be turned off in the options; the mailbox panel stays off by default.
- The main command is now /gff. /gf keeps working only while no other addon uses it.
- The minimap button and the option entries have their own names, so they no longer share them with other addons.

### 2.2.1

**Features**
- Auction: when the last scan is older than a set time (10 minutes by default, 0 = never), the first click on Post checks the live lowest price of that item and recalculates; the second click posts. Two clicks because posting needs a direct click.
- Auction: the Post button shows "Checking" while the live price is read and "Posting" while the auction is created, and cannot be clicked twice meanwhile.
- Auction: a collapsible side panel on the right holds the navigation between views and the posting options; the bottom tabs are replaced by it.
- Auction: the Scan button shows the scan percentage and a thin progress bar while Auctionator scans.
- Shopping: a List button sends what is missing (exact names and quantities) to an Auctionator shopping list named GoldFinder, kept after you close the auction house.
- Shopping: each profession row has its own List button, with a list named GoldFinder - <profession>, for when you only care about one.
- Guide: Fishing guide by skill range with zones (from the WoW Forever fishing guides of wow-professions.com and warcrafttavern.com).
- Guide: recipes taught by an item (patterns, plans, formulas), and the optional cheaper recipe of a band, say where to get them, with the vendor or the creature that drops it, its zone and coordinates. Read from QuestieDB when it is installed; nothing changes without it.
- Tracker: new option, off by default, to show the Fishing and Skinning zone for your next skill range, like Mining and Herbalism.

**Changes**
- Zone notes of the guides (for example "copper", "tin and silver" or the Fishing tips) are shown in English with an English interface instead of in Spanish.

**Fixes**
- The live price check no longer loops when an item has no competing auction: the saved price is used.
- Live results are read in price order.
- Wide state buttons no longer overlap the price column.
- The scan indicator no longer reports a failed scan just because it was quiet for a while.
- A recipe source that could not be read at login is looked up again later.

### 2.2.0

- English (enUS) and Spanish (esES) interface; it follows the game language, with a language selector in the options.
- The "Fijar" button is now "Guardar" (Keep) and its reasons say "lo guardaste tú".
- Mailbox panel: a checkbox per item to leave it out of this mail (count, mails and value update; resets when the mailbox closes).
- Bags list: an X button per item hides it from the list (per character; a footer row shows or hides them again). Decisions do not change.
- Objective tracker: material icons, the cost of the missing materials, the skill-up chance per craft, and a note when the guide proposes another recipe than the cheapest one.
- Internal refactor: code split into core, adapters, features and ui folders; no behavior change.

### 2.1.2

- QuestieDB is now an optional dependency: the addon loads on characters where Questie is disabled
  (quest-based item needs are simply skipped there).

### 2.1.1

- Merchant prices are read through a compatibility helper that falls back to C_MerchantFrame.GetItemInfo if
  GetMerchantItemInfo disappears in a future client patch.

### 2.1

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

### 2.0

- First version.

</details>

Full history: [CHANGELOG.md](CHANGELOG.md).

<!-- changelog:end -->

## Development

```
core/       pure Lua: decisions, planner, prices, texts (no game calls)
adapters/   the only place that talks to game APIs, each call guarded
features/   one folder per window or panel (vendor, mail, auction, guide, route, tracker, welcome)
ui/         shared widgets
locales/    enUS (base) and esES
tests/      offline suites, plain Lua 5.1
odd/tasks/  the specs the work is planned from
tools/      build and data helpers
```

Run all the tests from the repository root with Lua 5.1:

```
for t in tests/*.lua; do lua5.1 "$t"; done
```

Build the release zip with `python tools/build_zip.py` (it writes `dist/GoldFinderForever-<version>.zip` with a single `GoldFinderForever/` folder). After editing `CHANGELOG.md`, refresh the section above with `python tools/sync_readme_changelog.py`.

Branches: `develop` is the default branch, where work is integrated; feature branches start from it, and **pull requests always go to `develop`**. `main` holds what is published and every version is tagged (`v2.3.0`); it only receives merges from `develop` when a version is released (a check rejects any other pull request into `main`). Commit subjects are `ID - task` (for example `GF-112 - Fix findings of the 2.3.0 code review`).

## Data sources

- Recipes and profession guide: public game tables (wago.tools).
- Leatherworking, Mining and Herbalism routes and trainer locations: loose data from the Icy Veins guides.
- Fishing zones by skill range: the WoW Forever fishing guides of wow-professions.com and warcrafttavern.com (zones and ranges only).
- It contains no Zygor data and no code from other addons.

## License

[MIT](LICENSE).

---

## Español

GoldFinder Forever lee tus bolsas y los precios de la subasta y te dice, objeto por objeto, si conviene **vender al vendedor, subastar o guardar**, con el motivo. También planifica subir profesiones con tus propios precios. **Nada se vende, se publica ni se envía sin tu clic.** La interfaz está en español e inglés y sigue el idioma del juego.

### Funciones

- **Consejo en cada objeto**: vender, subastar o guardar, con el motivo (lo usa tu profesión, un alt o una misión).
- **Panel del vendedor**: lo que conviene venderle, con botones Vender y Guardar.
- **Casa de subastas**: pestaña GoldFinder con Subastar en un clic. Si tu último escaneo es viejo, el primer clic revisa el precio en vivo y el segundo publica. Un panel lateral plegable reúne la navegación y las opciones, y el botón Scan muestra su progreso.
- **Correo** (apagado por defecto): envía al banquero lo que hay que subastar, con una casilla por objeto.
- **Bolsas**: botón X para ocultar un objeto de la lista (por personaje) y botón Ver para recuperarlo.
- **Compras**: lo que te falta de cada profesión, con botón Lista que lo manda a una lista de Auctionator, y una lista aparte por profesión.
- **Profesiones**: pestañas Ruta y Fabricar, chance de subir y coste por punto en cada receta, y una guía 1-300 con tus precios. Incluye Pesca y, con QuestieDB, dónde conseguir las recetas que se aprenden con un objeto.
- **Seguimiento**: tu siguiente paso de profesión en el seguimiento de objetivos.
- **Ventana de bienvenida**: se abre una sola vez la primera vez que entras y lista lo que hace el addon y qué funciones están activas.

### Instalar y actualizar

Instálalo desde [CurseForge](https://www.curseforge.com/wow/addons/goldfinder-forever) o copia la carpeta **`GoldFinderForever`** en `Interface/AddOns`. Requiere Auctionator; QuestieDB y TradeSkillMaster son opcionales. El comando principal es `/gff`: las opciones se abren con `/gff ajustes`, la guía con `/gff guia` y la bienvenida con `/gff bienvenida`.

Si vienes de la 2.2.x, la carpeta cambió de nombre: borra la carpeta `GoldFinder` antigua. Los datos guardados empiezan limpios en la 2.3.0.

### Avisar de un problema o sugerir algo

- **Fallos y sugerencias:** [abre una incidencia en GitHub](https://github.com/footox/GoldFinderForever/issues/new/choose). El formulario pide lo que hace falta y lleva un minuto.
- **Comentario rápido o duda:** los comentarios de la [página de CurseForge](https://www.curseforge.com/wow/addons/goldfinder-forever).

Para que un aviso sea fácil de atender: la **versión del addon** (sale en la lista de addons de la pantalla de personajes), **qué hiciste, qué esperabas y qué pasó**, una **captura del tooltip** del objeto con la línea de GoldFinder si es un consejo de precios, el **texto del error** tal cual (de BugGrabber o de la ventana de errores de Lua) y si tienes **Auctionator** y **TradeSkillMaster** cargados. El addon no envía nada desde el juego; no publiques contraseñas ni datos de cuenta, y no hacen falta los nombres de tus personajes.

El historial de versiones está en la sección **Changelog** de arriba y completo en [CHANGELOG.md](CHANGELOG.md).
