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
- **Shopping**: what you are missing for each profession, with a List button that sends it (exact names and quantities) to an Auctionator shopping list, plus one list per profession.
- **Professions**: Route and Craft tabs in the professions window, skill-up chance and cost per point on each recipe, and a 1-300 guide with your own prices. It includes Fishing and, with QuestieDB, where to get the recipes that are taught by an item.
- **Tracking**: your next profession step in the objective tracker, with the icon of each material, the cost of what you are missing and the skill-up chance per craft.
- **Welcome window**: opens once the first time you log in and lists what the addon does and which features are on.

## Requirements and install

| | |
|---|---|
| Client | WoW: Forever (Interface `16001`) |
| Required | [Auctionator](https://www.curseforge.com/wow/addons/auctionator) for auction prices |
| Optional | QuestieDB (quest items and recipe sources), TradeSkillMaster (market prices) |

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

## Known limitations

- It is made for WoW: Forever; other clients are not tested.
- Auction prices come from Auctionator. Without a scan there are no prices to advise with.
- The route planner is greedy: it picks the cheapest useful craft for each skill point, which is not a proven global optimum.
- Fishing zones by skill range come from community guides and are not verified by the addon.
- The live price check at posting time reads the first rows of the auction results only.

## Changelog

<!-- changelog:start -->

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

<details>
<summary>Older versions (2.2.0 to 2.0)</summary>

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

El historial de versiones está en la sección **Changelog** de arriba y completo en [CHANGELOG.md](CHANGELOG.md).
