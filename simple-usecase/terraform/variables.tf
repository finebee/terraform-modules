variable "teammate_model" {
  description = "llm model for teammate"
  type        = string
  default     = "azure/gpt-4o"
}


variable "teammate_description" {
  description = "Name of the virtual entity that binds the JIT permissions logic"
  type        = string
  default     = "AI-powered AWS JIT permissions guardian. [updated]"
}

variable "teammate_instructions" {
  description = "Name of the virtual entity that binds the JIT permissions logic"
  type        = string
  default     = "this is ai instructions. [updated]"
}

variable "kubiya_runner" {
  description = "Runner (cluster) to use for the teammate"
  type        = string
}

variable "kubiya_groups_allowed_groups" {
  description = "Kubiya groups who can request access through the teammate"
  type        = list(string)
  default     = ["Admin"]
}

variable "kubiya_integrations" {
  description = "List of Kubiya integrations to enable. Supports multiple values. \n For AWS integration, the main account must be provided."
  type        = list(string)
  default     = ["slack"]
}

variable "debug_mode" {
  description = "Debug mode allows you to see more detailed information and outputs during runtime"
  type        = bool
  default     = false
}
