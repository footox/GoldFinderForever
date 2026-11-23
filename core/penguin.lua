-- core/penguin.lua: the penguin winks. Short, optional phrases (a chat line now and then at login, the /gff penguin command and
-- the line printed when a scan starts). The phrases live in the locale files as numbered keys: "penguin.hello.1",
-- "penguin.hello.2"... One function picks one of them; the random choice is injected so the tests are deterministic.

local _, GF = ...

-- group: "penguin.hello", "penguin.cmd" or "penguin.scan". rnd(n) -> 1..n (default math.random). nil when the group has no phrase.
-- The number of phrases is read from the English table (the base), the text from the active language (with English fallback).
function GF.PenguinPhrase(group, rnd)
  local base = GF.locales and GF.locales.enUS or {}
  local n = 0
  while base[group .. "." .. (n + 1)] do n = n + 1 end
  if n == 0 then return nil end
  local k = (rnd or math.random)(n)
  if type(k) ~= "number" or k < 1 or k > n then k = 1 end
  return GF.L[group .. "." .. math.floor(k)]
end

-- A greeting at login: only when the option is on, never on the very first run (the welcome window is there) and one login in four.
function GF.PenguinLoginDue(optionOn, firstRun, rnd)
  if not optionOn or firstRun then return false end
  return (rnd or math.random)(4) == 1
end
