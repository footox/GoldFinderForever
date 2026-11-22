-- core/slash.lua: decides whether a slash command name is already owned by another addon, so ours never takes it over.



local _, GF = ...



-- true when another addon already registered the slash command `cmd` (for example "/gf"). slashCmdList is the

-- game's SlashCmdList, globals is _G (where SLASH_<KEY><n> live) and ownKey the key this addon registers under,

-- which is skipped.

function GF.CommandTaken(slashCmdList, globals, ownKey, cmd)

  cmd = tostring(cmd):lower()

  for key in pairs(slashCmdList or {}) do

    if key ~= ownKey then

      local i = 1

      while globals and globals["SLASH_" .. key .. i] do

        if tostring(globals["SLASH_" .. key .. i]):lower() == cmd then return true end

        i = i + 1

      end

    end

  end

  return false

end

-- Runs "/gff data <rest>" through the public API of the data addon (the global table GoldFinderForeverData).
-- Returns an array of chat lines, or nil and a reason: "missing" (addon or its Command function is not there) or
-- "failed" (it raised or returned something that is not a list). Only strings are kept, and at most MAX_LINES.
GF.DATA_MAX_LINES = 30
function GF.RunDataCommand(api, rest)
  if type(api) ~= "table" or type(api.Command) ~= "function" then return nil, "missing" end
  local ok, lines = pcall(api.Command, type(rest) == "string" and rest or "")
  if not ok or type(lines) ~= "table" then return nil, "failed" end
  local out = {}
  for _, line in ipairs(lines) do
    if type(line) == "string" then
      out[#out + 1] = line
      if #out >= GF.DATA_MAX_LINES then break end
    end
  end
  return out
end
