-- Switch to a space by alias
-- Command palette with fuzzy search

local eventtap = require("hs.eventtap")
local config = require("config")
local palette = require("lib.palette")

local M = {}

function M.switchToSpace(n)
    eventtap.keyStroke({ "ctrl" }, tostring(n))
end

-- Command palette for switching Spaces
function M.bindPalette()
    palette.bind({
        mods = config.hyper,
        key = config.keybindings.switchToSpace.key,
        placeholder = "Switch to…",
        searchKeys = { "_name", "_spaceStr" },
        buildChoices = function()
            local items = {}
            for _, alias in ipairs(config.spaces) do
                table.insert(items, {
                    text = alias.icon .. "  " .. alias.name,
                    subText = "Switch to Space " .. alias.space,
                    space = alias.space,
                    _name = alias.name,
                    _spaceStr = tostring(alias.space),
                })
            end
            return items
        end,
        onSelect = function(choice) M.switchToSpace(choice.space) end,
    })
end

function M.init()
    M.bindPalette()
end

return M
