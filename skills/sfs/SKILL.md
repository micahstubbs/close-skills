---
name: sfs
description: Analyze the current conversation session to identify reusable patterns and create skills for general tasks (user-level) and project-specific tasks (project-level) that don't already have corresponding skills
---

# SFS (Skills From Session)

Analyze the current conversation session to identify reusable patterns and
workflows worth capturing as skills. Creates user-level skills for general tasks
and project-level skills for project-specific ones.

## Usage

```
/sfs [optional guidance on what types of skills to look for]
```

## Process

### 1. Analyze Session Context

Review the current conversation to identify:

- **Repeated patterns**: tasks done multiple times with similar steps
- **Complex workflows**: multi-step processes that required careful orchestration
- **Domain expertise**: specialized knowledge applied to solve a problem
- **Error recovery**: debugging or troubleshooting paths that worked
- **Automation opportunities**: manual tasks that could be streamlined

### 2. Check Existing Skills

Before creating anything, verify it doesn't already exist:

```bash
ls ~/.claude/skills/                                     # user level
ls .claude/skills/ 2>/dev/null || echo "no project skills"   # project level
```

### 3. Categorize Identified Patterns

| Category | Skill Level | Examples |
|----------|-------------|----------|
| **General tasks** | User (`~/.claude/skills/`) | Git workflows, debugging patterns, code review |
| **Project-specific** | Project (`.claude/skills/`) | Deploy steps, this repo's test setup |

### 4. Create Skills Using /ns

```
# User-level (general)
/ns <short-name> <kebab-case-alias>: <description>

# Project-level (specific)
/ns project <short-name> <kebab-case-alias>: <description>
```

### 5. Report Created Skills

```markdown
## Skills Created from Session

### User-Level Skills (general)
- `<short-name>` / `<alias>`: <description>

### Project-Level Skills (project-specific)
- `<short-name>` / `<alias>`: <description>

### Patterns Identified but Not Converted
- <pattern>: <reason not converted to a skill>
```

## Identification Criteria

A pattern is worth converting to a skill if:

1. **Reusability**: it will be used again
2. **Complexity**: it has multiple steps that are easy to forget or get wrong
3. **Consistency**: it benefits from being done the same way each time
4. **Documentation value**: it captures knowledge that would otherwise be lost

A pattern should NOT become a skill if:

1. **One-off**: unlikely to be repeated
2. **Trivial**: simple enough not to need documentation
3. **Already exists**: covered by an existing skill
4. **Too specific**: only applies to one unique situation

## Example Session Analysis

**Session activities:**

1. Provisioned a VM with a particular security configuration
2. Debugged a memory leak by bisecting a config change
3. Split a large working tree into several focused commits
4. Converted a directory of documents into a single report

**Skill recommendations:**

- VM provisioning: good user-level candidate — multi-step, easy to get wrong,
  and the security defaults are the part people forget
- Memory-leak debugging: check first. Generic debugging methodology is usually
  already covered by an existing skill; don't duplicate it
- Multi-commit splitting: check first, same reason
- Document-to-report conversion: user-level candidate if the pipeline has
  non-obvious steps; skip it if it's one `pandoc` invocation

The pattern to notice: two of the four were probably already covered. Checking
step 2 honestly is what keeps a skill set usable.

## Notes

- Focus on patterns that appeared naturally during problem-solving
- Don't force every action into a skill — only genuinely reusable ones
- When in doubt about user vs project level, prefer user-level (more reusable)
- Skills should capture the "why" and the decision points, not just mechanical
  steps
- Reference existing skills when a pattern is already covered
