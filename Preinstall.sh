#!/bin/sh
# Installer authorizes this package before running its scripts as root.
set -eu
umask 077
fail() { printf 'Tilde: %s\n' "$*" >&2; exit 1; }
log() { printf 'Tilde: %s\n' "$*"; }
valid_name() {
    case "$1" in
        ''|.|..|-*|*[!A-Za-z0-9._-]*) return 1 ;;
        *) return 0 ;;
    esac
}
[ "$(/usr/bin/id -u)" = 0 ] || fail 'Installer must authorize this package as administrator.'
volume=${3:-/}
case "$volume" in /*) ;; *) fail 'The target volume must be an absolute path.' ;; esac
while [ "$volume" != / ] && [ "${volume%/}" != "$volume" ]; do volume=${volume%/}; done
[ -d "$volume" ] || fail "The target volume is unavailable: $volume"
application_path=/Applications/Tilde.app
version=1.0.0
editor_path=$application_path/Contents/Helpers/tilde
command_directory=/usr/local/bin
scratch_root=${INSTALLER_TEMP:-"${volume%/}/private/tmp"}
case "$scratch_root" in /*) ;; *) fail 'The installer scratch path must be absolute.' ;; esac
while [ "$scratch_root" != / ] && [ "${scratch_root%/}" != "$scratch_root" ]; do scratch_root=${scratch_root%/}; done
[ -d "$scratch_root" ] || fail "The installer scratch directory is unavailable: $scratch_root"
state_directory="${scratch_root%/}/com.meansandmeasures.Tilde-editor"
state_file=$state_directory/pending.plist
if [ ! -e "$state_directory" ] && [ ! -L "$state_directory" ]; then
    /bin/mkdir -m 700 "$state_directory"
fi
[ ! -L "$state_directory" ] && [ -d "$state_directory" ] || fail 'The installation-state path is not a regular directory.'
[ "$(/usr/bin/stat -f %u "$state_directory")" = 0 ] || fail 'The installation-state directory must belong to root.'
/bin/chmod 700 "$state_directory"
temporary=
handoff_ready=0
cleanup() {
    status=$?
    trap - EXIT HUP INT TERM
    set +e
    if [ -n "$temporary" ]; then
        /bin/rm -f "$temporary" || status=1
    fi
    if [ "$status" -ne 0 ] || [ "$handoff_ready" != 1 ]; then
        /bin/rm -f "$state_file" || status=1
        /bin/rmdir "$state_directory" || status=1
    fi
    exit "$status"
}
trap cleanup EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM
# A prior fallback run may have stopped after preinstall, before postinstall.
# Remove only this package's known handoff files, never an arbitrary directory tree.
/bin/rm -f "$state_file"
for stale in "$state_directory"/.pending.*; do
    if [ -f "$stale" ] || [ -L "$stale" ]; then /bin/rm -f "$stale"; fi
done
available() {
    candidate="${volume%/}$command_directory/$1"
    if [ -L "$candidate" ]; then
        [ "$(/usr/bin/readlink "$candidate")" = "$editor_path" ]
    else
        [ ! -e "$candidate" ]
    fi
}
choose_available() {
    if available "$1"; then command_name=$1; return; fi
    fallback=tilde-editor-$version
    number=1
    while ! available "$fallback"; do
        number=$((number + 1))
        [ "$number" -le 1000 ] || fail 'No available command name was found.'
        fallback=tilde-editor-$version-$number
    done
    command_name=$fallback
}
requested_name=${TILDE_COMMAND_NAME:-tilde}
if ! valid_name "$requested_name"; then
    log 'The supplied command name is invalid; using the default name selection.'
    requested_name=tilde
fi
choose_available "$requested_name"
# Only positive evidence of a graphical invocation enables a prompt.
# COMMAND_LINE_INSTALL is set by Apple's command-line installer.
# A deployment wrapper may explicitly request headless or GUI behavior.
interaction=${TILDE_INSTALL_MODE:-auto}
case "$interaction" in auto|gui|headless) ;; *) interaction=headless ;; esac
if [ -n "${COMMAND_LINE_INSTALL:-}" ]; then interaction=headless; fi
if [ "$interaction" = auto ]; then
    interaction=headless
    ancestor=$PPID
    while [ "$ancestor" -gt 1 ]; do
        executable=$(/bin/ps -p "$ancestor" -o comm=) || break
        case "$executable" in
            */Installer.app/Contents/MacOS/Installer) interaction=gui; break ;;
            */installer) break ;;
        esac
        ancestor=$(/bin/ps -p "$ancestor" -o ppid= | /usr/bin/tr -d ' ') || break
        case "$ancestor" in ''|*[!0-9]*) break ;; esac
    done
fi
if [ "$command_name" != "$requested_name" ] && [ "$interaction" = gui ]; then
    console_user=$(/usr/bin/stat -f %Su /dev/console)
    case "$console_user" in root|loginwindow|_mbsetupuser|'') interaction=headless ;; esac
    if [ "$interaction" = gui ]; then
        console_uid=$(/usr/bin/id -u "$console_user")
        if selection=$(/bin/launchctl asuser "$console_uid" /usr/bin/sudo -n -u "$console_user" \
            /usr/bin/osascript - "$requested_name" "$command_name" <<'APPLESCRIPT'
on run arguments
    set occupiedName to item 1 of arguments
    set suggestedName to item 2 of arguments
    try
        set reply to display dialog "The command “" & occupiedName & "” is already in use. Choose a name for Tilde’s command. The existing command will remain unchanged." default answer suggestedName buttons {"Cancel Installation", "Continue"} default button "Continue" cancel button "Cancel Installation" with title "Install Tilde" with icon note giving up after 30
        if gave up of reply then return "DEFAULT"
        return "NAME:" & text returned of reply
    on error number -128
        return "CANCEL"