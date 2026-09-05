#!/usr/bin/env bash
# Smoke tests for close-skills. No test framework required -- ./tests/run-tests.sh
#
# Everything that touches the filesystem works inside a mktemp -d scratch
# directory, so the tests never see or modify your real ~/.claude.

set -uo pipefail

REPO_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PASS=0
FAIL=0

pass() { PASS=$((PASS + 1)); printf '  ok   %s\n' "$1"; }
fail() {
    FAIL=$((FAIL + 1))
    printf '  FAIL %s\n' "$1"
    [[ $# -gt 1 ]] && printf '       %s\n' "$2"
    return 0
}

assert_eq() {
    local desc="$1" actual="$2" expected="$3"
    if [[ "$actual" == "$expected" ]]; then pass "$desc"
    else fail "$desc" "expected '$expected', got '$actual'"; fi
}

assert_contains() {
    local desc="$1" haystack="$2" needle="$3"
    if [[ "$haystack" == *"$needle"* ]]; then pass "$desc"
    else fail "$desc" "expected to contain '$needle', got: $haystack"; fi
}

assert_not_contains() {
    local desc="$1" haystack="$2" needle="$3"
    if [[ "$haystack" != *"$needle"* ]]; then pass "$desc"
    else fail "$desc" "expected NOT to contain '$needle'"; fi
}

assert_status() {
    local desc="$1" expected="$2"; shift 2
    "$@" >/dev/null 2>&1
    assert_eq "$desc" "$?" "$expected"
}

SCRATCH="$(mktemp -d)"
cleanup() { rm -rf "$SCRATCH"; }
trap cleanup EXIT

# ---------------------------------------------------------------- shell syntax

echo "== shell syntax =="
for f in "$REPO_DIR/install.sh" "$REPO_DIR/scripts/"*.sh "$REPO_DIR/tests/run-tests.sh"; do
    assert_status "bash -n $(basename "$f")" 0 bash -n "$f"
done

# ------------------------------------------------------------ skill structure

echo "== skill structure =="
EXPECTED_SKILLS=(
    close learn
    nss new-skills-session
    usfs update-skills-from-session
    sfs skills-from-session
    nsfst new-skills-from-session-transcript
    ns new-skill
    nsp new-skill-pick
)

for skill in "${EXPECTED_SKILLS[@]}"; do
    if [[ -f "$REPO_DIR/skills/$skill/SKILL.md" ]]; then
        pass "skills/$skill/SKILL.md exists"
    else
        fail "skills/$skill/SKILL.md exists" "missing"
    fi
done

# Every SKILL.md must open with YAML front matter whose `name` matches its
# directory -- Claude Code resolves skills by that name, so a mismatch means
# the skill is invocable under a name nobody will guess.
for dir in "$REPO_DIR"/skills/*/; do
    skill="$(basename "$dir")"
    file="$dir/SKILL.md"
    [[ -f "$file" ]] || continue
    assert_eq "$skill front matter starts at line 1" "$(head -1 "$file")" "---"
    declared="$(awk 'NR>1 && /^---$/{exit} /^name:/{print $2}' "$file")"
    assert_eq "$skill front matter name matches directory" "$declared" "$skill"
    if awk 'NR>1 && /^---$/{exit} /^description:/{found=1} END{exit !found}' "$file"; then
        pass "$skill declares a description"
    else
        fail "$skill declares a description" "no description: line in front matter"
    fi
done

# Aliases must actually point at a skill that ships in this repo.
for skill in new-skills-session update-skills-from-session skills-from-session \
             new-skills-from-session-transcript new-skill new-skill-pick; do
    body="$(cat "$REPO_DIR/skills/$skill/SKILL.md")"
    assert_contains "$skill delegates via the Skill tool" "$body" "use the Skill tool to run"
done

# ------------------------------------------------------------------- scrubbing

echo "== no machine-specific paths =="
LEAKS="$(grep -rInE '/home/[a-z]|~/wk/|~/keys/|/Users/[a-z]' \
    "$REPO_DIR/skills" "$REPO_DIR/scripts" "$REPO_DIR/install.sh" \
    "$REPO_DIR/README.md" "$REPO_DIR/CLAUDE.md" "$REPO_DIR/docs" 2>/dev/null || true)"
assert_eq "no absolute home paths in shipped files" "$LEAKS" ""

# ------------------------------------------------------- git-commit-iterator

echo "== git-commit-iterator =="
ITER="$REPO_DIR/scripts/git-commit-iterator.sh"
export LEARN_PROGRESS_DIR="$SCRATCH/progress"
export LEARN_CHUNK_SIZE=2

out="$("$ITER" --help 2>&1)"
assert_contains "--help prints usage" "$out" "git-commit-iterator.sh"

assert_status "non-repo path exits 1" 1 "$ITER" "$SCRATCH" status

# Build a throwaway repo with 5 commits.
FIXTURE="$SCRATCH/repo"
mkdir -p "$FIXTURE"
(
    cd "$FIXTURE" || exit 1
    git init -q .
    git config user.email test@example.com
    git config user.name "Test"
    for i in 1 2 3 4 5; do
        echo "$i" > file.txt
        git add file.txt
        git commit -q -m "commit $i"
    done
) >/dev/null 2>&1

out="$("$ITER" "$FIXTURE" status 2>&1)"
assert_contains "status reports total commits" "$out" "Total commits: 5"
assert_contains "status starts at zero processed" "$out" "Processed: 0"

out="$("$ITER" "$FIXTURE" next 2>&1)"
assert_contains "first chunk is commits 1-2" "$out" "Commits 1-2 of 5"
assert_contains "first chunk includes newest commit" "$out" "commit 5"
assert_not_contains "first chunk stops at the chunk size" "$out" "commit 3"

out="$("$ITER" "$FIXTURE" next 2>&1)"
assert_contains "second chunk advances the offset" "$out" "Commits 3-4 of 5"

out="$("$ITER" "$FIXTURE" status 2>&1)"
assert_contains "status reflects the advanced offset" "$out" "Processed: 4"

out="$("$ITER" "$FIXTURE" next 2>&1)"
assert_contains "final chunk is short" "$out" "Commits 5-5 of 5"

out="$("$ITER" "$FIXTURE" next 2>&1)"
assert_contains "exhausted history reports completion" "$out" "complete"

out="$("$ITER" "$FIXTURE" status 2>&1)"
assert_contains "status reports COMPLETED" "$out" "COMPLETED"

out="$("$ITER" "$FIXTURE" reset 2>&1)"
assert_contains "reset confirms" "$out" "reset"
out="$("$ITER" "$FIXTURE" status 2>&1)"
assert_contains "reset clears the offset" "$out" "Processed: 0"

assert_status "unknown action exits 2" 2 "$ITER" "$FIXTURE" bogus

unset LEARN_PROGRESS_DIR LEARN_CHUNK_SIZE

# -------------------------------------------------------------------- install

echo "== install.sh =="
CONFIG="$SCRATCH/config"

out="$("$REPO_DIR/install.sh" "$CONFIG" 2>&1)"
assert_eq "install exits 0" "$?" "0"
assert_contains "install reports linking" "$out" "linked"

for skill in "${EXPECTED_SKILLS[@]}"; do
    if [[ -f "$CONFIG/skills/$skill/SKILL.md" ]]; then
        pass "installed skills/$skill resolves to a SKILL.md"
    else
        fail "installed skills/$skill resolves to a SKILL.md" "missing"
    fi
done

if [[ -x "$CONFIG/scripts/git-commit-iterator.sh" ]]; then
    pass "installed script is executable"
else
    fail "installed script is executable" "not executable via $CONFIG"
fi

out="$("$REPO_DIR/install.sh" "$CONFIG" 2>&1)"
assert_contains "re-install is idempotent" "$out" "already installed"

# A file the user put there themselves must not be clobbered.
mkdir -p "$SCRATCH/config2/skills/close"
echo "mine" > "$SCRATCH/config2/skills/close/SKILL.md"
out="$("$REPO_DIR/install.sh" "$SCRATCH/config2" 2>&1)"
assert_eq "install refuses to clobber a foreign skill" "$?" "1"
assert_eq "foreign skill left untouched" "$(cat "$SCRATCH/config2/skills/close/SKILL.md")" "mine"

out="$("$REPO_DIR/install.sh" --uninstall "$CONFIG" 2>&1)"
assert_contains "uninstall reports removal" "$out" "removed"
if [[ -e "$CONFIG/skills/close" || -L "$CONFIG/skills/close" ]]; then
    fail "uninstall removes installed skills" "skills/close still present"
else
    pass "uninstall removes installed skills"
fi

out="$("$REPO_DIR/install.sh" --uninstall "$SCRATCH/config2" 2>&1)"
assert_contains "uninstall skips foreign files" "$out" "skipped"
assert_eq "foreign skill survives uninstall" "$(cat "$SCRATCH/config2/skills/close/SKILL.md")" "mine"

# --copy mode produces real files, not links.
CONFIG3="$SCRATCH/config3"
"$REPO_DIR/install.sh" --copy "$CONFIG3" >/dev/null 2>&1
if [[ -f "$CONFIG3/skills/close/SKILL.md" && ! -L "$CONFIG3/skills/close" ]]; then
    pass "--copy installs real directories"
else
    fail "--copy installs real directories" "close is missing or still a symlink"
fi

assert_status "unknown option exits 2" 2 "$REPO_DIR/install.sh" --nope

# ------------------------------------------------------------ install-beads

# Everything here is offline: --dry-run and --uninstall never touch the
# network, and the manifest logic is exercised with hand-made files.
echo "== install-beads.sh =="
IB="$REPO_DIR/scripts/install-beads.sh"
BINDEST="$SCRATCH/bindest"

digest() {
    if command -v sha256sum >/dev/null 2>&1; then sha256sum "$1" | cut -d' ' -f1
    else shasum -a 256 "$1" | cut -d' ' -f1; fi
}

out="$("$IB" --help 2>&1)"
assert_eq "--help exits 0" "$?" "0"
assert_contains "--help documents --uninstall" "$out" "--uninstall"

assert_status "unknown option exits 2" 2 "$IB" --nope
assert_status "--only rejects unknown tool" 2 "$IB" --only nope
assert_status "--dest without a value exits 2" 2 "$IB" --dest

out="$("$IB" --dry-run --br-version v0.5.10 --dest "$BINDEST" 2>&1)"
assert_eq "dry-run exits 0" "$?" "0"
assert_contains "dry-run names the pinned br asset" "$out" "br-0.5.10-"
assert_contains "dry-run names the bv build" "$out" "beads_viewer_rust"
if [[ -e "$BINDEST" ]]; then
    fail "dry-run creates nothing" "$BINDEST exists"
else
    pass "dry-run creates nothing"
fi

out="$(INSTALL_BEADS_OS=Darwin INSTALL_BEADS_ARCH=arm64 \
       "$IB" --dry-run --only br --br-version v1.2.3 --dest "$BINDEST" 2>&1)"
assert_contains "platform detection maps Darwin/arm64" "$out" "br-1.2.3-darwin_arm64.tar.gz"
assert_not_contains "--only br skips bv" "$out" "beads_viewer_rust"

out="$(INSTALL_BEADS_OS=Windows_NT "$IB" --dry-run --only br --dest "$BINDEST" 2>&1)"
assert_eq "unsupported platform without --from-source exits 1" "$?" "1"
assert_contains "unsupported platform suggests --from-source" "$out" "--from-source"

out="$(INSTALL_BEADS_OS=Windows_NT "$IB" --dry-run --only br --from-source --dest "$BINDEST" 2>&1)"
assert_eq "unsupported platform with --from-source is a cargo build" "$?" "0"
assert_contains "--from-source plans a cargo install" "$out" "cargo install"

# Uninstall against an empty directory reports absence and succeeds.
mkdir -p "$BINDEST"
out="$("$IB" --uninstall --dest "$BINDEST" 2>&1)"
assert_eq "uninstall on empty dest exits 0" "$?" "0"
assert_contains "uninstall reports absent br" "$out" "absent   $BINDEST/br"

# A binary with no manifest entry is not ours and must survive.
echo "mine" > "$BINDEST/br"
out="$("$IB" --uninstall --dest "$BINDEST" 2>&1)"
assert_contains "uninstall skips a foreign br" "$out" "skipped  $BINDEST/br"
assert_eq "foreign br left untouched" "$(cat "$BINDEST/br")" "mine"

# A binary whose hash matches the manifest is ours and is removed, along
# with the bv -> bvr link; the manifest disappears once it is empty.
printf '#!/bin/sh\necho bvr\n' > "$BINDEST/bvr"
printf '%s  bvr\n' "$(digest "$BINDEST/bvr")" > "$BINDEST/.install-beads-manifest"
ln -s bvr "$BINDEST/bv"
out="$("$IB" --uninstall --dry-run --dest "$BINDEST" 2>&1)"
assert_contains "uninstall --dry-run says what it would remove" "$out" "would remove $BINDEST/bvr"
assert_eq "uninstall --dry-run removes nothing" "$(cat "$BINDEST/bvr" | head -1)" "#!/bin/sh"
out="$("$IB" --uninstall --dest "$BINDEST" 2>&1)"
assert_contains "uninstall removes a manifest-matched bvr" "$out" "removed  $BINDEST/bvr"
assert_contains "uninstall removes the bv link" "$out" "removed  $BINDEST/bv"
if [[ -e "$BINDEST/bvr" || -L "$BINDEST/bv" ]]; then
    fail "bvr and bv are gone" "still present"
else
    pass "bvr and bv are gone"
fi
if [[ -e "$BINDEST/.install-beads-manifest" ]]; then
    fail "empty manifest is removed" "manifest still present"
else
    pass "empty manifest is removed"
fi
assert_eq "foreign br still untouched after full uninstall" "$(cat "$BINDEST/br")" "mine"

# A binary that was ours but has since been modified is no longer ours.
printf 'v1\n' > "$BINDEST/bvr"
printf '%s  bvr\n' "$(digest "$BINDEST/bvr")" > "$BINDEST/.install-beads-manifest"
printf 'v2\n' > "$BINDEST/bvr"
out="$("$IB" --uninstall --dest "$BINDEST" 2>&1)"
assert_contains "uninstall skips a modified bvr" "$out" "skipped  $BINDEST/bvr"
assert_eq "modified bvr survives" "$(cat "$BINDEST/bvr")" "v2"

# A bv that is not our link is left alone.
rm -f "$BINDEST/bv"; echo "mine" > "$BINDEST/bv"
out="$("$IB" --uninstall --dest "$BINDEST" 2>&1)"
assert_contains "uninstall skips a foreign bv" "$out" "skipped  $BINDEST/bv"

echo
echo "passed: $PASS   failed: $FAIL"
[[ "$FAIL" -eq 0 ]]
