# Workflow Guide

## Overview

This guide describes the automated workflow for processing multiple Git repositories, making code changes according to specified tasks, and creating pull requests.

### Workspace Directory

- **`workspace/`**: Contains multiple project directories
  - Each subdirectory is a separate Git repository

## Project Configuration

Each project in the workspace has the following Git remote setup:

```
origin    → User's forked repository
upstream  → Original project repository (PR target)
```

- Default branch: `main`
- Release branches follow the pattern: `backplane-2.x`

## Workflow Process

### 1. Task Initialization

When the user initiates a task:

1. Read the contents of `task.md`
2. Parse the Records table - each row is a project to process

### 2. Project Processing Loop

For each record in the table:

#### a. Navigate to Project

```bash
cd workspace/<record.repo>
```

#### b. Prepare Repository

```bash
# Stash any uncommitted changes
git stash

# Fetch latest changes from all remotes
git fetch --all

# Checkout the specified upstream branch
git checkout upstream/<record.branch>
```

#### c. Create Feature Branch

1. Generate a short branch name (max 5 words) based on `task.description`
2. Follow Git branch naming best practices
3. Create and checkout the new branch:

```bash
git checkout -b <task_short_description>
```

#### d. Execute Task

- Implement code changes according to `task.description`
- Ensure all code comments are in English

#### e. Commit Changes

```bash
# All commits must be signed
git commit -s -m "Your commit message"
```

**Commit Requirements:**

- Use the `-s` flag for signing
- Message must be in English
- Keep messages concise (max 2 sentences)

#### f. Create Pull Request

Use GitHub CLI to create PR from fork to upstream:

```bash
gh pr create \
  --repo <org>/<repo-name> \
  --base <base-branch> \
  --head <github-username>:<branch-name> \
  --title "..." \
  --body $'...'
```

**PR Requirements:**

- Always target the upstream repository
- Default base branch is `main` unless specified
- Title must be concise and in English
- Description should use markdown format with detailed reasoning
- Use `$'...'` syntax for proper escape sequence handling

## Important Notes

### Git Commands

- List branches: `git --no-pager branch`
- Get current username: `git config --get user.name`

### Code Standards

- All code comments must be in English
- Never use non-English characters in code comments

### Error Handling

- If a project fails, mark `pass` as `no` and provide a clear explanation in `result`
- Continue processing remaining projects even if one fails

## Quick Reference

| Action                   | Command                                     |
| ------------------------ | ------------------------------------------- |
| Stash changes            | `git stash`                                 |
| Fetch all remotes        | `git fetch --all`                           |
| Checkout upstream branch | `git checkout upstream/<branch>`            |
| Create feature branch    | `git checkout -b <branch-name>`             |
| Signed commit            | `git commit -s -m "message"`                |
| Create PR                | `gh pr create --repo <org>/<repo> ...`      |
