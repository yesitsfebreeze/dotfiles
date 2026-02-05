--@~/.config/nvim/init.lua

palette = dofile(vim.fn.stdpath('config') .. '/../palette.lua')
hl = function(group, opts) vim.api.nvim_set_hl(0, group, opts) end
gr = vim.api.nvim_create_augroup('CustomCommands', { clear = true })
aucmd=function(e,c,g) vim.api.nvim_create_autocmd(e,{group=g or gr,[type(c)=='function'and'callback'or'command']=c}) end
bind=function(b,f,d,m) vim.keymap.set(m or b.modes,b.bind,f,{desc=d}) end
enter_insert_mode=function() if vim.bo.buftype=='' and vim.bo.filetype~='' then vim.cmd'startinsert' end end

local pkg  = vim.fn.stdpath('data') .. '/site'
local path = pkg .. '/pack/deps/start/mini.nvim'
if not (vim.uv or vim.loop).fs_stat(path) then
  vim.fn.system({ 'git', 'clone', '--filter=blob:none', 'https://github.com/nvim-mini/mini.nvim', path })
  vim.cmd('packadd mini.nvim')
end
require('mini.deps').setup({ path = { package = pkg } })
local add, now, later = MiniDeps.add, MiniDeps.now, MiniDeps.later

local KEYMAP = {
  exit = { bind = '<Esc>', modes = { 'i', 'v' } },
	leader = { bind = "<C-\\>", modes = { 'n', 'i', 'v' } },
  cmd = { bind = '<C-/>k', modes = { 'i' } },
}

vim.g.mapleader = KEYMAP.leader.bind
vim.g.maplocalleader = KEYMAP.leader.bind

-- basically inverted vim, we are default in insert mode
-- and a key to go to normal mode, ESC always goes to insert mode
aucmd({'BufEnter', 'BufWinEnter'}, enter_insert_mode)
bind(KEYMAP.exit, '<Nop>', 'Disabled - use leader key instead', 'i')
bind(KEYMAP.leader, '<Esc>', 'Exit to Normal Mode', 'i')
bind(KEYMAP.exit, function() vim.cmd('startinsert') end, 'Return to Insert Mode', 'n')

now(function()
  vim.opt.background = 'dark'
  vim.opt.termguicolors = true
  vim.opt.relativenumber = true
  vim.opt.number = true
  vim.opt.signcolumn = 'yes'
  vim.opt.cursorline = true
    
  vim.opt.tabstop = 2
  vim.opt.shiftwidth = 2
  vim.opt.expandtab = true
  vim.opt.autoindent = true
  vim.opt.wrap = false
  vim.opt.ignorecase = true
  vim.opt.smartcase = true
    
  vim.opt.backspace = "indent,eol,start"
  vim.opt.clipboard:append("unnamedplus")
  vim.opt.splitright = true
  vim.opt.splitbelow = true
  vim.opt.swapfile = false
  vim.opt.scrolloff = 99999

  add({ source = 'tribela/transparent.nvim', name = 'transparent' })
  add({ source = 'oskarnurm/koda.nvim', name = 'koda' })
  require('transparent').setup({})
  require('koda').setup({ transparent = true })
  vim.cmd("colorscheme koda")
end)

later(function()
  local m=palette.modes
  for k,v in pairs{Normal=palette.orange,Insert=palette.orange,Visual=palette.orange,Replace=palette.orange,Command=palette.orange} do
    hl('Cursor'..k,{bg=v})
  end

  local b='blinkwait10-blinkon10-blinkoff10'
  vim.opt.guicursor='n:block-CursorNormal-'..b..
    ',i-ci:block-CursorInsert-'..b..
    ',v-ve:block-CursorVisual-'..b..
    ',r-cr:block-CursorReplace-'..b..
    ',c:block-CursorCommand-'..b..
    ',o:block-CursorNormal-'..b

  aucmd({'ModeChanged','WinEnter'},function()
    local md=vim.fn.mode()
    hl('CursorLineNr',{fg=m[md] or m.i,bg='NONE',bold=true})
  end)
  aucmd({'InsertLeave','WinEnter'},'set rnu')
  aucmd({'InsertEnter','WinLeave'},'set nornu')
  aucmd('InsertLeave',function()
    local c=vim.fn.col('.')
    if c>1 and c<=#vim.fn.getline('.') then vim.fn.cursor(vim.fn.line('.'),c+1) end
  end)
end)

-- -- Lualine
-- now(function()
--   add({ source = 'nvim-lualine/lualine.nvim' })
--   add({ source = 'folke/noice.nvim', depends = { 'MunifTanjim/nui.nvim' } })
  
--   vim.opt.cmdheight = 0
--   vim.opt.laststatus = 0
--   vim.opt.showmode = false

--   local m = { n = 'N', i = 'I', v = 'V', V = 'V', [''] = 'V', c = 'C', R = 'R', t = 'T' }
--   local e = { fg = '#c0ccdb', bg = 'NONE' }
  
--   require('lualine').setup({
--     options = { component_separators = '', section_separators = '', globalstatus = true, 
--       theme = { normal = {a=e,b=e,c=e}, insert = {a=e,b=e,c=e}, visual = {a=e,b=e,c=e}, replace = {a=e,b=e,c=e}, command = {a=e,b=e,c=e} }},
--     sections = {}, inactive_sections = {},
--     tabline = {
--       lualine_a = {{ function() return vim.fn.mode()=='c' and ':' or "   "..m[vim.fn.mode()] end, 
--         color = function() return {fg=palette.modes[vim.fn.mode()]or'#c0ccdb',gui='bold'} end }},
--       lualine_b = {'branch','diff','diagnostics'},
--       lualine_c = {{ function() return vim.fn.mode()=='c' and vim.fn.getcmdline() or vim.fn.expand('%:~:.') end,
--         color = function() return vim.fn.mode()=='c' and {fg=palette.modes.c} or nil end }},
--       lualine_x = { function() return vim.fn.mode()~='c' and vim.bo.filetype or '' end },
--       lualine_y = { function() return vim.fn.mode()~='c' and vim.fn.line('.')..':'..vim.fn.col('.') or '' end },
--       lualine_z = {{ function() return vim.fn.mode()~='c' and os.date('%H:%M') or '' end }},
--     },
--   })

--   require('noice').setup({
--     cmdline = { enabled = true, view = 'cmdline' },
--     messages = { enabled = true, view = 'mini', view_error = 'mini', view_warn = 'mini' },
--     popupmenu = { enabled = false },
--     views = { cmdline = { position = { row = 0, col = 0 }, size = { width = '100%', height = 'auto' } } },
--     routes = {{ view = 'mini', filter = { event = 'msg_showmode' } }},
--   })
-- end)