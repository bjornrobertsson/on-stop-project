# On-Stop Script Improvements Guide

This guide explains the improvements made to your Terraform/Coder on-stop scripts and how to implement them.

## Issues Identified in Original Scripts

### 1. Authentication Problems
- **Issue**: Complex, unreliable token handling with multiple fallback methods
- **Impact**: Scripts failing silently or with authentication errors
- **Solution**: Streamlined authentication flow with proper error handling

### 2. Missing Error Handling
- **Issue**: Many operations lacked proper error checking
- **Impact**: Scripts continuing after failures, leading to unexpected behavior
- **Solution**: Added comprehensive error handling with `set -euo pipefail`

### 3. Race Conditions
- **Issue**: Scripts assumed files and directories existed
- **Impact**: Failures when expected resources weren't available
- **Solution**: Added proper validation and conditional execution

### 4. Poor Logging
- **Issue**: Inconsistent logging to `/home/coder/logger.txt`
- **Impact**: Difficult to debug issues
- **Solution**: Structured logging with timestamps and proper log management

### 5. Hardcoded Paths
- **Issue**: Scripts used hardcoded paths that might not exist
- **Impact**: Failures in different environments
- **Solution**: Configurable paths with validation

## Improved Files Created

### 1. `improved_shutdown_script.tf`
**Enhanced shutdown script with:**
- Robust authentication flow
- Comprehensive error handling
- Configurable git operations
- Better logging and debugging
- Graceful failure handling

### 2. `improved_startup_script.tf`
**Enhanced startup script with:**
- Token caching for shutdown use
- Environment setup
- Connectivity testing
- Proper workspace initialization

### 3. `modules/coder-logout/improved_run.sh`
**Improved authentication module with:**
- Multiple authentication methods
- Better error messages
- Proper logging
- Fallback mechanisms

### 4. `on-stop-config.env`
**Configuration file for:**
- Customizing script behavior
- Enabling/disabling features
- Setting paths and options
- Debug mode control

### 5. `main-improved.tf`
**Complete improved main.tf with:**
- All enhanced scripts integrated
- Configuration support
- Better resource organization

## Implementation Steps

### Step 1: Backup Current Configuration
```bash
cp main.tf main.tf.backup
cp modules/coder-logout/run.sh modules/coder-logout/run.sh.backup
```

### Step 2: Deploy Configuration File
```bash
# Copy the configuration file to your workspace
cp on-stop-config.env /home/coder/on-stop-config.env

# Customize the configuration as needed
vim /home/coder/on-stop-config.env
```

### Step 3: Update Coder-Logout Module
```bash
# Replace the existing run.sh with the improved version
cp modules/coder-logout/improved_run.sh modules/coder-logout/run.sh
chmod +x modules/coder-logout/run.sh
```

### Step 4: Update Main Configuration
**Option A: Replace entire main.tf**
```bash
cp main-improved.tf main.tf
# Add your existing workspace/agent configuration to main.tf
```

**Option B: Add improved scripts to existing main.tf**
```bash
# Add the contents of improved_shutdown_script.tf and improved_startup_script.tf
# to your existing main.tf file
```

### Step 5: Test the Configuration
```bash
# Initialize and plan
terraform init
terraform plan

# Apply changes
terraform apply
```

## Testing Your Improvements

### 1. Test Startup Script
- Start a new workspace
- Check `/home/coder/startup.log` for successful execution
- Verify token caching in `/home/coder/.cache/coder/`
- Confirm `/tmp/logout_token` exists

### 2. Test Shutdown Script
- Stop the workspace
- Check `/home/coder/shutdown.log` for execution details
- Verify git operations completed successfully
- Check for any error messages

### 3. Debug Mode
```bash
# Enable debug mode in configuration
echo 'DEBUG_MODE=true' >> /home/coder/on-stop-config.env

# Restart workspace to see detailed execution
```

## Configuration Options

### Key Settings in `on-stop-config.env`

```bash
# Enable/disable git operations
GIT_AUTO_UNSHALLOW=true
GIT_AUTO_COMMIT=true
GIT_AUTO_PUSH=true

# Customize git repository path
GIT_REPO_PATH="src/server/shallow"

# Control file operations
CREATE_RANDOM_FILES=true
RANDOM_FILE_SOURCE="test2.py"

# Debug and logging
DEBUG_MODE=false
VERBOSE_LOGGING=true
```

## Troubleshooting

### Debugging Scripts

All scripts use `set -euo pipefail` for strict error handling. When debugging issues:

1. **Enable Debug Mode**: Replace `set -euo pipefail` with `set -euxo pipefail` to see each command as it executes
2. **Check Log Files**: Review the detailed logs in `/home/coder/shutdown.log` and `/home/coder/startup.log`
3. **Test Individual Commands**: SSH into the workspace and run commands manually

### Common Issues

1. **Authentication Failures**
   - Check log files for specific error messages
   - Verify `CODER_USER_TOKEN` is available
   - Ensure `/tmp/logout_token` exists and is readable

2. **Git Operations Failing**
   - Verify git repository exists and is accessible
   - Check GitHub token caching in startup script
   - Ensure proper git configuration

3. **Script Not Running**
   - Verify `run_on_stop = true` is set
   - Check Terraform apply was successful
   - Look for syntax errors in logs

### Log Files to Check
- `/home/coder/startup.log` - Startup script execution
- `/home/coder/shutdown.log` - Shutdown script execution
- `/home/coder/coder-auth.log` - Authentication attempts

### Debug Commands
```bash
# Test authentication manually
coder list

# Check cached tokens
ls -la /home/coder/.cache/coder/
ls -la /tmp/logout_token

# Test git operations
cd src/server/shallow
git status
git fetch --dry-run
```

## Benefits of Improvements

1. **Reliability**: Scripts handle errors gracefully and continue operation
2. **Debuggability**: Comprehensive logging makes troubleshooting easier
3. **Flexibility**: Configuration file allows customization without code changes
4. **Maintainability**: Cleaner, more organized code structure
5. **Robustness**: Multiple fallback mechanisms for authentication and operations

## Next Steps

1. Test the improved scripts in your environment
2. Customize the configuration file for your specific needs
3. Monitor the log files to ensure everything works as expected
4. Consider adding additional features like notifications or cleanup tasks

The improved scripts should provide much more reliable on-stop functionality with better error handling and debugging capabilities.