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

data "coder_workspace" "me" {}

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
    namespace = "coder-workspaces"
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
          cpu    = "2"
          memory = "4Gi"
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
