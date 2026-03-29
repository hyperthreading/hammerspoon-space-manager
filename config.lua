local json = require("hs.json")

local M = {}

M.hyper = { "ctrl", "alt", "shift", "cmd" }

-- Palette backend: "builtin" (hs.chooser) or "custom" (hs.webview)
M.paletteBackend = "custom"

M.keybindings = {
    switchToSpace = { key = "space" },
    focusWindow = { key = "s" },
    moveWindowToSpace = { key = "m" },
    renameSpace = { key = "r" },
}

-- Default space aliases (used as fallback)
local defaultSpaces = {
    { space = 1, name = "Browser", icon = "🌐" },
    { space = 2, name = "Slack", icon = "💬" },
    { space = 3, name = "Docs", icon = "📋" },
    { space = 4, name = "Misc", icon = "💤" },
    { space = 5, name = "Project 1", icon = "❤️" },
    { space = 6, name = "Project 2", icon = "🧡" },
    { space = 7, name = "Project 3", icon = "🧡" },
    { space = 8, name = "Project 4", icon = "🧡" },
    { space = 9, name = "Calendar & Inbox", icon = "📅" },
}

local savePath = hs.configdir .. "/space-names.json"

local function loadSavedNames()
    local f = io.open(savePath, "r")
    if not f then return {} end
    local content = f:read("*a")
    f:close()
    local ok, data = pcall(json.decode, content)
    if ok and data then return data end
    return {}
end

function M.saveSpaceNames()
    local overrides = {}
    for _, s in ipairs(M.spaces) do
        overrides[tostring(s.space)] = { name = s.name, icon = s.icon }
    end
    local f = io.open(savePath, "w")
    if f then
        f:write(json.encode(overrides))
        f:close()
    end
end

-- Initialize spaces: merge defaults with any saved overrides
local function initSpaces()
    local saved = loadSavedNames()
    local result = {}
    for _, def in ipairs(defaultSpaces) do
        local override = saved[tostring(def.space)]
        if override then
            table.insert(result, {
                space = def.space,
                name = override.name or def.name,
                icon = override.icon or def.icon,
            })
        else
            table.insert(result, { space = def.space, name = def.name, icon = def.icon })
        end
    end
    return result
end

M.spaces = initSpaces()

return M
