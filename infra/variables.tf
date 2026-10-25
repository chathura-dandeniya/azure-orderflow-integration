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