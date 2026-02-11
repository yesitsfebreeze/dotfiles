local builtin = require('telescope.builtin')

return {
    title = 'Files',
    condition = function() return true end,
    pick = function(opts)
        builtin.find_files(opts)
    end,
}
