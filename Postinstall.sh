#!/bin/sh
set -eu
umask 077
fail() { printf 'Tilde: %s\n' "$*" >&2; exit 1; }
valid_name() {
    case "$1" in ''|.|..|-*|*[!A-Za-z0-9._-]*) return 1 ;; *) return 0 ;; esac
}
[ "$(/usr/bin/id -u)" = 0 ] || fail 'Installer must authorize this package as administrator.'
volume=${3:-/}
case "$volume" in /*) ;; *) fail 'The target volume must be an absolute path.' ;; esac
while [ "$volume" != / ] && [ "${volume%/}" != "$volume" ]; do volume=${volume%/}; done
scratch_root=${INSTALLER_TEMP:-"${volume%/}/private/tmp"}
case "$scratch_root" in /*) ;; *) fail 'The installer scratch path must be absolute.' ;; esac
while [ "$scratch_root" != / ] && [ "${scratch_root%/}" != "$scratch_root" ]; do scratch_root=${scratch_root%/}; done
state_directory="${scratch_root%/}/com.meansandmeasures.Tilde-editor"
state_file=$state_directory/pending.plist
[ ! -L "$state_directory" ] && [ -d "$state_directory" ] || fail 'The installation-state directory is unavailable.'
[ "$(/usr/bin/stat -f %u "$state_directory")" = 0 ] || fail 'The installation-state directory must belong to root.'
cleanup() {
    status=$?
    trap - EXIT HUP INT TERM
    set +e
    /bin/rm -f "$state_file" || status=1
    /bin/rmdir "$state_directory" || status=1
    exit "$status"
}
trap cleanup EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM
[ ! -L "$state_file" ] && [ -f "$state_file" ] || fail 'Preinstall did not record the installation choices.'
[ "$(/usr/bin/stat -f %u "$state_file")" = 0 ] || fail 'The installation choices must belong to root.'
read_value() { /usr/bin/plutil -extract "$1" raw -expect string -o - "$state_file"; }
[ "$(read_value TargetVolume)" = "$volume" ] || fail 'The recorded target volume does not match this installation.'
application_path=$(read_value ApplicationPath)
editor_path=$(read_value EditorPath)
command_directory=$(read_value CommandDirectory)
command_name=$(read_value CommandName)
[ "$application_path" = /Applications/Tilde.app ] || fail 'Unexpected application destination.'
[ "$editor_path" = "$application_path/Contents/Helpers/tilde" ] || fail 'Unexpected editor destination.'
[ "$command_directory" = /usr/local/bin ] || fail 'Unexpected command destination.'
valid_name "$command_name" || fail 'The recorded command name is invalid.'
[ -f "${volume%/}$editor_path" ] && [ -x "${volume%/}$editor_path" ] || fail 'The app payload did not install an executable editor.'
/bin/mkdir -p "${volume%/}$command_directory"
# symlink(2) atomically claims exactly this pathname and never replaces it.
base_name=$command_name
number=1
while :; do
    command_path="${volume%/}$command_directory/$command_name"
    if [ -L "$command_path" ] && [ "$(/usr/bin/readlink "$command_path")" = "$editor_path" ]; then break; fi
    if [ ! -e "$command_path" ] && [ ! -L "$command_path" ]; then
        if /usr/bin/perl -e 'symlink $ARGV[0], $ARGV[1] or exit 1' "$editor_path" "$command_path"; then break; fi
        if [ ! -e "$command_path" ] && [ ! -L "$command_path" ]; then
            fail "Cannot create the command shortcut: $command_path"
        fi
    fi
    number=$((number + 1))
    [ "$number" -le 1000 ] || fail 'No available command name was found.'
    command_name=$base_name-$number
done
printf 'Tilde installed. Command: %s/%s\n' "$command_directory" "$command_name"
exit 0
