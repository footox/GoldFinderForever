-- Offline tests for MailPlan (Lua 5.1): attachment plan of one mail for the "Enviar al banquero" button
-- (max 12 whole stacks, never below the reserve, locked/bound slots skipped, remaining mails). Run from the addon folder:
--   "C:\Program Files (x86)\Lua\5.1\lua.exe" tests\mail_plan_test.lua

local src = assert(io.open("GoldFinder.lua")):read("*a")
local a = assert(src:find("-- PLAN DE CORREO", 1, true), "start marker")
local b = assert(src:find("-- FIN DE PLAN DE CORREO", 1, true), "end marker")
local chunk = src:sub(a, b - 1) .. "\nreturn MailPlan"
local f = assert(loadstring(chunk))
setfenv(f, setmetatable({}, { __index = _G }))
local MailPlan = f()

local failures = 0
local function check(name, cond)
  if cond then print("PASS " .. name) else print("FAIL " .. name); failures = failures + 1 end
end
local function S(bag, slot, id, count, locked, bound)
  return { bag = bag, slot = slot, id = id, count = count, locked = locked, bound = bound }
end
local function units(p, id)
  local n = 0
  for _, s in ipairs(p.attach) do if s.id == id then n = n + s.count end end
  return n
end

-- whole stacks within the surplus: 20 + 5 = 25, the second 20 would leave the reserve short
local p = MailPlan({ S(0, 1, 100, 20), S(0, 2, 100, 20), S(0, 3, 100, 5) }, { [100] = 25 }, 12)
check("whole stacks up to the surplus (25)", units(p, 100) == 25 and #p.attach == 2)
check("stack over the surplus is skipped", #p.skipped == 1 and p.skipped[1].count == 20
  and p.skipped[1].why == "no se envia: quedaria por debajo de la reserva")
check("totals: stacks and units", p.stacks == 2 and p.units == 25)
check("one mail: no mails remain", p.remaining == 0)

-- never reserved units: surplus smaller than every stack sends nothing of that item
p = MailPlan({ S(0, 1, 100, 20) }, { [100] = 10 }, 12)
check("no partial stacks: nothing attached", #p.attach == 0 and #p.skipped == 1)

-- items without surplus are not touched nor listed
p = MailPlan({ S(0, 1, 200, 5), S(0, 2, 100, 1) }, { [100] = 1 }, 12)
check("item not in the surplus is ignored", #p.attach == 1 and p.attach[1].id == 100 and #p.skipped == 0)
p = MailPlan({ S(0, 1, 100, 5) }, { [100] = 0 }, 12)
check("surplus 0: nothing", #p.attach == 0 and #p.skipped == 0)

-- max 12 attachments; the rest goes in the next mails
local slots = {}
for i = 1, 30 do slots[#slots + 1] = S(1, i, 300, 1) end
p = MailPlan(slots, { [300] = 30 }, 12)
check("max 12 stacks per mail", #p.attach == 12 and p.units == 12)
check("30 stacks: 2 more mails", p.remaining == 2)
p = MailPlan(slots, { [300] = 24 }, 12)
check("24 of 30 within surplus: 1 more mail, 6 skipped", #p.attach == 12 and p.remaining == 1 and #p.skipped == 6)

-- locked and bound slots are skipped with their reason and do not count toward the surplus
p = MailPlan({ S(0, 1, 100, 5, true), S(0, 2, 100, 5) }, { [100] = 5 }, 12)
check("locked slot skipped", #p.attach == 1 and p.attach[1].slot == 2 and #p.skipped == 1
  and p.skipped[1].why:find("bloqueado", 1, true) ~= nil)
p = MailPlan({ S(0, 1, 100, 5, false, true) }, { [100] = 5 }, 12)
check("bound slot skipped", #p.attach == 0 and p.skipped[1].why:find("ligado", 1, true) ~= nil)

-- bigger stacks first, so the surplus is filled with fewer attachments; plan keeps bag and slot
p = MailPlan({ S(0, 1, 100, 1), S(2, 7, 100, 10) }, { [100] = 10 }, 12)
check("biggest stack first", #p.attach == 1 and p.attach[1].bag == 2 and p.attach[1].slot == 7)
check("small stack skipped when the big one fills the surplus", #p.skipped == 1 and p.skipped[1].count == 1)

-- defaults and empty input
p = MailPlan({}, {}, nil)
check("empty bags: empty plan", #p.attach == 0 and #p.skipped == 0 and p.remaining == 0 and p.stacks == 0)
slots = {}
for i = 1, 13 do slots[#slots + 1] = S(1, i, 300, 1) end
p = MailPlan(slots, { [300] = 13 })
check("default max is 12", #p.attach == 12 and p.remaining == 1)

print(failures == 0 and "ALL PASS" or (failures .. " FAILED"))
if failures > 0 then os.exit(1) end
