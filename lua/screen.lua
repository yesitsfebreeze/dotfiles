-- Screen dimension helpers
-- Returns calculated dimensions for common UI layouts

local vim = vim or {}

local M = {}

function M.get()
	local screen_w = vim.o.columns
	local screen_h = vim.o.lines
	
	return {
		-- Raw dimensions
		width = screen_w,
		height = screen_h,
		
		-- Half dimensions
		half_width = math.floor(screen_w / 2),
		half_height = math.floor(screen_h / 2),
		
		-- Common telescope layout (half width, nearly full height)
		telescope = {
			width = math.floor(screen_w / 3),
			height = screen_h,
		},
		
		-- Full minus padding
		padded = {
			width = screen_w - 4,
			height = screen_h - 4,
		},
	}
end

return M
