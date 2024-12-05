variable "docker_container_name" {
  description = "The name of the Docker container."
}

variable "container_ports" {
  type = object({
    internal = number
    external = number
  })
  description = "Ports mapping for the Docker container."
}