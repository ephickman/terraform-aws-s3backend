variable "namespace" {
	description = "The name of the installation, so that we can generate unique names for the resources."
	type        = string
}

variable "principal_arns" {
	description = "A list of principal ARNs (i.e. principal identifiers) allowed to assume the IAM role for this backend."
	type        = list(string)
	default     = null
}

variable "force_destroy_state" {
	description = "WTF? Force destroy the S3 Bucket containing the state files? (Note: I don't know why we would want that, and the default is TRUE!!)"
	type        = bool
	default     = true
}