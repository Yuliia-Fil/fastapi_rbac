variable "region" {
  description = "AWS region for the deployment."
  type        = string
  default     = "us-east-1"
}

variable "name" {
  description = "Deployment name used for resource tags and the instance role."
  type        = string
  default     = "ghost-blog"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{0,30}[a-z0-9]$", var.name))
    error_message = "Use 2–32 lower-case letters, digits, or hyphens for the deployment name."
  }
}

variable "domain" {
  description = "Fully qualified public blog hostname, without a scheme or trailing dot."
  type        = string

  validation {
    condition = length(var.domain) <= 253 && can(regex(
      "^([a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?\\.)+[a-z][a-z0-9-]{0,61}[a-z0-9]$",
      var.domain
    ))
    error_message = "Use a lower-case public DNS hostname such as blog.example.com."
  }
}

variable "hosted_zone_id" {
  description = "ID of the existing public Route 53 hosted zone for the hostname."
  type        = string

  validation {
    condition     = can(regex("^Z[A-Z0-9]+$", var.hosted_zone_id))
    error_message = "Use a Route 53 zone ID starting with Z."
  }
}
