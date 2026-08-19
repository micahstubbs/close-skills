#!/usr/bin/env bash
# git-commit-iterator.sh -- walk a repository's history in fixed-size chunks,
# remembering where you left off. Used by the /learn skill to mine old commits
# for lessons without re-reading the same commits every time.
#
#   git-commit-iterator.sh [repo_path] status   # how far through history you are
#   git-commit-iterator.sh [repo_path] next     # print the next chunk, advance
#   git-commit-iterator.sh [repo_path] reset    # start this repo over
#
# repo_path defaults to the current directory.
#
# Progress is keyed by the repo's origin remote URL (falling back to its
# absolute path) so the same clone tracked from two checkouts shares one
# position. State lives in $LEARN_PROGRESS_DIR, default ~/.claude/.learn-progress.
#
# Environment:
#   LEARN_PROGRESS_DIR   where offsets are stored
#   LEARN_CHUNK_SIZE     commits per `next` (default 50)

set -euo pipefail

CHUNK_SIZE="${LEARN_CHUNK_SIZE:-50}"
PROGRESS_DIR="${LEARN_PROGRESS_DIR:-$HOME/.claude/.learn-progress}"

usage() {
    sed -n '2,20p' "${BASH_SOURCE[0]}" | sed 's/^# \?//'
}

# Hash the repo identity. Prefer sha256sum/shasum over md5sum: md5sum is absent
# on macOS, where the equivalent is `md5`.
hash_string() {
    if command -v sha256sum >/dev/null 2>&1; then
        printf '%s' "$1" | sha256sum | cut -d' ' -f1
    elif command -v shasum >/dev/null 2>&1; then
        printf '%s' "$1" | shasum -a 256 | cut -d' ' -f1
    else
        echo "error: neither sha256sum nor shasum found" >&2
        exit 1
    fi
}

get_repo_id() {
    local repo_url
    # `git config --get` exits 1 when the key is unset; that is not an error here.
    repo_url="$(git config --get remote.origin.url 2>/dev/null || true)"
    [[ -n "$repo_url" ]] || repo_url="$(pwd)"
    hash_string "$repo_url"
}

offset_file() { printf '%s/%s.offset' "$PROGRESS_DIR" "$1"; }
complete_file() { printf '%s/%s.complete' "$PROGRESS_DIR" "$1"; }

get_offset() {
    local f
    f="$(offset_file "$1")"
    if [[ -f "$f" ]]; then cat "$f"; else echo 0; fi
}

set_offset() {
    mkdir -p "$PROGRESS_DIR"
    printf '%s\n' "$2" > "$(offset_file "$1")"
}

mark_completed() {
    mkdir -p "$PROGRESS_DIR"
    printf 'Full history processed on %s\n' "$(date +%Y-%m-%d)" > "$(complete_file "$1")"
}

is_completed() { [[ -f "$(complete_file "$1")" ]]; }

get_total_commits() { git rev-list --count --all; }

main() {
    local repo_path="${1:-.}" action="${2:-next}"

    case "$repo_path" in
        -h|--help) usage; exit 0 ;;
    esac

    cd "$repo_path" || exit 1

    if ! git rev-parse --git-dir >/dev/null 2>&1; then
        echo "error: $repo_path is not a git repository" >&2
        exit 1
    fi

    local repo_id total offset remaining
    repo_id="$(get_repo_id)"

    case "$action" in
        status)
            total="$(get_total_commits)"
            offset="$(get_offset "$repo_id")"

            if is_completed "$repo_id"; then
                echo "Status: COMPLETED"
                cat "$(complete_file "$repo_id")"
                exit 0
            fi

            remaining=$((total - offset))
            echo "Total commits: $total"
            echo "Processed: $offset"
            echo "Remaining: $remaining"
            if [[ "$total" -gt 0 ]]; then
                echo "Progress: $((offset * 100 / total))%"
            fi
            ;;

        next)
            if is_completed "$repo_id"; then
                echo "# Already completed"
                cat "$(complete_file "$repo_id")"
                exit 0
            fi

            total="$(get_total_commits)"
            offset="$(get_offset "$repo_id")"
            remaining=$((total - offset))

            if [[ "$remaining" -le 0 ]]; then
                mark_completed "$repo_id"
                echo "# Processing complete"
                echo "# Total commits processed: $total"
                exit 0
            fi

            local count="$CHUNK_SIZE"
            [[ "$remaining" -lt "$count" ]] && count="$remaining"

            echo "# Commits $((offset + 1))-$((offset + count)) of $total"
            echo "# Progress: $((offset * 100 / total))% -> $(((offset + count) * 100 / total))%"
            echo

            git log --all --oneline --skip="$offset" -n "$count"

            set_offset "$repo_id" $((offset + count))
            ;;

        reset)
            set_offset "$repo_id" 0
            rm -f "$(complete_file "$repo_id")"
            echo "Progress reset for this repository"
            ;;

        -h|--help)
            usage
            ;;

        *)
            echo "error: unknown action '$action'" >&2
            echo >&2
            usage >&2
            exit 2
            ;;
    esac
}

main "$@"
