"@~/.vimrc

set nocompatible
set hidden
set number
set relativenumber
set signcolumn=yes
set cursorline
set splitright
set splitbelow
set backspace=indent,eol,start
set ttimeoutlen=0
set updatetime=200
set mouse=
set noswapfile

set tabstop=2
set shiftwidth=2
set expandtab
set autoindent

set nowrap
set ignorecase
set smartcase
set scrolloff=99999

set background=dark
set termguicolors

" Theme
hi clear
syntax reset
hi Normal guifg=#c0ccdb guibg=NONE
hi Cursor guibg=#d4856a guifg=#131719
hi CursorLine guibg=NONE gui=NONE cterm=NONE
hi CursorLineNr guifg=#d4856a gui=NONE cterm=NONE
hi LineNr guifg=#4e5c66
hi SignColumn guibg=NONE
hi Comment guifg=#4e5c66
hi String guifg=#84c4ce
hi Number guifg=#529ca8
hi Constant guifg=#d4856a
hi Keyword guifg=#d4856a
hi Function guifg=#43b5b3
hi Type guifg=#d4856a
hi Identifier guifg=#ffffff
hi Visual guibg=#293236
hi Search guibg=#5298c4 guifg=#131719
hi MatchParen guifg=#d4856a guibg=NONE gui=bold cterm=bold
hi StatusLine guifg=#ffffff guibg=#5298c4
hi StatusLineNC guifg=#4e5c66 guibg=#1e2427
hi VertSplit guifg=#1e2427 guibg=#1e2427

if has('clipboard')
	set clipboard^=unnamedplus
endif
let mapleader=" "
let maplocalleader=" "
nnoremap <leader>rrr :source ~/.vimrc<CR>

" Normal mode flag system
let g:stay_in_normal = 0

inoremap <Esc> <Esc>i<Right>
nnoremap <Esc> :let g:stay_in_normal = 0<CR>i
vnoremap <Esc> <Esc>:call <SID>CheckNormalFlag()<CR>
snoremap <Esc> <Esc>:call <SID>CheckNormalFlag()<CR>
onoremap <Esc> <Esc>:call <SID>CheckNormalFlag()<CR>
cnoremap <Esc> <C-c>i
inoremap <S-F12> <Esc>:let g:stay_in_normal = 1<CR>
nnoremap <S-F12> :let g:stay_in_normal = 1<CR>
vnoremap <S-F12> <Esc>:let g:stay_in_normal = 1<CR>

function! s:CheckNormalFlag()
  if !g:stay_in_normal
    startinsert
  endif
endfunction

" Ctrl+C/V/X mappings
vnoremap <C-c> :<C-u>call <SID>YankKeepPos()<CR>
vnoremap <C-x> "+d:call <SID>CheckNormalFlag()<CR>
inoremap <C-v> <C-r>+
nnoremap <C-v> "+p:call <SID>CheckNormalFlag()<CR>

function! s:YankKeepPos()
  let l:pos = getpos('.')
  normal! "+y
  call setpos('.', l:pos)
  call s:CheckNormalFlag()
endfunction

" Shift+arrow selection
inoremap <S-Up> <Esc>:let g:stay_in_normal = 0<CR>v<Up>
inoremap <S-Down> <Esc>:let g:stay_in_normal = 0<CR>v<Down>
inoremap <S-Left> <Esc>:let g:stay_in_normal = 0<CR>v<Left>
inoremap <S-Right> <Esc>:let g:stay_in_normal = 0<CR>v<Right>
inoremap <S-Home> <Esc>:let g:stay_in_normal = 0<CR>v^
inoremap <S-End> <Esc>:let g:stay_in_normal = 0<CR>v$
vnoremap <S-Up> <Up>
vnoremap <S-Down> <Down>
vnoremap <S-Left> <Left>
vnoremap <S-Right> <Right>
vnoremap <S-Home> ^
vnoremap <S-End> $

set nu nornu
augroup Global | au!
  au InsertEnter,WinLeave * set nornu
  au InsertLeave,WinEnter * set rnu
  au BufEnter,BufWinEnter * if &modifiable && &buftype == '' | startinsert | endif
augroup END

" Exit visual mode and return to insert on cursor movement
vnoremap <Up> <Esc>:call <SID>CheckNormalFlag()<CR><Up>
vnoremap <Down> <Esc>:call <SID>CheckNormalFlag()<CR><Down>
vnoremap <Left> <Esc>:call <SID>CheckNormalFlag()<CR><Left>
vnoremap <Right> <Esc>:call <SID>CheckNormalFlag()<CR><Right>
vnoremap <Home> <Esc>:call <SID>CheckNormalFlag()<CR><Home>
vnoremap <End> <Esc>:call <SID>CheckNormalFlag()<CR><End>
vnoremap <PageUp> <Esc>:call <SID>CheckNormalFlag()<CR><PageUp>
vnoremap <PageDown> <Esc>:call <SID>CheckNormalFlag()<CR><PageDown>

" Set cursor color to orange
if exists('$TMUX')
  let &t_SI = "\<Esc>Ptmux;\<Esc>\<Esc>]12;#d4856a\007\<Esc>\\"
  let &t_EI = "\<Esc>Ptmux;\<Esc>\<Esc>]12;#d4856a\007\<Esc>\\"
else
  let &t_SI = "\033]12;#d4856a\007"
  let &t_EI = "\033]12;#d4856a\007"
endif
