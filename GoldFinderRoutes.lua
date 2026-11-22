-- GoldFinderRoutes: rutas alternativas de subida de profesion para comparar costes con los precios de la subasta.
-- Datos (hechos: que fabricar, cuantas unidades, materiales y zonas) tomados de las guias de Icy Veins para
-- WoW Forever (4-nov-2026): Peleteria, Mineria y Herboristeria. Cada paso: from/to = tramo de habilidad,
-- mats = { {objeto, cantidad, [desde que habilidad cuenta]} }, makes = lo que el paso produce y se gasta despues.
-- zones = zonas sugeridas por tramo. Los curtidos, cinturones y barras intermedios se expresan en materiales
-- base. Es una estimacion.
-- Objetos: 2318 Light Leather, 2319 Medium Leather, 4234 Heavy Leather, 4304 Thick Leather, 783 Light Hide,
-- 4232 Medium Hide, 4235 Heavy Hide, 4289 Salt, 2320 Coarse Thread, 2321 Fine Thread, 4291 Silken Thread,
-- 4340 Gray Dye, 2770 Copper Ore, 2771 Tin Ore, 2841 Bronze Bar.
GoldFinderRoutes = {
  leatherworking = {
    {
      name = "Icy Veins",
      steps = {
        { from = 1,   to = 30,  what = "Light Armor Kit",          mats = { { 2318, 29 } } },
        { from = 30,  to = 55,  what = "Cured Light Hide",         mats = { { 783, 27 }, { 4289, 27 } } },
        { from = 55,  to = 75,  what = "Embossed Leather Gloves",  mats = { { 2318, 63 }, { 2320, 42 } } },
        { from = 75,  to = 80,  what = "Medium Leather",           mats = { { 2318, 32 } }, makes = { { 2319, 8 } } },
        { from = 80,  to = 90,  what = "Cured Medium Hide",        mats = { { 4232, 10 }, { 4289, 10 } } },
        { from = 90,  to = 100, what = "Fine Leather Belt",        mats = { { 2318, 96 }, { 2320, 32 } } },
        { from = 100, to = 115, what = "Light Leather Pants",      mats = { { 2318, 220 }, { 2321, 22 }, { 783, 22, 55 }, { 4289, 22, 55 } } },
        { from = 115, to = 125, what = "Dark Leather Belt",
          mats = { { 2321, 20 }, { 4340, 10 }, { 2318, 60, 90 }, { 2320, 20, 90 }, { 4232, 10, 90 }, { 4289, 10, 90 } } },
        { from = 125, to = 130, what = "Heavy Leather",            mats = { { 2319, 35 } }, makes = { { 4234, 7 } } },
        { from = 130, to = 130, what = "Cured Heavy Hide",         mats = { { 4235, 20 }, { 4289, 60 } } },
        { from = 130, to = 150, what = "Heavy Armor Kit",          mats = { { 4234, 45 }, { 2321, 9 } } },
        { from = 150, to = 155, what = "Heavy Armor Kit",          mats = { { 4234, 40 }, { 2321, 8 } } },
        { from = 155, to = 165, what = "Barbaric Shoulders",
          mats = { { 4234, 80 }, { 2321, 20 }, { 4235, 10, 130 }, { 4289, 30, 130 } } },
        { from = 165, to = 175, what = "Guardian Gloves",
          mats = { { 4234, 40 }, { 4291, 10 }, { 4235, 10, 130 }, { 4289, 30, 130 } } },
        { from = 175, to = 195, what = "Thick Armor Kit",          mats = { { 4304, 100 }, { 4291, 20 } } },
        { from = 195, to = 210, what = "Nightscape Headband",      mats = { { 4304, 100 }, { 4291, 40 } } },
        { from = 210, to = 225, what = "Nightscape Pants",         mats = { { 4304, 210 }, { 4291, 60 } } },
      },
    },
  },

  -- Mineria: de 1 a 105 se puede subir FUNDIENDO mineral comprado en lugar de minarlo (cobre hasta 65,
  -- estano de 65 a 75 y bronce hasta unos 105). El bronce que sale (140 barras) se puede vender.
  mining = {
    {
      name = "Icy Veins (fundir)",
      steps = {
        { from = 1,  to = 65,  what = "Smelt Copper", mats = { { 2770, 65 } } },
        { from = 65, to = 75,  what = "Smelt Tin",    mats = { { 2771, 70 } } },
        { from = 75, to = 105, what = "Smelt Bronze", mats = { { 2770, 70 } }, makes = { { 2841, 140 } } },
      },
      zones = {
        { from = 1,   to = 65,  zone = "Durotar, Mulgore, Tirisfal Glades o Zephras Isle", note = "cobre" },
        { from = 65,  to = 125, zone = "Silverpine Forest, Hillsbrad Foothills, The Barrens, Ashenvale o Stonetalon Mountains", note = "estano y plata" },
        { from = 125, to = 175, zone = "Thousand Needles, Arathi Highlands o Desolace", note = "hierro; oro desde 155" },
        { from = 175, to = 225, zone = "The Hinterlands o Tanaris", note = "mithril desde 175" },
        { from = 225, to = 245, zone = "The Hinterlands o Tanaris", note = "mithril; truesilver desde 230" },
        { from = 245, to = 275, zone = "Un'Goro Crater o Felwood", note = "Small Thorium" },
        { from = 275, to = 300, zone = "Winterspring o Eastern Plaguelands", note = "Rich Thorium desde 275" },
      },
    },
  },

  herbalism = {
    {
      name = "Icy Veins",
      steps = {},
      zones = {
        { from = 1,   to = 70,  zone = "Durotar, Mulgore, Tirisfal Glades o Zephras Isle", note = "Peacebloom, Silverleaf; Earthroot desde 15" },
        { from = 70,  to = 115, zone = "The Barrens o Silverpine Forest", note = "Mageroyal, Briarthorn; Stranglekelp 85; Bruiseweed 100" },
        { from = 115, to = 170, zone = "Hillsbrad Foothills o Stonetalon Mountains", note = "Wild Steelbloom; Kingsblood 125; Liferoot 150" },
        { from = 170, to = 205, zone = "Arathi Highlands o Stranglethorn Vale", note = "Goldthorn, Fadeleaf; Khadgar's Whisker 185" },
        { from = 205, to = 230, zone = "Tanaris, Searing Gorge o Alterac Mountains", note = "Firebloom 205; Purple Lotus 210" },
        { from = 230, to = 270, zone = "Feralas o The Hinterlands", note = "Sungrass; Ghost Mushroom 245; Golden Sansam 260" },
        { from = 270, to = 300, zone = "Felwood o Eastern Plaguelands", note = "Dreamfoil 270; Mountain Silversage 280; Plaguebloom 285" },
      },
    },
  },
  -- Desuello: solo zonas por tramo (no hay materiales que comprar). Regla: una bestia pide su nivel x 5 de Desuello.
  skinning = {
    {
      name = "Icy Veins",
      steps = {},
      zones = {
        { from = 1,   to = 75,  zone = "Durotar, Mulgore, Tirisfal Glades o Elwynn Forest", note = "incluso las bestias de nivel 1 dan habilidad" },
        { from = 75,  to = 125, zone = "The Barrens o Loch Modan", note = "bestias de nivel 16-18" },
        { from = 125, to = 150, zone = "Hillsbrad Foothills o Wetlands", note = "leones, osos y raptores" },
        { from = 150, to = 185, zone = "Thousand Needles o Arathi Highlands", note = "basiliscos y tortugas; sube con el nivel de la bestia" },
        { from = 185, to = 225, zone = "Dustwallow Marsh, Badlands o Stranglethorn Vale", note = "bestias hasta nivel 39" },
        { from = 225, to = 250, zone = "Tanaris o Feralas", note = "bestias hasta nivel 47" },
        { from = 250, to = 275, zone = "Un'Goro Crater o Felwood", note = "ravasaurios" },
        { from = 275, to = 300, zone = "Western Plaguelands o Winterspring", note = "lobos, osos y felinos" },
      },
    },
  },
  -- Pesca: solo zonas por tramo. Fuentes: guias de WoW Forever de wow-professions.com y warcrafttavern.com
  -- (22-nov-2026); donde difieren se usa la de wow-professions.com. Hechos sueltos (zonas y tramos), sin texto copiado.
  fishing = {
    {
      name = "Forever guides",
      steps = {},
      zones = {
        { from = 1, to = 75, zone = "Durotar, Mulgore, Tirisfal Glades, Elwynn Forest o Dun Morogh", note = "cualquier lago, rio o costa; Fishing Pole y Shiny Bauble" },
        { from = 75, to = 150, zone = "The Barrens, Darkshore, Loch Modan, Silverpine Forest o Westfall", note = "tambien sirven las ciudades principales (no Undercity); Nightcrawlers si se escapan" },
        { from = 150, to = 225, zone = "Dustwallow Marsh, Desolace, Arathi Highlands o Stranglethorn Vale", note = "Bright Baubles; el libro de Experto se compra en Booty Bay" },
        { from = 225, to = 300, zone = "Feralas, Tanaris o Un'Goro Crater", note = "Bright Baubles; Artesano: mision de Nat Pagle en Dustwallow Marsh (habilidad 225)" },
      },
    },
  },
}
