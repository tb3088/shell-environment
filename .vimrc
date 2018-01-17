set nocompatible
execute pathogen#infect()
filetype plugin indent on
colorscheme default
syntax enable

" highlight Normal ctermfg=lightgray ctermbg=black
"highlight Comment ctermfg=lightblue guifg=lightblue
" highlight LineNr ctermfg=gray guifg=gray
highlight LineNr ctermfg=blue guifg=gray
" highlight String 
" highlight Constant 

" Use the highlight group to expose unwanted/bad whitespace
highlight BadWhitespace ctermbg=red guibg=red

" Display tabs at the beginning of a line in Python mode as bad.
au BufRead,BufNewFile *.py,*.pyw match BadWhitespace /^\t\+/
" Make trailing whitespace be flagged as bad.
au BufRead,BufNewFile *.py,*.pyw,*.c,*.h,*.yml,*.yaml,*.json,*.pp match BadWhitespace /\s\+$/

au BufRead,BufNewFile *.py,*.pyw,*.c,*.h,*.pp set textwidth=78
au BufRead,BufNewFile *.py,*.pyw,*.tf set expandtab
au BufRead,BufNewFile *.yml,*.yaml,*.json set expandtab shiftwidth=2
" prevent insertion of '*' at the beginning of every line in a comment
au BufRead,BufNewFile *.c,*.h set formatoptions-=c formatoptions-=o formatoptions-=r
" Ruby/Puppet - set expandtab tabstop=2 shiftwidth=2 softtabstop=2
"au BufRead,BufNewFile *.ru,*.pp,*eml set filetype=ruby


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

" only on windows gVim
set guifont=Liberation_Mono:h9:cANSI
set guioptions=egmrLt

" squelch gratuitous noise
set noerrorbells visualbell t_vb=
autocmd GUIEnter * set visualbell t_vb=
