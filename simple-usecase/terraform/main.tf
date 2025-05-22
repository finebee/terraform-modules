terraform {
  required_providers {
    kubiya = {
      source = "kubiya-terraform/kubiya"
    }
  }
}

provider "kubiya" {
  // API key is set as an environment variable KUBIYA_API_KEY
}

# Configure the JIT Guardian agent
resource "kubiya_agent" "jit_guardian" {
  name          = var.teammate_name
  runner        = var.kubiya_runner
  description   = var.teammate_description
  model         = var.teammate_model
  instructions  = "this is ai instructions"
  integrations  = var.kubiya_integrations
  users         = []
  groups        = var.kubiya_groups_allowed_groups
  is_debug_mode = var.debug_mode

  lifecycle {
    ignore_changes = [
      environment_variables
    ]
  }
}

# Output the teammate details
output "jit_guardian" {
  value = {
    name                       = kubiya_agent.jit_guardian.name
  }
}

