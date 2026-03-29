-- Rename the current space via Hyper+R
-- Shows a text prompt pre-filled with the current name, saves to disk

local spaces = require("hs.spaces")
local dialog = require("hs.dialog")
local config = require("config")

local M = {}

local function getCurrentSpaceIndex()
    local screen = hs.screen.mainScreen()
    local currentSpaceId = spaces.activeSpaceOnScreen(screen)
    local allSpaces = spaces.spacesForScreen(screen:getUUID())
    for i, spaceId in ipairs(allSpaces) do
        if spaceId == currentSpaceId then
            return i
        end
    end
    return nil
end

local function findSpaceConfig(spaceNum)
    for _, s in ipairs(config.spaces) do
        if s.space == spaceNum then
            return s
        end
    end
    return nil
end

function M.renameCurrentSpace()
    local spaceIndex = getCurrentSpaceIndex()
    if not spaceIndex then
        hs.alert.show("Could not determine current space")
        return
    end

    local spaceConfig = findSpaceConfig(spaceIndex)
    local currentName = spaceConfig and spaceConfig.name or ("Space " .. spaceIndex)

    hs.focus()
    local button, newName = dialog.textPrompt(
        "Rename Space " .. spaceIndex,
        "Enter a new name for this space:",
        currentName,
        "OK",
        "Cancel"
    )

    if button == "OK" and newName and newName ~= "" then
        if spaceConfig then
            spaceConfig.name = newName
        end
        config.saveSpaceNames()
        hs.alert.show(spaceConfig.icon .. "  Space " .. spaceIndex .. " → " .. newName)
    end
end

function M.init()
    hs.hotkey.bind(config.hyper, config.keybindings.renameSpace.key, function()
        M.renameCurrentSpace()
    end)
end

return M
