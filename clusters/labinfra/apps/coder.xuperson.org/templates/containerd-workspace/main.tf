terraform {
  required_providers {
    coder = {
      source  = "coder/coder"
      version = "~> 0.12"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.16"
    }
  }
}

variable "namespace" {
  type        = string
  default     = "coder-workspaces"
  description = "The Kubernetes namespace to create workspaces in"
}

data "coder_workspace" "me" {}
data "coder_workspace_owner" "me" {}

data "coder_parameter" "cpu" {
  name         = "cpu"
  display_name = "CPU Cores"
  description  = "Number of CPU cores for the workspace"
  type         = "number"
  default      = 2
  icon         = "/emojis/1f5a5.png"
  mutable      = true
  validation {
    min = 1
    max = 8
  }
}

data "coder_parameter" "memory" {
  name         = "memory"
  display_name = "Memory (GB)"
  description  = "Amount of memory for the workspace"
  type         = "number"
  default      = 4
  icon         = "/icon/memory.svg"
  mutable      = true
  validation {
    min = 1
    max = 16
  }
}

resource "coder_agent" "main" {
  os   = "linux"
  arch = "amd64"
  startup_script = <<EOF
#!/bin/sh
# Docker is already mounted via hostPath, just wait for it
while ! docker info >/dev/null 2>&1; do
  echo "Waiting for Docker..."
  sleep 1
done
echo "Docker ready!"
EOF
}

resource "kubernetes_pod" "main" {
  count = data.coder_workspace.me.start_count
  metadata {
    name      = "coder-${data.coder_workspace.me.id}-${data.coder_workspace.me.name}"
    namespace = var.namespace
    labels = {
      "app.kubernetes.io/name"     = "coder-workspace"
      "app.kubernetes.io/instance" = "coder-${data.coder_workspace.me.id}"
      "app.kubernetes.io/part-of"  = "coder"
      "com.coder.resource"         = "true"
      "com.coder.workspace.id"     = data.coder_workspace.me.id
      "com.coder.workspace.name"   = data.coder_workspace.me.name
      "com.coder.user.id"          = data.coder_workspace_owner.me.id
      "com.coder.user.username"    = data.coder_workspace_owner.me.name
    }
  }

  spec {
    container {
      name  = "dev"
      image = "codercom/enterprise-base:ubuntu"
      command = ["sh", "-c", coder_agent.main.init_script]

      env {
        name  = "CODER_AGENT_TOKEN"
        value = coder_agent.main.token
      }

      env {
        name  = "DOCKER_HOST"
        value = "unix:///var/run/docker.sock"
      }

      security_context {
        run_as_user = 0
        capabilities {
          add = ["SYS_ADMIN"]
        }
      }

      resources {
        requests = {
          cpu    = "500m"
          memory = "1Gi"
        }
        limits = {
          cpu    = "${data.coder_parameter.cpu.value}"
          memory = "${data.coder_parameter.memory.value}Gi"
        }
      }

      # Mount the Docker socket from the host
      volume_mount {
        name       = "docker-socket"
        mount_path = "/var/run/docker.sock"
      }

      volume_mount {
        name       = "home"
        mount_path = "/home/coder"
      }
    }

    # Host path volume for Docker socket access
    volume {
      name = "docker-socket"
      host_path {
        path = "/var/run/docker.sock"
        type = "Socket"
      }
    }

    volume {
      name = "home"
      empty_dir {}
    }
  }
}

resource "coder_metadata" "workspace_info" {
  count       = data.coder_workspace.me.start_count
  resource_id = coder_agent.main.id
  item {
    key   = "CPU"
    value = "${data.coder_parameter.cpu.value} cores"
  }
  item {
    key   = "Memory"
    value = "${data.coder_parameter.memory.value}GB"
  }
  item {
    key   = "Docker"
    value = "Available"
  }
}