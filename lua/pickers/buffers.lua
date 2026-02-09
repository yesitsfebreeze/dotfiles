local builtin = require('telescope.builtin')

return {
    title = 'Buffers',
    condition = function() return true end,
    pick = function(opts)
        builtin.buffers(opts)
    end,
}
