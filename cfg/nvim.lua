local URL = "https://raw.githubusercontent.com/yesitsfebreeze/nvim/refs/heads/master/nvim.lua"
-- README_START
-- local d = vim.fn.stdpath("config").."/lua"
-- vim.fn.mkdir(d, "p")
-- if not (vim.uv or vim.loop).fs_stat(d .. "/nvim.lua") then vim.fn.system({"curl","-fsSL",URL,"-o", d .. "/nvim.lua"}) end
-- require("nvim")
-- README_END

vim.api.nvim_create_user_command('ReloadConfig', function()
  local f = vim.fn.stdpath("config") .. "/lua/nvim.lua"
  vim.os.remove(f)
  vim.fn.system({ "curl", "-fsSL", URL .. '?t=' .. vim.os.time(), "-o", f })
  c('source ' .. vim.fn.stdpath("config") .. '/init.lua')
end, {})

local function np(p) return p:lower():gsub("^([a-z]):", "(%1_)"):gsub("^/", ""):gsub("[/\\]+", "_"):gsub("^_+", "") end
local function jp(...) return vim.fs.joinpath(...) end

local MODES = {
  n = '#5298c4',
  i = '#a7da1e',
  v = '#9d37fc',
  V = '#9d37fc',
  ['\22'] = '#9d37fc', -- visual block (Ctrl-V)
  c = '#f7b83d',
  R = '#e61f44',
  s = '#d4856a',
  S = '#d4856a',
  ['\19'] = '#d4856a', -- select block (Ctrl-S)
}

local km = vim.keymap.set
local KEYMAP = {
	leader = "\28", -- Ctrl-\
	save = "<C-s>",
	save_all = "<C-S>",
	multicursor = "<C-d>",
	explorer = '<leader>e',
	quit = "<leader>q",
	quit_all = "<leader>Q",
	find_files = "<leader>/f",
	live_grep = "<leader>/g",
	buffers = "<leader>fb",
	help_tags = "<leader>fh",
	oldfiles = "<leader>fr",
	grep_string = "<leader>fc",
	recent_files = "<C-o>",
}

vim.g.mapleader = KEYMAP.leader
vim.g.maplocalleader = KEYMAP.leader

-- Setup mini.nvim if not present
local path_package = vim.fn.stdpath('data') .. '/site/'
local mini_path = path_package .. 'pack/deps/start/mini.nvim'
if not vim.loop.fs_stat(mini_path) then
	local mini = 'https://github.com/nvim-mini/mini.nvim'
	vim.cmd('echo "Installing mini.nvim" | redraw')
	vim.fn.system({ 'git', 'clone', '--filter=blob:none', mini, mini_path })
	vim.cmd('packadd mini.nvim | helptags ALL')
	vim.cmd('echo "Installed mini.nvim" | redraw')
end

require('mini.deps').setup({ path = { package = path_package } })
local add, now, later = MiniDeps.add, MiniDeps.now, MiniDeps.later
local function startup(cb, dl) vim.api.nvim_create_autocmd('VimEnter', {
  callback = function() vim.defer_fn(cb, dl) end,
  once = true,
}) end

-- Oil
now(function()
  add({ source = 'stevearc/oil.nvim' })
  local oil = require('oil')
  oil.setup({
    default_file_explorer = true,
    view_options = {
      show_hidden = true,
      -- is_hidden_file = function(name, bufnr) return name:match("^%.") ~= nil end
      -- is_always_hidden = function(name, bufnr) return false end
      -- natural_order = "fast",
      -- case_insensitive = false,
      -- sort = {
      -- 	{ "type", "asc" },
      -- 	{ "name", "asc" },
      -- },
      -- highlight_filename = function(entry, is_hidden, is_link_target, is_link_orphan) return nil end
    },
    columns = {
      "icon",
      "size",
    },
    keymaps = {
      ["<leader>e"] = "actions.close",
    },
  })
  startup(oil.open, 1)
  km('n', KEYMAP.explorer, oil.open, { desc = 'Open Oil file explorer' })
end)

-- Session management
now(function()
  local session_name = np(vim.fn.getcwd())

	add('echasnovski/mini.sessions')
	require('mini.sessions').setup({ autoread = false, autowrite = false })

	startup(function()
      local sesh = jp(require('mini.sessions').config.directory, session_name)
      if vim.fn.filereadable(sesh) ~= 1 then return end
        local ok, err = pcall(function() require('mini.sessions').read(session_name, { force = true }) end)
        if ok then print('Loaded session: ' .. session_name) end
  end, 2)
	
  vim.api.nvim_create_autocmd('VimLeavePre', { callback = function()
    print('Saving session: ' .. session_name)
    require('mini.sessions').write(session_name, { force = true })
  end})

  -- On startup with no args, open Oil in the sessions directory
  startup(function()
    -- if vim.fn.argc() > 0 then return end
    -- local session_dir = require('mini.sessions').config.directory
    -- require('oil').open(session_dir)
    -- local group = vim.api.nvim_create_augroup('OilSessionLoader', { clear = true })
    -- vim.api.nvim_create_autocmd('BufEnter', {
    --   group = group,
    --   once = false,
    --   callback = function()
    --     print
    --     vim.keymap.set('n', '<CR>', function()
    --       local file = vim.fn.expand('<cfile>')
    --       local session = vim.fn.fnamemodify(file, ':t:r')
    --       require('mini.sessions').read(session, { force = true })
    --       -- Remove the autocmd group after loading
    --       vim.api.nvim_del_augroup_by_name('OilSessionLoader')
    --     end, { buffer = 0 })
    --   end,
    -- })
  end, 2)

end)

-- Theme
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

  add('lourenci/github-colors')
  vim.cmd([[colorscheme github-colors]])

  -- Transparent background
  local hl = function(group, opts) vim.api.nvim_set_hl(0, group, opts) end
  hl('Normal', { bg = 'NONE' })
  hl('NormalNC', { bg = 'NONE' })
  hl('SignColumn', { bg = 'NONE' })
  hl('NormalFloat', { bg = 'NONE' })
  hl('CursorLine', { bg = 'NONE', fg = MODES.n})

  -- Block cursor with mode colors
  hl('CursorNormal', { bg = MODES.n })
  hl('CursorInsert', { bg = MODES.i })
  hl('CursorVisual', { bg = MODES.v })
  hl('CursorReplace', { bg = MODES.R })
  hl('CursorCommand', { bg = MODES.c })

  local blink = ('blinkwait10-blinkon10-blinkoff10')
  vim.opt.guicursor = table.concat({
    'n:block-CursorNormal-' .. blink,
    'i-ci:block-CursorInsert-' .. blink,
    'v-ve:block-CursorVisual-' .. blink,
    'r-cr:block-CursorReplace-' .. blink,
    'c:block-CursorCommand-' .. blink,
    'o:block-CursorNormal-' .. blink,
  }, ',')
  
  local function cl() hl('CursorLineNr', { fg = MODES[vim.fn.mode()] or MODES.n, bg = 'NONE', bold = true }) end
  cl()
  vim.api.nvim_create_autocmd('ModeChanged', { pattern = '*', callback = cl })

  -- Toggle relative/absolute line numbers based on mode
  
  local au = vim.api.nvim_create_autocmd
  local grp = vim.api.nvim_create_augroup('numbertoggle', { clear = true })
  au({ 'InsertLeave', 'WinEnter' }, { group = grp, command = 'set relativenumber' })
  au({ 'InsertEnter', 'WinLeave' }, { group = grp, command = 'set norelativenumber' })

  -- Prevent cursor from jumping back when leaving insert mode
  au('InsertLeave', {
    group = vim.api.nvim_create_augroup('cursorfix', { clear = true }),
    callback = function()
      local col = vim.fn.col('.')
      local line = vim.fn.getline('.')
      if col > 1 and col <= #line then
        vim.fn.cursor(vim.fn.line('.'), col + 1)
      end
    end,
  })
end)

-- Lualine
now(function()
  -- vim.opt.cmdheight = 0
  add({ source = 'nvim-lualine/lualine.nvim' })

  local mode_map = {
    n = 'N',
    i = 'I',
    v = 'V',
    V = 'V',
    [''] = 'V',
    c = 'C',
    R = 'R',
    s = 'S',
    S = 'S',
    [''] = 'S',
    t = 'T',
    nt = 'N',
  }

  vim.api.nvim_set_hl(0, 'StatusLine', { bg = 'NONE' })
  vim.api.nvim_set_hl(0, 'StatusLineNC', { bg = 'NONE' }) 

  local empty = { fg = '#c0ccdb', bg = 'NONE' }

  require('lualine').setup({
    options = {
      component_separators = '',
      section_separators = '',
      globalstatus = true,
      theme = {
        normal = { a = empty, b = empty, c = empty },
        insert = { a = empty, b = empty, c = empty },
        visual = { a = empty, b = empty, c = empty },
        replace = { a = empty, b = empty, c = empty },
        command = { a = empty, b = empty, c = empty },
        inactive = { a = empty, b = empty, c = empty },
      },
    },
    sections = {
      lualine_a = { {
        function()
          return mode_map[vim.fn.mode()] or vim.fn.mode():upper()
        end,
        color = function()
          return { fg = MODES[vim.fn.mode()] or '#c0ccdb', gui = 'bold' }
        end,
        padding = { left = 1, right = 1 },
      } },
      lualine_b = { 'branch', 'diff', 'diagnostics' },
      lualine_c = { { 'filename', path = 1 } },
      lualine_x = { 'encoding', 'filetype' },
      lualine_y = { 'progress', 'location' },
      lualine_z = { {
        function() return os.date('%H:%M') end,
        padding = { left = 1, right = 1 },
      } },
    },
  })
end)

-- Multi-cursor
now(function()
  add({ source = 'mg979/vim-visual-multi' })
  vim.g.VM_maps = {}
  vim.g.VM_maps['Find Under']         = KEYMAP.multicursor
  vim.g.VM_maps['Find Subword Under'] = KEYMAP.multicursor
  vim.g.VM_theme = 'neon'
end)

-- Telescope (fuzzy finder)
now(function()
  add({
    source = 'nvim-telescope/telescope.nvim',
    depends = {
      'nvim-lua/plenary.nvim',
      'nvim-telescope/telescope-fzf-native.nvim',
    },
  })
  local telescope = require('telescope')
  local actions = require('telescope.actions')

  telescope.setup({
    defaults = {
      path_display = { 'smart' },
      mappings = {
        i = {
          ['<C-j>'] = actions.move_selection_next,
          ['<C-k>'] = actions.move_selection_previous,
          ['<Esc>'] = actions.close,
        },
      },
    },
  })
  
  km('n', KEYMAP.find_files, '<cmd>Telescope find_files<cr>', { desc = 'Find files' })
  km('n', KEYMAP.live_grep, '<cmd>Telescope live_grep<cr>', { desc = 'Live grep' })
  km('n', KEYMAP.buffers, '<cmd>Telescope buffers<cr>', { desc = 'Find buffers' })
  km('n', KEYMAP.help_tags, '<cmd>Telescope help_tags<cr>', { desc = 'Help tags' })
  km('n', KEYMAP.oldfiles, '<cmd>Telescope oldfiles<cr>', { desc = 'Recent files' })
  km('n', KEYMAP.grep_string, '<cmd>Telescope grep_string<cr>', { desc = 'Grep word under cursor' })
  km('n', KEYMAP.recent_files, '<cmd>Telescope oldfiles<cr>', { desc = 'Recent files' })
end)
