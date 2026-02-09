-- Query: Unified search/query interface with mode selector

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

local state = {
    open = false,
    mode = MODE_GREP,
    view = FILTER,
    prompts = {
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
    local json = vim.fn.json_encode(state)
    local file = io.open(session_file, 'w')
    if file then
        file:write(json)
        file:close()
    end
end

local function restore()
    local session_file = ensure_session_file()
    if not session_file then return end
    if vim.fn.filereadable(session_file) ~= 1 then return end

    local file = io.open(session_file, 'r')
    if not file then return end 

    local json = file:read('*a')
    file:close()
    local ok, data = pcall(vim.fn.json_decode, json)
    if not (ok and data) then return end

    -- Migrate old format
    if data.filter_input then data.prompts = { filter = data.filter_input, grep = data.grep_input or '' } end
    
    state = vim.tbl_deep_extend('force', state, data)
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
    -- Save current input before closing
    if current_buffer then
        local p = action_state.get_current_picker(current_buffer)
        if p then
            local prompt = p:_get_prompt()
            if state.view == FILTER then state.prompts.filter = prompt end
            if state.view == GREP then state.prompts.grep = prompt end
        end
    end
    
    state.is_open = false
    store()
    if current_buffer then actions.close(current_buffer) end
    current_buffer = nil
end

local function intercept(bufnr, map, opts)
    current_buffer = bufnr
    map('i', opts.hotkeys.close, close)
    
    map('i', opts.hotkeys.switch, function()
        if state.view == FILTER then
            local p = action_state.get_current_picker(bufnr)
            if not p or not p.manager then return end
            
            state.prompts.filter = p:_get_prompt()
            local files = collect_files(p, state.mode)

            if #files > 0 then
                state.view = GREP
                state.files = files
                state.selected = state.mode
                actions.close(bufnr)
                grep_in_files(opts)
            end
            return
        end

        if state.view == GREP then
            local p = action_state.get_current_picker(bufnr)
            state.prompts.grep = p:_get_prompt()
            state.view = FILTER
            store()
            actions.close(bufnr)
            if PICKERS[state.mode] then
                PICKERS[state.mode]()
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
    local picker_opts = vim.tbl_extend('force', layout(), {
        default_text = state.prompts.grep,
        prompt_title = 'Live Grep in ' .. #state.files .. ' files',
        search_dirs = state.files,
        attach_mappings = function(bufnr, map)
            return intercept(bufnr, map, opts)
        end,
    })
    
    builtin.live_grep(picker_opts)
end

local function configure_picker(mode_key, builtin_fn, opts)
    local mode = MODES[mode_key]
    PICKERS[mode_key] = function(extra_opts)
        local opts_table = vim.tbl_extend('force', layout(), {
            default_text = state.prompts.filter,
            prompt_title = mode.display,
            attach_mappings = function(bufnr, map)
                return intercept(bufnr, map, opts)
            end
        }, extra_opts or {})
        builtin_fn(opts_table)
    end
end

local function mode_selector(opts)
	local mode_list = {}
	for mode_id, mode_data in pairs(MODES) do
		table.insert(mode_list, { id = mode_id, display = mode_data.display })
	end
	
	pickers.new({}, vim.tbl_extend('force', layout(), {
		prompt_title = 'Query',
		finder = finders.new_table({
			results = mode_list,
			entry_maker = function(e)
				return { value = e, display = e.display, ordinal = e.display }
			end,
		}),
		sorter = conf.generic_sorter({}),
		previewer = nil,
		attach_mappings = function(bufnr, map)
			current_buffer = bufnr
			actions.select_default:replace(function()
				local selection = action_state.get_selected_entry()
				if selection and selection.value then
					local selected_mode = selection.value.id
					if state.mode ~= selected_mode then
						state.prompts.filter = ''
						state.prompts.grep = ''
					end
					state.mode = selected_mode
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

function open(opts)
	-- If already open, clear prompts and switch to mode selector
	if state.is_open then
		state.prompts.filter = ''
		state.prompts.grep = ''
		state.mode = nil
		if current_buffer then actions.close(current_buffer) end
		current_buffer = nil
		mode_selector(opts)
		return
	end
	
	state.is_open = true
	
	-- If we have a previous mode, open that picker directly
	if state.mode and PICKERS[state.mode] then
		-- If view was GREP, reopen grep with saved files
		if state.view == GREP and state.files and #state.files > 0 then
			grep_in_files(opts)
		else
			-- Otherwise open the filter view for that mode
			state.view = FILTER
			PICKERS[state.mode]()
		end
		return
	end
	
	-- No previous state, show mode selector
	mode_selector(opts)
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

    local gr = vim.api.nvim_create_augroup('QueryGroup', { clear = true })
    
    vim.api.nvim_create_autocmd('VimResized', {
        group = gr,
        callback = function() 
            if state.is_open then
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