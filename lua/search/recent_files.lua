-- Recent files search module
-- Returns list of recent files (open buffers + oldfiles)

local M = {}

function M.get_files()
	local files = {}
	local seen = {}
	local current_file = vim.api.nvim_buf_get_name(vim.api.nvim_get_current_buf())
	
	-- Collect open buffers sorted by lastused
	local open_buffers = {}
	for _, buf in ipairs(vim.api.nvim_list_bufs()) do
		if vim.api.nvim_buf_is_loaded(buf) then
			local name = vim.api.nvim_buf_get_name(buf)
			if name ~= '' and name ~= current_file and vim.bo[buf].buftype == '' then
				local info = vim.fn.getbufinfo(buf)[1]
				table.insert(open_buffers, { path = name, time = info.lastused or 0 })
			end
		end
	end
	
	table.sort(open_buffers, function(a, b) return a.time > b.time end)
	
	for _, item in ipairs(open_buffers) do
		table.insert(files, item.path)
		seen[item.path] = true
	end
	
	-- Add from oldfiles
	for _, file in ipairs(vim.v.oldfiles or {}) do
		if not seen[file] and file ~= current_file and vim.fn.filereadable(file) == 1 then
			table.insert(files, file)
			seen[file] = true
			if #files >= 50 then break end
		end
	end
	
	return files
end

return M
