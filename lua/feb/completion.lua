local M = {}
local add = require('feb/deps').add
local later = require('feb/deps').later

local defaults = {
	border = "single",
	transparent = true,
}

function M.setup(opts)
	local o = vim.tbl_deep_extend('force', defaults, opts or {})
	
	-- Install completion plugins
	add({ source = 'hrsh7th/nvim-cmp' })
	add({ source = 'hrsh7th/cmp-nvim-lsp' })
	add({ source = 'hrsh7th/cmp-buffer' })
	add({ source = 'hrsh7th/cmp-path' })
	add({ source = 'L3MON4D3/LuaSnip' })
	add({ source = 'saadparwaiz1/cmp_luasnip' })
	
	later(function()
		local cmp = require('cmp')
		local luasnip = require('luasnip')
		
		cmp.setup({
			snippet = {
				expand = function(args)
					luasnip.lsp_expand(args.body)
				end,
			},
			preselect = cmp.PreselectMode.None,
			completion = {
				completeopt = 'menu,menuone,noselect',
				autocomplete = false,  -- Disable auto-trigger
			},
			window = {
				completion = {
					border = o.border,
					winhighlight = o.transparent and 'Normal:Normal,FloatBorder:FloatBorder,CursorLine:Visual' or nil,
				},
				documentation = {
					border = o.border,
					winhighlight = o.transparent and 'Normal:Normal,FloatBorder:FloatBorder' or nil,
				},
			},
			mapping = cmp.mapping.preset.insert({
				['<C-b>'] = cmp.mapping.scroll_docs(-4),
				['<C-f>'] = cmp.mapping.scroll_docs(4),
				['<C-Space>'] = cmp.mapping.complete(),
				['<C-e>'] = cmp.mapping.abort(),
				['<Esc>'] = cmp.mapping(function(fallback)
					if cmp.visible() then
						cmp.abort()
					else
						fallback()
					end
				end, { 'i' }),
				['<CR>'] = cmp.mapping.confirm({ select = false }),
				['<Down>'] = cmp.mapping(function(fallback)
					if cmp.visible() then
						cmp.select_next_item()
					else
						fallback()
					end
				end, { 'i', 's' }),
				['<Up>'] = cmp.mapping(function(fallback)
					if cmp.visible() then
						cmp.select_prev_item()
					else
						fallback()
					end
				end, { 'i', 's' }),
				['<Tab>'] = cmp.mapping(function(fallback)
					-- Check if cmp is disabled for this buffer
					local ok, enabled = pcall(vim.api.nvim_buf_get_var, 0, 'cmp_enabled')
					if ok and enabled == false then
						fallback()
						return
					end
					if cmp.visible() then
						cmp.select_next_item()
					elseif luasnip.expand_or_jumpable() then
						luasnip.expand_or_jump()
					else
						cmp.complete()
					end
				end, { 'i', 's' }),
				['<S-Tab>'] = cmp.mapping(function(fallback)
					if cmp.visible() then
						cmp.select_prev_item()
					elseif luasnip.jumpable(-1) then
						luasnip.jump(-1)
					else
						fallback()
					end
				end, { 'i', 's' }),
			}),
			sources = cmp.config.sources({
				{ name = 'nvim_lsp', priority = 1000 },
				{ name = 'luasnip', priority = 750 },
				{ name = 'buffer', priority = 500 },
				{ name = 'path', priority = 250 },
			}),
			experimental = {
				ghost_text = false,
			},
		})

		-- Disable completion in Telescope prompts
		cmp.setup.filetype('TelescopePrompt', {
			enabled = false,
		})

		-- Transparent backgrounds
		if o.transparent then
			local cmp_group = vim.api.nvim_create_augroup('CompletionConfig', { clear = true })
			vim.api.nvim_create_autocmd('ColorScheme', {
				group = cmp_group,
				pattern = '*',
				callback = function()
					vim.api.nvim_set_hl(0, 'CmpNormal', { bg = 'NONE' })
					vim.api.nvim_set_hl(0, 'CmpBorder', { bg = 'NONE' })
				end,
			})
		end
	end)
end

return M
