-- GoldFinderTrainers: instructores de profesion por rango, con zona y coordenadas, para sugerir alternativas
-- cercanas. Datos (hechos: nombre, zona, coordenadas) tomados de las guias de subida de Icy Veins para
-- WoW Forever (4-nov-2026). Clave = tope de habilidad que da el rango (75 Apprentice, 150 Journeyman,
-- 225 Expert, 300 Artisan). Cada lista: "Nombre|Zona|x|y;..." por facción (A Alianza, H Horda). Incluye
-- los instructores neutrales. Mineria, Desuello y Herboristeria usan la misma lista para 150, 225 y 300.
GoldFinderTrainers = {}

local SKIN_A = "Balthus Stoneflayer|Ironforge|39.6|32.6;Eladriel|Darnassus|64.2|21.8;Maris Granger|Stormwind City|67.8|49.0;Helene Peltskinner|Elwynn Forest|46.2|62.2;Radnaal Maneweaver|Teldrassil|42.0|50.0;Wilma Ranthal|Redridge Mountains|88.8|71.0;Jayla|Ashenvale|50.0|67.2;Mendalass Tattermend (Neutral)|Zephras Isle|43.2|43.4;Ishlee Breezewhisper (Neutral)|Zephras Isle|59.6|76.0"
local SKIN_H = "Thuwd|Orgrimmar|63.2|45.2;Mooranta|Thunder Bluff|44.6|43.0;Killian Hagey|Undercity|70.4|59.2;Yonn Deepcut|Mulgore|45.6|57.8;Rand Rhobart|Tirisfal Glades|65.6|60.0;Dranh|The Barrens|45.0|59.0;Malux|Desolace|23.2|69.8;Kulleg Stonehorn|Feralas|74.6|42.8;Mendalass Tattermend (Neutral)|Zephras Isle|43.2|43.4;Ishlee Breezewhisper (Neutral)|Zephras Isle|59.6|76.0"
local MINE_A = "Geofram Bouldertoe|Ironforge|50.2|26.0;Gelman Stonehand|Stormwind City|51.0|17.2;Yarr Hammerstone|Dun Morogh|50.0|50.4;Dank Drizzlecut|Dun Morogh|69.2|55.4;Brock Stoneseeker|Loch Modan|37.2|46.8;Kurdram Stonehammer|Darkshore|38.2|41.0;Matt Johnson|Duskwood|74.0|49.6;Messana Crestwind (Neutral)|Zephras Isle|44.8|44.4;Halavuul Cragwind (Neutral)|Zephras Isle|65.4|80.4;Pikkle (Neutral)|Tanaris|51.0|28.0;Grungle (Neutral)|Riverglades|77.6|51.8"
local MINE_H = "Makaru|Orgrimmar|73.0|26.4;Brek Stonehoof|Thunder Bluff|34.6|57.6;Brom Killian|Undercity|56.0|37.0;Krunn|Durotar|51.8|40.8;Johan Focht|Silverpine Forest|43.4|40.6;Messana Crestwind (Neutral)|Zephras Isle|44.8|44.4;Halavuul Cragwind (Neutral)|Zephras Isle|65.4|80.4;Pikkle (Neutral)|Tanaris|51.0|28.0;Grungle (Neutral)|Riverglades|77.6|51.8"
local HERB_A = "Firodren Mooncaller|Darnassus|48.0|68.4;Reyna Stonebranch|Ironforge|55.6|58.4;Tannysa|Stormwind City|44.8|77.0;Shylamiir|Stormwind City|15.2|49.8;Malorne Bladeleaf|Teldrassil|57.6|60.6;Herbalist Pomeroy|Elwynn Forest|39.8|48.4;Kali Healtouch|Loch Modan|36.6|48.4;Alma Jainrose|Redridge Mountains|21.8|45.8;Cylania Rootstalker|Ashenvale|50.6|67.0;Telurinon Moonshadow|Wetlands|8.0|55.8;Brant Jasperbloom|Dustwallow Marsh|64.0|47.6;Edward Egan|Alterac Mountains|18.4|63.2;Halassa Fernbreeze (Neutral)|Zephras Isle|43.0|43.6;Syriel Nightrain (Neutral)|Zephras Isle|57.8|75.4;Flora Silverwind (Neutral)|Stranglethorn Vale|27.6|77.8;Malvor (Neutral)|Moonglade|45.6|46.8"
local HERB_H = "Jandi|Orgrimmar|55.6|39.6;Komin Winterhoof|Thunder Bluff|49.8|39.8;Martha Alliestar|Undercity|54.6|50.4;Mishiki|Durotar|55.4|75.0;Faruza|Tirisfal Glades|59.8|52.0;Aranae Venomblood|Hillsbrad Foothills|61.6|19.6;Angrun|Stranglethorn Vale|32.2|27.6;Ruw|Feralas|76.0|43.4;Halassa Fernbreeze (Neutral)|Zephras Isle|43.0|43.6;Syriel Nightrain (Neutral)|Zephras Isle|57.8|75.4;Flora Silverwind (Neutral)|Stranglethorn Vale|27.6|77.8;Malvor (Neutral)|Moonglade|45.6|46.8"

GoldFinderTrainers.leatherworking = {
  [75] = {
    A = "Randal Worth|Stormwind City|67.4|49.4;Gretta Finespindle|Ironforge|39.0|32.4;Darianna|Darnassus|64.4|21.2;Adele Fielder|Elwynn Forest|46.4|62.2;Nadyia Maneweaver|Teldrassil|41.8|49.4;Waldor|The Barrens|51.8|55.4;Indari Sunseam|Zephras Isle|44.6|44.4",
    H = "Kamari|Orgrimmar|63.0|45.0;Thuwd|Orgrimmar|63.2|45.2;Dan Golthas|Undercity|70.4|58.4;Mak|Thunder Bluff|42.2|43.2;Chaw Stronghide|Mulgore|45.0|61.4;Shelene Rhobart|Tirisfal Glades|65.4|60.0;Waldor|The Barrens|51.8|55.4;Indari Sunseam|Zephras Isle|44.6|44.4",
  },
  [150] = {
    A = "Simon Tanner|Stormwind City|67.2|49.4;Fimble Finespindle|Ironforge|39.4|33.0;Faldron|Darnassus|64.4|21.4;Aayndia Floralwind|Ashenvale|35.8|52.0;Emerii Tallgust|Zephras Isle|63.8|80.4",
    H = "Karolek|Orgrimmar|62.8|44.4;Arthur Moore|Undercity|70.6|57.8;Tarn|Thunder Bluff|42.4|43.0;Brawn|Stranglethorn Vale|31.6|28.8;Krulmoo Fullmoon|The Barrens|44.8|59.4;Narv Hidecrafter|Desolace|55.2|56.2;Emerii Tallgust|Zephras Isle|63.8|80.4",
  },
  [225] = { A = "Telonis|Darnassus|64.4|21.4", H = "Una|Thunder Bluff|41.4|42.6" },
  [300] = { A = "Drakk Stonehand|The Hinterlands|13.4|43.4", H = "Hahrana Ironhide|Feralas|74.4|43.0" },
}

GoldFinderTrainers.tailoring = {
  [75] = {
    A = "Lawrence Schneider|Stormwind City|43.6|73.8;Uthrar Threx|Ironforge|43.6|28.2;Trianna|Darnassus|63.6|21.6;Eldrin|Elwynn Forest|79.2|69.0;Grondal Moonbreeze|Darkshore|38.2|40.6",
    H = "Snang|Orgrimmar|63.0|49.6;Victor Ward|Undercity|70.2|29.6;Vhan|Thunder Bluff|44.0|44.6;Bowen Brisboise|Tirisfal Glades|52.6|55.6;Kil'hala|The Barrens|52.2|31.6",
  },
  [150] = {
    A = "Sellandus|Stormwind City|42.0|76.2;Jormund Stonebrow|Ironforge|43.6|28.2;Me'lynn|Darnassus|62.6|22.6;Grarnik Goodstitch|Stranglethorn Vale|28.6|76.8;Taleen Shimmerthread|Zephras Isle|44.8|44.2;Othesia Evengale|Zephras Isle|64.4|81.0",
    H = "Magar|Orgrimmar|63.4|50.0;Rhiannon Davis|Undercity|70.6|29.6;Tepa|Thunder Bluff|44.2|45.0;Mahani|The Barrens|44.8|59.4;Grarnik Goodstitch|Stranglethorn Vale|28.6|76.8;Taleen Shimmerthread|Zephras Isle|44.8|44.2;Othesia Evengale|Zephras Isle|64.4|81.0",
  },
  [225] = { A = "Georgio Bolero|Stormwind City|43.2|73.6;Charles Worth|Alterac Mountains|17.8|60.6", H = "Josef Gregorian|Undercity|70.6|30.6" },
  [300] = { A = "Timothy Worthington|Dustwallow Marsh|66.2|51.6", H = "Daryl Stack|Hillsbrad Foothills|63.6|20.8" },
}

GoldFinderTrainers.skinning = {
  [150] = { A = SKIN_A, H = SKIN_H }, [225] = { A = SKIN_A, H = SKIN_H }, [300] = { A = SKIN_A, H = SKIN_H },
}
GoldFinderTrainers.mining = {
  [150] = { A = MINE_A, H = MINE_H }, [225] = { A = MINE_A, H = MINE_H }, [300] = { A = MINE_A, H = MINE_H },
}
GoldFinderTrainers.herbalism = {
  [150] = { A = HERB_A, H = HERB_H }, [225] = { A = HERB_A, H = HERB_H }, [300] = { A = HERB_A, H = HERB_H },
}

-- Pesca: solo el rango Journeyman es de instructor (Expert es un libro y Artisan es Nat Pagle).
GoldFinderTrainers.fishing = {
  [150] = {
    A = "Androl Oakhand|Teldrassil|55.8|93.6;Arnold Leland|Stormwind City|55.0|69.6;Astaia|Darnassus|47.6|56.6;Brannock|Feralas|32.2|41.6;Donald Rabonne|Hillsbrad Foothills|50.6|61.0;Grimnur Stonebrand|Ironforge|48.4|6.4;Harold Riggs|Wetlands|8.2|58.6;Hunter Moore|Hillsbrad Foothills|54.0|80.2;Lee Brown|Elwynn Forest|47.6|62.2;Matthew Hooper|Redridge Mountains|26.8|50.4;Paxton Ganter|Dun Morogh|35.6|40.4;Warg Deepwater|Loch Modan|40.6|39.6;Baelann Swiftcurrent (Neutral)|Zephras Isle|63.2|75.6;Fenn Fairweather (Neutral)|Zephras Isle|45.0|48.4;Krix (Neutral)|Riverglades|79.2|54.8;Myizz Luckycatch (Neutral)|Stranglethorn Vale|27.6|77.0",
    H = "Armand Cromwell|Undercity|80.8|31.2;Clyde Kellen|Tirisfal Glades|67.2|51.0;Kah Mistrunner|Thunder Bluff|56.0|46.8;Katoom the Angler|The Hinterlands|80.2|81.4;Kil'Hiwana|Ashenvale|10.8|33.6;Lau'Tiki|Durotar|53.2|81.6;Lui'Mala|Desolace|22.6|72.6;Lumak|Orgrimmar|69.8|29.6;Uthan Stillwater|Mulgore|44.6|60.6;Baelann Swiftcurrent (Neutral)|Zephras Isle|63.2|75.6;Fenn Fairweather (Neutral)|Zephras Isle|45.0|48.4;Krix (Neutral)|Riverglades|79.2|54.8;Myizz Luckycatch (Neutral)|Stranglethorn Vale|27.6|77.0",
  },
}
