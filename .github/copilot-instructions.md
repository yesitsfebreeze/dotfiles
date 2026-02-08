# Neovim Configuration - AI Coding Guide

## Architecture Overview

This is a **modular, custom Neovim configuration** built on Lua. Each feature lives in a dedicated module under `lua/`, loaded by [init.lua](init.lua). The configuration uses `mini.deps` for plugin management (bootstrapped in [lua/deps.lua](lua/deps.lua)), avoiding traditional plugin managers like Packer or lazy.nvim.

### Core Philosophy
- **Inverted modal editing**: Default to INSERT mode, NORMAL requires explicit activation (see [lua/invert.lua](lua/invert.lua))
- **Transparent, minimalist UI**: No backgrounds, square borders, centered content
- **Mode-based visual feedback**: Colors change across cursor, statusline, and gutter based on current mode
- **Self-contained modules**: Each `lua/*.lua` file is independent with a `.setup(opts)` pattern

## Module Pattern

All modules follow this structure:

```lua
local M = {}
local add = require('deps').add  -- For plugin dependencies

local defaults = { ... }  -- Default configuration

local function merge_opts(user)
	-- Merge user opts with defaults
end

function M.setup(opts)
	local o = merge_opts(opts)
	add({ source = 'author/plugin' })  -- Install plugins
	-- Configuration logic
end

return M
```

**Key convention**: When adding plugins, use `add({ source = 'author/plugin' })` from [lua/deps.lua](lua/deps.lua), not traditional plugin managers.

## Critical Modules

### Modal Inversion ([lua/invert.lua](lua/invert.lua))
- **Default state**: INSERT mode (inverted from standard Vim)
- **Enter NORMAL**: Press configured hotkey (default `<F24>`)
- **Stay in NORMAL**: `g.leave_normal = false` flag prevents auto-return to INSERT
- **Exit NORMAL**: `<Esc>` sets `g.leave_normal = true`, triggering auto-return
- **Disabled contexts**: Excluded buffer/file types (Oil, Telescope, etc.) revert to standard Vim behavior

When modifying modal behavior, respect the `g.leave_normal` flag and `is_disabled()` checks.

### Session Management ([lua/sessions.lua](lua/sessions.lua))
- **Auto-saves**: Sessions saved per-directory to `~/.local/share/nvim/sessions/`
- **Naming**: Directory paths converted to filenames (`/path/to/dir` → `_path_to_dir.vim`)
- **Telescope picker**: Bound to `<leader>e` (default), shows all sessions sorted by mtime
- **File vs folder**: Opening `nvim file.txt` loads session in background; `nvim .` opens Oil explorer

### Centering Plugin ([lua/century.lua](lua/century.lua))
- **Virtual padding**: Adds 256 virtual lines above/below buffers
- **Auto-centering**: `CursorMoved` events keep cursor vertically centered
- **Buffer exclusions**: Skips non-real buffers (Oil, Telescope, `buftype ~= ""`)
- Uses extmarks with `virt_lines_above` for top padding, standard `virt_lines` for bottom

### Mode Colors
Defined in [init.lua](init.lua) and passed to multiple modules:
```lua
local ModeColors = {
	n = "#efb756",  -- Normal: orange
	i = "#4ceca4",  -- Insert: teal
	v = "#5aa3f0",  -- Visual: blue
	r = "#e84e55",  -- Replace: red
	c = "#c763eb",  -- Command: purple
}
```

Modules that consume `colors`: `blockcursor`, `statusline`, `gutter`.

## Developer Workflows

### Testing Changes
1. Edit module files in `lua/`
2. Reload config: `:source ~/.config/nvim/init.lua` or restart Neovim
3. Check plugin installation: `:lua print(vim.inspect(MiniDeps.get_session()))`

### Adding New Modules
1. Create `lua/newmodule.lua` with standard pattern
2. Add `require('newmodule').setup(opts)` to [init.lua](init.lua)
3. Use `add({ source = '...' })` for plugin dependencies

### Debugging Modal Issues
- Check `vim.g.leave_normal` value: `:lua print(vim.g.leave_normal)`
- Verify buffer isn't in disabled list: `:lua print(vim.bo.buftype, vim.bo.filetype)`
- Enable verbose mode changes: `:autocmd ModeChanged`

## Key Conventions

### Plugin Management
- **Never** manually call `:Lazy` or `:PackerSync` – this config doesn't use those
- Install plugins via `add()` in module `setup()` functions
- `mini.deps` bootstraps on first run from [lua/deps.lua](lua/deps.lua)

### Transparent Backgrounds
All UI elements explicitly set `guibg=NONE` (see [lua/theme.lua](lua/theme.lua)):
- Applied via autocmd on `ColorScheme` events
- Re-applies after theme changes
- Affects Normal, Float, Telescope, StatusLine, etc.

### Square Borders
All floating windows use ASCII square borders:
```lua
borderchars = { '─', '│', '─', '│', '┌', '┐', '┘', '└' }
```
Applied in [init.lua](init.lua) for Telescope, Oil configs include `border = 'single'`.

### Hotkey Configuration
Centralized in [init.lua](init.lua) `HotKeys` table:
```lua
local HotKeys = {
	to_normal = "<F24>",      -- Enter normal mode (invert.lua)
	leader = " ",             -- Leader key
	explorer = "<leader>q",   -- Oil file explorer
	recentfiles = "<leader>w",  -- Telescope recent files
	sessions = "<leader>e",   -- Session picker
}
```

Always pass hotkeys to modules via `setup(opts)`, don't hardcode.

## Integration Points

### Telescope
- Recent files picker: [lua/recentfiles.lua](lua/recentfiles.lua)
- Session management: [lua/sessions.lua](lua/sessions.lua)
- Both use vertical layout anchored East (right side)
- Close Oil windows before opening pickers (see `close_oil_windows()`)

### Oil.nvim
- File explorer as buffer ([lua/explorer.lua](lua/explorer.lua))
- Excluded from centering, gutter, and modal inversion
- Float config: `padding = 2`, `border = "single"`

### Treesitter
- Rainbow delimiters with custom colors ([lua/treesitter.lua](lua/treesitter.lua))
- Auto-installs parsers on buffer enter
- Colors reapplied on `ColorScheme` autocmd

### Gitsigns
- Configured in [lua/gutter.lua](lua/gutter.lua)
- Custom sign characters: `▎` for all change types
- Colors: `add=#76946A`, `change=#DCA561`, `delete=#C34043`

## Common Pitfalls

1. **Plugin loading order**: [init.lua](init.lua) must call `require('blockcursor')` before mode-dependent modules
2. **Cursor position preservation**: Don't modify `virtualedit` setting (set to `"onemore"` by [lua/blockcursor.lua](lua/blockcursor.lua))
3. **Mode colors**: Always destructure from `ModeColors` table in [init.lua](init.lua), don't define inline
4. **Transparent backgrounds**: When adding UI elements, always set `guibg=NONE` and register `ColorScheme` autocmd
5. **Module isolation**: Never `require()` other modules except `deps` – pass data via `setup(opts)` parameters
