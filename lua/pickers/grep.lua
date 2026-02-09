local builtin = require('telescope.builtin')

return {
    title = 'Grep',
    condition = function() return true end,
    pick = function(opts)
        builtin.live_grep(opts)
    end,
}
