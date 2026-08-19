---
name: usfs
description: Review session and transcript to find new patterns, facts, or instructions to add to EXISTING skills. Continuous self-learning - updates and enhances current skills rather than creating new ones.
---

# USFS (Update Skills From Session)

Review the current session (and optionally its transcript) to find new patterns,
information, facts, or instructions that should be added to **existing** skills.
This is the continuous self-improvement counterpart to `/nss`, which creates new
ones.

## Usage

```
/usfs [optional guidance on what to look for]
```

## How It Differs from /nss and /sfs

| Skill | Purpose |
|-------|---------|
| `/sfs` | Create **new** skills from session patterns |
| `/nss` | Create **new** skills (combines sfs + nsfst) |
| `/nsfst` | Create **new** skills from transcript file |
| **`/usfs`** | **Update existing** skills with session learnings |

## Process

### 1. Gather Session Context

Use both conversation context and transcript:

```bash
# Find transcript for fuller history
PROJECT_DIR=$(pwd | sed 's|/|-|g' | sed 's|^-||')
ls -t ~/.claude/projects/${PROJECT_DIR}/*.jsonl 2>/dev/null | head -1
```

If context has been compacted, read the transcript file for complete history.

### 2. Identify Learnings

Scan the session for:

- **New techniques** applied that an existing skill should document
- **Edge cases** encountered that a skill should warn about
- **Better approaches** discovered that replace or supplement current guidance
- **New tool integrations** or flags used within an existing skill's domain
- **Failure modes** hit that a skill should help avoid
- **Updated APIs/CLIs** where a skill references outdated syntax
- **Missing steps** in a skill's workflow that the session revealed are needed
- **New decision criteria** that would improve a skill's guidance

### 3. Map Learnings to Existing Skills

```bash
ls ~/.claude/skills/ | sort
ls .claude/skills/ 2>/dev/null | sort
```

For each learning, identify which existing skill it belongs to. Skip learnings
that:

- Don't map to any existing skill (suggest `/nss` for those)
- Are already documented in the skill
- Are too project-specific for a user-level skill (add to the project's
  `CLAUDE.md` instead)
- Are one-off situations unlikely to recur

### 4. Read and Update Skills

For each skill that needs updating:

1. **Read the current SKILL.md** to understand existing content
2. **Identify where the new information fits** — new section, additional bullet,
   updated example
3. **Edit the skill** — add the new information in the appropriate location
4. **Preserve existing content** — add to, don't replace, unless you are
   correcting something that is now wrong

### 5. Also Check CLAUDE.md Files

Some learnings belong in `CLAUDE.md` rather than a skill — general rules and
conventions, as opposed to a workflow you invoke by name.

```bash
cat ~/.claude/CLAUDE.md 2>/dev/null | head -20     # user level
cat CLAUDE.md 2>/dev/null | head -20               # project level
```

### 6. Report

```markdown
## Skills Updated

### Modified Skills
- `<skill-name>`: <what was added/changed and why>

### CLAUDE.md Updates
- <user|project>: <what was added/changed>

### Learnings Not Applied
- <learning>: <reason> (already documented / too specific / suggest /nss)

### Suggested New Skills
- <pattern>: <brief description> (run /nss to create)
```

## Principles

- **Additive by default**: enhance skills, don't rewrite them
- **Evidence-based**: only add learnings validated by actual session experience
- **Contextual**: include the "why" — what situation revealed this learning
- **Conservative**: when unsure whether something belongs, skip it rather than
  clutter a skill
- **Cross-reference**: if a learning spans multiple skills, add it to the most
  relevant one and reference it from the others

## Notes

- Run near session end, after `/nss` — create new skills first, then enhance
  existing ones, so the same pattern doesn't land in both
- Pairs with `/learn` for project-specific lessons
- This is the self-improvement loop: each session makes the skill set a little
  sharper
- Review the diff before committing. Skills that grow without pruning stop
  being read
