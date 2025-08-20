# Claude Multi-Repo Agent

This project provides an automated system for executing Claude Code tasks across multiple GitHub repositories simultaneously.

## Project Overview

**Claude Multi-Repo Agent** is a universal automation toolkit that:
- Executes tasks across multiple GitHub repositories and branches
- Automatically manages repository forks and clones
- Generates individual task files for each target repository-branch combination
- Leverages Claude Code for intelligent task execution

## Key Components

### Core Files
- `gen-and-run-tasks.sh`: Main automation script (generate + execute)
- `target.yml`: Repository and branch configuration
- `task.md`: Task description and requirements
- `GUIDE.md`: Optional workflow instructions

### Directory Structure
- `workspace/`: Auto-managed repository clones with upstream remotes
- `tasks/`: Generated task files (format: `001_repo_branch.md`)
- `logs/`: Execution logs (when using `--save-logs`)

## Configuration Format

### target.yml Structure
```yaml
target:
  - org: organization-name    # GitHub organization
    repos: [repo1, repo2]     # Repository names
    branches: [main, develop] # Target branches
```

### Task File Template
Each generated task file contains:
- Repository metadata (org, repo, branch, workspace path)
- Workflow guide (from GUIDE.md)
- Task description (from task.md)

## Automation Workflow

1. **Repository Setup**: Automatically forks and clones repositories if not present in workspace
2. **Task Generation**: Creates individual task files for each org/repo/branch combination
3. **Task Execution**: Runs Claude Code on each task file
4. **Progress Tracking**: Provides execution summaries and optional logging

## Usage Patterns

### Standard Workflow
```bash
./gen-and-run-tasks.sh              # Generate and execute all tasks
./gen-and-run-tasks.sh --save-logs  # With logging
```

### Advanced Options
```bash
./gen-and-run-tasks.sh --generate-only  # Only generate task files
./gen-and-run-tasks.sh --run-only       # Execute existing tasks
```

## Git Integration

The system automatically:
- Checks for existing repository forks
- Creates forks if needed using GitHub CLI
- Clones forked repositories to workspace
- Sets up upstream remotes for PR workflows
- Handles multiple organizations and repositories

## Requirements

- Claude Code CLI (authenticated)
- GitHub CLI `gh` (authenticated)
- `yq` (optional, for better YAML parsing)
- Bash shell environment

---

This tool is designed for batch operations like dependency updates, security patches, documentation synchronization, and configuration standardization across repository ecosystems.