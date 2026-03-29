-- ~/.hammerspoon/init.lua
-- Entry point — add or remove modules here

require("hs.ipc")
require("modules.move-window").init()
require("modules.switch-space").init()
require("modules.manage-space").init()
require("modules.focus-window").init()
require("modules.rename-space").init()
