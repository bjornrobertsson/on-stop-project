terraform {
  required_providers {
    coder = {
      source = "coder/coder"
    }
    kubernetes = {
      source = "hashicorp/kubernetes"
    }
  }
}

module "coder-logout" {
  count               = data.coder_workspace.me.start_count
  source              = "./modules/coder-logout"
#  version             = "1.0.23"
  agent_id = coder_agent.main.id
}

module "coder-login" {
  count    = data.coder_workspace.me.start_count
  source   = "registry.coder.com/coder/coder-login/coder"
  version  = "1.0.15"
  agent_id = coder_agent.main.id
}


module "jetbrains_gateway" {
  count          = data.coder_workspace.me.start_count
  source         = "registry.coder.com/modules/jetbrains-gateway/coder"
  version        = "1.0.28"
  agent_id       = coder_agent.main.id
  folder         = "/home/coder"
  jetbrains_ides = ["CL", "GO", "IU", "PY", "WS"]
  default        = "GO"
}

module "filebrowser" {
  count    = data.coder_workspace.me.start_count
  source   = "registry.coder.com/modules/filebrowser/coder"
  version  = "1.0.23"
  agent_id = coder_agent.main.id
}


provider "coder" {
}

# Prompt the user for the git repo URL
data "coder_parameter" "git_repo" {
  name         = "git_repo"
  display_name = "Git repository"
  description  = "Git repository to clone"
  type         = "string"
  default      = "https://github.com/bjornrobertsson/shallow"
  mutable      = true
  icon         = "/icon/git.svg"
}

# Clone the repository for branch `feat/example`
module "git_clone" {
  count    = data.coder_workspace.me.start_count
  source   = "registry.coder.com/coder/git-clone/coder"
  version  = "1.0.18"
  agent_id = coder_agent.main.id
  url      = data.coder_parameter.git_repo.value
  base_dir = "~/src/server"
}



variable "use_kubeconfig" {
  type        = bool
  description = <<-EOF
  Use host kubeconfig? (true/false)

  Set this to false if the Coder host is itself running as a Pod on the same
  Kubernetes cluster as you are deploying workspaces to.

  Set this to true if the Coder host is running outside the Kubernetes cluster
  for workspaces.  A valid "~/.kube/config" must be present on the Coder host.
  EOF
  default     = false
}

variable "namespace" {
  type        = string
  description = "The Kubernetes namespace to create workspaces in (must exist prior to creating workspaces). If the Coder host is itself running as a Pod on the same Kubernetes cluster as you are deploying workspaces to, set this to the same namespace."
  default = "coder"
  # sensitive = true
}

data "coder_parameter" "cpu" {
  name         = "cpu"
  display_name = "CPU"
  description  = "The number of CPU cores"
  type         = "number"
  default      = "2"
  mutable      = true
  icon         = "/icon/memory.svg"
  option {
    name  = "2 Cores"
    value = "2"
  }
  option {
    name  = "4 Cores"
    value = "4"
  }
  option {
    name  = "6 Cores"
    value = "6"
  }
  option {
    name  = "8 Cores"
    value = "8"
  }
}

data "coder_parameter" "memory" {
  name         = "memory"
  display_name = "Memory"
  description  = "The amount of memory in GB"
  type         = "number"
  default      = "4"
  mutable      = true
  icon         = "/icon/memory.svg"
  option {
    name  = "4 GB"
    value = "4"
  }
  option {
    name  = "8 GB"
    value = "8"
  }
  option {
    name  = "16 GB"
    value = "16"
  }
  option {
    name  = "32 GB"
    value = "32"
  }
}

data "coder_parameter" "home_disk_size" {
  name         = "home_disk_size"
  display_name = "Home disk size"
  description  = "The size of the home disk in GB"
  type         = "number"
  default      = "10"
  mutable      = true
  icon         = "/icon/folder.svg"
  validation {
    min = 1
    max = 99999
  }
}

data "coder_parameter" "namespace" {
  name = "Coder Namespace"
  default = "coder"
  mutable = false
}

provider "kubernetes" {
  # Authenticate via ~/.kube/config or a Coder-specific ServiceAccount, depending on admin preferences
  config_path = var.use_kubeconfig == true ? "~/.kube/config" : null
}

data "coder_workspace" "me" {}
data "coder_workspace_owner" "me" {}

resource "coder_agent" "main" {
  os             = "linux"
  arch           = "amd64"
  startup_script = <<-EOT
      set -e

      # 
      echo "data.coder_workspace_ownder.me.id value is :  ${data.coder_workspace_owner.me.id}"

      # Install the latest code-server.
      # Append "--version x.x.x" to install a specific version of code-server.
      curl -fsSL https://code-server.dev/install.sh | sh -s -- --method=standalone --prefix=/tmp/code-server
      # From the Coder extension marketplace
      /tmp/code-server/bin/code-server --install-extension ms-toolsai.jupyter

      # Start code-server in the background.
      /tmp/code-server/bin/code-server --auth none --port 13337 >/tmp/code-server.log 2>&1 &

      # Export token environment variable (injected by Terraform)
      export CODER_SESSION_TOKEN="${data.coder_workspace_owner.me.session_token}"
      echo "CODER_SESSION_TOKEN: $${CODER_SESSION_TOKEN}"
      TOKEN=$${CODER_SESSION_TOKEN}
      # Print token for debugging (don't do this in production!)
      echo "DEBUG: Using token: $${TOKEN}"

      # Store environment variables for authentication
      echo "CODER_AGENT_TOKEN=$${CODER_AGENT_TOKEN}" > /home/coder/.cache/coder/auth_tokens
      echo "CODER_SESSION_TOKEN=$${CODER_SESSION_TOKEN}" >> /home/coder/.cache/coder/auth_tokens

      # Set Coder URL
      CODER_URL="$${CODER_URL:-https://rcoder.sal.za.net}"
      echo "Using Coder URL: $${CODER_URL}"
      echo "----------------------------------------"

      # Get workspace organization ID
      if [ -n "$${CODER_WORKSPACE_NAME}" ]; then
        echo "Workspace: $${CODER_WORKSPACE_NAME}"

        WORKSPACE_ORG_ID=$(curl -s -X GET "$${CODER_URL}/api/v2/users/me/workspace/$${CODER_WORKSPACE_NAME}" \
          -H 'Accept: application/json' \
          -H "Coder-Session-Token: $${TOKEN}" | jq -r '.latest_build.job.organization_id')

        if [ "$${WORKSPACE_ORG_ID}" != "null" ]; then
          echo "Workspace Org ID: $${WORKSPACE_ORG_ID}"
        fi
        echo "----------------------------------------"
      fi

      # Get user info
      USER_INFO=$(curl -s -X GET "$${CODER_URL}/api/v2/users/me" \
        -H 'Accept: application/json' \
        -H "Coder-Session-Token: $${TOKEN}")

      USERNAME=$(echo "$${USER_INFO}" | jq -r '.username')
      NAME=$(echo "$${USER_INFO}" | jq -r '.name')
      EMAIL=$(echo "$${USER_INFO}" | jq -r '.email')
      USER_ID=$(echo "$${USER_INFO}" | jq -r '.id')

      echo "User Info:"
      echo "Username: $${USERNAME}"
      echo "Name: $${NAME}"
      echo "Email: $${EMAIL}"
      echo "ID: $${USER_ID}"
      echo

      # Get the specific organization for this workspace template
      if [ -n "$${WORKSPACE_ORG_ID}" ] && [ "$${WORKSPACE_ORG_ID}" != "null" ]; then
        ORG_INFO=$(curl -s -X GET "$${CODER_URL}/api/v2/organizations/$${WORKSPACE_ORG_ID}" \
          -H 'Accept: application/json' \
          -H "Coder-Session-Token: $${TOKEN}")

        if [ -n "$${ORG_INFO}" ]; then
          ORG_NAME=$(echo "$${ORG_INFO}" | jq -r '.name')
          ORG_DISPLAY=$(echo "$${ORG_INFO}" | jq -r '.display_name')
          
          if [ "$${ORG_DISPLAY}" != "null" ] && [ -n "$${ORG_DISPLAY}" ]; then
            ORG_FULL="$${ORG_NAME} ($${ORG_DISPLAY})"
          else
            ORG_FULL="$${ORG_NAME}"
          fi

          echo "Template Organization:"
          echo "| Username | Name | Email | Organization | Org ID |"
          echo "|----------|------|-------|--------------|--------|"
          printf "| %-8s | %-4s | %-5s | %-12s | %-7s |\n" \
            "$${USERNAME}" "$${NAME}" "$${EMAIL}" "$${ORG_FULL}" "$${WORKSPACE_ORG_ID}"
        else
          echo "Could not retrieve organization information for ID: $${WORKSPACE_ORG_ID}"
        fi
      else
        echo "No workspace organization ID found"
      fi
      echo "Storing GitHub token"
      coder external-auth access-token GH > ~/.cache/coder/github_token
      echo "Storing a temporary token *defaults to 24hours*"
      coder tokens rm logout_token
      coder tokens create -n logout_token  > /tmp/logout_token
      echo "New token: $(cat /tmp/logout_token)"

  EOT


  # The following metadata blocks are optional. They are used to display
  # information about your workspace in the dashboard. You can remove them
  # if you don't want to display any information.
  # For basic resources, you can use the `coder stat` command.
  # If you need more control, you can write your own script.
  metadata {
    display_name = "CPU Usage"
    key          = "0_cpu_usage"
    script       = "coder stat cpu"
    interval     = 10
    timeout      = 1
  }

  metadata {
    display_name = "RAM Usage"
    key          = "1_ram_usage"
    script       = "coder stat mem"
    interval     = 10
    timeout      = 1
  }

  metadata {
    display_name = "Home Disk"
    key          = "3_home_disk"
    script       = "coder stat disk --path $${HOME}"
    interval     = 60
    timeout      = 1
  }

  metadata {
    display_name = "CPU Usage (Host)"
    key          = "4_cpu_usage_host"
    script       = "coder stat cpu --host"
    interval     = 10
    timeout      = 1
  }

  metadata {
    display_name = "Memory Usage (Host)"
    key          = "5_mem_usage_host"
    script       = "coder stat mem --host"
    interval     = 10
    timeout      = 1
  }

  metadata {
    display_name = "Load Average (Host)"
    key          = "6_load_host"
    # get load avg scaled by number of cores
    script   = <<EOT
      echo "`cat /proc/loadavg | awk '{ print $1 }'` `nproc`" | awk '{ printf "%0.2f", $1/$2 }'
    EOT
    interval = 60
    timeout  = 1
  }
}

# code-server
resource "coder_app" "code-server" {
  agent_id     = coder_agent.main.id
  slug         = "code-server"
  display_name = "code-server"
  icon         = "/icon/code.svg"
  url          = "http://localhost:13337?folder=/home/coder"
  subdomain    = true
  share        = "owner"

  healthcheck {
    url       = "http://localhost:13337/healthz"
    interval  = 3
    threshold = 10
  }
}

resource "kubernetes_persistent_volume_claim" "home" {
  metadata {
    name      = "coder-${data.coder_workspace.me.id}-home"
    namespace = var.namespace
    labels = {
      "app.kubernetes.io/name"     = "coder-pvc"
      "app.kubernetes.io/instance" = "coder-pvc-${data.coder_workspace.me.id}"
      "app.kubernetes.io/part-of"  = "coder"
      //Coder-specific labels.
      "com.coder.resource"       = "true"
      "com.coder.workspace.id"   = data.coder_workspace.me.id
      "com.coder.workspace.name" = data.coder_workspace.me.name
      "com.coder.user.id"        = data.coder_workspace_owner.me.id
      "com.coder.user.username"  = data.coder_workspace_owner.me.name
    }
    annotations = {
      "com.coder.user.email" = data.coder_workspace_owner.me.email
    }

  }
  wait_until_bound = false
  spec {
    access_modes = ["ReadWriteOnce"]
    resources {
      requests = {
        storage = "${data.coder_parameter.home_disk_size.value}Gi"
      }
    }
#    storage_class_name = "nfs-client"
#    storage_class_name = "longhorn"
    storage_class_name = "truenas-iscsi-nonroot"

  }
}

resource "kubernetes_deployment" "main" {
  count = data.coder_workspace.me.start_count
  depends_on = [
    kubernetes_persistent_volume_claim.home
  ]
  wait_for_rollout = false
  metadata {
    name      = "coder-${data.coder_workspace.me.id}"
    namespace = var.namespace
    labels = {
      "app.kubernetes.io/name"     = "coder-workspace"
      "app.kubernetes.io/instance" = "coder-workspace-${data.coder_workspace.me.id}"
      "app.kubernetes.io/part-of"  = "coder"
      "com.coder.resource"         = "true"
      "com.coder.workspace.id"     = data.coder_workspace.me.id
      "com.coder.workspace.name"   = data.coder_workspace.me.name
      "com.coder.user.id"          = data.coder_workspace_owner.me.id
      "com.coder.user.username"    = data.coder_workspace_owner.me.name
    }
    annotations = {
      "com.coder.user.email" = data.coder_workspace_owner.me.email
    }
  }

  spec {
    replicas = 1
    selector {
      match_labels = {
        "app.kubernetes.io/name"     = "coder-workspace"
        "app.kubernetes.io/instance" = "coder-workspace-${data.coder_workspace.me.id}"
        "app.kubernetes.io/part-of"  = "coder"
        "com.coder.resource"         = "true"
        "com.coder.workspace.id"     = data.coder_workspace.me.id
        "com.coder.workspace.name"   = data.coder_workspace.me.name
        "com.coder.user.id"          = data.coder_workspace_owner.me.id
        "com.coder.user.username"    = data.coder_workspace_owner.me.name
      }
    }
    strategy {
      type = "Recreate"
    }

    template {
      metadata {
        labels = {
          "app.kubernetes.io/name"     = "coder-workspace"
          "app.kubernetes.io/instance" = "coder-workspace-${data.coder_workspace.me.id}"
          "app.kubernetes.io/part-of"  = "coder"
          "com.coder.resource"         = "true"
          "com.coder.workspace.id"     = data.coder_workspace.me.id
          "com.coder.workspace.name"   = data.coder_workspace.me.name
          "com.coder.user.id"          = data.coder_workspace_owner.me.id
          "com.coder.user.username"    = data.coder_workspace_owner.me.name
        }
      }
      spec {
        toleration {
          key      = "nvidia.com/gpu.present"
          operator = "Exists"
          effect   = "NoSchedule"
        }
        node_selector = {
          "nvidia.com/gpu.present" = "false"  # Adjust based on your cluster labels
        }

        security_context {
          run_as_user = 1000
          fs_group    = 1000
        }

        init_container {
          name              = "controller"
          image             = "ubuntu"
          image_pull_policy = "Always"
          command           = ["sh", "-c", "${local.controller_init_script}"]
        }



        container {
          name              = "dev"
          image             = "codercom/enterprise-base:ubuntu"
          image_pull_policy = "Always"
          command           = ["sh", "-c", coder_agent.main.init_script]
          security_context {
            run_as_user = "1000"
          }
          env {
            name  = "CODER_AGENT_TOKEN"
            value = coder_agent.main.token
          }
          resources {
            requests = {
              "cpu"    = "250m"
              "memory" = "512Mi"
            }
            limits = {
              "cpu"    = "${data.coder_parameter.cpu.value}"
              "memory" = "${data.coder_parameter.memory.value}Gi"
            }
          }
          volume_mount {
            mount_path = "/home/coder"
            name       = "home"
            read_only  = false
          }
        }

        volume {
          name = "home"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim.home.metadata.0.name
            read_only  = false
          }
        }

        affinity {
          // This affinity attempts to spread out all workspace pods evenly across
          // nodes.
          pod_anti_affinity {
            preferred_during_scheduling_ignored_during_execution {
              weight = 1
              pod_affinity_term {
                topology_key = "kubernetes.io/hostname"
                label_selector {
                  match_expressions {
                    key      = "app.kubernetes.io/name"
                    operator = "In"
                    values   = ["coder-workspace"]
                  }
                }
              }
            }
          }
        }
      }
    }
  }
}

locals {
  controller_init_script = <<-EOT
    echo "Running controller init container"
    echo "Namespace: ${var.namespace}"
    echo "Workspace ID: ${data.coder_workspace.me.id}"
    echo "Workspace Name: ${data.coder_workspace.me.name}"
    echo "Owner Email: ${data.coder_workspace_owner.me.email}"
    # Add any logic you want to test
    sleep 5
    echo "Controller init done"
  EOT
}

resource "coder_script" "shutdown_script" {
  agent_id     = coder_agent.main.id
  display_name = "On-Stop Demo Script"
  icon         = "/icon/git.svg"
  run_on_stop  = true

  script = <<-EOT
   #!/usr/bin/bash
   set -euo pipefail
   
   # Configuration
   LOG_FILE="/home/coder/shutdown.log"
   WORK_DIR="/home/coder"
   GIT_BASE_DIR="/home/coder/src/server"
   
   # Logging function
   log() {
     echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
   }
   
   log "=== On-stop demo script started ==="
   
   # Example 1: Basic system information
   log "System information:"
   log "Hostname: $(hostname)"
   log "Uptime: $(uptime)"
   log "Disk usage: $(df -h / | tail -1)"
   
   # Example 2: Workspace information
   log "Workspace information:"
   log "Workspace name: ${data.coder_workspace.me.name}"
   log "Workspace owner: ${data.coder_workspace_owner.me.name}"
   log "Workspace ID: ${data.coder_workspace.me.id}"
   
   # Example 3: Test Coder API connectivity
   if curl -s -H "Coder-Session-Token: $${CODER_AGENT_TOKEN}" "$${CODER_URL}/api/v2/workspaces" >/dev/null 2>&1; then
     log "Coder API connectivity: OK"
   else
     log "Coder API connectivity: FAILED"
   fi
   
   # Example 4: Find and process Git repository
   log "Looking for Git repositories in $GIT_BASE_DIR..."
   
   if [[ -d "$GIT_BASE_DIR" ]]; then
     # Find the first git repository in the base directory
     GIT_REPO_PATH=$(find "$GIT_BASE_DIR" -name ".git" -type d -exec dirname {} \; | head -1)
     
     if [[ -n "$GIT_REPO_PATH" && -d "$GIT_REPO_PATH" ]]; then
       log "Found Git repository at: $GIT_REPO_PATH"
       cd "$GIT_REPO_PATH" || { log "Failed to enter git directory"; cd "$WORK_DIR"; }
       
       if [[ -d ".git" ]]; then
         log "Git status:"
         git status --porcelain 2>&1 | tee -a "$LOG_FILE" || log "Git status failed"
         
         log "Current branch: $(git branch --show-current 2>/dev/null || echo 'unknown')"
         log "All branches: $(git branch -a 2>/dev/null || echo 'no branches')"
         log "Remote branches: $(git branch -r 2>/dev/null || echo 'no remote branches')"
         log "Remote URL: $(git remote get-url origin 2>/dev/null || echo 'no remote')"
         log "Last commit: $(git log -1 --oneline 2>/dev/null || echo 'no commits')"
         log "Upstream branch: $(git rev-parse --abbrev-ref --symbolic-full-name @{u} 2>/dev/null || echo 'no upstream')"
         
         # Check if repository is shallow
         if git rev-parse --is-shallow-repository >/dev/null 2>&1 && [[ "$(git rev-parse --is-shallow-repository)" == "true" ]]; then
           log "Repository is shallow (depth limited)"
         else
           log "Repository has full history"
         fi
         
         # Create a simple status file
         echo "Workspace stopped at $(date)" > workspace-status.txt
         log "Created workspace status file"
         
         # Commit and push if there are changes
         if [[ -n "$(git status --porcelain)" ]]; then
           log "Found uncommitted changes, creating commit..."
           git add .
           git commit -m "Auto-save on workspace stop - $(date)" 2>&1 | tee -a "$LOG_FILE" || log "Commit failed"
           
           # Use direct external-auth access (no caching needed)
           log "Attempting to get GitHub token directly..."
           if GITHUB_TOKEN=$(coder external-auth access-token GH 2>/dev/null); then
             log "Successfully obtained GitHub token for authentication"
             
             # Get current remote URL
             CURRENT_URL=$(git remote get-url origin)
             log "Current remote URL: $CURRENT_URL"
             
             # Check current branch and switch to main if needed
             CURRENT_BRANCH=$(git branch --show-current 2>/dev/null || echo 'unknown')
             log "Current branch: $CURRENT_BRANCH"
             
             if [[ "$CURRENT_BRANCH" != "main" && "$CURRENT_BRANCH" != "master" ]]; then
               log "Not on main/master branch, checking if main branch exists..."
               if git show-ref --verify --quiet refs/heads/main; then
                 log "Switching to main branch"
                 git checkout main 2>&1 | tee -a "$LOG_FILE" || log "Failed to checkout main"
               elif git show-ref --verify --quiet refs/heads/master; then
                 log "Switching to master branch"
                 git checkout master 2>&1 | tee -a "$LOG_FILE" || log "Failed to checkout master"
               else
                 log "Creating and switching to main branch"
                 git checkout -b main 2>&1 | tee -a "$LOG_FILE" || log "Failed to create main branch"
               fi
               
               # Re-add and commit changes on the correct branch
               git add .
               git commit -m "Auto-save on workspace stop - $(date)" 2>&1 | tee -a "$LOG_FILE" || log "Re-commit failed"
             fi
             
             # Ensure we're tracking the remote main branch
             REMOTE_MAIN_EXISTS=$(git ls-remote --heads origin main 2>/dev/null | wc -l)
             REMOTE_MASTER_EXISTS=$(git ls-remote --heads origin master 2>/dev/null | wc -l)
             
             if [[ "$REMOTE_MAIN_EXISTS" -gt 0 ]]; then
               TARGET_BRANCH="main"
             elif [[ "$REMOTE_MASTER_EXISTS" -gt 0 ]]; then
               TARGET_BRANCH="master"
             else
               TARGET_BRANCH="main"  # Default to main for new repos
             fi
             
             log "Target remote branch: $TARGET_BRANCH"
             
             # Set upstream tracking if not already set
             if ! git rev-parse --abbrev-ref --symbolic-full-name @{u} >/dev/null 2>&1; then
               log "Setting upstream tracking to origin/$TARGET_BRANCH"
               git branch --set-upstream-to=origin/$TARGET_BRANCH 2>&1 | tee -a "$LOG_FILE" || log "Failed to set upstream"
             fi
             
             # If it's an HTTPS URL, modify it to include the token
             if [[ "$CURRENT_URL" =~ ^https://github.com/ ]]; then
               # Extract the repo path (everything after github.com/)
               REPO_PATH=$(echo "$CURRENT_URL" | sed 's|https://github.com/||')
               # Create authenticated URL
               AUTH_URL="https://token:$GITHUB_TOKEN@github.com/$REPO_PATH"
               
               # Temporarily set the remote URL with token
               git remote set-url origin "$AUTH_URL"
               log "Updated remote URL with authentication token"
               
               # Attempt to push with auto-merge
               log "Attempting to push to $TARGET_BRANCH with auto-merge..."
               if git push origin HEAD:$TARGET_BRANCH 2>&1 | tee -a "$LOG_FILE"; then
                 log "✓ Git push successful!"
                 
                 # Verify push results
                 log "Post-push verification:"
                 log "Current branch after push: $(git branch --show-current 2>/dev/null)"
                 log "Last commit after push: $(git log -1 --oneline 2>/dev/null)"
                 log "Remote tracking branch: $(git rev-parse --abbrev-ref --symbolic-full-name @{u} 2>/dev/null || echo 'no upstream')"
               else
                 log "✗ Git push failed, attempting force push..."
                 if git push --force-with-lease origin HEAD:$TARGET_BRANCH 2>&1 | tee -a "$LOG_FILE"; then
                   log "✓ Force push successful!"
                 else
                   log "✗ Force push also failed"
                 fi
               fi
               
               # Restore original URL (remove token for security)
               git remote set-url origin "$CURRENT_URL"
               log "Restored original remote URL"
             else
               log "Remote URL is not HTTPS GitHub URL, attempting push without token modification"
               git push origin HEAD:$TARGET_BRANCH 2>&1 | tee -a "$LOG_FILE" || log "Push failed without authentication"
             fi
           else
             log "✗ Failed to get GitHub token directly"
             log "This may indicate that GitHub external auth is not configured or the agent cannot access it"
             log "Attempting push without authentication..."
             git push 2>&1 | tee -a "$LOG_FILE" || log "Push failed without authentication"
           fi
         else
           log "No uncommitted changes found"
         fi
       else
         log "Directory exists but is not a Git repository"
       fi
       
       cd "$WORK_DIR"
     else
       log "Git repository not found at: $GIT_REPO_PATH"
     fi
   else
     log "Git base directory not found: $GIT_BASE_DIR"
   fi
   
   # Example 5: Save workspace metadata
   cat > /tmp/workspace-metadata.json << EOF
{
  "workspace_name": "${data.coder_workspace.me.name}",
  "workspace_owner": "${data.coder_workspace_owner.me.name}",
  "workspace_id": "${data.coder_workspace.me.id}",
  "stopped_at": "$(date -Iseconds)",
  "hostname": "$(hostname)"
}
EOF
   log "Saved workspace metadata to /tmp/workspace-metadata.json"
   
   # Example 6: Cleanup temporary files
   log "Cleaning up temporary files..."
   find /tmp -name "*.tmp" -type f -delete 2>/dev/null || true
   
   log "=== On-stop demo script completed successfully ==="
   log "Check $LOG_FILE for full execution details"
  EOT
}


resource "coder_script" "startup_auth" {
  agent_id     = coder_agent.main.id
  display_name = "Startup Token Caching"
  run_on_start = true
  
  script = <<-EOT
    #!/bin/bash
    # When debugging this could be detrimental and set -x might help troubleshooting
    set -euo pipefail
    
    # Configuration
    LOG_FILE="/home/coder/startup.log"
    
    # Logging function
    log() {
      echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
    }
    
    # Initialize
    log "=== Starting workspace setup ==="
    
    # Create workspace directories
    mkdir -p "/home/coder/src/server"
    log "Created workspace directories"
    
    # Basic git configuration
    if ! git config --global user.name >/dev/null 2>&1; then
        git config --global user.name "$${CODER_WORKSPACE_OWNER:-coder-user}"
        log "Set Git user name"
    fi
    
    if ! git config --global user.email >/dev/null 2>&1; then
        git config --global user.email "$${CODER_WORKSPACE_OWNER:-coder-user}@coder.local"
        log "Set Git user email"
    fi
    
    log "=== Workspace setup completed ==="
  EOT
}