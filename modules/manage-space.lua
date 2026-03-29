-- Add and remove spaces dynamically.
-- Space aliases are refreshed by space ID so palette entries survive index shifts.

local spaces = require("hs.spaces")
local dialog = require("hs.dialog")
local config = require("config")

local M = {}

local state = {
    pendingRemoveWatcher = nil,
    spaceWatcher = nil,
}

local function currentScreen()
    return config.getCurrentScreen()
end

local function currentScreenSpaces(screen)
    return config.refreshSpaces(screen)
end

local function formatSpaceLabel(spaceEntry)
    if not spaceEntry then
        return "Space"
    end

    return string.format("%s  %s", spaceEntry.icon, spaceEntry.name)
end

local function confirmRemoval(spaceEntry)
    local prevWindow = hs.window.focusedWindow()
    hs.focus()

    local choice = dialog.blockAlert(
        "Delete Space " .. spaceEntry.index,
        "Remove \"" .. spaceEntry.name .. "\"?\nmacOS will move any remaining windows to another Space.",
        "Delete",
        "Cancel",
        "critical"
    )

    if prevWindow then prevWindow:focus() end

    return choice == "Delete"
end

local function stopPendingRemoveWatcher()
    if state.pendingRemoveWatcher then
        state.pendingRemoveWatcher:stop()
        state.pendingRemoveWatcher = nil
    end
end

function M.addSpace(target)
    local screen = target or currentScreen()
    if not screen then
        hs.alert.show("Could not determine current screen")
        return
    end

    local before = currentScreenSpaces(screen)
    local knownIds = {}
    for _, spaceEntry in ipairs(before) do
        knownIds[spaceEntry.id] = true
    end

    local ok, err = spaces.addSpaceToScreen(screen)
    if not ok then
        hs.alert.show(err or "Could not add space")
        return
    end

    local after = currentScreenSpaces(screen)
    local addedSpace = nil

    for _, spaceEntry in ipairs(after) do
        if not knownIds[spaceEntry.id] then
            addedSpace = spaceEntry
            break
        end
    end

    config.saveSpaceNames()
    hs.alert.show("Added " .. formatSpaceLabel(addedSpace))
end

function M.removeCurrentSpace(target)
    local screen = target or currentScreen()
    if not screen then
        hs.alert.show("Could not determine current screen")
        return
    end

    local screenSpaces = currentScreenSpaces(screen)
    if #screenSpaces < 2 then
        hs.alert.show("Cannot remove the only Space")
        return
    end

    local currentSpace = config.getCurrentSpace(screen)
    if not currentSpace then
        hs.alert.show("Could not determine current space")
        return
    end

    if not confirmRemoval(currentSpace) then
        return
    end

    local targetSpace = screenSpaces[currentSpace.index - 1] or screenSpaces[currentSpace.index + 1]
    if not targetSpace then
        hs.alert.show("Could not find another Space to switch to")
        return
    end

    stopPendingRemoveWatcher()
    state.pendingRemoveWatcher = spaces.watcher.new(function()
        local activeSpace = spaces.activeSpaceOnScreen(screen)
        if not activeSpace or activeSpace == currentSpace.id then
            return
        end

        stopPendingRemoveWatcher()
        hs.timer.doAfter(0.2, function()
            local ok, err = spaces.removeSpace(currentSpace.id)
            if not ok then
                hs.alert.show(err or "Could not remove space")
                return
            end

            currentScreenSpaces(screen)
            config.saveSpaceNames()
            hs.alert.show("Removed " .. formatSpaceLabel(currentSpace))
        end)
    end)
    state.pendingRemoveWatcher:start()

    local ok, err = spaces.gotoSpace(targetSpace.id)
    if not ok then
        stopPendingRemoveWatcher()
        hs.alert.show(err or "Could not switch spaces")
    end
end

function M.bindHotkeys()
    hs.hotkey.bind(config.hyper, config.keybindings.addSpace.key, function()
        M.addSpace()
    end)

    hs.hotkey.bind(config.hyper, config.keybindings.removeSpace.key, function()
        M.removeCurrentSpace()
    end)
end

function M.startWatcher()
    if state.spaceWatcher then
        return
    end

    state.spaceWatcher = spaces.watcher.new(function()
        config.refreshSpaces()
    end)
    state.spaceWatcher:start()
end

function M.init()
    M.bindHotkeys()
    M.startWatcher()
end

return M
