" docker on Windows and also when in screen
"nnoremap <C-Z> <nop>

" system-wide VIMRC can interfere
filetype off
runtime bundle/vim-pathogen/autoload/pathogen.vim
" execute pathogen#infect()

set nocompatible | filetype indent plugin on | syntax enable

" industry and torte also good
colorscheme murphy
" highlight Normal ctermfg=lightgrey ctermbg=black
highlight Function ctermfg=Green
" highlight Comment ctermfg=Pink
highlight LineNr ctermfg=Brown
highlight ColorColumn ctermbg=DarkGray

" Use the highlight group to expose unwanted/bad whitespace
highlight BadWhitespace ctermbg=red guibg=red

" Display tabs at the beginning of a line in Python mode as bad.
au BufRead,BufNewFile *.py,*.pyw match BadWhitespace /^\t\+/
" Make trailing whitespace be flagged as bad.
au BufRead,BufNewFile *.py,*.pyw,*.c,*.h,*.yml,*.yaml,*.json,*.pp match BadWhitespace /\s\+$/

au BufRead,BufNewFile *.py,*.pyw,*.tf set expandtab
au BufRead,BufNewFile *.yml,*.yaml,*.json set expandtab shiftwidth=2
" prevent insertion of '*' at the beginning of every line in a comment
au BufRead,BufNewFile *.c,*.h set formatoptions-=c formatoptions-=o formatoptions-=r
au BufNewFile,BufRead .bashrc*,.functions* set filetype=bash textwidth=85
au BufNewFile,BufRead .bashrc*,.functions* match BadWhitespace /\s\+$/

set modeline
set noim
set paste
set tabstop=8 softtabstop=4 shiftwidth=4 noet
set number
set backspace=indent,eol,start
" set laststatus=2
set autoindent
set ignorecase
set matchtime=3
set showmatch
set noswapfile
set wrap linebreak
set colorcolumn=-3
" set cursorline

" only on windows gVim
set guifont=Liberation_Mono:h9:cANSI
set guioptions=egmrLt

" squelch gratuitous noise
set noerrorbells visualbell t_vb=
autocmd GUIEnter * set visualbell t_vb=

if $COLORSCHEME != ""
  let base16colorspace=256
  exec 'colorscheme '.$COLORSCHEME
endif

"ref: https://vim.fandom.com/wiki/Mapping_keys_in_Vim_-_Tutorial_(Part_1)
" use F5 to grep for word under cursor in CWD
nnoremap <F5> :grep <C-R><C-W> *<CR>

