#!/bin/bash

# Combined script to generate and run task files from target.yml and task.md

set -e

# Function to format timestamp
format_timestamp() {
    date '+%Y-%m-%d %H:%M:%S'
}

# Function to calculate duration in seconds
calculate_duration() {
    local start_time="$1"
    local end_time="$2"
    echo $((end_time - start_time))
}

# Function to format duration in human readable format
format_duration() {
    local duration="$1"
    local hours=$((duration / 3600))
    local minutes=$(((duration % 3600) / 60))
    local seconds=$((duration % 60))
    
    if [ $hours -gt 0 ]; then
        printf "%dh %dm %ds" $hours $minutes $seconds
    elif [ $minutes -gt 0 ]; then
        printf "%dm %ds" $minutes $seconds
    else
        printf "%ds" $seconds
    fi
}

# Function to show usage
show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --guide-file FILE   Specify custom guide file (default: GUIDE.md)"
    echo "  --generate-only     Only generate task files, don't run them"
    echo "  --run-only         Only run existing task files (skip generation)"
    echo "  --save-logs        Save Claude CLI output to log files (when running)"
    echo "  --help, -h         Show this help message"
    echo ""
    echo "Default behavior: Generate task files and then run them"
}

# Parse command line arguments
GENERATE_ONLY=false
RUN_ONLY=false
SAVE_LOGS=false
GUIDE_FILE="GUIDE.md"

while [[ $# -gt 0 ]]; do
    case $1 in
        --guide-file)
            GUIDE_FILE="$2"
            shift 2
            ;;
        --generate-only)
            GENERATE_ONLY=true
            shift
            ;;
        --run-only)
            RUN_ONLY=true
            shift
            ;;
        --save-logs)
            SAVE_LOGS=true
            shift
            ;;
        --help|-h)
            show_usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Validate conflicting options
if [[ "$GENERATE_ONLY" == "true" && "$RUN_ONLY" == "true" ]]; then
    echo "Error: --generate-only and --run-only cannot be used together"
    exit 1
fi

# Define file paths
TARGET_FILE="target.yml"
TASK_FILE="task.md"
# GUIDE_FILE is set by command line arguments or defaults to "GUIDE.md"
OUTPUT_DIR="tasks"
LOG_DIR="logs"
WORKSPACE_DIR="workspace"

# GENERATION SECTION
if [[ "$RUN_ONLY" != "true" ]]; then
    echo "=== TASK GENERATION ==="
    
    # Clean up tasks directory at the beginning
    echo "Cleaning up existing tasks directory..."
    rm -rf "$OUTPUT_DIR"

    # Check if required files exist
    if [[ ! -f "$TARGET_FILE" ]]; then
        echo "Error: $TARGET_FILE not found"
        exit 1
    fi

    if [[ ! -f "$TASK_FILE" ]]; then
        echo "Error: $TASK_FILE not found"
        exit 1
    fi

    if [[ ! -f "$GUIDE_FILE" ]]; then
        echo "Error: $GUIDE_FILE not found"
        exit 1
    fi

    # Read task content (everything from task.md) and remove empty lines
    TASK_CONTENT=$(cat "$TASK_FILE" | sed '/^[[:space:]]*$/d')

    # Read guide content (everything from GUIDE.md) and remove empty lines
    GUIDE_CONTENT=$(cat "$GUIDE_FILE" | sed '/^[[:space:]]*$/d')

    # Create tasks directory
    echo "Generating tasks in $OUTPUT_DIR directory..."
    mkdir -p "$OUTPUT_DIR"
    
    # Create workspace directory if it doesn't exist
    mkdir -p "$WORKSPACE_DIR"

    # Function to ensure repository exists in workspace
    ensure_repo_exists() {
        local org="$1"
        local repo="$2"
        local repo_dir="$WORKSPACE_DIR/$repo"
        
        if [[ -d "$repo_dir" ]]; then
            echo "Repository $repo already exists in workspace"
            return 0
        fi
        
        echo "Repository $repo not found in workspace, checking for fork..."
        
        # Get current GitHub username
        local current_user=$(gh api user --jq '.login' 2>/dev/null)
        if [[ -z "$current_user" ]]; then
            echo "Error: Could not get current GitHub user. Please check gh authentication."
            return 1
        fi
        
        # Check if user has already forked the repo
        local fork_exists=$(gh repo list "$current_user" --fork --json name --jq ".[].name" | grep "^$repo$" || true)
        
        if [[ -z "$fork_exists" ]]; then
            echo "Fork not found. Creating fork of $org/$repo..."
            if ! gh repo fork "$org/$repo" --clone=false; then
                echo "Error: Failed to fork $org/$repo"
                return 1
            fi
            echo "Successfully forked $org/$repo"
        else
            echo "Fork $current_user/$repo already exists"
        fi
        
        # Clone the forked repository
        echo "Cloning $current_user/$repo to workspace..."
        if ! gh repo clone "$current_user/$repo" "$repo_dir"; then
            echo "Error: Failed to clone $current_user/$repo"
            return 1
        fi
        
        # Add upstream remote
        echo "Adding upstream remote $org/$repo..."
        cd "$repo_dir"
        if ! git remote add upstream "https://github.com/$org/$repo.git"; then
            echo "Warning: Failed to add upstream remote (may already exist)"
        fi
        cd - > /dev/null
        
        echo "Successfully set up repository $repo in workspace"
        return 0
    }

    # Create a counter for task files
    TASK_COUNTER=1

    # Parse target.yml and extract org/repo/branch combinations
    # This uses yq to parse YAML, but falls back to basic parsing if yq is not available
    if command -v yq &> /dev/null; then
        # Use yq for proper YAML parsing - generate all org/repo/branch combinations
        yq eval '.target[] as $item | $item.org as $org | $item.repos[] as $repo | $item.branches[] as $branch | $org + "/" + $repo + "/" + $branch' "$TARGET_FILE" 2>/dev/null | while read -r target; do
            if [[ -n "$target" && "$target" != "null" ]]; then
                # Parse org/repo/branch from target
                IFS='/' read -r org repo branch <<< "$target"
                
                # Ensure repository exists in workspace
                if ! ensure_repo_exists "$org" "$repo"; then
                    echo "Warning: Failed to set up repository $org/$repo, skipping..."
                    continue
                fi
                
                # Create filename with zero-padded counter
                TASK_FILE_NAME=$(printf "%03d_%s_%s.md" "$TASK_COUNTER" "$repo" "$branch")

                # Write task content to individual file
                cat > "$OUTPUT_DIR/$TASK_FILE_NAME" << EOF
# Task: $repo/$branch (from $org/$repo)

## Repository Info
- **Organization**: $org
- **Repository**: $repo
- **Branch**: $branch
- **Workspace Path**: $WORKSPACE_DIR/$repo

## Guide
<guide>
$GUIDE_CONTENT
</guide>

## Description
<task>
$TASK_CONTENT
</task>
EOF

                echo "Created: $OUTPUT_DIR/$TASK_FILE_NAME"
                TASK_COUNTER=$((TASK_COUNTER + 1))
            fi
        done
    else
        # Fallback: Basic parsing without yq
        echo "Warning: yq not found, using basic YAML parsing"

        # Extract org, repos and branches arrays from YAML and generate combinations
        awk '
        /^[[:space:]]*-[[:space:]]*org:/ {
            # Extract org
            gsub(/^[[:space:]]*-[[:space:]]*org:[[:space:]]*/, "")
            gsub(/[[:space:]]*$/, "")
            org = $0
        }
        /^[[:space:]]*repos:/ {
            # Extract repos array
            gsub(/^[[:space:]]*repos:[[:space:]]*\[/, "")
            gsub(/\][[:space:]]*$/, "")
            gsub(/[[:space:]]*/, "")
            split($0, repo_array, ",")
            delete repos
            for (i in repo_array) {
                repos[i] = repo_array[i]
            }
        }
        /^[[:space:]]*branches:/ {
            # Extract branches array
            gsub(/^[[:space:]]*branches:[[:space:]]*\[/, "")
            gsub(/\][[:space:]]*$/, "")
            gsub(/[[:space:]]*/, "")
            split($0, branch_array, ",")
            delete branches
            for (i in branch_array) {
                branches[i] = branch_array[i]
            }
            
            # Generate all combinations when we have org, repos and branches
            if (org != "" && length(repos) > 0 && length(branches) > 0) {
                for (r in repos) {
                    for (b in branches) {
                        print org "/" repos[r] "/" branches[b]
                    }
                }
                delete repos
                delete branches
                org = ""
            }
        }
        ' "$TARGET_FILE" | while read -r target; do
            if [[ -n "$target" ]]; then
                # Parse org/repo/branch from target
                IFS='/' read -r org repo branch <<< "$target"
                
                # Ensure repository exists in workspace
                if ! ensure_repo_exists "$org" "$repo"; then
                    echo "Warning: Failed to set up repository $org/$repo, skipping..."
                    continue
                fi
                
                # Create filename with zero-padded counter
                TASK_FILE_NAME=$(printf "%03d_%s_%s.md" "$TASK_COUNTER" "$repo" "$branch")

                # Write task content to individual file
                cat > "$OUTPUT_DIR/$TASK_FILE_NAME" << EOF
# Task: $repo/$branch (from $org/$repo)

## Repository Info
- **Organization**: $org
- **Repository**: $repo
- **Branch**: $branch
- **Workspace Path**: $WORKSPACE_DIR/$repo

## Guide
<guide>
$GUIDE_CONTENT
</guide>

## Description
<task>
$TASK_CONTENT
</task>
EOF

                echo "Created: $OUTPUT_DIR/$TASK_FILE_NAME"
                TASK_COUNTER=$((TASK_COUNTER + 1))
            fi
        done
    fi

    echo "Successfully generated tasks in $OUTPUT_DIR directory"
    echo ""
fi

# EXECUTION SECTION
if [[ "$GENERATE_ONLY" != "true" ]]; then
    echo "=== TASK EXECUTION ==="
    
    # Check if tasks directory exists
    if [[ ! -d "$OUTPUT_DIR" ]]; then
        echo "Error: $OUTPUT_DIR directory not found"
        echo "Please ensure task generation was successful"
        exit 1
    fi

    # Create logs directory only if saving logs
    if [[ "$SAVE_LOGS" == "true" ]]; then
        mkdir -p "$LOG_DIR"
    fi

    # Get all task files sorted by name
    TASK_FILES=($(find "$OUTPUT_DIR" -name "*.md" | sort))

    if [[ ${#TASK_FILES[@]} -eq 0 ]]; then
        echo "Error: No task files found in $OUTPUT_DIR"
        echo "Please ensure task generation was successful"
        exit 1
    fi

    echo "Found ${#TASK_FILES[@]} task files to process"

    # Function to run a single task
    run_task() {
        local task_file="$1"
        local task_name=$(basename "$task_file" .md)
        local log_file="$LOG_DIR/${task_name}.log"
        
        local start_timestamp=$(format_timestamp)
        local start_time=$(date +%s)
        
        echo "Processing: $task_file"
        echo "Started at: $start_timestamp"
        
        local exit_code=0
        
        if [[ "$SAVE_LOGS" == "true" ]]; then
            # Run Claude CLI and save output to log file
            if cat "$task_file" | claude -p "Execute this task" --verbose --output-format text --dangerously-skip-permissions > "$log_file" 2>&1; then
                exit_code=0
            else
                exit_code=1
            fi
        else
            # Run Claude CLI and print output directly
            echo "Output for $task_name:"
            echo "========================"
            if cat "$task_file" | claude -p "Execute this task" --verbose --output-format text --dangerously-skip-permissions; then
                echo "========================"
                exit_code=0
            else
                echo "========================"
                exit_code=1
            fi
        fi
        
        local end_timestamp=$(format_timestamp)
        local end_time=$(date +%s)
        local duration=$(calculate_duration $start_time $end_time)
        local formatted_duration=$(format_duration $duration)
        
        echo "Finished at: $end_timestamp"
        echo "Duration: $formatted_duration"
        
        if [[ $exit_code -eq 0 ]]; then
            echo "✓ Completed: $task_name"
            if [[ "$SAVE_LOGS" == "true" ]]; then
                echo "  Log: $log_file"
            fi
            return 0
        else
            echo "✗ Failed: $task_name"
            if [[ "$SAVE_LOGS" == "true" ]]; then
                echo "  Log: $log_file"
            fi
            return 1
        fi
    }

    # Process all tasks
    execution_start_timestamp=$(format_timestamp)
    execution_start_time=$(date +%s)
    
    echo "Starting task execution..."
    echo "Execution started at: $execution_start_timestamp"
    if [[ "$SAVE_LOGS" == "true" ]]; then
        echo "Logs will be saved to: $LOG_DIR/"
    else
        echo "Output will be printed directly (no logs saved)"
    fi

    SUCCESSFUL=0
    FAILED=0

    for task_file in "${TASK_FILES[@]}"; do
        if run_task "$task_file"; then
            SUCCESSFUL=$((SUCCESSFUL + 1))
        else
            FAILED=$((FAILED + 1))
        fi
        echo ""
    done

    execution_end_timestamp=$(format_timestamp)
    execution_end_time=$(date +%s)
    total_duration=$(calculate_duration $execution_start_time $execution_end_time)
    formatted_total_duration=$(format_duration $total_duration)

    # Summary
    echo "================================"
    echo "Task Execution Summary:"
    echo "  Started at: $execution_start_timestamp"
    echo "  Finished at: $execution_end_timestamp"
    echo "  Total duration: $formatted_total_duration"
    echo "  Successful: $SUCCESSFUL"
    echo "  Failed: $FAILED"
    echo "  Total: ${#TASK_FILES[@]}"
    echo "================================"

    if [[ $FAILED -gt 0 ]]; then
        if [[ "$SAVE_LOGS" == "true" ]]; then
            echo "Some tasks failed. Check logs in $LOG_DIR/ for details."
        else
            echo "Some tasks failed. See output above for details."
        fi
        exit 1
    else
        echo "All tasks completed successfully!"
        exit 0
    fi
fi