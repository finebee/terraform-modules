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

# Load knowledge sources
data "http" "jit_access_knowledge" {
  url = "https://raw.githubusercontent.com/kubiyabot/terraform-modules/refs/heads/main/jit-permissions-guardians/terraform/knowledge/jit_access.md"
}

# Configure sources
resource "kubiya_source" "enforcer_source" {
  url    = "https://github.com/kubiyabot/community-tools/tree/main/just_in_time_access_proactive"
  runner = var.kubiya_runner
  dynamic_config = jsonencode({
    aws_jit_config      = var.config_json
    opa_runner_name     = var.kubiya_runner
    approves_group_name = var.approves_group_name
    dd_site             = var.dd_enabled ? var.dd_site : ""
    dd_api_key          = var.dd_enabled ? var.dd_api_key : ""
    idp_provider        = var.okta_enabled ? "okta" : "kubiya"
    okta_base_url       = var.okta_enabled ? var.okta_base_url : ""
    okta_client_id      = var.okta_enabled ? var.okta_client_id : ""
    okta_private_key    = var.okta_enabled ? var.okta_private_key : ""
    okta_token_endpoint = var.okta_enabled ? "${var.okta_base_url}/oauth2/v1/token" : ""

  })
}

# Configure auxiliary request tools
resource "kubiya_source" "aws_jit_tools" {
  url            = "https://github.com/kubiyabot/community-tools/tree/main/aws_jit_tools"
  dynamic_config = var.config_json
  runner         = var.kubiya_runner
}

# Create knowledge base
resource "kubiya_knowledge" "jit_access" {
  name             = "JIT Access Management Guide"
  groups           = var.kubiya_groups_allowed_groups
  description      = "Knowledge base for JIT access management and troubleshooting"
  labels           = ["aws", "jit", "access-management"]
  supported_agents = [kubiya_agent.jit_guardian.name]
  content          = data.http.jit_access_knowledge.response_body
}

resource "null_resource" "runner_env_setup" {
  triggers = {
    runner     = var.kubiya_runner
    webhook_id = kubiya_webhook.webhook.id
  }

  provisioner "local-exec" {
    command = <<-EOT
      curl -X PUT \
      -H "Authorization: UserKey $KUBIYA_API_KEY" \
      -H "Content-Type: application/json" \
      -d '{
        "uuid": "${kubiya_agent.jit_guardian.id}",
        "environment_variables": {
          "KUBIYA_TOOL_TIMEOUT": "${var.kubiya_tool_timeout}",
          "REQUEST_ACCESS_WEBHOOK_URL": "${kubiya_webhook.webhook.url}"
        }
      }' \
      "https://api.kubiya.ai/api/v1/agents/${kubiya_agent.jit_guardian.id}"
    EOT
  }
  depends_on = [
    kubiya_webhook.webhook
  ]
}

resource "kubiya_webhook" "webhook" {
  // Required fileds
  //mandatory fields
  //Please specify a unique name to identify this webhook
  name = "${var.teammate_name} JIT webhook"
  //Please specify the source of the webhook - e.g: 'pull request opened on repository foo'
  source = "JIT"
  //Provide AI instructions prompt for the agent to follow upon incoming webhook. use {{.event.}} syntax for dynamic parsing of the event
  prompt = "Sum up this just in time access request. Here is all the relevant data (no need to run describe tool).. request_id: {{.event.request_id}}, requested_by: {{ .event.user_email}}, requested to run tool {{.event.tool_name}} with parameters {{.event.tool_params}}. requested for a duration of {{.event.requested_ttl}}"
  //Select an Agent which will perform the task and receive the webhook payload
  agent = kubiya_agent.jit_guardian.name
  //Please provide a destination that starts with `#` or `@`
  destination = var.approvers_slack_channel
  //optional fields
  //Insert a JMESPath expression to filter by, for more information reach out to https://jmespath.org
  filter = ""

}

# Configure the JIT Guardian agent
resource "kubiya_agent" "jit_guardian" {
  name          = var.teammate_name
  runner        = var.kubiya_runner
  description   = "AI-powered AWS JIT permissions guardian"
  model         = "azure/gpt-4o"
  instructions  = ""
  sources       = [kubiya_source.enforcer_source.name, kubiya_source.aws_jit_tools.name]
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
    approvers_slack_channel    = var.approvers_slack_channel
    request_access_webhook_url = kubiya_webhook.webhook.url
  }
}

