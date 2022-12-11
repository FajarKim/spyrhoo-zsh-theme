#!/bin/bash
#
# Make sure important variables exist if not already defined
#
# $USER is defined by login(1) which is not always executed (e.g. containers)
# POSIX: https://pubs.opengroup.org/onlinepubs/009695299/utilities/id.html
USER=${USER:-$(id -u -n)}
# $HOME is defined at the time of login, but it could be unset. If it is unset,
# a tilde by itself (~) will not be expanded to the current user's home directory.
# POSIX: https://pubs.opengroup.org/onlinepubs/009696899/basedefs/xbd_chap08.html#tag_08_03
HOME="${HOME:-$(getent passwd $USER 2>/dev/null | cut -d: -f6)}"
# macOS does not have getent, but this works even if $HOME is unset
HOME="${HOME:-$(eval echo ~$USER)}"

# Default settings
SPYRHOO="${SPYRHOO:-$HOME/.spyrhoo-zsh-theme}"

# The test -t 1 check only works when the function is not called from
# a subshell (like in `$(...)` or `(...)`, so this hack redefines the
# function at the top level to always return false when stdout is not
# a tty.
if test -t 1; then
  is_tty() {
    true
  }
else
  is_tty() {
    false
  }
fi

# This function uses the logic from supports-hyperlinks[1][2], which is
# made by Kat Marchán (@zkat) and licensed under the Apache License 2.0.
# [1] https://github.com/zkat/supports-hyperlinks
# [2] https://crates.io/crates/supports-hyperlinks
#
# Copyright (c) 2021 Kat Marchán
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
supports_hyperlinks() {
  # $FORCE_HYPERLINK must be set and be non-zero (this acts as a logic bypass)
  if test -n "$FORCE_HYPERLINK"; then
    [ "$FORCE_HYPERLINK" != 0 ]
    return $?
  fi

  # If stdout is not a tty, it doesn't support hyperlinks
  is_tty || return 1

  # DomTerm terminal emulator (domterm.org)
  if test -n "$DOMTERM"; then
    return 0
  fi

  # VTE-based terminals above v0.50 (Gnome Terminal, Guake, ROXTerm, etc)
  if test -n "$VTE_VERSION"; then
    [ $VTE_VERSION -ge 5000 ]
    return $?
  fi

  # If $TERM_PROGRAM is set, these terminals support hyperlinks
  case "$TERM_PROGRAM" in
  Hyper|iTerm.app|terminology|WezTerm) return 0 ;;
  esac

  # kitty supports hyperlinks
  if [ "$TERM" = xterm-kitty ]; then
    return 0
  fi

  # Windows Terminal also supports hyperlinks
  if test -n "$WT_SESSION"; then
    return 0
  fi

  # Konsole supports hyperlinks, but it's an opt-in setting that can't be detected
  # if test -n "$KONSOLE_VERSION"; then
  #   return 0
  # fi

  return 1
}

setup_color() {
  # Only use colors if connected to a terminal
  if ! is_tty; then
    BOLD=""
    RESET=""
    return
  fi

  BOLD=$(printf '\033[1m')
  RESET=$(printf '\033[m')
}

fmt_link() {
  # $1: text, $2: url, $3: fallback mode
  if supports_hyperlinks; then
    printf '\033]8;;%s\033\\%s\033]8;;\033\\\n' "$2" "$1"
    return
  fi

  case "$3" in
  --text) printf '%s\n' "$1" ;;
  --url|*) fmt_underline "$2" ;;
  esac
}

fmt_underline() {
  is_tty && printf '\033[4m%s\033[24m\033[1m' "$*" || printf '%s\n' "$*"
}

_spy_run_upgrade() {
  # Update upstream remote to spyrhoo-zsh-theme org
  git remote -v | while read remote url extra; do
    case "$url" in
    https://github.com/FajarKim/spyrhoo-zsh-theme | https://github.com/FajarKim/spyrhoo-zsh-theme.git)
      git remote set-url "$remote" "https://github.com/FajarKim/spyrhoo-zsh-theme.git"
      break ;;
    git@github.com:FajarKim/spyrhoo-zsh-theme | git@github.com:FajarKim/spyrhoo-zsh-theme.git)
      git remote set-url "$remote" "git@github.com:FajarKim/spyrhoo-zsh-theme.git"
      break ;;
    # Update out-of-date "unauthenticated git protocol on port 9418" to https
    git://github.com/FajarKim/spyrhoo-zsh-theme | git://github.com/FajarKim/spyrhoo-zsh-theme.git)
      git remote set-url "$remote" "https://github.com/FajarKim/spyrhoo-zsh-theme.git"
      break ;;
    esac
  done

  # Set git-config values known to fix git errors
  # Line endings (#4069)
  git config core.eol lf
  git config core.autocrlf false
  # zeroPaddedFilemode fsck errors (#4963)
  git config fsck.zeroPaddedFilemode ignore
  git config fetch.fsck.zeroPaddedFilemode ignore
  git config receive.fsck.zeroPaddedFilemode ignore
  # autostash on rebase (#7172)
  resetAutoStash=$(git config --bool rebase.autoStash 2>/dev/null)
  git config rebase.autoStash true

  local ret=0

  # repository settings
  remote_repo="$(git config --local spyrhoo-zsh-theme.remote)"
  branch_repo="$(git config --local spyrhoo-zsh-theme.branch)"
  remote=${remote_repo:-origin}
  branch=${branch_repo:-master}

  # repository state
  last_head=$(git symbolic-ref --quiet --short HEAD || git rev-parse HEAD)
  # checkout update branch
  git checkout -q "$branch" -- || exit 1
  # branch commit before update (used in changelog)
  last_commit=$(git rev-parse "$branch")

  # Update spyrhoo-zsh-theme
  echo "Updating Spyrhoo Zsh Theme..."
  if LANG= git pull --quiet --rebase $remote $branch; then
    # Check if it was really updated or not
    if test "$(git rev-parse HEAD)" = "$last_commit"; then
      echo "Spyrhoo Zsh Theme is already at the latest version."
      exit
    else
      message="Hooray! Spyrhoo Zsh Theme has been updated!"
      # Save the commit prior to updating
      git config spyrhoo-zsh-theme.lastVersion "$last_commit"
    fi
  fi
  print_success
}

print_success() {
  printf '%s\n' "${BOLD}                             __"
  printf '%s\n' '      _________  __  _______/ /_  ____  ____'
  printf '%s\n' '     / ___/ __ \/ / / / ___/ __ \/ __ \/ __ \'
  printf '%s\n' '    (__  ) /_/ / /_/ / /  / / / / /_/ / /_/ /'
  printf '%s\n' '   /____/ .___/\__, /_/  /_/ /_/\____/\____/ ZSH THEME'
  printf '%s\n' '       /_/    /____/'
  printf >&2 '%s\n' "Contact me in:"
  printf >&2 '%s\n' "• Facebook : $(fmt_link 파자르김 https://bit.ly/facebook-fajarkim)"
  printf >&2 '%s\n' "• Instagram: $(fmt_link @fajarkim_ https://instagram.com/fajarkim_)"
  printf >&2 '%s\n' "• Twitter  : $(fmt_link @fajarkim_ https://twitter.com/fajarkim_)"
  printf >&2 '%s\n' "• Telegram : $(fmt_link @FajarThea https://t.me/FajarThea)"
  printf >&2 '%s\n' "• WhatsApp : $(fmt_link +6285659850910 https://bit.ly/whatsapp-fajarkim)"
  printf >&2 '%s\n' "• E-mail   : fajarrkim@gmail.com${RESET}"
}

main() {
  setup_color
  if test -d "$SPYRHOO" && test -w "$SPYRHOO" && test -x "$SPYRHOO"; then
    cd "$SPYRHOO"
    _spy_run_upgrade
  else
    _spy_run_upgrade
  fi
  cd - >/dev/null 2>&1
}

main $@
