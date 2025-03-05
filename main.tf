
module "github_repo" {
  source                = "../../modules/github-repo"
  github_token          = var.github_token
  github_organization = var.github_organization
  project_name = var.project_name
}

module "github_actions" {
  source                = "../../modules/github-actions"
  github_token          = var.github_token
  project_name          = local.credentials.name
  aws_access_key_id     = var.aws_access_key_id
  aws_secret_access_key = var.aws_secret_access_key
  aws_region            = var.aws_region
  github_organization = var.github_organization
  kubernetes = false
  github_repo_name = module.github_repo.github_monorepo_name
  github_infrastructure_full_name = module.github_repo.github_infrastructure_full_name
  apps = toset(local.app_list)
  workers = toset(local.worker_list)
}

module "iam" {
  source       = "../../modules/iam"
  project_name = var.project_name
}

module "redis" {
  for_each = { for app in local.app_list : app.app_name => app if app.redis }
  source        = "../../modules/redis"
  vpc_id        = module.vpc.vpc_id
  subnet_ids    = module.vpc.private_subnets
  app_name  = each.value.app_name
}

module "vpc" {
  source       = "../../modules/vpc"
  project_name = var.project_name
  cluster_name = var.project_name
}

module "cloud-watch" {
  source            = "../../modules/cloud-watch"
  project_name      = var.project_name
  slack_webhook_url = local.credentials.slack_webhook_url
}

module "s3" {
  source       = "../../modules/simple-storage-service"
  project_name = var.project_name
}

module "ecr" {
  source       = "../../modules/elastic-container-registry"
  project_name = var.project_name
}

module "database" {
  for_each = { for app in local.app_list : app.app_name => app if app.postgres }
  source                     = "../../modules/relational-database-service"
  app_name                   = each.value.app_name
  allowed_ip_list            = var.access_ip_range
  vpc_id                     = module.vpc.vpc_id
  subnet_ids                 = module.vpc.public_subnets
  vpc_security_group_default = module.vpc.default_security_group_id
  db_username                = var.db_username
  db_password                = var.db_password
  db_name                = var.db_name
}

module "cognito" {
  for_each = { for app in local.app_list : app.app_name => app if app.cognito }
  source = "../../modules/cognito"

  app_name              = each.value.app_name
  application_url       = "https://${each.value.domain}"
  aws_region            = var.aws_region
  cognito_apikey_header = local.credentials.cognito_apikey_header
  log_group_name = var.project_name
}

module "ecs_core" {
  count = var.skip_ecs ? 0 : 1
  source = "../../modules/ecs-core"

  log_group_name = var.project_name
  aws_region = var.aws_region
  ingress_ssl_arn = local.credentials.ssl
  namespace = var.project_name
  project_name = var.project_name
  vpc_id                     = module.vpc.vpc_id
  public_subnets                 = module.vpc.public_subnets
  private_subnets                 = module.vpc.private_subnets
  default_security_group_id = module.vpc.default_security_group_id
  healthcheck_endpoint = "/health"
  apps = toset(local.app_list)
}

data "aws_secretsmanager_secret" "app_secret" {
  for_each = { for app in local.app_list : "${app.app_name}-secrets" => app }
  name = each.key
}

module "ecs_services" {
  for_each = { for app in local.app_list : app.app_name => app }
  source = "../../modules/ecs-service"

  app_name = each.value.app_name
  container_port = each.value.port
  connect_to_alb = true
  repository_url = "${module.ecr.repository_url}:${each.value.app_name}"
  ecs_secret_arn = data.aws_secretsmanager_secret.app_secret["${each.value.app_name}-secrets"].arn
  secret_name = "${each.value.app_name}-secrets"

  aws_region = var.aws_region
  default_security_group_id = module.vpc.default_security_group_id
  ecs_task_execution_role_arn = module.ecs_core[0].ecs_task_execution_role_arn
  ecs_task_role_arn = module.ecs_core[0].ecs_task_role_arn
  ecs_log_group_name = module.ecs_core[0].ecs_log_group_name
  ecs_cluster_id = module.ecs_core[0].ecs_cluster_id
  ecs_cluster_name = module.ecs_core[0].ecs_cluster_name
  ecs_container_security_group_id = module.ecs_core[0].ecs_container_security_group_id
  private_subnets                 = module.vpc.private_subnets

  aws_alb_target_group_arn = module.ecs_core[0].aws_alb_target_groups[each.key].arn
}


module "ecs_worker_services" {
  for_each = { for app in local.worker_list : app.app_name => app }
  source = "../../modules/ecs-service"

  app_name = "${each.value.worker_name}"
  connect_to_alb = false
  repository_url = "${module.ecr.repository_url}:${each.value.worker_name}"
  ecs_secret_arn = data.aws_secretsmanager_secret.app_secret["${each.value.app_name}-secrets"].arn
  secret_name = "${each.value.app_name}-secrets"

  aws_region = var.aws_region
  default_security_group_id = module.vpc.default_security_group_id
  ecs_task_execution_role_arn = module.ecs_core[0].ecs_task_execution_role_arn
  ecs_task_role_arn = module.ecs_core[0].ecs_task_role_arn
  ecs_log_group_name = module.ecs_core[0].ecs_log_group_name
  ecs_cluster_id = module.ecs_core[0].ecs_cluster_id
  ecs_cluster_name = module.ecs_core[0].ecs_cluster_name
  ecs_container_security_group_id = module.ecs_core[0].ecs_container_security_group_id
  private_subnets                 = module.vpc.private_subnets

  aws_alb_target_group_arn = ""
}