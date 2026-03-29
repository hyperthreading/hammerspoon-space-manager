-- Built-in command palette using hs.chooser
-- Original implementation extracted from lib/palette.lua

local fuzzy = require("lib.fuzzy")

local M = {}
local IMAGE_MT = hs.getObjectMetatable("hs.image")

local function normalizeChoice(choice)
    local normalized = {}
    for key, value in pairs(choice) do
        normalized[key] = value
    end

    local icon = normalized.icon
    if getmetatable(icon) == IMAGE_MT then
        normalized.image = icon
    elseif type(icon) == "string" and icon ~= "" and normalized.iconType ~= "image" and not icon:match("^data:image/") then
        normalized.text = icon .. "  " .. (normalized.text or "")
    end

    return normalized
end

local function normalizeChoices(choices)
    local normalized = {}
    for i, choice in ipairs(choices or {}) do
        normalized[i] = normalizeChoice(choice)
    end
    return normalized
end

function M.create(opts)
    local chooser = hs.chooser.new(function(choice)
        if not choice then return end
        opts.onSelect(choice)
    end)

    chooser:placeholderText(opts.placeholder or "Search…")

    chooser:queryChangedCallback(function(query)
        local choices = opts.buildChoices()
        chooser:choices(normalizeChoices(fuzzy.filter(choices, query, opts.searchKeys or { "_name" })))
    end)

    return chooser
end

function M.bind(opts)
    local chooser = M.create(opts)
    hs.hotkey.bind(opts.mods, opts.key, function()
        if opts.onOpen then opts.onOpen() end
        local choices = opts.buildChoices()
        chooser:choices(normalizeChoices(choices))
        if opts.initialSelection then
            local idx = opts.initialSelection(choices)
            if idx then chooser:selectedRow(idx) end
        end
        chooser:show()
    end)
    return chooser
end

return M
