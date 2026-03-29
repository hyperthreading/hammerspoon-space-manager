local fuzzy = require("lib.fuzzy")

local M = {}

--- Create a fuzzy-searchable command palette.
---
--- @param opts table
---   - placeholder (string): placeholder text
---   - buildChoices (function): returns list of chooser items, each with _searchKeys
---   - onSelect (function): called with the selected choice
---   - searchKeys (table): list of item field names to fuzzy match against
--- @return hs.chooser
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

--- Create and bind a palette to a hotkey.
--- Same opts as create(), plus:
---   - mods (table): modifier keys
---   - key (string): key to bind
---   - onOpen (function, optional): called before the palette is shown
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
