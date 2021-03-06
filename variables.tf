variable "prefix"      { default = "eks" }
variable "stage"       { default = "poc"}

variable "vpc_cidr" { default = "10.4.0.0/16" }

variable "clname" {
  type        = "string"
  description = "Cluster name"
  default     = "eks1"
}

/* AWS */
variable "ami" {
  # EU-CENTRAL-1 => CentOS 7
  default        = "ami-077c0308fba3bc548"
}

/* ZONE NAMES */
variable "zone_number" { default = 3 }
variable "az" {
  default = ["eu-central-1a", "eu-central-1b", "eu-central-1c"]
}

variable "region"      { default = "eu-central-1" }

variable "sshkey_path"    {}
variable "aws_access_key" {}
variable "aws_secret_key" {}
variable "route53zone"    {}

variable "host-size"   { default = "t3.medium" }

variable "hostcount"   { default = 2 }
variable "hostmax"     { default = 6 }
variable "hostmin"     { default = 1 }

variable "sshkey_name" { default = "aws_gen" }
