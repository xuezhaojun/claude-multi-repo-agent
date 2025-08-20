# Claude Multi-Repo Agent

This project provides an automated system for executing Claude Code tasks across multiple GitHub repositories simultaneously.

## Project Overview

**Claude Multi-Repo Agent** is a universal automation toolkit that:
- Executes tasks across multiple GitHub repositories and branches
- Automatically manages repository forks and clones
- Organizes task scenarios using predefined bundles
- Generates individual task files for each target repository-branch combination
- Leverages Claude Code for intelligent task execution

## Key Components

### Core Files
- `gen-and-run-tasks.sh`: Main automation script (generate + execute)
- `target.yml`: Repository and branch configuration (root mode)
- `task.md`: Task description and requirements (root mode)
- `GUIDE.md`: Optional workflow instructions

### Bundle Organization
- `bundles/`: Directory containing task scenario bundles
  - `bundles/scenario-name/target.yml`: Bundle-specific repository configuration
  - `bundles/scenario-name/task.md`: Bundle-specific task description
- Examples: `bundles/upgrade-deps/`, `bundles/security-patch/`, `bundles/docs-sync/`

### Directory Structure
- `workspace/`: Auto-managed repository clones with upstream remotes
- `tasks/`: Generated task files (format: `001_repo_branch.md`)
- `logs/`: Execution logs (when using `--save-logs`)
- `bundles/`: Task scenario bundles (NEW)

## Configuration Format

### target.yml Structure
```yaml
target:
  - org: organization-name    # GitHub organization
    repos: [repo1, repo2]     # Repository names
    branches: [main, develop] # Target branches
```

### Bundle Structure
Each bundle is a directory containing:
```
bundles/scenario-name/
├── target.yml    # Bundle-specific repository and branch configuration
└── task.md       # Bundle-specific task description and requirements
```

### Task File Template
Each generated task file contains:
- Repository metadata (org, repo, branch, workspace path)
- Workflow guide (from GUIDE.md - always from root)
- Task description (from task.md - either root or bundle)

## Automation Workflow

1. **Repository Setup**: Automatically forks and clones repositories if not present in workspace
2. **Task Generation**: Creates individual task files for each org/repo/branch combination
3. **Task Execution**: Runs Claude Code on each task file
4. **Progress Tracking**: Provides execution summaries and optional logging

## Usage Patterns

### Standard Workflow (Root Configuration)
```bash
./gen-and-run-tasks.sh              # Generate and execute all tasks
./gen-and-run-tasks.sh --save-logs  # With logging
```

### Bundle Workflow (Recommended)
```bash
./gen-and-run-tasks.sh --bundle bundles/upgrade-deps     # Execute dependency update bundle
./gen-and-run-tasks.sh --bundle bundles/security-patch  # Execute security patch bundle
./gen-and-run-tasks.sh --bundle bundles/docs-sync       # Execute documentation sync bundle
```

### Advanced Options
```bash
./gen-and-run-tasks.sh --generate-only                    # Only generate task files
./gen-and-run-tasks.sh --run-only                         # Execute existing tasks
./gen-and-run-tasks.sh --bundle bundles/scenario --generate-only  # Generate from bundle only
./gen-and-run-tasks.sh --bundle bundles/scenario --guide-file custom-guide.md  # Bundle + custom guide
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

## Bundle Examples

### Common Bundle Scenarios

1. **Dependency Updates** (`bundles/upgrade-deps/`)
   - Target: Development repositories across multiple organizations
   - Task: Update package.json, requirements.txt, go.mod, etc.

2. **Security Patches** (`bundles/security-patch/`)
   - Target: Production and security-critical repositories
   - Task: Apply CVE fixes and security updates

3. **Documentation Sync** (`bundles/docs-sync/`)
   - Target: Documentation repositories and websites
   - Task: Synchronize content, update links, standardize formatting

4. **Compliance Updates** (`bundles/compliance/`)
   - Target: All organizational repositories
   - Task: Update license headers, add security policies, standardize configurations

---

This tool is designed for batch operations like dependency updates, security patches, documentation synchronization, and configuration standardization across repository ecosystems. The bundle system enables organized, reusable task scenarios for efficient multi-repository management.