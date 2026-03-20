"============================================================
" Modern Vim Configuration
" Migrated from Vundle → vim-plug
" Backup: ~/.vimrc.bak.*
"============================================================

"--------------------基础设置-----------------------------
set nocompatible
set encoding=utf-8
set fileencodings=ucs-bom,utf-8,utf-16,gbk,big5,gb18030,latin1
set fileformats=unix,dos,mac

syntax on
set background=dark
set mouse=a
set number
set relativenumber          " 相对行号，方便跳转
set showcmd
set showmatch               " 显示匹配括号
set cursorline              " 始终高亮当前行

" 缩进
set smartindent
set autoindent
set shiftwidth=4
set tabstop=4
set softtabstop=4
set noexpandtab             " 保留你的 Tab 习惯
" Python 等语言自动切换为空格（见底部 autocmd）

" 搜索
set hlsearch
set incsearch
set ignorecase smartcase
set nowrapscan
set magic

" 体验优化
set wildmenu                " 命令行 Tab 补全菜单
set wildmode=longest:full,full
set scrolloff=5             " 光标距边缘保持 5 行
set sidescrolloff=8
set history=1000
set ttimeoutlen=50          " 更快的按键响应
set updatetime=300          " 更快的 swap 写入 & 插件响应
set lazyredraw              " 宏执行时不重绘，更快
set hidden                  " 允许切换未保存的 buffer
set splitright              " 垂直分屏默认在右边打开
set splitbelow              " 水平分屏默认在下边打开

" 剪贴板
set clipboard=unnamedplus

" OSC 52: SSH 远程时 y 复制自动同步到本地剪贴板
" 需要终端支持 OSC 52（iTerm2 / macOS Terminal / Windows Terminal / Alacritty）
function! s:OscYank()
    let encoded = system('echo -n ' . shellescape(getreg('"')) . ' | base64 | tr -d "\n"')
    let osc = "\x1b]52;c;" . encoded . "\x07"
    call writefile([osc], '/dev/tty', 'b')
endfunction
autocmd TextYankPost * if v:event.operator ==# 'y' | call <SID>OscYank() | endif

" 折叠
set foldenable
set foldmethod=syntax
set foldlevelstart=99       " 默认全部展开

" 备份/交换文件集中存放
set nobackup
set nowritebackup
set swapfile
set directory=~/.vim/swap//
silent! call mkdir(expand('~/.vim/swap'), 'p')

" 持久化 undo
if has('persistent_undo')
    set undofile
    set undodir=~/.vim/undo//
    silent! call mkdir(expand('~/.vim/undo'), 'p')
endif

" 记忆上次编辑位置
au BufReadPost * if line("'\"") > 1 && line("'\"") <= line("$") | exe "normal! g'\"" | endif

" .vimrc 保存后自动重载
autocmd! BufWritePost .vimrc source %

" Shell
set shell=/bin/bash

"--------------------插件---------------------------------
call plug#begin('~/.vim/plugged')

" 文件树
Plug 'preservim/nerdtree'

" 注释工具
Plug 'preservim/nerdcommenter'

" 异步语法检查（替代 syntastic）
Plug 'dense-analysis/ale'

" 状态栏（替代 powerline）
Plug 'vim-airline/vim-airline'
Plug 'vim-airline/vim-airline-themes'

" 配色方案
Plug 'flazz/vim-colorschemes'
Plug 'morhetz/gruvbox'

" 模糊搜索（超好用）
Plug 'junegunn/fzf', { 'do': { -> fzf#install() } }
Plug 'junegunn/fzf.vim'

" Git 集成
Plug 'tpope/vim-fugitive'
Plug 'airblade/vim-gitgutter'

" 成对符号操作
Plug 'tpope/vim-surround'

" 自动补全括号
Plug 'jiangmiao/auto-pairs'

" 更好的重复操作
Plug 'tpope/vim-repeat'

call plug#end()

"--------------------配色---------------------------------
" termguicolors 必须在 colorscheme 之前设置，否则配色初始化时用错调色板
if has('termguicolors')
    set termguicolors
endif
silent! colorscheme gruvbox
"silent! colorscheme desert
"silent! colorscheme solarized

"--------------------插件配置-----------------------------

" --- NERDTree ---
map <F4> :NERDTreeToggle<CR>
let NERDTreeShowHidden=1
let NERDTreeIgnore=['\.pyc$', '__pycache__', '\.swp$']
" 最后一个窗口是 NERDTree 时自动关闭
autocmd BufEnter * if winnr('$') == 1 && exists('b:NERDTree') && b:NERDTree.isTabTree() | quit | endif

" --- ALE (异步语法检查) ---
let g:ale_sign_error = '>>'
let g:ale_sign_warning = '>'
let g:ale_echo_msg_format = '[%linter%] %s [%severity%]'
let g:ale_lint_on_text_changed = 'normal'
let g:ale_lint_on_insert_leave = 1
let g:ale_lint_on_enter = 1
let g:ale_fix_on_save = 0
let g:ale_cpp_cc_options = '-std=c++17 -Wall'
let g:ale_c_cc_options = '-Wall'
" ALE 状态栏集成由 airline 自动处理

" --- Airline ---
set laststatus=2
let g:airline_powerline_fonts = 0       " 不依赖特殊字体
let g:airline#extensions#ale#enabled = 1
let g:airline#extensions#branch#enabled = 1
let g:airline#extensions#tabline#enabled = 1   " 顶部显示 buffer 标签

" --- GitGutter ---
set signcolumn=yes

" --- fzf ---
" 确保 fzf 二进制在 PATH 中
let $PATH = expand('~/.vim/plugged/fzf/bin') . ':' . $PATH
nnoremap <C-p> :Files<CR>
nnoremap <leader>/ :Rg<CR>
nnoremap <leader>b :Buffers<CR>

" 光标词/选中文本 → fzf 全局搜索（关键词显示在输入框中，可继续编辑）
command! -nargs=* RgWord call fzf#vim#grep(
    \ 'rg --column --line-number --no-heading --color=always --smart-case -- '.fzf#shellescape(<q-args>),
    \ fzf#vim#with_preview({'options': ['--query', <q-args>]}), 0)
nnoremap <leader>* :RgWord <C-r>=expand('<cword>')<CR><CR>
vnoremap <leader>* y:RgWord <C-r>"<CR>

"--------------------按键映射-----------------------------

" F8/F9 粘贴模式
map <F8> :set paste<CR>
map <F9> :set nopaste<CR>

" Leader 键（默认 \，可改为空格）
" let mapleader = " "

" 快速保存/退出
nnoremap <leader>w :w<CR>
nnoremap <leader>q :q<CR>

" 清除搜索高亮
nnoremap <leader><space> :nohlsearch<CR>

" Buffer 切换
nnoremap <leader>n :bnext<CR>
nnoremap <leader>p :bprevious<CR>

" 窗口间跳转
nnoremap <C-h> <C-w>h
nnoremap <C-j> <C-w>j
nnoremap <C-k> <C-w>k
nnoremap <C-l> <C-w>l

"--------------------语言特定-----------------------------

" Python: 强制空格缩进
autocmd FileType python setlocal expandtab shiftwidth=4 softtabstop=4 tabstop=4

" YAML: 2 空格
autocmd FileType yaml,yml setlocal expandtab shiftwidth=2 softtabstop=2 tabstop=2

" JavaScript/TypeScript/JSON: 2 空格
autocmd FileType javascript,typescript,json setlocal expandtab shiftwidth=2 softtabstop=2 tabstop=2

" Makefile: 必须用 Tab
autocmd FileType make setlocal noexpandtab

"--------------------本地配置-----------------------------

" 加载本地配置（不被 dotfiles 覆盖）
if filereadable(expand('~/.vimrc.local'))
    source ~/.vimrc.local
endif
