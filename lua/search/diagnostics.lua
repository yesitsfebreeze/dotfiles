-- LSP diagnostics search module
-- Returns diagnostic entries

local M = {}

function M.search(input_files, term)
	local diagnostics = {}
	
	for _, diag in ipairs(vim.diagnostic.get()) do
		local bufnr = diag.bufnr
		local filename = vim.api.nvim_buf_get_name(bufnr)
		
		if filename ~= '' then
			local match = term == '' or 
				filename:lower():find(term:lower(), 1, true) or
				diag.message:lower():find(term:lower(), 1, true)
			
			if match then
				table.insert(diagnostics, {
					filename = filename,
					lnum = diag.lnum + 1,
					col = diag.col + 1,
					severity = diag.severity,
					message = diag.message,
					display = string.format("%s:%d: %s", 
						vim.fn.fnamemodify(filename, ':~:.'), 
						diag.lnum + 1, 
						diag.message)
				})
			end
		end
	end
	
	return diagnostics
end

return M
