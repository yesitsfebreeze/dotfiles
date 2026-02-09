local pickers = require('telescope.pickers')
local finders = require('telescope.finders')
local conf = require('telescope.config').values
local actions = require('telescope.actions')
local action_state = require('telescope.actions.state')

return {
    id = 'sessions',
    display = 'Sessions',
    custom = function(picker_opts)
        local dir = vim.fn.stdpath('data') .. '/sessions'
        local files = vim.fn.glob(dir .. '/*.vim', false, true)
        local sessions = vim.tbl_map(function(path)
            return {
                name = vim.fn.fnamemodify(path, ':t:r'):gsub('_', '/'),
                path = path
            }
        end, files)
        
        pickers.new({}, vim.tbl_extend('force', picker_opts, {
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
                return picker_opts.attach_mappings and picker_opts.attach_mappings(bufnr, map) or true
            end,
        })):find()
    end,
}
