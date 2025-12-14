#!/bin/bash

# Gemini Ex Examples Runner
# Run all numbered examples in sequence

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Quiet mode (suppress example output)
QUIET=false
if [[ "$1" == "-q" || "$1" == "--quiet" ]]; then
    QUIET=true
fi

# Check authentication
check_auth() {
    if [[ -n "$GEMINI_API_KEY" ]]; then
        masked="${GEMINI_API_KEY:0:4}...${GEMINI_API_KEY: -4}"
        echo -e "${GREEN}Auth: Gemini API Key ($masked)${NC}"
        return 0
    elif [[ -n "$VERTEX_JSON_FILE" || -n "$GOOGLE_APPLICATION_CREDENTIALS" ]]; then
        echo -e "${GREEN}Auth: Vertex AI / Application Credentials${NC}"
        return 0
    else
        echo -e "${RED}ERROR: No authentication configured!${NC}"
        echo "Set GEMINI_API_KEY or VERTEX_JSON_FILE environment variable."
        exit 1
    fi
}

# Run a single example
run_example() {
    local file="$1"
    local name=$(basename "$file")

    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}Running: $name${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

    cd "$PROJECT_DIR"

    if $QUIET; then
        # Quiet mode - only show pass/fail
        if mix run "$file" >/dev/null 2>&1; then
            echo -e "${GREEN}[OK] $name completed successfully${NC}"
            return 0
        else
            echo -e "${RED}[FAIL] $name failed${NC}"
            return 1
        fi
    else
        # Default: show full output (filter noisy log lines)
        mix run "$file" 2>&1 | grep -v "\[info\].*streaming manager" | grep -v "\[debug\]"
        if [[ ${PIPESTATUS[0]} -eq 0 ]]; then
            echo -e "${GREEN}[OK] $name completed successfully${NC}"
            return 0
        else
            echo -e "${RED}[FAIL] $name failed${NC}"
            return 1
        fi
    fi
}

# Main
echo ""
echo -e "${YELLOW}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${YELLOW}║          GEMINI EX - EXAMPLES RUNNER                       ║${NC}"
echo -e "${YELLOW}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

check_auth
echo ""

# Find all numbered examples
examples=($(ls -1 "$SCRIPT_DIR"/[0-9][0-9]_*.exs 2>/dev/null | sort))

if [[ ${#examples[@]} -eq 0 ]]; then
    echo -e "${RED}No examples found!${NC}"
    exit 1
fi

echo -e "Found ${#examples[@]} examples to run"

if ! $QUIET; then
    echo -e "${YELLOW}(Use -q for quiet mode - only show pass/fail)${NC}"
fi

# Counters
passed=0
failed=0
failed_examples=()

# Run each example
for example in "${examples[@]}"; do
    if run_example "$example"; then
        passed=$((passed + 1))
    else
        failed=$((failed + 1))
        failed_examples+=("$(basename "$example")")
    fi

    # Small delay to avoid rate limiting
    sleep 1
done

# Summary
echo ""
echo -e "${YELLOW}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${YELLOW}║                      SUMMARY                               ║${NC}"
echo -e "${YELLOW}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

echo -e "Total:  ${#examples[@]}"
echo -e "${GREEN}Passed: $passed${NC}"

if [[ $failed -gt 0 ]]; then
    echo -e "${RED}Failed: $failed${NC}"
    echo ""
    echo -e "${RED}Failed examples:${NC}"
    for f in "${failed_examples[@]}"; do
        echo -e "  - $f"
    done
    exit 1
else
    echo -e "${GREEN}All examples passed!${NC}"
fi

echo ""
