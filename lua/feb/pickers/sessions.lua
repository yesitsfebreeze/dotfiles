local pickers = require('telescope.pickers')
local finders = require('telescope.finders')
local conf = require('telescope.config').values
local actions = require('telescope.actions')
local action_state = require('telescope.actions.state')
local sessions = require('feb/sessions')

return {
    title = 'Sessions',
    condition = function() return true end,
    pick = function(opts)
        local dir = vim.fn.stdpath('data') .. '/sessions'
        local files = vim.fn.glob(dir .. '/*.vim', false, true)
        local session_list = vim.tbl_map(function(path)
            return {
                name = vim.fn.fnamemodify(path, ':t:r'):gsub('_', '/'),
                session_name = vim.fn.fnamemodify(path, ':t:r'),
                path = path
            }
        end, files)

        pickers.new({}, vim.tbl_extend('force', opts, {
            finder = finders.new_table({
                results = session_list,
                entry_maker = function(e)
                    return { value = e.session_name, display = e.name, ordinal = e.name }
                end,
            }),
            sorter = conf.generic_sorter({}),
            previewer = nil,
            attach_mappings = function(bufnr, map)
                actions.select_default:replace(function()
                    actions.close(bufnr)
                    local selection = action_state.get_selected_entry()
                    if selection then
                        sessions.load_session_by_name(selection.value)
                    end
                end)
                return opts.attach_mappings and opts.attach_mappings(bufnr, map) or true
            end,
        })):find()
    end,
}
