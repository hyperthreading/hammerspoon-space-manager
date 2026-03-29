local window = require("hs.window")
local windowfilter = require("hs.window.filter")
local timer = require("hs.timer")
local config = require("config")
local fuzzy = require("lib.fuzzy")
local palette = require("lib.palette")

local M = {}
M.searchKeys = { "_matchText", "_appName", "_title" }

local function elapsedMilliseconds(startTime, endTime)
    return (endTime - startTime) / 1e6
end

local function trim(text)
    return text and text:match("^%s*(.-)%s*$") or ""
end

local function joinSearchText(appName, title)
    if appName == "" then return title end
    if title == "" then return appName end
    return appName .. " " .. title
end

local function buildChoicesFromWindows(windows, windowMap)
    local items = {}

    for _, win in ipairs(windows) do
        if win:isStandard() then
            local winId = win:id()
            local app = win:application()
            local appName = trim(app and app:name() or "")
            local title = trim(win:title() or "")

            if winId and (appName ~= "" or title ~= "") then
                local windowKey = tostring(winId)
                if windowMap then
                    windowMap[windowKey] = win
                end

                table.insert(items, {
                    text = appName ~= "" and appName or title,
                    subText = title ~= "" and title or "Untitled window",
                    windowId = winId,
                    windowKey = windowKey,
                    _matchText = joinSearchText(appName, title),
                    _appName = appName,
                    _title = title,
                })
            end
        end
    end

    return items
end

function M.buildChoices()
    local windows = windowfilter.defaultCurrentSpace:getWindows(windowfilter.sortByFocusedLast)
    return buildChoicesFromWindows(windows)
end

local function collectChoices()
    local windowMap = {}
    local windows = windowfilter.defaultCurrentSpace:getWindows(windowfilter.sortByFocusedLast)
    local choices = buildChoicesFromWindows(windows, windowMap)
    return choices, windowMap, windows
end

function M.profileBuildChoices()
    local startTime = timer.absoluteTime()
    local windows = windowfilter.defaultCurrentSpace:getWindows(windowfilter.sortByFocusedLast)
    local afterGetWindows = timer.absoluteTime()
    local windowMap = {}
    local choices = buildChoicesFromWindows(windows, windowMap)
    local endTime = timer.absoluteTime()

    return {
        windowCount = #windows,
        choiceCount = #choices,
        cachedWindowCount = #choices,
        getWindowsMs = elapsedMilliseconds(startTime, afterGetWindows),
        buildChoicesMs = elapsedMilliseconds(afterGetWindows, endTime),
        totalMs = elapsedMilliseconds(startTime, endTime),
    }
end

function M.profileFuzzy(query)
    local choices = M.buildChoices()
    local startTime = timer.absoluteTime()
    local filtered = fuzzy.filter(choices, query or "", M.searchKeys)
    local endTime = timer.absoluteTime()

    return {
        query = query or "",
        choiceCount = #choices,
        filteredCount = #filtered,
        fuzzyMs = elapsedMilliseconds(startTime, endTime),
    }
end

local function resolveWindow(choice, windowMap)
    local target = nil

    if choice and windowMap and choice.windowKey then
        target = windowMap[choice.windowKey]
        if target and not target:id() then
            target = nil
        end
    end

    if not target and choice and choice.windowId then
        target = window.get(choice.windowId)
    end

    return target
end

function M.focusWindow(choice, windowMap)
    local target = resolveWindow(choice, windowMap)

    if not target then
        hs.alert.show("Window is no longer available")
        return
    end

    target:focus()
    target:raise()
end

function M.profileFocusWindow(windowId)
    local choices, windowMap = collectChoices()
    local targetChoice = nil

    if windowId then
        for _, choice in ipairs(choices) do
            if choice.windowId == windowId then
                targetChoice = choice
                break
            end
        end
    else
        targetChoice = choices[1]
    end

    if not targetChoice then
        return {
            windowId = nil,
            focusMs = nil,
            error = "No switchable windows in this Space",
        }
    end

    local startTime = timer.absoluteTime()
    M.focusWindow(targetChoice, windowMap)
    local endTime = timer.absoluteTime()

    return {
        windowId = targetChoice.windowId,
        focusMs = elapsedMilliseconds(startTime, endTime),
    }
end

function M.bindPalette()
    local capturedChoices = {}
    local capturedWindows = {}

    local chooser = palette.create({
        placeholder = "Focus window in current Space…",
        searchKeys = M.searchKeys,
        buildChoices = function()
            return capturedChoices
        end,
        onSelect = function(choice)
            M.focusWindow(choice, capturedWindows)
        end,
    })

    hs.hotkey.bind(config.hyper, config.keybindings.focusWindow.key, function()
        capturedChoices, capturedWindows = collectChoices()

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
