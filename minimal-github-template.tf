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

# External authentication for private GitHub repositories
data "coder_external_auth" "github" {
  id       = "github"
  optional = true
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
  default     = "coder"
  description = "The Kubernetes namespace to create workspaces in (must exist prior to creating workspaces). If the Coder host is itself running as a Pod on the same Kubernetes cluster as you are deploying workspaces to, set this to the same namespace."
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
  name         = "cpu"
  display_name = "CPU"
  description  = "The number of CPU cores"
  default      = "2"
  icon         = "/icon/memory.svg"
  mutable      = true
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
  default      = "2"
  icon         = "/icon/memory.svg"
  mutable      = true
  option {
    name  = "2 GB"
    value = "2"
  }
  option {
    name  = "4 GB"
    value = "4"
  }
  option {
    name  = "6 GB"
    value = "6"
  }
  option {
    name  = "8 GB"
    value = "8"
  }
}

data "coder_parameter" "home_disk_size" {
  name         = "home_disk_size"
  display_name = "Home disk size"
  description  = "The size of the home disk in GB"
  default      = "10"
  type         = "number"
  icon         = "/emojis/1f4be.png"
  mutable      = false
  validation {
    min = 1
    max = 99999
  }
}

data "coder_parameter" "fallback_image" {
  name         = "fallback_image"
  display_name = "Fallback Image"
  description  = "This image will be used when a devcontainer cannot be found."
  default      = "codercom/enterprise-base:ubuntu"
  mutable      = true
}

data "coder_parameter" "repo" {
  name         = "repo"
  display_name = "Repository"
  description  = "Select a repository to automatically clone and start working with a devcontainer."
  default      = "https://github.com/coder/coder"
  mutable      = true
}

variable "cache_repo_dockerconfig_secret" {
  description = "An existing Kubernetes secret in the same namespace containing Docker configuration for a cache registry"
  type        = string
  default     = ""
  sensitive   = true
}

data "kubernetes_secret" "cache_repo_dockerconfig_secret" {
  count = var.cache_repo_dockerconfig_secret == "" ? 0 : 1
  metadata {
    name      = var.cache_repo_dockerconfig_secret
    namespace = var.namespace
  }
}

locals {
  repo_url = data.coder_parameter.repo.value
  # The envbuilder provider requires a key-value map of environment variables.
  # Base environment variables for envbuilder
  base_envbuilder_env = {
    "CODER_AGENT_TOKEN" : coder_agent.main.token,
    # Use the docker gateway if the access URL is 127.0.0.1
    "CODER_AGENT_URL" : replace(data.coder_workspace.me.access_url, "/localhost|127\\.0\\.0\\.1/", "host.docker.internal"),
    # ENVBUILDER_GIT_URL and ENVBUILDER_CACHE_REPO will be overridden by the provider
    # if the cache repo is enabled.
    "ENVBUILDER_GIT_URL" : var.cache_repo == "" ? local.repo_url : "",
    # Use the docker gateway if the access URL is 127.0.0.1
    "ENVBUILDER_INIT_SCRIPT" : replace(coder_agent.main.init_script, "/localhost|127\\.0\\.0\\.1/", "host.docker.internal"),
    "ENVBUILDER_FALLBACK_IMAGE" : data.coder_parameter.fallback_image.value,
    "ENVBUILDER_DOCKER_CONFIG_BASE64" : base64encode(try(data.kubernetes_secret.cache_repo_dockerconfig_secret[0].data[".dockerconfigjson"], "")),
    "ENVBUILDER_PUSH_IMAGE" : var.cache_repo == "" ? "" : "true"
    # You may need to adjust this if you get an error regarding deleting files when building the workspace.
    # For example, when testing in KinD, it was necessary to set `/product_name` and `/product_uuid` in
    # addition to `/var/run`.
    # "ENVBUILDER_IGNORE_PATHS": "/product_name,/product_uuid,/var/run",
  }
  
  # Add GitHub authentication if available
  github_env = data.coder_external_auth.github.access_token != "" ? {
    "ENVBUILDER_GIT_USERNAME" : data.coder_external_auth.github.access_token
  } : {}
  
  # Merge base environment with GitHub auth
  envbuilder_env = merge(local.base_envbuilder_env, local.github_env)
}

locals {
  devcontainer_builder_image = "codercom/envbuilder"
}

resource "envbuilder_cached_image" "cached" {
  count = var.cache_repo == "" ? 0 : 1
  # Use the EnvBuilder variable to populate the git URL.
  git_url      = local.repo_url
  builder_repo = var.cache_repo
  insecure     = var.insecure_cache_repo
  env_map      = local.envbuilder_env
}

resource "coder_agent" "main" {
  arch                   = data.coder_provisioner.me.arch
  os                     = "linux"
  startup_script_timeout = 180
  startup_script         = <<-EOT
    set -e

    # Add any commands that should be executed at workspace startup (e.g install requirements, start a program, etc) here
  EOT

  # These environment variables allow you to make Git commits right away after creating a
  # workspace. Note that they take precedence over configuration defined in ~/.gitconfig!
  # You can remove this block if you'd prefer to configure Git manually or using
  # dotfiles. (see docs/dotfiles.md)
  env = {
    GIT_AUTHOR_NAME     = "${data.coder_workspace_owner.me.name}"
    GIT_COMMITTER_NAME  = "${data.coder_workspace_owner.me.name}"
    GIT_AUTHOR_EMAIL    = "${data.coder_workspace_owner.me.email}"
    GIT_COMMITTER_EMAIL = "${data.coder_workspace_owner.me.email}"
  }

  # The following metadata blocks are optional. They are used to display
  # information about your workspace in the dashboard. You can remove them
  # if you don't want to display any information.
  # For basic templates, you can use the `coder stat` command to get a display
  # of the current resources in your workspace.
  # If you'd like to give your users more information about how to connect to
  # the workspace, you can use the `coder port-forward` command on a resource
  # that you've defined.

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
    # get load avg
    script   = "uptime | awk -F'load average:' '{ print $2 }'"
    interval = 60
    timeout  = 1
  }
}

resource "coder_metadata" "workspace_info" {
  count       = data.coder_workspace.me.start_count
  resource_id = coder_agent.main.id

  item {
    key   = "repo cloned"
    value = data.coder_parameter.repo.value
  }
  item {
    key   = "CPU"
    value = "${data.coder_parameter.cpu.value} cores"
  }
  item {
    key   = "memory"
    value = "${data.coder_parameter.memory.value}GB"
  }
  item {
    key   = "image"
    value = "envbuilder"
  }
  item {
    key   = "disk"
    value = "${data.coder_parameter.home_disk_size.value}GiB"
  }
  item {
    key   = "volume"
    value = kubernetes_persistent_volume_claim.workspaces.metadata[0].name
  }
  item {
    key   = "GitHub"
    value = data.coder_external_auth.github.access_token != "" ? "✅ Authenticated" : "❌ Not configured"
  }
}

resource "coder_metadata" "container_info" {
  count       = data.coder_workspace.me.start_count
  resource_id = coder_agent.main.id
  item {
    key   = "workspace image"
    value = var.cache_repo == "" ? local.devcontainer_builder_image : envbuilder_cached_image.cached.0.image
  }
  item {
    key   = "cache repo"
    value = var.cache_repo == "" ? "disabled" : var.cache_repo
  }
}

resource "kubernetes_persistent_volume_claim" "workspaces" {
  metadata {
    name      = "coder-${data.coder_workspace_owner.me.name}-${data.coder_workspace.me.name}"
    namespace = var.namespace
    labels = {
      "app.kubernetes.io/name"     = "coder-workspace"
      "app.kubernetes.io/instance" = "coder-workspace-${data.coder_workspace_owner.me.name}-${data.coder_workspace.me.name}"
      "app.kubernetes.io/part-of"  = "coder"
      "coder.owner"                = data.coder_workspace_owner.me.name
      "coder.owner_id"             = data.coder_workspace_owner.me.id
      "coder.workspace_id"         = data.coder_workspace.me.id
      "coder.workspace_name"       = data.coder_workspace.me.name
    }
    annotations = {
      "coder.owner"                = data.coder_workspace_owner.me.name
      "coder.owner_id"             = data.coder_workspace_owner.me.id
      "coder.workspace_id"         = data.coder_workspace.me.id
      "coder.workspace_name"       = data.coder_workspace.me.name
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
  }
}

resource "kubernetes_deployment" "main" {
  count = data.coder_workspace.me.start_count
  metadata {
    name      = "coder-${data.coder_workspace_owner.me.name}-${data.coder_workspace.me.name}"
    namespace = var.namespace
    labels = {
      "app.kubernetes.io/name"     = "coder-workspace"
      "app.kubernetes.io/instance" = "coder-workspace-${data.coder_workspace_owner.me.name}-${data.coder_workspace.me.name}"
      "app.kubernetes.io/part-of"  = "coder"
      "coder.owner"                = data.coder_workspace_owner.me.name
      "coder.owner_id"             = data.coder_workspace_owner.me.id
      "coder.workspace_id"         = data.coder_workspace.me.id
      "coder.workspace_name"       = data.coder_workspace.me.name
    }
    annotations = {
      "coder.owner"                = data.coder_workspace_owner.me.name
      "coder.owner_id"             = data.coder_workspace_owner.me.id
      "coder.workspace_id"         = data.coder_workspace.me.id
      "coder.workspace_name"       = data.coder_workspace.me.name
    }
  }

  spec {
    replicas = 1
    selector {
      match_labels = {
        "coder.owner"         = data.coder_workspace_owner.me.name
        "coder.workspace_id"  = data.coder_workspace.me.id
      }
    }
    template {
      metadata {
        labels = {
          "coder.owner"         = data.coder_workspace_owner.me.name
          "coder.workspace_id"  = data.coder_workspace.me.id
        }
        annotations = {
          "coder.owner"                = data.coder_workspace_owner.me.name
          "coder.owner_id"             = data.coder_workspace_owner.me.id
          "coder.workspace_id"         = data.coder_workspace.me.id
          "coder.workspace_name"       = data.coder_workspace.me.name
        }
      }
      spec {
        security_context {
          run_as_user = "1000"
          fs_group    = "1000"
        }
        container {
          name  = "dev"
          image = var.cache_repo == "" ? local.devcontainer_builder_image : envbuilder_cached_image.cached.0.image
          env {
            name  = "CODER_AGENT_TOKEN"
            value = coder_agent.main.token
          }
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
          security_context {
            run_as_user = "1000"
          }
        }
        volume {
          name = "workspaces"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim.workspaces.metadata[0].name
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