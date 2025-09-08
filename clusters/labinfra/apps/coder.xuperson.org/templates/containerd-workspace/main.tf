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
# Wait for Docker daemon in sidecar to be ready
while ! docker info >/dev/null 2>&1; do
  echo "Waiting for Docker daemon to be ready..."
  sleep 2
done
echo "Docker ready!"

# Install additional development tools
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh || echo "Docker client already installed"
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
    # Docker-in-Docker sidecar container
    container {
      name  = "docker-sidecar"
      image = "docker:dind"
      security_context {
        privileged = true
        run_as_user = 0
      }
      command = ["dockerd", "-H", "tcp://0.0.0.0:2375", "--tls=false"]
      env {
        name  = "DOCKER_TLS_CERTDIR"
        value = ""
      }
      resources {
        requests = {
          cpu    = "250m"
          memory = "512Mi"
        }
        limits = {
          cpu    = "1"
          memory = "1Gi"
        }
      }
    }

    # Main development container
    container {
      name  = "dev"
      image = "codercom/enterprise-base:ubuntu"
      command = ["sh", "-c", coder_agent.main.init_script]

      env {
        name  = "CODER_AGENT_TOKEN"
        value = coder_agent.main.token
      }

      # Connect to Docker daemon in sidecar
      env {
        name  = "DOCKER_HOST"
        value = "tcp://localhost:2375"
      }

      security_context {
        run_as_user = 1000
        run_as_group = 1000
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

      volume_mount {
        name       = "home"
        mount_path = "/home/coder"
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