# Claude Multi-Repo Agent

A powerful automation toolkit that leverages Claude Code to execute tasks across multiple GitHub repositories simultaneously. Perfect for batch operations, code maintenance, and cross-repository updates.

## ✨ Key Features

- 🔄 **Multi-Repository Processing**: Execute tasks across multiple repositories
- ⚡ **Parallel Execution**: Speed up processing with concurrent repository groups
- 🍴 **Smart Fork Management**: Automatically forks and clones repositories if needed
- 🎯 **Flexible Targeting**: Configure organizations, repositories, and branches with ease
- 📦 **Bundle Support**: Organize task scenarios with predefined target/task combinations
- 🤖 **Claude-Powered**: Leverages Claude Code for intelligent task execution
- 📊 **Progress Tracking**: Comprehensive logging and execution summaries
- 🚀 **One-Click Automation**: Generate and run tasks with a single command

## 🚀 Quick Start

### Prerequisites

- [Claude Code CLI](https://claude.ai/code) installed and authenticated
- [GitHub CLI (`gh`)](https://cli.github.com/) installed and authenticated
- `yq` (optional, for better YAML parsing)

### 1. Clone and Setup

```bash
git clone git@github.com:stolostron/claude-multi-repo-agent.git
cd claude-multi-repo-agent
```

### 2. Configure Your Task

Choose one of two approaches to configure your tasks:

#### Option A: Direct Configuration (Traditional)

Create or edit the configuration files in the root directory:

##### `target.yml` - Define target repositories
```yaml
target:
  - org: facebook           # GitHub organization
    repos: [react, create-react-app]
    branches: [main, develop]
  - org: microsoft
    repos: [vscode]
    branches: [main]
```

##### `task.md` - Define your task
```markdown
# Task Description
Update all package.json files to use Node.js 18 as the minimum version.

## Requirements
- Change "node": ">=16.0.0" to "node": ">=18.0.0"
- Update any related documentation
- Ensure tests still pass
```

#### Option B: Bundle Configuration (Recommended)

Organize predefined scenarios using bundles:

```bash
# Create bundle directories for different scenarios
mkdir -p bundles/upgrade-deps
mkdir -p bundles/security-patch
mkdir -p bundles/docs-sync
```

Each bundle contains its own `target.yml` and `task.md`:

```
bundles/
├── upgrade-deps/
│   ├── target.yml      # Repositories for dependency updates
│   └── task.md         # Dependency upgrade instructions
├── security-patch/
│   ├── target.yml      # Security-critical repositories
│   └── task.md         # Security patch tasks
└── docs-sync/
    ├── target.yml      # Documentation repositories
    └── task.md         # Documentation sync tasks
```

#### `GUIDE.md` - Task execution guidelines (always in root)
```markdown
# Custom Workflow Guide

Provides standardized workflow instructions that guide how each task should be executed.
Includes guidelines from feature development to PR submission.

Users can customize the entire workflow by specifying their own guide file.
```

### 3. Execute Tasks

#### Standard Execution (using root configuration)
```bash
# All-in-one execution
./gen-and-run-tasks.sh

# Parallel execution for faster processing
./gen-and-run-tasks.sh --parallel

# Step-by-step execution
./gen-and-run-tasks.sh --generate-only
./gen-and-run-tasks.sh --run-only
```

#### Bundle Execution (using predefined scenarios)
```bash
# Execute specific bundle
./gen-and-run-tasks.sh --bundle bundles/upgrade-deps

# Execute bundle in parallel (faster)
./gen-and-run-tasks.sh --bundle bundles/upgrade-deps --parallel

# Generate tasks from bundle only
./gen-and-run-tasks.sh --bundle bundles/security-patch --generate-only

# Save execution logs (automatically enabled in parallel mode)
./gen-and-run-tasks.sh --bundle bundles/docs-sync --save-logs
```

#### Advanced Options
```bash
# Use custom guide file
./gen-and-run-tasks.sh --guide-file my-custom-guide.md

# Combine bundle with custom guide
./gen-and-run-tasks.sh --bundle bundles/upgrade-deps --guide-file guides/company-workflow.md

# Parallel execution with custom concurrency
./gen-and-run-tasks.sh --parallel --max-jobs 8

# Combine all features
./gen-and-run-tasks.sh --bundle bundles/upgrade-deps --parallel --max-jobs 2 --guide-file guides/company-workflow.md
```

## 📋 Command Options

| Option | Description |
|--------|-------------|
| `--bundle PATH` | Specify bundle directory to read target.yml and task.md from |
| `--guide-file FILE` | Specify custom guide file (default: GUIDE.md) |
| `--generate-only` | Only generate task files, don't execute them |
| `--run-only` | Execute existing task files without regenerating |
| `--save-logs` | Save Claude CLI output to log files |
| `--parallel` | Execute tasks in parallel (automatically enables --save-logs) |
| `--max-jobs NUM` | Maximum number of parallel jobs (default: 4, only with --parallel) |
| `--help, -h` | Show help message |

## 📁 Project Structure

```
claude-multi-repo-agent/
├── gen-and-run-tasks.sh    # Main automation script
├── target.yml              # Repository and branch configuration (root mode)
├── task.md                 # Task description (root mode)
├── GUIDE.md                # Default workflow guidelines
├── CLAUDE.md               # Project instructions for Claude
├── bundles/                # Bundle scenarios (NEW)
│   ├── upgrade-deps/
│   │   ├── target.yml      # Dependency update repositories
│   │   └── task.md         # Dependency update tasks
│   ├── security-patch/
│   │   ├── target.yml      # Security repositories
│   │   └── task.md         # Security patch tasks
│   └── docs-sync/
│       ├── target.yml      # Documentation repositories
│       └── task.md         # Documentation sync tasks
├── guides/                 # Optional custom guide files
│   ├── company-workflow.md
│   └── minimal.md
├── workspace/              # Auto-managed repository clones
│   ├── repo1/
│   ├── repo2/
│   └── ...
├── tasks/                  # Generated task files
│   ├── 001_repo1_main.md
│   ├── 002_repo1_develop.md
│   └── ...
└── logs/                   # Execution logs (with --save-logs)
    ├── 001_repo1_main.log
    └── ...
```

## 📝 Guide Files

### Understanding Guide File Automation

The guide file is a **core automation component** of this project. The default `GUIDE.md` contains comprehensive workflow instructions that enable fully automated repository operations:

- **Repository Management**: Automated fork creation, cloning, and upstream remote setup
- **Branch Workflows**: Feature branch creation, checkout patterns, and Git operations
- **Code Standards**: English comment requirements, signing protocols, and quality checks
- **Pull Request Automation**: Complete GitHub CLI integration for PR creation and submission
- **Error Handling**: Robust failure recovery and continuation patterns

### Default Guide (GUIDE.md)

The included `GUIDE.md` provides a **production-ready automation framework** with:
- Complete Git workflow automation (stash, fetch, checkout, branch creation)
- Signed commit requirements with proper formatting
- GitHub CLI integration for upstream PR creation
- Comprehensive error handling and project continuation logic
- Code quality standards and English comment enforcement

### Custom Guide Files

When creating custom guide files, **ensure they maintain automation capabilities**:

```bash
# Use organization-specific workflow
./gen-and-run-tasks.sh --guide-file guides/company-workflow.md

# Use security-focused guidelines
./gen-and-run-tasks.sh --guide-file guides/security-updates.md

# Use minimal instructions for simple tasks
./gen-and-run-tasks.sh --guide-file guides/minimal.md
```

**Custom Guide Requirements:**
- Must provide complete automation instructions
- Should include all necessary Git commands and workflows
- Must specify PR creation patterns and requirements
- Should handle error scenarios and project continuation

**Benefits of Custom Guides:**
- Tailor workflows to specific requirements
- Enforce organization standards
- Provide domain-specific instructions
- Support different project types

> ⚠️ **Important**: When specifying custom guide files, ensure they contain sufficient automation instructions for Claude Code to execute tasks successfully. The default guide provides a comprehensive template for automation-ready workflows.

## 🔧 Configuration Reference

### target.yml Structure

```yaml
target:
  - org: organization-name    # Required: GitHub organization
    repos:                   # Required: List of repositories
      - repository-1
      - repository-2
    branches:                # Required: List of branches
      - main
      - develop
      - feature-branch
```

### Automatic Repository Management

The tool automatically handles repository setup:

1. **Check Workspace**: Looks for repositories in the `workspace/` directory
2. **Fork Detection**: Checks if you've already forked the target repository
3. **Auto-Fork**: Creates a fork if none exists
4. **Clone**: Clones your fork to the workspace
5. **Upstream Setup**: Adds the original repository as upstream remote

## 📝 Task File Format

Generated task files include:

```markdown
# Task: repo-name/branch-name (from org/repo-name)

## Repository Info
- **Organization**: org-name
- **Repository**: repo-name
- **Branch**: branch-name
- **Workspace Path**: workspace/repo-name

## Guide
<guide>
<!-- Content from GUIDE.md -->
</guide>

## Description
<task>
<!-- Content from task.md -->
</task>
```

## 🔄 Workflow Examples

### Example 1: Bundle-Based Dependency Updates

Create a reusable bundle for dependency updates:

```bash
# Create the bundle
mkdir -p bundles/upgrade-deps
```

```yaml
# bundles/upgrade-deps/target.yml
target:
  - org: mycompany
    repos: [frontend, backend, mobile-app]
    branches: [main, develop]
```

```markdown
<!-- bundles/upgrade-deps/task.md -->
# Update Dependencies
Update all projects to use the latest LTS versions of their runtime dependencies.

## Requirements
- Update package.json/requirements.txt/go.mod as appropriate
- Run security audit after updates
- Ensure all tests pass
```

```bash
# Execute the bundle
./gen-and-run-tasks.sh --bundle bundles/upgrade-deps

# Execute in parallel for faster processing
./gen-and-run-tasks.sh --bundle bundles/upgrade-deps --parallel
```

### Example 2: Security Patch Bundle

```yaml
# bundles/security-patch/target.yml
target:
  - org: opensource-org
    repos: [project-a, project-b, project-c]
    branches: [main, release-1.0, release-2.0]
```

```markdown
<!-- bundles/security-patch/task.md -->
# Apply Security Patches
Apply critical security updates to all affected repositories.
```

```bash
# Execute with logging for audit trail
./gen-and-run-tasks.sh --bundle bundles/security-patch --save-logs

# Execute in parallel with custom concurrency
./gen-and-run-tasks.sh --bundle bundles/security-patch --parallel --max-jobs 2
```

### Example 3: Documentation Sync Bundle

```yaml
# bundles/docs-sync/target.yml
target:
  - org: documentation-team
    repos: [docs-site, api-docs, user-guides]
    branches: [main]
```

```bash
# Generate and review before execution
./gen-and-run-tasks.sh --bundle bundles/docs-sync --generate-only
# Review generated tasks in tasks/ directory
./gen-and-run-tasks.sh --run-only
```

### Example 4: Traditional Root Configuration

For one-off tasks, still use the root configuration:

```yaml
# target.yml (in root)
target:
  - org: personal-projects
    repos: [website, blog]
    branches: [main]
```

```bash
# Execute without bundles
./gen-and-run-tasks.sh
```

## 🛠️ Advanced Usage

### Custom Claude Prompts

Modify the task execution prompt in `gen-and-run-tasks.sh`:

```bash
claude -p "Execute this task with special consideration for X"
```

### Integration with CI/CD

Run in automated environments:

```bash
# Non-interactive mode with logging
./gen-and-run-tasks.sh --save-logs

# Parallel execution for CI/CD (faster)
./gen-and-run-tasks.sh --parallel --max-jobs 6
```

### Filtering and Validation

The tool includes built-in validation:
- GitHub authentication check
- Repository access verification
- Branch existence validation

## 🚨 Best Practices

1. **Test First**: Start with a small subset of repositories
2. **Use Branches**: Work on feature branches, not main/master
3. **Review Changes**: Always review generated changes before merging
4. **Backup Important**: Keep backups of critical repositories
5. **Monitor Logs**: Use `--save-logs` for debugging and auditing
6. **Organize with Bundles**: Use bundles to organize recurring task scenarios
   - `bundles/weekly-updates/`: Regular maintenance tasks
   - `bundles/security-patches/`: Security-related updates
   - `bundles/compliance-checks/`: Compliance and audit tasks
7. **Version Control Bundles**: Keep bundle configurations in version control for team sharing
8. **Test Bundles**: Test new bundles with a small repository set before full deployment
9. **Validate Custom Guides**: When using custom guide files, ensure they provide complete automation instructions equivalent to the default guide
10. **Test Guide Automation**: Verify custom guides work with a test repository before applying to multiple targets
11. **Use Parallel Execution**: Enable `--parallel` for faster processing of multiple repositories
12. **Tune Concurrency**: Adjust `--max-jobs` based on system resources and API rate limits
13. **Repository Safety**: Parallel mode automatically prevents same-repository conflicts by grouping tasks

## 🤝 Contributing

This tool is designed to be organization-agnostic and can work with any GitHub repositories you have access to. Feel free to customize the workflow files and scripts for your specific needs.

---

**💡 Pro Tips**: 
- **Bundle Organization**: Create bundles for different scenarios (e.g., `bundles/monthly-updates/`, `bundles/security-patches/`) to streamline recurring tasks
- **Team Sharing**: Commit bundle configurations to enable team members to run the same task scenarios consistently  
- **Task Automation**: Use this tool for routine maintenance like dependency updates, documentation syncing, configuration standardization, and compliance checks across your entire repository ecosystem
- **Performance Optimization**: Use `--parallel` for large repository sets to significantly reduce execution time
- **Resource Management**: Start with lower `--max-jobs` values and increase based on system performance and API limits
- **Safety First**: Parallel mode intelligently groups tasks by repository to prevent Git conflicts while maximizing concurrency