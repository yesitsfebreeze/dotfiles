-- Buffers search module
-- Returns list of open buffers

local M = {}

function M.search(input_files, term)
	local buffers = {}
	
	for _, buf in ipairs(vim.api.nvim_list_bufs()) do
		if vim.api.nvim_buf_is_loaded(buf) then
			local name = vim.api.nvim_buf_get_name(buf)
			if name ~= '' and vim.bo[buf].buftype == '' then
				if term == '' or name:lower():find(term:lower(), 1, true) then
					table.insert(buffers, name)
				end
			end
		end
	end
	
	return buffers
end

return M
