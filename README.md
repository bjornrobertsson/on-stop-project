---
display_name: Kubernetes (Deployment)
description: Provision Kubernetes Deployments as Coder workspaces
icon: ../../../site/static/icon/k8s.png
maintainer_github: coder
verified: true
tags: [kubernetes, container]
---

# Test On-Stop Improved Template

This template demonstrates a **workaround** for git authentication during workspace shutdown, addressing a bug where the Coder agent loses authorization before `run_on_stop` scripts complete.

## Current Implementation (Workaround)

### Token Caching Approach
Due to a bug where the agent loses authorization during `run_on_stop` execution, this template uses a workaround:
- **Startup**: Caches GitHub tokens during workspace startup when external auth is available
- **Shutdown**: Uses cached tokens for git operations during workspace stop
- **Security**: Tokens are stored with restricted permissions (600) in `~/.cache/coder/`

### Process Flow
1. **Workspace Start**: Cache `coder external-auth access-token GH` to `~/.cache/coder/github_token`
2. **Workspace Stop**: Use cached token for git authentication instead of live external auth
3. **Git Operations**: Commit and push any uncommitted changes when workspace stops
4. **Branch Management**: Automatically switches to main/master branch and handles auto-merge

## Known Issues & Limitations

### Agent Authorization Bug
This workaround exists because of a bug in Coder where:
- The agent loses authorization before `run_on_stop` scripts complete
- `coder external-auth access-token` fails with "Workspace agent not authorized"
- API connectivity is lost during script execution
- This violates the documented behavior that scripts should complete before agent shutdown

### Workaround Limitations
- **Security**: Tokens are stored on disk in the workspace
- **Expiration**: Tokens may expire during long-running workspaces
- **Complexity**: Additional startup logic required for token caching
- **Reliability**: Dependent on successful token caching during startup

## Ideal Solution

The proper fix would be to ensure the agent maintains authorization until `run_on_stop` scripts complete, as documented. This would allow:
```bash
# This should work but currently fails:
GITHUB_TOKEN=$(coder external-auth access-token GH)
```

## Auto-Merge and Branch Management
- Automatically switches to main/master branch before pushing
- Creates main branch if it doesn't exist locally
- Detects whether remote uses 'main' or 'master' as default branch
- Sets up proper upstream tracking automatically
- Uses `git push origin HEAD:main` to ensure push goes to the correct branch
- Includes force-with-lease fallback for cases where fast-forward isn't possible

## Proper Agent Lifecycle
- The `run_on_stop` script properly signals completion before the workspace stops
- No token caching during startup eliminates security risks and complexity
- Direct external-auth access works as long as the agent is running

## Error Handling
- Better error handling for git operations
- Detailed logging of authentication steps
- Graceful fallback when external auth is not available
- Comprehensive debugging information for troubleshooting

## Usage

The template will automatically:
1. Clone the specified git repository during workspace startup
2. Use direct external-auth access for git operations during workspace shutdown
3. Commit and push any uncommitted changes when the workspace stops

## Security Benefits

- **No token storage**: Tokens are never written to disk or cached in the workspace
- **Fresh tokens**: Each operation gets a new token, avoiding expiration issues
- **Minimal exposure**: Tokens are only in memory briefly during the push operation
- **Immediate cleanup**: Remote URLs are restored immediately after use

## Troubleshooting

If git push fails:
1. Check that GitHub external auth is properly configured in Coder
2. Verify the agent can access the Coder API during shutdown
3. Check the shutdown logs: `cat /home/coder/shutdown.log`
4. Ensure the workspace has the necessary permissions for the repository

## Technical Notes

This approach relies on the fact that during `run_on_stop` execution:
- The Coder agent is still running and can make API calls
- External auth tokens are accessible via `coder external-auth access-token`
- The script completion signals when the workspace can be safely stopped

This is the recommended approach as it's more secure, reliable, and follows Coder's intended agent lifecycle.

# Remote Development on Kubernetes Pods

Provision Kubernetes Pods as [Coder workspaces](https://coder.com/docs/workspaces) with this example template.

<!-- TODO: Add screenshot -->

## Prerequisites

### Infrastructure

**Cluster**: This template requires an existing Kubernetes cluster

**Container Image**: This template uses the [codercom/enterprise-base:ubuntu image](https://github.com/coder/enterprise-images/tree/main/images/base) with some dev tools preinstalled. To add additional tools, extend this image or build it yourself.

### Authentication

This template authenticates using a `~/.kube/config`, if present on the server, or via built-in authentication if the Coder provisioner is running on Kubernetes with an authorized ServiceAccount. To use another [authentication method](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs#authentication), edit the template.

## Architecture

This template provisions the following resources:

- Kubernetes pod (ephemeral)
- Kubernetes persistent volume claim (persistent on `/home/coder`)

This means, when the workspace restarts, any tools or files outside of the home directory are not persisted. To pre-bake tools into the workspace (e.g. `python3`), modify the container image. Alternatively, individual developers can [personalize](https://coder.com/docs/dotfiles) their workspaces with dotfiles.

> **Note**
> This template is designed to be a starting point! Edit the Terraform to extend the template to support your use case.
