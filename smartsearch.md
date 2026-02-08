# Smart Search Design

## Overview
A unified search interface that chains multiple search operations using modifier prefixes. Each modifier processes the results from the previous operation, creating a pipeline of filters.

## Architecture

### Core Concept
- **Input format**: `[modifier][modifier]...[search_term]`
- **Parsing**: Read characters left-to-right; first non-modifier character starts the search term
- **Chaining**: Each modifier operates on the result of the previous one
- **Display**: Title shows the type of the **last** modifier

### Search Modules (`lua/search/`)

Each module exports a function that takes previous results and a search term:

1. **recent_files.lua**
   - `get_files()` → returns list of recent/open files
   - No input processing, generates initial file list

2. **file_search.lua**
   - `search(input_files, term)` → filters or searches files by name
   - If `input_files` provided: filters by term
   - If no input: uses ripgrep to get all files, then filters

3. **grep.lua**
   - `search(input_files, term)` → searches file contents
   - If `input_files` provided: greps only those files
   - If no input: greps entire project
   - Returns: `{filename, lnum, col, text, display}`

4. **buffers.lua**
   - `search(input_files, term)` → filters open buffers
   - Returns buffer paths matching term

5. **commits.lua**
   - `search(input_files, term)` → searches git commits
   - Uses `git log --grep` if term provided
   - Returns: `{hash, message, display}`

6. **diagnostics.lua**
   - `search(input_files, term)` → filters LSP diagnostics
   - Searches filename or message
   - Returns: `{filename, lnum, col, severity, message, display}`

7. **sessions.lua**
   - `search(input_files, term)` → lists saved sessions
   - Filters session names by term
   - Returns: `{path, name, display}`

## Modifier Configuration

Default modifiers in `smartsearch.lua`:

```lua
modifiers = {
  ['@'] = 'recent',      -- Recent files scope
  ['?'] = 'files',       -- All files scope
  ['\\'] = 'grep',       -- Grep content
  ['b'] = 'buffers',     -- Open buffers
  ['c'] = 'commits',     -- Git commits
  ['d'] = 'diagnostics', -- LSP diagnostics
  ['s'] = 'sessions',    -- Sessions
}
```

**User customizable** - can add more modifiers or change characters.

## Behavior

### Input Processing
1. Parse input character by character from left to right
2. Build chain of operations from modifiers
3. Everything after last modifier = search term
4. If input is empty or only modifiers → execute chain with empty term

### Execution Flow
```
Input: "@?.conf\url"

Parse:
  '@' → recent (get recent files)
  '?' → files (filter by ".conf")
  '\' → grep (search for "url")
  
Execute:
  1. recent_files.get_files() → [file1, file2, file3, ...]
  2. file_search.search([file1, file2, ...], ".conf") → [config1.conf, config2.conf]
  3. grep.search([config1.conf, config2.conf], "url") → [{filename, lnum, col, text}, ...]
  
Display: Title = "Grep" (last modifier)
```

### Empty States
- **No modifiers, no term**: Empty results
- **Modifier only (`@`)**: Execute that operation with empty term
- **Chain only (`@?`)**: Execute chain with empty term

### Default Text
- `default_text = "@"` pre-fills the input field
- Opens immediately showing recent files
- User can delete `@` to start from empty
- Configurable in options

## Telescope Integration

### Finder Creation
Based on result type:
- **files**: Display relative path, value = full path
- **grep/diagnostics**: Display `file:line: text`, contains `filename`, `lnum`, `col`
- **commits**: Display commit info, contains `hash`
- **sessions**: Display session name, contains `path`

### Selection Action
- **files**: `edit <path>`
- **grep/diagnostics**: `edit +<line> <path>`, set cursor to `col`
- **commits**: `Git show <hash>`
- **sessions**: `source <path>`

### Live Updates
- `TextChangedI` autocmd watches input changes
- Re-parses and refreshes results on every keystroke
- **No `new_prefix`** in refresh (prevents input field reset)

## Options

```lua
require('smartsearch').setup({
  hotkey = "<C-o>",           -- Trigger key
  default_text = "@",         -- Pre-filled input
  modifiers = {               -- Custom modifiers
    ['@'] = 'recent',
    ['?'] = 'files',
    ['\\'] = 'grep',
    ['b'] = 'buffers',
    ['c'] = 'commits',
    ['d'] = 'diagnostics',
    ['s'] = 'sessions',
  }
})
```

## Examples

| Input | Chain | Search Term | Result |
|-------|-------|-------------|--------|
| `@` | recent | (empty) | All recent files |
| `@readme` | recent | "readme" | Recent files with "readme" |
| `?config` | files | "config" | All files with "config" |
| `\function` | grep | "function" | Grep "function" in all files |
| `btest` | buffers | "test" | Open buffers with "test" |
| `cfix` | commits | "fix" | Commits with "fix" in message |
| `@?` | recent→files | (empty) | Recent files filtered by (nothing) |
| `@?.conf` | recent→files | ".conf" | Recent files with ".conf" |
| `@?.conf\url` | recent→files→grep | "url" | Grep "url" in recent .conf files |
| `?\main` | files→grep | "main" | Grep "main" in all files |

## Implementation Notes

### Non-Blocking Operations
- **Must use `vim.fn.systemlist()`** instead of `io.popen()`
- Prevents UI freezing during ripgrep/git operations
- Critical for grep and file_search modules

### Title Updates
- Title always reflects the **last modifier** in chain
- Shows what type of results are displayed
- Updates dynamically as you type

### Performance
- Each search module should handle empty terms efficiently
- File lists cached when possible (recent files)
- Ripgrep operations run per-keystroke (fast enough)
- Git operations limited to 100 results

### Error Handling
- Empty results = empty telescope list, not error
- Invalid git repos = empty commit list
- Missing files in recent list = filtered out

### UI
- Should use the same configuration as the other floats
- Consists of 3 vertically stacked sections
    - Preview
    - Files
    - Input

### Fuzzy Matching
- Telescope's fuzzy finder per result type 

### History/Persistance
- The last typed search term should stay across a session

## Future Enhancements

Possible additions:
- **Custom modules**: User-defined search types
- **Modifier arguments**: `@50` = last 50 recent files
- **Negation**: `!grep` = exclude matches

