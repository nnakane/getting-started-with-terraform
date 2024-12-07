variable "environment" {
  default = "yyy"
}

variable "container_ports" {
  default = {
    internal = 80
    external = 8001
  }
}