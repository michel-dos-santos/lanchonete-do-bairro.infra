# precisa começar com TF_VAR_
variable "TF_VAR_AWS_ACCESS_KEY" {
  description = "The access key aws."
  type        = string
  sensitive   = true
}

# precisa começar com TF_VAR_
variable "TF_VAR_AWS_SECRET_KEY" {
  description = "The secret key aws."
  type        = string
  sensitive   = true
}

# precisa começar com TF_VAR_
variable "TF_VAR_POSTGRES_USER" {
  description = "The master username for the database."
  type        = string
  sensitive   = true
}

# precisa começar com TF_VAR_
variable "TF_VAR_POSTGRES_PASSWORD" {
  description = "The master password for the database."
  type        = string
  sensitive   = true
}