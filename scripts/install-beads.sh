#!/usr/bin/env bash
# Install the beads issue tracker (`br`) and its viewer (`bv`).
#
#   scripts/install-beads.sh                 # both tools into ~/.local/bin
#   scripts/install-beads.sh --dest DIR      # somewhere else
#   scripts/install-beads.sh --only br       # just the tracker (or: --only bv)
#   scripts/install-beads.sh --from-source   # build both from their git repos
#   scripts/install-beads.sh --dry-run       # print what would happen, touch nothing
#   scripts/install-beads.sh --uninstall     # remove what this script installed
#
# `br` is beads_rust (https://github.com/Dicklesworthstone/beads_rust). It
# ships prebuilt release binaries, so by default it is downloaded and verified
# against the release's SHA-256 checksum. `bv` is beads_viewer_rust
# (https://github.com/Dicklesworthstone/beads_viewer_rust), which publishes no
# prebuilt binaries but is on crates.io, so it is built with `cargo install`.
# Its binary is named `bvr`; this script links it as `bv` as well.
#
# Options:
#   --dest DIR           install directory (default: $BEADS_INSTALL_DIR or ~/.local/bin)
#   --only br|bv         install only one of the two tools
#   --br-version vX.Y.Z  pin a beads_rust release or git tag (default: latest)
#   --bv-version X.Y.Z   pin a beads_viewer_rust crate version, or a git tag
#                        with --from-source (default: latest)
#   --from-source        build with cargo from the upstream git repositories
#                        instead of the br release binary and the bv crate
#   --force              overwrite binaries this script did not install
#   --dry-run            show the plan and exit
#   --uninstall          remove binaries recorded in the install manifest
#   -h, --help           this text
#
# Requirements: curl or wget, tar, sha256sum or shasum. Building bv (or br
# with --from-source) also needs a Rust toolchain: https://rustup.rs
#
# A manifest at <dest>/.install-beads-manifest records what was installed, so
# --uninstall removes only files that still match it and leaves everything
# else alone.

set -euo pipefail

BR_REPO="Dicklesworthstone/beads_rust"
BV_REPO="Dicklesworthstone/beads_viewer_rust"
MANIFEST_NAME=".install-beads-manifest"

DEST="${BEADS_INSTALL_DIR:-$HOME/.local/bin}"
ONLY=""
BR_VERSION="${BEADS_BR_VERSION:-}"
BV_VERSION="${BEADS_BV_VERSION:-}"
FROM_SOURCE=false
FORCE=false
DRY_RUN=false
UNINSTALL=false

usage() { sed -n '2,36p' "${BASH_SOURCE[0]}" | sed 's/^# \?//'; }

while [[ $# -gt 0 ]]; do
    case "$1" in
        --dest) [[ $# -ge 2 ]] || { echo "install-beads.sh: --dest needs a directory" >&2; exit 2; }
                DEST="$2"; shift 2 ;;
        --only) [[ $# -ge 2 ]] || { echo "install-beads.sh: --only needs br or bv" >&2; exit 2; }
                ONLY="$2"; shift 2 ;;
        --br-version) [[ $# -ge 2 ]] || { echo "install-beads.sh: --br-version needs a version" >&2; exit 2; }
                BR_VERSION="$2"; shift 2 ;;
        --bv-version) [[ $# -ge 2 ]] || { echo "install-beads.sh: --bv-version needs a version" >&2; exit 2; }
                BV_VERSION="$2"; shift 2 ;;
        --from-source) FROM_SOURCE=true; shift ;;
        --force) FORCE=true; shift ;;
        --dry-run) DRY_RUN=true; shift ;;
        --uninstall) UNINSTALL=true; shift ;;
        -h|--help) usage; exit 0 ;;
        *) echo "install-beads.sh: unknown option '$1'" >&2; exit 2 ;;
    esac
done

case "$ONLY" in
    ""|br|bv) ;;
    *) echo "install-beads.sh: --only must be br or bv, not '$ONLY'" >&2; exit 2 ;;
esac

WANT_BR=true; WANT_BV=true
[[ "$ONLY" == bv ]] && WANT_BR=false
[[ "$ONLY" == br ]] && WANT_BV=false

MANIFEST="$DEST/$MANIFEST_NAME"

# ------------------------------------------------------------------ helpers

have() { command -v "$1" >/dev/null 2>&1; }

sha256_of() {
    if have sha256sum; then sha256sum "$1" | cut -d' ' -f1
    elif have shasum; then shasum -a 256 "$1" | cut -d' ' -f1
    else echo "install-beads.sh: need sha256sum or shasum" >&2; return 1
    fi
}

fetch() {  # fetch URL FILE
    if have curl; then curl -fsSL --retry 3 -o "$2" "$1"
    elif have wget; then wget -q -O "$2" "$1"
    else echo "install-beads.sh: need curl or wget" >&2; return 1
    fi
}

# Print the manifest's recorded hash for NAME, or nothing.
manifest_hash() {
    [[ -f "$MANIFEST" ]] || return 0
    # grep exits 1 on no match; that is the "not recorded" case, not an error.
    grep -E "^[0-9a-f]{64}  $1\$" "$MANIFEST" 2>/dev/null | tail -n1 | cut -d' ' -f1 || true
}

manifest_set() {  # manifest_set NAME HASH
    local tmp="$MANIFEST.tmp.$$"
    if [[ -f "$MANIFEST" ]]; then
        grep -vE "  $1\$" "$MANIFEST" > "$tmp" || true
    else
        : > "$tmp"
    fi
    printf '%s  %s\n' "$2" "$1" >> "$tmp"
    mv "$tmp" "$MANIFEST"
}

manifest_unset() {
    [[ -f "$MANIFEST" ]] || return 0
    local tmp="$MANIFEST.tmp.$$"
    grep -vE "  $1\$" "$MANIFEST" > "$tmp" || true
    mv "$tmp" "$MANIFEST"
    [[ -s "$MANIFEST" ]] || rm -f "$MANIFEST"
}

# True when DEST/NAME exists and was put there by this script.
installed_by_us() {
    local path="$DEST/$1" recorded
    [[ -f "$path" ]] || return 1
    recorded="$(manifest_hash "$1")"
    [[ -n "$recorded" && "$recorded" == "$(sha256_of "$path")" ]]
}

# Refuse to overwrite a binary that is not ours unless --force.
check_clobber() {
    local path="$DEST/$1"
    if [[ -e "$path" || -L "$path" ]] && ! installed_by_us "$1"; then
        if [[ "$FORCE" == true ]]; then
            echo "warning  $path exists and was not installed by this script; --force overwrites it"
            return 0
        fi
        echo "error: $path already exists and was not installed by this script." >&2
        echo "       Move it aside, pass --force, or install elsewhere with --dest DIR." >&2
        return 1
    fi
    return 0
}

place_binary() {  # place_binary SRC NAME
    local src="$1" name="$2" hash
    chmod 755 "$src"
    mv -f "$src" "$DEST/$name"
    hash="$(sha256_of "$DEST/$name")"
    manifest_set "$name" "$hash"
    echo "installed $DEST/$name"
}

detect_platform() {
    local os arch
    case "${INSTALL_BEADS_OS:-$(uname -s)}" in
        Linux) os=linux ;;
        Darwin) os=darwin ;;
        *) return 1 ;;
    esac
    case "${INSTALL_BEADS_ARCH:-$(uname -m)}" in
        x86_64|amd64) arch=amd64 ;;
        aarch64|arm64) arch=arm64 ;;
        *) return 1 ;;
    esac
    if [[ "$os" == linux ]] && { ldd --version 2>&1 || true; } | grep -qi musl; then
        os=linux_musl
    fi
    echo "${os}_${arch}"
}

latest_br_version() {
    local tmp
    tmp="$(mktemp)"
    fetch "https://api.github.com/repos/$BR_REPO/releases/latest" "$tmp"
    sed -n 's/.*"tag_name": *"\([^"]*\)".*/\1/p' "$tmp" | head -n1
    rm -f "$tmp"
}

# ---------------------------------------------------------------- uninstall

if [[ "$UNINSTALL" == true ]]; then
    if [[ "$DRY_RUN" == true ]]; then
        echo "dry-run: would remove from $DEST whatever $MANIFEST_NAME still matches"
    fi
    for name in br bvr; do
        path="$DEST/$name"
        if [[ ! -e "$path" && ! -L "$path" ]]; then
            echo "absent   $path"
        elif installed_by_us "$name"; then
            if [[ "$DRY_RUN" == true ]]; then
                echo "would remove $path"
            else
                rm -f "$path"
                manifest_unset "$name"
                echo "removed  $path"
            fi
        else
            echo "skipped  $path (modified, or not installed by this script)"
        fi
    done
    link="$DEST/bv"
    if [[ -L "$link" && "$(readlink "$link")" == "bvr" ]]; then
        if [[ "$DRY_RUN" == true ]]; then
            echo "would remove $link"
        else
            rm -f "$link"
            echo "removed  $link"
        fi
    elif [[ -e "$link" || -L "$link" ]]; then
        echo "skipped  $link (not a link to bvr made by this script)"
    else
        echo "absent   $link"
    fi
    exit 0
fi

# ------------------------------------------------------------------ install

PLATFORM="$(detect_platform || true)"

if [[ "$WANT_BR" == true && "$FROM_SOURCE" == false && -z "$PLATFORM" ]]; then
    echo "install-beads.sh: no prebuilt br release for $(uname -s)/$(uname -m); use --from-source" >&2
    exit 1
fi

needs_cargo=false
[[ "$WANT_BV" == true ]] && needs_cargo=true
[[ "$WANT_BR" == true && "$FROM_SOURCE" == true ]] && needs_cargo=true
if [[ "$needs_cargo" == true && "$DRY_RUN" == false ]] && ! have cargo; then
    echo "install-beads.sh: cargo is required to build $( [[ "$WANT_BV" == true ]] && echo bv || echo br ) but was not found." >&2
    echo "       Install a Rust toolchain from https://rustup.rs and re-run." >&2
    exit 1
fi

if [[ "$DRY_RUN" == true ]]; then
    echo "dry-run: nothing will be downloaded, built, or written"
    echo "dest     $DEST"
    if [[ "$WANT_BR" == true ]]; then
        if [[ "$FROM_SOURCE" == true ]]; then
            echo "br       cargo install --git https://github.com/$BR_REPO.git${BR_VERSION:+ --tag $BR_VERSION}"
        else
            v="${BR_VERSION:-latest (resolved from GitHub at install time)}"
            echo "br       release $v, asset br-${BR_VERSION#v}-${PLATFORM}.tar.gz, sha256-verified"
        fi
    fi
    if [[ "$WANT_BV" == true ]]; then
        if [[ "$FROM_SOURCE" == true ]]; then
            echo "bv       cargo install --git https://github.com/$BV_REPO.git${BV_VERSION:+ --tag $BV_VERSION} beads_viewer_rust, then bv -> bvr"
        else
            echo "bv       cargo install --locked beads_viewer_rust${BV_VERSION:+ --version $BV_VERSION} (crates.io), then bv -> bvr"
        fi
    fi
    exit 0
fi

mkdir -p "$DEST"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

if [[ "$WANT_BR" == true ]]; then
    check_clobber br
    if [[ "$FROM_SOURCE" == true ]]; then
        echo "building br from https://github.com/$BR_REPO.git (upstream targets Rust nightly)"
        cargo install --quiet --git "https://github.com/$BR_REPO.git" \
            ${BR_VERSION:+--tag "$BR_VERSION"} --root "$WORK/br-root" br
        place_binary "$WORK/br-root/bin/br" br
    else
        if [[ -z "$BR_VERSION" ]]; then
            BR_VERSION="$(latest_br_version)"
            [[ -n "$BR_VERSION" ]] || { echo "install-beads.sh: could not resolve the latest br release" >&2; exit 1; }
        fi
        asset="br-${BR_VERSION#v}-${PLATFORM}.tar.gz"
        base="https://github.com/$BR_REPO/releases/download/$BR_VERSION"
        echo "downloading $asset"
        fetch "$base/$asset" "$WORK/$asset"
        fetch "$base/$asset.sha256" "$WORK/$asset.sha256"
        expected="$(cut -d' ' -f1 "$WORK/$asset.sha256")"
        actual="$(sha256_of "$WORK/$asset")"
        if [[ -z "$expected" || "$expected" != "$actual" ]]; then
            echo "install-beads.sh: checksum mismatch for $asset" >&2
            echo "       expected $expected" >&2
            echo "       got      $actual" >&2
            exit 1
        fi
        mkdir -p "$WORK/br-extract"
        tar -xzf "$WORK/$asset" -C "$WORK/br-extract"
        [[ -f "$WORK/br-extract/br" ]] || { echo "install-beads.sh: $asset did not contain a br binary" >&2; exit 1; }
        place_binary "$WORK/br-extract/br" br
    fi
fi

if [[ "$WANT_BV" == true ]]; then
    check_clobber bvr
    if [[ "$FROM_SOURCE" == true ]]; then
        echo "building bvr from https://github.com/$BV_REPO.git${BV_VERSION:+ at $BV_VERSION} (this takes a few minutes)"
        cargo install --quiet --git "https://github.com/$BV_REPO.git" \
            ${BV_VERSION:+--tag "$BV_VERSION"} --root "$WORK/bv-root" beads_viewer_rust
    else
        echo "building bvr from the beads_viewer_rust crate${BV_VERSION:+ $BV_VERSION} (this takes a few minutes)"
        cargo install --quiet --locked ${BV_VERSION:+--version "$BV_VERSION"} \
            --root "$WORK/bv-root" beads_viewer_rust
    fi
    place_binary "$WORK/bv-root/bin/bvr" bvr
    link="$DEST/bv"
    if [[ -L "$link" && "$(readlink "$link")" == "bvr" ]]; then
        echo "ok       $link -> bvr (already linked)"
    elif [[ -e "$link" || -L "$link" ]]; then
        if [[ "$FORCE" == true ]]; then
            rm -f "$link"; ln -s bvr "$link"; echo "linked   $link -> bvr (replaced with --force)"
        else
            echo "warning  $link exists and is not a link to bvr; left alone (bvr is installed, pass --force to relink)"
        fi
    else
        ln -s bvr "$link"
        echo "linked   $link -> bvr"
    fi
fi

case ":$PATH:" in
    *":$DEST:"*) ;;
    *) echo; echo "note: $DEST is not on your PATH. Add it, for example:"
       echo "      export PATH=\"$DEST:\$PATH\"" ;;
esac

echo
# bvr prints its version to stderr, so capture both streams.
[[ "$WANT_BR" == true ]] && echo "br: $("$DEST/br" --version 2>&1 || echo installed)"
[[ "$WANT_BV" == true ]] && echo "bv: $("$DEST/bvr" --version 2>&1 || echo installed)"
exit 0
