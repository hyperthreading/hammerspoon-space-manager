-- Built-in command palette using hs.chooser
-- Original implementation extracted from lib/palette.lua

local fuzzy = require("lib.fuzzy")

local M = {}

function M.create(opts)
  local chooser = hs.chooser.new(function(choice)
    if not choice then return end
    opts.onSelect(choice)
  end)

  chooser:placeholderText(opts.placeholder or "Search…")

  chooser:queryChangedCallback(function(query)
    local choices = opts.buildChoices()
    chooser:choices(fuzzy.filter(choices, query, opts.searchKeys or { "_name" }))
  end)

  return chooser
end

function M.bind(opts)
  local chooser = M.create(opts)
  hs.hotkey.bind(opts.mods, opts.key, function()
    if opts.onOpen then opts.onOpen() end
    chooser:choices(opts.buildChoices())
    chooser:show()
  end)
  return chooser
end

return M
