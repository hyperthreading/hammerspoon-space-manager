-- Custom command palette built with hs.webview
-- Same interface as lib/palette.lua: M.create(opts) and M.bind(opts)

local fuzzy = require("lib.fuzzy")

local M = {}

local WIDTH = 600
local HEIGHT = 796

local HTML_TEMPLATE = [[
<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<style>
  * { margin: 0; padding: 0; box-sizing: border-box; }
  body {
    font-family: -apple-system, BlinkMacSystemFont, "SF Pro Text", sans-serif;
    background: transparent;
    -webkit-user-select: none;
    user-select: none;
  }
  #container {
    background: #252525;
    border-radius: 12px;
    border: 1px solid rgba(255, 255, 255, 0.1);
    overflow: hidden;
    box-shadow: 0 24px 80px rgba(0, 0, 0, 0.45),
                0 2px 12px rgba(0, 0, 0, 0.2);
  }
  #search-wrapper {
    padding: 14px 16px;
    border-bottom: 1px solid rgba(255, 255, 255, 0.06);
  }
  #search {
    width: 100%;
    background: transparent;
    border: none;
    outline: none;
    color: #e8e8e8;
    font-size: 16px;
    font-family: inherit;
    -webkit-user-select: text;
    user-select: text;
  }
  #search::placeholder { color: rgba(255, 255, 255, 0.35); }
  #list {
    max-height: 720px;
    overflow-y: auto;
    padding: 4px 0;
  }
  #list::-webkit-scrollbar { width: 6px; }
  #list::-webkit-scrollbar-thumb {
    background: rgba(255, 255, 255, 0.15);
    border-radius: 3px;
  }
  #list::-webkit-scrollbar-track { background: transparent; }
  .item {
    padding: 10px 16px;
    cursor: default;
    transition: background 0.06s ease;
  }
  .item.selected { background: rgba(88, 166, 255, 0.12); }
  .item-text {
    color: #e8e8e8;
    font-size: 14px;
    line-height: 1.3;
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }
  .item-subtext {
    color: #777;
    font-size: 12px;
    line-height: 1.3;
    margin-top: 2px;
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }
  #empty {
    padding: 20px 16px;
    color: rgba(255, 255, 255, 0.3);
    font-size: 13px;
    text-align: center;
    display: none;
  }
</style>
</head>
<body>
<div id="container">
  <div id="search-wrapper">
    <input id="search" type="text" placeholder="{{PLACEHOLDER}}" autofocus spellcheck="false" />
  </div>
  <div id="list"></div>
  <div id="empty">No matches</div>
</div>
<script>
  let items = [];
  let selectedIndex = 0;
  const post = (msg) => webkit.messageHandlers.palette.postMessage(msg);

  function updateChoices(newItems) {
    items = newItems;
    selectedIndex = items.length > 0 ? 0 : -1;
    render();
  }

  function resetPalette() {
    const s = document.getElementById('search');
    s.value = '';
    s.focus();
    selectedIndex = 0;
    post({ type: 'ready' });
  }

  function esc(s) {
    const d = document.createElement('div');
    d.textContent = s;
    return d.innerHTML;
  }

  function render() {
    const list = document.getElementById('list');
    const empty = document.getElementById('empty');

    if (items.length === 0) {
      list.innerHTML = '';
      empty.style.display = document.getElementById('search').value ? 'block' : 'none';
      return;
    }

    empty.style.display = 'none';
    list.innerHTML = items.map((item, i) =>
      '<div class="item' + (i === selectedIndex ? ' selected' : '') + '" data-index="' + i + '">' +
        '<div class="item-text">' + esc(item.text) + '</div>' +
        (item.subText ? '<div class="item-subtext">' + esc(item.subText) + '</div>' : '') +
      '</div>'
    ).join('');

    const sel = list.querySelector('.selected');
    if (sel) sel.scrollIntoView({ block: 'nearest' });
  }

  document.getElementById('search').addEventListener('input', function(e) {
    post({ type: 'query', query: e.target.value });
  });

  document.getElementById('list').addEventListener('mousemove', function(e) {
    const el = e.target.closest('.item');
    if (!el) return;
    const idx = parseInt(el.dataset.index);
    if (idx !== selectedIndex) {
      const prev = document.querySelector('.item.selected');
      if (prev) prev.classList.remove('selected');
      el.classList.add('selected');
      selectedIndex = idx;
    }
  });

  document.getElementById('list').addEventListener('mousedown', function(e) {
    e.preventDefault();
    const el = e.target.closest('.item');
    if (el) post({ type: 'select', index: parseInt(el.dataset.index) });
  });

  document.addEventListener('keydown', function(e) {
    if (e.key === 'ArrowDown') {
      e.preventDefault();
      if (items.length > 0) {
        selectedIndex = (selectedIndex + 1) % items.length;
        render();
      }
    } else if (e.key === 'ArrowUp') {
      e.preventDefault();
      if (items.length > 0) {
        selectedIndex = (selectedIndex - 1 + items.length) % items.length;
        render();
      }
    } else if (e.key === 'Enter') {
      e.preventDefault();
      if (items[selectedIndex]) post({ type: 'select', index: selectedIndex });
    } else if (e.key === 'Escape') {
      e.preventDefault();
      post({ type: 'dismiss' });
    }
  });

  post({ type: 'ready' });
</script>
</body>
</html>
]]

function M.create(opts)
    local allChoices = {}
    local filteredChoices = {}
    local wv = nil
    local isVisible = false
    local pageReady = false

    local obj = {}

    local function sendChoices()
        if not wv then return end
        local items = {}
        for _, c in ipairs(filteredChoices) do
            items[#items + 1] = { text = c.text or "", subText = c.subText or "" }
        end
        wv:evaluateJavaScript("updateChoices(" .. hs.json.encode(items) .. ")")
    end

    local function applyFilter(query)
        if query and #query > 0 then
            filteredChoices = fuzzy.filter(allChoices, query, opts.searchKeys or { "_name" })
        else
            filteredChoices = allChoices
        end
        sendChoices()
    end

    local function dismiss()
        if not isVisible then return end
        isVisible = false
        if wv then wv:hide() end
    end

    local function ensureWebView()
        if wv then return end

        local uc = hs.webview.usercontent.new("palette")
        uc:setCallback(function(msg)
            local body = msg.body
            if body.type == "ready" then
                pageReady = true
                if isVisible then sendChoices() end
            elseif body.type == "query" then
                applyFilter(body.query)
            elseif body.type == "select" then
                local choice = filteredChoices[body.index + 1]
                dismiss()
                if choice and opts.onSelect then
                    opts.onSelect(choice)
                end
            elseif body.type == "dismiss" then
                dismiss()
            end
        end)

        local scr = hs.screen.mainScreen():frame()
        local rect = hs.geometry.rect(
            scr.x + (scr.w - WIDTH) / 2,
            scr.y + scr.h * 0.2,
            WIDTH, HEIGHT
        )

        wv = hs.webview.new(rect, { developerExtrasEnabled = false }, uc)
        wv:windowStyle({ "borderless" })
        wv:level(hs.drawing.windowLevels.floating)
        wv:allowTextEntry(true)
        wv:transparent(true)
        wv:shadow(false)
        wv:deleteOnClose(false)
        wv:windowCallback(function(action, _, hasFocus)
            if action == "focusChange" and not hasFocus and isVisible then
                dismiss()
            end
        end)

        local html = HTML_TEMPLATE:gsub("{{PLACEHOLDER}}", function()
            return opts.placeholder or "Search…"
        end)
        wv:html(html)
    end

    function obj:show()
        allChoices = opts.buildChoices and opts.buildChoices() or {}
        filteredChoices = allChoices
        ensureWebView()

        -- Reposition to current main screen
        local scr = hs.screen.mainScreen():frame()
        wv:frame(hs.geometry.rect(
            scr.x + (scr.w - WIDTH) / 2,
            scr.y + scr.h * 0.2,
            WIDTH, HEIGHT
        ))

        isVisible = true
        wv:show()
        hs.focus()

        if pageReady then
            wv:evaluateJavaScript("resetPalette()")
            sendChoices()
        end
        -- First load: JS sends 'ready' after HTML loads → sendChoices
        -- Subsequent shows: resetPalette sends 'ready' → sendChoices
    end

    function obj:hide()
        dismiss()
    end

    function obj:delete()
        dismiss()
        if wv then wv:delete(); wv = nil end
    end

    function obj:choices(newChoices)
        allChoices = newChoices
        filteredChoices = newChoices
        if isVisible then sendChoices() end
    end

    return obj
end

function M.bind(opts)
    local p = M.create(opts)
    hs.hotkey.bind(opts.mods, opts.key, function()
        if opts.onOpen then opts.onOpen() end
        p:show()
    end)
    return p
end

return M
