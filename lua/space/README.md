# space

A minimal floating overlay panel for Neovim, anchored to the bottom of a window.

## Overview

`space` creates a non-focusable floating window that sits at the bottom of a target window. It's useful for rendering transient UI elements — status bars, prompts, previews — without disturbing the main editing layout.

The overlay supports virtual-text-based line rendering, dynamic resizing, and scoped keybinding management that cleanly restores prior mappings on close.

## Usage

```lua
local space = require("space")

local s = space()          -- attach to current window
local s = space(win)       -- attach to a specific window
local s = space({ win = win, height = 6, width = 80 })
```

### Options

| Option           | Type    | Default                              | Description                          |
|------------------|---------|--------------------------------------|--------------------------------------|
| `win`            | number  | current window                       | Window to anchor the overlay to      |
| `height`         | number  | `4`                                  | Height in lines                      |
| `width`          | number  | width of target window               | Width in columns                     |
| `focusable`      | boolean | `false`                              | Whether the overlay can receive focus |
| `zindex`         | number  | `10`                                 | Stacking order                       |
| `winhighlight`   | string  | `"Normal:Normal,NormalFloat:Normal"` | Window highlight overrides           |

## API

### `s:height()`
Returns the current height of the overlay.

### `s:win_height()`
Returns the total height of the parent window.

### `s:orig()`
Returns the handle of the parent window.

### `s:buf()`
Returns the overlay buffer handle.

### `s:win()`
Returns the overlay window handle.

### `s:resize(new_height)`
Resize the overlay. Clamped to the parent window height. No-op if the height is unchanged.

### `s:set_line(lnum, virt)`
Render a virtual text chunk on line `lnum` (1-indexed). Clears any existing extmark on that line first.

```lua
s:set_line(1, { { "hello ", "Comment" }, { "world", "String" } })
```

### `s:clear()`
Remove all virtual text from the overlay buffer.

### `s:bind(mode, lhs, rhs, opts)`
Set a keybinding that will be automatically cleaned up on `close()`. If a prior mapping exists for the same key, it is snapshotted and restored when the binding is removed.

```lua
s:bind("n", "<Esc>", function() s:close() end, { buffer = bufnr })
```

### `s:unbind(mode, lhs, opts)`
Remove a single managed binding and restore the prior mapping if one existed.

### `s:rebind_all()`
Re-snapshot and re-apply all managed bindings. Useful after buffer or window changes that may have invalidated the mappings.

### `s:close()`
Restore all managed keybindings to their prior state, close the floating window, and wipe the buffer.
