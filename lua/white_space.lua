-- Whitespace and indentation settings:
-- - Tab configuration
-- - Whitespace visualization
-- - Indentation behavior
--
-- Options:
-- {
--   tab = '  ',
--   trail = '·',
--   extends = '›',
--   precedes = '‹',
--   nbsp = '␣',
--   color = '#484848'
-- }

local vim = vim or {}

local M = {}

local defaults = {
    tab = '⇥ ',
    trail = '·',
    extends = '⇠',
    precedes = '⇢',
    nbsp = '␣',
	color = '#626262'
}

function M.setup(opts)
	local o = vim.tbl_deep_extend('force', defaults, opts or {})
	-- Tab settings
	vim.opt.tabstop = 2        -- Number of spaces a tab counts for
	vim.opt.shiftwidth = 2     -- Number of spaces for auto-indent
	vim.opt.softtabstop = 2    -- Number of spaces for <Tab> in insert mode
	vim.opt.expandtab = false  -- Use tabs instead of spaces
	
	-- Indentation
	vim.opt.smartindent = true
	vim.opt.autoindent = true
	vim.opt.copyindent = true
	vim.opt.preserveindent = true
	
	-- Whitespace visualization
	vim.opt.list = true
	
	-- Build listchars table, only including non-empty values
	local listchars = {}
	if o.tab and o.tab ~= '' then listchars.tab = o.tab end
	if o.trail and o.trail ~= '' then listchars.trail = o.trail end
	if o.extends and o.extends ~= '' then listchars.extends = o.extends end
	if o.precedes and o.precedes ~= '' then listchars.precedes = o.precedes end
	if o.nbsp and o.nbsp ~= '' then listchars.nbsp = o.nbsp end
	
	vim.opt.listchars = listchars
	
	-- Set whitespace color
	vim.cmd("highlight Whitespace guifg=" .. o.color .. " guibg=NONE")
	vim.cmd("highlight NonText guifg=" .. o.color .. " guibg=NONE")
	vim.cmd("highlight SpecialKey guifg=" .. o.color .. " guibg=NONE")
	
	-- Line breaking
	vim.opt.wrap = false          -- Don't wrap lines
	vim.opt.linebreak = true      -- Break at word boundaries when wrapping
	vim.opt.breakindent = true    -- Preserve indentation in wrapped lines
	
	-- Backspace behavior
	vim.opt.backspace = {'indent', 'eol', 'start'}
end

return M
