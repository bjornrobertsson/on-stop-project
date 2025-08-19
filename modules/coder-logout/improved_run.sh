#!/usr/bin/env bash
# When debugging this could be detrimental and set -x might help troubleshooting
set -euo pipefail

# Improved Coder logout/authentication script
# This script handles authentication more reliably

# Configuration
LOG_FILE="/home/coder/coder-auth.log"
BOLD='\033[0;1m'
RESET='\033[0m'

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Initialize log
mkdir -p "$(dirname "$LOG_FILE")"
log "=== Starting Coder authentication ==="

printf "${BOLD}Authenticating with Coder...\n\n${RESET}"

# Function to test if already authenticated
test_auth() {
    if coder list >/dev/null 2>&1; then
        log "Already authenticated with Coder"
        echo "You are already authenticated with Coder."
        return 0
    fi
    return 1
}

# Function to authenticate with token
auth_with_token() {
    local token="$1"
    local url="$2"
    local description="$3"
    
    if [[ -z "$token" || -z "$url" ]]; then
        log "Missing token or URL for $description"
        return 1
    fi
    
    log "Attempting authentication with $description"
    if coder login --token="$token" --url="$url" 2>&1 | tee -a "$LOG_FILE"; then
        log "Successfully authenticated with $description"
        return 0
    else
        log "Failed to authenticate with $description"
        return 1
    fi
}

# Main authentication logic
main() {
    # Test if already authenticated
    if test_auth; then
        return 0
    fi
    
    # Try authentication with provided token
    if auth_with_token "${CODER_USER_TOKEN:-}" "${CODER_DEPLOYMENT_URL:-}" "provided user token"; then
        return 0
    fi
    
    # Try with environment variables
    if auth_with_token "${CODER_SESSION_TOKEN:-}" "${CODER_URL:-}" "session token"; then
        return 0
    fi
    
    # Try with cached token
    if [[ -f "/tmp/logout_token" ]]; then
        local cached_token
        cached_token=$(cat "/tmp/logout_token" 2>/dev/null || echo "")
        if auth_with_token "$cached_token" "${CODER_DEPLOYMENT_URL:-${CODER_URL:-}}" "cached logout token"; then
            return 0
        fi
    fi
    
    log "All authentication methods failed"
    echo "Failed to authenticate with Coder. Please check your tokens and URL."
    return 1
}

# Run main function
if main; then
    log "=== Coder authentication completed successfully ==="
else
    log "=== Coder authentication failed ==="
    exit 1
fi