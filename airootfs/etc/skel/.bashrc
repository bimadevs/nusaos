# .bashrc — NusaOS default
alias ll='ls -lAh'
alias la='ls -A'
alias update='sudo pacman -Syu'
alias install='sudo pacman -S'
alias search='pacman -Ss'
alias remove='sudo pacman -Rns'

PS1='\[\e[1;32m\]\u@\h\[\e[0m\] \[\e[1;34m\]\w\[\e[0m\] \$ '
