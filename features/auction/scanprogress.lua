-- features/auction/scanprogress.lua: listens to Auctionator's scan events (the same EventBus its own API uses for
-- RegisterForDBUpdate) and reports the state of the scan to the windows. Everything is guarded: without Auctionator or
-- without those events nothing happens and the Scan button works as before.

local _, GF = ...

GF.ScanProgress = {}

local started = false
local state = { on = false, pct = 0 }
local serial = 0
local STALE = 150   -- seconds without news: the scan is assumed dead and the indicator is cleared

-- onChange(state) runs on every change. Returns true if the events could be registered.
function GF.ScanProgress.Start(onChange)
  if started then return true end
  local A = rawget(_G, "Auctionator")
  if not (type(A) == "table" and A.EventBus and A.EventBus.Register) then return false end
  local groups = { A.FullScan and A.FullScan.Events, A.IncrementalScan and A.IncrementalScan.Events }
  local kinds, names = {}, {}
  for _, ev in ipairs(groups) do
    if type(ev) == "table" then
      for kind, key in pairs({ start = "ScanStart", progress = "ScanProgress", complete = "ScanComplete", failed = "ScanFailed" }) do
        local name = ev[key]
        if name then kinds[name] = kind; names[#names + 1] = name end
      end
    end
  end
  if #names == 0 then return false end
  local listener = {
    ReceiveEvent = function(_, name, value)
      local kind = kinds[name]
      if not kind then return end
      state = GF.ScanNext(state, kind, value)
      serial = serial + 1
      local mine = serial
      if state.on and C_Timer and C_Timer.After then
        C_Timer.After(STALE, function()
          if serial == mine and state.on then
            state = GF.ScanNext(state, "stop")
            pcall(onChange, state)
          end
        end)
      end
      pcall(onChange, state)
    end,
  }
  local ok = pcall(A.EventBus.Register, A.EventBus, listener, names)
  started = ok
  -- Closing the auction house mid-scan leaves Auctionator without a ScanComplete: clear the indicator right away
  -- instead of waiting for STALE (a scan that continues after reopening reports progress again by itself).
  if ok and type(CreateFrame) == "function" then
    local closer = CreateFrame("Frame")
    closer:RegisterEvent("AUCTION_HOUSE_CLOSED")
    closer:SetScript("OnEvent", function()
      if state.on then
        serial = serial + 1
        state = GF.ScanNext(state, "stop")
        pcall(onChange, state)
      end
    end)
  end
  return ok
end

function GF.ScanProgress.State() return state end
