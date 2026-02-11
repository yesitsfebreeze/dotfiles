local builtin = require('telescope.builtin')

return {
    title = 'Diagnostics',
    condition = function() return true end,
    pick = function(opts)
        builtin.diagnostics(opts)
    end,
}
