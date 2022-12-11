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
ZSH="${ZSH:-$HOME/.oh-my-zsh}"
ZSH_CUSTOM="${ZSH_CUSTOM:-$ZSH/custom}"
SPYRHOO="${SPYRHOO:-$HOME/.spyrhoo-zsh-theme}"

read -r -p "Are you sure you want to remove Spyrhoo Zsh Theme? [Y/n] " confirmation
if [ "$confirmation" != y ] && [ "$confirmation" != Y ]; then
  echo "Uninstall cancelled"
  exit
fi

if test -f "$ZSH_CUSTOM/themes/spyrhoo.zsh-theme"; then
  rm -rf "$ZSH_CUSTOM/themes/spyrhoo.zsh-theme" >/dev/null 2>&1 || rm -rf "$ZSH_CUSTOM/themes/spyrhoo.zsh-theme" >/dev/null 2>&1
fi
if test -d "$SPYRHOO" && test -w "$SPYRHOO" && test -x "$SPYRHOO"; then
  rm -rf "$SPYRHOO" >/dev/null 2>&1 || rm rf "$SPYRHOO" >/dev/null 2>&1
fi

echo "Thanks for trying out Spyrhoo Zsh Theme. It's been uninstalled."

exit
