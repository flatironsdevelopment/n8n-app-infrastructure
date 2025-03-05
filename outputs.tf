output "github_repo_url" {
  value = module.github_repo.github_repo_url
}

output "github_repo_url_app" {
  value = module.github_repo.github_repo_url_app
}

output "elasticache_cluster_hostname" {
  value = [{ for i in module.redis : "${i.app_name}" => "${i.elasticache_cluster_hostname}" }][0]
}

output "db_hostname" {
  value = [{ for i in module.database : "${i.app_name}" => "${i.db_hostname}" }][0]
}

output "cognito_user_pool_id" {
  value = [{ for i in module.cognito : "${i.app_name}" => "${i.cognito_user_pool_id}" }][0]
}

output "cognito_user_pool_client_id" {
  value = [{ for i in module.cognito : "${i.app_name}" => "${i.cognito_user_pool_client_id}" }][0]
}

output "access_key" {
  value = module.iam.access_key
}

output "secret_key" {
  value = module.iam.secret_key
  sensitive = true
}

output "aws_region" {
  value = nonsensitive("${var.aws_region}")
}

output "alb_dns" {
  value = var.skip_ecs ? "" : module.ecs_core[0].alb_dns
}

output "vpc_cidr_block" {
  value = module.vpc.vpc_cidr_block
}

output "apps" {
  value = local.app_list
}

output "workers" {
  value = local.worker_list
}