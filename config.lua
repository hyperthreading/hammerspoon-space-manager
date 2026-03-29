local json = require("hs.json")
local spaces = require("hs.spaces")
local screen = require("hs.screen")

local M = {}

M.hyper = { "ctrl", "alt", "shift", "cmd" }

-- Palette backend: "builtin" (hs.chooser) or "custom" (hs.webview)
M.paletteBackend = "custom"

M.keybindings = {
    switchToSpace = { key = "space" },
    focusWindow = { key = "s" },
    moveWindowToSpace = { key = "m" },
    renameSpace = { key = "r" },
    addSpace = { key = "=" },
    removeSpace = { key = "-" },
}

-- Default aliases by position. Dynamic spaces beyond this list fall back to "Space N".
local defaultSpaces = {
    { name = "Browser", icon = "🌐" },
    { name = "Slack", icon = "💬" },
    { name = "Docs", icon = "📋" },
    { name = "Misc", icon = "💤" },
    { name = "Project 1", icon = "❤️" },
    { name = "Project 2", icon = "🧡" },
    { name = "Project 3", icon = "🧡" },
    { name = "Project 4", icon = "🧡" },
    { name = "Calendar & Inbox", icon = "📅" },
}

local savePath = hs.configdir .. "/space-names.json"
local savedOverrides = {}

M.spaceCache = {}
M.spaces = {}

local function loadSavedNames()
    local f = io.open(savePath, "r")
    if not f then return {} end
    local content = f:read("*a")
    f:close()
    local ok, data = pcall(json.decode, content)
    if ok and data then return data end
    return {}
end

local function writeSavedNames(data)
    local f = io.open(savePath, "w")
    if not f then return end
    f:write(json.encode(data))
    f:close()
end

local function resolveScreen(target)
    if target == nil then
        local focusedWindow = hs.window.focusedWindow()
        if focusedWindow then
            return focusedWindow:screen()
        end
        return screen.mainScreen()
    end

    if getmetatable(target) == hs.getObjectMetatable("hs.screen") then
        return target
    end

    if type(target) == "string" then
        if target:lower() == "main" then
            return screen.mainScreen()
        end
        if target:lower() == "primary" then
            return screen.primaryScreen()
        end
        for _, candidate in ipairs(screen.allScreens()) do
            if candidate:getUUID() == target then
                return candidate
            end
        end
    end

    if math.type(target) == "integer" then
        for _, candidate in ipairs(screen.allScreens()) do
            if candidate:id() == target then
                return candidate
            end
        end
    end

    return nil
end

local function defaultAliasForIndex(index)
    local alias = defaultSpaces[index]
    if alias then
        return alias.name, alias.icon
    end

    return "Space " .. index, "•"
end

local function activeSpaceIds()
    local ids = {}

    for _, candidate in ipairs(screen.allScreens()) do
        local screenUUID = candidate:getUUID()
        local screenSpaces = screenUUID and spaces.spacesForScreen(screenUUID) or {}

        for _, spaceId in ipairs(screenSpaces or {}) do
            ids[tostring(spaceId)] = true
        end
    end

    return ids
end

local function updateDefaultSpaceView()
    local currentScreen = resolveScreen()
    if not currentScreen then
        M.spaces = {}
        return
    end

    M.spaces = M.spaceCache[currentScreen:getUUID()] or {}
end

local function buildSpacesForScreen(target)
    local resolvedScreen = resolveScreen(target)
    if not resolvedScreen then
        return {}
    end

    local screenUUID = resolvedScreen:getUUID()
    local screenSpaces = screenUUID and spaces.spacesForScreen(screenUUID) or {}
    local result = {}

    for index, spaceId in ipairs(screenSpaces or {}) do
        local override = savedOverrides[tostring(spaceId)]
        local legacyOverride = savedOverrides[tostring(index)]
        local defaultName, defaultIcon = defaultAliasForIndex(index)

        table.insert(result, {
            id = spaceId,
            space = index,
            index = index,
            name = (override and override.name) or (legacyOverride and legacyOverride.name) or defaultName,
            icon = (override and override.icon) or (legacyOverride and legacyOverride.icon) or defaultIcon,
        })
    end

    return result
end

function M.getCurrentScreen()
    return resolveScreen()
end

function M.refreshSpaces(target)
    if target ~= nil then
        local resolvedScreen = resolveScreen(target)
        if not resolvedScreen then
            return {}
        end

        M.spaceCache[resolvedScreen:getUUID()] = buildSpacesForScreen(resolvedScreen)
        updateDefaultSpaceView()
        return M.spaceCache[resolvedScreen:getUUID()]
    end

    M.spaceCache = {}

    for _, candidate in ipairs(screen.allScreens()) do
        local screenUUID = candidate:getUUID()
        if screenUUID then
            M.spaceCache[screenUUID] = buildSpacesForScreen(candidate)
        end
    end

    updateDefaultSpaceView()
    return M.spaces
end

function M.getSpaces(target)
    local resolvedScreen = resolveScreen(target)
    if not resolvedScreen then
        return {}
    end

    local screenUUID = resolvedScreen:getUUID()
    if not M.spaceCache[screenUUID] then
        M.spaceCache[screenUUID] = buildSpacesForScreen(resolvedScreen)
        updateDefaultSpaceView()
    end

    return M.spaceCache[screenUUID]
end

function M.getSpaceById(spaceId, target)
    for _, spaceEntry in ipairs(M.getSpaces(target)) do
        if spaceEntry.id == spaceId then
            return spaceEntry
        end
    end
    return nil
end

function M.getSpaceByIndex(index, target)
    for _, spaceEntry in ipairs(M.getSpaces(target)) do
        if spaceEntry.index == index then
            return spaceEntry
        end
    end
    return nil
end

function M.getCurrentSpace(target)
    local resolvedScreen = resolveScreen(target)
    if not resolvedScreen then
        return nil
    end

    local currentSpaceId = spaces.activeSpaceOnScreen(resolvedScreen)
    if not currentSpaceId then
        return nil
    end

    return M.getSpaceById(currentSpaceId, resolvedScreen)
end

function M.saveSpaceNames()
    local activeIds = activeSpaceIds()
    local overrides = {}

    for key, value in pairs(savedOverrides) do
        if activeIds[key] then
            overrides[key] = { name = value.name, icon = value.icon }
        end
    end

    for _, screenSpaces in pairs(M.spaceCache) do
        for _, spaceEntry in ipairs(screenSpaces) do
            local key = tostring(spaceEntry.id)
            if activeIds[key] then
                overrides[key] = {
                    name = spaceEntry.name,
                    icon = spaceEntry.icon,
                }
            end
        end
    end

    savedOverrides = overrides
    writeSavedNames(savedOverrides)
end

savedOverrides = loadSavedNames()
M.refreshSpaces()

return M
