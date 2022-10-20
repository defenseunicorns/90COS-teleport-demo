variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "us-east-1"
}

variable "account_id" {
  description = "Account ID for resource creation"
  type        = string
  default     = ""
}

variable "eks_node_group_role" {
  description = "Node group role name for policy association"
  type        = string
  default     = ""
}