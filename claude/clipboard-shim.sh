#!/bin/sh
# xclip / wl-paste stand-in for the sandbox. osc52pty (osc52pty/) saves the host
# clipboard image to the mounted dir on each Ctrl+V; this serves it to the
# agent's image paste. Only image reads are supported; everything else fails
# so callers fall back to their other clipboard paths.
IMAGE=/run/host-clipboard/clip.png

target= out= list=
while [ $# -gt 0 ]; do
    case "$1" in
    -t|-target|--type) target=$2; shift ;;
    -o|-out) out=1 ;;
    -l|--list-types) list=1 ;;
    esac
    shift
done

# xclip without -o is a copy.
if [ "$(basename "$0")" = xclip ] && [ -z "$out" ]; then
    echo "xclip: copying is not supported in the sandbox" >&2
    exit 1
fi
[ "$target" = TARGETS ] && list=1

[ -f "$IMAGE" ] || exit 1
if [ -n "$list" ]; then
    echo image/png
    exit 0
fi
[ "$target" = image/png ] && exec cat "$IMAGE"
exit 1
