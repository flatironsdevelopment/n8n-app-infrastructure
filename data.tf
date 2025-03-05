data "aws_caller_identity" "current" {
}

data "aws_secretsmanager_secret_version" "this" {
  secret_id = "${var.project_name}-infrastructure-variables"
}