-- Telescope setup module:
-- - Installs telescope and dependencies
-- - Configures default mappings and UI
-- - Other modules can just use telescope without setup

local vim = vim or {}
local deps = require('feb/deps')
local def = require('feb/defaults')
local screen = require('feb/screen')

local M = {}
local add, later = deps.add, deps.later

local defaults = {
	exclude_extensions = {},  -- File extensions to exclude (e.g., {'jpg', 'png', 'pdf'})
	max_results = 500,       -- Cap total results to prevent lag in large codebases
	max_results_per_file = 10, -- Cap matches per file for ripgrep (--max-count)
}

local default_config = nil

function M.get_custom_sorter(opts)
	opts = opts or {}
	local sorters = require('telescope.sorters')
	local default_sorter = sorters.get_fuzzy_file(opts)

	local original_scoring = default_sorter.scoring_function
	local original_highlighter = default_sorter.highlighter

	default_sorter.scoring_function = function(self, prompt, line, entry)
		local base_score = original_scoring(self, prompt, line, entry)

		if prompt == '' or not prompt then
			return base_score
		end

		local text = line:lower()
		local search = prompt:lower()

		-- Check for anchors
		local has_start = search:sub(1, 1) == '^'
		local has_end = search:sub(-1) == '$'

		if not has_start and not has_end then
			return base_score
		end

		-- Extract pattern without anchors
		local pattern = search
		if has_start then pattern = pattern:sub(2) end
		if has_end then pattern = pattern:sub(1, -2) end

		if pattern == '' then return base_score end

		-- Check for wildcards
		local has_wildcard = pattern:find('*', 1, true) ~= nil

		if has_wildcard then
			-- Convert to Lua pattern: escape special chars except *
			local lua_pattern = pattern:gsub('[%(%)%.%%%+%-%?%[%]%^%$]', '%%%1'):gsub('*', '.*')

			-- Add anchors to the pattern
			if has_start and has_end then
				lua_pattern = '^' .. lua_pattern .. '$'
			elseif has_start then
				lua_pattern = '^' .. lua_pattern
			elseif has_end then
				lua_pattern = lua_pattern .. '$'
			end

			-- Match with wildcard pattern
			if not text:match(lua_pattern) then
				return -1  -- Reject if doesn't match pattern
			end

			return base_score * 1.5
		end

		-- Apply exact anchor filtering (no wildcards)
		if has_start and text:sub(1, #pattern) ~= pattern then
			return -1  -- Reject if doesn't start with pattern
		end

		if has_end and text:sub(-#pattern) ~= pattern then
			return -1  -- Reject if doesn't end with pattern
		end

		-- Passed anchor checks, boost the score
		return base_score * 1.5
	end

	default_sorter.highlighter = function(self, prompt, display)
		if not prompt or prompt == '' then
			return original_highlighter(self, prompt, display)
		end

		-- Remove anchors and wildcards for highlighting
		local has_start = prompt:sub(1, 1) == '^'
		local has_end = prompt:sub(-1) == '$'
		local pattern = prompt
		if has_start then pattern = pattern:sub(2) end
		if has_end then pattern = pattern:sub(1, -2) end

		-- Remove wildcards for highlighting (highlight what remains)
		pattern = pattern:gsub('*', '')

		return original_highlighter(self, pattern, display)
	end

	return default_sorter
end

-- Get border configuration for Telescope
function M.get_border()
	local b = def.float_border
	return { b[2], b[4], b[6], b[8], b[1], b[3], b[5], b[7] }
end

-- Get default telescope configuration with sorter, borders, and formatting
function M.get_default_config(overrides)

	local config = default_config

	if overrides then
		return vim.tbl_deep_extend('force', config, overrides)
	end

	return config

end

function M._create_default_config(o)
	-- Build file_ignore_patterns from exclude_extensions  
	local ignore_patterns = {}
	for _, ext in ipairs(o.exclude_extensions) do
		-- Escape dots for Lua patterns (%.sql matches literal .sql)
		local escaped = ext:gsub('%.', '%%.')
		table.insert(ignore_patterns, '%.' .. escaped)
	end

	-- Build ripgrep arguments with glob exclusions
	local vimgrep_arguments = {
		'rg',
		'--color=never',
		'--no-heading',
		'--with-filename',
		'--line-number',
		'--column',
		'--smart-case',
		'--max-count=' .. o.max_results_per_file,
	}

	-- Add glob exclusions for each extension
	for _, ext in ipairs(o.exclude_extensions) do
		table.insert(vimgrep_arguments, '--glob')
		table.insert(vimgrep_arguments, '!*.' .. ext)
	end

	local actions = require('telescope.actions')

	-- Non-blocking close action for better performance
	local function fast_close(prompt_bufnr)
		-- Close immediately without waiting for cleanup
		vim.schedule(function()
			actions.close(prompt_bufnr)
		end)
	end

	default_config = {  -- Set module-level variable (no 'local')
		path_display = M.format_path,
		sorter = M.get_custom_sorter(),
		file_ignore_patterns = ignore_patterns,
		vimgrep_arguments = vimgrep_arguments,
		file_sorter = M.get_custom_sorter,
		generic_sorter = M.get_custom_sorter,

		-- Cap total results to prevent lag in large codebases
		max_results = o.max_results,

		-- Disable borders
		border = false,

		-- Results from top to bottom
		sorting_strategy = 'ascending',

		-- Layout configuration - same for ALL pickers
		-- Each section (results, preview) grows dynamically: 0 min, 16 max
		layout_strategy = 'vertical',
		layout_config = {
			width = function(_, max_columns) return max_columns end,
			height = function(self, _, max_lines)
				local max_section = 16
				local num_results = 0
				if self.manager and type(self.manager) == "table" and self.manager.num_results then
					num_results = self.manager:num_results()
				end
				local results_h = math.min(num_results, max_section)
				local preview_h = math.min(num_results, max_section)
				-- prompt(1) + results + preview + 2 spacing lines (removed by patch but needed for layout calc)
				return math.min(1 + results_h + preview_h + 2, max_lines)
			end,
			preview_height = function(self, _, _)
				local max_section = 16
				local num_results = 0
				if self.manager and type(self.manager) == "table" and self.manager.num_results then
					num_results = self.manager:num_results()
				end
				return math.min(num_results, max_section)
			end,
			prompt_position = 'top',
			mirror = true,  -- With prompt_position='top', this gives: Prompt, Results, Preview
		},

		-- Preview configuration
		preview = {
			check_mime_type = false,  -- Show preview for all file types
		},

		-- Performance optimizations
		cache_picker = false,  -- Don't cache picker state (prevents memory buildup)
		scroll_strategy = 'limit',  -- Limit scrolling for performance
		selection_strategy = 'reset',  -- Reset selection on prompt change

		mappings = {
			i = {
				["<esc>"] = fast_close,
				["<C-q>"] = false,
				["<M-q>"] = false,
			},
			n = {
				["<esc>"] = fast_close,
				["<C-q>"] = false,
				["<M-q>"] = false,
			},
		},
	}
end


-- Patch vertical layout to remove 1-line gaps between sections
function M._patch_vertical_layout()
	local strategies = require('telescope.pickers.layout_strategies')
	local _vertical = strategies.vertical

	strategies.vertical = function(self, max_columns, max_lines, override_layout)
		local layout = _vertical(self, max_columns, max_lines, override_layout)

		-- Only remove gaps when borders are disabled
		if self.window and self.window.border == false then
			local windows = {}
			for _, key in ipairs({ 'prompt', 'results', 'preview' }) do
				if layout[key] then
					table.insert(windows, layout[key])
				end
			end
			table.sort(windows, function(a, b) return a.line < b.line end)

			-- Close gaps: position each window immediately after the previous
			for i = 2, #windows do
				local prev = windows[i - 1]
				windows[i].line = prev.line + prev.height
			end
		end

		return layout
	end
end

-- Format path to ensure filename is visible
function M.format_path(_, path)
	local filename = vim.fn.fnamemodify(path, ':t')
	local max_width = screen.get().telescope.width - 6
	if #path <= max_width then return path end
	local avail = max_width - #filename - 4
	if avail > 0 then
		return path:sub(1, avail) .. '...' .. filename
	end
	return '...' .. filename
end

function M.setup(opts)
	local o = vim.tbl_deep_extend('force', defaults, opts or {})

	add({ source = 'nvim-telescope/telescope.nvim', depends = { 'nvim-lua/plenary.nvim' } })

	later(function()
		M._create_default_config(o)
		M._patch_vertical_layout()
		require('telescope').setup({
			defaults = M.get_default_config(),
			pickers = {
				-- Empty configs ensure no picker overrides the default layout
				live_grep = {},
				grep_string = {},
				find_files = {},
				oldfiles = {},
				buffers = {},
				git_commits = {},
				git_bcommits = {},
				lsp_references = {},
				lsp_definitions = {},
				lsp_implementations = {},
				diagnostics = {},
			}
		})

		local telescope_group = vim.api.nvim_create_augroup('TelescopeConfig', { clear = true })

		-- Prevent telescope prompts from being marked as modified
		-- Hide windows initially, poll every 16ms, show+resize once results load
		vim.api.nvim_create_autocmd('FileType', {
			group = telescope_group,
			pattern = 'TelescopePrompt',
			callback = function(ev)
				vim.bo[ev.buf].modified = false
				vim.bo[ev.buf].bufhidden = 'wipe'

				local state = require('telescope.state')

				-- Hide results/preview windows (not prompt) until results load
				local hidden_wins = {}
				local status = state.get_status(ev.buf)
				if status and status.layout then
					for _, key in ipairs({ 'results', 'preview' }) do
						local w = status.layout[key]
						if w and w.winid and vim.api.nvim_win_is_valid(w.winid) then
							table.insert(hidden_wins, w.winid)
							vim.wo[w.winid].winblend = 100
						end
					end
				end

				-- Poll every 50ms to dynamically resize as results change
				local timer = vim.uv.new_timer()
				local last_count = -1
				local revealed = false
				local last_update = 0
				local update_throttle = 150  -- minimum ms between layout updates

				timer:start(0, 10, vim.schedule_wrap(function()
					if not vim.api.nvim_buf_is_valid(ev.buf) then
						timer:stop()
						pcall(timer.close, timer)
						return
					end

					local s_ok, s = pcall(state.get_status, ev.buf)
					if not s_ok or not s or not s.layout or not s.picker then return end

					local count = 0
					local mgr = s.picker.manager
					if mgr and type(mgr) == 'table' and mgr.num_results then
						count = mgr:num_results()
					end

					-- Update result count for statusline
					pcall(function() vim.b[ev.buf].query_count = count end)

					-- Throttled resize when result count changes
					if count ~= last_count then
						local now = vim.uv.now()
						if now - last_update >= update_throttle then
							last_count = count
							last_update = now
							pcall(function() s.layout:update() end)
						end
					end

					-- Reveal results/preview once results are available
					if count > 0 and not revealed then
						revealed = true
						for _, winid in ipairs(hidden_wins) do
							if vim.api.nvim_win_is_valid(winid) then
								vim.wo[winid].winblend = 0
							end
						end
					end

					-- Re-hide if results go back to 0 (e.g. clearing search)
					if count == 0 and revealed then
						revealed = false
						for _, winid in ipairs(hidden_wins) do
							if vim.api.nvim_win_is_valid(winid) then
								vim.wo[winid].winblend = 100
							end
						end
					end
				end))
			end,
		})

		-- Completely disable quickfix window opening
		vim.api.nvim_create_autocmd('FileType', {
			group = telescope_group,
			pattern = 'qf',
			callback = function(_)
				-- Close any quickfix window that opens
				vim.defer_fn(function()
					vim.cmd('cclose')
					vim.cmd('lclose')
				end, 0)
			end,
		})
	end)
end

return M
