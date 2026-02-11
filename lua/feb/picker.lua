-- Query: Unified search/query/picker interface with mode selector

local vim = vim or {}

local M = {}
local keymap = require('feb/keymap')
local sessions = require('feb/sessions')
local telescope_pickers = require('telescope.pickers')
local finders = require('telescope.finders')
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
local picker_configs = {}
local PICKERS = {}

local state = {
    is_open = false,
    mode = nil,
    view = FILTER,
    prompts = {},  -- Will store per-mode: { mode_id = { filter = '', grep = '' } }
    files = {},
    selected = nil,
}

-- Load all picker configs from lua/feb/pickers/
local function load_pickers()
    local picker_dir = vim.fn.stdpath('config') .. '/lua/feb/pickers'
    local files = vim.fn.glob(picker_dir .. '/*.lua', false, true)
    
    for _, file in ipairs(files) do
        local id = vim.fn.fnamemodify(file, ':t:r')
        local ok, config = pcall(require, 'feb.pickers.' .. id)
        if ok and config then
            picker_configs[id] = config
        end
    end
end

local function ensure_session_file()
    local name = sessions.get_session_name()
    local dir = vim.fn.stdpath('data') .. '/query'
    if vim.fn.isdirectory(dir) == 0 then vim.fn.mkdir(dir, 'p') end
    return dir .. '/' .. name .. '.json'
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

    -- Ensure prompts is a proper nested table structure
    if type(data.prompts) ~= 'table' then
        data.prompts = {}
    else
        -- Migrate old flat format: { filter = '...', grep = '...' }
        -- to nested format: { [mode_id] = { filter = '...', grep = '...' } }
        if data.prompts.filter or data.prompts.grep then
            -- This is the old flat format, wrap it under a default mode if we have one
            if data.mode then
                data.prompts = { [data.mode] = { 
                    filter = data.prompts.filter or '', 
                    grep = data.prompts.grep or '' 
                } }
            else
                data.prompts = {}
            end
        end
    end
    
    -- Migrate very old format with top-level filter_input/grep_input
    if data.filter_input and data.mode then 
        if not data.prompts[data.mode] then
            data.prompts[data.mode] = {}
        end
        data.prompts[data.mode].filter = data.filter_input
        data.prompts[data.mode].grep = data.grep_input or ''
        data.filter_input = nil
        data.grep_input = nil
    end
    
    state = vim.tbl_deep_extend('force', state, data)
end

local function layout()
    local size = require('feb/screen').get().telescope
    local tele_scope = require('feb/telescope')
    return tele_scope.get_default_config({
        layout_strategy = 'vertical',
        layout_config = {
            anchor = 'E',
            width = size.width,
            height = size.height,
            preview_height = 0.5,
            prompt_position = 'bottom',
        },
    })
end

local function collect_files(picker, mode_id)
    local files = {}
    local seen = {}
    
    local config = picker_configs[mode_id]
    -- Try config.key first, then common field names
    local keys_to_try = config and config.key and { config.key } or { 'filename', 'path', 'value' }
    
    for entry in picker.manager:iter() do
        if entry then
            local file = nil
            for _, key in ipairs(keys_to_try) do
                if entry[key] then
                    file = entry[key]
                    break
                end
            end
            if file and not seen[file] then
                seen[file] = true
                table.insert(files, file)
            end
        end
    end
    
    return files
end

local function close()
    -- Save current prompt before closing
    if current_buffer and state.mode then
        local p = action_state.get_current_picker(current_buffer)
        if p then
            local prompt = p:_get_prompt()
            if not state.prompts[state.mode] then
                state.prompts[state.mode] = { filter = '', grep = '' }
            end
            if state.view == FILTER then
                state.prompts[state.mode].filter = prompt
            elseif state.view == GREP then
                state.prompts[state.mode].grep = prompt
            end
        end
    end
    
    state.is_open = false
    store()
    if current_buffer then actions.close(current_buffer) end
    current_buffer = nil
end

-- Forward declaration
local grep_in_files

-- Helper to get prompts for current mode
local function get_mode_prompts()
    if not state.mode then return { filter = '', grep = '' } end
    if not state.prompts[state.mode] then
        state.prompts[state.mode] = { filter = '', grep = '' }
    end
    return state.prompts[state.mode]
end

local function intercept(bufnr, map, opts)
    current_buffer = bufnr
    map('i', opts.hotkeys.close, close)
    
    map('i', opts.hotkeys.switch, function()
        if state.view == FILTER then
            local p = action_state.get_current_picker(bufnr)
            if not p or not p.manager then return end
            
            get_mode_prompts().filter = p:_get_prompt()
            local files = collect_files(p, state.mode)

            if #files > 0 then
                state.view = GREP
                state.files = files
                state.selected = state.mode
                actions.close(bufnr)
                grep_in_files(opts)
            else
                vim.notify('No files to grep found', vim.log.levels.WARN)
            end
            return
        end

        if state.view == GREP then
            local p = action_state.get_current_picker(bufnr)
            get_mode_prompts().grep = p:_get_prompt()
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

grep_in_files = function(opts)
    local picker_opts = vim.tbl_extend('force', layout(), {
        default_text = get_mode_prompts().grep,
        prompt_title = 'Live Grep in ' .. #state.files .. ' files',
        search_dirs = state.files,
        attach_mappings = function(bufnr, map)
            return intercept(bufnr, map, opts)
        end,
    })
    builtin.live_grep(picker_opts)
end

local function configure_picker(id, config, opts)
    PICKERS[id] = function(extra_opts)
        local picker_opts = vim.tbl_extend('force', layout(), {
            default_text = get_mode_prompts().filter,
            prompt_title = config.title,
            attach_mappings = function(bufnr, map)
                return intercept(bufnr, map, opts)
            end
        }, extra_opts or {})
        
        config.pick(picker_opts)
    end
end

local function get_available_modes()
    local modes = {}
    for id, config in pairs(picker_configs) do
        if config.condition() then
            table.insert(modes, { id = id, title = config.title })
        end
    end
    -- Sort alphabetically by title
    table.sort(modes, function(a, b) return a.title < b.title end)
    return modes
end

local function mode_selector(opts)
    local mode_list = get_available_modes()
    local conf = require('telescope.config').values

    telescope_pickers.new(vim.tbl_extend('force', layout(), {
        prompt_title = 'Query',
        finder = finders.new_table({
            results = mode_list,
            entry_maker = function(e)
                return { value = e, display = e.title, ordinal = e.title }
            end,
        }),
        sorter = conf.generic_sorter({}),
        previewer = nil,
        attach_mappings = function(bufnr, map)
            current_buffer = bufnr
            
            -- Auto-select on unique prefix match
            local auto_selecting = false
            local function check_auto_select()
                if auto_selecting then return end
                
                local picker = action_state.get_current_picker(bufnr)
                if not picker then return end
                
                local prompt = picker:_get_prompt()
                if not prompt or prompt == '' then return end
                
                -- Find all entries that start with the prompt (case-insensitive)
                local matches = {}
                local prompt_lower = prompt:lower()
                
                for entry in picker.manager:iter() do
                    local title = entry.ordinal or ''
                    if title:lower():sub(1, #prompt) == prompt_lower then
                        table.insert(matches, entry)
                    end
                end
                
                -- Auto-select if exactly one unique match
                if #matches == 1 then
                    auto_selecting = true
                    local selected_mode = matches[1].value.id
                    state.mode = selected_mode
                    
                    -- Close picker properly through our close function
                    state.is_open = false
                    store()
                    pcall(actions.close, bufnr)
                    current_buffer = nil
                    
                    if PICKERS[selected_mode] then
                        vim.schedule(function()
                            PICKERS[selected_mode]()
                        end)
                    end
                end
            end
            
            -- Monitor prompt changes for auto-selection
            vim.api.nvim_create_autocmd('TextChangedI', {
                buffer = bufnr,
                callback = function()
                    vim.schedule(check_auto_select)
                end,
            })
            
            actions.select_default:replace(function()
                local selection = action_state.get_selected_entry()
                if selection and selection.value then
                    local selected_mode = selection.value.id
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

local function open(opts)
    -- If already open, clear prompts and switch to mode selector
    if state.is_open then
        state.mode = nil
        if current_buffer and vim.api.nvim_buf_is_valid(current_buffer) then
            local picker = action_state.get_current_picker(current_buffer)
            if picker then pcall(actions.close, current_buffer) end
        end
        current_buffer = nil
        mode_selector(opts)
        return
    end
    
    state.is_open = true
    
    -- Always start with mode selector
    mode_selector(opts)
end

function M.setup(opts)
    opts = vim.tbl_deep_extend('force', defaults, opts or {})
    
    -- Load picker configs from lua/pickers/
    load_pickers()
    
    -- Configure each picker
    for id, config in pairs(picker_configs) do
        configure_picker(id, config, opts)
    end

    restore()

    keymap.rebind({ 'n', 'i' }, opts.hotkeys.open, function() open(opts) end, { 
        noremap = true, 
        silent = true, 
        desc = 'Query' 
    })

    local gr = vim.api.nvim_create_augroup('QueryGroup', { clear = true })
    
    vim.api.nvim_create_autocmd('VimResized', {
        group = gr,
        callback = function() 
            if state.is_open then
                close()
                open(opts)
            end
        end,    
    })
    
    vim.api.nvim_create_autocmd('VimLeavePre', {
        group = gr,
        callback = store
    })
end

return M
