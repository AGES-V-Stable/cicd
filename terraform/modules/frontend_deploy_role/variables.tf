variable "name" {
  type = string
}

variable "github_oidc_subject" {
  description = "Exact GitHub OIDC subject for this repository and environment."
  type        = string
}

variable "github_ref_pattern" {
  description = "Allowed Git ref in GitHub OIDC tokens."
  type        = string
}

variable "bucket_arn" {
  type = string
}

variable "distribution_arn" {
  type = string
}
