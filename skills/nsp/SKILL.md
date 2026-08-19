---
name: nsp
description: Create a new skill by describing what it does - short name and alias are auto-picked
---

# NSP (New Skill Pick)

Like `/ns`, but you only provide the description. The short name and kebab-case
alias are chosen for you.

## Usage

```
/nsp <description of what the skill does>
/nsp Build and deploy a container image to a cloud provider
/nsp Summarize a long video transcript into bullet points
/nsp project Export database tables to CSV files
```

Add `project` as the first word to create a project-level skill, same as `/ns`.

## Process

### 1. Parse the Description

Extract:

- **Level**: check for the `project` keyword (default: user)
- **Description**: everything else

### 2. Pick Names

**Short name (2–4 chars):**

- Initials of the key action words
- Avoid collisions with existing skills — list `~/.claude/skills/` first
- Prefer 2–3 characters for common actions

**Alias name (kebab-case):**

- Verb-noun pattern describing the action
- Concise but unambiguous, 2–4 words

| Description | Short | Alias |
|-------------|-------|-------|
| "Build and deploy a container to the cloud" | `dd` | `docker-deploy` |
| "Export database tables to CSV" | `dex` | `db-export` |
| "Summarize a video transcript" | `vts` | `video-summary` |
| "Rotate and re-deploy an API credential" | `rc` | `rotate-credential` |

### 3. Delegate to /ns

Invoke the `ns` skill with the chosen names:

```
/ns <short-name> <alias-name>: <description>
```

## Guidelines

- Prefer short names that are mnemonic — related to the action, not generic
- Check existing skills to avoid name collisions before committing to a name
- If the description is ambiguous, ask the user to clarify before picking names
- For `project` level, pass the keyword through to `/ns`

## Notes

- This is a convenience wrapper around `/ns`; all of its conventions apply
- If you're unsure about a name, pick the best option and proceed — renaming
  later is two `mv`s and an edit
