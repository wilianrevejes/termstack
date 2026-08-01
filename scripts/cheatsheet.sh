#!/usr/bin/env bash
#
# Prints the key and command cheatsheet for the stack. Shown at the end of
# setup.sh, on every new WezTerm shell (zsh/zshrc), on LEADER ? and
# Ctrl+Space ?, and any time you type `stack`.
#
# The text itself is not here: it lives in i18n/<lang>.sh as msg_cheatsheet,
# so translating it never means touching a script.

set -uo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Brings in the UI_* palette and the message catalog for the active language.
# shellcheck source-path=SCRIPTDIR source=_common.sh
source "$repo_dir/scripts/_common.sh"

msg_cheatsheet
