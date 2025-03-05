locals {
  credentials = jsondecode(
    data.aws_secretsmanager_secret_version.this.secret_string
  )
  apps = jsondecode(jsondecode(
    nonsensitive(data.aws_secretsmanager_secret_version.this.secret_string)
  ).apps)

  worker_list = flatten([for i in local.apps: [
    [for worker in try(i.workers, []): {
      app_name: i.name,
      technology: i.technology,
      dockerfile: worker.dockerfile,
      worker_name: worker.name,
      build_env: length(try(i.build_env, {})) > 0 ? join("\n            ", [for k, v in i.build_env : "${upper(k)}=${v}"]) : ""
    }]
  ]])

  app_list = [for i in local.apps : 
    { 
      app_name: i.name, 
      technology: i.technology, 
      port: i.port,
      domain:  i.domain,
      health_check_path: i.health_check_path,
      cognito: try(i.cognito, false),
      postgres: try(i.postgres, false),
      redis: try(i.redis, false),
      dockerfile: i.dockerfile,
      variables: try(i.variables, {}),
      build_env: length(try(i.build_env, {})) > 0 ? join("\n            ", [for k, v in i.build_env : "${upper(k)}=${v}"]) : ""
    }
  ]
}