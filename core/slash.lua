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

