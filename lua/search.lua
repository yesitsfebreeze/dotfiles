-- Query: Unified search interface with mode selector

local vim = vim or {}

local M = {}
local keymap = require('keymap')
local sessions = require('sessions')
local pickers = require('telescope.pickers')
local finders = require('telescope.finders')
local conf = require('telescope.config').values
local actions = require('telescope.actions')
local action_state = require('telescope.actions.state')
local builtin = require('telescope.builtin')

local defaults = {
	hotkeys = {
        open = "<C-Space>",
        close = "<Esc>",
        switch = "<Tab>",
    }
}
	
local FILTER = 'filter'
local GREP = 'grep'

local current_buffer = nil

local MODE_FILES = 0
local MODE_BUFFERS = 1
local MODE_RECENT = 2
local MODE_GREP = 3
local MODE_DIAGNOSTICS = 4
local MODE_SESSIONS = 5
local MODE_COMMITS = 6

vim.g.smart_query = {
    open = false,
    mode = MODE_GREP,
    view = FILTER,
    inputs = {
        filter = '',
        grep = '',
    },
    files = {},
    selected = nil,
}

local MODES = {
    [MODE_FILES] = { display = 'Files', key = 'path' },
    [MODE_BUFFERS] = { display = 'Buffers', key = 'filename' },
    [MODE_RECENT] = { display = 'Recent', key = 'value' },
    [MODE_GREP] = { display = 'Grep', key = 'filename' },
    [MODE_DIAGNOSTICS] = { display = 'Diagnostics', key = 'filename' },
    [MODE_SESSIONS] = { display = 'Sessions', key = nil },
    [MODE_COMMITS] = { display = 'Commits', key = nil },
}

local PICKERS = {}

-- Forward declaration needed due to circular dependency: intercept <-> grep_in_files
local grep_in_files

local function ensure_session_file()
    local name = sessions.get_session_name()
    local dir = vim.fn.stdpath('data') .. '/smart_query'
    if vim.fn.isdirectory(dir) == 0 then vim.fn.mkdir(dir, 'p') end
    local file = dir .. '/query_' .. name .. '.json'
    return file
end

local function store()
    local session_file = ensure_session_file()
    if not session_file then return end
    local json = vim.fn.json_encode(vim.g.smart_query)
    local file = io.open(session_file, 'w')
    if file then
        file:write(json)
        file:close()
    end
end

local function restore()
    local session_file = ensure_session_file()
    if not session_file then return end
    if vim.fn.filereadable(state_file) ~= 1 then return end

    local file = io.open(state_file, 'r')
    if not file then return end 

    local json = file:read('*a')
    file:close()
    local ok, data = pcall(vim.fn.json_decode, json)
    if not (ok and data) then return end

    vim.g.smart_query = data
end

local function layout()
    local size = require('screen').get().telescope

    return {
        layout_strategy = 'vertical',
        layout_config = {
            anchor = 'E',
            width = size.width,
            height = size.height,
            preview_height = 0.5,
            prompt_position = 'bottom',
        }
    }
end

local function collect_files(picker, mode_id)
    local files = {}
    local seen = {}
    
    local mode = MODES[mode_id]
    if not mode or not mode.key then return files end
    
    for entry in picker.manager:iter() do
        if entry then
            local file = entry[mode.key]
            if file and not seen[file] then
                seen[file] = true
                table.insert(files, file)
            end
        end
    end
    
    return files
end

local function close()
    local s = vim.g.smart_query
    store()
    if current_buffer then actions.close(current_buffer) end
    current_buffer = nil
    s.is_open = false
    vim.g.smart_query = s
end

local function intercept(bufnr, map, opts)
    current_buffer = bufnr
    map('i', opts.hotkeys.close, close)
    
    map('i', opts.hotkeys.switch, function()
        local s = vim.g.smart_query
        
        if s.view == FILTER then
            local p = action_state.get_current_picker(bufnr)
            if not p or not p.manager then  return  end
            
            s.filter_input = p:_get_prompt()
            local files = collect_files(p, s.mode)

            if #files > 0 then
                s.view = GREP
                s.files = files
                s.selected = s.mode
                vim.g.smart_query = s
                actions.close(bufnr)
                grep_in_files(opts)
            end
            return
        end

        if s.view == GREP then
            local p = action_state.get_current_picker(bufnr)
            s.grep_input = p:_get_prompt()
            s.view = FILTER
            vim.g.smart_query = s
            store()
            actions.close(bufnr)
            print("DEBUG: switching back to FILTER, s.mode=" .. tostring(s.mode) .. " display=" .. tostring(MODES[s.mode] and MODES[s.mode].display))
            if PICKERS[s.mode] then
                PICKERS[s.mode]()
            end
            return
        end
    end)
    
    return true
end

local function sessions_picker(opts)
    local dir = vim.fn.stdpath('data') .. '/sessions'
    local files = vim.fn.glob(dir .. '/*.vim', false, true)
    local sessions = vim.tbl_map(function(path)
        return {
            name = vim.fn.fnamemodify(path, ':t:r'):gsub('_', '/'),
            path = path
        }
    end, files)
    
    pickers.new({}, vim.tbl_extend('force', opts, {
        finder = finders.new_table({
            results = sessions,
            entry_maker = function(e)
                return { value = e.path, display = e.name, ordinal = e.name }
            end,
        }),
        sorter = conf.generic_sorter({}),
        previewer = nil,
        attach_mappings = function(bufnr, map)
            actions.select_default:replace(function()
                actions.close(bufnr)
                local selection = action_state.get_selected_entry()
                if selection then vim.cmd('source ' .. selection.value) end
            end)
            return opts.attach_mappings and opts.attach_mappings(bufnr, map) or true
        end,
    })):find()
end

grep_in_files = function(opts)
    local s = vim.g.smart_query
    local picker_opts = vim.tbl_extend('force', layout(), {
        default_text = s.grep_input,
        prompt_title = 'Live Grep in ' .. #s.files .. ' files',
        search_dirs = s.files,
        attach_mappings = function(bufnr, map)
            return intercept(bufnr, map, opts)
        end,
    })
    
    builtin.live_grep(picker_opts)
end

local function configure_picker(mode_key, builtin_fn, opts)
    local mode = MODES[mode_key]
    PICKERS[mode_key] = function(extra_opts)
        local s = vim.g.smart_query
        local opts_table = vim.tbl_extend('force', layout(), {
            default_text = s.filter_input,
            prompt_title = mode.display,
            attach_mappings = function(bufnr, map)
                return intercept(bufnr, map, opts)
            end
        }, extra_opts or {})
        builtin_fn(opts_table)
    end
end

function open(opts)
	local mode_list = {}
	for mode_id, mode_data in pairs(MODES) do
		table.insert(mode_list, { id = mode_id, display = mode_data.display })
	end
	
	pickers.new({}, vim.tbl_extend('force', layout(), {
		prompt_title = 'Search',
		finder = finders.new_table({
			results = mode_list,
			entry_maker = function(e)
				return { value = e, display = e.display, ordinal = e.display }
			end,
		}),
		sorter = conf.generic_sorter({}),
		previewer = nil,
		attach_mappings = function(bufnr, map)
            local s = vim.g.smart_query
			current_buffer = bufnr
			actions.select_default:replace(function()
				local selection = action_state.get_selected_entry()
				if selection and selection.value then
					local selected_mode = selection.value.id
					if s.mode ~= selected_mode then
						s.filter_input = ''
						s.grep_input = ''
					end
					s.mode = selected_mode
					vim.g.smart_query = s
					close()
					if PICKERS[selected_mode] then
						PICKERS[selected_mode]()
					end
				end
			end)
			return intercept(bufnr, map, opts)
		end,
	})):find()
end

function M.setup(opts)
    opts = vim.tbl_deep_extend('force', defaults, opts or {})
    
    -- Initialize PICKERS table
    configure_picker(MODE_FILES, builtin.find_files, opts)
    configure_picker(MODE_BUFFERS, builtin.buffers, opts)
    configure_picker(MODE_RECENT, builtin.oldfiles, opts)
    configure_picker(MODE_GREP, builtin.live_grep, opts)
    configure_picker(MODE_DIAGNOSTICS, builtin.diagnostics, opts)
    configure_picker(MODE_SESSIONS, sessions_picker, opts)
    configure_picker(MODE_COMMITS, builtin.git_commits, opts)

    restore()

    keymap.rebind({ 'n', 'i' }, opts.hotkeys.open, function() open(opts) end, { noremap = true, silent = true, desc = 'Query', })

    local gr = vim.api.nvim_create_augroup('SearchGroup', { clear = true })
    
    vim.api.nvim_create_autocmd('VimResized', {
        group = gr,
        callback = function() 
            local s = vim.g.smart_query
            if s.is_open then
                close()
                open()
            end
        end,    
    })
    
	vim.api.nvim_create_autocmd('VimLeavePre', {
		group = gr,
		callback = store
	})
end

return M