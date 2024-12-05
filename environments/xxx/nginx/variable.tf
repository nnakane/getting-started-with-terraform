variable "docker_container_name" {
  default = "container-xxx"
}

variable "container_ports" {
  default = {
    internal = 80
    external = 8000
  }
}