---
display_name: Kubernetes (Deployment)
description: Provision Kubernetes Deployments as Coder workspaces
icon: ../../../site/static/icon/k8s.png
maintainer_github: coder
verified: true
tags: [kubernetes, container]
---

# Test On-Stop Improved Template

This is an improved version of the on-stop template with fixed git authentication.

## Key Improvements

### Fixed Git Authentication
- The shutdown script now properly configures git authentication using cached GitHub tokens
- When pushing changes on workspace stop, the script:
  1. Checks for a cached GitHub token at `/home/coder/.cache/coder/github_token`
  2. Temporarily modifies the git remote URL to include the token for authentication
  3. Performs the git push operation
  4. Restores the original remote URL (removing the token for security)

### Error Handling
- Better error handling for git operations
- Detailed logging of authentication steps
- Fallback behavior when tokens are not available

## Usage

The template will automatically:
1. Cache GitHub tokens during workspace startup
2. Use these tokens for git operations during workspace shutdown
3. Commit and push any uncommitted changes when the workspace stops

## Troubleshooting

If git push fails:
1. Check that GitHub external auth is properly configured in Coder
2. Verify the cached token exists: `ls -la /home/coder/.cache/coder/github_token`
3. Check the shutdown logs: `cat /home/coder/shutdown.log`

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
