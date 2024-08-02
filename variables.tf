variable "prefix" {
  description = "prefix for resources created"
  default     = "ob1"
}

variable "username" {
  description = "prefix for resources created"
  default     = "admin"
}

variable "ssh_key_name" {
  description = "prefix for resources created"
  default     = "OB1-key-sews"
}

variable "f5_ami_search_name" {
  description = "search term to find the appropriate F5 AMI for current region"
  default = "F5*BIGIP-15.1.10.4-0.0.5*PAYG-Best*Plus*25Mbps*"
  }

variable "libs_dir" {
  description = "Destination directory on the BIG-IP to download the A&O Toolchain RPMs"
  type        = string
  default     = "/config/cloud/aws/node_modules"
  }

variable onboard_log {
  description = "Directory on the BIG-IP to store the cloud-init logs"
  type        = string
  default     = "/var/log/startup-script.log"
  }