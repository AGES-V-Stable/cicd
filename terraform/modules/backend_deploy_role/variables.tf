variable "name" {
  type = string
}

variable "github_oidc_subject" {
  description = "Exact GitHub OIDC subject for the backend repository and environment."
  type        = string
}

variable "github_ref_pattern" {
  description = "Allowed Git ref in GitHub OIDC tokens."
  type        = string
}

variable "ecr_repository_arn" {
  type = string
}

variable "lambda_function_arns" {
  description = "Lambda functions that the backend workflow can update and invoke."
  type        = list(string)
}
