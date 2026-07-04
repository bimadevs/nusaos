# .zshrc — NusaOS default
autoload -Uz compinit
compinit

HISTFILE=~/.zsh_history
HISTSIZE=1000
SAVEHIST=1000
setopt APPEND_HISTORY
setopt SHARE_HISTORY

alias ll='ls -lAh'
alias la='ls -A'
alias update='sudo pacman -Syu'
alias install='sudo pacman -S'
alias search='pacman -Ss'
alias remove='sudo pacman -Rns'

# Zsh plugins
source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
source /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh

PROMPT='%F{green}%n@%m%f %F{blue}%~%f %# '
RPROMPT='%F{cyan}%D{%H:%M}%f'
