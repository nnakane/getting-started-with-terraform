variable "docker_container_name" {
  default = "container-yyy"
}

variable "container_ports" {
  default = {
    internal = 80
    external = 8001
  }
}