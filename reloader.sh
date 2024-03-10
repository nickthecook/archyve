#!/bin/bash
# htmlreload
# When an HTML or CSS file changes, reload any visible browser windows.
# Usage:
# 
#     htmlreload [ --browsername ] [ files ... ]
#
# If no files to watch are specified, all files (recursively) in the
# current working directory are monitored. (Note: this can take a long
# time to initially setup if you have a lot of files).
#
# An argument that begins with a dash is the browser to control.
# `htmlreload --chrom` will match both Chromium and Chrome.

set -o errexit
set -o nounset

browser="firefox"      # Default browser name. (Technically "X11 Class")
keystroke="CTRL+R"    # The key that tells the browser to reload.

sendkey() {
    echo "Sending $2 to $1..."
    # Given an application name and a keystroke,
    # type the key in all windows owned by that application.
    xdotool search --all --onlyvisible --class "$1" \
        key --window %@ "$2"
}

# You may specify the browser name after one or more dashes (e.g., --chromium)
if [[ "${1:-}" == -* ]]; then
    browser="${1##*-}"
    shift
fi

# If no filenames given to watch, watch current working directory.
if [[ $# -eq 0 ]]; then
    echo "Watching all files under `pwd`"
    set - --recursive "`pwd`" #Added quotes for whitespace in path
fi

inotifywait --monitor --event CLOSE_WRITE "$@" | while read; do
    echo "$REPLY"
    sendkey $browser $keystroke
done
