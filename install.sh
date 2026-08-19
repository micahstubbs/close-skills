#!/usr/bin/env bash
# Install the /close skill chain into a Claude Code configuration directory.
#
#   ./install.sh                    # symlink into ~/.claude
#   ./install.sh /path/to/.claude   # install into a different config dir
#   ./install.sh --copy             # copy instead of symlinking
#   ./install.sh --uninstall        # remove what this script installed
#
# Skills land in <config>/skills/<name>/, the helper script in
# <config>/scripts/. Symlinks are the default so `git pull` updates the
# installed skills; pass --copy if you would rather have independent files you
# can edit in place.

set -euo pipefail

REPO_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

SKILLS=(
    close
    learn
    nss new-skills-session
    usfs update-skills-from-session
    sfs skills-from-session
    nsfst new-skills-from-session-transcript
    ns new-skill
    nsp new-skill-pick
)
SCRIPTS=(git-commit-iterator.sh)

MODE=symlink
UNINSTALL=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --copy) MODE=copy; shift ;;
        --symlink) MODE=symlink; shift ;;
        --uninstall) UNINSTALL=true; shift ;;
        -h|--help) sed -n '2,13p' "${BASH_SOURCE[0]}" | sed 's/^# \?//'; exit 0 ;;
        -*) echo "install.sh: unknown option '$1'" >&2; exit 2 ;;
        *) break ;;
    esac
done

CONFIG_DIR="${1:-$HOME/.claude}"
SKILLS_DIR="$CONFIG_DIR/skills"
SCRIPTS_DIR="$CONFIG_DIR/scripts"

# True when $1 is a symlink pointing at $2, or a copy this script made of $2.
installed_by_us() {
    local target="$1" src="$2"
    if [[ -L "$target" ]]; then
        [[ "$(readlink "$target")" == "$src" ]]
    elif [[ -e "$target" && -e "$src" ]]; then
        # A copy counts as ours only if it is byte-identical to the repo's.
        diff -r -q "$src" "$target" >/dev/null 2>&1
    else
        return 1
    fi
}

if [[ "$UNINSTALL" == true ]]; then
    for skill in "${SKILLS[@]}"; do
        target="$SKILLS_DIR/$skill"
        src="$REPO_DIR/skills/$skill"
        if [[ ! -e "$target" && ! -L "$target" ]]; then
            echo "absent   $target"
        elif installed_by_us "$target" "$src"; then
            rm -rf "$target"
            echo "removed  $target"
        else
            echo "skipped  $target (modified, or not installed by this script)"
        fi
    done

    for script in "${SCRIPTS[@]}"; do
        target="$SCRIPTS_DIR/$script"
        src="$REPO_DIR/scripts/$script"
        if [[ ! -e "$target" && ! -L "$target" ]]; then
            echo "absent   $target"
        elif installed_by_us "$target" "$src"; then
            rm -f "$target"
            echo "removed  $target"
        else
            echo "skipped  $target (modified, or not installed by this script)"
        fi
    done

    echo
    echo "Left alone: $CONFIG_DIR/.learn-progress (your /learn history position)"
    exit 0
fi

mkdir -p "$SKILLS_DIR" "$SCRIPTS_DIR"

install_one() {
    local src="$1" target="$2" kind="$3"

    if [[ -e "$target" || -L "$target" ]]; then
        if installed_by_us "$target" "$src"; then
            echo "ok       $target (already installed)"
            return 0
        fi
        echo "error: $target already exists and was not installed by this script." >&2
        echo "       Move it aside, or install into another config dir:" >&2
        echo "         ./install.sh /path/to/.claude" >&2
        return 1
    fi

    if [[ "$MODE" == copy ]]; then
        cp -R "$src" "$target"
        echo "copied   $target"
    else
        ln -s "$src" "$target"
        echo "linked   $target -> $src"
    fi
    [[ "$kind" == script ]] && chmod +x "$src"
    return 0
}

failed=0

for skill in "${SKILLS[@]}"; do
    install_one "$REPO_DIR/skills/$skill" "$SKILLS_DIR/$skill" skill || failed=1
done

for script in "${SCRIPTS[@]}"; do
    install_one "$REPO_DIR/scripts/$script" "$SCRIPTS_DIR/$script" script || failed=1
done

if [[ "$failed" -ne 0 ]]; then
    echo >&2
    echo "install.sh: one or more items were not installed (see errors above)" >&2
    exit 1
fi

echo
echo "Installed into $CONFIG_DIR. Start a new Claude Code session and run /close."
