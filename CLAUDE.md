# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

`close-skills` is a chain of Claude Code skills for end-of-session knowledge
capture: `/close` runs `/learn`, `/nss`, and `/usfs`. Public, MIT-licensed.
Keep it that way — no private paths, no machine-specific assumptions, no
references to skills or tooling that do not ship in this repo or install from
it. The one external dependency the repo admits is the beads issue tracker,
and `scripts/install-beads.sh` exists so that reference is honest.

## Issue tracking

This project tracks its own work in [beads](https://github.com/Dicklesworthstone/beads_rust):
`br` is the tracker, `bv` (binary name `bvr`, from
[beads_viewer_rust](https://github.com/Dicklesworthstone/beads_viewer_rust))
is the graph-aware triage view over it. Neither is required to use the
skills; they are required to work on this repo the way its author does.

```bash
scripts/install-beads.sh            # br + bv into ~/.local/bin
scripts/install-beads.sh --dry-run  # see what it would do first
```

`.beads/` is gitignored on purpose: the tracker's export embeds absolute
source paths, which would leak a home directory into a public tree. Issues
live locally; the JSONL never gets committed here.

## Conventions

- **Markdown and bash only. No runtime dependencies.** `package.json` exists for
  `npm test` and metadata; never add npm dependencies.
- **Every skill ships under two names.** A short one (`nss`) holding the real
  documentation, and a kebab-case alias (`new-skills-session`) that does nothing
  but delegate via the Skill tool. Add one, add both, and add both to the
  `SKILLS` array in `install.sh` and `EXPECTED_SKILLS` in `tests/run-tests.sh`.
- **A SKILL.md's front-matter `name` must equal its directory name.** Claude
  Code resolves skills by that name; a mismatch makes the skill invocable only
  under a name nobody will guess. There is a test for this.
- **No references to skills outside this repo.** It is the single easiest way to
  ship something that half-works for everyone but the author. If a skill in here
  wants to call `/foo`, either `/foo` ships here too or the reference comes out.
- **Deterministic logic goes in `scripts/`, judgment goes in SKILL.md.** This is
  the advice `/ns` gives; the repo should follow it.
- **Guard non-zero exits under `set -euo pipefail`.** `grep`, `diff`, and
  `git config --get` all exit 1 on legitimate outcomes. `scripts/` and
  `install.sh` both depend on getting this right.
- **Installers never remove what they did not install.** `install.sh` checks
  symlink targets and byte-identity; `scripts/install-beads.sh` keeps a
  manifest of SHA-256 digests and refuses to touch a binary that does not
  match it. Keep both `--uninstall` paths that conservative, and keep their
  tests offline (`--dry-run` plus hand-made manifests, never the network).
- Support bash 4.0+ and both GNU and BSD/macOS userland. `md5sum` and
  `readlink -f` are GNU-only; the iterator prefers `sha256sum` with a `shasum`
  fallback for exactly this reason.

## Before committing

```bash
./tests/run-tests.sh     # must be 0 failures
```

Tests are plain bash with no framework. Anything touching the filesystem must
work inside a `mktemp -d` scratch directory — a test that writes to the real
`~/.claude` will eventually clobber the developer's own skills. `install.sh`
takes a config directory argument specifically so tests can point it somewhere
harmless.

One test greps the whole repo for absolute home paths — anything rooted at a
Linux or macOS home directory, or at a personal working tree. If it fails,
something machine-specific leaked in; parameterize it rather than deleting the
test.

---

### Using bv as an AI sidecar

bv is a graph-aware triage engine for Beads projects (.beads/beads.jsonl). Instead of parsing JSONL or hallucinating graph traversal, use robot flags for deterministic, dependency-aware outputs with precomputed metrics (PageRank, betweenness, critical path, cycles, HITS, eigenvector, k-core).

**Scope boundary:** bv handles *what to work on* (triage, priority, planning). For agent-to-agent coordination (messaging, work claiming, file reservations), use [MCP Agent Mail](https://github.com/Dicklesworthstone/mcp_agent_mail).

**⚠️ CRITICAL: Use ONLY `--robot-*` flags. Bare `bv` launches an interactive TUI that blocks your session.**

#### The Workflow: Start With Triage

**`bv --robot-triage` is your single entry point.** It returns everything you need in one call:
- `quick_ref`: at-a-glance counts + top 3 picks
- `recommendations`: ranked actionable items with scores, reasons, unblock info
- `quick_wins`: low-effort high-impact items
- `blockers_to_clear`: items that unblock the most downstream work
- `project_health`: status/type/priority distributions, graph metrics
- `commands`: copy-paste shell commands for next steps

bv --robot-triage        # THE MEGA-COMMAND: start here
bv --robot-next          # Minimal: just the single top pick + claim command

#### Other Commands

**Planning:**
| Command | Returns |
|---------|---------|
| `--robot-plan` | Parallel execution tracks with `unblocks` lists |
| `--robot-priority` | Priority misalignment detection with confidence |

**Graph Analysis:**
| Command | Returns |
|---------|---------|
| `--robot-insights` | Full metrics: PageRank, betweenness, HITS (hubs/authorities), eigenvector, critical path, cycles, k-core, articulation points, slack |
| `--robot-label-health` | Per-label health: `health_level` (healthy\|warning\|critical), `velocity_score`, `staleness`, `blocked_count` |
| `--robot-label-flow` | Cross-label dependency: `flow_matrix`, `dependencies`, `bottleneck_labels` |
| `--robot-label-attention [--attention-limit=N]` | Attention-ranked labels by: (pagerank × staleness × block_impact) / velocity |

**History & Change Tracking:**
| Command | Returns |
|---------|---------|
| `--robot-history` | Bead-to-commit correlations: `stats`, `histories` (per-bead events/commits/milestones), `commit_index` |
| `--robot-diff --diff-since <ref>` | Changes since ref: new/closed/modified issues, cycles introduced/resolved |

**Other Commands:**
| Command | Returns |
|---------|---------|
| `--robot-burndown <sprint>` | Sprint burndown, scope changes, at-risk items |
| `--robot-forecast <id\|all>` | ETA predictions with dependency-aware scheduling |
| `--robot-alerts` | Stale issues, blocking cascades, priority mismatches |
| `--robot-suggest` | Hygiene: duplicates, missing deps, label suggestions, cycle breaks |
| `--robot-graph [--graph-format=json\|dot\|mermaid]` | Dependency graph export |
| `--export-graph <file.html>` | Self-contained interactive HTML visualization |

#### Scoping & Filtering

bv --robot-plan --label backend              # Scope to label's subgraph
bv --robot-insights --as-of HEAD~30          # Historical point-in-time
bv --recipe actionable --robot-plan          # Pre-filter: ready to work (no blockers)
bv --recipe high-impact --robot-triage       # Pre-filter: top PageRank scores
bv --robot-triage --robot-triage-by-track    # Group by parallel work streams
bv --robot-triage --robot-triage-by-label    # Group by domain

#### Understanding Robot Output

**All robot JSON includes:**
- `data_hash` — Fingerprint of source beads.jsonl (verify consistency across calls)
- `status` — Per-metric state: `computed|approx|timeout|skipped` + elapsed ms
- `as_of` / `as_of_commit` — Present when using `--as-of`; contains ref and resolved SHA

**Two-phase analysis:**
- **Phase 1 (instant):** degree, topo sort, density — always available immediately
- **Phase 2 (async, 500ms timeout):** PageRank, betweenness, HITS, eigenvector, cycles — check `status` flags

**For large graphs (>500 nodes):** Some metrics may be approximated or skipped. Always check `status`.

#### jq Quick Reference

bv --robot-triage | jq '.quick_ref'                        # At-a-glance summary
bv --robot-triage | jq '.recommendations[0]'               # Top recommendation
bv --robot-plan | jq '.plan.summary.highest_impact'        # Best unblock target
bv --robot-insights | jq '.status'                         # Check metric readiness
bv --robot-insights | jq '.Cycles'                         # Circular deps (must fix!)
bv --robot-label-health | jq '.results.labels[] | select(.health_level == "critical")'

**Performance:** Phase 1 instant, Phase 2 async (500ms timeout). Prefer `--robot-plan` over `--robot-insights` when speed matters. Results cached by data hash.

Use bv instead of parsing beads.jsonl—it computes PageRank, critical paths, cycles, and parallel tracks deterministically.
