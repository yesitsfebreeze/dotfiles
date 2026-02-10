-- Telescope setup module:
-- - Installs telescope and dependencies
-- - Configures default mappings and UI
-- - Other modules can just use telescope without setup

local vim = vim or {}
local def = require('defaults')
local screen = require('screen')

local M = {}
local add, later = require('deps').add, require('deps').later

local defaults = {
	exclude_extensions = {},  -- File extensions to exclude (e.g., {'jpg', 'png', 'pdf'})
}

local default_config = nil

function M.get_custom_sorter(opts)
	opts = opts or {}
	local conf = require('telescope.config').values
	local sorters = require('telescope.sorters')
	local default_sorter = conf.file_sorter(opts)
	
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
		table.insert(ignore_patterns, '.' .. ext)
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
	}
	
	-- Add glob exclusions for each extension
	for _, ext in ipairs(o.exclude_extensions) do
		table.insert(vimgrep_arguments, '--glob')
		table.insert(vimgrep_arguments, '!*.' .. ext)
	end

	local actions = require('telescope.actions')
	local config = {
		borderchars = M.get_border(),
		path_display = M.format_path,
		sorter = M.get_custom_sorter(),
		file_ignore_patterns = ignore_patterns,
		vimgrep_arguments = vimgrep_arguments,
		file_sorter = M.get_custom_sorter,
		generic_sorter = M.get_custom_sorter,
		mappings = {
			i = {
				["<esc>"] = actions.close,
				["<C-q>"] = false,
				["<M-q>"] = false,
			},
			n = {
				["<C-q>"] = false,
				["<M-q>"] = false,
			},
		},
	}

	default_config = config
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
		require('telescope').setup({ defaults = M.get_default_config() })
		
		local telescope_group = vim.api.nvim_create_augroup('TelescopeConfig', { clear = true })
		
		-- Completely disable quickfix window opening
		vim.api.nvim_create_autocmd('FileType', {
			group = telescope_group,
			pattern = 'qf',
			callback = function(ev)
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
