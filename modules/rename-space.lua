-- Rename the current space via Hyper+R
-- Shows a text prompt pre-filled with the current name, saves to disk

local dialog = require("hs.dialog")
local config = require("config")

local M = {}

function M.renameCurrentSpace()
    local currentScreen = config.getCurrentScreen()
    config.refreshSpaces(currentScreen)
    local spaceConfig = config.getCurrentSpace(currentScreen)

    if not spaceConfig then
        hs.alert.show("Could not determine current space")
        return
    end

    local prevWindow = hs.window.focusedWindow()
    hs.focus()
    local button, newName = dialog.textPrompt(
        "Rename Space " .. spaceConfig.index,
        "Enter a new name for this space:",
        spaceConfig.name,
        "OK",
        "Cancel"
    )

    if prevWindow then prevWindow:focus() end

    if button == "OK" and newName and newName ~= "" then
        spaceConfig.name = newName
        config.saveSpaceNames()
        hs.alert.show(spaceConfig.icon .. "  Space " .. spaceConfig.index .. " → " .. newName)
    end
end

function M.init()
    hs.hotkey.bind(config.hyper, config.keybindings.renameSpace.key, function()
        M.renameCurrentSpace()
    end)
end

return M
