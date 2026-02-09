local vim = vim or {}

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
	-- Diagnostic debounce timeout in milliseconds
	debounce = 100,
	-- Keymappings
	hotkeys = {
		declaration = "dc",
		definition = "dd",
		hover = "p",
		implementation = "ii",
		signature_help = "<C-h>",
		type_definition = "td",
		rename = "<leader>rn",
		code_action = "<leader>ca",
		references = "gr",
		format = "<leader>f",
		diagnostic_prev = "[d",
		diagnostic_next = "]d",
	diagnostic_float = "<leader>d",
	},
}

function M.setup(opts)
	local o = vim.tbl_deep_extend('force', defaults, opts or {})
	
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
		
		-- Set up autogroup for LSP autocmds
		local lsp_group = vim.api.nvim_create_augroup('LspConfig', { clear = true })
		
		-- Set up LspAttach autocmd for keybindings
		vim.api.nvim_create_autocmd('LspAttach', {
			group = lsp_group,
			callback = function(args)
				local client = vim.lsp.get_client_by_id(args.data.client_id)
				on_attach(client, args.buf)
			end,
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
					[vim.diagnostic.severity.INFO] = "?",
				},
			},
			underline = true,
			update_in_insert = true,  -- Always show and update diagnostics
			severity_sort = true,
			float = {
				border = o.border,
				source = 'if_many',
			},
		})
		
		-- Debounce diagnostic updates in insert mode
		local diagnostic_timers = {}
		local pending_diagnostics = {}
		
		-- Custom handler that debounces diagnostic updates in insert mode
		local original_handler = vim.lsp.handlers["textDocument/publishDiagnostics"]
		vim.lsp.handlers["textDocument/publishDiagnostics"] = function(err, result, ctx, config)
			local uri = result.uri
			local bufnr = vim.uri_to_bufnr(uri)
			
			-- If not in insert mode, apply diagnostics immediately
			if vim.api.nvim_get_mode().mode ~= 'i' then
				original_handler(err, result, ctx, config)
				return
			end
			
			-- Store the pending diagnostics
			pending_diagnostics[bufnr] = { err = err, result = result, ctx = ctx, config = config }
			
			-- Cancel existing timer for this buffer
			if diagnostic_timers[bufnr] then
				vim.fn.timer_stop(diagnostic_timers[bufnr])
			end
			
			-- Schedule applying diagnostics after debounce delay
			diagnostic_timers[bufnr] = vim.fn.timer_start(o.debounce, function()
				vim.schedule(function()
					local pending = pending_diagnostics[bufnr]
					if pending then
						original_handler(pending.err, pending.result, pending.ctx, pending.config)
						pending_diagnostics[bufnr] = nil
					end
					diagnostic_timers[bufnr] = nil
				end)
			end)
		end
		
		-- Apply pending diagnostics immediately when leaving insert mode
		vim.api.nvim_create_autocmd('InsertLeave', {
			group = lsp_group,
			callback = function()
				local bufnr = vim.api.nvim_get_current_buf()
				
				-- Cancel timer
				if diagnostic_timers[bufnr] then
					vim.fn.timer_stop(diagnostic_timers[bufnr])
					diagnostic_timers[bufnr] = nil
				end
				
				-- Apply any pending diagnostics immediately
				if pending_diagnostics[bufnr] then
					local pending = pending_diagnostics[bufnr]
					original_handler(pending.err, pending.result, pending.ctx, pending.config)
					pending_diagnostics[bufnr] = nil
				end
			end,
		})
		
		-- LSP handlers with square borders
		vim.lsp.handlers["textDocument/hover"] = vim.lsp.with(
			vim.lsp.handlers.hover, { border = o.border }
		)
		vim.lsp.handlers["textDocument/signatureHelp"] = vim.lsp.with(
			vim.lsp.handlers.signature_help, { border = o.border }
		)
		
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
	
