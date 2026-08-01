# shellcheck shell=bash
# shellcheck disable=SC2034  # consumidas pelos scripts que dão source aqui
#
# Catálogo de mensagens — português do Brasil.
#
# Selecione com:
#
#   TERMSTACK_LANG=pt-BR bash scripts/setup.sh
#
# ou deixe ser escolhido pelo $LANG do sistema.
#
# O en.sh é carregado ANTES deste arquivo, sempre. Chave que não estiver aqui
# cai no inglês em vez de imprimir linha vazia — então traduzir por partes
# funciona, e apagar uma chave daqui é seguro.
#
# Os valores são formatos de printf: `%s` marca onde o dado entra e a ORDEM
# tem que bater com a chamada. Quando o português pedir ordem diferente do
# inglês, use `%1$s`, `%2$s`. Por cento literal se escreve `%%`.

# ── Links de configuração ─────────────────────────────────────────────────

MSG_LINK_IS_REPO='%s é o próprio repositório'
MSG_LINK_OK='%s → repositório'
MSG_LINK_ELSEWHERE='%s já é link para %s, mantido'
MSG_LINK_EXISTS='%s já existe e não é link — não vou sobrescrever'
MSG_LINK_EXISTS_NOTE='mova e rode de novo:  mv "%s" "%s.bak"'
MSG_LINK_LEGACY='você já tem %s — não criei o link'
MSG_LINK_LEGACY_NOTE1='%s tem prioridade sobre ele, então o link deixaria'
MSG_LINK_LEGACY_NOTE2='sua config atual inerte.'
MSG_LINK_LEGACY_NOTE3='para trocar:  mv "%s" "%s.bak" && ln -s "%s" "%s"'
MSG_LINK_CREATED='%s → %s'

# ── machine.lua ───────────────────────────────────────────────────────────

MSG_MACHINE_KEPT='machine.lua já existe, mantido'
MSG_MACHINE_CREATED='machine.lua criado a partir de machine.example.lua'

# ── mise e as CLI ─────────────────────────────────────────────────────────

MSG_MISE_PRESENT='mise já instalado (%s)'
MSG_MISE_VIA_BREW='instalando mise pelo Homebrew'
MSG_MISE_VIA_CURL='instalando mise em ~/.local/bin'
MSG_MISE_MISSING='mise não encontrado, pulando a instalação das CLI'
MSG_TOOLS_INSTALLING='instalando as CLI (mise/config.toml)'

# ── Configuração do shell ─────────────────────────────────────────────────

MSG_RC_CREATED='%s criado (máquina limpa)'
MSG_RC_CONFIGURED='%s já configurado'
MSG_RC_OWN_OMZ='%s tem oh-my-zsh/p10k próprios, config do repositório NÃO ativada'
MSG_RC_OWN_OMZ_NOTE='só EDITOR foi configurado — a receita de migração está no bloco'
MSG_RC_LOADS='%s carrega a config do repositório'
MSG_RC_BASH='%s configurado (mise + EDITOR)'

msg_rc_migration_block() {
  printf '# Seu ~/.zshrc já carrega oh-my-zsh/p10k por conta própria, então a\n'
  printf '# config deste repositório NÃO é ativada: seriam dois compinit e\n'
  printf '# dois blocos de instant prompt.\n'
  printf '#\n'
  printf '# Para migrar, apague do seu rc: o bloco de instant prompt, o\n'
  printf '# export ZSH / ZSH_THEME / plugins=() / source oh-my-zsh.sh, o\n'
  printf '# source do ~/.p10k.zsh e o eval do mise. Depois troque estas\n'
  printf '# linhas por:\n'
  printf '#   source "%s/zsh/zshrc"\n' "$1"
}

# ── Repositórios clonados (oh-my-zsh, p10k, plugins) ──────────────────────

MSG_REPO_INSTALLED='%s instalado'
MSG_REPO_INSTALLED_REF='%s instalado (%s)'
MSG_REPO_CLONE_FAILED='%s falhou ao clonar'
MSG_REPO_DIRTY='%s pulado (árvore com modificação local)'
MSG_REPO_DIRTY_NOTE='para atualizar: git -C "%s" checkout .'
MSG_REPO_UPDATED='%s atualizado'
MSG_REPO_UPDATE_FAILED='%s falhou ao atualizar'
MSG_REPO_PINNED='%s pinado em %s'
MSG_REPO_REPINNED='%s repinado (%s → %s)'

# ── tmux ──────────────────────────────────────────────────────────────────

MSG_TMUX_MISSING='tmux não encontrado, pulando os plugins do tmux'
MSG_TMUX_PLUGINS='plugins do tmux'

# ── Fonte ─────────────────────────────────────────────────────────────────

MSG_FONT_PRESENT='JetBrainsMono Nerd Font já instalada'
MSG_FONT_NO_TAR='tar não encontrado, instale a fonte à mão'
MSG_FONT_DOWNLOADING='baixando JetBrainsMono Nerd Font (~5 MB)'
MSG_FONT_DOWNLOAD_FAILED='download da fonte falhou — instale à mão'
MSG_FONT_EXTRACT_FAILED='extração da fonte falhou'
MSG_FONT_INSTALLED='fonte instalada em %s'

# ── powerlevel10k ─────────────────────────────────────────────────────────

MSG_P10K_NO_TTY='sem terminal interativo, pulando o p10k configure'

# ── Neovim ────────────────────────────────────────────────────────────────

MSG_NVIM_MISSING='nvim não encontrado, pulando os plugins do Neovim'
MSG_NVIM_PLUGINS='plugins do Neovim (lazy.nvim)'

# ── macOS: bundle nunca aberto ────────────────────────────────────────────

msg_first_launch_hint() {
  ui_note 'bundle .app nunca aberto pelo LaunchServices bloqueia os'
  ui_note 'binários de linha de comando dele. Abra uma vez:'
  ui_note "  open -a \"$1\""
  ui_note 'confirme o diálogo do macOS, se aparecer, e rode de novo.'
}

# ── setup.sh ──────────────────────────────────────────────────────────────

msg_setup_usage() {
  echo "Uso: bash scripts/setup.sh [--clean] [--yes]"
  echo
  echo "  --clean    resolve os conflitos que o diagnóstico achar (com backup)"
  echo "  --yes, -y  não pergunta nada; sem --clean, nada existente é movido"
}

MSG_SETUP_UNSUPPORTED='Sistema não suportado por este script: %s'
MSG_SETUP_WINDOWS='No Windows, rode:  .\scripts\setup-windows.ps1'
MSG_SETUP_INTERRUPTED='interrompido — nada foi perdido, rodar de novo é seguro'
MSG_SETUP_RESUMING='seguindo dentro do WezTerm'

MSG_SETUP_STEP_DIAGNOSE='diagnóstico'
MSG_SETUP_STEP_DIAGNOSE_DESC='procura o que já existe aqui e atrapalharia. Não muda nada.'
MSG_SETUP_NO_CONFLICTS='nada conflita'
MSG_SETUP_CONFLICTS='os itens ✖ ficam de fora: o bootstrap nunca sobrescreve config existente'
MSG_SETUP_CLEAN_NOW='resolvendo agora (--clean), com backup em ~/.local/state/termstack/backup/'
MSG_SETUP_YES_NO_CLEAN='--yes sem --clean: seguindo sem resolver, nada será movido'
MSG_SETUP_ASK_RESOLVE='Resolver agora? (move o que atrapalha, com backup antes)'
MSG_SETUP_ASK_CARRY_ON='Seguir sem resolver?'
MSG_SETUP_CANCELLED='cancelado, nada foi alterado'
MSG_SETUP_CANCELLED_NOTE='quando quiser:  bash scripts/setup.sh --clean'

MSG_SETUP_NO_TTY='sem terminal interativo e sem --yes: nada foi instalado'
MSG_SETUP_NO_TTY_NOTE='para automação:  bash scripts/setup.sh --yes'
MSG_SETUP_STEP_INSTALL='instalação'
MSG_SETUP_STEP_INSTALL_DESC='ferramentas, WezTerm, fonte, links, plugins. Minutos numa máquina limpa.'
MSG_SETUP_INSTALLED='instalado'

MSG_SETUP_STEP_TERMINAL='terminal'
MSG_SETUP_STEP_TERMINAL_DESC='daqui em diante é preciso um terminal com a Nerd Font ativa.'
MSG_SETUP_IN_WEZTERM='já estamos dentro do WezTerm'
MSG_SETUP_UNCONFIRMED='não deu para confirmar que este terminal é o WezTerm'
MSG_SETUP_UNCONFIRMED_NOTE='se os ícones abaixo saírem quebrados, é por isso'
MSG_SETUP_NO_WEZTERM='WezTerm não encontrado — seguindo neste terminal'
MSG_SETUP_NO_WEZTERM_NOTE='os glifos podem sair quebrados se a fonte não estiver ativa aqui'
MSG_SETUP_NO_TTY_HERE='sem terminal interativo, seguindo aqui mesmo'
MSG_SETUP_OPENING='abrindo uma janela do WezTerm para seguir por lá'
MSG_SETUP_GUI_FAILED='não deu para abrir o WezTerm — siga por lá à mão:'
MSG_SETUP_GUI_FAILED_NOTE='bash %s/scripts/setup.sh --resumed'
MSG_SETUP_HANDED_OFF='seguindo na janela do WezTerm'
MSG_SETUP_HANDED_OFF_NOTE='esta janela se fecha sozinha quando a instalação terminar lá'
MSG_SETUP_HANDOFF_DONE='instalação concluída na janela do WezTerm — pode fechar este terminal'
MSG_SETUP_HANDOFF_TIMEOUT='30 min sem sinal da janela do WezTerm, encerrando por aqui'
MSG_SETUP_HANDOFF_TIMEOUT_NOTE='se a instalação de lá ainda estiver rodando, ela segue normalmente'

MSG_SETUP_STEP_PROMPT='prompt'
MSG_SETUP_STEP_PROMPT_DESC='ajustando o powerlevel10k à fonte deste terminal.'
MSG_SETUP_P10K_OK='MODE=%s — já combina com a fonte'
MSG_SETUP_P10K_MISMATCH='zsh/p10k.zsh está em MODE=%s com a Nerd Font instalada'
MSG_SETUP_ASK_P10K="Rodar 'p10k configure' agora?"
MSG_SETUP_P10K_DONE='configurado — revise e comite:  git diff zsh/p10k.zsh'
MSG_SETUP_P10K_SKIPPED='pulado — o preflight avisa até isso ser feito'

msg_setup_p10k_why() {
  ui_note 'o assistente do p10k não detecta fontes: ele grava o modo pelas SUAS'
  ui_note 'respostas às perguntas de glifo. Num terminal sem a fonte você'
  ui_note 'responde "não vejo" e ele grava o fallback — aí o cadeado vira ∅ e'
  ui_note 'os jobs viram ≡.'
  ui_note ''
  ui_note 'leva cerca de um minuto e reescreve o zsh/p10k.zsh do REPOSITÓRIO,'
  ui_note 'não o ~/.p10k.zsh: uma resposta só vale para todas as máquinas.'
}

MSG_SETUP_STEP_VERIFY='verificação'
MSG_SETUP_STEP_VERIFY_DESC='confirma que as quatro camadas carregam mesmo.'
MSG_SETUP_DONE_IN='pronto em %sm%ss'
MSG_SETUP_NEXT_STEPS='Próximos passos'
MSG_SETUP_NEXT_SHELL='recarrega o shell, com o mise no PATH'
MSG_SETUP_NEXT_ZELLIJ='aperte Ctrl+Space: o modo na barra vira TMUX'
MSG_SETUP_NEXT_NVIM='o LazyVim instala o resto no primeiro uso'
MSG_SETUP_CHECK_FAILED='a verificação apontou os itens acima'
MSG_SETUP_CHECK_FAILED_NOTE1='quase sempre é config existente que o bootstrap não sobrescreve'
MSG_SETUP_CHECK_FAILED_NOTE2='para ver e resolver:  bash scripts/setup.sh --clean'
MSG_SETUP_NEW_SHELL='abrindo um shell com o ambiente novo…'

# ── preflight.sh ──────────────────────────────────────────────────────────

MSG_PRE_UNKNOWN_ARG='Argumento desconhecido: %s'
MSG_PRE_ONE_OK='1 item em ordem'
MSG_PRE_N_OK='%s itens em ordem'
MSG_PRE_BACKED_UP='backup em %s'
MSG_PRE_FIX_BACKUP='fazer backup de %s'

MSG_PRE_GROUP_DUPS='Ferramentas duplicadas'
MSG_PRE_DUP_TOOL='%s instalado pelo brew E pelo mise'
MSG_PRE_DUP_WINNER='o que está ganhando agora: %s'
MSG_PRE_DUP_STALE='a cópia do brew envelhece e sombreia a do mise'
MSG_PRE_NO_DUPS='nenhuma ferramenta instalada por dois gerenciadores'
MSG_PRE_CASK_BOTH='casks wezterm e wezterm@nightly instalados juntos'
MSG_PRE_CASK_BOTH_NOTE='os dois escrevem em /Applications/WezTerm.app'
MSG_PRE_CASK_STABLE='cask wezterm (estável) instalado — é o build de fevereiro de 2024'
MSG_PRE_CASK_STABLE_NOTE='o Brewfile deste repositório usa wezterm@nightly'

MSG_PRE_GROUP_CONFIG='Configuração existente'
MSG_PRE_CFG_IS_REPO='%s é o próprio repositório'
MSG_PRE_CFG_LINKED='%s já aponta para o repositório'
MSG_PRE_CFG_ELSEWHERE='%s é link para outro lugar: %s'
MSG_PRE_CFG_EXISTS='%s já existe e não é link — o bootstrap não vai sobrescrever'
MSG_PRE_CFG_FREE='%s está livre'
MSG_PRE_CFG_LEGACY='%s existe e perde prioridade para %s'
MSG_PRE_CFG_LEGACY_NOTE='ficaria no disco sem nunca mais ser lido'
MSG_PRE_ZELLIJ_LEGACY='config antiga do Zellij em ~/Library/Application Support'
MSG_PRE_ZELLIJ_LEGACY_NOTE='ignorada enquanto ~/.config/zellij existir, mas confunde na depuração'

MSG_PRE_GROUP_STALE='Estado antigo'
MSG_PRE_NVIM_STATE='estado do Neovim de outra config: %s (%s)'
MSG_PRE_NVIM_STATE_NONE='nenhum estado do Neovim de outra distribuição'
MSG_PRE_TMUX_OLD='plugins antigos em ~/.tmux/plugins (%s) não são mais usados'
MSG_PRE_TMUX_OLD_NOTE='este repositório usa ~/.config/tmux/plugins'
MSG_PRE_TMUX_IN_USE='%s ainda em uso pela config atual, mantido'

MSG_PRE_GROUP_SHELL='Shell'
MSG_PRE_ZDOTDIR='ZDOTDIR=%s — o zsh não lê o ~/.zshrc'
MSG_PRE_ZDOTDIR_NOTE='a config do repositório seria escrita em ~/.zshrc e nunca carregada'
MSG_PRE_OWN_OMZ='%s carrega oh-my-zsh/p10k por conta própria'
MSG_PRE_OWN_OMZ_NOTE1='seriam dois compinit e dois blocos de instant prompt'
MSG_PRE_OWN_OMZ_NOTE2='a migração é manual: a receita está no bloco marcado no fim do seu rc'
MSG_PRE_STARSHIP='starship configurado no ~/.zshrc — briga com o powerlevel10k'
MSG_PRE_P10K_HOME='%s existe e não será mais lido (o repo usa zsh/p10k.zsh)'
MSG_PRE_P10K_HOME_NOTE='confunde na hora de depurar "editei e nada mudou"'
MSG_PRE_COMPINIT='compinit chamado %s vez(es) fora do repositório'
MSG_PRE_NVM='nvm no ~/.zshrc com o mise instalado'
MSG_PRE_NVM_NOTE='dois gerenciadores de Node no PATH, e dar source no nvm domina o startup'
MSG_PRE_NO_ZSHRC='sem ~/.zshrc — máquina limpa, o bootstrap cria'
MSG_PRE_P10K_MODE='zsh/p10k.zsh está em MODE=%s mas a Nerd Font está instalada'
MSG_PRE_P10K_MODE_NOTE="os ícones ficam no fallback; o setup.sh oferece rodar 'p10k configure'"
MSG_PRE_FPATH_OK='nenhum diretório inseguro no fpath'
MSG_PRE_COMPAUDIT='compaudit reclamou das permissões no fpath'
MSG_PRE_COMPAUDIT_NOTE='conserto: compaudit | xargs chmod g-w,o-w'

MSG_PRE_GROUP_ENV='Ambiente'
MSG_PRE_NO_MISE='mise ainda não instalado — o bootstrap instala'
MSG_PRE_MISE_ON_PATH='as ferramentas do mise resolvem no PATH'
MSG_PRE_MISE_INACTIVE='mise instalado mas não ativado neste shell'
# shellcheck disable=SC2016  # $SHELL é literal, para o usuário digitar
MSG_PRE_MISE_INACTIVE_NOTE='as ferramentas existem e ficam fora do PATH até você rodar: exec $SHELL'

MSG_PRE_ALL_CLEAR='Nada a limpar. Pode rodar o bootstrap.'
MSG_PRE_BLOCKER='bloqueio'
MSG_PRE_BLOCKERS='bloqueios'
MSG_PRE_WARNING='aviso'
MSG_PRE_WARNINGS='avisos'
MSG_PRE_GROUP_PLAN='O que o --clean faria'
MSG_PRE_UNAPPLIED='nada foi alterado. Para aplicar:'
MSG_PRE_UNAPPLIED_NOTE='bash scripts/preflight.sh --clean'
MSG_PRE_ASK_APPLY='Aplicar?'
MSG_PRE_CANCELLED='cancelado, nada foi alterado'
MSG_PRE_GROUP_APPLYING='Aplicando'
MSG_PRE_FIX_FAILED='falhou, seguindo'
MSG_PRE_DONE='Pronto. Rode o bootstrap do seu sistema.'

# ── check.sh ──────────────────────────────────────────────────────────────

MSG_CHECK_ONE_OK='1 verificação passou'
MSG_CHECK_N_OK='%s verificações passaram'

MSG_CHECK_LINK_OK='%s -> repositório'
MSG_CHECK_LINK_BAD='%s não aponta para %s'

MSG_CHECK_GROUP_MACHINE='Máquina'
MSG_CHECK_MDM='Mac gerenciado por MDM — as falhas abaixo podem ser política da empresa'
MSG_CHECK_NO_MDM='Mac sem MDM'
MSG_CHECK_MISE_PRESENT='mise presente (%s)'
MSG_CHECK_TOOLS_RESOLVE='ferramentas resolvem'
MSG_CHECK_NO_TOOLS='sem ferramentas'
MSG_CHECK_NO_MISE='mise não encontrado — as CLI vieram de outro lugar'

MSG_CHECK_GROUP_WEZTERM='WezTerm'
MSG_CHECK_WEZTERM_MISSING='wezterm não encontrado, pulando'
MSG_CHECK_WEZTERM_HUNG='wezterm travou (20s sem resposta) — não é a config'
MSG_CHECK_WEZTERM_HUNG_NOTE1='se persistir num Mac gerenciado por MDM, pode ser a política de execução'
MSG_CHECK_WEZTERM_HUNG_NOTE2='da empresa. Confirme com o TI antes de seguir.'
MSG_CHECK_WEZTERM_LOADS='a config carrega (leader ativo)'
MSG_CHECK_WEZTERM_FALLBACK='a config NÃO carrega — caiu na padrão. Rode sem o grep:'
MSG_CHECK_WEZTERM_FALLBACK_NOTE='%s --config-file %s/wezterm.lua show-keys'
MSG_CHECK_BINDING_OK='atalho LEADER -> %s'
MSG_CHECK_BINDING_MISSING='atalho LEADER -> %s faltando'

MSG_CHECK_GROUP_TMUX='tmux'
MSG_CHECK_TMUX_MISSING='tmux não encontrado, pulando'
MSG_CHECK_TMUX_CONF_ERR='tmux.conf reclamou: %s'
MSG_CHECK_TMUX_CONF_OK='tmux.conf carrega sem erro'
MSG_CHECK_TMUX_PREFIX_OK='o prefixo é C-Space'
MSG_CHECK_TMUX_PREFIX_BAD="o prefixo é '%s', esperado 'C-Space'"
MSG_CHECK_TMUX_THEME_OK='catppuccin carregado (paleta @thm_* definida)'
MSG_CHECK_TMUX_THEME_BAD='catppuccin não carregou — rode o bootstrap, ou prefixo + I dentro do tmux'
MSG_CHECK_WIDGET_RAW='o widget %s não foi substituído (o plugin não carregou)'
MSG_CHECK_WIDGET_OK='widget %s ativo'
MSG_CHECK_WIDGET_MISSING='o widget %s não está na barra de status'
MSG_CHECK_TMUX_BASE_OK='base-index é 1'
MSG_CHECK_TMUX_BASE_BAD="a primeira janela tem índice '%s', esperado '1'"

MSG_CHECK_GROUP_ZELLIJ='Zellij'
MSG_CHECK_ZELLIJ_MISSING='zellij não encontrado, pulando'
MSG_CHECK_ZELLIJ_KDL_OK='config.kdl é KDL válido'
MSG_CHECK_ZELLIJ_KDL_BAD='config.kdl inválido: %s'
MSG_CHECK_ZELLIJ_DIR_OK='CONFIG DIR aponta para ~/.config/zellij'
MSG_CHECK_ZELLIJ_DIR_BAD='CONFIG DIR errado: %s'
MSG_CHECK_ZELLIJ_LOCKED_OK='default_mode locked (Ctrl+hjkl livre para o Neovim)'
MSG_CHECK_ZELLIJ_LOCKED_BAD='default_mode não está locked — o Zellij vai roubar Ctrl+hjkl do Neovim'

MSG_CHECK_GROUP_NVIM='Neovim'
MSG_CHECK_NVIM_MISSING='nvim não encontrado, pulando'
MSG_CHECK_NVIM_NAV_BAD='plugin de navegação de multiplexador em nvim/ — veja o DESIGN.md, seção Zellij'
MSG_CHECK_NVIM_NAV_OK='sem plugin de navegação (Ctrl+hjkl chega inteiro do multiplexador)'

MSG_CHECK_GROUP_ZSH='zsh'
MSG_CHECK_OMZ_MISSING='%s não existe ou não é repo git — rode o bootstrap'
MSG_CHECK_OMZ_OK='oh-my-zsh instalado'
MSG_CHECK_PLUGIN_OK='plugin %s'
MSG_CHECK_PLUGIN_BAD='plugin %s faltando ou com o nome de arquivo errado'
MSG_CHECK_P10K_CLONED='powerlevel10k clonado'
MSG_CHECK_P10K_MISSING='powerlevel10k faltando'
MSG_CHECK_HL_LAST_OK='zsh-syntax-highlighting é o último do array'
MSG_CHECK_HL_LAST_BAD="o último plugin é '%s' — o syntax-highlighting tem que ser o último"
MSG_CHECK_ZSH_MISSING='zsh não encontrado, pulando'
MSG_CHECK_ZSH_HUNG='zsh -i travou (25s) — a config do repositório está presa'
MSG_CHECK_OMZ_COMPLAINED='o omz reclamou: %s'
MSG_CHECK_THEME_OK='ZSH_THEME é powerlevel10k'
MSG_CHECK_THEME_BAD='ZSH_THEME errado, ou o omz não carregou'
MSG_CHECK_P10K_LOADED='powerlevel10k carregado'
MSG_CHECK_P10K_NOT_LOADED='powerlevel10k não carregou'
MSG_CHECK_HL_OK='syntax-highlighting ativo'
MSG_CHECK_HL_BAD='syntax-highlighting não carregou'
MSG_CHECK_CATPPUCCIN_OK='catppuccin aplicado (os overrides ganharam)'
MSG_CHECK_CATPPUCCIN_BAD='catppuccin não aplicado: %s'

MSG_CHECK_GROUP_REPO='Repositório'
MSG_CHECK_CUSTOM_IGNORED='zsh/custom ignorado pelo git'
MSG_CHECK_CUSTOM_NOT_IGNORED='zsh/custom NÃO ignorado — clones de terceiros entrariam no repositório'
MSG_CHECK_MACHINE_IGNORED='machine.lua ignorado pelo git'
MSG_CHECK_MACHINE_NOT_IGNORED='machine.lua NÃO ignorado — risco de vazar config local'
MSG_CHECK_MACHINE_TRACKED='machine.lua está versionado no git — remova com: git rm --cached machine.lua'
MSG_CHECK_MACHINE_UNTRACKED='machine.lua não está versionado'
MSG_CHECK_LOCK_ABSENT='%s ainda não existe (criado no primeiro uso do Neovim)'
MSG_CHECK_LOCK_TRACKED='%s versionado no git'
MSG_CHECK_LOCK_UNTRACKED='%s NÃO versionado — as máquinas vão divergir. git add %s'

MSG_CHECK_ALL_GOOD='Tudo certo.'
MSG_CHECK_ONE_FAILED='1 verificação falhou.'
MSG_CHECK_N_FAILED='%s verificações falharam.'

# ── update.sh ─────────────────────────────────────────────────────────────

MSG_UPD_NO_SNAPSHOT='não há snapshot de update para restaurar'
MSG_UPD_GROUP_ROLLBACK='Rollback'
MSG_UPD_RESTORING='restaurando %s'
MSG_UPD_REPO_RESET='repositório → %s'
MSG_UPD_DIRTY='árvore com modificações: o repositório NÃO foi revertido'
MSG_UPD_DIRTY_NOTE='seus arquivos modificados ficaram como estavam. À mão:'
MSG_UPD_DIRTY_CMD='git -C "%s" stash && git -C "%s" reset --hard %s'
MSG_UPD_MACHINE_RESTORED='machine.lua restaurado'
MSG_UPD_NVIM_RESTORED='nvim/%s restaurado'

msg_upd_versions_note() {
  ui_note ''
  ui_note 'as versões das ferramentas NÃO voltam sozinhas:'
  ui_note 'um downgrade custa download e raramente é a causa. Se precisar'
  ui_note 'delas, as versões anteriores estão em:'
  ui_note "$1"
}

MSG_UPD_GROUP_SNAPSHOT='Snapshot'
MSG_UPD_SNAPSHOT_AT='snapshot em %s'

MSG_UPD_GROUP_REPO='Repositório'
MSG_UPD_PULL='git pull'
MSG_UPD_UP_TO_DATE='já está atualizado'
MSG_UPD_PULLED='%s → %s'
MSG_UPD_OFFLINE='offline: pulando todo passo de rede'

MSG_UPD_GROUP_LINKS='Links de configuração'

MSG_UPD_GROUP_TOOLS='Ferramentas'
MSG_UPD_MISE_UPGRADE='mise upgrade'
MSG_UPD_BREW='Homebrew'

MSG_UPD_GROUP_PLUGINS='Plugins'
MSG_UPD_ZSH_REPOS='oh-my-zsh, powerlevel10k e os plugins do zsh'
MSG_UPD_ZSH_FAILED='um repositório do zsh falhou'
MSG_UPD_NVIM_UNCHANGED='nvim/ sem mudanças, pulando os plugins do Neovim'

MSG_UPD_CHECK_FAILED='A verificação falhou depois do update.'
MSG_UPD_ROLLING_BACK='voltando para o snapshot.'
MSG_UPD_GROUP_AFTER='Estado depois do rollback'
MSG_UPD_RESTORED='Ambiente restaurado. O que veio no pull ficou de fora.'
MSG_UPD_SNAPSHOT_KEPT='snapshot mantido em: %s'
MSG_UPD_ROLLBACK_NOOP='O rollback não resolveu — a falha é anterior ao update.'
MSG_UPD_SNAPSHOT_STILL='snapshot em: %s'

# ── bootstrap-macos.sh ────────────────────────────────────────────────────

MSG_BOOT_NOT_MACOS='Este script tem que rodar no macOS.'

MSG_BOOT_GROUP_BEFORE='Antes de começar'
MSG_BOOT_ENTRY_POINT='o ponto de entrada é o setup.sh — ele pergunta antes de mexer no que'
MSG_BOOT_ENTRY_POINT_NOTE='já existe, e ajusta o prompt no fim:'
MSG_BOOT_ENTRY_POINT_CMD='bash "%s/scripts/setup.sh"'
MSG_BOOT_PREFLIGHT_FIX='para resolver os itens acima antes de instalar:'
MSG_BOOT_PREFLIGHT_FIX_CMD='bash "%s/scripts/preflight.sh" --clean'
MSG_BOOT_CARRY_ON='seguindo com o bootstrap — nada que já existe é sobrescrito.'

MSG_BOOT_GROUP_CLI='Ferramentas de linha de comando'

MSG_BOOT_GROUP_WEZTERM='WezTerm e fonte'
MSG_BOOT_BREW_BUNDLE='brew bundle (WezTerm nightly + JetBrainsMono Nerd Font)'
MSG_BOOT_OPEN_ONCE='abrindo o WezTerm uma vez (registra o bundle no LaunchServices)'
MSG_BOOT_NO_BREW='Homebrew não encontrado — o WezTerm tem que ser baixado à mão'

msg_boot_no_brew_hint() {
  ui_note 'as CLI e a fonte já foram instaladas sem ele.'
  ui_note 'WezTerm nightly (sem sudo, descompacte em ~/Applications):'
  ui_note '  https://github.com/wezterm/wezterm/releases/tag/nightly'
  ui_note '  arquivo WezTerm-macos-nightly.zip'
}

MSG_BOOT_GROUP_LINKS='Links de configuração'

MSG_BOOT_GROUP_PLUGINS='Plugins'
MSG_BOOT_ZSH_REPOS='oh-my-zsh, powerlevel10k e os plugins do zsh'
MSG_BOOT_ZSH_FAILED='um repositório do zsh falhou'

MSG_BOOT_GROUP_DONE='Pronto'

msg_boot_done() {
  ui_note "reabra o shell (ou: exec \$SHELL) para o mise entrar no PATH."
  ui_note ''
  ui_note 'um teste manual que não dá para automatizar: abra o Zellij e aperte'
  ui_note 'Ctrl+Space. O indicador de modo na barra tem que virar TMUX. Se não'
  ui_note 'virar, seu terminal não distingue essa combinação — troque o bind em'
  ui_note 'zellij/config.kdl (o padrão do próprio Zellij é Ctrl+b).'
  ui_note ''
  ui_note 'verifique tudo com:'
  ui_note "bash \"$1/scripts/check.sh\""
}

# ── bootstrap-linux.sh ────────────────────────────────────────────────────

MSG_BOOT_NOT_LINUX='Este script tem que rodar no Linux.'

MSG_BOOT_WSL_SKIP='WSL detectado: pulando WezTerm e fonte (use os do Windows)'
MSG_BOOT_WEZTERM_PRESENT='WezTerm já instalado (%s)'
MSG_BOOT_PACMAN='instalando WezTerm pelo pacman'
MSG_BOOT_PACMAN_NOTE='para o nightly: paru -S wezterm-git'
MSG_BOOT_APT='instalando WezTerm pelo repositório apt oficial'
MSG_BOOT_COPR='instalando WezTerm pelo copr (nightly)'
MSG_BOOT_ZYPPER='instalando WezTerm pelo zypper'
MSG_BOOT_NO_DISTRO='distribuição não reconhecida para instalar o WezTerm'
MSG_BOOT_APPIMAGE='AppImage: https://github.com/wezterm/wezterm/releases'

msg_boot_linux_done() {
  ui_note "reabra o shell (ou: exec \$SHELL) para o mise entrar no PATH."
  ui_note ''
  ui_note 'um teste manual que não dá para automatizar: abra o Zellij e aperte'
  ui_note 'Ctrl+Space. O indicador de modo na barra tem que virar TMUX.'
  ui_note ''
  ui_note 'verifique tudo com:'
  ui_note "bash \"$1/scripts/check.sh\""
}

# ── A colinha ─────────────────────────────────────────────────────────────
#
# Teto de 78 colunas de texto VISÍVEL — há teste garantindo. Em português as
# palavras são mais longas, então é aqui que o limite costuma estourar.

msg_cheatsheet() {
  local b=$UI_B c=$UI_AZ d=$UI_DIM r=$UI_R rule
  rule="$(printf '%*s' 74 '' | tr ' ' '─')"

  cat <<TXT

  ${c}${rule}${r}
  ${b}A stack em quatro camadas${r}
  WezTerm ${b}Ctrl+a${r}   Zellij ${b}Ctrl+Space${r}   tmux ${d}idem (reserva)${r}   LazyVim ${b}Espaço${r}
  ${d}Ctrl+h/j/k/l é do Neovim, sempre — por isso o Zellij nasce travado.${r}
  ${c}${rule}${r}

  ${b}Prefixo e depois${r} ${d}— WezTerm e Zellij, mesmas teclas${r}
    ${b}|${r} ${b}-${r} divide   ${b}h j k l${r} navega   ${b}x${r} fecha   ${b}z${r} zoom   ${b}c n p${r} abas   ${b}[${r} copy
    ${d}só WezTerm${r}  ${b}H J K L${r} redimensiona   ${b}1${r}…${b}9${r} aba N   ${b}espaço${r} launcher
                ${b}Ctrl+a${r} de novo manda Ctrl+a literal para o shell
    ${d}só Zellij${r}   ${b}f${r} flutuante   ${b}s${r} sessões   ${b}w${r} gerenciador   ${b}Esc${r} trava
                ${b}espaço${r} cicla layout ${d}(vertical / horizontal / empilhado)${r}
                ${d}zj -n dev abre nvim+terminal · zj attach NOME · zj ls${r}

  ${b}LazyVim — Espaço e depois${r}
    ${b}espaço${r} arquivo   ${b}/${r} grep   ${b},${r} buffers   ${b}e${r} árvore   ${b}f r${r} recentes
    ${b}g g${r} lazygit   ${b}b b${r} buffer anterior   ${b}c d${r} diagnóstico   ${b}q q${r} sai
    ${b}|${r} ${b}-${r} divide a janela   ${b}Ctrl+h/j/k/l${r} janelas   ${b}Ctrl+/${r} terminal   ${b}l${r} :Lazy
    ${d}:LazyExtras liga e desliga extras   :LazyHealth diagnóstico${r}

  ${b}Shell${r}
    ${b}v${r} nvim   ${b}lg${r} lazygit   ${b}zj${r} zellij   ${b}z DIR${r} salta ${d}(zoxide)${r}   ${b}gst ga gcm gp${r} ${d}git${r}
    ${b}Ctrl+R${r} histórico fuzzy   ${b}Ctrl+T${r} arquivo   ${b}↑ ↓${r} prefixo   ${b}→${r} aceita sugestão

  ${b}Esqueceu uma tecla?${r}
    ${b}Ctrl+a ?${r} ${d}ou${r} ${b}Ctrl+Space ?${r}   esta colinha ${d}(fecha com qualquer tecla)${r}
    ${b}Ctrl+Shift+P${r} palette do WezTerm ${d}(busca)${r}   ${b}prefixo ?${r} teclas do tmux
    ${b}Espaço${r} e espere: which-key do LazyVim ${d}— os três leem a config viva${r}

  ${b}Manutenção${r} ${d}— ajustes locais fora do git: machine.lua, ~/.zshrc.local${r}
    ${b}setup.sh${r} instala ${d}(--clean resolve)${r}   ${b}update.sh${r} snapshot + rollback
    ${b}check.sh${r} confere as camadas   ${b}preflight.sh${r} conflitos   ${b}stack${r} repete

TXT
}
