variable "aws_access_key" {
  type    = string
  default = ""
}

variable "aws_secret_key" {
  type    = string
  default = ""
}

variable "region" {
  type    = string
  default = "eu-north-1"
}

variable "a_zone" {
  type    = string
  default = "eu-north-1a"
}

variable "ami_id" {
  type    = string
  default = "ami-05d62b9bc5a6ca605"
}

variable "instance_type" {
  type    = string
  default = "t3.medium"
}

variable "key_name" {
  type    = string
  default = "Stockholm"
}

variable "my_ip" {
  type        = string
  description = "Your public IP"
  default     = "178.137.96.210/32"
}

variable "jenkins_admin_password" {
  type        = string
  description = "Password for Jenkins admin user"
  default     = "alonaarz"
}
