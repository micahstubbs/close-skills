---
name: ns
description: Create a new skill with a short abbreviated name and a kebab-case alias
---

# NS (New Skill)

Create a new skill with both a short memorable name and a descriptive kebab-case
alias, so it can be invoked either way.

## Usage

```
/ns <short-name> <kebab-case-alias>: <description of what the skill does>
/ns project <short-name> <kebab-case-alias>: <description>   # project-level skill
```

## Skill Levels

| Level | Location | Scope |
|-------|----------|-------|
| **User** (default) | `~/.claude/skills/` | Available in all projects |
| **Project** | `.claude/skills/` | Only available in the current project |

Use the `project` keyword to create a project-level skill. Otherwise skills are
created at user level.

**Level is a judgment call, not just a keyword.** Even when the request doesn't
say "project", prefer project level when the workflow depends on repo-local
scripts or config — a skill whose steps run `scripts/foo.mjs` from one repo — or
when a sibling skill for the same domain already lives in that repo's
`.claude/skills/`. A user-level skill that can't run outside one repo is just
clutter in every other project.

## Examples

```
# User-level skills (default)
/ns mc multi-commit: create multiple commits grouping related changes
/ns rp release-prep: run the checks and version bump before tagging a release

# Project-level skills
/ns project dp deploy-production: deploy to the production environment
/ns project ts test-setup: run this repo's test fixtures and seed data
```

## Process

### 1. Parse Arguments

Extract from the arguments:

- **Level**: check for the `project` keyword (default: user)
- **Short name**: 2–4 character abbreviation
- **Alias name**: kebab-case descriptive name
- **Description**: what the skill does

### 2. Determine Base Path

```bash
BASE_PATH="$HOME/.claude/skills"   # user level (default)
BASE_PATH=".claude/skills"         # project level
```

### 3. Create the Primary Skill

```bash
mkdir -p "$BASE_PATH/<short-name>"
```

Write `$BASE_PATH/<short-name>/SKILL.md`:

```markdown
---
name: <short-name>
description: <description>
---

# <SHORT-NAME> (<Expanded Name>)

<Description of what this skill does.>

## Usage

/<short-name> [arguments]

## Process

[Document the workflow steps]

## Notes

[Any additional guidance]
```

### 4. Create the Alias Skill

```bash
mkdir -p "$BASE_PATH/<kebab-case-alias>"
```

Write `$BASE_PATH/<kebab-case-alias>/SKILL.md`:

```markdown
---
name: <kebab-case-alias>
description: Alias for <short-name> - <description>
---

# <Title Case Alias> (Alias)

This is an alias for the `<short-name>` skill.

## Usage

Use `/<kebab-case-alias>` or `/<short-name>` - both invoke the same skill.

## Instructions

When this skill is invoked, immediately use the Skill tool to run
`<short-name>` with the provided arguments.
```

### 5. Commit Both Skills

Project-level skills live in the project repo, so committing them is the normal
git flow:

```bash
git add .claude/skills/<short-name>/ .claude/skills/<kebab-case-alias>/
git commit -m "Add <short-name> skill with <kebab-case-alias> alias: <brief description>"
```

User-level skills live in `~/.claude/skills/`. Commit them the same way **if**
that directory is under version control:

```bash
git -C ~/.claude add skills/<short-name>/ skills/<kebab-case-alias>/
git -C ~/.claude commit -m "Add <short-name> skill with <kebab-case-alias> alias"
```

If `~/.claude` is not a git repo, skip this step — the skill works either way.
Check with `git -C ~/.claude rev-parse --git-dir` before assuming.

## Naming Conventions

### Short Names (2–4 chars)

- Memorable abbreviation, usually the initials of the full name
- Mnemonic beats clever — it has to be guessable months later

### Alias Names (kebab-case)

- Full descriptive name, hyphen-separated
- Verb-noun or action-object pattern: `multi-commit`, `deploy-production`

## Output

```
Created skill: <short-name>
  Level: user (or project)
  Path: ~/.claude/skills/<short-name>/SKILL.md

Created alias: <kebab-case-alias>
  Path: ~/.claude/skills/<kebab-case-alias>/SKILL.md

Committed: "Add <short-name> skill with <kebab-case-alias> alias"
```

## Prefer Deterministic Scripts

**When creating skills, prefer to implement deterministic logic in shell scripts
rather than in the SKILL.md instructions.**

### Why Scripts?

- **Reproducibility**: a script executes the same way every time
- **Testability**: a script can be tested independently
- **Versioning**: script changes are legible in a diff
- **Reusability**: a script can be called from the CLI, other skills, or CI
- **Debugging**: easier to debug a script than a model's reading of prose

### Script Guidelines

1. **Put scripts in `~/.claude/scripts/`** for user-level skills, or the
   project's own `scripts/` for project-level ones
2. **Name the script after the skill**: `<skill-name>.sh` or `<skill-name>.py`
3. **Make it self-documenting**: support `--help`, print clear usage
4. **Handle errors deliberately**: `set -euo pipefail`, but watch the pitfalls below
5. **Reference the script from SKILL.md**, with the exact invocation
6. **Smoke-test before committing**: run the happy path at least once. The bash
   gotchas below stay silent until a specific branch is exercised

### Common `set -euo pipefail` Pitfalls

These bash patterns fail silently under `set -euo pipefail` and have burned
skill authors repeatedly:

| Pattern | Problem | Fix |
|---------|---------|-----|
| `x=$(cmd \| grep foo \| head -1)` where grep may find nothing | `grep` exits 1, `pipefail` propagates it, `set -e` kills the script mid-run with no message | `x=$(... \|\| true)` |
| `((COUNTER++))` when `COUNTER=0` | `(())` returns exit 1 when the post-increment evaluates to 0 | `COUNTER=$((COUNTER + 1))` |
| `${ARRAY[@]}` on an empty array, bash < 4.4 | `set -u` raises "unbound variable" | `"${ARRAY[@]+${ARRAY[@]}}"`, or guard with `[[ ${#ARRAY[@]} -gt 0 ]]` |
| `diff a b` as a condition | `diff` exits 1 on differences, which is not an error | `diff a b \|\| true`, or `if ! diff ...` |
| `grep -c foo file` to count matches | `grep` exits 1 when the count is 0 | append `\|\| true` |
| `cmd \| tee /dev/null` inside a substitution | `tee` can return non-zero on EPIPE | append `\|\| true`, or restructure |

Rule of thumb: **any command whose legitimate success value includes a non-zero
exit code must be guarded under `pipefail`**. The canonical offenders are
`grep`, `diff`, and `pgrep`.

### Example Structure

```
~/.claude/
├── scripts/
│   └── my-skill.sh       # deterministic logic
└── skills/
    └── ms/
        └── SKILL.md      # invokes ~/.claude/scripts/my-skill.sh
```

### What Goes Where?

| In the script | In SKILL.md |
|---------------|-------------|
| File operations | Context-dependent decisions |
| API calls with fixed parameters | Interpreting user intent |
| Data transformations | Asking clarifying questions |
| Validation logic | Explaining results to the user |
| Error handling | Adapting to unusual situations |

## Notes

- **Default is user-level** — skills go to `~/.claude/skills/` unless `project`
  is specified
- If arguments are incomplete, ask for clarification
- The primary skill holds the full documentation; the alias just redirects
- Always create and commit both together, or the alias silently rots
