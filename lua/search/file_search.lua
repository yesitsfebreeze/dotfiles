-- File search module
-- Filters files by name pattern or returns all files via ripgrep

local M = {}

function M.search(input_files, term)
	-- If we have input files, filter them by term
	if input_files and #input_files > 0 then
		if term == '' then
			return input_files
		end
		
		local filtered = {}
		for _, file in ipairs(input_files) do
			if file:lower():find(term:lower(), 1, true) then
				table.insert(filtered, file)
			end
		end
		return filtered
	end
	
	-- Otherwise, get all files via ripgrep
	local files = vim.fn.systemlist('rg --files')
	
	if term == '' then
		return files
	end
	
	local filtered = {}
	for _, file in ipairs(files) do
		if file:lower():find(term:lower(), 1, true) then
			table.insert(filtered, file)
		end
	end
	
	return filtered
end

return M
