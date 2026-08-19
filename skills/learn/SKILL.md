---
name: learn
description: Document debugging lessons in LESSONS.md after completing a debugging session or discovering important patterns
---

# Learn — Document Debugging Lessons

## When to Use

Use this skill after:

- Completing a debugging session
- Fixing a complex bug
- Discovering an important pattern or anti-pattern
- Finding a non-obvious solution to a problem
- Learning something that would benefit future debugging

## Usage

```
/learn                       # add a lesson from the current session
/learn from recent commits   # mine the last chunk of git history for lessons
/learn status                # progress of a systematic history review
/learn reset                 # start the history review over
```

## The Process

### Step 1: Locate LESSONS.md

Look for an existing lessons file, in this order:

1. `LESSONS.md` at the project root
2. `docs/LESSONS.md`

If neither exists, create `LESSONS.md` at the project root with a short header.
If one exists, append to it — the file is append-only.

### Step 2: Format the Lesson

```markdown
## YYYY-MM-DDTHH:MM - Brief Title

**Problem**: Clear description of what went wrong

**Root Cause**: Technical explanation of why it happened

**Lesson**: Generalizable insight to learn

**Code Issue** (if applicable):

    // Before (broken)
    ...

    // After (fixed)
    ...

**Solution**: What was done to fix it

**Prevention**: How to avoid this in future
```

### Step 3: Append

**LESSONS.md is append-only:**

- Do NOT edit previous entries
- Do NOT reorganize or refactor
- Do NOT "improve" old lessons
- ONLY append new lessons at the end

The value of the file comes from it being an honest record. A lesson rewritten
later to sound smarter is a lesson you will not trust when you need it.

### Step 4: Update Meta-Lessons (optional)

If the lesson represents a broader pattern, add to the "Meta-Lessons" section at
the end of the file. Add new insights; don't remove old ones.

### Step 5: Commit

```bash
git add LESSONS.md
git commit -m "docs(lessons): add [brief description of lesson]"
```

## Mining Git History

When you want lessons from work that predates this session — or the user asks
for "lessons from older commits" — walk the history in chunks instead of trying
to read it all at once. The helper script tracks where you left off, per
repository:

```bash
~/.claude/scripts/git-commit-iterator.sh . status   # progress so far
~/.claude/scripts/git-commit-iterator.sh . next     # next 50 commits
~/.claude/scripts/git-commit-iterator.sh . reset    # start over
```

Progress is keyed by the repo's `origin` remote (or its path, if there is no
remote) and stored under `~/.claude/.learn-progress/`, so running `next`
repeatedly walks steadily backwards through history rather than re-reading the
same commits.

Workflow for a chunk:

1. Run `status`. If it reports COMPLETED, say so and ask whether to `reset`
   rather than silently reprocessing.
2. Run `next` to get the chunk.
3. Scan subjects for `fix`, `bug`, `issue`, `resolve`, `correct`, `patch`.
4. Read the diffs behind the interesting ones.
5. Extract 2–4 genuine lessons — not one per commit.
6. Append them and commit. The iterator has already advanced its offset.

Stop when the iterator reports complete, when the user says so, or when the
chunk stops yielding anything generalizable.

## Guidelines

### What Makes a Good Lesson

**Good:**

- Specific root cause identified
- Generalizable to other projects
- Includes prevention strategy
- Shows before/after code
- Explains WHY, not just WHAT

**Bad:**

- Vague problem description
- Project-specific details only
- No prevention strategy
- Missing root cause analysis
- Just describing a fix without insight

### Lesson Categories

- **Infrastructure**: Build tools, module systems, dependencies
- **Configuration**: Environment variables, credentials, URLs
- **Protocols**: Format and transport mismatches
- **Integration**: API handshakes, session identifiers, state management
- **Performance**: Logging verbosity, resource leaks, bottlenecks
- **Testing**: Test isolation, cleanup, mocking strategies

### Meta-Lessons

Track broader patterns across multiple lessons:

- What debugging approaches work best?
- What types of issues are most common?
- What preventive measures are most effective?

## Example

> **User:** We just spent the afternoon debugging why audio flowed one
> direction but not the other.
>
> **Claude:** I'll use the learn skill to document this.

Appended to `LESSONS.md`:

```markdown
## 2026-01-14T14:30 - Missing Session Identifier in Bidirectional Protocol

**Problem**: Audio flowed from client to server but never back...
```

## Success Criteria

- Lesson appended to LESSONS.md
- Includes all required sections
- Timestamp included
- Previous entries unchanged
- Committed with a descriptive message
- Generalizable insight captured

## Remember

The goal is a knowledge base that prevents future bugs, speeds up debugging,
captures non-obvious solutions, and survives the people who wrote it. Every
debugging session should end with `/learn` while the insight is still fresh.
