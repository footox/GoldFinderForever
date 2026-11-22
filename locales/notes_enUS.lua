-- locales/notes_enUS.lua: English text for the zone notes stored (in Spanish) in the data files GoldFinderRoutes.lua and
-- GoldFinderGuides.lua. Key = the note exactly as written in the data, value = what an English UI shows. A note that is
-- only item names (for example "Dreamfoil 270; Plaguebloom 285") needs no entry. tests/notes_test.lua fails if a note in
-- the data has neither an entry here nor a place in its list of names-only notes.

local _, GF = ...

GF.NotesEN = {
  ["Bright Baubles; Artesano: mision de Nat Pagle en Dustwallow Marsh (habilidad 225)"] =
    "Bright Baubles; Artisan: Nat Pagle's quest in Dustwallow Marsh (skill 225)",
  ["Bright Baubles; el libro de Experto se compra en Booty Bay"] = "Bright Baubles; the Expert book is sold in Booty Bay",
  ["Peacebloom, Silverleaf; Earthroot desde 15"] = "Peacebloom, Silverleaf; Earthroot from 15",
  ["Rich Thorium desde 275"] = "Rich Thorium from 275",
  ["basiliscos y tortugas; sube con el nivel de la bestia"] = "basilisks and turtles; it scales with the beast's level",
  ["bestias de nivel 16-18"] = "level 16-18 beasts",
  ["bestias hasta nivel 39"] = "beasts up to level 39",
  ["bestias hasta nivel 47"] = "beasts up to level 47",
  ["cobre"] = "copper",
  ["cualquier lago, rio o costa; Fishing Pole y Shiny Bauble"] = "any lake, river or coast; Fishing Pole and Shiny Bauble",
  ["estano y plata"] = "tin and silver",
  ["hierro; oro desde 155"] = "iron; gold from 155",
  ["incluso las bestias de nivel 1 dan habilidad"] = "even level 1 beasts give skill",
  ["leones, osos y raptores"] = "lions, bears and raptors",
  ["lobos, osos y felinos"] = "wolves, bears and cats",
  ["mithril desde 175"] = "mithril from 175",
  ["mithril; truesilver desde 230"] = "mithril; truesilver from 230",
  ["ravasaurios"] = "ravasaurs",
  ["tambien sirven las ciudades principales (no Undercity); Nightcrawlers si se escapan"] =
    "the main cities work too (not Undercity); Nightcrawlers if they get away",
}
