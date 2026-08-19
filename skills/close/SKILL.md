---
name: close
description: End-of-session knowledge capture - run /learn then /nss then /usfs to document lessons, create new skills, and update existing skills
---

# Close

Run the end-of-session knowledge capture sequence: document lessons learned,
create new skills from session patterns, and update existing skills with
session learnings.

## Usage

```
/close
```

## Process

### 1. Document Lessons (`/learn`)

Capture any debugging insights, non-obvious solutions, or important patterns
discovered during the session. These land in the project's `LESSONS.md` —
append-only, project-scoped, the things that are true here but nowhere else.

```
Invoke: /learn
```

### 2. Create New Skills (`/nss`)

Review the session for reusable patterns that should become new skills. This is
the "did I just do something worth doing the same way next time?" pass.

```
Invoke: /nss
```

### 3. Update Existing Skills (`/usfs`)

Review the session for learnings that belong in skills you already have — new
flags, new failure modes, a step that turned out to be missing.

```
Invoke: /usfs
```

## Why this order

Each step has a different destination, and running them in this order keeps
material from landing in the wrong one:

| Step | Captures | Destination |
|------|----------|-------------|
| `/learn` | Project-specific gotchas and root causes | `LESSONS.md` in the project |
| `/nss` | Reusable workflows not yet covered | New skill directories |
| `/usfs` | Refinements to workflows already covered | Existing `SKILL.md` files |

`/learn` first, because a lesson is the cheapest thing to write down and the
easiest to lose. `/nss` before `/usfs`, because a pattern that becomes a new
skill should not also be pasted into a neighboring one.

## Notes

- Run at the end of any session with substantial work
- Each step is independent — if one finds nothing to do, move to the next
- Nothing here is destructive: `/learn` appends, `/nss` creates, `/usfs` edits
  additively
- Commit after all three complete
