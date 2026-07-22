variable "aws_region" {
  description = "AWS region in which to create the proof-of-concept deployment."
  type        = string
  default     = "us-west-2"
}

variable "project_name" {
  description = "Name used for AWS resources, tags, and the account budget."
  type        = string
  default     = "openmetadata-poc"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{2,31}$", var.project_name))
    error_message = "project_name must be 3-32 lowercase letters, digits, or hyphens and start with a letter."
  }
}

variable "allowed_cidrs" {
  description = "IPv4 CIDRs allowed to reach the HTTP ALB. Use your public IP with /32 for this short-lived test."
  type        = list(string)

  validation {
    condition = (
      length(var.allowed_cidrs) > 0 &&
      alltrue([for cidr in var.allowed_cidrs : can(cidrnetmask(cidr))]) &&
      alltrue([for cidr in var.allowed_cidrs : cidr != "0.0.0.0/0"])
    )
    error_message = "allowed_cidrs must contain valid IPv4 CIDRs and cannot include 0.0.0.0/0; normally use your public IP as a /32."
  }
}

variable "vpc_cidr" {
  description = "CIDR for the dedicated proof-of-concept VPC."
  type        = string
  default     = "10.42.0.0/16"

  validation {
    condition     = can(cidrnetmask(var.vpc_cidr))
    error_message = "vpc_cidr must be a valid IPv4 CIDR."
  }
}

variable "public_subnet_cidrs" {
  description = "Two public subnet CIDRs used by the ALB; the EC2 instance runs in the first subnet."
  type        = list(string)
  default     = ["10.42.0.0/24", "10.42.1.0/24"]

  validation {
    condition = (
      length(var.public_subnet_cidrs) == 2 &&
      alltrue([for cidr in var.public_subnet_cidrs : can(cidrnetmask(cidr))]) &&
      var.public_subnet_cidrs[0] != var.public_subnet_cidrs[1]
    )
    error_message = "public_subnet_cidrs must contain two distinct valid IPv4 CIDRs."
  }
}

variable "instance_type" {
  description = "EC2 instance type. t3a.xlarge supplies 4 vCPUs and 16 GiB for the lightweight single-host stack."
  type        = string
  default     = "t3a.xlarge"
}

variable "root_volume_size_gib" {
  description = "Encrypted gp3 root volume size in GiB."
  type        = number
  default     = 20

  validation {
    condition     = var.root_volume_size_gib >= 20
    error_message = "root_volume_size_gib must be at least 20 GiB."
  }
}

variable "data_volume_size_gib" {
  description = "Encrypted gp3 volume size in GiB for Docker data, PostgreSQL, and Elasticsearch."
  type        = number
  default     = 100

  validation {
    condition     = var.data_volume_size_gib >= 100
    error_message = "data_volume_size_gib must be at least 100 GiB for the documented OpenMetadata proof-of-concept baseline."
  }
}

variable "openmetadata_version" {
  description = "Pinned OpenMetadata v1.12 maintenance release."
  type        = string
  default     = "1.12.8"

  validation {
    condition     = can(regex("^1\\.12\\.[0-9]+$", var.openmetadata_version))
    error_message = "openmetadata_version must remain on the requested 1.12.x release line."
  }
}

variable "monthly_budget_usd" {
  description = "Monthly account-level AWS cost budget in USD."
  type        = number
  default     = 300

  validation {
    condition     = var.monthly_budget_usd > 0
    error_message = "monthly_budget_usd must be greater than zero."
  }
}

variable "budget_alert_email" {
  description = "Optional email for AWS Budget actual and forecast alerts. AWS sends a confirmation email."
  type        = string
  default     = null
  nullable    = true

  validation {
    condition     = var.budget_alert_email == null || can(regex("^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$", var.budget_alert_email))
    error_message = "budget_alert_email must be null or a valid email address."
  }
}

