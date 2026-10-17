#!/usr/bin/env bash
# Links the Signpost and Signpost_Data repositories into the game's AddOns folder using tools/dev.local.json:
# symlinks on macOS/Linux, junctions under Git Bash on Windows. `--unlink` removes the links. Only links are ever
# removed; a real folder is never touched. The client only notices new addon folders when it starts.
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
repo="$(cd "$here/.." && pwd)"
config="${DEV_CONFIG:-$here/dev.local.json}"
unlink=0
[ "${1:-}" = "--unlink" ] && unlink=1

if [ ! -f "$config" ]; then
    echo "$config not found: copy tools/dev.local.example.json to it and fill in the paths" >&2
    exit 1
fi
python="$(command -v python3 || command -v python)"
field() { "$python" -c 'import json, sys; print(json.load(open(sys.argv[1], encoding="utf-8"))[sys.argv[2]])' "$config" "$1"; }

case "$(uname -s)" in
    MINGW* | MSYS* | CYGWIN*) windows=1 ;;
    *) windows=0 ;;
esac

addons="$(field wowDir)/$(field flavorDir)/Interface/AddOns"
if [ "$windows" = 1 ]; then
    addons="$(cygpath -u "$addons")"
fi

make_link() {
    if [ "$windows" = 1 ]; then
        cmd //c mklink //J "$(cygpath -w "$1")" "$(cygpath -w "$2")" >/dev/null
    else
        ln -s "$2" "$1"
    fi
}

remove_link() {
    if [ "$windows" = 1 ]; then
        cmd //c rmdir "$(cygpath -w "$1")"
    else
        rm "$1"
    fi
}

[ "$unlink" = 1 ] || mkdir -p "$addons"

for name in Signpost Signpost_Data; do
    if [ "$name" = Signpost ]; then target="$repo"; else target="$(dirname "$repo")/Signpost_Data"; fi
    link="$addons/$name"
    if [ -L "$link" ]; then
        if [ "$unlink" = 1 ]; then
            remove_link "$link"
            echo "removed $link"
            continue
        fi
        if [ -d "$target" ] && [ "$(cd "$link" && pwd -P)" = "$(cd "$target" && pwd -P)" ]; then
            echo "ok      $link -> $target"
            continue
        fi
        remove_link "$link"
    elif [ -e "$link" ]; then
        echo "warning: $link is a real folder, not a link; leaving it alone" >&2
        continue
    elif [ "$unlink" = 1 ]; then
        continue
    fi
    if [ ! -d "$target" ]; then
        echo "warning: $target does not exist; skipping $name" >&2
        continue
    fi
    make_link "$link" "$target"
    echo "linked  $link -> $target"
done
