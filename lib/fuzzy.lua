local M = {}

--- Fuzzy match: checks if all chars in query appear in str in order.
--- Returns a score (lower is better) or nil if no match.
--- Rewards consecutive matches, earlier matches, and exact case.
function M.score(str, query)
  if #query == 0 then return 0 end

  local lower_str = str:lower()
  local lower_query = query:lower()
  local str_idx = 1
  local query_idx = 1
  local score = 0
  local prev_match_idx = 0

  while str_idx <= #lower_str and query_idx <= #lower_query do
    if lower_str:sub(str_idx, str_idx) == lower_query:sub(query_idx, query_idx) then
      local gap = str_idx - prev_match_idx - 1
      score = score + gap

      if str_idx == 1 then
        score = score - 5
      end

      if str:sub(str_idx, str_idx) == query:sub(query_idx, query_idx) then
        score = score - 1
      end

      prev_match_idx = str_idx
      query_idx = query_idx + 1
    end
    str_idx = str_idx + 1
  end

  if query_idx > #lower_query then
    return score
  end
  return nil
end

--- Filter and sort a list of items by fuzzy match.
--- Each item must have searchable fields specified by `keys` (list of strings).
--- Returns items sorted by best match score.
function M.filter(items, query, keys)
  if #query == 0 then return items end

  local scored = {}
  for _, item in ipairs(items) do
    local best = nil
    for _, key in ipairs(keys) do
      if item[key] then
        local s = M.score(item[key], query)
        if s and (not best or s < best) then
          best = s
        end
      end
    end
    if best then
      table.insert(scored, { item = item, score = best })
    end
  end

  table.sort(scored, function(a, b) return a.score < b.score end)

  local result = {}
  for _, s in ipairs(scored) do
    table.insert(result, s.item)
  end
  return result
end

return M
