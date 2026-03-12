#!/usr/bin/env bash
# create-research.sh - Create a research note file
#
# Usage:
#   create-research.sh --title "Title" [--type <type>] [--json]
#
# Exit codes:
#   0 - Success
#   1 - Invalid arguments
#   3 - Template missing
#   4 - Filesystem error

set -euo pipefail

# ============================================================================
# Configuration
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../lib/logging.sh"
source "$SCRIPT_DIR/../../lib/timestamp-utils.sh"
source "$SCRIPT_DIR/../../lib/filename-utils.sh"
source "$SCRIPT_DIR/../../lib/common.sh"

REPO_ROOT="$(get_repo_root)"
TEMPLATE_PATH="$REPO_ROOT/.spectri/templates/spectri-trail/research-note-template.md"
RESEARCH_DIR="$REPO_ROOT/spectri/research"

# ============================================================================
# Utility Functions
# ============================================================================

usage() {
    cat <<EOF
Usage: create-research.sh --title "Title" [--type <type>] [--json]

Options:
  --title    Title for the research note (required)
  --type     Research type: architectural, tooling, pattern, integration, or custom (default: architectural)
  --json     Output result as JSON

Examples:
  create-research.sh --title "React server components evaluation"
  create-research.sh --title "CI pipeline options" --type tooling --json
EOF
}

# ============================================================================
# Main Logic
# ============================================================================

main() {
    local title=""
    local research_type="architectural"
    local json_output=false

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --title)
                title="$2"
                shift 2
                ;;
            --type)
                research_type="$2"
                shift 2
                ;;
            --json)
                json_output=true
                shift
                ;;
            --help|-h)
                usage
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                usage
                exit 1
                ;;
        esac
    done

    # Validate required arguments
    if [[ -z "$title" ]]; then
        log_error "Missing required argument: --title"
        usage
        exit 1
    fi

    # Check template exists
    if [[ ! -f "$TEMPLATE_PATH" ]]; then
        log_error "Template not found: $TEMPLATE_PATH"
        exit 3
    fi

    # Create target directory if needed
    if ! mkdir -p "$RESEARCH_DIR"; then
        log_error "Failed to create directory: $RESEARCH_DIR"
        exit 4
    fi

    # Generate filename
    local date_prefix
    date_prefix="$(get_date_timestamp)"
    local slug
    slug="$(slugify "$title")"
    local filename="${date_prefix}-${slug}-research.md"
    local filepath="$RESEARCH_DIR/$filename"

    # Get timestamp
    local full_date
    full_date="$(get_iso_timestamp)"

    # Copy template and substitute placeholders
    local content
    content=$(cat "$TEMPLATE_PATH")
    content=$(echo "$content" | sed "s|{{TITLE}}|${title}|g")
    content=$(echo "$content" | sed "s|{{DATE_ISO}}|${full_date}|g")
    content=$(echo "$content" | sed "s|{{AGENT_SESSION_ID}}|${AGENT_SESSION_ID:-unknown}|g")
    # Replace 'Researched By' with 'Agent' per SPECTRI.md standard
    content=$(echo "$content" | sed "s|^Researched By:.*|Agent: ${AGENT_SESSION_ID:-unknown}|")

    if ! echo "$content" > "$filepath"; then
        log_error "Failed to write research file: $filepath"
        exit 4
    fi

    # Stage the file
    if has_git; then
        git add "$filepath" 2>/dev/null || true
    fi

    # Output result
    local relative_path="${filepath#$REPO_ROOT/}"

    if $json_output; then
        cat <<EOF
{
  "filename": "$filename",
  "path": "$filepath",
  "relative_path": "$relative_path",
  "type": "$research_type"
}
EOF
    else
        echo "Research note created successfully"
        echo ""
        echo "Filename: $filename"
        echo "Path: $relative_path"
        echo "Type: $research_type"
        echo ""
        echo "Next steps:"
        echo "1. Fill in Purpose, Context, Findings, and Recommendations"
        echo "2. Update frontmatter Status as you progress (stub → in-progress → complete)"
        echo "3. Commit when complete"
    fi
}

# Run main
main "$@"
