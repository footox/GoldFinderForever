-- core/scan.lua: the state of an auction scan shown by the Scan button and its progress bar. Pure: the previous state and
-- an event come in, the new state comes out.

local _, GF = ...

-- state = { on = scanning now, pct = 0..1, failed = bool }; kind = "start" | "progress" | "complete" | "failed";
-- value = the progress fraction Auctionator reports (0..1) for "progress".
function GF.ScanNext(state, kind, value)
  state = state or { on = false, pct = 0 }
  if kind == "start" then return { on = true, pct = 0 } end
  if kind == "progress" then
    local v = tonumber(value) or state.pct or 0
    return { on = true, pct = math.min(math.max(v, 0), 1) }
  end
  if kind == "complete" then return { on = false, pct = 1 } end
  if kind == "failed" then return { on = false, pct = 0, failed = true } end
  if kind == "stop" then return { on = false, pct = 0 } end   -- no news for a long time: clear the indicator, do not claim a failure
  return state
end

-- Whole percent for the label: 0-100, never 100 while the scan is still running.
function GF.ScanPercent(state)
  if not state then return 0 end
  local p = math.floor((state.pct or 0) * 100 + 0.5)
  if state.on and p >= 100 then p = 99 end
  return math.min(math.max(p, 0), 100)
end

-- The Auctionator frame that starts a scan, or nil when it does not exist. Auctionator builds these frames when the auction
-- house opens, so asking for one with the auction house closed gives nil. replicate: Auctionator's "replicate scan" option.
function GF.ScanFrameFor(state, replicate)
  if type(state) ~= "table" then return nil end
  local frame
  if replicate then frame = state.FullScanFrameRef else frame = state.IncrementalScanFrameRef end
  if (type(frame) == "table" or type(frame) == "userdata") and type(frame.InitiateScan) == "function" then return frame end
  return nil
end
