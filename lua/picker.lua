-- Query: Unified search/query/picker interface with mode selector

local vim = vim or {}

local M = {}
local keymap = require('keymap')
local sessions = require('sessions')
local telescope = require('telescope')
local telescope_pickers = require('telescope.pickers')
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
local picker_configs = {}
local PICKERS = {}

local state = {
    open = false,
    mode = nil,
    view = FILTER,
    prompts = {
        filter = '',
        grep = '',
    },
    files = {},
    selected = nil,
}

-- Load all picker configs from lua/pickers/
local function load_pickers()
    local picker_dir = vim.fn.stdpath('config') .. '/lua/pickers'
    local files = vim.fn.glob(picker_dir .. '/*.lua', false, true)
    
    for _, file in ipairs(files) do
        local id = vim.fn.fnamemodify(file, ':t:r')
        local ok, config = pcall(require, 'pickers.' .. id)
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

    -- Migrate old format
    if data.filter_input then 
        data.prompts = { filter = data.filter_input, grep = data.grep_input or '' } 
    end
    
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
        },
        borderchars = telescope.get_border(),
    }
end

local function collect_files(picker, mode_id)
    local files = {}
    local seen = {}
    
    local config = picker_configs[mode_id]
    if not config or not config.key then return files end
    
    for entry in picker.manager:iter() do
        if entry then
            local file = entry[config.key]
            if file and not seen[file] then
                seen[file] = true
                table.insert(files, file)
            end
        end
    end
    
    return files
end

local function close()
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

-- Forward declaration
local grep_in_files

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

local function configure_picker(id, config, opts)
    PICKERS[id] = function(extra_opts)
        local picker_opts = vim.tbl_extend('force', layout(), {
            default_text = state.prompts.filter,
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

local function open(opts)
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
        -- Check if mode is still available (condition may have changed)
        local config = picker_configs[state.mode]
        
        if config and config.condition() then
            if state.view == GREP and state.files and #state.files > 0 then
                local ok = pcall(grep_in_files, opts)
                if not ok then
                    state.mode = nil
                    mode_selector(opts)
                end
            else
                state.view = FILTER
                local ok = pcall(PICKERS[state.mode])
                if not ok then
                    state.mode = nil
                    mode_selector(opts)
                end
            end
            return
        else
            state.mode = nil
        end
    end
    
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
