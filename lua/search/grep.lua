-- Grep search module
-- Greps content in files

local M = {}

function M.search(input_files, term)
	local results = {}
	
	-- Don't grep if term is empty - return empty results
	if term == '' then
		return results
	end
	
	-- Build ripgrep command with result limiting
	local cmd = 'rg --vimgrep --color=never --smart-case --max-count=1000 '
	
	if input_files and #input_files > 0 then
		-- Grep in specific files
		cmd = cmd .. vim.fn.shellescape(term) .. ' '
		for _, file in ipairs(input_files) do
			cmd = cmd .. vim.fn.shellescape(file) .. ' '
		end
	else
		-- Grep all files
		cmd = cmd .. vim.fn.shellescape(term)
	end
	
	-- Use vim.fn.systemlist with shell command
	local output = vim.fn.systemlist(cmd)
	
	for _, line in ipairs(output) do
		local filename, lnum, col, text = line:match("^(.-)%:(%d+)%:(%d+)%:(.*)$")
		if filename then
			table.insert(results, {
				filename = filename,
				lnum = tonumber(lnum),
				col = tonumber(col),
				text = text,
				display = string.format("%s:%s: %s", vim.fn.fnamemodify(filename, ':~:.'), lnum, text)
			})
		end
	end
	
	return results
end

return M
