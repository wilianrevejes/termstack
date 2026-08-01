# Catppuccin Mocha para o powerlevel10k, estilo rainbow (segmento com fundo).
#
# Arquivo separado de propósito: `p10k configure` reescreve o p10k.zsh
# INTEIRO, do zero. Cor editada lá dentro morre no primeiro wizard. Aqui não —
# o zshrc sourceia este arquivo DEPOIS, então ele sempre ganha.
#
# Não existe port oficial do catppuccin para p10k (a org só tem
# zsh-syntax-highlighting, zsh-fsh e skim). O port de comunidade de referência
# substituiria o p10k.zsh inteiro, jogando fora a lista de segmentos já
# enxugada — daí estas 30 linhas em vez da dependência.
#
# Hex direto funciona porque o WezTerm tem truecolor: o p10k aceita #RRGGBB em
# qualquer POWERLEVEL9K_*_{FORE,BACK}GROUND, além dos índices 0-255.

# Paleta oficial (catppuccin/catppuccin, flavour mocha).
crust='#11111b'    surface0='#313244'  surface1='#45475a'
overlay0='#6c7086' subtext1='#bac2de'  lavender='#b4befe'
blue='#89b4fa'     teal='#94e2d5'      green='#a6e3a1'
yellow='#f9e2af'   peach='#fab387'     red='#f38ba8'
mauve='#cba6f7'    sky='#89dceb'

# ── dir ───────────────────────────────────────────────────────────────────
typeset -g POWERLEVEL9K_DIR_BACKGROUND=$blue
typeset -g POWERLEVEL9K_DIR_FOREGROUND=$crust
typeset -g POWERLEVEL9K_DIR_SHORTENED_FOREGROUND=$surface1
typeset -g POWERLEVEL9K_DIR_ANCHOR_FOREGROUND=$crust
typeset -g POWERLEVEL9K_DIR_NOT_WRITABLE_BACKGROUND=$red
typeset -g POWERLEVEL9K_DIR_NOT_WRITABLE_FOREGROUND=$crust

# ── vcs ───────────────────────────────────────────────────────────────────
# Os quatro estados são cores distintas de propósito: é o que faz você ver o
# estado do repositório sem precisar ler o texto.
typeset -g POWERLEVEL9K_VCS_CLEAN_BACKGROUND=$green
typeset -g POWERLEVEL9K_VCS_MODIFIED_BACKGROUND=$yellow
typeset -g POWERLEVEL9K_VCS_UNTRACKED_BACKGROUND=$teal
typeset -g POWERLEVEL9K_VCS_CONFLICTED_BACKGROUND=$red
typeset -g POWERLEVEL9K_VCS_{CLEAN,MODIFIED,UNTRACKED,CONFLICTED}_FOREGROUND=$crust
typeset -g POWERLEVEL9K_VCS_LOADING_BACKGROUND=$surface0
typeset -g POWERLEVEL9K_VCS_LOADING_FOREGROUND=$overlay0

# ── status ────────────────────────────────────────────────────────────────
typeset -g POWERLEVEL9K_STATUS_OK_BACKGROUND=$surface0
typeset -g POWERLEVEL9K_STATUS_OK_FOREGROUND=$green
typeset -g POWERLEVEL9K_STATUS_OK_PIPE_BACKGROUND=$surface0
typeset -g POWERLEVEL9K_STATUS_OK_PIPE_FOREGROUND=$green
typeset -g POWERLEVEL9K_STATUS_ERROR_BACKGROUND=$red
typeset -g POWERLEVEL9K_STATUS_ERROR_FOREGROUND=$crust
typeset -g POWERLEVEL9K_STATUS_ERROR_SIGNAL_BACKGROUND=$red
typeset -g POWERLEVEL9K_STATUS_ERROR_SIGNAL_FOREGROUND=$crust
typeset -g POWERLEVEL9K_STATUS_ERROR_PIPE_BACKGROUND=$red
typeset -g POWERLEVEL9K_STATUS_ERROR_PIPE_FOREGROUND=$crust

# ── demais segmentos do RIGHT_PROMPT_ELEMENTS ─────────────────────────────
typeset -g POWERLEVEL9K_COMMAND_EXECUTION_TIME_BACKGROUND=$peach
typeset -g POWERLEVEL9K_COMMAND_EXECUTION_TIME_FOREGROUND=$crust
typeset -g POWERLEVEL9K_BACKGROUND_JOBS_BACKGROUND=$surface0
typeset -g POWERLEVEL9K_BACKGROUND_JOBS_FOREGROUND=$sky
typeset -g POWERLEVEL9K_NVM_BACKGROUND=$mauve
typeset -g POWERLEVEL9K_NVM_FOREGROUND=$crust
typeset -g POWERLEVEL9K_CONTEXT_BACKGROUND=$surface0
typeset -g POWERLEVEL9K_CONTEXT_FOREGROUND=$yellow
typeset -g POWERLEVEL9K_CONTEXT_ROOT_BACKGROUND=$red
typeset -g POWERLEVEL9K_CONTEXT_ROOT_FOREGROUND=$crust
typeset -g POWERLEVEL9K_TIME_BACKGROUND=$surface1
typeset -g POWERLEVEL9K_TIME_FOREGROUND=$subtext1

# vi_mode: o zshrc força emacs, mas o segmento continua no prompt.
typeset -g POWERLEVEL9K_VI_MODE_FOREGROUND=$crust
typeset -g POWERLEVEL9K_VI_MODE_NORMAL_BACKGROUND=$green
typeset -g POWERLEVEL9K_VI_MODE_VISUAL_BACKGROUND=$lavender
typeset -g POWERLEVEL9K_VI_MODE_OVERWRITE_BACKGROUND=$yellow
typeset -g POWERLEVEL9K_VI_MODE_INSERT_FOREGROUND=$overlay0

# `verbose` avisa toda vez que algum init imprime no console durante o
# startup. Num rc com mise, integração de shell do editor e completions de
# SDK, isso vira sermão a cada shell. `quiet` mantém a aceleração sem o aviso.
typeset -g POWERLEVEL9K_INSTANT_PROMPT=quiet

unset crust surface0 surface1 overlay0 subtext1 lavender blue teal green \
  yellow peach red mauve sky
