-- Move focused window to space N
-- Workaround for hs.spaces.moveWindowToSpace being broken on macOS Sequoia
-- Based on MoveSpaces.spoon drag-and-drop technique

local spaces = require("hs.spaces")
local eventtap = require("hs.eventtap")
local config = require("config")
local palette = require("lib.palette")

local M = {}
local cache = { moving = false }

function M.moveToSpace(n, win)
    if cache.moving then return end

    win = win or hs.window.focusedWindow()
    if not win or not win:isStandard() then
        hs.alert.show("No focused window")
        return
    end

    local screen = win:screen()
    local screenSpaces = spaces.spacesForScreen(screen:getUUID())

    if not screenSpaces or #screenSpaces == 0 then
        hs.alert.show("Could not get spaces")
        return
    end

    if n > #screenSpaces then
        hs.alert.show("Space " .. n .. " does not exist (max: " .. #screenSpaces .. ")")
        return
    end

    local currentSpace = spaces.activeSpaceOnScreen(screen)
    if screenSpaces[n] == currentSpace then return end

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

    -- Switch via native macOS shortcut (Ctrl+N)
    eventtap.keyStroke({ "ctrl" }, tostring(n))

    hs.timer.doAfter(0.5, function()
        newMouseEvent(leftMouseUp, clickPoint):post()

        hs.timer.doAfter(0.1, function()
            hs.mouse.absolutePosition(cache.mousePosition)
            cache.mousePosition = nil
            cache.moving = false
        end)
    end)
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
            local items = {}
            for _, alias in ipairs(config.spaces) do
                table.insert(items, {
                    text = alias.icon .. "  " .. alias.name,
                    subText = "Move \"" .. winTitle .. "\" → Space " .. alias.space,
                    space = alias.space,
                    _name = alias.name,
                    _spaceStr = tostring(alias.space),
                })
            end
            return items
        end,
        onSelect = function(choice)
            if capturedWin then
                capturedWin:focus()
                -- Small delay to ensure the window is focused before dragging
                hs.timer.doAfter(0.1, function()
                    M.moveToSpace(choice.space, capturedWin)
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
