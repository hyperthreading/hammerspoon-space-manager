-- Switch to a space by alias
-- Command palette with fuzzy search

local spaces = require("hs.spaces")
local config = require("config")
local palette = require("lib.palette")

local M = {}

function M.switchToSpace(spaceId)
    local ok, err = spaces.gotoSpace(spaceId)
    if not ok then
        hs.alert.show(err or "Could not switch spaces")
    end
end

-- Command palette for switching Spaces
function M.bindPalette()
    palette.bind({
        mods = config.hyper,
        key = config.keybindings.switchToSpace.key,
        placeholder = "Switch to…",
        searchKeys = { "_name", "_spaceStr", "subText" },
        buildChoices = function()
            local items = {}

            for _, alias in ipairs(config.refreshSpaces()) do
                table.insert(items, {
                    text = alias.name,
                    subText = "Switch to Space " .. alias.index,
                    icon = alias.icon,
                    iconType = "text",
                    id = alias.id,
                    _name = alias.name,
                    _spaceStr = tostring(alias.index),
                })
            end

            return items
        end,
        initialSelection = function(choices)
            local current = config.getCurrentSpace()
            if not current then return nil end
            for i, choice in ipairs(choices) do
                if choice.id == current.id then return i end
            end
            return nil
        end,
        onSelect = function(choice) M.switchToSpace(choice.id) end,
    })
end

function M.init()
    M.bindPalette()
end

return M
