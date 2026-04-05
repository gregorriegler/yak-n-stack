#!/bin/bash
set -e

DIR="$(cd "$(dirname "$0")" && pwd)"
BASHUNIT="$DIR/lib/bashunit"

if [ ! -f "$BASHUNIT" ]; then
    echo "Installing bashunit..."
    cd "$DIR" && curl -s https://bashunit.typeddevs.com/install.sh | bash
fi

"$BASHUNIT" "$DIR"/tests/*_test.sh "$@"
