---
name: nsfst
description: Analyze a session's JSONL transcript file to identify reusable patterns and create new skills. Reads the actual transcript from disk rather than relying on conversation context (useful after compaction or for retrospective analysis).
---

# NSFST (New Skills From Session Transcript)

Analyze a session's JSONL transcript file to identify reusable workflows and
create new skills. Unlike `/sfs`, which reads the current conversation context,
this skill reads the raw transcript from disk — which is what you want after
context compaction, or when looking back at a session that already ended.

## Usage

```
/nsfst [optional: path to a specific .jsonl transcript file]
```

If no path is provided, finds the most recent session transcript automatically.

## Process

### 1. Locate Transcript

Claude Code stores transcripts under `~/.claude/projects/`, in a directory named
after the project path with `/` replaced by `-`:

```bash
PROJECT_DIR=$(pwd | sed 's|/|-|g' | sed 's|^-||')
ls -t ~/.claude/projects/${PROJECT_DIR}/*.jsonl 2>/dev/null | head -1
```

If a specific path was provided as an argument, use that instead.

### 2. Extract Patterns from Transcript

Read and analyze the transcript. Focus on:

- **Multi-step workflows**: tasks that required 3+ sequential steps
- **API interaction patterns**: external calls with auth, retry, or parse steps
- **Error recovery sequences**: how errors were diagnosed and fixed
- **Cross-tool coordination**: patterns spanning multiple CLI tools or services
- **File transformation pipelines**: format conversions, build steps
- **Agent coordination**: patterns for directing work to subagents

Transcripts get large. Don't read a multi-megabyte JSONL file front to back —
grep for the tools that actually appeared, then read around the hits:

```bash
# Which command-line tools show up in this session at all?
grep -oE '"command":"[^"]{0,80}' transcript.jsonl \
  | sed 's/.*"command":"//' | awk '{print $1}' | sort | uniq -c | sort -rn | head -20
```

Start from that frequency list: a tool invoked once is noise, a tool invoked
eight times in a particular order is a candidate skill.

### 3. Check for Existing Coverage

```bash
ls ~/.claude/skills/ | sort
ls .claude/skills/ 2>/dev/null | sort
```

Only create skills for patterns NOT already covered.

### 4. Evaluate Each Pattern

A pattern warrants a skill if it meets ALL of:

1. **Repeatable**: will plausibly occur again
2. **Complex enough**: 3+ steps, non-obvious sequencing, or easy-to-forget details
3. **Not already covered**: no existing skill handles it
4. **Has decision points**: captures the "why", not just the "what"

Patterns that are one-off, trivial, or too project-specific should be skipped —
or sent to `LESSONS.md` via `/learn` instead.

### 5. Create Skills

```
# User-level (reusable across projects)
/ns <short> <kebab-alias>: <description>

# Project-level (project-specific)
/ns project <short> <kebab-alias>: <description>
```

### 6. Report

```markdown
## Skills Created

### New User-Level Skills
- `<short>` / `<alias>`: <description>

### New Project-Level Skills
- `<short>` / `<alias>`: <description>

### Patterns Skipped
- <pattern>: <reason> (already covered by X / too specific / trivial)

### Patterns Logged to LESSONS.md
- <pattern>: <reason it's a lesson, not a skill>
```

## Difference from /sfs

| Feature | `/sfs` | `/nsfst` |
|---------|--------|----------|
| Source | Current conversation context | Transcript file on disk |
| Works after compaction | No | Yes |
| Works retrospectively | No | Yes |
| Best for | In-session skill capture | Post-session analysis |

## Notes

- If the transcript is over ~10MB, sample it with grep/awk rather than reading
  it whole
- Prefer `LESSONS.md` for project-specific gotchas; prefer skills for reusable
  workflows
- `/sfs` is the in-session variant — use that while the conversation is live
- `/nss` picks between the two automatically, and is usually the one to reach for
