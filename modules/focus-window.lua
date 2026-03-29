local window = require("hs.window")
local spaces = require("hs.spaces")
local windowfilter = require("hs.window.filter")
local timer = require("hs.timer")
local config = require("config")
local fuzzy = require("lib.fuzzy")
local palette = require("lib.palette")

local M = {}
M.searchKeys = { "_matchText", "_appName", "_title" }

local REFRESH_DEBOUNCE_SECONDS = 0.15
local SPACE_REFRESH_DEBOUNCE_SECONDS = 0.2
local function elapsedMilliseconds(startTime, endTime)
    return (endTime - startTime) / 1e6
end

local log = hs.logger.new("focus-window", "info")
local state = {
    choices = {},
    windowMap = {},
    spaceId = nil,
    lastRefreshAt = nil,
    lastRefreshDurationMs = nil,
    refreshReason = nil,
    refreshTimer = nil,
    refreshScheduled = false,
    filter = nil,
    spaceWatcher = nil,
}

local function logSlow(label, startTime)
    local elapsed = elapsedMilliseconds(startTime, timer.absoluteTime())
    if elapsed > 100 then
        log.wf("[SLOW] %s took %.1fms", label, elapsed)
    end
end

local function logSlowCacheAccess(label, startTime, choiceCount)
    local suffix = string.format(" [%d choices, space=%s]", choiceCount or 0, tostring(state.spaceId))
    logSlow(label .. suffix, startTime)
end

local function trim(text)
    return text and text:match("^%s*(.-)%s*$") or ""
end

local function joinSearchText(appName, title)
    if appName == "" then return title end
    if title == "" then return appName end
    return appName .. " " .. title
end

local function currentSpaceId()
    return spaces.focusedSpace()
end

local function mergeReason(existing, incoming)
    if not existing or existing == "" then return incoming end
    if not incoming or incoming == "" or existing == incoming then return existing end
    return existing .. "+" .. incoming
end

local function countKeys(tbl)
    local count = 0
    for _ in pairs(tbl or {}) do
        count = count + 1
    end
    return count
end

local function ensureFilter()
    if state.filter then
        return state.filter
    end

    local filter = windowfilter.copy(windowfilter.defaultCurrentSpace)
    local filters = filter:getFilters()
    local override = {}

    for key, value in pairs(filters.override or {}) do
        override[key] = value
    end

    override.currentSpace = true
    override.allowRoles = "AXStandardWindow"

    filter:setOverrideFilter(override)
    filter:setSortOrder(windowfilter.sortByFocusedLast)
    state.filter = filter
    return filter
end

local function buildChoicesFromWindows(windows, windowMap)
    local items = {}

    for _, win in ipairs(windows) do
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

    return items
end

local function collectChoicesNow(reason)
    local startTime = timer.absoluteTime()
    local filter = ensureFilter()
    local windowMap = {}
    local windows = filter:getWindows(windowfilter.sortByFocusedLast)
    local choices = buildChoicesFromWindows(windows, windowMap)
    logSlow(
        string.format(
            "collectChoices(%s) [%d windows, %d choices]",
            reason or "unknown",
            #windows,
            #choices
        ),
        startTime
    )
    return choices, windowMap, windows
end

local function replaceCache(choices, windowMap)
    state.choices = choices
    state.windowMap = windowMap
    state.spaceId = currentSpaceId()
    state.lastRefreshAt = os.time()
end

local function refreshCache(reason)
    local startTime = timer.absoluteTime()
    local choices, windowMap, windows = collectChoicesNow(reason)
    local endTime = timer.absoluteTime()

    replaceCache(choices, windowMap)
    state.lastRefreshDurationMs = elapsedMilliseconds(startTime, endTime)

    if state.lastRefreshDurationMs > 100 then
        log.wf(
            "[SLOW] refreshCache(%s) took %.1fms for %d windows (%d choices)",
            reason or "unknown",
            state.lastRefreshDurationMs,
            #windows,
            #choices
        )
    end
end

local function scheduleRefresh(reason, delaySeconds)
    ensureFilter()

    state.refreshReason = mergeReason(state.refreshReason, reason)
    state.refreshScheduled = true

    if state.refreshTimer then
        state.refreshTimer:stop()
    end

    state.refreshTimer = timer.doAfter(delaySeconds or REFRESH_DEBOUNCE_SECONDS, function()
        local refreshReason = state.refreshReason
        state.refreshTimer = nil
        state.refreshReason = nil
        state.refreshScheduled = false
        refreshCache(refreshReason)
    end)
end

local function subscribeRefreshSources()
    if state.spaceWatcher then
        return
    end

    local filter = ensureFilter()
    local eventReasons = {
        { windowfilter.windowsChanged,          "windowsChanged" },
        { windowfilter.windowTitleChanged,      "windowTitleChanged" },
        { windowfilter.windowFocused,           "windowFocused" },
        { windowfilter.windowCreated,           "windowCreated" },
        { windowfilter.windowDestroyed,         "windowDestroyed" },
        { windowfilter.windowInCurrentSpace,    "windowInCurrentSpace" },
        { windowfilter.windowNotInCurrentSpace, "windowNotInCurrentSpace" },
    }

    for _, eventSpec in ipairs(eventReasons) do
        filter:subscribe(eventSpec[1], function()
            scheduleRefresh(eventSpec[2])
        end)
    end

    state.spaceWatcher = spaces.watcher.new(function()
        scheduleRefresh("spaceChanged", SPACE_REFRESH_DEBOUNCE_SECONDS)
    end)
    state.spaceWatcher:start()
end

function M.buildChoices()
    local choices = collectChoicesNow("buildChoices")
    return choices
end

function M.profileBuildChoices()
    local startTime = timer.absoluteTime()
    local windows = ensureFilter():getWindows(windowfilter.sortByFocusedLast)
    local afterGetWindows = timer.absoluteTime()
    local windowMap = {}
    local choices = buildChoicesFromWindows(windows, windowMap)
    local endTime = timer.absoluteTime()

    return {
        windowCount = #windows,
        choiceCount = #choices,
        cachedWindowCount = countKeys(windowMap),
        getWindowsMs = elapsedMilliseconds(startTime, afterGetWindows),
        buildChoicesMs = elapsedMilliseconds(afterGetWindows, endTime),
        totalMs = elapsedMilliseconds(startTime, endTime),
        cachedSpaceId = state.spaceId,
        refreshScheduled = state.refreshScheduled,
    }
end

function M.profileFuzzy(query)
    local choices = state.choices
    if #choices == 0 then
        choices = M.buildChoices()
    end
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
    local choices = state.choices
    local windowMap = state.windowMap
    local targetChoice = nil

    if #choices == 0 then
        choices, windowMap = collectChoicesNow("profileFocusWindow")
    end

    if windowId then
        for _, choice in ipairs(choices) do
            if choice.windowId == windowId then
                targetChoice = choice
                break
            end
        end
    end

    if not targetChoice then
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
    local capturedWindowMap = {}

    local p = palette.create({
        placeholder = "Focus window in current Space…",
        searchKeys = M.searchKeys,
        buildChoices = function()
            return capturedChoices
        end,
        onSelect = function(choice)
            local t0 = timer.absoluteTime()
            M.focusWindow(choice, capturedWindowMap)
            logSlow("focusWindow", t0)
        end,
    })

    hs.hotkey.bind(config.hyper, config.keybindings.focusWindow.key, function()
        local t0 = timer.absoluteTime()
        capturedChoices = state.choices
        capturedWindowMap = state.windowMap

        if #capturedChoices == 0 then
            if state.refreshScheduled then
                logSlowCacheAccess("cacheMiss(warmingUp)", t0, #capturedChoices)
                hs.alert.show("Window cache is warming up")
            else
                logSlowCacheAccess("cacheMiss(empty)", t0, #capturedChoices)
                hs.alert.show("No switchable windows in this Space")
            end
            return
        end

        p:choices(capturedChoices)
        p:show()
        logSlowCacheAccess("cacheHit(showChooser)", t0, #capturedChoices)
    end)
end

function M.init()
    ensureFilter()
    subscribeRefreshSources()
    scheduleRefresh("warmup", 0)
    M.bindPalette()
end

return M
