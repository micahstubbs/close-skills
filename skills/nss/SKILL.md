---
name: nss
description: Unified skill to review the current session and create new skills from any reusable patterns found. Combines /sfs (conversation context) and /nsfst (transcript file) approaches.
---

# NSS (New Skills from Session)

Review the current session to identify reusable patterns and create new skills.
This is a convenience wrapper that combines `/sfs` (conversation context
analysis) and `/nsfst` (transcript file analysis) into a single command focused
on the current session.

## Usage

```
/nss [optional guidance on what types of patterns to look for]
```

## Process

### 1. Determine Best Source

- **If conversation context is intact** (no compaction, session still active):
  use the current conversation context directly (like `/sfs`)
- **If context has been compacted**, or you need fuller history: locate and read
  the session transcript file (like `/nsfst`)

To find the transcript:

```bash
PROJECT_DIR=$(pwd | sed 's|/|-|g' | sed 's|^-||')
ls -t ~/.claude/projects/${PROJECT_DIR}/*.jsonl 2>/dev/null | head -1
```

### 2. Identify Patterns

Scan the session for:

- **Multi-step workflows** done 2+ times or requiring careful orchestration
- **Error recovery sequences** that followed a reproducible diagnostic path
- **Cross-tool coordination** involving multiple CLI tools or services
- **File transformation pipelines** (format conversions, build chains)
- **Agent/subagent coordination** patterns
- **API interaction patterns** with auth, retry, or parsing steps

### 3. Check Existing Skills

```bash
ls ~/.claude/skills/ | sort
ls .claude/skills/ 2>/dev/null | sort
```

Skip any pattern already covered by an existing skill.

### 4. Evaluate Each Pattern

A pattern warrants a skill if it meets ALL of:

1. **Repeatable**: will plausibly occur again
2. **Complex enough**: 3+ steps, non-obvious sequencing, or easy-to-forget details
3. **Not already covered**: no existing skill handles it
4. **Has decision points**: captures the "why", not just the "what"

Skip patterns that are one-off, trivial, or too project-specific. Log those to
`LESSONS.md` via `/learn` instead.

### 5. Create Skills

For each qualifying pattern, invoke `/ns`:

```
/ns <short> <kebab-alias>: <description>
```

### 6. Report

```markdown
## Skills Created from This Session

### New Skills
- `<short>` / `<alias>`: <description>

### Patterns Skipped
- <pattern>: <reason> (already covered by X / too specific / trivial)
```

## Related Skills

| Skill | Source | Best For |
|-------|--------|----------|
| `/nss` | Context + transcript | Quick "find skills from this session" |
| `/sfs` | Conversation context only | Mid-session skill capture |
| `/nsfst` | Transcript file only | Retrospective post-session analysis |
| `/usfs` | Context + transcript | **Update existing** skills with session learnings |

## Notes

- Run near session end for maximum pattern capture
- Prefer user-level skills (more reusable) unless the pattern is clearly
  project-specific
- Skills should capture decision points and "why", not just mechanical steps
- After creating new skills with `/nss`, run `/usfs` to also enhance existing
  skills with session learnings — or just run `/close`, which does the whole
  sequence
