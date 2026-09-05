# close-skills

A small chain of [Claude Code](https://claude.com/claude-code) skills that runs
at the end of a working session and writes down what you just learned.

```console
/close
```

That one command runs three passes, each with a different destination:

| Pass | Asks | Writes to |
| --- | --- | --- |
| `/learn` | What went wrong here, and why? | `LESSONS.md` in the project |
| `/nss` | Did I just do something worth doing the same way again? | a new skill |
| `/usfs` | Did I learn something about a workflow I already have a skill for? | an existing `SKILL.md` |

Everything else in the repo exists to serve those three: `/nss` picks between
`/sfs` and `/nsfst` depending on whether your context survived; both of those
call `/ns` to actually write a skill; `/nsp` is `/ns` for when you can describe
the skill but cannot think of a name.

## Why bother

An agent session produces two kinds of output. There is the work — the commits,
the fixed bug, the shipped feature — and there is everything you figured out
along the way to producing it. The first kind gets committed. The second kind
evaporates when the context window closes, and then you rediscover it in three
weeks, from scratch, at the same cost.

The fix is not complicated. It is just easy to skip, because at the end of a
long session the last thing anyone wants is a documentation chore. So `/close`
makes it one command, and splits the output by destination so nothing has to be
filed twice:

- A **lesson** is true about *this codebase*. It goes in `LESSONS.md`,
  append-only, next to the code it is about.
- A **skill** is true about *a kind of task*. It goes in `~/.claude/skills/`,
  where it will be loaded in every future session, in every project.

The split matters more than it looks. Lessons that get promoted to skills
become noise in every unrelated project. Skills that get buried in a project's
`LESSONS.md` never load when you need them.

## Install

Requires Claude Code, `bash` 4.0+, and `git`.

```bash
git clone https://github.com/micahstubbs/close-skills.git
cd close-skills
./install.sh
```

That symlinks fourteen skill directories into `~/.claude/skills/` and one helper
script into `~/.claude/scripts/`. Symlinks rather than copies, so `git pull`
updates the installed skills.

```bash
./install.sh /path/to/.claude   # a different config directory
./install.sh --copy             # real files you can edit in place
./install.sh --uninstall        # remove what the script installed
```

The installer refuses to overwrite anything it did not create, and `--uninstall`
skips files you have modified. If you already have a skill named `close`,
`learn`, or `ns`, you will get an error naming the collision rather than a
silent replacement.

Start a new session afterwards — Claude Code reads the skills directory at
startup.

## What each skill does

### `/close` — the entry point

Runs `/learn`, then `/nss`, then `/usfs`. That order is deliberate: `/learn`
first because a lesson is the cheapest thing to write down and the easiest to
lose, and `/nss` before `/usfs` so a pattern that becomes a new skill doesn't
also get pasted into a neighboring one.

Each step is independent. If one finds nothing worth capturing, it says so and
the chain moves on.

### `/learn` — lessons into LESSONS.md

Appends a timestamped entry with problem, root cause, lesson, solution, and
prevention. The file is **append-only**: no editing old entries, no
reorganizing, no improving. A lesson rewritten later to sound smarter is a
lesson you will not trust when you need it.

`/learn` also has a history-mining mode for lessons that predate the session:

```bash
~/.claude/scripts/git-commit-iterator.sh . status   # how far through you are
~/.claude/scripts/git-commit-iterator.sh . next     # next 50 commits
~/.claude/scripts/git-commit-iterator.sh . reset    # start over
```

The script remembers its position per repository — keyed by the `origin` remote
URL, so two checkouts of the same repo share one position — which is what makes
"keep going through the history" a resumable operation across sessions rather
than a re-read of the same commits every time. Chunk size and state directory
are `LEARN_CHUNK_SIZE` and `LEARN_PROGRESS_DIR`.

### `/nss` — new skills from this session

Looks at what you just did and asks which parts of it are worth keeping. A
pattern earns a skill only if it is repeatable, complex enough to be worth
writing down (3+ steps, non-obvious ordering, or easy-to-forget details), not
already covered, and has actual decision points rather than a fixed sequence of
commands.

That last criterion is the one that keeps a skill set usable. A skill that
records *what* you typed is a shell script with extra steps. A skill worth
loading records *why* you chose that over the obvious alternative.

`/nss` picks its source automatically: live conversation context if you still
have it, the session transcript on disk if you don't.

### `/sfs` and `/nsfst` — the two sources

`/sfs` reads the current conversation. `/nsfst` reads the session's JSONL
transcript from `~/.claude/projects/`, which is what you need after a context
compaction, or when looking back at a session that already ended.

| | `/sfs` | `/nsfst` |
| --- | --- | --- |
| Source | Current conversation | Transcript file on disk |
| Works after compaction | No | Yes |
| Works retrospectively | No | Yes |

Use `/nss` unless you specifically want one of them.

### `/usfs` — update the skills you already have

The counterpart to `/nss`. Instead of asking "is there a new skill here", it
asks "did I learn something about a skill I already have" — a flag that turned
out to matter, an edge case worth a warning, a step that was missing.

Additive by default: enhance, don't rewrite. Conservative by default: when
unsure whether something belongs, skip it. Skills that grow without pruning
stop being read, which makes them worse than no skill at all.

### `/ns` and `/nsp` — writing a skill

`/ns` creates a skill under two names — a short one you can type (`nss`) and a
kebab-case one you can remember (`new-skills-session`) — with the long name as a
thin alias that delegates to the short one. Every skill in this repo is built
that way; it is why there are fourteen directories for eight skills.

```
/ns mc multi-commit: create multiple commits grouping related changes
/ns project dp deploy-production: deploy to the production environment
```

`/nsp` is the same thing when you can describe the skill but not name it — it
picks the abbreviation and alias for you and hands off to `/ns`.

`/ns` also carries the guidance that keeps generated skills from being bad:
put deterministic logic in a script and let the SKILL.md handle the judgment
calls, and a table of the `set -euo pipefail` traps (`grep` exiting 1 on no
match, `((i++))` returning 1 at zero, `diff` exiting 1 on differences) that
silently kill skill scripts mid-run.

## Prerequisites and assumptions

- **Claude Code**, obviously, with a `~/.claude` configuration directory.
- **`git`** — `/learn` commits `LESSONS.md`, and the history iterator is `git log`
  with a bookmark.
- **`sha256sum` or `shasum`** for the iterator's per-repo state key. Present on
  Linux and macOS both.
- The transcript-reading skills assume Claude Code's layout,
  `~/.claude/projects/<path-with-slashes-as-dashes>/*.jsonl`.

No issue tracker, package manager, or external service is required. `/ns`
commits new skills to `~/.claude` if that directory happens to be a git repo,
and quietly skips the commit if it isn't.

## Optional: the beads issue tracker

This repo tracks its own work in [beads](https://github.com/Dicklesworthstone/beads_rust),
a local-first issue tracker that lives in a `.beads/` directory next to the
code, and triages it with [beads_viewer_rust](https://github.com/Dicklesworthstone/beads_viewer_rust),
a graph-aware view over the same data. The skills do not need either. If you
want them anyway, one script installs both:

```bash
scripts/install-beads.sh                 # br + bv into ~/.local/bin
scripts/install-beads.sh --dest DIR      # somewhere else
scripts/install-beads.sh --only br       # just the tracker
scripts/install-beads.sh --dry-run       # show the plan, touch nothing
scripts/install-beads.sh --uninstall     # remove what it installed
```

`br` is downloaded as a prebuilt release binary and verified against the
release's SHA-256 checksum. `bv` publishes no binaries, so it is built from
the `beads_viewer_rust` crate with `cargo install`; that needs a Rust
toolchain from [rustup.rs](https://rustup.rs) and takes a few minutes. Its
binary is called `bvr`, and the script links `bv` to it so the usual name
works. `--from-source` builds both from their git repositories instead;
`--br-version` and `--bv-version` pin releases.

The script keeps a manifest of what it installed and, like `install.sh`,
refuses to overwrite or remove anything it did not put there.

## Tests

```bash
./tests/run-tests.sh
```

Plain bash, no framework. Everything that touches the filesystem works inside a
`mktemp -d` scratch directory, so the tests never see your real `~/.claude`. The
git iterator is exercised against a five-commit throwaway repo built on the fly.

## Layout

```
skills/close/                  the entry point
skills/learn/                  lessons -> LESSONS.md
skills/nss/, sfs/, nsfst/      create new skills (dispatcher + two sources)
skills/usfs/                   update existing skills
skills/ns/, nsp/               write a skill (explicit names / auto-picked)
skills/<long-name>/            alias directories delegating to the short names
scripts/git-commit-iterator.sh resumable chunked walk through git history
scripts/install-beads.sh       optional: install the br/bv issue tracker
install.sh                     symlink or copy into ~/.claude
tests/run-tests.sh             smoke tests
```

## License

MIT. See [LICENSE](LICENSE).
