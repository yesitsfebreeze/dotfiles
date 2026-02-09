local builtin = require('telescope.builtin')

return {
    title = 'Recent',
    condition = function() return true end,
    pick = function(opts)
        builtin.oldfiles(opts)
    end,
}
