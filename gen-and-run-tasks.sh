#!/usr/bin/env bash

# Combined script to generate and run task files from target.yml and task.md

set -e

# Function to find the latest Bash version available
find_latest_bash() {
    local bash_paths=(
        "/opt/homebrew/bin/bash"
        "/usr/local/bin/bash"
        "/bin/bash"
        "/usr/bin/bash"
    )
    
    local latest_version=""
    local latest_path=""
    local latest_major=0
    local latest_minor=0
    local latest_patch=0
    
    for bash_path in "${bash_paths[@]}"; do
        if [[ -x "$bash_path" ]]; then
            # Get version info from this bash executable
            local version_info=$("$bash_path" --version 2>/dev/null | head -1)
            if [[ $version_info =~ version\ ([0-9]+)\.([0-9]+)\.([0-9]+) ]]; then
                local major=${BASH_REMATCH[1]}
                local minor=${BASH_REMATCH[2]}
                local patch=${BASH_REMATCH[3]}
                
                # Compare versions (major.minor.patch)
                if [[ $major -gt $latest_major ]] || \
                   [[ $major -eq $latest_major && $minor -gt $latest_minor ]] || \
                   [[ $major -eq $latest_major && $minor -eq $latest_minor && $patch -gt $latest_patch ]]; then
                    latest_major=$major
                    latest_minor=$minor
                    latest_patch=$patch
                    latest_version="$major.$minor.$patch"
                    latest_path="$bash_path"
                fi
            fi
        fi
    done
    
    echo "$latest_path|$latest_version|$latest_major"
}

# Check if we're running with the latest Bash version
bash_info=$(find_latest_bash)
IFS='|' read -r latest_bash_path latest_version latest_major <<< "$bash_info"

# Check if current bash is the latest and meets requirements
current_bash_path=$(which bash 2>/dev/null || echo "/bin/bash")
if [[ "$latest_bash_path" != "$current_bash_path" && -n "$latest_bash_path" ]]; then
    echo "🔄 Found newer Bash version: $latest_version at $latest_bash_path"
    echo "   Current: $BASH_VERSION at $current_bash_path"
    echo "   Re-executing with newer version..."
    exec "$latest_bash_path" "$0" "$@"
fi

# Check Bash version requirement
if [[ ${BASH_VERSINFO[0]} -lt 4 ]]; then
    echo "❌ Error: Bash 4.0+ required for this script" >&2
    echo "Current version: ${BASH_VERSION}" >&2
    if [[ -n "$latest_bash_path" && $latest_major -ge 4 ]]; then
        echo "Found suitable Bash at: $latest_bash_path (version $latest_version)" >&2
        echo "Re-run with: $latest_bash_path $0 $*" >&2
    else
        echo "Please upgrade Bash and try again." >&2
    fi
    exit 1
fi

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

# Function to read JSON config
read_config() {
    local config_file="$1"
    local key="$2"
    local default_value="$3"

    if [[ -f "$config_file" ]]; then
        if command -v jq &> /dev/null; then
            # Use jq for proper JSON parsing
            local value=$(jq -r ".$key // \"$default_value\"" "$config_file" 2>/dev/null)
            if [[ "$value" != "null" && "$value" != "" ]]; then
                echo "$value"
            else
                echo "$default_value"
            fi
        else
            # Fallback: Basic parsing without jq
            local value=$(grep "\"$key\"" "$config_file" 2>/dev/null | sed 's/.*"'$key'"[[:space:]]*:[[:space:]]*\([^,}]*\).*/\1/' | sed 's/[",]//g' | xargs)
            if [[ -n "$value" ]]; then
                echo "$value"
            else
                echo "$default_value"
            fi
        fi
    else
        echo "$default_value"
    fi
}

# Function to load configuration from files
load_config() {
    local bundle_path="$1"

    # Set defaults
    CONFIG_PARALLEL="false"
    CONFIG_MAX_JOBS="4"
    CONFIG_SAVE_LOGS="false"
    CONFIG_GENERATE_ONLY="false"
    CONFIG_RUN_ONLY="false"
    CONFIG_GUIDE_FILE="GUIDE.md"

    # Read root config.json if it exists
    if [[ -f "config.json" ]]; then
        CONFIG_PARALLEL=$(read_config "config.json" "parallel" "$CONFIG_PARALLEL")
        CONFIG_MAX_JOBS=$(read_config "config.json" "maxJobs" "$CONFIG_MAX_JOBS")
        CONFIG_SAVE_LOGS=$(read_config "config.json" "saveLogs" "$CONFIG_SAVE_LOGS")
        CONFIG_GENERATE_ONLY=$(read_config "config.json" "generateOnly" "$CONFIG_GENERATE_ONLY")
        CONFIG_RUN_ONLY=$(read_config "config.json" "runOnly" "$CONFIG_RUN_ONLY")
        CONFIG_GUIDE_FILE=$(read_config "config.json" "guideFile" "$CONFIG_GUIDE_FILE")
    fi

    # Read bundle config.json if bundle is specified and config exists
    if [[ -n "$bundle_path" && -f "$bundle_path/config.json" ]]; then
        CONFIG_PARALLEL=$(read_config "$bundle_path/config.json" "parallel" "$CONFIG_PARALLEL")
        CONFIG_MAX_JOBS=$(read_config "$bundle_path/config.json" "maxJobs" "$CONFIG_MAX_JOBS")
        CONFIG_SAVE_LOGS=$(read_config "$bundle_path/config.json" "saveLogs" "$CONFIG_SAVE_LOGS")
        CONFIG_GENERATE_ONLY=$(read_config "$bundle_path/config.json" "generateOnly" "$CONFIG_GENERATE_ONLY")
        CONFIG_RUN_ONLY=$(read_config "$bundle_path/config.json" "runOnly" "$CONFIG_RUN_ONLY")
        CONFIG_GUIDE_FILE=$(read_config "$bundle_path/config.json" "guideFile" "$CONFIG_GUIDE_FILE")
    fi
}

# Function to show usage
show_usage() {
    echo ""
    echo "🚀 ═══════════════════════════════════════════════════════════════════════════════════"
    echo "🤖 CLAUDE MULTI-REPO AGENT"
    echo "═══════════════════════════════════════════════════════════════════════════════════"
    echo ""
    echo "📋 Usage: $0 [OPTIONS]"
    echo ""
    echo "⚙️  Options:"
    echo "  📦 --bundle PATH       Specify bundle directory to read target.yml and task.md from"
    echo "  📝 --guide-file FILE   Specify custom guide file (default: GUIDE.md or from config)"
    echo "  📝 --generate-only     Only generate task files, don't run them"
    echo "  ▶️  --run-only         Only run existing task files (skip generation)"
    echo "  📄 --save-logs        Save Claude CLI output to log files (when running)"
    echo "  🚀 --parallel         Execute tasks in parallel (automatically enables --save-logs)"
    echo "  ⚙️  --max-jobs NUM     Maximum number of parallel jobs (default: 4, only with --parallel)"
    echo "  ❓ --help, -h         Show this help message"
    echo ""
    echo "📁 Configuration files:"
    echo "  📜 config.json        Root configuration file (applies to all executions)"
    echo "  📦 bundle/config.json Bundle-specific configuration (overrides root config)"
    echo ""
    echo "🔄 Priority: Command line options > Bundle config > Root config > Defaults"
    echo "🎯 Default behavior: Generate task files and then run them sequentially"
    echo "📦 Bundle mode: When --bundle is specified, reads target.yml and task.md from the bundle directory"
    echo "🚀 Parallel mode: Tasks from the same repository are still executed sequentially to avoid conflicts"
    echo "═══════════════════════════════════════════════════════════════════════════════════"
    echo ""
}

# Initialize variables for command line parsing
BUNDLE_PATH=""
CLI_GENERATE_ONLY=""
CLI_RUN_ONLY=""
CLI_SAVE_LOGS=""
CLI_PARALLEL=""
CLI_MAX_JOBS=""
CLI_GUIDE_FILE=""

# Parse command line arguments first to get bundle path
while [[ $# -gt 0 ]]; do
    case $1 in
        --bundle)
            BUNDLE_PATH="$2"
            shift 2
            ;;
        --guide-file)
            CLI_GUIDE_FILE="$2"
            shift 2
            ;;
        --generate-only)
            CLI_GENERATE_ONLY=true
            shift
            ;;
        --run-only)
            CLI_RUN_ONLY=true
            shift
            ;;
        --save-logs)
            CLI_SAVE_LOGS=true
            shift
            ;;
        --parallel)
            CLI_PARALLEL=true
            shift
            ;;
        --max-jobs)
            CLI_MAX_JOBS="$2"
            shift 2
            ;;
        --help|-h)
            show_usage
            exit 0
            ;;
        *)
            echo "❌ Unknown option: $1"
            echo "📝 Use --help for usage information"
            exit 1
            ;;
    esac
done

# Load configuration from files
load_config "$BUNDLE_PATH"

# Apply configuration with priority: CLI > Bundle Config > Root Config > Defaults
GENERATE_ONLY="${CLI_GENERATE_ONLY:-$CONFIG_GENERATE_ONLY}"
RUN_ONLY="${CLI_RUN_ONLY:-$CONFIG_RUN_ONLY}"
SAVE_LOGS="${CLI_SAVE_LOGS:-$CONFIG_SAVE_LOGS}"
PARALLEL="${CLI_PARALLEL:-$CONFIG_PARALLEL}"
MAX_JOBS="${CLI_MAX_JOBS:-$CONFIG_MAX_JOBS}"
GUIDE_FILE="${CLI_GUIDE_FILE:-$CONFIG_GUIDE_FILE}"

# Validate conflicting options
if [[ "$GENERATE_ONLY" == "true" && "$RUN_ONLY" == "true" ]]; then
    echo "❌ Error: --generate-only and --run-only cannot be used together"
    exit 1
fi

# Validate parallel options
if [[ "$PARALLEL" == "true" ]]; then
    # Force save logs when running in parallel to avoid output confusion
    SAVE_LOGS=true
    echo "🚀 Parallel mode enabled: automatically enabling log saving"

    # Validate max-jobs is a positive integer
    if ! [[ "$MAX_JOBS" =~ ^[1-9][0-9]*$ ]]; then
        echo "❌ Error: --max-jobs must be a positive integer (got: $MAX_JOBS)"
        exit 1
    fi
fi

# Define file paths based on bundle configuration
if [[ -n "$BUNDLE_PATH" ]]; then
    # Validate bundle directory exists
    if [[ ! -d "$BUNDLE_PATH" ]]; then
        echo "❌ Error: Bundle directory '$BUNDLE_PATH' not found"
        exit 1
    fi

    TARGET_FILE="$BUNDLE_PATH/target.yml"
    TASK_FILE="$BUNDLE_PATH/task.md"

    # Check if bundle has its own GUIDE.md, otherwise use default or user-specified path
    if [[ -z "$CLI_GUIDE_FILE" && -f "$BUNDLE_PATH/GUIDE.md" ]]; then
        GUIDE_FILE="$BUNDLE_PATH/GUIDE.md"
    fi

    echo "📦 Using bundle: $BUNDLE_PATH"
    if [[ -f "$BUNDLE_PATH/GUIDE.md" && -z "$CLI_GUIDE_FILE" ]]; then
        echo "📋 Using bundle-specific guide: $BUNDLE_PATH/GUIDE.md"
    fi
else
    TARGET_FILE="target.yml"
    TASK_FILE="task.md"
    # GUIDE_FILE is set by command line arguments or defaults to "GUIDE.md"
fi

OUTPUT_DIR="tasks"
LOG_DIR="logs"
WORKSPACE_DIR="workspace"

# GENERATION SECTION
if [[ "$RUN_ONLY" != "true" ]]; then
    echo ""
    echo "🚀 ═══════════════════════════════════════════════════════════════════════════════════"
    echo "📝 TASK GENERATION"
    echo "═══════════════════════════════════════════════════════════════════════════════════"
    echo ""

    # Clean up tasks directory at the beginning
    echo "🧹 Cleaning up existing tasks directory..."
    rm -rf "$OUTPUT_DIR"

    # Check if required files exist
    if [[ ! -f "$TARGET_FILE" ]]; then
        echo "❌ Error: $TARGET_FILE not found"
        exit 1
    fi

    if [[ ! -f "$TASK_FILE" ]]; then
        echo "❌ Error: $TASK_FILE not found"
        exit 1
    fi

    if [[ ! -f "$GUIDE_FILE" ]]; then
        echo "❌ Error: $GUIDE_FILE not found"
        exit 1
    fi

    # Read task content (everything from task.md) and remove empty lines
    TASK_CONTENT=$(cat "$TASK_FILE" | sed '/^[[:space:]]*$/d')

    # Read guide content (everything from GUIDE.md) and remove empty lines
    GUIDE_CONTENT=$(cat "$GUIDE_FILE" | sed '/^[[:space:]]*$/d')

    # Create tasks directory
    echo "📂 Generating tasks in $OUTPUT_DIR directory..."
    mkdir -p "$OUTPUT_DIR"

    # Create workspace directory if it doesn't exist
    mkdir -p "$WORKSPACE_DIR"

    # Function to ensure repository exists in workspace
    ensure_repo_exists() {
        local org="$1"
        local repo="$2"
        local repo_dir="$WORKSPACE_DIR/$repo"

        if [[ -d "$repo_dir" ]]; then
            echo "   ✅ Repository $repo already exists in workspace"
            return 0
        fi

        echo "   🔍 Repository $repo not found in workspace, checking for fork..."

        # Get current GitHub username
        local current_user=$(gh api user --jq '.login' 2>/dev/null)
        if [[ -z "$current_user" ]]; then
            echo "   ❌ Error: Could not get current GitHub user. Please check gh authentication."
            return 1
        fi

        # Check if user has already forked the repo
        local fork_exists=$(gh repo list "$current_user" --fork --json name --jq ".[].name" | grep "^$repo$" || true)

        if [[ -z "$fork_exists" ]]; then
            echo "   🍴 Fork not found. Creating fork of $org/$repo..."
            if ! gh repo fork "$org/$repo" --clone=false; then
                echo "   ❌ Error: Failed to fork $org/$repo"
                return 1
            fi
            echo "   ✅ Successfully forked $org/$repo"
        else
            echo "   ✅ Fork $current_user/$repo already exists"
        fi

        # Clone the forked repository
        echo "   📥 Cloning $current_user/$repo to workspace..."
        if ! gh repo clone "$current_user/$repo" "$repo_dir"; then
            echo "   ❌ Error: Failed to clone $current_user/$repo"
            return 1
        fi

        # Add upstream remote
        echo "   🔗 Adding upstream remote $org/$repo..."
        cd "$repo_dir"
        if ! git remote add upstream "https://github.com/$org/$repo.git"; then
            echo "   ⚠️  Warning: Failed to add upstream remote (may already exist)"
        fi
        cd - > /dev/null

        echo "   ✅ Successfully set up repository $repo in workspace"
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
                echo "🔧 Setting up repository: $org/$repo"
                if ! ensure_repo_exists "$org" "$repo"; then
                    echo "⚠️  Warning: Failed to set up repository $org/$repo, skipping..."
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

                echo "   ✅ Created: $OUTPUT_DIR/$TASK_FILE_NAME"
                TASK_COUNTER=$((TASK_COUNTER + 1))
            fi
        done
    else
        # Fallback: Basic parsing without yq
        echo "⚠️  Warning: yq not found, using basic YAML parsing"

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
                echo "🔧 Setting up repository: $org/$repo"
                if ! ensure_repo_exists "$org" "$repo"; then
                    echo "⚠️  Warning: Failed to set up repository $org/$repo, skipping..."
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

                echo "   ✅ Created: $OUTPUT_DIR/$TASK_FILE_NAME"
                TASK_COUNTER=$((TASK_COUNTER + 1))
            fi
        done
    fi

    # Count actual generated task files
    GENERATED_COUNT=$(find "$OUTPUT_DIR" -name "*.md" 2>/dev/null | wc -l | tr -d ' ')

    echo ""
    echo "🎉 Successfully generated $GENERATED_COUNT tasks in $OUTPUT_DIR directory"
    echo "═══════════════════════════════════════════════════════════════════════════════════"
    echo ""
fi

# EXECUTION SECTION
if [[ "$GENERATE_ONLY" != "true" ]]; then
    echo "🏃 ═══════════════════════════════════════════════════════════════════════════════════"
    echo "⚡ TASK EXECUTION"
    echo "═══════════════════════════════════════════════════════════════════════════════════"
    echo ""

    # Check if tasks directory exists
    if [[ ! -d "$OUTPUT_DIR" ]]; then
        echo "❌ Error: $OUTPUT_DIR directory not found"
        echo "📝 Please ensure task generation was successful"
        exit 1
    fi

    # Create logs directory only if saving logs (clean up existing logs first)
    if [[ "$SAVE_LOGS" == "true" ]]; then
        echo "🧹 Cleaning up existing logs directory..."
        rm -rf "$LOG_DIR"
        mkdir -p "$LOG_DIR"
    fi

    # Get all task files sorted by name
    TASK_FILES=($(find "$OUTPUT_DIR" -name "*.md" | sort))

    if [[ ${#TASK_FILES[@]} -eq 0 ]]; then
        echo "❌ Error: No task files found in $OUTPUT_DIR"
        echo "📝 Please ensure task generation was successful"
        exit 1
    fi

    echo "📁 Found ${#TASK_FILES[@]} task files to process"

    # Function to run a single task
    run_task() {
        local task_file="$1"
        local task_name=$(basename "$task_file" .md)
        local log_file="$LOG_DIR/${task_name}.log"

        local start_timestamp=$(format_timestamp)
        local start_time=$(date +%s)

        echo ""
        echo "🚀 Processing: $(basename "$task_file" .md)"
        echo "🕰️  Started at: $start_timestamp"

        local exit_code=0

        if [[ "$SAVE_LOGS" == "true" ]]; then
            # Run Claude CLI and save output to log file
            echo "🤖 Running Claude CLI... (output saved to log)"
            if cat "$task_file" | claude -p "Execute this task" --verbose --output-format text --dangerously-skip-permissions > "$log_file" 2>&1; then
                exit_code=0
            else
                exit_code=1
            fi
        else
            # Run Claude CLI and print output directly
            echo "🤖 Running Claude CLI..."
            echo "────────────────────────────────────────"
            if cat "$task_file" | claude -p "Execute this task" --verbose --output-format text --dangerously-skip-permissions; then
                echo "────────────────────────────────────────"
                exit_code=0
            else
                echo "────────────────────────────────────────"
                exit_code=1
            fi
        fi

        local end_timestamp=$(format_timestamp)
        local end_time=$(date +%s)
        local duration=$(calculate_duration $start_time $end_time)
        local formatted_duration=$(format_duration $duration)

        echo "🏁 Finished at: $end_timestamp"
        echo "⏱️  Duration: $formatted_duration"

        if [[ $exit_code -eq 0 ]]; then
            echo "✅ Completed: $task_name"
            if [[ "$SAVE_LOGS" == "true" ]]; then
                echo "📄 Log: $log_file"
            fi
            return 0
        else
            echo "❌ Failed: $task_name"
            if [[ "$SAVE_LOGS" == "true" ]]; then
                echo "📄 Log: $log_file"
            fi
            return 1
        fi
    }

    # Function to run a single task and write result to temp file (for parallel execution)
    run_task_parallel() {
        local task_file="$1"
        local result_file="$2"
        local task_name=$(basename "$task_file" .md)
        local log_file="$LOG_DIR/${task_name}.log"

        # Ensure result file directory exists
        mkdir -p "$(dirname "$result_file")" 2>/dev/null || true

        local start_timestamp=$(format_timestamp)
        local start_time=$(date +%s)

        # Write start info to result file with error handling
        if ! echo "STARTED|$task_name|$start_timestamp" > "$result_file" 2>/dev/null; then
            echo "❌ ERROR: Cannot write to result file $result_file" >&2
            return 1
        fi

        local exit_code=0

        # Always save logs in parallel mode
        if cat "$task_file" | claude -p "Execute this task" --verbose --output-format text --dangerously-skip-permissions > "$log_file" 2>&1; then
            exit_code=0
        else
            exit_code=1
        fi

        local end_timestamp=$(format_timestamp)
        local end_time=$(date +%s)
        local duration=$(calculate_duration $start_time $end_time)
        local formatted_duration=$(format_duration $duration)

        # Write final result to result file with error handling
        local result_line
        if [[ $exit_code -eq 0 ]]; then
            result_line="SUCCESS|$task_name|$start_timestamp|$end_timestamp|$formatted_duration|$log_file"
        else
            result_line="FAILED|$task_name|$start_timestamp|$end_timestamp|$formatted_duration|$log_file"
        fi

        if ! echo "$result_line" > "$result_file" 2>/dev/null; then
            echo "❌ ERROR: Cannot write final result to $result_file" >&2
            return 1
        fi

        return $exit_code
    }

    # Function to group tasks by repository to avoid conflicts
    group_tasks_by_repo() {
        local tasks=("$@")

        # Check if associative arrays are supported (bash 4.0+)
        if [[ ${BASH_VERSINFO[0]} -ge 4 ]]; then
            declare -A repo_groups
        else
            echo "❌ Error: Bash 4.0+ required for parallel execution (associative arrays)" >&2
            exit 1
        fi

        for task_file in "${tasks[@]}"; do
            # Extract repository name from task filename (format: 001_repo_branch.md)
            local filename=$(basename "$task_file" .md)
            local repo=$(echo "$filename" | sed 's/^[0-9]*_\([^_]*\)_.*$/\1/')

            # Handle repository names with hyphens properly
            if [[ "$filename" =~ ^[0-9]+_(.+)_[^_]+$ ]]; then
                repo="${BASH_REMATCH[1]}"
            fi

            if [[ -z "${repo_groups[$repo]}" ]]; then
                repo_groups[$repo]="$task_file"
            else
                repo_groups[$repo]="${repo_groups[$repo]} $task_file"
            fi
        done

        # Output grouped tasks
        for repo in "${!repo_groups[@]}"; do
            echo "$repo:${repo_groups[$repo]}"
        done
    }

    # Function to execute tasks in parallel mode
    execute_parallel() {
        local task_files=("$@")
        local temp_dir=$(mktemp -d)
        local job_count=0
        local pids=()
        local result_files=()

        local parallel_start_time=$(date +%s)
        local parallel_start_timestamp=$(format_timestamp)

        echo "🚀 Parallel execution with max $MAX_JOBS concurrent jobs"
        echo "📁 Temporary directory: $temp_dir"

        # Group tasks by repository
        local repo_groups=($(group_tasks_by_repo "${task_files[@]}"))

        echo "📂 Found ${#repo_groups[@]} repository groups to process"

        for repo_group in "${repo_groups[@]}"; do
            # Wait if we've reached max jobs
            while [[ $job_count -ge $MAX_JOBS ]]; do
                # Check for completed jobs
                local new_pids=()
                local new_result_files=()
                for i in "${!pids[@]}"; do
                    local pid="${pids[$i]}"
                    local result_file="${result_files[$i]}"
                    if ! kill -0 "$pid" 2>/dev/null; then
                        # Job completed
                        wait "$pid"
                        job_count=$((job_count - 1))
                        echo "✅ Repository group completed (PID: $pid)"
                    else
                        # Job still running
                        new_pids+=("$pid")
                        new_result_files+=("$result_file")
                    fi
                done
                pids=("${new_pids[@]}")
                result_files=("${new_result_files[@]}")

                if [[ $job_count -ge $MAX_JOBS ]]; then
                    sleep 1
                fi
            done

            # Extract repo name and tasks from group
            local repo=$(echo "$repo_group" | cut -d: -f1)
            local tasks_str=$(echo "$repo_group" | cut -d: -f2-)
            read -a repo_tasks <<< "$tasks_str"

            echo "🚀 Starting repository group: $repo (${#repo_tasks[@]} tasks)"

            # Create result file for this repository group
            local result_file="$temp_dir/result_${repo}_$$"
            result_files+=("$result_file")

            # Start background job for this repository group (tasks run sequentially within group)
            (
                for task_file in ${repo_tasks[@]}; do
                    local task_result_file="$temp_dir/task_$(basename "$task_file" .md)_$$"
                    run_task_parallel "$task_file" "$task_result_file"
                    # Ensure the result file exists before trying to read it
                    if [[ -f "$task_result_file" ]]; then
                        cat "$task_result_file" >> "$result_file"
                        rm -f "$task_result_file"  # Clean up individual task result file
                    else
                        echo "❌ ERROR: Task result file not found: $task_result_file" >> "$result_file"
                    fi
                done
            ) &

            local pid=$!
            pids+=("$pid")
            job_count=$((job_count + 1))

            echo "⚙️  Started repository group: $repo (PID: $pid)"
        done

        # Wait for all remaining jobs to complete
        echo "⏳ Waiting for all repository groups to complete..."
        for pid in "${pids[@]}"; do
            wait "$pid"
            echo "✅ Repository group completed (PID: $pid)"
        done

        echo "🎉 All repository groups completed"

        # Process results
        local successful=0
        local failed=0

        echo ""
        echo "📊 PARALLEL EXECUTION RESULTS"
        echo "════════════════════════════════════════"
        echo "🔍 Expected ${#result_files[@]} result files to process"

        for result_file in "${result_files[@]}"; do
            if [[ -f "$result_file" ]]; then
                echo "🔍 Processing result file: $result_file"
                while IFS='|' read -r status task_name start_time end_time duration log_file; do
                    # Skip empty lines and lines that don't match expected format
                    if [[ -z "$status" || -z "$task_name" ]]; then
                        continue
                    fi
                    if [[ "$status" == "SUCCESS" ]]; then
                        echo "✅ $task_name ($duration) - 📄 Log: $log_file"
                        successful=$((successful + 1))
                    elif [[ "$status" == "FAILED" ]]; then
                        echo "❌ $task_name ($duration) - 📄 Log: $log_file"
                        failed=$((failed + 1))
                    else
                        echo "⚠️  Unknown status '$status' for task $task_name"
                    fi
                done < "$result_file"
            else
                echo "❌ Result file not found: $result_file"
            fi
        done

        echo ""
        echo "📊 Result summary: $successful successful, $failed failed (total processed: $((successful + failed)))"
        echo "🎉 All parallel tasks completed!"

        # Cleanup temp directory
        rm -rf "$temp_dir"

        # Return results
        SUCCESSFUL=$successful
        FAILED=$failed
    }

    # Process all tasks
    execution_start_timestamp=$(format_timestamp)
    execution_start_time=$(date +%s)

    echo "🚀 Starting task execution..."
    echo "🕰️  Execution started at: $execution_start_timestamp"
    if [[ "$SAVE_LOGS" == "true" ]]; then
        echo "📁 Logs will be saved to: $LOG_DIR/"
    else
        echo "🖥️  Output will be printed directly (no logs saved)"
    fi

    SUCCESSFUL=0
    FAILED=0

    if [[ "$PARALLEL" == "true" ]]; then
        echo "🚀 Running in parallel mode (max $MAX_JOBS concurrent repository groups)"
        execute_parallel "${TASK_FILES[@]}"
    else
        echo "🔄 Running in sequential mode"
        for task_file in "${TASK_FILES[@]}"; do
            if run_task "$task_file"; then
                SUCCESSFUL=$((SUCCESSFUL + 1))
            else
                FAILED=$((FAILED + 1))
            fi
            echo ""
        done
    fi

    execution_end_timestamp=$(format_timestamp)
    execution_end_time=$(date +%s)
    total_duration=$(calculate_duration $execution_start_time $execution_end_time)
    formatted_total_duration=$(format_duration $total_duration)

    # Summary
    echo ""
    echo "📊 ═══════════════════════════════════════════════════════════════════════════════════"
    echo "📦 EXECUTION SUMMARY"
    echo "═══════════════════════════════════════════════════════════════════════════════════"
    echo "🕰️  Started at:    $execution_start_timestamp"
    echo "🏁 Finished at:   $execution_end_timestamp"
    echo "⏱️  Total duration: $formatted_total_duration"
    echo "✅ Successful:    $SUCCESSFUL"
    echo "❌ Failed:        $FAILED"
    echo "📁 Total tasks:   ${#TASK_FILES[@]}"
    echo "═══════════════════════════════════════════════════════════════════════════════════"

    if [[ $FAILED -gt 0 ]]; then
        echo ""
        if [[ "$SAVE_LOGS" == "true" ]]; then
            echo "⚠️  Some tasks failed. Check logs in $LOG_DIR/ for details."
        else
            echo "⚠️  Some tasks failed. See output above for details."
        fi
        echo "❌ Execution completed with failures."
        exit 1
    else
        echo ""
        echo "🎉 All tasks completed successfully!"
        echo "✅ Execution completed successfully."
        exit 0
    fi
fi