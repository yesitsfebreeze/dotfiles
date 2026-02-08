local M = {}
local add = require('deps').add
local later = require('deps').later
local keymap = require('keymap')

local defaults = {
	-- Auto-install these servers when detected
	ensure_installed = {
		"lua_ls",      -- Lua
		"pyright",     -- Python
		"ts_ls",       -- TypeScript/JavaScript
		"rust_analyzer", -- Rust
		"gopls",       -- Go
		"clangd",      -- C/C++
	},
	-- UI settings
	border = "single",
	transparent = true,
	-- Keymappings
	hotkeys = {
		declaration = "gD",
		definition = "gd",
		hover = "K",
		implementation = "gi",
		signature_help = "<C-h>",
		type_definition = "<leader>D",
		rename = "<leader>rn",
		code_action = "<leader>ca",
		references = "gr",
		format = "<leader>f",
		diagnostic_prev = "[d",
		diagnostic_next = "]d",
		diagnostic_float = "<leader>d",
	},
}

local function merge_opts(user)
	return vim.tbl_deep_extend('force', defaults, user or {})
end

function M.setup(opts)
	local o = merge_opts(opts)
	
	-- Install LSP-related plugins
	add({ source = 'neovim/nvim-lspconfig' })
	add({ source = 'williamboman/mason.nvim' })
	add({ source = 'williamboman/mason-lspconfig.nvim' })
	
	-- Setup Mason and LSP after plugins are loaded
	later(function()
		-- Setup Mason (LSP installer)
		require('mason').setup({
			ui = {
				border = o.border,
				width = 0.8,
				height = 0.8,
			},
		})
		
		-- Bridge between Mason and lspconfig for auto-installation
		-- mason-lspconfig will automatically enable servers via vim.lsp.enable()
		require('mason-lspconfig').setup({
			ensure_installed = o.ensure_installed,
			automatic_enable = true,
		})
		
		-- Configure LSP settings for all servers
		local on_attach = function(client, bufnr)
			local bufopts = { noremap = true, silent = true, buffer = bufnr }
			local k = o.hotkeys
			
			-- Key mappings for LSP features
			if k.declaration then
				keymap.rebind('n', k.declaration, vim.lsp.buf.declaration, bufopts)
			end
			if k.definition then
				keymap.rebind('n', k.definition, vim.lsp.buf.definition, bufopts)
			end
			if k.hover then
				keymap.rebind('n', k.hover, vim.lsp.buf.hover, bufopts)
			end
			if k.implementation then
				keymap.rebind('n', k.implementation, vim.lsp.buf.implementation, bufopts)
			end
			if k.signature_help then
				keymap.rebind('n', k.signature_help, vim.lsp.buf.signature_help, bufopts)
			end
			if k.type_definition then
				keymap.rebind('n', k.type_definition, vim.lsp.buf.type_definition, bufopts)
			end
			if k.rename then
				keymap.rebind('n', k.rename, vim.lsp.buf.rename, bufopts)
			end
			if k.code_action then
				keymap.rebind('n', k.code_action, vim.lsp.buf.code_action, bufopts)
			end
			if k.references then
				keymap.rebind('n', k.references, vim.lsp.buf.references, bufopts)
			end
			if k.format then
				keymap.rebind('n', k.format, function()
					vim.lsp.buf.format({ async = true })
				end, bufopts)
			end
			
			-- Diagnostic navigation
			if k.diagnostic_prev then
				keymap.rebind('n', k.diagnostic_prev, vim.diagnostic.goto_prev, bufopts)
			end
			if k.diagnostic_next then
				keymap.rebind('n', k.diagnostic_next, vim.diagnostic.goto_next, bufopts)
			end
			if k.diagnostic_float then
				keymap.rebind('n', k.diagnostic_float, vim.diagnostic.open_float, bufopts)
			end
		end
		
		-- Set up LspAttach autocmd for keybindings
		vim.api.nvim_create_autocmd('LspAttach', {
			callback = function(args)
				local client = vim.lsp.get_client_by_id(args.data.client_id)
				on_attach(client, args.buf)
			end,
		})
		
		-- Custom server configurations using vim.lsp.config
		vim.lsp.config.lua_ls = {
			settings = {
				Lua = {
					diagnostics = {
						globals = { 'vim' },
					},
					workspace = {
						library = vim.api.nvim_get_runtime_file("", true),
						checkThirdParty = false,
					},
					telemetry = {
						enable = false,
					},
				},
			},
		}
	end)
	
	-- LSP UI settings
	if o.transparent then
		vim.api.nvim_create_autocmd('ColorScheme', {
			pattern = '*',
			callback = function()
				vim.api.nvim_set_hl(0, 'NormalFloat', { bg = 'NONE' })
				vim.api.nvim_set_hl(0, 'FloatBorder', { bg = 'NONE' })
			end,
		})
	end
	
	-- Setup Mason and LSP after plugins are loaded
	later(function()
		-- Setup Mason (LSP installer)
		require('mason').setup({
			ui = {
				border = o.border,
				width = 0.8,
				height = 0.8,
			},
		})
		
		-- Bridge between Mason and lspconfig for auto-installation
		-- mason-lspconfig will automatically enable servers via vim.lsp.enable()
		require('mason-lspconfig').setup({
			ensure_installed = o.ensure_installed,
			automatic_enable = true,
		})
		
		-- Configure diagnostic appearance
		vim.diagnostic.config({
			virtual_text = {
				prefix = '●',
				spacing = 4,
			},
			signs = {
				text = {
					[vim.diagnostic.severity.ERROR] = "✘",
					[vim.diagnostic.severity.WARN] = "▲",
					[vim.diagnostic.severity.HINT] = "⚑",
					[vim.diagnostic.severity.INFO] = "»",
				},
			},
			underline = true,
			update_in_insert = true,
			severity_sort = true,
			float = {
				border = o.border,
				source = 'if_many',
			},
		})
		
		-- LSP handlers with square borders
		vim.lsp.handlers["textDocument/hover"] = vim.lsp.with(
			vim.lsp.handlers.hover, { border = o.border }
		)
		vim.lsp.handlers["textDocument/signatureHelp"] = vim.lsp.with(
			vim.lsp.handlers.signature_help, { border = o.border }
		)
		
		-- Configure LSP settings for all servers
		local on_attach = function(client, bufnr)
			local bufopts = { noremap = true, silent = true, buffer = bufnr }
			local k = o.keys
			
			-- Key mappings for LSP features
			if k.declaration then
				keymap.rebind('n', k.declaration, vim.lsp.buf.declaration, bufopts)
			end
			if k.definition then
				keymap.rebind('n', k.definition, vim.lsp.buf.definition, bufopts)
			end
			if k.hover then
				keymap.rebind('n', k.hover, vim.lsp.buf.hover, bufopts)
			end
			if k.implementation then
				keymap.rebind('n', k.implementation, vim.lsp.buf.implementation, bufopts)
			end
			if k.signature_help then
				keymap.rebind('n', k.signature_help, vim.lsp.buf.signature_help, bufopts)
			end
			if k.type_definition then
				keymap.rebind('n', k.type_definition, vim.lsp.buf.type_definition, bufopts)
			end
			if k.rename then
				keymap.rebind('n', k.rename, vim.lsp.buf.rename, bufopts)
			end
			if k.code_action then
				keymap.rebind('n', k.code_action, vim.lsp.buf.code_action, bufopts)
			end
			if k.references then
				keymap.rebind('n', k.references, vim.lsp.buf.references, bufopts)
			end
			if k.format then
				keymap.rebind('n', k.format, function()
					vim.lsp.buf.format({ async = true })
				end, bufopts)
			end
			
			-- Diagnostic navigation
			if k.diagnostic_prev then
				keymap.rebind('n', k.diagnostic_prev, vim.diagnostic.goto_prev, bufopts)
			end
			if k.diagnostic_next then
				keymap.rebind('n', k.diagnostic_next, vim.diagnostic.goto_next, bufopts)
			end
			if k.diagnostic_float then
				keymap.rebind('n', k.diagnostic_float, vim.diagnostic.open_float, bufopts)
			end
		end
		
		-- Set up LspAttach autocmd for keybindings
		vim.api.nvim_create_autocmd('LspAttach', {
			callback = function(args)
				local client = vim.lsp.get_client_by_id(args.data.client_id)
				on_attach(client, args.buf)
			end,
		})
		
		-- Custom server configurations using vim.lsp.config
		vim.lsp.config.lua_ls = {
			settings = {
				Lua = {
					diagnostics = {
						globals = { 'vim' },
					},
					workspace = {
						library = vim.api.nvim_get_runtime_file("", true),
						checkThirdParty = false,
					},
					telemetry = {
						enable = false,
					},
				},
			},
		}
		
		-- Manually trigger LSP for already-open buffers
		vim.schedule(function()
			for _, buf in ipairs(vim.api.nvim_list_bufs()) do
				if vim.api.nvim_buf_is_loaded(buf) then
					local ft = vim.bo[buf].filetype
					if ft ~= '' and vim.bo[buf].buftype == '' then
						-- Trigger FileType event to start LSP
						vim.api.nvim_exec_autocmds('FileType', {
							buffer = buf,
							modeline = false,
						})
					end
				end
			end
		end)
	end)
end

return M
