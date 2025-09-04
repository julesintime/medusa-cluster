terraform {
  required_providers {
    coder = {
      source = "coder/coder"
    }
  }
}

data "coder_provisioner" "me" {}

data "coder_workspace" "me" {}

data "coder_parameter" "ai_prompt" {
  type        = "string"
  name        = "AI Prompt"
  display_name = "AI Prompt"
  default     = ""
  description = "Write a prompt for Claude Code and Gemini"
  mutable     = true
}

data "coder_parameter" "workspaces_volume_size" {
  name         = "workspaces_volume_size"
  display_name = "Workspaces volume size"
  description  = "Size of the `/workspaces` volume (GiB)."
  default      = "10"
  type         = "number"
  icon         = "/emojis/1f4be.png"
  mutable      = false
  validation {
    min = 1
    max = 99999
  }
}

resource "coder_agent" "main" {
  arch = data.coder_provisioner.me.arch
  os   = data.coder_provisioner.me.os
  dir  = "/workspaces"

  startup_script = <<-EOT
    #!/bin/sh
    set -e

    # Create workspaces directory if it doesn't exist
    mkdir -p /workspaces

    # Add any commands that should be executed at workspace startup
  EOT

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
    display_name = "Workspaces Disk"
    key          = "3_workspaces_disk"
    script       = "coder stat disk --path /workspaces"
    interval     = 60
    timeout      = 1
  }
}

# Persistent volume for workspaces
resource "coder_app" "workspaces" {
  count        = data.coder_workspace.me.start_count
  agent_id     = coder_agent.main.id
  slug         = "workspaces"
  display_name = "Workspaces"
  url          = "file:///workspaces"
  icon         = "/icon/folder.svg"
  subdomain    = false
  share        = "owner"

  healthcheck {
    url       = "file:///workspaces"
    interval  = 5
    threshold = 6
  }
}

# Use this to set environment variables in your workspace
# details: https://registry.terraform.io/providers/coder/coder/latest/docs/resources/env
resource "coder_env" "welcome_message" {
  agent_id = coder_agent.main.id
  name     = "WELCOME_MESSAGE"
  value    = "Welcome to your Coder workspace!"
}

# Adds code-server
# See all available modules at https://registry.coder.com/modules
module "code-server" {
  count  = data.coder_workspace.me.start_count
  source = "registry.coder.com/coder/code-server/coder"

  # This ensures that the latest non-breaking version of the module gets downloaded, you can also pin the module version to prevent breaking changes in production.
  version = "~> 1.0"

  agent_id = coder_agent.main.id
}

# Adds coder-login for authentication
# See https://registry.coder.com/modules/coder/coder-login
module "coder-login" {
  count    = data.coder_workspace.me.start_count
  source   = "registry.coder.com/coder/coder-login/coder"
  version  = "~> 1.1"
  agent_id = coder_agent.main.id
}

# Adds Claude Code for AI-assisted development
# See https://registry.coder.com/modules/coder/claude-code
module "claude-code" {
  count               = data.coder_workspace.me.start_count
  source              = "registry.coder.com/coder/claude-code/coder"
  version             = "~> 2.0"
  agent_id            = coder_agent.main.id
  folder              = "/workspaces"
  install_claude_code = true
  claude_code_version = "latest"
}

# Adds Node.js via nvm
# See https://registry.coder.com/modules/thezoker/nodejs
module "nodejs" {
  count    = data.coder_workspace.me.start_count
  source   = "registry.coder.com/thezoker/nodejs/coder"
  version  = "~> 1.0"
  agent_id = coder_agent.main.id
  node_versions = [
    "18",
    "20",
    "node"
  ]
  default_node_version = "20"
}

# Adds Gemini CLI for AI-assisted development
# See https://registry.coder.com/modules/coder-labs/gemini
module "gemini" {
  count          = data.coder_workspace.me.start_count
  source         = "registry.coder.com/coder-labs/gemini/coder"
  version        = "~> 2.0"
  agent_id       = coder_agent.main.id
  folder         = "/workspaces"
  task_prompt    = data.coder_parameter.ai_prompt.value
  gemini_model   = "gemini-2.5-flash"
}

# Runs a script at workspace start/stop or on a cron schedule
# details: https://registry.terraform.io/providers/coder/coder/latest/docs/resources/script
resource "coder_script" "startup_script" {
  agent_id           = coder_agent.main.id
  display_name       = "Startup Script"
  script             = <<-EOF
    #!/bin/sh
    set -e
    # Additional startup commands can be added here
  EOF
  run_on_start       = true
  start_blocks_login = true
}
