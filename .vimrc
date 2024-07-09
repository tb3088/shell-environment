" docker on Windows and also when in screen
nnoremap <C-Z> <Nop>

" system-wide VIMRC can interfere
filetype off
runtime bundle/vim-pathogen/autoload/pathogen.vim
execute pathogen#infect()

set nocompatible | filetype plugin indent on | syntax enable

" if $COLORSCHEME != ""
"   let base16colorspace=256
"   exec 'colorscheme '.$COLORSCHEME
" endif

" set termguicolors
set background=dark
" murphy industry and torte also good
colorscheme PaperColor
" highlight Normal ctermfg=lightgrey ctermbg=black
" highlight Function ctermfg=Green
" highlight Comment ctermfg=Pink
" highlight LineNr ctermfg=Brown
highlight CursorLine cterm=NONE gui=NONE
highlight CursorLineNr ctermfg=Brown cterm=bold gui=bold
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
set cursorlineopt=number
set cursorline

" EasyTags https://peterodding.com/code/vim/easytags/
"let g:easytags_cmd = '/usr/local/bin/ctags'
"let g:easytags_file = '~/.vim/tags'

" Syntastic
set statusline+=%#warningmsg#
set statusline+=%{SyntasticStatuslineFlag()}
set statusline+=%*
let g:syntastic_always_populate_loc_list = 1
let g:syntastic_auto_loc_list = 1
let g:syntastic_check_on_open = 1
let g:syntastic_check_on_wq = 0

" only on windows gVim
set guifont=Liberation_Mono:h9:cANSI
set guioptions=egmrLt

" squelch gratuitous noise
set noerrorbells visualbell t_vb=
autocmd GUIEnter * set visualbell t_vb=

"ref:	https://vim.fandom.com/wiki/Mapping_keys_in_Vim_-_Tutorial_(Part_2)
"	https://vim.fandom.com/wiki/Browsing_programs_with_tags
" my .screenrc uses Ctrl-O as command prefix, Alt-L/R to switch buffers, and F1-F4 for direct
nnoremap <F1> <Nop>
nnoremap <F2> <Nop>
nnoremap <F3> <Nop>
nnoremap <F4> <Nop>
" redefine 'next' and 'previous' match
noremap <C-Up> <C-O>
noremap <C-Down> <C-I>

"ref: https://shapeshed.com/vim-netrw/
" use F5 to list files in current file's directory
nnoremap <silent> <F5> :lchdir %:p:h<CR>:Vexplore<CR>
let g:netrw_banner = 0
let g:netrw_winsize = 25
let g:netrw_liststyle = 3
"let g:netrw_browse_split = 1
" switch all splits to Horizontal/Vertical
nnoremap <F9> :windo wincmd K<CR>
nnoremap <F10> :windo wincmd H<CR>

