local window = require("hs.window")
local windowfilter = require("hs.window.filter")
local config = require("config")
local palette = require("lib.palette")

local M = {}

local function trim(text)
    return text and text:match("^%s*(.-)%s*$") or ""
end

local function joinSearchText(appName, title)
    if appName == "" then return title end
    if title == "" then return appName end
    return appName .. " " .. title
end

function M.buildChoices()
    local items = {}
    local windows = windowfilter.defaultCurrentSpace:getWindows(windowfilter.sortByFocusedLast)

    for _, win in ipairs(windows) do
        if win:isStandard() then
            local winId = win:id()
            local app = win:application()
            local appName = trim(app and app:name() or "")
            local title = trim(win:title() or "")

            if winId and (appName ~= "" or title ~= "") then
                table.insert(items, {
                    text = appName ~= "" and appName or title,
                    subText = title ~= "" and title or "Untitled window",
                    windowId = winId,
                    _matchText = joinSearchText(appName, title),
                    _appName = appName,
                    _title = title,
                })
            end
        end
    end

    return items
end

function M.focusWindow(windowId)
    local target = windowId and window.get(windowId) or nil

    if not target then
        hs.alert.show("Window is no longer available")
        return
    end

    target:focus()
    target:raise()
end

function M.bindPalette()
    local capturedChoices = {}

    local chooser = palette.create({
        placeholder = "Focus window in current Space…",
        searchKeys = { "_matchText", "_appName", "_title" },
        buildChoices = function()
            return capturedChoices
        end,
        onSelect = function(choice)
            M.focusWindow(choice.windowId)
        end,
    })

    hs.hotkey.bind(config.hyper, config.keybindings.focusWindow.key, function()
        capturedChoices = M.buildChoices()

        if #capturedChoices == 0 then
            hs.alert.show("No switchable windows in this Space")
            return
        end

        chooser:choices(capturedChoices)
        chooser:show()
    end)
end

function M.init()
    M.bindPalette()
end

return M
