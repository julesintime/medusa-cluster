terraform {
  required_providers {
    coder = {
      source  = "coder/coder"
      version = "~> 2.0"
    }
    kubernetes = {
      source = "hashicorp/kubernetes"
    }
    envbuilder = {
      source = "coder/envbuilder"
    }
  }
}

provider "coder" {}
provider "kubernetes" {
  config_path = var.use_kubeconfig == true ? "~/.kube/config" : null
}
provider "envbuilder" {}

data "coder_provisioner" "me" {}
data "coder_workspace" "me" {}
data "coder_workspace_owner" "me" {}

variable "use_kubeconfig" {
  type        = bool
  description = "Use host kubeconfig? (true/false)"
  default     = false
}

variable "namespace" {
  type        = string
  default     = "coder"
  description = "The Kubernetes namespace to create workspaces in"
}

variable "cache_repo" {
  default     = ""
  description = "Use a container registry as a cache to speed up builds."
  type        = string
}

variable "insecure_cache_repo" {
  default     = false
  description = "Enable this option if your cache registry does not serve HTTPS."
  type        = bool
}

data "coder_parameter" "cpu" {
  type         = "number"
  name         = "cpu"
  display_name = "CPU"
  description  = "CPU limit (cores)."
  default      = "2"
  icon         = "/emojis/1f5a5.png"
  mutable      = true
  validation {
    min = 1
    max = 99999
  }
  order = 1
}

data "coder_parameter" "memory" {
  type         = "number"
  name         = "memory"
  display_name = "Memory"
  description  = "Memory limit (GiB)."
  default      = "2"
  icon         = "/icon/memory.svg"
  mutable      = true
  validation {
    min = 1
    max = 99999
  }
  order = 2
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
  order = 3
}

data "coder_parameter" "repo" {
  description  = "Select a repository to automatically clone and start working with a devcontainer."
  display_name = "Repository (auto)"
  mutable      = true
  name         = "repo"
  order        = 4
  type         = "string"
}

data "coder_parameter" "fallback_image" {
  default      = "codercom/enterprise-base:ubuntu"
  description  = "This image runs if the devcontainer fails to build."
  display_name = "Fallback Image"
  mutable      = true
  name         = "fallback_image"
  order        = 6
}

data "coder_parameter" "devcontainer_builder" {
  description  = "Image that will build the devcontainer."
  display_name = "Devcontainer Builder"
  mutable      = true
  name         = "devcontainer_builder"
  default      = "ghcr.io/coder/envbuilder:latest"
  order        = 7
}

# External authentication for private GitHub repositories
data "coder_external_auth" "github" {
  id       = "github"
  optional = true
}

variable "cache_repo_secret_name" {
  default     = ""
  description = "Path to a docker config.json containing credentials to the provided cache repo, if required."
  sensitive   = true
  type        = string
}

data "kubernetes_secret" "cache_repo_dockerconfig_secret" {
  count = var.cache_repo_secret_name == "" ? 0 : 1
  metadata {
    name      = var.cache_repo_secret_name
    namespace = var.namespace
  }
}

locals {
  deployment_name            = "coder-${lower(data.coder_workspace.me.id)}"
  devcontainer_builder_image = data.coder_parameter.devcontainer_builder.value
  git_author_name            = coalesce(data.coder_workspace_owner.me.full_name, data.coder_workspace_owner.me.name)
  git_author_email           = data.coder_workspace_owner.me.email
  repo_url                   = data.coder_parameter.repo.value
  has_repo                   = local.repo_url != ""
  # The envbuilder provider requires a key-value map of environment variables.
  envbuilder_env = {
    "CODER_AGENT_TOKEN" : coder_agent.main.token,
    "CODER_AGENT_URL" : replace(data.coder_workspace.me.access_url, "/localhost|127\\.0\\.0\\.1/", "host.docker.internal"),
    "ENVBUILDER_GIT_URL" : var.cache_repo == "" ? local.repo_url : "",
    "ENVBUILDER_INIT_SCRIPT" : replace(coder_agent.main.init_script, "/localhost|127\\.0\\.0\\.1/", "host.docker.internal"),
    "ENVBUILDER_FALLBACK_IMAGE" : data.coder_parameter.fallback_image.value,
    "ENVBUILDER_DOCKER_CONFIG_BASE64" : base64encode(try(data.kubernetes_secret.cache_repo_dockerconfig_secret[0].data[".dockerconfigjson"], "")),
    "ENVBUILDER_PUSH_IMAGE" : var.cache_repo == "" ? "" : "true",
    # GitHub authentication for private repositories - DIRECTLY SET as per official Coder template
    "ENVBUILDER_GIT_USERNAME" : data.coder_external_auth.github.access_token,
  }
}

resource "envbuilder_cached_image" "cached" {
  count         = var.cache_repo == "" || !local.has_repo ? 0 : data.coder_workspace.me.start_count
  builder_image = local.devcontainer_builder_image
  git_url       = local.repo_url
  cache_repo    = var.cache_repo
  extra_env     = local.envbuilder_env
  insecure      = var.insecure_cache_repo
}

resource "kubernetes_persistent_volume_claim" "workspaces" {
  metadata {
    name      = "coder-${lower(data.coder_workspace.me.id)}-workspaces"
    namespace = var.namespace
    labels = {
      "app.kubernetes.io/name"     = "coder-${lower(data.coder_workspace.me.id)}-workspaces"
      "app.kubernetes.io/instance" = "coder-${lower(data.coder_workspace.me.id)}-workspaces"
      "app.kubernetes.io/part-of"  = "coder"
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
        storage = "${data.coder_parameter.workspaces_volume_size.value}Gi"
      }
    }
  }
}

resource "kubernetes_deployment" "main" {
  count = data.coder_workspace.me.start_count
  depends_on = [
    kubernetes_persistent_volume_claim.workspaces
  ]
  wait_for_rollout = false
  metadata {
    name      = local.deployment_name
    namespace = var.namespace
    labels = {
      "app.kubernetes.io/name"     = "coder-workspace"
      "app.kubernetes.io/instance" = local.deployment_name
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
        "app.kubernetes.io/name" = "coder-workspace"
      }
    }
    strategy {
      type = "Recreate"
    }

    template {
      metadata {
        labels = {
          "app.kubernetes.io/name" = "coder-workspace"
        }
      }
      spec {
        security_context {}

        container {
          name              = "dev"
          image             = var.cache_repo == "" ? local.devcontainer_builder_image : envbuilder_cached_image.cached.0.image
          image_pull_policy = "Always"
          security_context {}

          dynamic "env" {
            for_each = nonsensitive(var.cache_repo == "" ? local.envbuilder_env : envbuilder_cached_image.cached.0.env_map)
            content {
              name  = env.key
              value = env.value
            }
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
            mount_path = "/workspaces"
            name       = "workspaces"
            read_only  = false
          }
        }

        volume {
          name = "workspaces"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim.workspaces.metadata.0.name
            read_only  = false
          }
        }

        affinity {
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

resource "coder_agent" "main" {
  arch           = data.coder_provisioner.me.arch
  os             = "linux"
  startup_script = <<-EOT
    set -e
  EOT
  dir            = "/workspaces"

  env = {
    GIT_AUTHOR_NAME     = local.git_author_name
    GIT_AUTHOR_EMAIL    = local.git_author_email
    GIT_COMMITTER_NAME  = local.git_author_name
    GIT_COMMITTER_EMAIL = local.git_author_email
  }

  metadata {
    display_name = "GitHub Authentication"
    key          = "8_github_auth"
    value        = data.coder_external_auth.github.access_token != "" ? "✅ Authenticated" : "❌ Not configured"
  }
}

# Module removed to avoid validation issues - code-server can be installed via startup script

resource "coder_metadata" "container_info" {
  count       = data.coder_workspace.me.start_count
  resource_id = coder_agent.main.id
  item {
    key   = "workspace image"
    value = var.cache_repo == "" ? local.devcontainer_builder_image : envbuilder_cached_image.cached.0.image
  }
  item {
    key   = "git url"
    value = local.repo_url
  }
  item {
    key   = "cache repo"
    value = var.cache_repo == "" ? "not enabled" : var.cache_repo
  }
}