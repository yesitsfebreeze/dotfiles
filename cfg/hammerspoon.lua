os.execute('cd ~/.config/dotfiles && just update &')

local w = {}
local curr = nil
local last = nil

hs.timer.doEvery(0.025, function()
  curr = hs.application.frontmostApplication()
  local win = hs.window.focusedWindow()
  if curr and win then
    w[curr:pid()] = win
  end
  if curr == last then return end
  last = curr
  if win then return end
  local w = w[curr:pid()]
  if not w then 
    local wins = curr:allWindows()
    if #wins > 0 then w = wins[1] end
  end
  w:focus()
  w:raise()
end)

  
