# Century

Always keep your cursor centered, even at the edges of the file.

## Features

- Keeps cursor vertically centered in the viewport
- Works even when at the first or last line of a file
- Uses virtual lines for smooth overscrolling at top and bottom
- Lightweight and performant with change detection

## Installation

### With mini.deps

```lua
local add = MiniDeps.add

add({
  source = 'feb/century',  -- or your github username
  depends = {},
})

require('century').setup()
```

## Configuration

```lua
require('century').setup({
  scrolloff = 999,  -- Default scrolloff value
})
```

## How it works

Century uses Neovim's extmarks API to add virtual lines above and below the buffer content. When your cursor is near the top of the file, it adds virtual padding above, and when near the bottom, it adds padding below. This creates the illusion of being able to scroll past the edges of the file while keeping your cursor perfectly centered.

## License

MIT
