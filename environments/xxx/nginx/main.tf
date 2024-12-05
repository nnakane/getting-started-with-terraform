module "nginx" {
  source = "../../../modules/nginx"

  docker_container_name = var.docker_container_name
  container_ports = var.container_ports

  providers = {
    docker = docker
  }
}