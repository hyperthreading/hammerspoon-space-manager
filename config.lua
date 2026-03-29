local M = {}

M.hyper = { "ctrl", "alt", "shift", "cmd" }

M.keybindings = {
    switchToSpace = { key = "space" },
    moveWindowToSpace = { key = "m" },
}

-- Customize your space aliases here (space number → name)
M.spaces = {
    { space = 1, name = "Browser", icon = "🌐" },
    { space = 2, name = "Slack", icon = "💬" },
    { space = 3, name = "Docs", icon = "📋" },
    { space = 4, name = "Misc", icon = "💤" },
    { space = 5, name = "Project 1", icon = "❤️" },
    { space = 6, name = "Project 2", icon = "🧡" },
    { space = 7, name = "Project 3", icon = "🧡" },
    { space = 8, name = "Project 4", icon = "🧡" },
    { space = 9, name = "Calendar & Inbox", icon = "📅" },
}
return M
