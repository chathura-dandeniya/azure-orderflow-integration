variable "project" {
  description = "Short project name used in resource names"
  type        = string
  default     = "orderflow"
}

variable "environment" {
  description = "Environment name (dev, test, prod)"
  type        = string
  default     = "dev"
}

variable "location" {
  description = "Azure region"
  type        = string
  default     = "australiaeast"
}

variable "tags" {
  description = "Tags applied to every resource"
  type        = map(string)
  default = {
    project     = "orderflow"
    environment = "dev"
    managed_by  = "terraform"
    owner       = "chathura Dandeniya"
  }
}

variable "alert_email" {
  description = "Email address that receives operational alerts"
  type        = string
  default     = "chaturadh@gmail.com"
}

variable "deploy_function_subscriptions" {
  description = "Create Event Grid subscriptions that target Functions. Set true only after the Function code is deployed."
  type        = bool
  default     = false
}

variable "admin_object_ids" {
  description = "Entra object IDs that get developer/operator data-plane access (you + the CI service principal)"
  type        = set(string)
}