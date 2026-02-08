-- Git commits search module
-- Returns git commit entries

local M = {}

function M.search(input_files, term)
	local commits = {}
	
	-- Get git log
	local cmd = 'git log --pretty=format:"%h %s" --max-count=100'
	if term ~= '' then
		cmd = cmd .. ' --grep="' .. term .. '"'
	end
	
	local output = vim.fn.systemlist(cmd .. ' 2>/dev/null')
	for _, line in ipairs(output) do
		local hash, msg = line:match("^(%S+)%s+(.*)$")
		if hash then
			table.insert(commits, {
				hash = hash,
				message = msg,
				display = line
			})
		end
	end
	
	return commits
end

return M
