-- Century: Always keep your cursor centered, even at the edges
-- Provides virtual padding at the top and bottom of buffers for a centered editing experience

local M = {}

local padding_ns
local prev_top_padding = -1
local prev_bottom_padding = -1

local function update_centering()
	local buf = vim.api.nvim_get_current_buf()
	if vim.bo[buf].buftype ~= '' or vim.bo[buf].filetype == 'oil' then return end
	
	local cursor_line = vim.api.nvim_win_get_cursor(0)[1]
	local win_height = vim.api.nvim_win_get_height(0)
	local half_height = math.floor(win_height / 2)
	local total_lines = vim.api.nvim_buf_line_count(buf)
	
	-- Calculate top padding: half_height - cursor_line (when cursor is near top)
	local needed_top_padding = math.max(0, half_height - cursor_line)
	
	-- Calculate bottom padding: cursor_line - (total_lines - half_height) (when cursor is near bottom)
	local needed_bottom_padding = math.max(0, cursor_line - (total_lines - half_height))
	
	-- Only update if padding changed
	if needed_top_padding == prev_top_padding and needed_bottom_padding == prev_bottom_padding then 
		return 
	end
	
	-- Clear existing padding
	vim.api.nvim_buf_clear_namespace(buf, padding_ns, 0, -1)
	
	-- Add top padding
	if needed_top_padding > 0 then
		local pad_lines = {}
		for i = 1, needed_top_padding do
			table.insert(pad_lines, {{'', 'Normal'}})
		end
		
		vim.api.nvim_buf_set_extmark(buf, padding_ns, 0, 0, {
			virt_lines_above = true,
			virt_lines = pad_lines,
		})
		
		-- Reset to topline 1 and scroll up to show virtual lines
		vim.fn.winrestview({ topline = 1 })
		for i = 1, needed_top_padding do
			vim.cmd('execute "normal! \\<C-y>"')
		end
	end
	
	-- Add bottom padding
	if needed_bottom_padding > 0 then
		local pad_lines = {}
		for i = 1, needed_bottom_padding do
			table.insert(pad_lines, {{'', 'Normal'}})
		end
		
		vim.api.nvim_buf_set_extmark(buf, padding_ns, total_lines - 1, 0, {
			virt_lines = pad_lines,
		})
	end
	
	prev_top_padding = needed_top_padding
	prev_bottom_padding = needed_bottom_padding
end

function M.setup(opts)
	opts = opts or {}
	
	-- Create namespace for padding
	padding_ns = vim.api.nvim_create_namespace('century_padding')
	
	-- Set scrolloff to keep cursor centered in middle of file
	vim.opt.scrolloff = opts.scrolloff or 999
	
	-- Set up autocommands
	local augroup = vim.api.nvim_create_augroup('Century', { clear = true })
	
	-- Schedule on buffer entry to ensure window is fully set up
	vim.api.nvim_create_autocmd({'BufWinEnter', 'BufEnter'}, {
		group = augroup,
		callback = function()
			vim.schedule(update_centering)
		end,
	})
	
	vim.api.nvim_create_autocmd({'CursorMoved', 'CursorMovedI'}, {
		group = augroup,
		callback = update_centering,
	})
end

return M
