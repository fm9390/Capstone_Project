variable "db_name" {
  description = "Name of the RDS database"
  type        = string
  default     = "discogs"
}

variable "db_user" {
  description = "Username for the RDS database"
  type        = string
}

variable "db_password" {
  description = "Password for the RDS database"
  type        = string
  sensitive   = true
}
