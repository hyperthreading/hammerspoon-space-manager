-- Move focused window to space N
-- Uses a drag-and-switch workaround on the first 9 spaces and falls back to hs.spaces above that.

local spaces = require("hs.spaces")
local eventtap = require("hs.eventtap")
local config = require("config")
local palette = require("lib.palette")

local M = {}
local cache = { moving = false }

local function showMoveError(message)
    hs.alert.show(message or "Could not move window")
end

local function dragWindowToSpaceIndex(spaceIndex, win, targetSpaceId)
    cache.moving = true
    cache.mousePosition = hs.mouse.absolutePosition()

    -- Safe click point near the zoom (green) button
    local zoomPoint = hs.geometry(win:zoomButtonRect())
    local clickPoint = zoomPoint:move({ -1, -1 }).topleft

    local newMouseEvent = eventtap.event.newMouseEvent
    local leftMouseDown = eventtap.event.types.leftMouseDown
    local leftMouseUp = eventtap.event.types.leftMouseUp

    newMouseEvent(leftMouseDown, clickPoint):post()
    hs.timer.usleep(150000) -- 150ms

    -- Use the native macOS shortcut while dragging.
    eventtap.keyStroke({ "ctrl" }, tostring(spaceIndex))

    hs.timer.doAfter(0.5, function()
        newMouseEvent(leftMouseUp, clickPoint):post()

        hs.timer.doAfter(0.1, function()
            hs.mouse.absolutePosition(cache.mousePosition)
            cache.mousePosition = nil
            cache.moving = false

            local currentSpaces = spaces.windowSpaces(win)
            if currentSpaces then
                for _, currentSpaceId in ipairs(currentSpaces) do
                    if currentSpaceId == targetSpaceId then
                        return
                    end
                end
            end

            showMoveError("Window move did not complete")
        end)
    end)
end

local function fallbackMoveToSpace(win, targetSpaceId)
    cache.moving = true
    local ok, err = spaces.moveWindowToSpace(win, targetSpaceId)
    cache.moving = false

    if not ok then
        showMoveError(err)
    end
end

local function resolveTarget(screenSpaces, spaceRef)
    if type(spaceRef) == "table" then
        local targetId = spaceRef.id or spaceRef.spaceId
        local targetIndex = spaceRef.index or spaceRef.space

        if targetId then
            for index, spaceId in ipairs(screenSpaces) do
                if spaceId == targetId then
                    return spaceId, index
                end
            end
        end

        if targetIndex and screenSpaces[targetIndex] then
            return screenSpaces[targetIndex], targetIndex
        end

        return nil, nil
    end

    if math.type(spaceRef) == "integer" and screenSpaces[spaceRef] then
        return screenSpaces[spaceRef], spaceRef
    end

    if math.type(spaceRef) == "integer" then
        for index, spaceId in ipairs(screenSpaces) do
            if spaceId == spaceRef then
                return spaceId, index
            end
        end
    end

    return nil, nil
end

function M.moveToSpace(spaceRef, win)
    if cache.moving then return end

    win = win or hs.window.focusedWindow()
    if not win or not win:isStandard() then
        showMoveError("No focused window")
        return
    end

    local screen = win:screen()
    local screenSpaces = spaces.spacesForScreen(screen:getUUID())

    if not screenSpaces or #screenSpaces == 0 then
        showMoveError("Could not get spaces")
        return
    end

    local targetSpaceId, targetIndex = resolveTarget(screenSpaces, spaceRef)
    if not targetSpaceId or not targetIndex then
        showMoveError("Space not found on this screen")
        return
    end

    local currentSpaceId = spaces.activeSpaceOnScreen(screen)
    if targetSpaceId == currentSpaceId then
        return
    end

    if targetIndex <= 9 then
        dragWindowToSpaceIndex(targetIndex, win, targetSpaceId)
        return
    end

    fallbackMoveToSpace(win, targetSpaceId)
end

-- Direct keybindings: Hyper + 1..9
function M.bindHotkeys()
    for i = 1, 9 do
        hs.hotkey.bind(config.hyper, tostring(i), function()
            M.moveToSpace(i)
        end)
    end
end

-- Command palette for moving the focused window to another Space
function M.bindPalette()
    local capturedWin = nil

    palette.bind({
        mods = config.hyper,
        key = config.keybindings.moveWindowToSpace.key,
        placeholder = "Move window to…",
        searchKeys = { "_name", "_spaceStr", "subText" },
        onOpen = function()
            capturedWin = hs.window.focusedWindow()
        end,
        buildChoices = function()
            local winTitle = capturedWin and capturedWin:title() or "No window"
            local screenSpaces = config.refreshSpaces(capturedWin and capturedWin:screen() or nil)
            local items = {}

            for _, alias in ipairs(screenSpaces) do
                table.insert(items, {
                    text = alias.icon .. "  " .. alias.name,
                    subText = "Move \"" .. winTitle .. "\" → Space " .. alias.index,
                    id = alias.id,
                    index = alias.index,
                    _name = alias.name,
                    _spaceStr = tostring(alias.index),
                })
            end

            return items
        end,
        onSelect = function(choice)
            if capturedWin then
                capturedWin:focus()
                -- Small delay to ensure the window is focused before moving it.
                hs.timer.doAfter(0.1, function()
                    M.moveToSpace({ id = choice.id, index = choice.index }, capturedWin)
                end)
            end
        end,
    })
end

function M.init()
    M.bindHotkeys()
    M.bindPalette()
end

return M
