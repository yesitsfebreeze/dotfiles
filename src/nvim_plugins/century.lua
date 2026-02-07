--@~/.config/nvim/lua/century.lua
-- Fixed virtual padding above+below, then always center cursor and scroll into padding when needed.

local M = {}

local ns = vim.api.nvim_create_namespace("century_fixedpad")
local uv = vim.uv or vim.loop

local timer = uv.new_timer()
local in_apply = false

-- per-buffer: remember what pad size we last applied, so we don't rebuild constantly
local buf_pad = {} ---@type table<integer, integer>

local function scroll_view(delta)
  local win = vim.api.nvim_get_current_win()
  local view = vim.fn.winsaveview()

  local linecount = vim.api.nvim_buf_line_count(0)
  local new_top = view.topline + delta

  if new_top < 1 then new_top = 1 end
  if new_top > linecount then new_top = linecount end

  view.topline = new_top
  vim.api.nvim_win_call(win, function()
    vim.fn.winrestview(view)
  end)
end

vim.api.nvim_create_user_command("ScrollDown", function(opts)
  local n = tonumber(opts.args) or 1
  scroll_view(n)
end, { nargs = "?" })

vim.api.nvim_create_user_command("ScrollUp", function(opts)
  local n = tonumber(opts.args) or 1
  scroll_view(-n)
end, { nargs = "?" })

local function is_real_edit_buf(buf)
  if not vim.api.nvim_buf_is_valid(buf) then return false end
  if vim.bo[buf].buftype ~= "" then return false end
  if vim.bo[buf].filetype == "oil" then return false end
  return true
end

local function is_insertish_mode()
  local m = vim.fn.mode(1)
  local c = m:sub(1, 1)
  return c == "i" or c == "R"
end

local function mk_virt_lines(n)
  local t = {}
  for _ = 1, n do
    t[#t + 1] = { { "", "Normal" } }
  end
  return t
end

local function ensure_fixed_padding(buf, pad)
  if buf_pad[buf] == pad then return end
  buf_pad[buf] = pad

  vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)

  if pad > 0 then
    local lines = mk_virt_lines(pad)

    -- above first line
    vim.api.nvim_buf_set_extmark(buf, ns, 0, 0, {
      virt_lines_above = true,
      virt_lines = lines,
      hl_mode = "combine",
    })

    -- below last line
    local last = math.max(vim.api.nvim_buf_line_count(buf) - 1, 0)
    vim.api.nvim_buf_set_extmark(buf, ns, last, 0, {
      virt_lines = lines,
      hl_mode = "combine",
    })
  end
end

local function apply(win, opts)
  if in_apply then return end
  if not vim.api.nvim_win_is_valid(win) then return end

  local buf = vim.api.nvim_win_get_buf(win)
  if not is_real_edit_buf(buf) then return end

  local win_h = vim.api.nvim_win_get_height(win)
  if win_h <= 1 then return end

  local cursor_line = vim.api.nvim_win_get_cursor(win)[1]
  local total = vim.api.nvim_buf_line_count(buf)
  local half = math.floor(win_h / 2)

  local pad = opts.pad
  if pad == "auto" then
    pad = half + (opts.extra or 0)
  else
    pad = tonumber(pad) or (half + (opts.extra or 0))
  end

  ensure_fixed_padding(buf, pad)

  if is_insertish_mode() and not opts.center_in_insert then
    return
  end

  in_apply = true
  vim.api.nvim_win_call(win, function()
    -- Center first (normal Neovim behavior)
    vim.cmd("normal! zz")

    -- Now: if we're close to top/bottom of *real* buffer, bias the view into the virtual padding.
    -- Top zone: cursor_line <= half
    -- Bottom zone: cursor_line >= total - half
    local top_need = math.max(0, half - cursor_line)
    local bot_need = math.max(0, cursor_line - (total - half))

    if top_need > 0 then
      -- allow entering virt-above region
      vim.fn.winrestview({ topline = 0 })
      -- scroll up into the virtual space by the amount we "lack"
      vim.cmd(("normal! %d\\<C-y>"):format(math.min(top_need, pad)))
    elseif bot_need > 0 then
      -- scroll down into the virtual space by the amount we "lack"
      vim.cmd(("normal! %d\\<C-e>"):format(math.min(bot_need, pad)))
    end
  end)
  in_apply = false
end

local function debounce(fn)
  timer:stop()
  timer:start(15, 0, function()
    vim.schedule(fn)
  end)
end

function M.setup(opts)
--   opts = opts or {}
--   opts.pad = opts.pad or "auto"        -- "auto" = half window height; or number
--   opts.extra = opts.extra or 0         -- extra fixed lines on top of auto
--   opts.center_in_insert = opts.center_in_insert or false

--   -- scrolloff should be low; you’re implementing overscroll yourself
--   vim.opt.scrolloff = opts.scrolloff or 0

--   local aug = vim.api.nvim_create_augroup("CenturyFixedPad", { clear = true })

--   local function tick()
--     apply(vim.api.nvim_get_current_win(), opts)
--   end

--   vim.api.nvim_create_autocmd({
--     "BufWinEnter",
--     "WinEnter",
--     "CursorMoved",
--     "CursorMovedI",
--     "TextChanged",
--     "TextChangedI",
--     "WinScrolled",
--     "VimResized",
--     "WinResized",
--     "OptionSet",
--     "DiagnosticChanged",
--   }, {
--     group = aug,
--     callback = function()
--       debounce(tick)
--     end,
--   })

--   -- if line count changes a lot (paste), our bottom extmark position changes; rebuild next time
--   vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
--     group = aug,
--     callback = function(ev)
--       buf_pad[ev.buf] = nil
--     end,
--   })

--   vim.api.nvim_create_autocmd({ "BufWipeout" }, {
--     group = aug,
--     callback = function(ev)
--       buf_pad[ev.buf] = nil
--     end,
--   })
end

return M
