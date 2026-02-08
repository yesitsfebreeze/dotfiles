-- Sessions search module
-- Returns available session files

local M = {}

function M.search(input_files, term)
	local sessions = {}
	local session_dir = vim.fn.stdpath('data') .. '/sessions'
	
	local files = vim.fn.systemlist('ls -t "' .. session_dir .. '" 2>/dev/null')
	for _, file in ipairs(files) do
		if file:match('%.vim$') then
			local session_name = file:gsub('%.vim$', ''):gsub('^_', '/'):gsub('_', '/')
			
			if term == '' or session_name:lower():find(term:lower(), 1, true) then
				table.insert(sessions, {
					path = session_dir .. '/' .. file,
					name = session_name,
					display = session_name
				})
			end
		end
	end
	
	return sessions
end

return M
