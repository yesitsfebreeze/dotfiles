local function restoreLastMinimizedWindow(app)
  if not app then return end

  local wins = app:allWindows()
  if not wins or #wins == 0 then return end

  local minimized = {}
  local visibleCount = 0

  for _, w in ipairs(wins) do
    if w:isStandard() then
      if w:isMinimized() then
        table.insert(minimized, w)
      elseif w:isVisible() then
        visibleCount = visibleCount + 1
      end
    end
  end

  -- Only restore if there are NO visible windows
  if visibleCount > 0 or #minimized == 0 then return end

  -- Pick the most recently focused minimized window
  table.sort(minimized, function(a, b)
    return (a:lastFocusTime() or 0) > (b:lastFocusTime() or 0)
  end)

  minimized[1]:unminimize()
  minimized[1]:focus()
end

hs.application.watcher.new(function(appName, eventType, app)
  if eventType == hs.application.watcher.activated then
    restoreLastMinimizedWindow(app)
  end
end):start()
