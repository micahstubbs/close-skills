# Lessons

Append-only log of debugging lessons from working on this repo. New entries
go at the end; old entries are never edited.

## 2026-09-05T16:05 - A crate's name is not its binary's name

**Problem**: `cargo install --git https://github.com/Dicklesworthstone/beads_viewer_rust.git bvr` failed with "could not find `bvr` in ... with version `*`", even though the tool everyone calls `bvr` lives in that repo and its README used to show that exact command.

**Root Cause**: `cargo install <name>` selects a *package* by its `[package] name`, not by the `[[bin]] name` it produces. The package is `beads_viewer_rust`; the binary is `bvr`. The short crate name was already taken on crates.io by an unrelated crate, so upstream could never make the two match.

**Lesson**: Before writing an installer for a Rust tool, read its `Cargo.toml` rather than its README, and treat `[package] name` and `[[bin]] name` as two separate facts. When they differ, the crates.io route (`cargo install <package>`) is also usually available and faster to resolve than the git route.

**Code Issue**:
```bash
# Before (broken): selects a package named bvr, which does not exist
cargo install --git https://github.com/Dicklesworthstone/beads_viewer_rust.git bvr

# After (fixed): the package is beads_viewer_rust; it still installs a bin named bvr
cargo install --locked beads_viewer_rust
```

**Solution**: `scripts/install-beads.sh` installs the `beads_viewer_rust` crate from crates.io by default, uses the git URL only under `--from-source`, and links `bv -> bvr` itself.

**Prevention**: The dry-run output prints the exact `cargo install` line, so a wrong package name is visible before anything builds.

## 2026-09-05T16:06 - `--version` output may go to stderr

**Problem**: The installer's final report printed `bv: ` with nothing after it, although the binary was installed and `bvr --version` printed a version when run by hand.

**Root Cause**: `bvr --version` writes to stderr. The report line captured `$(bvr --version 2>/dev/null)`, which discarded the only output.

**Lesson**: Do not assume `--version` goes to stdout. Some tools route all human-facing output, including the version banner, to stderr so that stdout stays machine-clean. Probe both streams separately once before writing a capture.

**Code Issue**:
```bash
# Before (broken)
echo "bv: $("$DEST/bvr" --version 2>/dev/null || echo installed)"

# After (fixed)
echo "bv: $("$DEST/bvr" --version 2>&1 || echo installed)"
```

**Solution**: Capture both streams for the version report of both tools.

**Prevention**: A quick `[$(cmd --version 2>/dev/null)]` vs `[$(cmd --version 2>&1 >/dev/null)]` pair tells you where the text lives in one line.

## 2026-09-05T16:07 - `git filter-repo` needs an answer and takes your remote

**Problem**: A second history rewrite in the same checkout died with `EOFError: EOF when reading a line`, and after the successful rerun `git push` had no `origin` to push to.

**Root Cause**: filter-repo leaves `.git/filter-repo/already_ran` behind. When that marker is older than a day it asks "Treat this run as a continuation of the previous run (Y/N)?" on stdin, which a non-interactive shell cannot answer. Separately, every successful run deletes the `origin` remote on purpose, so a rewritten history cannot be pushed by accident.

**Lesson**: Rewriting history is a two-prompt operation even with `--force`: one prompt on stdin if the repo has been rewritten before, and one implicit prompt afterwards in the form of a missing remote. Neither is an error in your filter.

**Solution**:
```bash
printf 'N\n' | git filter-repo --invert-paths --path <file> --force
git remote add origin <url>
git fetch <url> master:refs/remotes/origin/master   # restore a lease baseline
git push --force-with-lease=master:origin/master <url> master
```

**Prevention**: Back up untracked files you care about first (filter-repo does not delete them, but the checkout is about to change under you), and verify the purge with `git log --all -p | grep <pattern>` rather than by trusting the tool's summary. GitHub keeps the old commit fetchable by SHA until its own garbage collection; only deleting and recreating the repo forces it sooner.

## Meta-Lessons

- Two of three lessons here came from *reading the tool's own source of truth* (`Cargo.toml`, the actual byte streams) instead of its documentation or its friendly output. When an installer or wrapper misbehaves, go one layer down before changing code.
