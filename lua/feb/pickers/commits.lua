local builtin = require('telescope.builtin')

return {
    title = 'Commits',
    condition = function()
        vim.fn.system('git rev-parse --is-inside-work-tree 2>/dev/null')
        return vim.v.shell_error == 0
    end,
    pick = function(opts)
        builtin.git_commits(opts)
    end,
}
