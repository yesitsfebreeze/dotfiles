return {
    id = 'commits',
    display = 'Commits',
    builtin = 'git_commits',
    condition = function()
        vim.fn.system('git rev-parse --is-inside-work-tree 2>/dev/null')
        return vim.v.shell_error == 0
    end,
}
