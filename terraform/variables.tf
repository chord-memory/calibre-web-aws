variable "domain_name" {
  description = "FQDN for Calibre-Web (subdomain)"
  type        = string
}

variable "region" {
  description = "AWS region for deploying resources"
  type        = string
}

variable "profile" {
  description = "AWS SSO profile name for authed user"
  type        = string
}

variable "hosted_zone_id" {
  description = "Route53 hosted zone ID for chord-memory.net"
  type        = string
}

variable "docker_image" {
  description = "Name & tag of calibre-web-automated image from registry"
  type        = string
  default     = "crocodilestick/calibre-web-automated:latest"
}

variable "hardcover_token" {
  description = "Hardcover API Key for metadata provider feature"
  type        = string
  default     = ""
}

variable "setup_path" {
  default     = "../setup"
  type        = string
}

variable "library_bucket_name" {
  default = "cweb-library"
  type    = string
}

variable "ingest_bucket_name" {
  default = "cweb-ingest"
  type    = string
}

variable "setup_bucket_name" {
  default = "cweb-setup"
  type    = string
}

variable "config_volume_size_gb" {
  default = 4
  type    = number
}

variable "ingest_volume_size_gb" {
  default = 4
  type    = number
}

variable "library_volume_size_gb" {
  default = 8
  type    = number
}

variable "admin_email" {
  description = "Used for Caddy logs/emails"
  type        = string
}

variable "admin_user" {
  description = "Calibre-Web UI creds"
  default     = "admin"
  type        = string
}

variable "admin_pass" {
  description = "Calibre-Web UI creds"
  type        = string
}