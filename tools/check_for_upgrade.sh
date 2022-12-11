#!/bin/zsh
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

function _spy_upgrade_current_epoch {
  local sec=${EPOCHSECONDS-}
  test $sec || printf -v sec '%(%s)T' -1 2>/dev/null || sec=$(command date +%s)
  echo $((sec / 60 / 60 / 24))
}

function _spy_upgrade_update_timestamp {
  echo "LAST_EPOCH=$(_spy_upgrade_current_epoch)" > $SPYRHOO/.cache/.lock-update
}

function _spy_upgrade_check {
  if test ! -f $SPYRHOO/.cache/.lock-update; then
    # create $SPYRHOO/.cache/.lock-update
    _spy_upgrade_update_timestamp
    return 0
  fi

  local LAST_EPOCH
  . $SPYRHOO/.cache/.lock-update
  if test ! $LAST_EPOCH; then
    _spy_upgrade_update_timestamp
    return 0
  fi

  # Default to the old behavior
  local epoch_expires=${UPDATE_SPYRHOO_DAYS:-30}
  local epoch_elapsed=$(($(_spy_upgrade_current_epoch) - LAST_EPOCH))
  if ((epoch_elapsed <= epoch_expires)); then
    return 0
  fi

  # update $SPYRHOO/.cache/.lock-update
  _spy_upgrade_update_timestamp
  if [ $DISABLE_UPDATE_PROMPT == true ] ||
       { read -p '[Spyrhoo] Would you like to check for updates? [Y/n]: ' line &&
           [ $line == Y* || $line == y* || ! $line ]; }
  then
    source "$SPYRHOO"/tools/upgrade.sh
  fi
}

# Cancel upgrade if the current user doesn't have write permissions for the
# spyrhoo-zsh-theme directory.
test -w "$SPYRHOO" || return 0

# Cancel upgrade if git is unavailable on the system
type -P git &>/dev/null || return 0

# You can change the settings by creating another file in
# the '.cache' directory with the file name 'update-prompt'.
# Then fill the file with text:
#   DISABLE_UPDATE_PROMPT=true
# or
#   DISABLE_UPDATE_PROMPT=false
#
local DISABLE_UPDATE_PROMPT
test ! -f $SPYRHOO/.cache/update-prompt || . $SPYRHOO/.cache/update-prompt
if test ! $DISABLE_UPDATE_PROMPT; then
  DISABLE_UPDATE_PROMPT=false
fi

if command mkdir "$SPYRHOO/.cache/update.lock" 2>/dev/null; then
  _spy_upgrade_check
  command rmdir "$SPYRHOO"/.cache/update.lock
fi
