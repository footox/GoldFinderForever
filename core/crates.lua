-- core/crates.lua: the Waylaid Crates. Item ids of the crates (Apprentice to Artisan; herbs, ore, textiles, curiosities, fabrics,
-- ingots and parts), seen with their names on a real character. They serve Favor, so the addon must never advise selling
-- one. Pure data and one function. Ids that were not seen are not listed: add them only after seeing them in the game.

local _, GF = ...

GF.WAYLAID_CRATES = {
  [248682] = true, [248683] = true, [248684] = true, [248685] = true, [248686] = true, [248687] = true,
  [248688] = true, [248689] = true, [248690] = true, [248691] = true, [248692] = true, [248693] = true,
  [248694] = true, [248695] = true, [248696] = true, [248697] = true, [248698] = true, [248699] = true,
  [248702] = true, [248703] = true, [248704] = true, [248705] = true, [248706] = true, [248707] = true,
  [248708] = true, [248709] = true, [248710] = true, [248711] = true, [248712] = true, [248713] = true,
}

function GF.IsWaylaidCrate(id)
  return GF.WAYLAID_CRATES[id] == true
end
