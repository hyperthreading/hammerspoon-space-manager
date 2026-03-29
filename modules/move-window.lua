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

local function windowIsOnSpace(win, targetSpaceId)
    local currentSpaces = spaces.windowSpaces(win)
    if not currentSpaces then
        return false
    end

    for _, currentSpaceId in ipairs(currentSpaces) do
        if currentSpaceId == targetSpaceId then
            return true
        end
    end

    return false
end

local function fallbackMoveToSpace(win, targetSpaceId)
    local ok, err = spaces.moveWindowToSpace(win, targetSpaceId)
    if not ok then
        return false, err
    end

    hs.timer.usleep(120000)

    if windowIsOnSpace(win, targetSpaceId) then
        return true
    end

    return false, "Window move did not complete"
end

local function dragWindowToSpaceIndex(spaceIndex, win, targetSpaceId)
    cache.moving = true
    cache.mousePosition = hs.mouse.absolutePosition()

    local zoomButtonRect = win:zoomButtonRect()
    if not zoomButtonRect then
        local ok, err = fallbackMoveToSpace(win, targetSpaceId)
        cache.moving = false
        cache.mousePosition = nil
        if not ok then
            showMoveError(err)
        end
        return
    end

    -- Use a titlebar point just to the right of the green button.
    local zoomRect = hs.geometry(zoomButtonRect)
    local clickPoint = hs.geometry.point(zoomRect.x + zoomRect.w + 6, zoomRect.y + (zoomRect.h / 2))
    local dragPoint = hs.geometry.point(clickPoint.x + 1, clickPoint.y)

    local newMouseEvent = eventtap.event.newMouseEvent
    local leftMouseDown = eventtap.event.types.leftMouseDown
    local leftMouseDragged = eventtap.event.types.leftMouseDragged
    local leftMouseUp = eventtap.event.types.leftMouseUp

    hs.mouse.absolutePosition(clickPoint)
    hs.timer.usleep(50000)

    newMouseEvent(leftMouseDown, clickPoint):post()
    hs.timer.usleep(80000)
    newMouseEvent(leftMouseDragged, dragPoint):post()
    hs.timer.usleep(80000)

    -- Use the native macOS shortcut while dragging.
    eventtap.keyStroke({ "ctrl" }, tostring(spaceIndex))

    hs.timer.doAfter(0.6, function()
        newMouseEvent(leftMouseUp, dragPoint):post()

        hs.timer.doAfter(0.15, function()
            hs.mouse.absolutePosition(cache.mousePosition)
            cache.mousePosition = nil
            cache.moving = false

            if windowIsOnSpace(win, targetSpaceId) then
                return
            end

            local ok, err = fallbackMoveToSpace(win, targetSpaceId)
            if not ok then
                showMoveError(err)
            end
        end)
    end)
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

    cache.moving = true
    local ok, err = fallbackMoveToSpace(win, targetSpaceId)
    cache.moving = false

    if not ok then
        showMoveError(err)
    end
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
                    text = alias.name,
                    subText = "Move \"" .. winTitle .. "\" → Space " .. alias.index,
                    icon = alias.icon,
                    iconType = "text",
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
