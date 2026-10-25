# ==============================================================================
# NusaOS Zsh Configuration (Modern Developer Environment)
# ==============================================================================

# Enable colors and change prompt
autoload -U colors && colors

# History settings
HISTSIZE=10000
SAVEHIST=10000
HISTFILE=~/.zsh_history

# Prompt initialization with Starship
if command -v starship >/dev/null 2>&1; then
    eval "$(starship init zsh)"
fi

# Modern CLI Tool Aliases (State-of-the-art replacements)
if command -v eza >/dev/null 2>&1; then
    alias ls='eza --icons'
    alias ll='eza -lh --icons --git'
    alias la='eza -lah --icons --git'
    alias tree='eza --tree --icons'
else
    alias ls='ls --color=auto'
    alias ll='ls -lh'
    alias la='ls -lah'
fi

if command -v bat >/dev/null 2>&1; then
    alias cat='bat --paging=never'
fi

if command -v ripgrep >/dev/null 2>&1; then
    alias grep='rg'
else
    alias grep='grep --color=auto'
fi

if command -v fd >/dev/null 2>&1; then
    alias find='fd'
fi

if command -v btop >/dev/null 2>&1; then
    alias top='btop'
fi

if command -v nvim >/dev/null 2>&1; then
    alias vim='nvim'
    alias vi='nvim'
fi

alias update='paru -Syu'
alias nusa-help='fastfetch'

# Display system info on interactive shell login
if [[ -o interactive ]] && command -v fastfetch >/dev/null 2>&1; then
    fastfetch
fi

# Source syntax highlighting and autosuggestions if installed
if [[ -f /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]]; then
    source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
fi

if [[ -f /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh ]]; then
    source /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh
fi
