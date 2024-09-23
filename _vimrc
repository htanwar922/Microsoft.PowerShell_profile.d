
" Vim.Vim package from winget

" Add following block to the main _vimrc file in "C:\\Program Files\\Vim\\_vimrc"
" if filereadable(expand("$HOME\\Documents\\PowerShell\\Microsoft.PowerShell_profile.d\\_vimrc"))
"  source "$HOME\\Documents\\PowerShell\\Microsoft.PowerShell_profile.d\\_vimrc"
" endif

set nowritebackup  " Disable backup before writing
set noswapfile     " Disable swap files
set number		   " Show line numbers
syntax on

" Get Vim-Plug plugin manager
" iwr -useb https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim | ni "$HOME/vimfiles/autoload/plug.vim" -Force

" call plug#begin($HOME.'/vimfiles/plugged')
"   Plug 'preservim/nerdcommenter'
" call plug#end()

