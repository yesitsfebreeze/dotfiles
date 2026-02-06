--@~/.config/nvim/init.lua

palette = dofile(vim.fn.stdpath('config') .. '/../palette.lua')
hl = function(group, opts) vim.api.nvim_set_hl(0, group, opts) end
gr = vim.api.nvim_create_augroup('CustomCommands', { clear = true })
np = function(p) return p:lower():gsub("^([a-z]):", "(%1_)"):gsub("^/", ""):gsub("[/\\]+", "_"):gsub("^_+", "") end
rp = function(s) return s:gsub("^%(([a-z])_%)", "%1:"):gsub("_", "/"):gsub("^([^/])", "/%1") end
jp = function(...) return vim.fs.joinpath(...) end
aucmd=function(e,c,g) vim.api.nvim_create_autocmd(e,{group=g or gr,[type(c)=='function'and'callback'or'command']=c}) end
bind=function(b,f,d,m) vim.keymap.set(m or b.modes,b.bind,f,{desc=d}) end
enter_insert_mode=function() if vim.bo.buftype=='' and vim.bo.filetype~='' and vim.bo.filetype~='oil' then vim.cmd'startinsert' end end
startup = function(cb, dl) vim.api.nvim_create_autocmd('VimEnter', { callback = function() vim.defer_fn(cb, dl) end, once = true }) end

local pkg  = vim.fn.stdpath('data') .. '/site'
local path = pkg .. '/pack/deps/start/mini.nvim'
if not (vim.uv or vim.loop).fs_stat(path) then
  vim.fn.system({ 'git', 'clone', '--filter=blob:none', 'https://github.com/nvim-mini/mini.nvim', path })
  vim.cmd('packadd mini.nvim')
end
require('mini.deps').setup({ path = { package = pkg } })
local add, now, later = MiniDeps.add, MiniDeps.now, MiniDeps.later

-- Δ == Ctrl+Shift
local KEYMAP = {
	exit = { bind = '<Esc>', modes = { 'i', 'v' } },
	leader = { bind = '<F24>', modes = { 'n', 'i', 'v' } },
	cmd = { bind = '<C-k>', modes = { 'n', 'i' } },
	quit = { bind = "<C-q>", modes = {'n', 'i'} },
	hard_quit = { bind = "<C-Q>", modes = {'n', 'i'} },
	save = { bind = "<C-s>", modes = {'n', 'i'} },
	save_all = { bind = "Δs", modes = {'n', 'i'} },
	old_files = { bind = "<C-o>", modes = {'n', 'i'} },
	find_files = { bind = "Δf", modes = {'n', 'i'} },
	find = { bind = "<C-f>", modes = {'n', 'i'} },
	buffers = { bind = "<C-r>", modes = {'n', 'i'} },
	sessions = { bind = "<C-p>", modes = {'n', 'i'} },
	gotoline = { bind = "<C-l>", modes = {'n', 'i'} },
	undo = { bind = "<C-z>", modes = {'n', 'i'} },
	redo = { bind = "Δz", modes = {'n', 'i'} },
}

now(function()
	vim.g.mapleader = KEYMAP.leader.bind
	vim.g.maplocalleader = KEYMAP.leader.bind
	vim.g.keep_normal_mode = false

	-- basically inverted vim, we are default in insert mode
	-- and a key to go to normal mode, ESC always goes to insert mode
	aucmd({'BufEnter', 'BufWinEnter'}, enter_insert_mode)
	bind(KEYMAP.exit, '<Nop>', 'Disabled - use leader key instead', 'i')
	bind(KEYMAP.leader, function()
		vim.g.keep_normal_mode = true
		vim.cmd('stopinsert')
	end, 'Exit to Normal Mode', 'i')
	bind(KEYMAP.exit, function() vim.cmd('startinsert') end, 'Return to Insert Mode', 'n')
	aucmd('ModeChanged', function()
		local mode = vim.fn.mode()
		if mode == 'n' and not vim.g.keep_normal_mode then
			vim.schedule(function() vim.cmd('startinsert') end)
		elseif mode == 'i' then
			vim.g.keep_normal_mode = false
		end
	end)

	bind(KEYMAP.quit, function() vim.cmd('confirm quit') end, 'Quit')
	bind(KEYMAP.hard_quit, function() vim.cmd('confirm qall') end, 'Quit All')

	bind(KEYMAP.save, '<cmd>w<cr>', 'Save file')
	bind(KEYMAP.save_all, '<cmd>wa<cr>', 'Save all files')
	bind(KEYMAP.undo, '<cmd>undo<cr>', 'Undo')
	bind(KEYMAP.redo, '<cmd>redo<cr>', 'Redo')
	bind(KEYMAP.cmd, '<ESC>:', 'Command mode')

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
		
	vim.opt.backspace = 'indent,eol,start'
	vim.opt.clipboard:append('unnamedplus')
	vim.opt.splitright = true
	vim.opt.splitbelow = true
	vim.opt.swapfile = false
	vim.opt.scrolloff = 999

	-- Dynamic padding to center cursor at both top and bottom of file
	local padding_ns = vim.api.nvim_create_namespace('dynamic_padding')
	local prev_top_padding = -1
	local prev_bottom_padding = -1
	
	local function update_centering()
		local buf = vim.api.nvim_get_current_buf()
		if vim.bo[buf].buftype ~= '' or vim.bo[buf].filetype == 'oil' then return end
		
		local cursor_line = vim.api.nvim_win_get_cursor(0)[1]
		local win_height = vim.api.nvim_win_get_height(0)
		local half_height = math.floor(win_height / 2)
		local total_lines = vim.api.nvim_buf_line_count(buf)
		
		-- Calculate top padding: half_height - cursor_line (when cursor is near top)
		local needed_top_padding = math.max(0, half_height - cursor_line)
		
		-- Calculate bottom padding: cursor_line - (total_lines - half_height) (when cursor is near bottom)
		local needed_bottom_padding = math.max(0, cursor_line - (total_lines - half_height))
		
		-- Only update if padding changed
		if needed_top_padding == prev_top_padding and needed_bottom_padding == prev_bottom_padding then 
			return 
		end
		
		-- Clear existing padding
		vim.api.nvim_buf_clear_namespace(buf, padding_ns, 0, -1)
		
		-- Add top padding
		if needed_top_padding > 0 then
			local pad_lines = {}
			for i = 1, needed_top_padding do
				table.insert(pad_lines, {{'', 'Normal'}})
			end
			
			vim.api.nvim_buf_set_extmark(buf, padding_ns, 0, 0, {
				virt_lines_above = true,
				virt_lines = pad_lines,
			})
			
			-- Reset to topline 1 and scroll up to show virtual lines
			vim.fn.winrestview({ topline = 1 })
			for i = 1, needed_top_padding do
				vim.cmd('execute "normal! \\<C-y>"')
			end
		end
		
		-- Add bottom padding
		if needed_bottom_padding > 0 then
			local pad_lines = {}
			for i = 1, needed_bottom_padding do
				table.insert(pad_lines, {{'', 'Normal'}})
			end
			
			vim.api.nvim_buf_set_extmark(buf, padding_ns, total_lines - 1, 0, {
				virt_lines = pad_lines,
			})
		end
		
		prev_top_padding = needed_top_padding
		prev_bottom_padding = needed_bottom_padding
	end
	
	-- Schedule on buffer entry to ensure window is fully set up
	aucmd({'BufWinEnter', 'BufEnter'}, function()
		vim.schedule(update_centering)
	end)
	
	aucmd({'CursorMoved', 'CursorMovedI'}, update_centering)

	add({ source = 'tribela/transparent.nvim', name = 'transparent' })
	add({ source = 'oskarnurm/koda.nvim', name = 'koda' })
	
	require('transparent').setup({})
	require('koda').setup({
		transparent = true,
		colors = {
			bg         = palette.background,
			fg         = palette.foreground,
			dim        = '#000000',
			line       = 'NONE',
			keyword    = palette.keyword,
			comment    = palette.comment,
			border     = palette.foreground,
			emphasis   = palette.foreground,
			func       = palette.func,
			string     = palette.string,
			const      = palette.constant,
			highlight  = palette.cyan,
			info       = palette.info,
			success    = palette.green,
			warning    = palette.warning,
			danger     = palette.error,
			green      = palette.green,
			orange     = palette.orange,
			red        = palette.red,
			pink       = palette.purple,
			cyan       = palette.cyan,
		},
	})
  vim.cmd('colorscheme koda')
  hl('CursorLine', {bg='NONE', fg='NONE'})
end)

later(function()
	local m=palette.modes
	for k,v in pairs{Normal=m.n,Insert=m.i,Visual=m.v,Replace=m.R,Command=m.c} do
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

-- Oil
now(function()
	add({ source = 'stevearc/oil.nvim' })
	local oil = require('oil')
	oil.setup({
		default_file_explorer = true,
		view_options = {
				show_hidden = true,
		--   is_hidden_file = function(name, bufnr) return name:match('^%.') ~= nil end
		--   is_always_hidden = function(name, bufnr) return false end
		--   natural_order = 'fast',
		--   case_insensitive = false,
			sort = {
				{ 'type', 'asc' },
				{ 'name', 'asc' },
			},
			highlight_filename = function(entry, is_hidden, is_link_target, is_link_orphan) return nil end
		},
		columns = {
			'icon',
			'size',
		},
		keymaps = {
			['<leader>e'] = 'actions.close',
		},
	})
--   bind('n', KEYMAP.explorer, oil.open, { desc = 'Open Oil file explorer' })
end)

-- Session management
now(function()
	local session_name = np(vim.fn.getcwd())
	local has_file_arg = vim.fn.argc() > 0 and vim.fn.argv(0) ~= '.'

	add('echasnovski/mini.sessions')
	require('mini.sessions').setup({ autoread = false, autowrite = false })

	-- Only handle sessions if no file argument was passed
	if not has_file_arg then
		startup(function()
			local sesh = jp(require('mini.sessions').config.directory, session_name)
			
			if vim.fn.filereadable(sesh) == 1 then
				-- Session exists: load it
				local ok = pcall(function() 
					require('mini.sessions').read(session_name, { force = true }) 
				end)
				if ok then 
					print('Loaded session: ' .. session_name) 
				end
			else
				-- No session exists: create one and open Oil
				require('mini.sessions').write(session_name, { force = true })
				print('Created new session: ' .. session_name)
				require('oil').open()
			end
		end, 2)
		
		-- Auto-save session on exit
		vim.api.nvim_create_autocmd('VimLeavePre', { 
			callback = function()
				print('Saving session: ' .. session_name)
				require('mini.sessions').write(session_name, { force = true })
			end
		})
	end
end)

-- Lualine
now(function()
	add({ source = 'nvim-lualine/lualine.nvim' })
	add({ source = 'folke/noice.nvim', depends = { 'MunifTanjim/nui.nvim' } })

	vim.opt.cmdheight = 0
	vim.opt.laststatus = 0
	vim.opt.showmode = false

	local m = { n = 'N', i = 'I', v = 'V', V = 'V', [''] = 'V', c = 'C', R = 'R', t = 'T' }
	local e = { fg = '#c0ccdb', bg = 'NONE' }

	require('lualine').setup({
		options = { component_separators = '', section_separators = '', globalstatus = true, 
			theme = { normal = {a=e,b=e,c=e}, insert = {a=e,b=e,c=e}, visual = {a=e,b=e,c=e}, replace = {a=e,b=e,c=e}, command = {a=e,b=e,c=e} }},
		sections = {}, inactive_sections = {},
		tabline = {
			lualine_a = {{ function() return vim.fn.mode()=='c' and ' :' or '   '..m[vim.fn.mode()] end, 
				color = function() return {fg=palette.modes[vim.fn.mode()]or'#c0ccdb',gui='bold'} end }},
			lualine_b = {'branch','diff','diagnostics'},
			lualine_c = {{ function() return vim.fn.mode()=='c' and vim.fn.getcmdline() or vim.fn.expand('%:~:.') end,
				color = function() return vim.fn.mode()=='c' and {fg=palette.modes.c} or nil end }},
			lualine_x = { function() return vim.fn.mode()~='c' and vim.bo.filetype or '' end },
			lualine_y = { function() return vim.fn.mode()~='c' and vim.fn.line('.')..':'..vim.fn.col('.') or '' end },
			lualine_z = {{ function() return vim.fn.mode()~='c' and os.date('%H:%M') or '' end }},
		},
	})

	local pad = '    '
		require('noice').setup({
		cmdline = { 
			enabled = true, 
			view = 'cmdline',
			format = {
				cmdline = { icon = pad..':' },
				search_down = { icon = pad..'/' },
				search_up = { icon = pad..'?' },
				filter = { icon = pad..'!' },
				lua = { icon = pad..' :lua' },
				help = { icon = pad..':help' },
			}
		},
		messages = { enabled = true, view = 'mini', view_error = 'mini', view_warn = 'mini' },
		popupmenu = { enabled = false },
		views = { cmdline = { position = { row = 0, col = 0 }, size = { width = '100%', height = 'auto' } } },
		routes = {{ view = 'mini', filter = { event = 'msg_showmode' } }},
	})
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

	-- Smart old files: recent files, but search files when typing
	local function smart_old_files()
		local pickers = require('telescope.pickers')
		local finders = require('telescope.finders')
		local conf = require('telescope.config').values
		local make_entry = require('telescope.make_entry')

		-- Get oldfiles filtered to current working directory
		local cwd = vim.fn.getcwd()
		local oldfiles = vim.tbl_filter(function(file)
			return vim.fn.filereadable(file) == 1 and vim.startswith(file, cwd)
		end, vim.v.oldfiles)

		pickers.new({}, {
			prompt_title = 'Recent Files (type to search all files)',
			finder = finders.new_dynamic({
				fn = function(prompt)
					if not prompt or prompt == "" then
						-- No input: show recent files
						return oldfiles
					else
						-- Has input: search all files by name in cwd using ripgrep
						local results = {}
						local handle = io.popen('cd ' .. vim.fn.shellescape(cwd) .. ' && rg --files --hidden --glob "!.git/" --glob "!node_modules/" 2>/dev/null')
						if handle then
							for line in handle:lines() do
								if line:lower():find(prompt:lower(), 1, true) then
									table.insert(results, line)
								end
							end
							handle:close()
						end
						return results
					end
				end,
				entry_maker = function(entry)
					return make_entry.gen_from_file({})(entry)
				end,
			}),
			sorter = conf.generic_sorter({}),
			previewer = conf.file_previewer({}),
		}):find()
	end

	-- Session picker
	local function telescope_sessions()
		local pickers = require('telescope.pickers')
		local finders = require('telescope.finders')
		local conf = require('telescope.config').values
		local actions = require('telescope.actions')
		local action_state = require('telescope.actions.state')

		local session_dir = require('mini.sessions').config.directory
		local sessions = vim.fn.glob(session_dir .. '/*', false, true)
		local session_names = vim.tbl_map(function(path)
			return vim.fn.fnamemodify(path, ':t')
		end, sessions)

		pickers.new({}, {
			prompt_title = 'Sessions',
			finder = finders.new_table({ 
				results = session_names,
				entry_maker = function(entry)
					return {
						value = entry,
						display = rp(entry),
						ordinal = entry,
					}
				end
			}),
			sorter = conf.generic_sorter({}),
			attach_mappings = function(prompt_bufnr, map)
				actions.select_default:replace(function()
					actions.close(prompt_bufnr)
					local selection = action_state.get_selected_entry()
					if selection then
						require('mini.sessions').read(selection.value, { force = true })
						print('Loaded session: ' .. selection.display)
					end
				end)
				return true
			end,
		}):find()
	end

  bind(KEYMAP.old_files, smart_old_files, 'Find recently opened files')
	bind(KEYMAP.find_files, '<cmd>Telescope live_grep<cr>', 'Search in file content')
	bind(KEYMAP.find, '<cmd>Telescope current_buffer_fuzzy_find<cr>', 'Find in current buffer')
	bind(KEYMAP.buffers, '<cmd>Telescope buffers<cr>', 'Buffer switch')
	bind(KEYMAP.sessions, telescope_sessions, 'Switch sessions')

--   km('n', KEYMAP.find_files, '<cmd>Telescope find_files<cr>', { desc = 'Find files' })
--   km('n', KEYMAP.live_grep, '<cmd>Telescope live_grep<cr>', { desc = 'Live grep' })
--   km('n', KEYMAP.buffers, '<cmd>Telescope buffers<cr>', { desc = 'Find buffers' })
--   km('n', KEYMAP.help_tags, '<cmd>Telescope help_tags<cr>', { desc = 'Help tags' })
--   km('n', KEYMAP.oldfiles, '<cmd>Telescope oldfiles<cr>', { desc = 'Recent files' })
--   km('n', KEYMAP.grep_string, '<cmd>Telescope grep_string<cr>', { desc = 'Grep word under cursor' })
--   km('n', KEYMAP.recent_files, '<cmd>Telescope oldfiles<cr>', { desc = 'Recent files' })
end)
